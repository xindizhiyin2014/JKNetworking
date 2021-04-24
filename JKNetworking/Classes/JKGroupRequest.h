//
//  JKGroupRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/11/13.
//

#import <Foundation/Foundation.h>
#import "JKBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface JKGroupRequest : NSObject<JKRequestInGroupProtocol>
/// the array of the JKBaseRequest
@property (nonatomic, strong, readonly) NSMutableArray<__kindof NSObject<JKRequestInGroupProtocol> *> *requestArray;
/// the class to handle the request indicator
@property (nonatomic, strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;

/// the failed requests
@property (nonatomic, strong, readonly, nullable) NSMutableArray<__kindof NSObject<JKRequestInGroupProtocol> *> *failedRequests;

/// the status of the groupRequest is complete inadvance
@property (nonatomic, assign, readonly) BOOL inAdvanceCompleted;

/// add child request,make sure request conform protocol JKRequestProtocol
/// @param request request
- (void)addRequest:(__kindof NSObject<JKRequestInGroupProtocol> *)request;

/// add child requests,make sure the request in requestArray conform protocol JKRequestProtocol
/// @param requestArray requestArray
- (void)addRequestsWithArray:(NSArray<__kindof NSObject<JKRequestInGroupProtocol> *>*)requestArray;

- (void)start;

- (void)stop;

/// inadvance self with the result
/// @param isSuccess the result
- (void)inAdvanceCompleteWithResult:(BOOL)isSuccess;

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

+ (void)configChildGroupRequest:(__kindof JKGroupRequest *)request
                        success:(void(^)(__kindof JKGroupRequest *request))successBlock
                        failure:(void(^)(__kindof JKGroupRequest *request))failureBlock;

@end

#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest : JKGroupRequest

/*
 config the require success requests
 if not config,or the config requests has no elment, only one request success, the batchRequest success block will be called;only all requests in batchRequest failed,the batchRequest fail block will be called.
 if config the requests,only the requests in the config requests all success,then the batchRequest success block will be called,if one of request in config request failed,the batchRequest fail block will be called.
 this method should invoke after you add the request in the batchRequest.
 */
- (void)configRequireSuccessRequests:(nullable NSArray <__kindof NSObject<JKRequestInGroupProtocol> *> *)requests;

- (void)startWithCompletionSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                           failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock;

@end

#pragma mark - - JKChainRequest - -
@interface JKChainRequest : JKGroupRequest

- (void)startWithCompletionSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                           failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock;

@end

NS_ASSUME_NONNULL_END
