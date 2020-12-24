//
//  JKGroupRequest.m
//  JKNetworking
//
//  Created by JackLee on 2019/11/13.
//

#import "JKGroupRequest.h"

#import "JKNetworkingMacro.h"
#import "JKNetworkAgent.h"

@interface JKBaseRequest(JKGroupRequest)

/// the download/upload request progress block
@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);
/// when upload data cofig the formData
@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);
/// is a default/download/upload request
@property (nonatomic, assign) JKRequestType requestType;
/// the data need to upload
@property (nonatomic, strong) NSData *uploadData;
/// the request is independent request or not
@property (nonatomic, assign, readwrite) BOOL isIndependentRequest;
/// the request success block
@property (nonatomic, copy, nullable) void(^groupSuccessBlock)(__kindof JKBaseRequest *request);
/// the request failure block
@property (nonatomic, copy, nullable) void(^groupFailureBlock)(__kindof JKBaseRequest *request);
/// only in chainRequest,can use this property
@property (nonatomic, assign) BOOL manualStartNextRequest;


@end

@implementation JKBaseRequest(JKGroupRequest)

@dynamic progressBlock;
@dynamic formDataBlock;
@dynamic requestType;
@dynamic uploadData;
@dynamic isIndependentRequest;
@dynamic groupSuccessBlock;
@dynamic groupFailureBlock;
@dynamic manualStartNextRequest;

@end

@interface JKGroupRequest()

/// the array of the JKBaseRequest
@property (nonatomic, strong, readwrite) NSMutableArray<__kindof JKBaseRequest *> *requestArray;
/// the block of success
@property (nonatomic, copy, nullable) void (^successBlock)(__kindof JKGroupRequest *request);
/// the block of failure
@property (nonatomic, copy, nullable) void (^failureBlock)(__kindof JKGroupRequest *request);
/// the count of finished requests
@property (nonatomic, assign) NSInteger finishedCount;
/// the status of the JKGroupRequest is executing or not
@property (nonatomic, assign) BOOL executing;

/// the failed requests
@property (nonatomic, strong, readwrite, nullable) NSMutableArray<__kindof JKBaseRequest *> *failedRequests;



@end

@implementation JKGroupRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestArray = [NSMutableArray new];
        _finishedCount = 0;
    }
    return self;
}

- (void)addRequest:(__kindof JKBaseRequest *)request
{
    if (![request isKindOfClass:[JKBaseRequest class]]) {
#if DEBUG
        NSAssert(NO, @"makesure [request isKindOfClass:[JKBaseRequest class]] be YES");
#endif
        return;
    }
    if ([self.requestArray containsObject:request]) {
#if DEBUG
        NSAssert(NO, @"request was added");
#endif
        return;
    }
    request.isIndependentRequest = NO;
    [self.requestArray addObject:request];
}

- (void)addRequestsWithArray:(NSArray<__kindof JKBaseRequest *> *)requestArray
{
    NSMutableSet *tmpSet = [NSMutableSet setWithArray:requestArray];
    if (tmpSet.count != requestArray.count) {
#if DEBUG
        NSAssert(NO, @"requestArray has duplicated requests");
#endif
        return;
    }
    NSMutableSet *requestSet = [NSMutableSet setWithArray:self.requestArray];
    BOOL hasCommonRequest = [requestSet intersectsSet:tmpSet];
    if (hasCommonRequest) {
#if DEBUG
        NSAssert(NO, @"requestArray has common request with the added requests");
#endif
        return;
    }
    for (JKBaseRequest *request in requestArray) {
        if (![request isKindOfClass:[JKBaseRequest class]]) {
#if DEBUG
            NSAssert(NO, @"makesure [request isKindOfClass:[JKBaseRequest class]] be YES");
#endif
            return;
        }
        request.isIndependentRequest = NO;
    }
    [self.requestArray addObjectsFromArray:requestArray];
}

- (void)start
{
    
}

- (void)stop
{
    
}

