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
/// the request success block
@property (nonatomic, copy, nullable) void(^groupSuccessBlock)(__kindof JKBaseRequest *request);
/// the request failure block
@property (nonatomic, copy, nullable) void(^groupFailureBlock)(__kindof JKBaseRequest *request);


@end

@implementation JKBaseRequest(JKGroupRequest)

@dynamic progressBlock;
@dynamic formDataBlock;
@dynamic requestType;
@dynamic uploadData;
@dynamic groupSuccessBlock;
@dynamic groupFailureBlock;

@end

@interface JKGroupRequest()

/// the array of the JKBaseRequest
@property (nonatomic, strong, readwrite) NSMutableArray<__kindof NSObject<JKRequestInGroupProtocol> *> *requestArray;
/// the block of success
@property (nonatomic, copy, nullable) void (^successBlock)(__kindof JKGroupRequest *request);
/// the block of failure
@property (nonatomic, copy, nullable) void (^failureBlock)(__kindof JKGroupRequest *request);
/// the count of finished requests
@property (nonatomic, assign) NSInteger finishedCount;
/// the status of the JKGroupRequest is executing or not
@property (nonatomic, assign) BOOL executing;
/// the failed requests
@property (nonatomic, strong, readwrite, nullable) NSMutableArray<__kindof NSObject<JKRequestInGroupProtocol> *> *failedRequests;
/// the status of the groupRequest is complete inadvance
@property (nonatomic, assign, readwrite) BOOL inAdvanceCompleted;

@end

@implementation JKGroupRequest
@synthesize isIndependentRequest;
@synthesize groupRequest;
@synthesize groupSuccessBlock;
@synthesize groupFailureBlock;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestArray = [NSMutableArray new];
        _finishedCount = 0;
    }
    return self;
}

- (void)addRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request
{
    if (![request conformsToProtocol:@protocol(JKRequestInGroupProtocol)]) {
#if DEBUG
        NSAssert(NO, @"makesure request is conforms to protocol JKRequestInGroupProtocol");
#endif
        return;
    }
    if ([self.requestArray containsObject:request]) {
#if DEBUG
        NSAssert(NO, @"request was added");
#endif
        return;
    }
    request.groupRequest = self;
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
    for (__kindof NSObject<JKRequestInGroupProtocol> *request  in requestArray) {
        [self addRequest:request];
    }
}

- (void)start
{
    
}

- (void)stop
{
    
}
- (void)inAdvanceCompleteWithResult:(BOOL)isSuccess
{
    
}

#pragma mark - - JKRequestInGroupProtocol - -
- (BOOL)isIndependentRequest
{
    return self.groupRequest?NO:YES;
}

- (void)inAdvanceCompleteGroupRequestWithResult:(BOOL)isSuccess
{
    if (self.groupRequest) {
        [self.groupRequest inAdvanceCompleteWithResult:isSuccess];
    }else {
#if DEBUG
        NSAssert(NO, @"self.groupRequest is nil");
#endif
    }
}


+ (void)configNormalRequest:(__kindof JKBaseRequest *)request
                    success:(void(^)(__kindof JKBaseRequest *request))successBlock
                    failure:(void(^)(__kindof JKBaseRequest *request))failureBlock;
{
    NSAssert(request.requestType == JKRequestTypeDefault, @"make sure request.requestType == JKRequestTypeDefault be YES");
    if (request.groupSuccessBlock
        || request.groupFailureBlock) {
#if DEBUG
    NSAssert(!request.groupSuccessBlock, @"can't config the successBlock");
    NSAssert(!request.groupFailureBlock, @"can't config the failureBlock");
#else
        return;
#endif
    }
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configUploadRequest:(__kindof JKBaseUploadRequest *)request
                   progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
              formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                    success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                    failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    NSAssert(request.requestType == JKRequestTypeUpload, @"make sure request.requestType == JKRequestTypeUpload be YES");
    if (request.progressBlock
        || request.formDataBlock
        || request.groupSuccessBlock
        || request.groupFailureBlock) {
#if DEBUG
    NSAssert(!request.progressBlock, @"can't config the uploadProgressBlock");
    NSAssert(!request.formDataBlock, @"can't config the formDataBlock");
    NSAssert(!request.groupSuccessBlock, @"can't config the successBlock");
    NSAssert(!request.groupFailureBlock, @"can't config the failureBlock");
#else
        return;
#endif
    }
    request.progressBlock = uploadProgressBlock;
    request.formDataBlock = formDataBlock;
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                      success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                      failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    NSAssert(request.requestType == JKRequestTypeDownload, @"make sure request.requestType == JKRequestTypeDownload be YES");
    if (request.progressBlock
        || request.groupSuccessBlock
        || request.groupFailureBlock) {
#if DEBUG
    NSAssert(!request.progressBlock, @"can't config the downloadProgressBlock");
    NSAssert(!request.groupSuccessBlock, @"can't config the successBlock");
    NSAssert(!request.groupFailureBlock, @"can't config the failureBlock");
#else
        return;
#endif
    }
    request.progressBlock = downloadProgressBlock;
    request.groupSuccessBlock = successBlock;
    request.groupFailureBlock = failureBlock;
}

