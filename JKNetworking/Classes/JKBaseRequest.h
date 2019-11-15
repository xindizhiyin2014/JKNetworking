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
   /// the request not support signature
  JKNetworkErrorNotSupportSignature = 10000,
   /// the response is not a valid json
  JKNetworkErrorInvalidJSONFormat,
};

static NSString * const JKNetworkErrorDomain = @"JKNetworkError";

@protocol JKRequestAccessoryProtocol <NSObject>

@optional

+ (void)requestWillStart:(id)request;

+ (void)requestWillStop:(id)request;

+ (void)requestDidStop:(id)request;

@end

@class JKBaseRequest,JKBaseDownloadRequest;

@protocol JKRequestConfigProtocol <NSObject>

/// config the upload request if the request in JKBatchRequest or JKChainRequest
/// @param request request
/// @param data the data need to upload
/// @param uploadProgressBlock the upload progress block
/// @param formDataBlock the formData config block
- (void)configUploadRequest:(__kindof JKBaseRequest *)request
                       data:(nullable NSData *)data
                   progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
              formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock;

/// config the download request if the request in JKBatchRequest or JKChainRequest
/// @param request request
/// @param downloadProgressBlock the download progress block
- (void)configDownloadRequest:(__kindof JKBaseDownloadRequest *)request
                     progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock;

@end


@interface JKBaseRequest : NSObject

/// the request apiName
@property (nonatomic, copy, nonnull) NSString *requestUrl;

/// the request baseurl, it can contain host,port,and some path
@property (nonatomic, copy, nullable) NSString *baseUrl;

/// the request baseurl of cdn it can contain host,port,and some path
@property (nonatomic, copy, nullable) NSString *cdnBaseUrl;

/// use cdn or not,default is NO
@property (nonatomic, assign) BOOL useCDN;

/// the request timeout interval
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;

/// the method of the request,default is GET
@property (nonatomic, assign) JKRequestMethod requestMethod;

/// the request serializer type
@property (nonatomic, assign) JKRequestSerializerType requestSerializerType;

/// the response serializer type
@property (nonatomic, assign) JKResponseSerializerType responseSerializerType;

/// the requestTask of the Request
@property (nonatomic, strong, readonly, nullable) NSURLSessionTask *requestTask;

/// the responseObject of the request
@property (nonatomic, strong, readonly, nullable) id responseObject;

/// the requestJSONObject of the request if the responseObject can not convert to a JSON object it is nil
@property (nonatomic, strong, readonly, nullable) id responseJSONObject;

/// the object of the json validate config
@property (nonatomic, strong, nullable) id jsonValidator;

/// the error of the requestTask
@property (nonatomic, strong, readonly, nullable) NSError *error;

/// the status of the requestTask is cancelled or not
@property (nonatomic, assign, readonly, getter=isCancelled) BOOL cancelled;

/// the status of the requestTask is executing of not
@property (nonatomic, assign, readonly, getter=isExecuting) BOOL executing;

/// the request header dic
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *requestHeaders;

/// the params of the request
@property (nonatomic, copy, nullable) NSDictionary *requestArgument;

/// use cache or not default is NO
@property (nonatomic, assign) BOOL ignoreCache;

/// if the use the cache please make sure the value bigger than zero
@property (nonatomic, assign) NSInteger cacheTimeInSeconds;

/// is the response is use the cache data,default is NO
@property (nonatomic, assign, readonly) BOOL isDataFromCache;

/// the status of the request is not in a batchRequest or not in a chainRequest,default is YES
@property (nonatomic, assign, readonly) BOOL isIndependentRequest;

/// is use the signature for the request
@property (nonatomic, assign) BOOL useSignature;

/// the url has signatured
@property (nonatomic, copy, nullable) NSString *signaturedUrl;

/// the params has signatured
@property (nonatomic, strong, nullable) id signaturedParams;

/// the network status handle class
@property (nonatomic,strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;

- (void)clearCompletionBlock;

- (void)start;

- (void)stop;

/// after request success before successBlock callback,do this func
- (void)requestSuccessPreHandle;

///after request failure before successBlock callback,do this func
- (void)requestFailurePreHandle;

- (void)startWithCompletionBlockWithSuccess:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;
/// upload data
/// @param data data
/// @param uploadProgressBlock uploadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)uploadWithData:(nullable NSData *)data
              progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
         formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
               success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
               failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;


- (void)addRequestHeader:(NSDictionary <NSString *,NSString *>*)header;

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


@interface JKBaseDownloadRequest :JKBaseRequest

/// the url of the download file resoure
@property (nonatomic, copy, readonly) NSString *absoluteString;
/// the filePath of the downloaded file
@property (nonatomic, copy, readonly) NSString *downloadedFilePath;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)init NS_UNAVAILABLE;

+ (instancetype)initWithUrl:(nonnull NSString *)url;

/// downloadFile
/// @param downloadProgressBlock downloadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)downloadWithProgress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                     success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                     failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;

/// get the md5 string of the target sting
+ (NSString *)MD5String:(NSString *)string;


@end

NS_ASSUME_NONNULL_END
