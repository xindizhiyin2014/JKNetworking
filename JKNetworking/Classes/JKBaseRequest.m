//
//  JKBaseRequest.m
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import "JKBaseRequest.h"
#import "JKNetworkAgent.h"
#import "JKNetworkConfig.h"
#import <JKDataHelper/JKDataHelper.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@interface JKBaseRequest()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;

@property (nonatomic, strong, readwrite, nullable) id responseObject;

@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;

@property (nonatomic, strong, readwrite, nullable) NSError *error;
/// is the response frome cache
@property (nonatomic, assign, readwrite) BOOL isDataFromCache;

@property (nonatomic, assign, readwrite) BOOL isIndependentRequest;

/// the request success block
@property (nonatomic, copy, nullable) void(^successCompletionBlock)(__kindof JKBaseRequest *request);
/// the request failure block
@property (nonatomic, copy, nullable) void(^failureCompletionBlock)(__kindof JKBaseRequest *request);
/// the download/upload request progress block
@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);
/// is a download request or not
@property (nonatomic, assign) BOOL isDownload;
/// is a upload request or not
@property (nonatomic, assign) BOOL isUpload;
/// the data need to upload
@property (nonatomic, strong) NSData *uploadData;
/// when upload data cofig the formData
@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);


@end

@implementation JKBaseRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestTimeoutInterval = 60;
        _isIndependentRequest = YES;
    }
    return self;
}

- (void)clearCompletionBlock
{
    if (self.successCompletionBlock) {
        self.successCompletionBlock = nil;
    }
    
    if (self.failureCompletionBlock) {
        self.failureCompletionBlock = nil;
    }
}

- (void)start
{
    if (self.isDownload || self.isUpload) {
        return;
    }
    
    if (self.isIndependentRequest) {
        if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
            [self.requestAccessory requestWillStart:self];
        }
    }
    if (!self.ignoreCache) {
        self.isDataFromCache = NO;
        [[JKNetworkAgent sharedAgent] addRequest:self];
        return;
    }
    
    NSError *error = nil;
    if (![self readResponseFromCache:&error]) {
        self.isDataFromCache = NO;
        [[JKNetworkAgent sharedAgent] addRequest:self];
        return;
    }
    
    self.isDataFromCache = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.successCompletionBlock) {
            self.successCompletionBlock(self);
        }
        [self clearCompletionBlock];
    });
}

- (void)stop
{
    [[JKNetworkAgent sharedAgent] cancelRequest:self];
}

- (void)requestSuccessPreHandle
{
    if (!self.ignoreCache){
     [self writeResponseToCacheFile];
    }
}

- (void)requestFailurePreHandle
{
    
}

- (void)startWithCompletionBlockWithSuccess:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock
{
    if (self.isDownload || self.isUpload) {
        NSAssert(NO, @"request is upload request of download request,please use the specified func");
        return;
    }
    self.successCompletionBlock = successBlock;
    self.failureCompletionBlock = failureBlock;
    [self start];
}

+ (__kindof JKBaseDownloadRequest *)downloadWithUrl:(NSString *)urlStr
                                   progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                    success:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock
{
    JKBaseDownloadRequest *request = [JKBaseDownloadRequest initWithUrl:urlStr];
    request.successCompletionBlock = successBlock;
    request.failureCompletionBlock = failureBlock;
    request.progressBlock = downloadProgressBlock;
    [[JKNetworkAgent sharedAgent] addRequest:request];
    return request;
}

- (void)uploadWithData:(nullable NSData *)data
              progress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
         formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
               success:(nullable void(^)(__kindof JKBaseRequest *))successBlock
               failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock
{
    self.successCompletionBlock = successBlock;
    self.failureCompletionBlock = failureBlock;
    self.progressBlock = uploadProgressBlock;
    self.formDataBlock = formDataBlock;
    self.isUpload = YES;
    self.uploadData = data;
    [[JKNetworkAgent sharedAgent] addRequest:self];
}

