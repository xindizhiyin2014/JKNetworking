//
//  JKNetworkAgent.m
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import "JKNetworkAgent.h"
#import <AFNetworking/AFHTTPSessionManager.h>
#import "JKBaseRequest.h"
#import "JKGroupRequest.h"
#import "JKNetworkConfig.h"
#import "JKMockManager.h"
#import <JKDataHelper/JKDataHelper.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import "JKNetworkingMacro.h"
#import "JKBackgroundSessionManager.h"


@interface JKBaseRequest(JKNetworkAgent)

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *responseJSONObject;
@property (atomic, strong, readwrite, nullable) NSError *error;
/// the progressBlock of download/upload request
@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);
/// the parse block
@property (nonatomic, copy, nullable) id(^parseBlock)(__kindof JKBaseRequest *request, NSRecursiveLock *lock);
/// the request success block
@property (nonatomic, copy, nullable) void(^successBlock)(__kindof JKBaseRequest *request);
/// the request failure block
@property (nonatomic, copy, nullable) void(^failureBlock)(__kindof JKBaseRequest *request);

/// is a default/download/upload request
@property (nonatomic, assign) JKRequestType requestType;
/// when upload data cofig the formData
@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);
/// the url has signatured
@property (nonatomic, copy, readwrite, nullable) NSString *signaturedUrl;
/// the params has signatured
@property (nonatomic, strong, readwrite, nullable) id signaturedParams;
/// the data is from response is parsed
@property (nonatomic, strong, readwrite, nullable) id parsedData;


/// 每次真正发起请求前，重置状态，避免受到上次请求数据的干扰
- (void)resetOriginStatus;

@end

@implementation JKBaseRequest(JKNetworkAgent)

@dynamic requestTask;
@dynamic responseObject;
@dynamic responseJSONObject;
@dynamic error;
@dynamic progressBlock;
@dynamic parseBlock;
@dynamic successBlock;
@dynamic failureBlock;
@dynamic requestType;
@dynamic formDataBlock;
@dynamic signaturedUrl;
@dynamic signaturedParams;
@dynamic parsedData;

/// 每次真正发起请求前，重置状态，避免受到上次请求数据的干扰
- (void)resetOriginStatus
{
    self.requestTask = nil;
    self.responseObject = nil;
    self.responseJSONObject = nil;
    self.error = nil;
    self.signaturedUrl = nil;
    self.signaturedParams = nil;
    self.parsedData = nil;
}

@end



@interface JKNetworkAgent()
{
    dispatch_queue_t _processingQueue;
}
//@property (nonatomic, strong) NSMutableDictionary <NSNumber *, __kindof JKBaseRequest *>*requestDic;
@property (nonatomic, strong) NSMutableArray <__kindof JKBaseRequest *>*allStartedRequests;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) AFJSONResponseSerializer *jsonResponseSerializer;
@property (nonatomic, strong) AFXMLParserResponseSerializer *xmlParserResponseSerialzier;

/// the set of the request status
@property (nonatomic, strong) NSIndexSet *allStatusCodes;

/// the array of the batchRequest
@property (nonatomic, strong) NSMutableArray *batchRequests;

/// the array of the chainRequest
@property (nonatomic, strong) NSMutableArray *chainRequests;

/// the priority first request
@property (nonatomic, strong, nullable) id priorityFirstRequest;

/// the requests need after it fininsed,if the priority first request is not nil,
@property (nonatomic, strong, nonnull) NSMutableArray *bufferRequests;

@property (nonatomic, strong, nonnull) JKBackgroundSessionManager *backgroundSessionMananger;
@property (nonatomic, strong) NSRecursiveLock *parseLock;


@end


@implementation JKNetworkAgent

