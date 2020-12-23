//
//  JKNetworkTaskDelegate.h
//  JKNetworking_
//
//  Created by JackLee on 2020/12/4.
//

#import <Foundation/Foundation.h>
#import "JKBaseRequest.h"
NS_ASSUME_NONNULL_BEGIN
@interface JKNetworkBaseDownloadTaskDelegate : NSObject
@property (nonatomic, weak, readonly) __kindof JKBaseDownloadRequest *request;
@property (nonatomic, copy) void(^downloadProgressBlock)(NSProgress *downloadProgress);
@property (nonatomic, copy) void(^completionHandler)(NSURLResponse *response, NSError *error);

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRequest:(__kindof JKBaseDownloadRequest *)request;

- (void)URLSession:(NSURLSession *)session task:(__kindof NSURLSessionTask *)task
                      didBecomeInvalidWithError:(NSError *)error;

@end

@interface JKNetworkDownloadTaskDelegate : JKNetworkBaseDownloadTaskDelegate
<
NSURLSessionDataDelegate
>

@end


@interface JKNetworkBackgroundDownloadTaskDelegate : JKNetworkBaseDownloadTaskDelegate
<
NSURLSessionDownloadDelegate
>

@end

NS_ASSUME_NONNULL_END
