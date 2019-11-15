//
//  JKViewController.m
//  JKNetworking
//
//  Created by xindizhiyin2014 on 10/29/2019.
//  Copyright (c) 2019 xindizhiyin2014. All rights reserved.
//

#import "JKViewController.h"
#import "JKBaseRequest.h"
#import "JKNetworking.h"
#import <AFNetworking/AFNetworking.h>
#import "JKMockURLProtocol.h"
@interface JKViewController ()

@end

@implementation JKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
//    [JKNetworkConfig sharedConfig].baseUrl = @"https://123.com";
//    [self singleGetRequest];
//    [[JKNetworkAgent sharedAgent] cancelAllRequests];
//    [self singlePostRequest];
//    [self batchRequest];
//    [self chainRequest];
//    [self downloadRequest];
//    [self priorityFirstRequest];
//    [self priorityFirstRequest1];
//        [self priorityFirstRequest2];
//    [self priorityFirstRequest3];
//    [self mockRequest];
//    [self mockRequest1];

    
}

- (void)singleGetRequest
{
 JKBaseRequest *request = [JKBaseRequest new];
    request.requestUrl = @"/a1";
    request.responseSerializerType = JKResponseSerializerTypeJSON;
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
}

- (void)singlePostRequest
{
      JKBaseRequest *request = [JKBaseRequest new];
            request.requestUrl = @"/a2";
            request.requestMethod = JKRequestMethodPOST;
            request.responseSerializerType = JKResponseSerializerTypeJSON;
            request.requestArgument = @{@"name":@"jack"};
            [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
                       NSLog(@"BBB %@",request.responseJSONObject);

            } failure:^(__kindof JKBaseRequest * request) {
                
            }];
}

- (void)batchRequest
{
          JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.requestUrl = @"/a2";
            request2.requestMethod = JKRequestMethodPOST;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestArgument = @{@"name":@"jack"};
            JKBatchRequest *batchRequest = [[JKBatchRequest alloc] initWithRequestArray:@[request1,request2]];
            [batchRequest startWithCompletionBlockWithSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                JKBaseRequest *requestA = batchRequest.requestArray.firstObject;
                JKBaseRequest *requestB = batchRequest.requestArray.lastObject;
                NSLog(@"AAA %@",requestA.responseJSONObject);

                NSLog(@"BBB %@",requestB.responseJSONObject);

    
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                
            }];
        
}

- (void)chainRequest
{
    JKBaseRequest *request1 = [JKBaseRequest new];
    request1.requestUrl = @"/a1";
    request1.responseSerializerType = JKResponseSerializerTypeJSON;
    JKBaseRequest *request2 = [JKBaseRequest new];
    request2.requestUrl = @"/a2";
    request2.requestMethod = JKRequestMethodPOST;
    request2.responseSerializerType = JKResponseSerializerTypeJSON;
    request2.requestArgument = @{@"name":@"jack"};
    JKChainRequest *chainRequest = [JKChainRequest new];
    [chainRequest addRequest:request1 success:^(__kindof JKBaseRequest * request1) {
     NSLog(@"AAA %@",request1.responseJSONObject);
    }];
    
    [chainRequest addRequest:request2 success:^(__kindof JKBaseRequest * request2) {
      NSLog(@"BBB %@",request2.responseJSONObject);
    }];
    [chainRequest startWithCompletionBlockWithSuccess:^(JKChainRequest * _Nonnull chainRequest) {
        JKBaseRequest *requestA = chainRequest.requestArray.firstObject;
        JKBaseRequest *requestB = chainRequest.requestArray.lastObject;
        NSLog(@"CCC %@",requestA.responseJSONObject);

        NSLog(@"DDD %@",requestB.responseJSONObject);
    } failure:^(JKChainRequest * _Nonnull chainRequest) {
        
    }];
}

- (void)downloadRequest
{
    JKBaseDownloadRequest *downloadRequest = [JKBaseDownloadRequest initWithUrl:@"http://g.hiphotos.baidu.com/image/pic/item/c2cec3fdfc03924590b2a9b58d94a4c27d1e2500.jpg"];

    [downloadRequest downloadWithProgress:^(NSProgress * _Nonnull downloadProgress) {
        NSLog(@"progress %@",downloadProgress.localizedDescription);
    } success:^(__kindof JKBaseRequest * request) {
        NSLog(@"success %@",downloadRequest.downloadedFilePath);
    } failure:^(__kindof JKBaseRequest * request) {
        NSLog(@"failure");
    }];
    
}

- (void)priorityFirstRequest
{
   JKBaseRequest *request = [JKBaseRequest new];
    request.requestUrl = @"/a1";
    request.responseSerializerType = JKResponseSerializerTypeJSON;
    
    [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:request];
    
           JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a3";
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.requestUrl = @"/a2";
            request2.requestMethod = JKRequestMethodPOST;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestArgument = @{@"name":@"jack"};
            JKBatchRequest *batchRequest = [[JKBatchRequest alloc] initWithRequestArray:@[request1,request2]];
            [batchRequest startWithCompletionBlockWithSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                JKBaseRequest *requestA = batchRequest.requestArray.firstObject;
                JKBaseRequest *requestB = batchRequest.requestArray.lastObject;
                NSLog(@"AAA_1 %@",requestA.responseJSONObject);

                NSLog(@"BBB_1 %@",requestB.responseJSONObject);

    
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                
            }];
    
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
   
}

