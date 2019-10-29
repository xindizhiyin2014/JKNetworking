//
//  JKBaseRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger,JKRequestMethod)
{
    JKRequestMethodGET = 0,
    JKRequestMethodPOST,
    JKRequestMethodHEAD,
    JKRequestMethodPUT,
    JKRequestMethodDELETE,
    JKRequestMethodPATCH,
};

typedef NS_ENUM(NSInteger,JKRequestSerializerType)
{
    JKRequestSerializerTypeHTTP = 0,
    JKRequestSerializerTypeJSON,
};

typedef NS_ENUM(NSInteger,JKResponseSerializerType)
{
    JKResponseSerializerTypeHTTP = 0,
    JKResponseSerializerTypeJSON,
    JKResponseSerializerTypeXMLParser,
};

typedef NS_ENUM(NSInteger,JKNetworkErrorType) {
  JKNetworkErrorNotSupportSignature = 10000,
  JKNetworkErrorInvalidJSONFormat,
};

static NSString * const JKNetworkErrorDomain = @"JKNetworkError";

@protocol JKRequestAccessoryProtocol <NSObject>

@optional

+ (void)requestWillStart:(id)request;

+ (void)requestWillStop:(id)request;

+ (void)requestDidStop:(id)request;

@end

@interface JKBaseRequest : NSObject

@property (nonatomic, copy, nonnull) NSString *requestUrl;                     ///< the request apiName

@property (nonatomic, copy, nullable) NSString *host;                          ///< the request host domain

@property (nonatomic, copy, nullable) NSString *cdnHost;                       ///< the request cdn host domain

@property (nonatomic, assign) BOOL useCDN;                                     ///< use cdn or not,default is NO

@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;           ///< the request timeout interval

@property (nonatomic, assign) JKRequestMethod requestMethod;                   ///< the method of the request,default is GET

@property (nonatomic, assign) JKRequestSerializerType requestSerializerType;   ///< the request serializer type

@property (nonatomic, assign) JKResponseSerializerType responseSerializerType; ///< the response serializer type

@property (nonatomic, strong, readonly) NSURLSessionTask *requestTask;         ///< the requestTask of the Request

@property (nonatomic, strong, readonly, nullable) id responseObject;           ///< the responseObject of the request

@property (nonatomic, strong, readonly, nullable) id responseJSONObject;       ///< the requestJSONObject of the request if the responseObject can not convert to a JSON object it is nil
@property (nonatomic, strong, nullable) id jsonValidator;                       ///< the object of the json validate config

@property (nonatomic, strong, readonly, nullable) NSError *error;              ///< the error of the requestTask

@property (nonatomic, assign, readonly, getter=isCancelled) BOOL cancelled;    ///< the status of the requestTask is cancelled or not

@property (nonatomic, assign, readonly, getter=isExecuting) BOOL executing;    ///< the status of the requestTask is executing of not
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *requestHeaders; ///< the request header dic

@property (nonatomic, copy, nullable) NSDictionary *requestArgument;                   ///< the params of the request

@property (nonatomic, assign) BOOL ignoreCache;                   ///< use cache or not default is NO

@property (nonatomic, assign) NSInteger cacheTimeInSeconds;       ///< if the use the cache please make the value bigger than zero

@property (nonatomic, assign, readonly) BOOL isDataFromCache;     ///< is the response is use the cache data,default is NO

@property (nonatomic, assign) BOOL isInBatchRequest;              ///< is a request of the batch request,default is NO;

@property (nonatomic, assign) BOOL useSignature;                  ///< is use the signature for the request;
@property (nonatomic, copy, nullable) NSString *signaturedUrl;    ///< the url has signatured
@property (nonatomic, strong, nullable) id signaturedParams;      ///< the params has signatured

@property (nonatomic,strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory; ///< the network status handle class

- (void)clearCompletionBlock;

- (void)start;

- (void)stop;

/**
 after request success before successBlock callback,do this func
 */
- (void)requestSuccessPreHandle;

/**
 after request failure before successBlock callback,do this func
 */
- (void)requestFailurePreHandle;

- (void)startWithCompletionBlockWithSuccess:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock;

/// downloadFile
/// @param urlStr the urlStr of the file
/// @param downloadProgressBlock downloadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
+ (__kindof JKBaseRequest *)downloadWithUrl:(NSString *)urlStr
                                   progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                    success:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock;

/// upload data
/// @param data data
/// @param uploadProgressBlock uploadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)uploadWithData:(nullable NSData *)data
              progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
         formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
               success:(nullable void(^)(__kindof JKBaseRequest *))successBlock
               failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock;


- (void)addRequstHeader:(NSDictionary <NSString *,NSString *>*)header;

/// add the validator for the reponse,if the jsonValidator isn't kind of NSArray or NSDictionary,the func do nothing
- (void)addJsonValidator:(NSDictionary *)validator;

- (BOOL)statusCodeValidator;

/// the custom func of filter url,default is nil
- (NSString *)buildCustomRequestUrl;

/// the custom signature func, default is NO，if use custom signature do the signature in this func
- (BOOL)customSignature;

- (BOOL)readResponseFromCache:(NSError **)error;

- (void)writeResponseToCacheFile;

@end

NS_ASSUME_NONNULL_END
