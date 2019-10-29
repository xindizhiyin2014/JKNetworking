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

@interface JKBaseDownloadRequest :JKBaseRequest

@property (nonatomic, copy) NSString *absoluteString;

@end


@implementation JKBaseDownloadRequest

- (NSString *)buildCustomRequestUrl
{
    return self.absoluteString;
}

@end

@interface JKBaseRequest()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;

@property (nonatomic, strong, readwrite, nullable) id responseObject;

@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;

@property (nonatomic, strong, readwrite, nullable) NSError *error;

@property (nonatomic, assign, readwrite) BOOL isDataFromCache; ///< is the response frome cache

@property (nonatomic, copy, nullable) void(^successCompletionBlock)(__kindof JKBaseRequest *request); ///< the request success block

@property (nonatomic, copy, nullable) void(^failureCompletionBlock)(__kindof JKBaseRequest *request); ///< the request failure block

@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);      ///< the download/upload request progress block

@property (nonatomic, assign) BOOL isDownload;                 ///< is a download request or not

@property (nonatomic, assign) BOOL isUpload;                   ///< is a upload request or not

@property (nonatomic, strong) NSData *uploadData;              ///< the data need to upload

@property (nonatomic, copy, nullable) void (^formDataBlock)(id<AFMultipartFormData> formData);   ///< when upload data cofig the formData


@end

@implementation JKBaseRequest

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
    
    if (!self.isInBatchRequest) {
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
        return;
    }
    self.successCompletionBlock = successBlock;
    self.failureCompletionBlock = failureBlock;
    [self start];
}

+ (__kindof JKBaseRequest *)downloadWithUrl:(NSString *)urlStr
                                   progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                    success:(nullable void(^)(__kindof JKBaseRequest *))successBlock
                                    failure:(nullable void(^)(__kindof JKBaseRequest *))failureBlock
{

    JKBaseDownloadRequest *request = [JKBaseDownloadRequest new];
    request.absoluteString = urlStr;
    request.successCompletionBlock = successBlock;
    request.failureCompletionBlock = failureBlock;
    request.progressBlock = downloadProgressBlock;
    request.isDownload = YES;
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

- (void)addRequstHeader:(NSDictionary <NSString *,NSString *>*)header
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

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.requestTask.currentRequest.URL, self.requestTask.currentRequest.HTTPMethod, self.requestArgument];

}
@end
