//
//  JKNetworkTaskDelegate.m
//  JKNetworking_
//
//  Created by JackLee on 2020/12/4.
//

#import "JKNetworkTaskDelegate.h"
#import "JKNetworkConfig.h"
#import "JKNetworkingMacro.h"
@interface JKBaseRequest(JKNetworkBaseDownloadTaskDelegate)

@property (nonatomic, copy, nullable) void(^progressBlock)(NSProgress *progress);

@end

@implementation JKBaseRequest(JKNetworkBaseDownloadTaskDelegate)
@dynamic progressBlock;


@end

@interface JKNetworkBaseDownloadTaskDelegate()
@property (nonatomic, weak, readwrite) __kindof JKDownloadRequest *request;
@property (nonatomic, copy) NSString *downloadTargetPath;
@property (nonatomic, copy) NSString *tempPath;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) int64_t currentLength;
@property (nonatomic, assign) int64_t totalLength;
@property (nonatomic, copy, nullable) NSError *(^parseBlock)(__kindof JKDownloadRequest *request, NSRecursiveLock *lock);
@property (nonatomic, strong) NSRecursiveLock *lock;


@end

@implementation JKNetworkBaseDownloadTaskDelegate

- (instancetype)initWithRequest:(__kindof JKDownloadRequest *)request
{
    self = [super init];
    if (self) {
        _request = request;
        _progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        _currentLength = 0;
        _totalLength = 0;
        _downloadTargetPath = request.downloadedFilePath;
        _tempPath = request.tempFilePath;
        _parseBlock = [request valueForKey:@"parseBlock"];
        _lock = [NSRecursiveLock new];
        NSURLSessionTask *task = request.requestTask;
        @weakify(task);
        _progress.totalUnitCount = NSURLSessionTransferSizeUnknown;
        _progress.cancellable = YES;
        _progress.cancellationHandler = ^{
            @strongify(task);
            [task cancel];
        };
        _progress.pausable = YES;
        _progress.pausingHandler = ^{
            @strongify(task);
            [task suspend];
        };
    #if AF_CAN_USE_AT_AVAILABLE
        if (@available(iOS 9, macOS 10.11, *))
    #else
        if ([_progress respondsToSelector:@selector(setResumingHandler:)])
    #endif
        {
            _progress.resumingHandler = ^{
                @strongify(task);
                [task resume];
            };
        }
        
        [_progress addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        [_request  addObserver:self forKeyPath:@"progressBlock" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session task:(__kindof NSURLSessionTask *)task
                      didBecomeInvalidWithError:(NSError *)error
{
    
}
#pragma mark - observeValueForKeyPath

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"fractionCompleted"]) {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(object);
        }
    } else if ([keyPath isEqualToString:@"progressBlock"]) {
        @synchronized (self) {
            self.downloadProgressBlock = self.request.progressBlock;
        }
        
    }
        
}


- (void)dealloc
{
    [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
    [self.request removeObserver:self forKeyPath:@"progressBlock"];
}

@end



@interface JKNetworkDownloadTaskDelegate()

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, assign) int64_t resumeDataLength;


@end

@implementation JKNetworkDownloadTaskDelegate

- (instancetype)initWithRequest:(__kindof JKDownloadRequest *)request
{
    self = [super initWithRequest:request];
    if (self) {
        _resumeDataLength = 0;
        BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.tempPath];
        if (resumeDataFileExists) {
            NSData *resumeData = [NSData dataWithContentsOfFile:self.tempPath];
            _resumeDataLength = resumeData.length;
        }
    }
    return self;
}



#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    if (self.fileHandle) {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        self.totalLength = 0;
        self.currentLength = 0;
        self.resumeDataLength = 0;
    }
    if (self.completionHandler) {
        if (!error) {
            if (self.parseBlock) {
                error = self.parseBlock(self.request,self.lock);
            } else {
                [[NSFileManager defaultManager] moveItemAtPath:self.tempPath toPath:self.downloadTargetPath error:nil];
            }
        }
        self.completionHandler(task.response, error);
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
    self.totalLength = self.resumeDataLength + response.expectedContentLength;
    self.currentLength = self.resumeDataLength;
}

- (void)URLSession:(__unused NSURLSession *)session dataTask:(__unused NSURLSessionDataTask *)dataTask
                                              didReceiveData:(NSData *)data
{
    self.currentLength += data.length;
    self.progress.totalUnitCount = self.totalLength;
    self.progress.completedUnitCount = self.currentLength;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.tempPath]) {
        [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
    }
    if (!_fileHandle) {
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempPath];
    }
    [self.fileHandle seekToEndOfFile];
    if (@available(iOS 13.0, *)) {
        __autoreleasing NSError *error = nil;
        [self.fileHandle writeData:data error:&error];
        if (error) {
#if DEBUG
            NSLog(@"JKNetwork_downloadError:%@",error.description);
#endif
        }
    } else {
        // Fallback on earlier versions
        [self.fileHandle writeData:data];
    }
}

@end


@interface JKNetworkBackgroundDownloadTaskDelegate()

@end

@implementation JKNetworkBackgroundDownloadTaskDelegate

- (instancetype)initWithRequest:(__kindof JKDownloadRequest *)request
{
    self = [super initWithRequest:request];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notif
{
    if (self.request.requestTask.state == NSURLSessionTaskStateRunning) {
        [self.request.requestTask resume];
    }
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (self.completionHandler) {
        self.completionHandler(task.response, error);
    }
}
- (void)URLSession:(NSURLSession *)session task:(__kindof NSURLSessionTask *)task
                      didBecomeInvalidWithError:(NSError *)error
{
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        NSURLSessionDownloadTask *downloadTask = (NSURLSessionDownloadTask *)task;
        [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            [resumeData  writeToFile:self.tempPath atomically:YES];
        }];
    } else {
#if DEBUG
        NSAssert(NO, @"make sure [task isKindOfClass:[NSURLSessionDownloadTask class]] be YES");
#endif
    }
    
}

#pragma mark - NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location
{
    NSError *error = nil;
    if (self.parseBlock) {
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:self.tempPath] error:nil];
        error = self.parseBlock(self.request,self.lock);
    }else {
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:self.downloadTargetPath] error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
    }
    
    if (self.completionHandler) {
        self.completionHandler(downloadTask.response,error);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    self.progress.totalUnitCount = totalBytesExpectedToWrite;
    self.progress.completedUnitCount = totalBytesWritten;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                      didResumeAtOffset:(int64_t)fileOffset
                                     expectedTotalBytes:(int64_t)expectedTotalBytes
{
    self.progress.totalUnitCount = expectedTotalBytes;
    self.progress.completedUnitCount = fileOffset;
}


@end
