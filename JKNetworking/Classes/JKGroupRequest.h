//
//  JKGroupRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/11/13.
//

#import <Foundation/Foundation.h>
#import "JKBaseRequest.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - - JKBatchRequest - -

@interface JKBatchRequest : NSObject<JKRequestConfigProtocol>

/// the array of the JKBaseRequest
@property (nonatomic, strong, readonly) NSArray<__kindof JKBaseRequest *> *requestArray;

/// the failed request in the chainRequest
@property (nonatomic, strong , readonly, nullable) __kindof JKBaseRequest *failedRequest;

/// the class to handle the request indicator
@property (nonatomic, strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

/// init with the array of the JKBaseRequest or subclass of  JKBaseRequest
/// @param requestArray requestArray
- (instancetype)initWithRequestArray:(NSArray<__kindof JKBaseRequest *> *)requestArray;

/// start the chainRequest
/// @param successBlock the block of success
/// @param failureBlock the block of failure
- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                                    failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock;
- (void)stop;


@end

#pragma mark - - JKChainRequest - - 
@interface JKChainRequest : NSObject<JKRequestConfigProtocol>

/// the array of the JKBaseRequest
@property (nonatomic, strong, readonly) NSMutableArray <__kindof JKBaseRequest *>*requestArray;

/// the failed request in the chainRequest
@property (nonatomic, strong, readonly, nullable) __kindof JKBaseRequest *failedRequest;

/// the class to handle the request indicator
@property (nonatomic, strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;


/// add the request in the chainRequest
/// @param request request
/// @param success the successBlock of the single request
- (void)addRequest:(__kindof JKBaseRequest *)request
           success:(nullable void(^)(__kindof JKBaseRequest *))success;

/// start chainRequest
/// @param successBlock the block of success
/// @param failureBlock the block of failure
- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKChainRequest *chainRequest))successBlock
                                    failure:(nullable void (^)(JKChainRequest *chainRequest))failureBlock;

/// stop the chain request
- (void)stop;

@end

NS_ASSUME_NONNULL_END
