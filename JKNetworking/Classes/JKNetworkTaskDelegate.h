//
//  JKNetworkTaskDelegate.h
//  JKNetworking_
//
//  Created by JackLee on 2020/12/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JKBaseRequest;
@interface JKNetworkTaskDelegate : NSObject
<
NSURLSessionTaskDelegate,
NSURLSessionDataDelegate,
NSURLSessionDownloadDelegate
>

@property (nonatomic, copy) NSString *downloadTargetPath;
@property (nonatomic, copy) NSString *tempPath;
@property (nonatomic, assign) int64_t resumeDataLength;
@property (nonatomic, copy) void(^uploadProgressBlock)(NSProgress *uploadProgress);
@property (nonatomic, copy) void(^downloadProgressBlock)(NSProgress *downloadProgress);
@property (nonatomic, copy) void(^completionHandler)(NSURLResponse *response, id responseObject, NSError *error);
@property (nonatomic, copy) NSURL * (^downloadTaskDidFinishDownloading)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location);
- (instancetype)initWithRequest:(__kindof JKBaseRequest *)request;

@end

NS_ASSUME_NONNULL_END