+ (instancetype)sharedAgent
{
    static JKNetworkAgent *_networkAgent = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _networkAgent = [[self alloc] init];
    });
    return _networkAgent;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _allStartedRequests = [NSMutableArray new];
        _batchRequests = [NSMutableArray new];
        _chainRequests = [NSMutableArray new];
        _bufferRequests = [NSMutableArray new];
        _lock = [[NSLock alloc] init];
        _processingQueue =dispatch_queue_create("com.jk.networkAgent.processing", DISPATCH_QUEUE_CONCURRENT);
        _sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:[JKNetworkConfig sharedConfig].sessionConfiguration];
        _sessionManager.securityPolicy = [JKNetworkConfig sharedConfig].securityPolicy;
        _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];
        _sessionManager.completionQueue = _processingQueue;
        _sessionManager.responseSerializer.acceptableStatusCodes = _allStatusCodes;
        _jsonResponseSerializer = [self config_jsonResponseSerializer];
        _xmlParserResponseSerialzier = [self config_xmlParserResponseSerialzier];
        _backgroundSessionMananger = [JKBackgroundSessionManager new];
        _parseLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)addRequest:(__kindof JKBaseRequest *)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    
    if (![request isKindOfClass:[JKBaseRequest class]]) {
#if DEBUG
        NSAssert(NO, @"please makesure [request isKindOfClass:[JKBaseRequest class]] be YES");
#endif
        return;
    }
    
    if (request.isExecuting) {
        return;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(beforeAllRequests)]) {
            [[JKNetworkConfig sharedConfig].requestHelper beforeAllRequests];
        }
    });
    if (self.priorityFirstRequest) {
        if (([self.priorityFirstRequest isKindOfClass:[JKBaseRequest class]] && ![self.priorityFirstRequest isEqual:request])
            || ([self.priorityFirstRequest isKindOfClass:[JKBatchRequest class]] && ![[(JKBatchRequest *)self.priorityFirstRequest requestArray] containsObject:request])
            ||([self.priorityFirstRequest isKindOfClass:[JKChainRequest class]] && ![[(JKChainRequest *)self.priorityFirstRequest requestArray] containsObject:request])) {
            [self.lock lock];
            if (![self.bufferRequests containsObject:request]) {
               [self.bufferRequests addObject:request];
            }
            [self.lock unlock];
            return;
        }
    }
    
    [request resetOriginStatus];
    if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(beforeEachRequest:)]) {
        [[JKNetworkConfig sharedConfig].requestHelper beforeEachRequest:request];
    }
    NSError * __autoreleasing requestSerializationError = nil;
    request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    if (requestSerializationError) {
        [self requestDidFailWithRequest:request error:requestSerializationError];
        return;
    }
    [self.lock lock];
    if (request) {
        [self.allStartedRequests addObject:request];
    }
    
    [self.lock unlock];
    
    [request.requestTask resume];
}

- (void)cancelRequest:(__kindof JKBaseRequest *)request
{
     if (!request) {
    #if DEBUG
            NSAssert(NO, @"request can't be nil");
    #endif
            return;
        }
        if (![request isKindOfClass:[JKBaseRequest class]]) {
    #if DEBUG
            NSAssert(NO, @"please makesure [request isKindOfClass:[JKBaseRequest class]] be YES");
    #endif
            return;
    }
    if (![self.allStartedRequests containsObject:request]) {
        [request clearCompletionBlock];
        return;
    }
    if (request.isCancelled
        || request.requestTask.state == NSURLSessionTaskStateCompleted) {
        return;
    }
    [request.requestTask cancel];
    [self.lock lock];
    [self.allStartedRequests removeObject:request];
    [self.lock unlock];
    
    [request clearCompletionBlock];
}

- (void)cancelAllRequests
{
    if (self.priorityFirstRequest) {
        if ([self.priorityFirstRequest isKindOfClass:[JKBaseRequest class]]) {
            JKBaseRequest *request = (JKBaseRequest *)self.priorityFirstRequest;
            [request stop];
        } else if ([self.priorityFirstRequest isKindOfClass:[JKBatchRequest class]]) {
            JKBatchRequest *request = (JKBatchRequest *)self.priorityFirstRequest;
            [request stop];
        } else if ([self.priorityFirstRequest isKindOfClass:[JKChainRequest class]]){
            JKChainRequest *request = (JKChainRequest *)self.priorityFirstRequest;
            [request stop];
        }
    }
    
    [self.lock lock];
    [self.batchRequests removeAllObjects];
    [self.chainRequests removeAllObjects];
    [self.bufferRequests removeAllObjects];
    [self.lock unlock];
    
    [self.lock lock];
    NSArray *allStartedRequests = [self.allStartedRequests copy];
    [self.lock unlock];
    
    for (__kindof JKBaseRequest *request in allStartedRequests) {
        [request stop];
    }
}


