//
//  JKBatchRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>
#import "JKBaseRequest.h"
NS_ASSUME_NONNULL_BEGIN

@interface JKBatchRequest : NSObject

@property (nonatomic, strong, readonly) NSArray<__kindof JKBaseRequest *> *requestArray;

@property (nonatomic, strong , readonly, nullable) __kindof JKBaseRequest *failedRequest;

@property (nonatomic,strong,nullable) Class<JKRequestAccessoryProtocol> requestAccessory;      ///< 网络请求状态指示器处理类

- (instancetype)initWithRequestArray:(NSArray<__kindof JKBaseRequest *> *)requestArray;

- (void)startWithCompletionBlockWithSuccess:(nullable void (^)(JKBatchRequest *batchRequest))successBlock
                                    failure:(nullable void (^)(JKBatchRequest *batchRequest))failureBlock;

@end

NS_ASSUME_NONNULL_END