+ (void)configNormalRequest:(__kindof JKBaseRequest *)request
                    success:(void(^)(__kindof JKBaseRequest *request))successBlock
                    failure:(void(^)(__kindof JKBaseRequest *request))failureBlock;
{
    NSAssert(request.requestType == JKRequestTypeDefault, @"make sure request.requestType == JKRequestTypeDefault be YES");
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configUploadDataRequest:(__kindof JKBaseUploadRequest *)request
                       progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
                  formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                        success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                        failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    NSAssert(request.requestType == JKRequestTypeUpload, @"make sure request.requestType == JKRequestTypeUpload be YES");
    if (!request.uploadData) {
#if DEBUG
        NSAssert(NO, @"request.uploadData can't be nil");
#endif
        return;
    }
    request.progressBlock = uploadProgressBlock;
    request.formDataBlock = formDataBlock;
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configUploadFileRequest:(__kindof JKBaseUploadRequest *)request
                       progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
                        success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                        failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    NSAssert(request.requestType == JKRequestTypeUpload, @"make sure request.requestType == JKRequestTypeUpload be YES");
    if (!request.uploadFilePath) {
#if DEBUG
        NSAssert(request.uploadFilePath, @"request.uploadFilePath can't nil");
#endif
        return;
    }
    request.progressBlock = uploadProgressBlock;
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                      success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                      failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    NSAssert(request.requestType == JKRequestTypeDownload, @"make sure request.requestType == JKRequestTypeDownload be YES");
    request.progressBlock = downloadProgressBlock;
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

- (void)clearCompletionBlock
{
    if (self.successBlock) {
        self.successBlock = nil;
    }
    if (self.failureBlock) {
        self.failureBlock = nil;
    }
}

@end


#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest()

@property (nonatomic, strong, nullable) NSMutableArray<__kindof JKBaseRequest *> *requireSuccessRequests;


@end

@implementation JKBatchRequest

- (void)start
{
    if (self.requestArray.count == 0) {
#if DEBUG
        NSAssert(NO, @"please makesure self.requestArray.count > 0");
#endif
        return;
    }
    if (self.executing) {
        return;
    }
    self.executing = YES;
    if (self.requestAccessory
        && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
        [self.requestAccessory requestWillStart:self];
    }
    for (__kindof JKBaseRequest *request in self.requestArray) {
        @weakify(self);
        [request startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            @strongify(self);
            self.finishedCount++;
            if (request.groupSuccessBlock) {
                request.groupSuccessBlock(request);
            }
            if (self.finishedCount == self.requestArray.count) {
                //the last request success, the batchRequest should call success block
                [self finishAllRequestsWithSuccessBlock];
            }
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {
            @strongify(self);
            if (!self.failedRequests) {
                self.failedRequests = [NSMutableArray new];
            }
            if ([self.requireSuccessRequests containsObject:request]) {
                [self.failedRequests addObject:request];
                if (request.groupFailureBlock) {
                    request.groupFailureBlock(request);
                }
                for (__kindof JKBaseRequest *tmpRequest in [self.requestArray copy]) {
                    [tmpRequest stop];
                }
                [self finishAllRequestsWithFailureBlock];
            } else {
                self.finishedCount++;
                [self.failedRequests addObject:request];
                if (request.groupFailureBlock) {
                    request.groupFailureBlock(request);
                }
                if (self.finishedCount == self.requestArray.count) {
                    if (self.failedRequests.count != self.requestArray.count) {
                        // not all requests failed ,the batchRequest should call success block
                        [self finishAllRequestsWithSuccessBlock];
                    }else {
                        // all requests failed,the batchRequests should call fail block
                        [self finishAllRequestsWithFailureBlock];
                    }
                }
            }
        }];
    }
}

- (void)finishAllRequestsWithSuccessBlock
{
    if (self.requestAccessory
        && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
        [self.requestAccessory requestWillStop:self];
    }
    if (self.successBlock) {
        self.successBlock(self);
    }
    if (self.requestAccessory
        && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
        [self.requestAccessory requestDidStop:self];
    }
    [self stop];
}

- (void)finishAllRequestsWithFailureBlock
{
    if (self.requestAccessory
        && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
        [self.requestAccessory requestWillStop:self];
    }
    if (self.failureBlock) {
        self.failureBlock(self);
    }
    if (self.requestAccessory
        && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
        [self.requestAccessory requestDidStop:self];
    }
    [self stop];
}

- (void)stop
{
    [self clearCompletionBlock];
    self.finishedCount = 0;
    self.failedRequests = nil;
    [[JKNetworkAgent sharedAgent] removeBatchRequest:self];
    self.executing = NO;
}

- (void)configRequireSuccessRequests:(nullable NSArray <__kindof JKBaseRequest *> *)requests
{

    for (__kindof JKBaseRequest *request in requests) {
        if (![request isKindOfClass:[JKBaseRequest class]]) {
#if DEBUG
            NSAssert(NO, @"please make sure [request isKindOfClass:[JKBaseRequest class]] be YES");
#endif
            return;
        }
    }
    self.requireSuccessRequests = [NSMutableArray arrayWithArray:requests];
}

- (void)startWithCompletionSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                           failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    [[JKNetworkAgent sharedAgent] addBatchRequest:self];
}