- (NSURLSessionTask *)sessionTaskForRequest:(__kindof JKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    NSString *url = nil;
    id param = nil;
    if (request.useSignature) {
        if ([request customSignature]) {
            url = request.signaturedUrl;
            param = request.signaturedParams;
        } else {
            if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(signatureRequest:)]) {
                [[JKNetworkConfig sharedConfig].requestHelper signatureRequest:request];
                url = request.signaturedUrl;
                param = request.signaturedParams;
            } else {
                NSError *signatureError = [NSError errorWithDomain:JKNetworkErrorDomain code:JKNetworkErrorNotSupportSignature userInfo:@{@"msg":@"the requestHelper do not implement selecotr signatureRequest:"}];
                signatureError = *error;
                return nil;
            }
        }
    } else {
        url = [self buildRequestUrl:request];
        param = request.requestArgument;
    }
    
    if ([JKNetworkConfig sharedConfig].isMock) {
        BOOL needMock = [JKMockManager matchRequest:request url:url];
        if (needMock) {
            NSURL *Url = [NSURL URLWithString:url];
            NSString *scheme = Url.scheme;
            NSString *host = Url.host;
            NSNumber *port = Url.port;
            NSString *domain = nil;
            if (port) {
                domain = [NSString stringWithFormat:@"%@://%@:%@",scheme,host,port];
            } else {
                domain = [NSString stringWithFormat:@"%@://%@",scheme,host];
            }
           url = [url stringByReplacingOccurrencesOfString:domain withString:[JKNetworkConfig sharedConfig].mockBaseUrl];
        }
    }
    
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
    if (request.requestType == JKRequestTypeDownload) {
        return [self downloadTaskWithRequest:(JKDownloadRequest *)request requestSerializer:requestSerializer URLString:url parameters:param error:error];
    } else if (request.requestType == JKRequestTypeUpload) {
        return [self uploadTaskWithRequest:request requestSerializer:requestSerializer URLString:url parameters:param error:error];
    }
    return [self dataTaskWithRequest:request requestSerializer:requestSerializer URLString:url parameters:param error:error];
}



- (NSURLSessionTask *)downloadTaskWithRequest:(__kindof JKDownloadRequest *)request
                            requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                    URLString:(NSString *)URLString
                                    parameters:(id)parameters
                                         error:(NSError * _Nullable __autoreleasing *)error
{
   __block NSURLSessionTask *dataTask = [self.backgroundSessionMananger dataTaskWithDownloadRequest:request requestSerializer:requestSerializer URLString:URLString parameters:parameters progress:request.progressBlock completionHandler:^(NSURLResponse * _Nonnull response, NSError * _Nullable error) {
        [self handleResultWithRequest:request error:error];
    } error:error];
    return dataTask;
}

- (NSURLSessionDataTask *)uploadTaskWithRequest:(__kindof JKUploadRequest *)request
                                requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                        URLString:(NSString *)URLString
                                       parameters:(id)parameters
                                            error:(NSError * _Nullable __autoreleasing *)error
{
    NSMutableURLRequest *urlRequest = [requestSerializer multipartFormRequestWithMethod:@"POST" URLString:URLString parameters:parameters constructingBodyWithBlock:request.formDataBlock error:error];
    __block NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:urlRequest uploadProgress:request.progressBlock downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        request.responseObject = responseObject;
        [self handleResultWithRequest:request error:error];
    }];
    request.requestTask = dataTask;
    return dataTask;
}


- (NSURLSessionDataTask *)dataTaskWithRequest:(__kindof JKBaseRequest *)request
                            requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                    URLString:(NSString *)URLString
                                   parameters:(id)parameters
                                        error:(NSError * _Nullable __autoreleasing *)error
{
    NSString *method = nil;
    switch (request.requestMethod) {
        case JKRequestMethodGET:
        {
            method = @"GET";
        }
            break;
        case JKRequestMethodPOST:
        {
            method = @"POST";
        }
            break;
        case JKRequestMethodHEAD:
        {
            method = @"HEAD";
        }
            break;
        case JKRequestMethodPUT:
        {
            method = @"PUT";
        }
            break;
        case JKRequestMethodDELETE:
        {
            method = @"DELETE";
        }
            break;
        case JKRequestMethodPATCH:
        {
            method = @"PATCH";
        }
            break;
        default:
            break;
    }
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    __block NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:urlRequest uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        request.responseObject = responseObject;
        [self handleResultWithRequest:request error:error];
    }];
    return dataTask;
}