- (void)priorityFirstRequest1
{
  JKBaseRequest *request = [JKBaseRequest new];
  request.requestUrl = @"/a1";
  request.responseSerializerType = JKResponseSerializerTypeJSON;
  
  [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:request];
    
    JKBaseRequest *request1 = [JKBaseRequest new];
    request1.requestUrl = @"/a3";
    request1.responseSerializerType = JKResponseSerializerTypeJSON;
    JKBaseRequest *request2 = [JKBaseRequest new];
    request2.requestUrl = @"/a2";
    request2.requestMethod = JKRequestMethodPOST;
    request2.responseSerializerType = JKResponseSerializerTypeJSON;
    request2.requestArgument = @{@"name":@"jack"};
    JKChainRequest *chainRequest = [JKChainRequest new];
    [chainRequest addRequest:request1 success:^(__kindof JKBaseRequest * request1) {
     NSLog(@"AAA a3 %@",request1.responseJSONObject);
    }];
    
    [chainRequest addRequest:request2 success:^(__kindof JKBaseRequest * request2) {
      NSLog(@"BBB  a2%@",request2.responseJSONObject);
    }];
    [chainRequest startWithCompletionBlockWithSuccess:^(JKChainRequest * _Nonnull chainRequest) {
        JKBaseRequest *requestA = chainRequest.requestArray.firstObject;
        JKBaseRequest *requestB = chainRequest.requestArray.lastObject;
        NSLog(@"CCC %@",requestA.responseJSONObject);

        NSLog(@"DDD %@",requestB.responseJSONObject);
    } failure:^(JKChainRequest * _Nonnull chainRequest) {
        
    }];
    
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
    
}

- (void)priorityFirstRequest2
{
    JKBaseRequest *request1 = [JKBaseRequest new];
    request1.requestUrl = @"/a3";
    request1.responseSerializerType = JKResponseSerializerTypeJSON;
    JKBaseRequest *request2 = [JKBaseRequest new];
    request2.requestUrl = @"/a2";
    request2.requestMethod = JKRequestMethodPOST;
    request2.responseSerializerType = JKResponseSerializerTypeJSON;
    request2.requestArgument = @{@"name":@"jack"};
    JKChainRequest *chainRequest = [JKChainRequest new];
    [chainRequest addRequest:request1 success:^(__kindof JKBaseRequest * request1) {
     NSLog(@"AAA a3 %@",request1.responseJSONObject);
    }];
    
    [chainRequest addRequest:request2 success:^(__kindof JKBaseRequest * request2) {
      NSLog(@"BBB  a2%@",request2.responseJSONObject);
    }];
    [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:chainRequest];


    JKBaseRequest *request = [JKBaseRequest new];
    request.requestUrl = @"/a1";
    request.responseSerializerType = JKResponseSerializerTypeJSON;
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
    
    [chainRequest startWithCompletionBlockWithSuccess:^(JKChainRequest * _Nonnull chainRequest) {
        JKBaseRequest *requestA = chainRequest.requestArray.firstObject;
        JKBaseRequest *requestB = chainRequest.requestArray.lastObject;
        NSLog(@"CCC %@",requestA.responseJSONObject);

        NSLog(@"DDD %@",requestB.responseJSONObject);
    } failure:^(JKChainRequest * _Nonnull chainRequest) {
        
    }];
    
}

- (void)priorityFirstRequest3
{
    
    
    
           JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a3";
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.requestUrl = @"/a2";
            request2.requestMethod = JKRequestMethodPOST;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestArgument = @{@"name":@"jack"};
            JKBatchRequest *batchRequest = [[JKBatchRequest alloc] initWithRequestArray:@[request1,request2]];
    [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:batchRequest];

            
    
    JKBaseRequest *request = [JKBaseRequest new];
    request.requestUrl = @"/a1";
    request.responseSerializerType = JKResponseSerializerTypeJSON;
    
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
    
    [batchRequest startWithCompletionBlockWithSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                JKBaseRequest *requestA = batchRequest.requestArray.firstObject;
                JKBaseRequest *requestB = batchRequest.requestArray.lastObject;
                NSLog(@"AAA_1 %@",requestA.responseJSONObject);

                NSLog(@"BBB_1 %@",requestB.responseJSONObject);

    
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                
            }];
    
}

- (void)mockRequest
{
   [JKNetworkConfig sharedConfig].baseUrl = @"https://www.baidu.com";
    [JKNetworkConfig sharedConfig].mockBaseUrl = @"https://123.com";
    [JKNetworkConfig sharedConfig].isMock = YES;
    NSDictionary *config = @{@"GET,/a1":@{}};
    [JKMockManager initMockConfig:config];
    JKBaseRequest *request = [JKBaseRequest new];
    request.requestUrl = @"/a1";
    request.responseSerializerType = JKResponseSerializerTypeJSON;
    [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
        NSLog(@"AAA %@",request.responseJSONObject);
    } failure:^(__kindof JKBaseRequest * request) {
        
    }];
}

- (void)mockRequest1
{
    [JKNetworkConfig sharedConfig].mockBaseUrl = @"https://123.com";
    [JKNetworkConfig sharedConfig].isMock = YES;
    NSDictionary *config = @{@"GET,/a1":@{}};
    [JKMockManager initMockConfig:config];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.protocolClasses = @[[JKMockURLProtocol class]];
    AFHTTPSessionManager *sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    AFHTTPRequestSerializer *requestSerializer = [AFHTTPRequestSerializer serializer];
    sessionManager.securityPolicy = [AFSecurityPolicy defaultPolicy];
    sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSMutableURLRequest *request = [requestSerializer requestWithMethod:@"GET" URLString:@"https://www.baidu.com/a1" parameters:nil error:nil];
   NSURLSessionTask *dataTask = [sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSLog(@"AAA %@",responseObject);
    }];
    [dataTask resume];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
