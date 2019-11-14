//
//  JKMockManager.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class JKBaseRequest;
@interface JKMockManager : NSObject

+ (void)initMockConfig:(NSDictionary *)config;

+ (BOOL)matchRequest:(__kindof JKBaseRequest *)request
                 url:(NSString *)url;

/// get the configed httpMethod of the reuquest need mock
/// @param apiName apiName
/// @param method httpMethod
+ (NSString *)mockHttpMethodWithApiName:(NSString *)apiName
                                 method:(NSString *)method;

/// get the configed url queryParams of the reuquest need mock
/// @param apiName apiName
/// @param method httpMethod
+ (NSDictionary *)mockQueryParamsWithApiName:(NSString *)apiName
                                      method:(NSString *)method;

/// get the configed headers of the request need mock
/// @param apiName apiName
/// @param method httpMethod
+ (NSDictionary *)mockHeadersWithApiName:(NSString *)apiName
                                  method:(NSString *)method;

/// get the the configed bodyParams of the request nned mock
/// @param apiName apiName
/// @param method httpMethod
+ (NSDictionary *)mockBodyParamsWithApiName:(NSString *)apiName
                                     method:(NSString *)method;

/**
 url的参数 返回key:value
 */
+ (NSDictionary *)paramsWithURL:(NSString *)url;

+ (NSDictionary *)convertDictionaryWithURLParams:(NSString *)paramsURL;

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