- (void)handleResultWithRequest:(__kindof JKBaseRequest *)request error:(NSError *)error
{
    if (!request) {
        return;
    }
    NSError *__autoreleasing serializationError = nil;
    NSError *__autoreleasing validationError = nil;
    NSError *requestError = nil;
    BOOL succeed = NO;
    
    if (request.requestType != JKRequestTypeDownload) {
        NSData *responseData = nil;
        if ([request.responseObject isKindOfClass:[NSData class]]) {
            responseData = (NSData *)request.responseObject;
        }
        switch (request.responseSerializerType) {
            case JKResponseSerializerTypeHTTP:
    //            defalut serializer. do nothing
                break;
                
            case JKResponseSerializerTypeJSON: {
                request.responseObject = [self.jsonResponseSerializer responseObjectForResponse:request.requestTask.response data:responseData error:&serializationError];
                request.responseJSONObject = request.responseObject;
            }
                break;
            
            case JKResponseSerializerTypeXMLParser: {
                request.responseObject = [self.xmlParserResponseSerialzier responseObjectForResponse:request.requestTask.response data:responseData error:&serializationError];
            }
                break;
                
            default:
                break;
        }
    }
    
    if (error) {
        succeed = NO;
        requestError = error;
    } else if (serializationError) {
        succeed = NO;
        requestError = serializationError;
    } else {
        if (request.responseSerializerType == JKResponseSerializerTypeHTTP
            || request.responseSerializerType == JKResponseSerializerTypeJSON) {
            succeed = [self validateResult:request error:&validationError];
            requestError = validationError;
        }
    }

    if (succeed) {
        [self requestDidSucceedWithRequest:request];
    } else {
        [self requestDidFailWithRequest:request error:requestError];
    }
    if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(afterEachRequest:)]) {
        [[JKNetworkConfig sharedConfig].requestHelper afterEachRequest:request];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.lock lock];
        [self.allStartedRequests removeObject:request];
        [self.lock unlock];
        [request clearCompletionBlock];
    });
}

- (BOOL)validateResult:(__kindof JKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    BOOL result = YES;
    result = [request statusCodeValidator];
    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:JKNetworkErrorDomain code:JKNetworkErrorStatusCode userInfo:@{NSLocalizedDescriptionKey:@"Invalid status code"}];
        }
        return result;
    }
    if (request.requestType == JKRequestTypeDownload) {
        return YES;
    }
    id json = request.responseJSONObject;
    id validator = [request jsonValidator];
    if (json && validator) {
        result = [self validateJSON:json withValidator:validator];
        if (!result) {
            NSError *tmpError = [[NSError alloc] initWithDomain:JKNetworkErrorDomain code:JKNetworkErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"validateResult failed",@"extra":request.responseJSONObject?:@{}}];
            if (error != NULL) {
              *error = tmpError;
            }
        } else {
            if ([JKNetworkConfig sharedConfig].requestHelper
                && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(validateBusinessSuccess:error:)]) {
                result = [[JKNetworkConfig sharedConfig].requestHelper validateBusinessSuccess:request error:error];
                if (!result) {
                    return result;
                }
            }
        }
    } else if (!json) {
#if DEBUG
        NSLog(@"JKNetworking validateResult responseJSONObject is nil");
#endif
    }
    return result;
}

- (void)requestDidSucceedWithRequest:(__kindof JKBaseRequest *)request
{
    @autoreleasepool {
        BOOL needExtraHandle = [request requestSuccessPreHandle];
        if (needExtraHandle) {
            if ([JKNetworkConfig sharedConfig].requestHelper
                && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(preHandleSuccessRequest:)]) {
                [[JKNetworkConfig sharedConfig].requestHelper preHandleSuccessRequest:request];
            }
        }
    }
    if ([request isKindOfClass:[JKRequest class]]
        && request.parseBlock) {
        request.parsedData = request.parseBlock(request,self.parseLock);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.isIndependentRequest) {
            if (request.requestAccessory
                && [request.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [request.requestAccessory requestWillStop:request];
            }
        }
        if (request.successBlock) {
            request.successBlock(request);
        }
        if (request.isIndependentRequest) {
            if (request.requestAccessory
                && [request.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [request.requestAccessory requestDidStop:request];
            }
        }
        [self judgeToStartBufferRequestsWithRequest:request];
    });
    
}