+ (void)configChildGroupRequest:(__kindof JKGroupRequest *)request
                        success:(void(^)(__kindof JKGroupRequest *request))successBlock
                        failure:(void(^)(__kindof JKGroupRequest *request))failureBlock
{
    NSAssert([request isKindOfClass:[JKGroupRequest class]], @"make sure [request isKindOfClass:[JKGroupRequest class]] be YES");
    if (request.groupSuccessBlock
        || request.groupFailureBlock) {
#if DEBUG
    NSAssert(!request.groupSuccessBlock, @"can't config the successBlock");
    NSAssert(!request.groupFailureBlock, @"can't config the failureBlock");
#else
        return;
#endif
    }
    request.groupSuccessBlock = ^(NSObject<JKRequestInGroupProtocol> * _Nonnull request) {
        if (successBlock) {
            successBlock((JKGroupRequest *)request);
        }
    };
    request.groupFailureBlock = ^(NSObject<JKRequestInGroupProtocol> * _Nonnull request) {
        if (failureBlock) {
            failureBlock((JKGroupRequest *)request);
        }
    };
    
}


- (void)handleAccessoryWithBlock:(void(^)(void))block
{
    if (self.isIndependentRequest) {
        if (self.requestAccessory
            && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
            [self.requestAccessory requestWillStop:self];
        }
    }
    if (block) {
        block();
    }
    if (self.isIndependentRequest) {
        if (self.requestAccessory
            && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
            [self.requestAccessory requestDidStop:self];
        }
    }
}

- (void)clearCompletionBlock
{
    if (self.successBlock) {
        self.successBlock = nil;
    }
    if (self.failureBlock) {
        self.failureBlock = nil;
    }
    if (self.groupSuccessBlock) {
        self.groupSuccessBlock = nil;
    }
    if (self.groupFailureBlock) {
        self.groupFailureBlock = nil;
    }
}

@end


#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest()

