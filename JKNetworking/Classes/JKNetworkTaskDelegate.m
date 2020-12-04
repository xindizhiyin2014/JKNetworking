//
//  JKNetworkTaskDelegate.m
//  JKNetworking_
//
//  Created by JackLee on 2020/12/4.
//

#import "JKNetworkTaskDelegate.h"
#import "JKBaseRequest.h"
#import "JKNetworkingMacro.h"

@interface JKNetworkTaskDelegate()

@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, assign) int64_t currentLength;
@property (nonatomic, assign) int64_t totalLength;

@end

@implementation JKNetworkTaskDelegate
- (instancetype)initWithRequest:(__kindof JKBaseRequest *)request {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    _currentLength = 0;
    _resumeDataLength = 0;
    _totalLength = 0;
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
    return self;
}

- (void)dealloc {
    [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

#pragma mark - NSProgress Tracking

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(object);
        } else if (self.uploadProgressBlock) {
            self.uploadProgressBlock(object);
        }
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
     id responseObject = nil;
    if (self.completionHandler) {
        self.completionHandler(task.response, responseObject, error);
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
    self.totalLength = self.resumeDataLength + response.expectedContentLength;
    self.currentLength = self.resumeDataLength;
}

- (void)URLSession:(__unused NSURLSession *)session
          dataTask:(__unused NSURLSessionDataTask *)dataTask
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
            NSLog(@"VVNetwork_downloadError:%@",error.description);
#endif
        }
    } else {
        // Fallback on earlier versions
        [self.fileHandle writeData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    
    
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
   
    
}
@end
