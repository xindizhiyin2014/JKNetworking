//
//  JKBaseRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>

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

typedef NS_ENUM(NSInteger,JKRequestType)
{
    /// the default request
    JKRequestTypeDefault = 0,
    /// the download request
    JKRequestTypeDownload,
    /// the upload request
    JKRequestTypeUpload
};

typedef NS_ENUM(NSInteger,JKNetworkErrorType) {
   /// the request not support signature
  JKNetworkErrorNotSupportSignature = 10000,
   /// the response is not a valid json
  JKNetworkErrorInvalidJSONFormat,
};

typedef NS_ENUM(NSInteger,JKDownloadBackgroundPolicy) {
 // if the download task not complete, it will apply to some minutes to download
  JKDownloadBackgroundDefault = 0,
  // if the download task not complete,it forbidden to download at background
  JKDownloadBackgroundForbidden,
  // if the download task not complete,it apply download at background until complete
  JKDownloadBackgroundRequire,
};

static NSString * const JKNetworkErrorDomain = @"JKNetworkError";

@protocol JKRequestAccessoryProtocol <NSObject>

@optional

+ (void)requestWillStart:(id)request;

+ (void)requestWillStop:(id)request;

+ (void)requestDidStop:(id)request;

@end


@interface JKBaseRequest : NSObject

/// the request apiName,fact is a path of url,it can contain path and query params
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

/// the status of the requestTask is executing or not
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
@property (nonatomic, copy, readonly, nullable) NSString *signaturedUrl;

/// the params has signatured
@property (nonatomic, strong, readonly, nullable) id signaturedParams;

/// the network status handle class
@property (nonatomic,strong, nullable) Class<JKRequestAccessoryProtocol> requestAccessory;

/// the customUrl of the request,it contain domain,path,query, and so on.
@property (nonatomic, copy, nullable) NSString *customRequestUrl;

- (void)clearCompletionBlock;

- (void)start;

- (void)stop;

/// after request success before successBlock callback,do this func,if you want extra handle,return YES,else return NO
- (BOOL)requestSuccessPreHandle;

///after request failure before successBlock callback,do this func,if you want extra handle,return YES,else return NO
- (BOOL)requestFailurePreHandle;

- (void)startWithCompletionSuccess:(nullable void(^)(__kindof JKBaseRequest *request))successBlock failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;

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


@interface JKBaseUploadRequest : JKBaseRequest

/// upload data
/// @param uploadProgressBlock uploadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)uploadWithProgress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
             formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                   success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                   failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock;
@end

@interface JKBaseDownloadRequest :JKBaseRequest

/// the url of the download file resoure
@property (nonatomic, copy, readonly) NSString *absoluteString;
/// the filePath of the downloaded file
@property (nonatomic, copy, readonly) NSString *downloadedFilePath;
/// the temp filepath of the download file
@property (nonatomic, copy, readonly) NSString *tempFilePath;
/// the background policy of the downloadRequest
@property (nonatomic, assign) JKDownloadBackgroundPolicy backgroundPolicy;

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

@end

NS_ASSUME_NONNULL_END
