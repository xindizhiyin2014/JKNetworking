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
/// is a upload request or not
@property (nonatomic, assign) BOOL isUpload;
/// the data need to upload
@property (nonatomic, strong) NSData *uploadData;

@property (nonatomic, assign, readwrite) BOOL isIndependentRequest;

@end

@implementation JKBaseRequest(JKGroupRequest)

@dynamic progressBlock,formDataBlock,isUpload,uploadData,isIndependentRequest;

@end


#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest()

@property (nonatomic, copy, nullable) void (^successCompletionBlock)(JKBatchRequest *);
@property (nonatomic, copy, nullable) void (^failureCompletionBlock)(JKBatchRequest *);
@property (nonatomic, strong, readwrite) NSMutableArray<__kindof JKBaseRequest *> *requestArray;
@property (nonatomic, strong , readwrite, nullable) __kindof JKBaseRequest *failedRequest;
@property (nonatomic, assign) NSInteger finishedCount;

@end

@implementation JKBatchRequest

- (instancetype)initWithRequestArray:(NSArray<__kindof JKBaseRequest *> *)requestArray
{
    self = [super init];
    if (self) {
        _requestArray = [requestArray mutableCopy];
        for (JKBaseRequest *request in requestArray) {
            request.isIndependentRequest = NO;
        }
    }
    return self;
}

- (void)configUploadRequest:(__kindof JKBaseRequest *)request
                       data:(nullable NSData *)data
                   progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
              formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
{
    request.isUpload = YES;
    request.uploadData = data;
    request.progressBlock = uploadProgressBlock;
    request.formDataBlock = formDataBlock;
}
- (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
{
#if DEBUG
    NSAssert([request isKindOfClass:[JKBaseDownloadRequest class]], @"configDownloadRequest only supportJKBaseDownloadRequest");
#endif
        request.progressBlock = downloadProgressBlock;
}

- (void)start
{
    if (self.finishedCount > 0) {
#if DEBUG
        NSLog(@"Error:batch request has already start");
#endif
        return;
    }
    if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
        [self.requestAccessory requestWillStart:self];
    }
    self.failedRequest = nil;
    for (__kindof JKBaseRequest *request in self.requestArray) {
        @weakify(self);
        [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            @strongify(self);
            self.finishedCount++;
            if (self.finishedCount == self.requestArray.count) {
                if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                    [self.requestAccessory requestWillStop:self];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.successCompletionBlock) {
                        self.successCompletionBlock(self);
                    }
                     [self clearRequests];
                     [self clearCompletionBlock];
                     self.finishedCount = 0;
                    [[JKNetworkAgent sharedAgent] removeBatchRequest:self];

                });
                if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                    [self.requestAccessory requestDidStop:self];
                }
            }
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {
            @strongify(self);
            [self stopRequests];
            self.failedRequest = request;
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [self.requestAccessory requestWillStop:self];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.failureCompletionBlock) {
                    self.failureCompletionBlock(self);
                }
               [self clearRequests];
               [self clearCompletionBlock];
               self.finishedCount = 0;
               [[JKNetworkAgent sharedAgent] removeBatchRequest:self];
            });
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [self.requestAccessory requestDidStop:self];
            }
        }];
    }
}

- (void)stop
{
    [self stopRequests];
    [self clearRequests];
    [self clearCompletionBlock];
    self.finishedCount = 0;
    [[JKNetworkAgent sharedAgent] removeBatchRequest:self];
}

- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                                    failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock
{
    self.successCompletionBlock = successBlock;
    self.failureCompletionBlock = failureBlock;
    [[JKNetworkAgent sharedAgent] addBatchRequest:self];
}

- (void)stopRequests
{
  for (__kindof JKBaseRequest *request in self.requestArray) {
        [request stop];
    }
}

- (void)clearRequests
{
    [self.requestArray removeAllObjects];
}

- (void)clearCompletionBlock
{
    if (self.successCompletionBlock) {
        self.successCompletionBlock = nil;
    }
    
    if (self.failureCompletionBlock) {
        self.failureCompletionBlock = nil;
    }
}


@end

#pragma mark - - JKChainRequest - - 

@interface JKChainRequest()