- (void)requestDidFailWithRequest:(__kindof JKBaseRequest *)request error:(NSError *)error
{
    request.error = error;
    @autoreleasepool {
        BOOL needExtraHandle = [request requestFailurePreHandle];
        if (needExtraHandle) {
            if ([JKNetworkConfig sharedConfig].requestHelper
                && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(preHandleFailureRequest:)]) {
                [[JKNetworkConfig sharedConfig].requestHelper preHandleFailureRequest:request];
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.isIndependentRequest) {
            if (request.requestAccessory
                && [request.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [request.requestAccessory requestWillStop:request];
            }
        }
        if (request.failureBlock) {
            request.failureBlock(request);
        }
        if (request.isIndependentRequest) {
            if (request.requestAccessory
                && [request.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [request.requestAccessory requestDidStop:request];
            }
        }
        [self judgeToStartBufferRequestsWithRequest:request];
    });
    
}

- (NSString *)buildRequestUrl:(__kindof JKBaseRequest *)request
{
    NSString *urlStr = [request buildCustomRequestUrl];
    if (!urlStr || (urlStr && [urlStr isKindOfClass:[NSString class]] && urlStr.length == 0)) {
        NSString *detailUrl = [request requestUrl];
        
        if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(filterUrl:withRequest:)]) {
            detailUrl = [[JKNetworkConfig sharedConfig].requestHelper filterUrl:detailUrl withRequest:request];
        }
        
        NSString *baseUrl = @"";
        if ([request useCDN]) {
            if (request.cdnBaseUrl.length > 0) {
                baseUrl = request.cdnBaseUrl;
            }else{
                if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(baseUrlOfRequest:)]) {
                     baseUrl = [[JKNetworkConfig sharedConfig].requestHelper baseUrlOfRequest:request];
                }else {
                    baseUrl = [JKNetworkConfig sharedConfig].cdnBaseUrl;
                }
            }
        }else{
          if (request.baseUrl.length > 0) {
              baseUrl = request.baseUrl;
          } else {
              if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(baseUrlOfRequest:)]) {
                   baseUrl = [[JKNetworkConfig sharedConfig].requestHelper baseUrlOfRequest:request];
              }else {
                   baseUrl = [JKNetworkConfig sharedConfig].baseUrl;
              }
          }
        }
        if (baseUrl.length == 0) {
#if DEBUG
            NSAssert(NO, @"please make sure baseUrl.length > 0 be YES!");
#endif
        }
        NSURL *url = [NSURL URLWithString:baseUrl];
        if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"]) {
            url = [url URLByAppendingPathComponent:@""];
        }
        if (![[url path] isEqualToString:@"/"]) {
          detailUrl = [NSString stringWithFormat:@"%@%@",[url path],detailUrl];
        }
        urlStr = [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
    }
    return urlStr;
}

- (void)addBatchRequest:(__kindof JKBatchRequest *)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    if (![request isKindOfClass:[JKBatchRequest class]]) {
#if DEBUG
        NSAssert(NO, @"please makesure [request isKindOfClass:[JKBatchRequest class]] be YES");
#endif
        return;
    }
    if (self.priorityFirstRequest && ![self.priorityFirstRequest isEqual:request]) {
        [self.lock lock];
        if (![self.bufferRequests containsObject:request]) {
            [self.bufferRequests addObject:request];
        }
        [self.lock unlock];
    } else{
        [self.lock lock];
        if (![self.batchRequests containsObject:request]) {
            [self.batchRequests addObject:request];
        }
        [self.lock unlock];
        [request start];
    }
}

