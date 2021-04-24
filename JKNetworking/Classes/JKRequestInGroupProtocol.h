//
//  JKRequestInGroupProtocol.h
//  JKNetworking_
//
//  Created by JackLee on 2021/4/22.
//

#ifndef JKRequestInGroupProtocol_h
#define JKRequestInGroupProtocol_h
@class JKGroupRequest;
@protocol JKRequestInGroupProtocol <NSObject>

/// the status of the request is not in a batchRequest or not in a chainRequest,default is YES
@property (nonatomic, assign, readonly) BOOL isIndependentRequest;

@property (nonatomic, weak, nullable) __kindof JKGroupRequest *groupRequest;

/// the childRequest success block
@property (nonatomic, copy, nullable) void(^groupSuccessBlock)(NSObject<JKRequestInGroupProtocol> * _Nonnull request);
/// the childRequest failure block
@property (nonatomic, copy, nullable) void(^groupFailureBlock)(NSObject<JKRequestInGroupProtocol> * _Nonnull request);

- (void)start;

- (void)stop;

/// complete the groupRequest(batchRequest or chainRequest) in advance,even if the groupRequest has requests not complete.
- (void)inAdvanceCompleteGroupRequestWithResult:(BOOL)isSuccess;

@end

#endif /* JKRequestInGroupProtocol_h */
