//
//  JKNetworkAgent.m
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import "JKNetworkAgent.h"
#import <AFNetworking/AFNetworking.h>
#import "JKBaseRequest.h"
#import "JKGroupRequest.h"
#import "JKNetworkConfig.h"
#import "JKMockManager.h"

@interface JKBaseRequest(Private)

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;
@property (nonatomic, strong, readwrite, nullable) NSError *error;
/// the progressBlock of download/upload request
@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);

/// the request success block
@property (nonatomic, copy, nullable) void(^successCompletionBlock)(__kindof JKBaseRequest *request);

/// the request failure block progress block
@property (nonatomic, copy, nullable) void(^failureCompletionBlock)(__kindof JKBaseRequest *request);
/// is a default/download/upload request
@property (nonatomic, assign) JKRequestType requestType;

/// the data need to upload
@property (nonatomic, strong) NSData *uploadData;

/// when upload data cofig the formData
@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);

@end

@implementation JKBaseRequest(Private)
@dynamic requestTask,responseObject,responseJSONObject,error,progressBlock,successCompletionBlock,failureCompletionBlock,requestType,uploadData,formDataBlock;

@end



@interface JKNetworkAgent()
{
    dispatch_queue_t _processingQueue;
}
@property (nonatomic, strong) NSMutableDictionary <NSNumber *,__kindof JKBaseRequest *>*requestDic;
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
@property (nonatomic, strong, nullable) id priprityFirstRequest;

/// the requests need after it fininsed,if the priority first request is not nil,
@property (nonatomic, strong, nonnull) NSMutableArray *bufferRequests;

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
        _requestDic = [NSMutableDictionary dictionary];
        _batchRequests = [NSMutableArray new];
        _chainRequests = [NSMutableArray new];
        _bufferRequests = [NSMutableArray new];
        _lock = [[NSLock alloc] init];
        _processingQueue =dispatch_queue_create("com.jk.networkAgent.processing", DISPATCH_QUEUE_CONCURRENT);
        _sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:[JKNetworkConfig sharedConfig].sessionConfiguration];
        _sessionManager.securityPolicy = [JKNetworkConfig sharedConfig].securityPolicy;
        _sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _allStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];
        _sessionManager.completionQueue = _processingQueue;
        _sessionManager.responseSerializer.acceptableStatusCodes = _allStatusCodes;
    }
    return self;
}

- (void)addRequest:(__kindof JKBaseRequest *)request
{
    if (self.priprityFirstRequest) {
        if (([self.priprityFirstRequest isKindOfClass:[JKBaseRequest class]] && ![self.priprityFirstRequest isEqual:request])
            || ([self.priprityFirstRequest isKindOfClass:[JKBatchRequest class]] && ![[(JKBatchRequest *)self.priprityFirstRequest requestArray] containsObject:request])
            ||([self.priprityFirstRequest isKindOfClass:[JKChainRequest class]] && ![[(JKChainRequest *)self.priprityFirstRequest requestArray] containsObject:request])) {
            [self.lock lock];
            if (![self.bufferRequests containsObject:request]) {
               [self.bufferRequests addObject:request];
            }
            [self.lock unlock];
            return;
        }
    }
    
    if (request.isExecuting) {
        return;
    }
    NSError * __autoreleasing requestSerializationError = nil;
    request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    if (requestSerializationError) {
        [self requestDidFailWithRequest:request error:requestSerializationError];
        return;
    }
    [self.lock lock];
    if (request) {
        [self.requestDic addEntriesFromDictionary:@{@(request.requestTask.taskIdentifier):request}];
    }
    
    [self.lock unlock];
    
    [request.requestTask resume];
}

- (void)cancelRequest:(__kindof JKBaseRequest *)request
{
    if (!request) {
        return;
    }
    [request.requestTask cancel];
    [self.lock lock];
    [self.requestDic removeObjectForKey:@(request.requestTask.taskIdentifier)];
    [self.lock unlock];
    
    [request clearCompletionBlock];
}

