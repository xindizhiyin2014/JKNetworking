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
#import "JKGroupRequest.h"

@interface JKBaseRequest()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;

@property (nonatomic, strong, readwrite, nullable) id responseObject;

@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;

@property (nonatomic, strong, readwrite, nullable) NSError *error;
/// is the response frome cache
@property (nonatomic, assign, readwrite) BOOL isDataFromCache;
/// the request success block
@property (nonatomic, copy, nullable) void(^successBlock)(__kindof JKBaseRequest *request);
/// the request failure block
@property (nonatomic, copy, nullable) void(^failureBlock)(__kindof JKBaseRequest *request);
/// the download/upload request progress block
@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);
/// is a default/download/upload request
@property (nonatomic, assign) JKRequestType requestType;
/// when upload data cofig the formData
@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);

@property (nonatomic, copy, readwrite, nullable) NSString *signaturedUrl;

/// the params has signatured
@property (nonatomic, strong, readwrite, nullable) id signaturedParams;

@end

@implementation JKBaseRequest
@synthesize isIndependentRequest;
@synthesize groupRequest;
@synthesize groupSuccessBlock;
@synthesize groupFailureBlock;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestTimeoutInterval = 60;
    }
    return self;
}

- (void)clearCompletionBlock
{
    if (self.successBlock) {
        self.successBlock = nil;
    }
    if (self.failureBlock) {
        self.failureBlock = nil;
    }
    if (self.groupSuccessBlock) {
        self.groupSuccessBlock = nil;
    }
    if (self.groupFailureBlock) {
        self.groupFailureBlock = nil;
    }
}

- (void)start
{
    if (self.requestType != JKRequestTypeDefault) {
    #if DEBUG
            NSAssert(NO, @" request is upload request or download request,please use the specified func");
    #endif
        return;
    }
    
    if (self.isIndependentRequest) {
        if (self.requestAccessory && [self.requestAccessory respondsToSelector:@selector(requestWillStart:)]) {
            [self.requestAccessory requestWillStart:self];
        }
    }
    
    if ([JKNetworkConfig sharedConfig].requestHelper
        && [[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(judgeToChangeCachePolicy:)]) {
        [[JKNetworkConfig sharedConfig].requestHelper judgeToChangeCachePolicy:self];
    }
    
    if (self.ignoreCache) {
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
        if (self.successBlock) {
            self.successBlock(self);
        }
        [self clearCompletionBlock];
    });
}

- (void)stop
{
    [[JKNetworkAgent sharedAgent] cancelRequest:self];
}

- (BOOL)requestSuccessPreHandle
{
    if (self.cacheTimeInSeconds > 0){
       [self writeResponseToCacheFile];
    }
    return NO;
}

- (BOOL)requestFailurePreHandle
{
    return NO;
}

- (void)startWithCompletionSuccess:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock
{
    if (self.requestType != JKRequestTypeDefault) {
#if DEBUG
        NSAssert(NO, @" request is upload request or download request,please use the specified func");
#endif
        return;
    }
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    [self start];
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
    return self.customRequestUrl;
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

- (void)clearResponseFromCache
{
    if ([[JKNetworkConfig sharedConfig].requestHelper respondsToSelector:@selector(clearResponseFromCacheOfRequest:)]) {
        [[JKNetworkConfig sharedConfig].requestHelper clearResponseFromCacheOfRequest:self];
    }
}

#pragma mark - - JKRequestInGroupProtocol - -
- (BOOL)isIndependentRequest
{
    return self.groupRequest?NO:YES;
}

- (void)inAdvanceCompleteGroupRequestWithResult:(BOOL)isSuccess
{
    if (self.groupRequest) {
        [self.groupRequest inAdvanceCompleteWithResult:isSuccess];
    }else {
#if DEBUG
        NSAssert(NO, @"self.groupRequest is nil");
#endif
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

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.requestTask.currentRequest.URL, self.requestTask.currentRequest.HTTPMethod, self.requestArgument];

}
@end

@interface JKBaseUploadRequest()

@end

@implementation JKBaseUploadRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.requestType = JKRequestTypeUpload;
    }
    return self;
}

- (void)uploadWithProgress:(nullable void(^)(NSProgress *progress))uploadProgressBlock
             formDataBlock:(nullable void(^)(id <AFMultipartFormData> formData))formDataBlock
                   success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                   failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    self.progressBlock = uploadProgressBlock;
    self.formDataBlock = formDataBlock;
    [[JKNetworkAgent sharedAgent] addRequest:self];
}

@end


@interface JKBaseDownloadRequest()

/// the url of the download file resoure
@property (nonatomic, copy, readwrite) NSString *absoluteString;

/// the filePath of the downloaded file
@property (nonatomic, copy, readwrite) NSString *downloadedFilePath;

@property (nonatomic, copy, readwrite) NSString *tempFilePath;

@end

@implementation JKBaseDownloadRequest


+ (instancetype)initWithUrl:(nonnull NSString *)url
{
    JKBaseDownloadRequest *request = [[self alloc] init];
    if (request) {
#if DEBUG
        NSAssert(url, @"url can't be nil");
#endif
        request.absoluteString = url;
    }
    return request;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.requestType = JKRequestTypeDownload;
    }
    return self;
}

- (NSString *)buildCustomRequestUrl
{
    return self.absoluteString;
}

- (void)downloadWithProgress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                     success:(nullable void(^)(__kindof JKBaseRequest *request))successBlock
                     failure:(nullable void(^)(__kindof JKBaseRequest *request))failureBlock
{
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    self.progressBlock = downloadProgressBlock;
    [[JKNetworkAgent sharedAgent] addRequest:self];
}


- (NSString *)MD5String:(NSString *)string
{
   if (!jk_safeStr(string)) {
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

#pragma mark - - getter - -
- (nullable NSString *)downloadedFilePath
{
    if (!_downloadedFilePath) {
        if (!jk_safeStr(self.absoluteString)) {
            return nil;
        }
        NSString *downloadFolderPath = [JKNetworkConfig sharedConfig].downloadFolderPath;
        NSString *fileName = [self MD5String:self.absoluteString];
        fileName = [fileName stringByAppendingPathExtension:[self.absoluteString pathExtension]]?:@"";
        _downloadedFilePath = [NSString pathWithComponents:@[downloadFolderPath, fileName]];
    }
    return _downloadedFilePath;
}

- (nullable NSString *)tempFilePath
{
    if (!_tempFilePath) {
        if (!jk_safeStr(self.absoluteString)) {
            return nil;
        }
        NSString *str = [NSString stringWithFormat:@"backgroundPolicy_%@_%@",@(self.backgroundPolicy),self.absoluteString];
        NSString *md5URLStr = [self MD5String:str];
        _tempFilePath = [[JKNetworkConfig sharedConfig].incompleteCacheFolder stringByAppendingPathComponent:md5URLStr];
    }
    return _tempFilePath;
}

@end
