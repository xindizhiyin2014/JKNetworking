//
//  JKNetworkConfig.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
NS_ASSUME_NONNULL_BEGIN
@class JKBaseRequest;

@protocol JKRequestHelperProtocol <NSObject>

@optional

/// this is the url append or filter func
/// @param originUrl originUrl
/// @param request request
- (NSString *)filterUrl:(NSString *)originUrl withRequest:(__kindof JKBaseRequest *)request;

/// use this func to signature the request
/// @param request the request
- (void)signatureRequest:(__kindof JKBaseRequest *)request;

/// load Cache data of the request
/// @param request request
- (id)loadCacheDataOfRequest:(__kindof JKBaseRequest *)request error:(NSError **)error;

/// save the request's reponse to cache
/// @param request request
- (void)saveResponseToCacheOfRequest:(__kindof JKBaseRequest *)request;

/// get the host with the requestUrl of the request
/// @param request request
- (NSString *)hostOfRequest:(__kindof JKBaseRequest *)request;

@end

@interface JKNetworkConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)sharedConfig;

/// the request baseurl, it can contain host,port,and some path
@property (nonatomic, copy, nullable) NSString *baseUrl;

/// the request baseurl of cdn it can contain host,port,and some path
@property (nonatomic, copy, nullable) NSString *cdnBaseUrl;

/// the baseUrl of the mockRequest
@property (nonatomic, copy, nullable) NSString *mockBaseUrl;

/// the status of the mock,default is NO
@property (nonatomic, assign) BOOL isMock;

/// the all request timeoutInterval in mock model,default is 300 second.
@property (nonatomic, assign) NSUInteger mockModelTimeoutInterval;

/// the security policy ,it use AFNetworking  AFSecurityPolicy
@property (nonatomic, strong, nonnull) AFSecurityPolicy *securityPolicy;

@property (nonatomic, strong, nonnull) NSURLSessionConfiguration *sessionConfiguration;

/// the folder filePath of the download file,the defalut is under doment /JKNetworking_download
@property (nonatomic, copy, nonnull) NSString *downloadFolderPath;

@property (nonatomic, strong, readonly, nullable) id<JKRequestHelperProtocol> requestHelper;

- (void)configRequestHelper:(id<JKRequestHelperProtocol>)requestHelper;

@end

NS_ASSUME_NONNULL_END
