//
//  JKBaseRequest.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>
#import "JKRequestInGroupProtocol.h"

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
  JKNetworkErrorStatusCode,
};

typedef NS_ENUM(NSInteger,JKDownloadBackgroundPolicy) {
 // if the download task not complete, it will apply to some minutes to download
  JKDownloadBackgroundDefault = 0,
  // if the download task not complete,it forbidden to download at background
  JKDownloadBackgroundForbidden,
  // if the download task not complete,it apply download at background until complete
  JKDownloadBackgroundRequire,
};

typedef NS_ENUM(NSInteger, JKRequestPriority) {
    JKRequestPriorityDefault = 0,
    JKRequestPriorityLow,
    JKRequestPriorityHigh
};

static NSString * const JKNetworkErrorDomain = @"JKNetworkError";


@protocol JKRequestAccessoryProtocol <NSObject>

@optional

+ (void)requestWillStart:(id)request;

+ (void)requestWillStop:(id)request;

+ (void)requestDidStop:(id)request;

@end


@interface JKBaseRequest : NSObject<JKRequestInGroupProtocol>

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

@property (nonatomic, assign) JKRequestPriority priority;

/// the responseObject of the request
@property (nonatomic, strong, readonly, nullable) id responseObject;

/// the requestJSONObject of the request if the responseObject can not convert to a JSON object it is nil
@property (nonatomic, strong, readonly, nullable) id responseJSONObject;

/// the object of the json validate config
@property (nonatomic, strong, nullable) id jsonValidator;

/// the error of the requestTask
@property (atomic, strong, readonly, nullable) NSError *error;

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
/// the data is from response is parsed
@property (nonatomic, strong, readonly, nullable) id parsedData;


- (void)clearCompletionBlock;

- (void)start;

- (void)stop;

/// after request success before successBlock callback,do this func,if you want extra handle,return YES,else return NO
- (BOOL)requestSuccessPreHandle;

///after request failure before successBlock callback,do this func,if you want extra handle,return YES,else return NO
- (BOOL)requestFailurePreHandle;

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

- (void)clearResponseFromCache;

@end

@interface JKRequest : JKBaseRequest
/// start the request
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)startWithCompletionSuccess:(nullable void(^)(__kindof JKRequest *request))successBlock failure:(nullable void(^)(__kindof JKRequest *request))failureBlock;

/// start the request
/// @param parseBlock the block used to parse response, exec not in mainThread
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)startWithCompletionParse:(nullable id(^)(__kindof JKRequest *request, NSRecursiveLock *lock))parseBlock
                         success:(nullable void(^)(__kindof JKRequest *request))successBlock
                         failure:(nullable void(^)(__kindof JKRequest *request))failureBlock;
@end


@interface JKUploadRequest : JKBaseRequest

/// upload data
/// @param uploadProgressBlock uploadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)uploadWithProgress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
             formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                   success:(nullable void(^)(__kindof JKUploadRequest *request))successBlock
                   failure:(nullable void(^)(__kindof JKUploadRequest *request))failureBlock;
@end

@interface JKDownloadRequest :JKBaseRequest

/// the url of the download file resoure
@property (nonatomic, copy, readonly) NSString *absoluteString;
/// the filePath of the downloaded file
@property (nonatomic, copy, nullable, readonly) NSString *downloadedFilePath;
/// the temp filepath of the download file
@property (nonatomic, copy, nullable, readonly) NSString *tempFilePath;
/// the background policy of the downloadRequest
@property (nonatomic, assign, readonly) JKDownloadBackgroundPolicy backgroundPolicy;
/// the request is recovered from the os system,when start a background request during the last runing time,and the request has not completed
@property (nonatomic, assign, readonly) BOOL isRecoveredFromSystem;

+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)init NS_UNAVAILABLE;

/// init,if has request with same config,do not init again.
/// @param url url
/// @param downloadedPath if downloadedPath nil,the downloadedFilePath use default
/// @param backgroundPolicy backgroundPolicy
+ (instancetype)initWithUrl:(NSString *)url
             downloadedPath:(nullable NSString *)downloadedPath
           backgroundPolicy:(JKDownloadBackgroundPolicy)backgroundPolicy;

/// find the executing DownloadRequest
/// @param url url
/// @param downloadedPath downloadedPath can't be nil
/// @param backgroundPolicy backgroundPolicy
+ (nullable)excutingDownloadRequestWithUrl:(NSString *)url
                            downloadedPath:(NSString *)downloadedPath
                          backgroundPolicy:(JKDownloadBackgroundPolicy)backgroundPolicy;

/// downloadFile
/// @param downloadProgressBlock downloadProgressBlock
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)downloadWithProgress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                     success:(nullable void(^)(__kindof JKDownloadRequest *request))successBlock
                     failure:(nullable void(^)(__kindof JKDownloadRequest *request))failureBlock;

/// downloadFile
/// @param downloadProgressBlock downloadProgressBlock
/// @param parseBlock parseBlock hanle decrypt,decode action,if use this block ,you need move the tempFilePath to downloadedFilePath youself
/// @param successBlock successBlock
/// @param failureBlock failureBlock
- (void)downloadWithProgress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                       parse:(nullable NSError *(^)(__kindof JKDownloadRequest *request, NSRecursiveLock *lock))parseBlock
                     success:(nullable void(^)(__kindof JKDownloadRequest *request))successBlock
                     failure:(nullable void(^)(__kindof JKDownloadRequest *request))failureBlock;

+ (NSString *)tempFilePathWithURLString:(NSString *)URLString
                       backgroundPolicy:(JKDownloadBackgroundPolicy)backgroundPolicy;
@end

NS_ASSUME_NONNULL_END