@end

#pragma mark - - JKChainRequest - -

@interface JKChainRequest()

@property (nonatomic, strong, nullable) __kindof JKBaseRequest *lastRequest;

@end

@implementation JKChainRequest

- (void)start
{
    if (self.requestArray.count == 0) {
#if DEBUG
        NSAssert(NO, @"please makesure self.requestArray.count > 0");
#endif
        return;
    }
    if (self.executing) {
        return;
    }
    self.executing = YES;
    if ([self.requestArray count] > 0) {
        if (self.requestAccessory  && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
            [self.requestAccessory requestWillStart:self];
        }
        [self startNextRequest];
    }
}

- (void)stop
{
    [self clearCompletionBlock];
    self.finishedCount = 0;
    self.failedRequests = nil;
    [[JKNetworkAgent sharedAgent] removeChainRequest:self];
    self.executing = NO;
}

- (void)configRequest:(__kindof JKBaseRequest *)request manualStartNextRequest:(BOOL)manualStartNextRequest
{
    if (self.executing) {
#if DEBUG
        NSAssert(NO, @"please config before the chainRequest start!");
#endif
        return;
    }
    request.manualStartNextRequest = manualStartNextRequest;
}

- (void)startWithCompletionSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                           failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    [[JKNetworkAgent sharedAgent] addChainRequest:self];
}

- (void)manualStartNextRequest
{
    if (self.lastRequest.error) {
#if DEBUG
        NSAssert(NO, @"lastRequest has error,can't startNextRequest!");
#endif
        return;
    }
    if (self.lastRequest.manualStartNextRequest) {
        [self startNextRequest];
    } else {
#if DEBUG
        NSAssert(NO, @"can't invoke manualStartNextRequest now,please check");
#endif
    }
}

- (void)startNextRequest
{
    if (self.finishedCount < [self.requestArray count]) {
        JKBaseRequest *request = self.requestArray[self.finishedCount];
        self.finishedCount++;
        [request startWithCompletionSuccess:^(__kindof JKBaseRequest * request) {
            self.lastRequest = request;
            BOOL canStartNextRequest = self.finishedCount < [self.requestArray count];
            if (request.groupSuccessBlock) {
                request.groupSuccessBlock(request);
            }
            if (canStartNextRequest) {
                if (!request.manualStartNextRequest) {
                    [self startNextRequest];
                }
            } else {
                if (!canStartNextRequest) {
                    if (self.requestAccessory
                        && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                        [self.requestAccessory requestWillStop:self];
                    }
                    if (self.successBlock) {
                        self.successBlock(self);
                    }
                    if (self.requestAccessory
                        && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                        [self.requestAccessory requestDidStop:self];
                    }
                    [self stop];
                }
            }
            
            
        } failure:^(__kindof JKBaseRequest * request) {
            if (!self.failedRequests) {
                self.failedRequests = [NSMutableArray new];
            }
            [self.failedRequests addObject:request];
            self.lastRequest = request;
            if (request.groupFailureBlock) {
                request.groupFailureBlock(request);
            }
            for (__kindof JKBaseRequest *tmpRequest in [self.requestArray copy]) {
                [tmpRequest stop];
            }
            if (self.requestAccessory
                && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [self.requestAccessory requestWillStop:self];
            }
            if (self.failureBlock) {
                self.failureBlock(self);
            }
            if (self.requestAccessory
                && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [self.requestAccessory requestDidStop:self];
            }
            [self stop];
        }];
    }
}

@end


