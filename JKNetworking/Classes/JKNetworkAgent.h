//
//  JKNetworkAgent.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JKBaseRequest;
@class JKBatchRequest;
@class JKChainRequest;

@interface JKNetworkAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedAgent;

- (void)addRequest:(__kindof JKBaseRequest *)request;

- (void)cancelRequest:(__kindof JKBaseRequest *)request;

- (void)cancelAllRequests;

- (NSString *)buildRequestUrl:(__kindof JKBaseRequest *)request;

- (void)addBatchRequest:(__kindof JKBatchRequest *)request;

- (void)removeBatchRequest:(__kindof JKBatchRequest *)request;

- (void)addChainRequest:(__kindof JKChainRequest *)request;

- (void)removeChainRequest:(__kindof JKChainRequest *)request;

/// add the priority request,all the request will start until the prority request is finished
/// @param request the request can ba a JKBaseRequest/JKBatchRequest/JKChainRequest
- (void)addPriorityFirstRequest:(id)request;

@end
NS_ASSUME_NONNULL_END
