//
//  JKBatchRequest.m
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import "JKBatchRequest.h"
#import "JKNetworkingMacro.h"

@interface JKBatchRequest()

@property (nonatomic, copy, nullable) void (^successCompletionBlock)(JKBatchRequest *);
@property (nonatomic, copy, nullable) void (^failureCompletionBlock)(JKBatchRequest *);
@property (nonatomic, strong, readwrite) NSArray<__kindof JKBaseRequest *> *requestArray;
@property (nonatomic, strong , readwrite, nullable) __kindof JKBaseRequest *failedRequest;
@property (nonatomic, assign) NSInteger finishedCount;

@end

@implementation JKBatchRequest

- (instancetype)initWithRequestArray:(NSArray<__kindof JKBaseRequest *> *)requestArray
{
    self = [super init];
    if (self) {
        self.requestArray = [requestArray copy];
        
        for (__kindof JKBaseRequest *request in self.requestArray) {
            request.isInBatchRequest = YES;
            if (![request isKindOfClass:[JKBatchRequest class]] || [request isKindOfClass:NSClassFromString(@"JKBaseDownloadRequest")]) {
#if DEBUG
                NSLog(@"Error:request must be class of JKBaseRequest,and can not be class of JKBaseDownloadRequest");
#endif
                return nil;
            }
        }
    }
    return self;
}

- (void)clearCompletionBlock
{
    if (self.successCompletionBlock) {
        self.successCompletionBlock = nil;
    }
    
    if (self.failureCompletionBlock) {
        self.failureCompletionBlock = nil;
    }
    self.finishedCount = 0;
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
                });
                if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                    [self.requestAccessory requestDidStop:self];
                }
                [self clearCompletionBlock];
            }
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {
            @strongify(self);
            self.failedRequest = request;
            [self stop];
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStop:)]) {
                [self.requestAccessory requestWillStop:self];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.failureCompletionBlock) {
                    self.failureCompletionBlock(self);
                }
            });
            if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestDidStop:)]) {
                [self.requestAccessory requestDidStop:self];
            }
        }];
    }
}

- (void)stop
{
    for (__kindof JKBaseRequest *request in self.requestArray) {
        [request stop];
    }
    [self clearCompletionBlock];
}

- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                                    failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock
{
    self.successCompletionBlock = successBlock;
    self.failureCompletionBlock = failureBlock;
    [self start];
}

@end
