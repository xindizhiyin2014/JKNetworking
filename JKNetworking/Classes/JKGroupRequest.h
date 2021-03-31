//
//  JKGroupRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/11/13.
//

#import <Foundation/Foundation.h>
#import "JKBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface JKGroupRequest : NSObject
/// the array of the JKBaseRequest
@property (nonatomic, strong, readonly) NSMutableArray<__kindof JKBaseRequest *> *requestArray;
/// the class to handle the request indicator
@property (nonatomic, strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;

/// the failed requests
@property (nonatomic, strong, readonly, nullable) NSMutableArray<__kindof JKBaseRequest *> *failedRequests;

- (void)addRequest:(__kindof JKBaseRequest *)request;

- (void)addRequestsWithArray:(NSArray<__kindof JKBaseRequest *> *)requestArray;

- (void)start;

- (void)stop;

+ (void)configNormalRequest:(__kindof JKBaseRequest *)request
                    success:(void(^)(__kindof JKBaseRequest *request))successBlock
                    failure:(void(^)(__kindof JKBaseRequest *request))failureBlock;

+ (void)configUploadRequest:(__kindof JKBaseUploadRequest *)request
                   progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
              formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                    success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                    failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;

+ (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                      success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                      failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;

@end

#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest : JKGroupRequest

/*
 config the require success requests
 if not config,or the config requests has no elment, only one request success, the batchRequest success block will be called;only all requests in batchRequest failed,the batchRequest fail block will be called.
 if config the requests,only the requests in the config requests all success,then the batchRequest success block will be called,if one of request in config request failed,the batchRequest fail block will be called.
 this method should invoke after you add the request in the batchRequest.
 */
- (void)configRequireSuccessRequests:(nullable NSArray <__kindof JKBaseRequest *> *)requests;

- (void)startWithCompletionSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                           failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock;

@end

#pragma mark - - JKChainRequest - -
@interface JKChainRequest : JKGroupRequest

/// config the request is manual start the next request,deafult is NO,must config before the chainRequest start.
- (void)configRequest:(__kindof JKBaseRequest *)request manualStartNextRequest:(BOOL)manualStartNextRequest;

- (void)startWithCompletionSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                           failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock;
/// manual start the next request
- (void)manualStartNextRequest;
/// complete the chainRequest in advance,even if the ChainRequest has requests not complete.this function can only call when a manual request success
- (void)inAdvanceCompleteChainRequest;

@end

NS_ASSUME_NONNULL_END
