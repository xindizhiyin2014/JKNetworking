//
//  JKNetworkAgent.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JKBaseRequest;

@interface JKNetworkAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedAgent;

- (void)addRequest:(__kindof JKBaseRequest *)request;

- (void)cancelRequest:(__kindof JKBaseRequest *)request;

- (void)cancelAllRequests;

- (NSString *)buildRequestUrl:(__kindof JKBaseRequest *)request;

@end
NS_ASSUME_NONNULL_END