@property (nonatomic, strong, nullable) NSMutableArray<__kindof NSObject<JKRequestInGroupProtocol> *> *requireSuccessRequests;

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
    if (self.isIndependentRequest) {
        if (self.requestAccessory
            && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
            [self.requestAccessory requestWillStart:self];
        }
    }
    for (__kindof NSObject<JKRequestInGroupProtocol> *request in self.requestArray) {
        
        if ([request isKindOfClass:[JKBaseUploadRequest class]]) {
            JKBaseUploadRequest *uploadRequest = (JKBaseUploadRequest *)request;
            @weakify(self);
            [uploadRequest uploadWithProgress:uploadRequest.progressBlock formDataBlock:uploadRequest.formDataBlock success:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else if ([request isKindOfClass:[JKBaseDownloadRequest class]]) {
            JKBaseDownloadRequest *downloadRequest = (JKBaseDownloadRequest *)request;
            @weakify(self);
            [downloadRequest downloadWithProgress:downloadRequest.progressBlock success:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else  if ([request isKindOfClass:[JKBaseRequest class]]) {
            @weakify(self);
            JKBaseRequest *baseRequest = (JKBaseRequest *)request;
            [baseRequest startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else if ([request isKindOfClass:[JKBatchRequest class]]) {
            JKBatchRequest *batchRequest = (JKBatchRequest *)request;
            @weakify(self);
            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else if ([request isKindOfClass:[JKChainRequest class]]) {
            JKChainRequest *chainRequest = (JKChainRequest *)request;
            @weakify(self);
            [chainRequest startWithCompletionSuccess:^(JKChainRequest * _Nonnull chainRequest) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(JKChainRequest * _Nonnull chainRequest) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        }
        
    }
}

- (void)handleSuccessOfRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request
{
    self.finishedCount++;
    if (request.groupSuccessBlock) {
        request.groupSuccessBlock(request);
    }
    
    if (self.finishedCount == self.requestArray.count) {
        //the last request success, the batchRequest should call success block
        [self finishAllRequestsWithSuccessBlock];
    }
}

- (void)handleFailureOfRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request
{
    if (!self.failedRequests) {
        self.failedRequests = [NSMutableArray new];
    }
    if ([self.requireSuccessRequests containsObject:request]) {
        [self.failedRequests addObject:request];
        if (request.groupFailureBlock) {
            request.groupFailureBlock(request);
        }
        for (__kindof NSObject<JKRequestInGroupProtocol> *tmpRequest in [self.requestArray copy]) {
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
}

- (void)finishAllRequestsWithSuccessBlock
{
    [self handleAccessoryWithBlock:^{
        if (self.successBlock) {
            self.successBlock(self);
        }
    }];
    [self stop];
}

- (void)finishAllRequestsWithFailureBlock
{
    [self handleAccessoryWithBlock:^{
        if (self.failureBlock) {
            self.failureBlock(self);
        }
    }];
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

- (void)inAdvanceCompleteWithResult:(BOOL)isSuccess
{
#if DEBUG
    NSAssert(NO, @"not support now");
#endif
}

- (void)configRequireSuccessRequests:(nullable NSArray <__kindof NSObject<JKRequestInGroupProtocol> *> *)requests
{
 
    for (__kindof JKBaseRequest *request in requests) {
        if (![request conformsToProtocol:@protocol(JKRequestInGroupProtocol)]) {
#if DEBUG
            NSAssert(NO, @"please make sure request conforms protocol JKRequestInGroupProtocol");
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

@property (nonatomic, strong, nullable) __kindof NSObject<JKRequestInGroupProtocol> *lastRequest;
@property (nonatomic, assign, readonly) BOOL canStartNextRequest;

@end

@implementation JKChainRequest

- (void)start
{
    self.inAdvanceCompleted = NO;
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
    self.lastRequest = nil;
    [[JKNetworkAgent sharedAgent] removeChainRequest:self];
    self.executing = NO;
}

- (void)startWithCompletionSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                           failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    [[JKNetworkAgent sharedAgent] addChainRequest:self];
}


- (void)inAdvanceCompleteWithResult:(BOOL)isSuccess
{
    self.inAdvanceCompleted = YES;
    if (isSuccess) {
        [self handleAccessoryWithBlock:^{
            if (self.successBlock) {
                self.successBlock(self);
            }
        }];
    } else {
        [self handleAccessoryWithBlock:^{
            if (self.failureBlock) {
                self.failureBlock(self);
            }
        }];
    }
    [self stop];
}

- (void)startNextRequest
{
    if (self.canStartNextRequest) {
        __kindof NSObject<JKRequestInGroupProtocol> *request = self.requestArray[self.finishedCount];
        self.finishedCount++;
        if ([request isKindOfClass:[JKBaseUploadRequest class]]) {
            JKBaseUploadRequest *uploadRequest = (JKBaseUploadRequest *)request;
            @weakify(self);
            [uploadRequest uploadWithProgress:uploadRequest.progressBlock formDataBlock:uploadRequest.formDataBlock success:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else if ([request isKindOfClass:[JKBaseDownloadRequest class]]) {
            JKBaseDownloadRequest *downloadRequest = (JKBaseDownloadRequest *)request;
            @weakify(self);
            [downloadRequest downloadWithProgress:downloadRequest.progressBlock success:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        } else {
            @weakify(self);
            [request startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleSuccessOfRequest:request];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                @strongify(self);
                [self handleFailureOfRequest:request];
            }];
        }
    }
}

- (void)handleSuccessOfRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request
{
    self.lastRequest = request;
    if (request.groupSuccessBlock) {
        request.groupSuccessBlock(request);
        if (self.inAdvanceCompleted) {
            return;
        }
    }
    if (self.canStartNextRequest) {
        [self startNextRequest];
    } else {
        [self handleAccessoryWithBlock:^{
            if (self.successBlock) {
                self.successBlock(self);
            }
        }];
        [self stop];
    }
}

- (void)handleFailureOfRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request
{
    if (!self.failedRequests) {
        self.failedRequests = [NSMutableArray new];
    }
    [self.failedRequests addObject:request];
    self.lastRequest = request;
    if (request.groupFailureBlock) {
        request.groupFailureBlock(request);
        if (self.inAdvanceCompleted) {
            return;
        }
    }
    for (__kindof NSObject<JKRequestInGroupProtocol> *tmpRequest in [self.requestArray copy]) {
        [tmpRequest stop];
    }
    [self handleAccessoryWithBlock:^{
        if (self.failureBlock) {
            self.failureBlock(self);
        }
    }];
    [self stop];
}

#pragma mark - - getter - -
- (BOOL)canStartNextRequest
{
    return self.finishedCount < [self.requestArray count] && !self.inAdvanceCompleted;
}

@end