- (void)cancelAllRequests
{
    if (self.priprityFirstRequest) {
        if ([self.priprityFirstRequest isKindOfClass:[JKBaseRequest class]]) {
            JKBaseRequest *request = (JKBaseRequest *)self.priprityFirstRequest;
            [request stop];
        } else if ([self.priprityFirstRequest isKindOfClass:[JKBatchRequest class]]) {
            JKBatchRequest *request = (JKBatchRequest *)self.priprityFirstRequest;
            [request stop];
        } else if ([self.priprityFirstRequest isKindOfClass:[JKChainRequest class]]){
            JKChainRequest *request = (JKChainRequest *)self.priprityFirstRequest;
            [request stop];
        }
    }
    
    NSArray *allKeys = nil;
    [self.lock lock];
    [self.bufferRequests removeAllObjects];
    allKeys = [self.requestDic allKeys];
    [self.lock unlock];
    
    if (allKeys && allKeys.count > 0) {
        JKBaseRequest *reuqest = nil;
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys) {
            [self.lock lock];
            reuqest = self.requestDic[key];
            [self.lock unlock];
            
            if (reuqest) {
                [reuqest stop];
            }
        }
    }
}

- (NSURLSessionTask *)sessionTaskForRequest:(__kindof JKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    
    JKRequestMethod method = [request requestMethod];
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
    }else {
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
        return [self downloadTaskWithRequestSerializer:requestSerializer URLString:url parameters:param progress:request.progressBlock error:error];
    } else if (request.requestType == JKRequestTypeUpload) {
        return [self uploadTaskWithRequestSerializer:requestSerializer URLString:url parameters:param data:request.uploadData progress:request.progressBlock formDataBlock:request.formDataBlock error:error];
    }
    
    switch (method) {
        case JKRequestMethodGET:
        {
            return [self dataTaskWithHTTPMethod:@"GET" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case JKRequestMethodPOST:
        {
            return [self dataTaskWithHTTPMethod:@"POST" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case JKRequestMethodHEAD:
        {
            return [self dataTaskWithHTTPMethod:@"HEAD" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case JKRequestMethodPUT:
        {
            return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case JKRequestMethodDELETE:
        {
           return [self dataTaskWithHTTPMethod:@"DELETE" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        case JKRequestMethodPATCH:
        {
           return [self dataTaskWithHTTPMethod:@"PATCH" requestSerializer:requestSerializer URLString:url parameters:param error:error];
        }
            break;
        default:
            break;
    }
    return nil;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                                 URLString:(NSString *)URLString
                                                parameters:(id)parameters
                                                  progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                                     error:(NSError * _Nullable __autoreleasing *)error {
    // add parameters to URL;
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:parameters error:error];

    NSString *downloadTargetPath;
    NSString *downloadFolderPath = [JKNetworkConfig sharedConfig].downloadFolderPath;
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:downloadFolderPath isDirectory:&isDirectory]) {
       isDirectory = [[NSFileManager defaultManager] createDirectoryAtPath:downloadFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // If targetPath is a directory, use the file name we got from the urlRequest.
    // Make sure downloadTargetPath is always a file, not directory.
    if (isDirectory) {
        NSString *fileName = [JKBaseDownloadRequest MD5String:urlRequest.URL.absoluteString];
        fileName = [fileName stringByAppendingPathExtension:urlRequest.URL.pathExtension]?:@"";
        downloadTargetPath = [NSString pathWithComponents:@[downloadFolderPath, fileName]];
    } else {
        return nil;
    }

    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    // https://github.com/AFNetworking/AFNetworking/issues/3775
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }

    NSString *tempFilePath = [self incompleteDownloadTempPathForDownloadPath:downloadTargetPath].path;
    BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:tempFilePath];
    NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:downloadTargetPath]];
    BOOL resumeDataIsValid = [JKNetworkAgent validateResumeData:data];

    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
    BOOL resumeSucceeded = NO;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    // Try to resume with resumeData.
    // Even though we try to validate the resumeData, this may still fail and raise excecption.
    if (canBeResumed) {
        @try {
            downloadTask = [self.sessionManager downloadTaskWithResumeData:data progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                return [NSURL fileURLWithPath:tempFilePath isDirectory:NO];
            } completionHandler:
                            ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                if (!error) {
                    [[NSFileManager defaultManager] moveItemAtPath:tempFilePath toPath:downloadTargetPath error:&error];
                }
                [self handleRequestResult:downloadTask responseObject:filePath error:error];
                            }];
            resumeSucceeded = YES;
        } @catch (NSException *exception) {
#if DEBUG
  NSLog(@"Resume download failed, reason = %@", exception.reason);
#endif
            resumeSucceeded = NO;
        }
    }
    if (!resumeSucceeded) {
        downloadTask = [self.sessionManager downloadTaskWithRequest:urlRequest progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:tempFilePath isDirectory:NO];
        } completionHandler:
                        ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                        if (!error) {
                            [[NSFileManager defaultManager] moveItemAtPath:tempFilePath toPath:downloadTargetPath error:&error];
                        }
                        [self handleRequestResult:downloadTask responseObject:filePath error:error];
                        }];
    }
    return downloadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                                    URLString:(NSString *)URLString
                                                   parameters:(id)parameters
                                                         data:(NSData *)data
                                                     progress:(nullable void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                                formDataBlock:(nullable void (^)(id <AFMultipartFormData> formData))formDataBlock
                                                        error:(NSError * _Nullable __autoreleasing *)error
{

 NSMutableURLRequest *urlRequest = [requestSerializer multipartFormRequestWithMethod:@"POST" URLString:URLString parameters:parameters constructingBodyWithBlock:formDataBlock error:error];
    __block NSURLSessionUploadTask *uploadTask = [self.sessionManager uploadTaskWithRequest:urlRequest fromData:data progress:^(NSProgress * _Nonnull uploadProgress) {
        if (uploadProgressBlock) {
            uploadProgressBlock(uploadProgress);
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [self handleRequestResult:uploadTask responseObject:responseObject error:error];
    }];
    return uploadTask;
}

- (void)handleRequestResult:(NSURLSessionTask *)task responseObject:(id)responseObject error:(NSError *)error
{
    JKBaseRequest *request = nil;
    [self.lock lock];
    request = self.requestDic[@(task.taskIdentifier)];
    [self.lock unlock];
    
    if (!request) {
        return;
    }
    
    NSError *__autoreleasing serializationError = nil;
    NSError *__autoreleasing validationError = nil;
    NSError *requestError = nil;
    BOOL succeed = NO;
    
    if (request.requestType != JKRequestTypeDownload) {
        request.responseObject = responseObject;
            NSData *responseData = nil;
            if ([request.responseObject isKindOfClass:[NSData class]]) {
                responseData = (NSData *)responseObject;
            }
            switch (request.responseSerializerType) {
                case JKResponseSerializerTypeHTTP:
        //            defalut serializer. do nothing
                    break;
                    case JKResponseSerializerTypeJSON:
                {
                    request.responseObject = [self.jsonResponseSerializer responseObjectForResponse:task.response data:responseData error:&serializationError];
                    request.responseJSONObject = request.responseObject;
                }
                    break;
                    case JKResponseSerializerTypeXMLParser:
                {
                    request.responseObject = [self.xmlParserResponseSerialzier responseObjectForResponse:task.response data:responseData error:&serializationError];
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
        if (request.responseSerializerType == JKResponseSerializerTypeJSON) {
            succeed = [self validateResult:request error:&validationError];
            requestError = validationError;
        }
    }
    
    if (succeed) {
        [self requestDidSucceedWithRequest:request];
    } else {
        [self requestDidFailWithRequest:request error:requestError];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.lock lock];
        [self.requestDic removeObjectForKey:@(task.taskIdentifier)];
        [self.lock unlock];
        
        [request clearCompletionBlock];
    });
}

- (BOOL)validateResult:(__kindof JKBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error
{
    if (request.requestType == JKRequestTypeDownload) {
        return YES;
    }
    BOOL result = YES;
    id json = request.responseJSONObject;
    id validator = [request jsonValidator];
    if (json && validator) {
        result = [self validateJSON:json withValidator:validator];
        if (!result) {
            NSError *tmpError = [[NSError alloc] initWithDomain:JKNetworkErrorDomain code:JKNetworkErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"validateResult failed",@"extra":request.responseJSONObject?:@{}}];
            if (error != NULL) {
              *error = tmpError;
            }
        }
    }
    return result;
}

- (void)requestDidSucceedWithRequest:(__kindof JKBaseRequest *)request
{
    @autoreleasepool {
        BOOL needExtraHandle = [request requestSuccessPreHandle];
        if (needExtraHandle) {
            if ([JKNetworkConfig sharedConfig].requestHelper && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(preHandleSuccessRequest:)]) {
                [[JKNetworkConfig sharedConfig].requestHelper preHandleSuccessRequest:request];
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.isIndependentRequest) {
            if (request.requestAccessory && [request.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [request.requestAccessory requestWillStop:request];
            }
        }
        if (request.successCompletionBlock) {
            request.successCompletionBlock(request);
        }
        if (request.isIndependentRequest) {
            if (request.requestAccessory && [request.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
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
            if ([JKNetworkConfig sharedConfig].requestHelper && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(preHandleFailureRequest:)]) {
                [[JKNetworkConfig sharedConfig].requestHelper preHandleFailureRequest:request];
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.isIndependentRequest) {
            if (request.requestAccessory && [request.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [request.requestAccessory requestWillStop:request];
            }
        }
        if (request.failureCompletionBlock) {
            request.failureCompletionBlock(request);
        }
        if (request.isIndependentRequest) {
            if (request.requestAccessory && [request.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
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
          if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(baseUrlOfRequest:)]) {
               baseUrl = [[JKNetworkConfig sharedConfig].requestHelper baseUrlOfRequest:request];
          }else {
                baseUrl = [JKNetworkConfig sharedConfig].baseUrl;
              
          }
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
    if (self.priprityFirstRequest && ![self.priprityFirstRequest isEqual:request]) {
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
    [self.lock lock];
    [self.batchRequests removeObject:request];
    [self.lock unlock];
    [self judgeToStartBufferRequestsWithRequest:request];
}

- (void)addChainRequest:(__kindof JKChainRequest *)request
{
    if (self.priprityFirstRequest && ![self.priprityFirstRequest isEqual:request]) {
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
    [self.lock lock];
    [self.chainRequests removeObject:request];
    [self.lock unlock];
    [self judgeToStartBufferRequestsWithRequest:request];
}

- (void)addPriorityFirstRequest:(id)request
{
    if (!([request isKindOfClass:[JKBaseRequest class]] || [request isKindOfClass:[JKBatchRequest class]] || [request isKindOfClass:[JKChainRequest class]])) {
#if DEBUG
        NSAssert(NO, @"no support this request as a PriorityFirstRequest");
#endif
    }
    
#if DEBUG
    if (self.requestDic.count > 0) {
        NSAssert(NO, @"addPriorityFirstRequest func must use before any request started");
    }
#endif
    self.priprityFirstRequest = request;
}

- (void)judgeToStartBufferRequestsWithRequest:(id)request
{
    if (self.priprityFirstRequest && [self.priprityFirstRequest isEqual:request]) {
        self.priprityFirstRequest = nil;
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

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                           error:(NSError * _Nullable __autoreleasing *)error {
    return [self dataTaskWithHTTPMethod:method requestSerializer:requestSerializer URLString:URLString parameters:parameters constructingBodyWithBlock:nil error:error];
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
                                           error:(NSError * _Nullable __autoreleasing *)error {
    NSMutableURLRequest *request = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self.sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [self handleRequestResult:dataTask responseObject:responseObject error:error];
    }];
    return dataTask;
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

- (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLStr = [JKBaseDownloadRequest MD5String:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLStr];
    return [NSURL fileURLWithPath:tempPath];
}

+ (BOOL)validateResumeData:(NSData *)data {
    // From http://stackoverflow.com/a/22137510/3562486
    if (!data || [data length] < 1) return NO;

    NSError *error;
    NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    if (!resumeDictionary || error) return NO;

    // Before iOS 9 & Mac OS X 10.11
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED < 90000)\
|| (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED < 101100)
    NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
    if ([localFilePath length] < 1) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
#endif
    // After iOS 9 we can not actually detects if the cache file exists. This plist file has a somehow
    // complicated structue. Besides, the plist structure is different between iOS 9 and iOS 10.
    // We can only assume that the plist being successfully parsed means the resume data is valid.
    return YES;
}

#pragma mark - getter -

- (AFJSONResponseSerializer *)jsonResponseSerializer {
    if (!_jsonResponseSerializer) {
        _jsonResponseSerializer = [AFJSONResponseSerializer serializer];
        _jsonResponseSerializer.acceptableStatusCodes = _allStatusCodes;
    }
    return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerialzier {
    if (!_xmlParserResponseSerialzier) {
        _xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
        _xmlParserResponseSerialzier.acceptableStatusCodes = _allStatusCodes;
    }
    return _xmlParserResponseSerialzier;
}

#pragma mark - private -
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


@end