- (void)removeBatchRequest:(__kindof JKBatchRequest *)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    if (![request isKindOfClass:[JKBatchRequest class]]) {
#if DEBUG
        NSAssert(NO, @"please makesure [request isKindOfClass:[JKBatchRequest class]] be YES");
#endif
        return;
    }
    [self.lock lock];
    [self.batchRequests removeObject:request];
    [self.lock unlock];
    for (__kindof JKBaseRequest *baseRequest in [request.requestArray copy]) {
        [baseRequest stop];
    }
    [self judgeToStartBufferRequestsWithRequest:request];
}

- (void)addChainRequest:(__kindof JKChainRequest *)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    if (![request isKindOfClass:[JKChainRequest class]]) {
#if DEBUG
        NSAssert(NO, @"please makesure [request isKindOfClass:[JKChainRequest class]] be YES");
#endif
        return;
    }
    if (self.priorityFirstRequest && ![self.priorityFirstRequest isEqual:request]) {
        [self.lock lock];
        if (![self.bufferRequests containsObject:request]) {
            [self.bufferRequests addObject:request];
        }
        [self.lock unlock];

    } else{
        [self.lock lock];
        if (![self.chainRequests containsObject:request]) {
            [self.chainRequests addObject:request];
        }
        [self.lock unlock];
        [request start];
    }
}

- (void)removeChainRequest:(__kindof JKChainRequest *)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    if (![request isKindOfClass:[JKChainRequest class]]) {
#if DEBUG
        NSAssert(NO, @"please makesure [request isKindOfClass:[JKChainRequest class]] be YES");
#endif
        return;
    }
    [self.lock lock];
    [self.chainRequests removeObject:request];
    [self.lock unlock];
    for (__kindof JKBaseRequest *baseRequest in [request.requestArray copy]) {
        [baseRequest stop];
    }
    [self judgeToStartBufferRequestsWithRequest:request];
}

- (void)addPriorityFirstRequest:(id)request
{
    if (!request) {
#if DEBUG
        NSAssert(NO, @"request can't be nil");
#endif
        return;
    }
    if (!([request isKindOfClass:[JKBaseRequest class]]
          || [request isKindOfClass:[JKBatchRequest class]]
          || [request isKindOfClass:[JKChainRequest class]])) {
#if DEBUG
        NSAssert(NO, @"no support this request as a PriorityFirstRequest");
#endif
        return;
    }
    
    if (self.allStartedRequests.count > 0) {
#if DEBUG
       NSAssert(NO, @"addPriorityFirstRequest func must use before any request started");
#endif
       return;
    }
    self.priorityFirstRequest = request;
}