@property (nonatomic, strong, nonnull) NSMutableArray <__kindof JKBaseRequest *>*requestArray;

@property (nonatomic, copy, nullable) void(^successBlock)(JKChainRequest *chainRequest);

@property (nonatomic, copy, nullable) void(^failureBlock)(JKChainRequest *chainRequest);

@property (nonatomic, strong, readwrite, nullable) __kindof JKBaseRequest *failedRequest;

@property (nonatomic ,assign) NSUInteger nextRequestIndex;
/// the single request success block dictionary
@property (nonatomic, strong, nonnull) NSMutableDictionary *successBlocksDic;

@end

@implementation JKChainRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _nextRequestIndex = 0;
        _requestArray = [NSMutableArray new];
        _successBlocksDic = [NSMutableDictionary new];
    }
    return self;
}

- (void)addRequest:(__kindof JKBaseRequest *)request
           success:(nullable void(^)(__kindof JKBaseRequest *))success
{
    [self.requestArray addObject:request];
    request.isIndependentRequest = NO;
    NSString *key = [NSString stringWithFormat:@"%p",request];
    [self.successBlocksDic setValue:success forKey:key];
}

- (void)configUploadRequest:(__kindof JKBaseRequest *)request
                       data:(nullable NSData *)data
                   progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
              formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
{
    request.isUpload = YES;
    request.uploadData = data;
    request.progressBlock = uploadProgressBlock;
    request.formDataBlock = formDataBlock;
}
- (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
{
    #if DEBUG
        NSAssert([request isKindOfClass:[JKBaseDownloadRequest class]], @"configDownloadRequest only supportJKBaseDownloadRequest");
    #endif
        request.progressBlock = downloadProgressBlock;
}

- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                                    failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    [[JKNetworkAgent sharedAgent] addChainRequest:self];

}

- (void)start
{
    if (self.nextRequestIndex >0) {
#if DEBUG
        NSLog(@"Error! chain request has already started");
#endif
        return;
    }
    self.failedRequest = nil;
    if ([self.requestArray count] > 0) {
        if (self.requestAccessory  && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
            [self.requestAccessory requestWillStart:self];
        }
        [self startNextRequest];
    }
}

- (void)stop
{
    [self stopRequests];
    [self clearRequests];
    [self clearBlock];
    self.nextRequestIndex = 0;
    [[JKNetworkAgent sharedAgent] removeChainRequest:self];
}

- (BOOL)startNextRequest
{
    if (self.nextRequestIndex < [self.requestArray count]) {
        JKBaseRequest *request = self.requestArray[self.nextRequestIndex];
        self.nextRequestIndex++;
        [request clearCompletionBlock];
        [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
            NSString *key = [NSString stringWithFormat:@"%p",request];
            void(^successBlock)(__kindof JKBaseRequest *) = self.successBlocksDic[key];
            if (successBlock) {
                successBlock(request);
            }
            BOOL status = [self startNextRequest];
            if (!status) {
                if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                    [self.requestAccessory requestWillStop:self];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.successBlock) {
                        self.successBlock(self);
                    }
                    [self clearRequests];
                    [self clearBlock];
                    self.nextRequestIndex = 0;
                    [[JKNetworkAgent sharedAgent] removeChainRequest:self];
                });
                if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                    [self.requestAccessory requestDidStop:self];
                }

            }
        } failure:^(__kindof JKBaseRequest * request) {
            [self stopRequests];
            self.failedRequest = request;
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [self.requestAccessory requestWillStop:self];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.failureBlock) {
                    self.failureBlock(self);
                }
                [self clearRequests];
                [self clearBlock];
                self.nextRequestIndex = 0;
                [[JKNetworkAgent sharedAgent] removeChainRequest:self];
            });
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [self.requestAccessory requestDidStop:self];
            }
        }];
        return YES;
    }
    return NO;
}

- (void)stopRequests
{
    for (JKBaseRequest *request in self.requestArray) {
      [request stop];
    }
}

- (void)clearRequests
{
    [self.requestArray removeAllObjects];
    [self.successBlocksDic removeAllObjects];
}

- (void)clearBlock
{
    if (self.successBlock) {
        self.successBlock = nil;
    }
    
    if (self.failureBlock) {
        self.failureBlock = nil;
    }

}

@end


