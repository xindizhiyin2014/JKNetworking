//
//  JKBackgroundSessionManager.h
//  JKNetworking_
//
//  Created by JackLee on 2020/12/23.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN
@class JKDownloadRequest;
@class AFHTTPRequestSerializer;

@interface JKBackgroundSessionManager : NSObject
/// the background url task identifer
@property (nonatomic, copy, readonly, nonnull) NSString *backgroundTaskIdentifier;

@property (nonatomic, copy, nullable) void (^completionHandler)(void);

- (NSURLSessionTask *)dataTaskWithDownloadRequest:(__kindof JKDownloadRequest *)request
                                requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                        URLString:(NSString *)URLString
                                       parameters:(id)parameters
                                         progress:(nullable void (^)(NSProgress *downloadProgress))downloadProgressBlock
                                completionHandler:(nullable void (^)(NSURLResponse *response, NSError * _Nullable error))completionHandler
                                            error:(NSError * _Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