- (NSArray <__kindof JKBaseRequest *>*)allRequests
{
    [self.lock lock];
    NSMutableSet *requestSet = [NSMutableSet new];
    NSArray *array1 = [self.allStartedRequests copy];
    [requestSet addObjectsFromArray:array1];
    for (__kindof JKBatchRequest *request in self.batchRequests) {
        NSArray *tmpArray = request.requestArray;
        [requestSet addObjectsFromArray:tmpArray];
    }

    for (__kindof JKChainRequest *request in self.chainRequests) {
        NSArray *tmpArray = request.requestArray;
        [requestSet addObjectsFromArray:tmpArray];
    }
    if (self.priorityFirstRequest) {
        if ([self.priorityFirstRequest isKindOfClass:[JKBatchRequest class]]) {
            JKBatchRequest *request = (JKBatchRequest *)self.priorityFirstRequest;
            NSArray *tmpArray = request.requestArray;
            [requestSet addObjectsFromArray:tmpArray];
        } else if([self.priorityFirstRequest isKindOfClass:[JKChainRequest class]]) {
            JKChainRequest *request = self.priorityFirstRequest;
            NSArray *tmpArray = request.requestArray;
            [requestSet addObjectsFromArray:tmpArray];
        } else if ([self.priorityFirstRequest isKindOfClass:[JKBaseRequest class]]) {
            [requestSet addObject:self.priorityFirstRequest];
        }
    }
    [self.lock unlock];
    return [requestSet allObjects];
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier
                                                                   completionHandler:(void (^)(void))completionHandler
{
    if ([self.backgroundSessionMananger.backgroundTaskIdentifier isEqualToString:identifier]) {
        self.backgroundSessionMananger.completionHandler = completionHandler;
    }
}

- (void)judgeToStartBufferRequestsWithRequest:(id)request
{
    if (self.priorityFirstRequest && [self.priorityFirstRequest isEqual:request]) {
        self.priorityFirstRequest = nil;
        for (id tmpRequest in self.bufferRequests) {
            if ([tmpRequest isKindOfClass:[JKBaseRequest class]]) {
                [self addRequest:tmpRequest];
            } else if ([tmpRequest isKindOfClass:[JKBatchRequest class]]) {
                [self addBatchRequest:tmpRequest];
            } else if([tmpRequest isKindOfClass:[JKChainRequest class]]) {
                [self addChainRequest:tmpRequest];
            }
        }
        [self.bufferRequests removeAllObjects];
    }
}

- (AFHTTPRequestSerializer *)requestSerializerForRequest:(__kindof JKBaseRequest *)request {
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (request.requestSerializerType == JKRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (request.requestSerializerType == JKRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
    if ([JKNetworkConfig sharedConfig].HTTPMethodsEncodingParametersInURI) {
        requestSerializer.HTTPMethodsEncodingParametersInURI = [JKNetworkConfig sharedConfig].HTTPMethodsEncodingParametersInURI;
    }
    if ([JKNetworkConfig sharedConfig].isMock) {
     requestSerializer.timeoutInterval = [JKNetworkConfig sharedConfig].mockModelTimeoutInterval;
    } else {
     requestSerializer.timeoutInterval = [request requestTimeoutInterval];
    }
    
    // If api needs to add custom value to HTTPHeaderField
    NSDictionary<NSString *, NSString *> *headerFieldValueDictionary = [request requestHeaders];
    if (headerFieldValueDictionary != nil) {
        for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys) {
            NSString *value = headerFieldValueDictionary[httpHeaderField];
            [requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    return requestSerializer;
}

- (NSString *)incompleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    static NSString *cacheFolder;

    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:@"JKIncomplete"];
    }

    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
#if DEBUG
    NSLog(@"Failed to create cache directory at %@", cacheFolder);
#endif
    cacheFolder = nil;
    }
    return cacheFolder;
}

- (NSURL *)incompleteTmpFileURLForDownloadURLString:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLStr = [JKNetworkAgent MD5String:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLStr];
    return [NSURL fileURLWithPath:tempPath];
}



#pragma mark - private -
- (AFJSONResponseSerializer *)config_jsonResponseSerializer
{
    AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
    jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;
    jsonResponseSerializer.removesKeysWithNullValues = YES;
    return jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)config_xmlParserResponseSerialzier
{
    AFXMLParserResponseSerializer *xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
    xmlParserResponseSerialzier.acceptableStatusCodes = _allStatusCodes;
    return xmlParserResponseSerialzier;
}

- (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator {
    if ([json isKindOfClass:[NSDictionary class]] &&
        [jsonValidator isKindOfClass:[NSDictionary class]]) {
        NSDictionary * dict = json;
        NSDictionary * validator = jsonValidator;
        BOOL result = YES;
        NSEnumerator * enumerator = [validator keyEnumerator];
        NSString * key;
        while ((key = [enumerator nextObject]) != nil) {
            id value = dict[key];
            id format = validator[key];
            if ([value isKindOfClass:[NSDictionary class]]
                || [value isKindOfClass:[NSArray class]]) {
                result = [self validateJSON:value withValidator:format];
                if (!result) {
                    break;
                }
            } else {
                if ([value isKindOfClass:format] == NO &&
                    [value isKindOfClass:[NSNull class]] == NO) {
                    result = NO;
                    break;
                }
            }
        }
        return result;
    } else if ([json isKindOfClass:[NSArray class]] &&
               [jsonValidator isKindOfClass:[NSArray class]]) {
        NSArray * validatorArray = (NSArray *)jsonValidator;
        if (validatorArray.count > 0) {
            NSArray * array = json;
            NSDictionary * validator = jsonValidator[0];
            for (id item in array) {
                BOOL result = [self validateJSON:item withValidator:validator];
                if (!result) {
                    return NO;
                }
            }
        }
        return YES;
    } else if ([json isKindOfClass:jsonValidator]) {
        return YES;
    } else {
        return NO;
    }
}

+ (NSString *)MD5String:(NSString *)string
{
   if (!jk_safeStr(string)) {
        return nil;
    }
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), digest ); // This is the md5 call
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return  output?:@"";
}


@end