- (void)addRequestHeader:(NSDictionary <NSString *,NSString *>*)header
{
    if (!self.requestHeaders) {
        if (jk_safeDict(header)) {
           self.requestHeaders = header;
        }
    } else if (jk_safeDict(self.requestHeaders)) {
        if (jk_safeDict(header)) {
             NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:self.requestHeaders];
                   [dic addEntriesFromDictionary:header];
            self.requestHeaders = [dic copy];
        }
    } else {
        if (jk_safeDict(header)) {
           self.requestHeaders = header;
        }
    }
}

- (void)addJsonValidator:(NSDictionary *)validator
{
    if (!self.jsonValidator) {
        self.jsonValidator = validator;
    } else if (jk_safeDict(self.jsonValidator)) {
        if (jk_safeDict(validator)) {
            NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:self.jsonValidator];
            [dic addEntriesFromDictionary:validator];
            self.jsonValidator = [dic copy];
        }
    } else if (jk_safeArray(self.jsonValidator)) {
        if (jk_safeDict(validator)) {
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.jsonValidator];
            [array addObject:validator];
            self.jsonValidator = [array copy];
        }
    }
}

- (BOOL)statusCodeValidator
{
//    NSHTTPURLResponse *response = (NSHTTPURLResponse *)self.requestTask.response;
//    NSInteger statusCode = response.statusCode;
//#warning todo
    return YES;
}

- (NSString *)buildCustomRequestUrl
{
    return nil;
}

- (BOOL)customSignature
{
    return NO;
}

- (BOOL)readResponseFromCache:(NSError **)error
{
    if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(loadCacheDataOfRequest:error:)]) {
      id responseObject = [[JKNetworkConfig sharedConfig].requestHelper loadCacheDataOfRequest:self error:error];
        self.responseObject = responseObject;
        if (self.responseSerializerType == JKResponseSerializerTypeJSON) {
            self.responseJSONObject = responseObject;
        }
        if (!error) {
            return YES;
        }
        return NO;
    }
    return NO;
}

- (void)writeResponseToCacheFile
{
    if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(saveResponseToCacheOfRequest:)]) {
        [[JKNetworkConfig sharedConfig].requestHelper saveResponseToCacheOfRequest:self];
    }
}

#pragma mark - getter -

- (BOOL)isCancelled {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateCanceling;
}

- (BOOL)isExecuting {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateRunning;
}

+ (NSString *)MD5String:(NSString *)string
{
   if (jk_safeStr(string)) {
        return nil;
    }
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), digest ); // This is the md5 call
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return  output?:@"";
}

+ (NSString *)downloadFilePathWithUrlString:(NSString *)urlString
{
    if (jk_safeStr(urlString)) {
        return nil;
    }
    
        NSString *downloadFolderPath = [JKNetworkConfig sharedConfig].downloadFolderPath;
        BOOL isDirectory;
        if(![[NSFileManager defaultManager] fileExistsAtPath:downloadFolderPath isDirectory:&isDirectory]) {
            isDirectory = NO;
    #if DEBUG
            NSAssert(isDirectory, @"please makse sure the [JKNetworkConfig sharedConfig].downloadFolderPath is a directory");
    #endif
        }
        // If targetPath is a directory, use the file name we got from the urlRequest.
        // Make sure downloadTargetPath is always a file, not directory.
        if (isDirectory) {
            NSString *fileName = [JKBaseRequest MD5String:urlString];
            fileName = [fileName stringByAppendingPathExtension:[urlString pathExtension]];
           NSString *downloadTargetPath = [NSString pathWithComponents:@[downloadFolderPath, fileName]];
            return downloadTargetPath;
        }
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.requestTask.currentRequest.URL, self.requestTask.currentRequest.HTTPMethod, self.requestArgument];

}
@end

@interface JKBaseDownloadRequest()

@property (nonatomic, copy, readwrite) NSString *absoluteString;       ///< the url of the download file resoure
@property (nonatomic, copy, readwrite) NSString *downloadedFilePath;   ///< the filePath of the downloaded file
@end

@implementation JKBaseDownloadRequest


+ (instancetype)initWithUrl:(nonnull NSString *)url
{
    JKBaseDownloadRequest *request = [[self alloc] init];
    if (request) {
        request.absoluteString = url;
        request.isDownload = YES;
        request.downloadedFilePath = [self downloadFilePathWithUrlString:url];
    }
    return request;
}

- (NSString *)buildCustomRequestUrl
{
    return self.absoluteString;
}


@end
