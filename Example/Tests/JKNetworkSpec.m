//
//  JKNetworkSpec.m
//  JKNetworking
//
//  Created by JackLee on 2020/7/23.
//  Copyright 2020 xindizhiyin2014. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import <AFNetworking/AFNetworking.h>
#import "JKNetworking.h"

SPEC_BEGIN(JKRequestSpec)

describe(@"BaseRequest", ^{
         beforeAll(^{
 #if DEBUG
     AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
     policy.validatesDomainName = NO;
     policy.allowInvalidCertificates = YES;
     [JKNetworkConfig sharedConfig].securityPolicy = policy;
 #endif
    [JKNetworkConfig sharedConfig].baseUrl = @"https://123/mock/17";
});
    
    context(@"single request", ^{

        it(@"return success", ^{
            JKBaseRequest *request = [JKBaseRequest new];
            request.requestUrl = @"/a1";
            request.requestSerializerType = JKRequestSerializerTypeHTTP;
            request.responseSerializerType = JKResponseSerializerTypeJSON;

            __block BOOL success = NO;
            [request startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
                success = YES;
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            [[expectFutureValue(theValue(success)) shouldAfterWaitOf(5)] beYes];
        });

        it(@"return failure", ^{
            //失败的网络请求
            JKBaseRequest *request = [JKBaseRequest new];
            request.baseUrl = @"https://aacoioio.com";
            request.requestUrl = @"/aaa";
            request.requestSerializerType = JKRequestSerializerTypeHTTP;
            request.responseSerializerType = JKResponseSerializerTypeJSON;
            request.requestTimeoutInterval = 5;
            __block BOOL fail = NO;
            [request startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail = YES;
            }];
            [[expectFutureValue(theValue(fail)) shouldAfterWaitOf(6)] beYes];
        });

        it(@"use same request instance repeat start requests", ^{
            JKBaseRequest *request = [JKBaseRequest new];
            request.requestUrl = @"/a1";
            request.requestSerializerType = JKRequestSerializerTypeHTTP;
            request.responseSerializerType = JKResponseSerializerTypeJSON;

            __block BOOL success = NO;
            [request startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
                success = YES;
                [[request.responseObject shouldNot] beNil];
                [[request.responseJSONObject shouldNot] beNil];
                [request startWithCompletionSuccess:nil failure:nil];
                [[request.responseObject should] beNil];
                [[request.responseJSONObject should] beNil];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            [[expectFutureValue(theValue(success)) shouldAfterWaitOf(3)] beYes];
        });

        it(@"use cache", ^{
            // 后续缓存升级后，进行单元测试
        });

    });

    context(@"batch request", ^{
        beforeEach(^{
            [[JKNetworkAgent sharedAgent] cancelAllRequests];
        });
        it(@"addRequest,request is not a JKBaseRequest", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKChainRequest *request = [JKChainRequest new];
            [[theBlock(^{
                [batchRequest addRequest:request];
            }) should] raiseWithReason:@"makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
        });

        it(@"addRequest,request has added in", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            [batchRequest addRequest:request];
            [[batchRequest.requestArray should] haveCountOf:1];
            [[theBlock(^{
                [batchRequest addRequest:request];
            }) should] raiseWithReason:@"request was added"];
        });

        it(@"addRequestsWithArray,array has repeated requests", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            NSArray *array = @[request,request];
            [[theBlock(^{
                [batchRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"requestArray has duplicated requests"];
        });

        it(@"addRequestsWithArray,array has a request not a JKBaseRequest", ^{
           JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            JKChainRequest *chainRequest = [JKChainRequest new];
            NSArray *array = @[request,chainRequest];
            [[theBlock(^{
                [batchRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
        });

        it(@"addRequestsWithArray,array has a request add in", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            JKBaseRequest *request2 = [JKBaseRequest new];
            [batchRequest addRequest:request1];
            NSArray *array = @[request1,request2];
            [[theBlock(^{
                [batchRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"requestArray has common request with the added requests"];
        });

        it(@"addRequestsWithArray,normal", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            JKBaseRequest *request2 = [JKBaseRequest new];
            NSArray *array = @[request1,request2];
            [batchRequest addRequestsWithArray:array];
            [[batchRequest.requestArray should] haveCountOf:2];
        });

        it(@"configRequireSuccessRequests,requests is equal requestArray,require all success,all request success", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success1 = NO;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success1 = YES;
                [[request should] equal:request1];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.requestUrl = @"/a2";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success2 = NO;
            [JKBatchRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success2 = YES;
                [[request should] equal:request2];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            NSArray *array = @[request1,request2];
            [batchRequest addRequestsWithArray:array];
            [batchRequest configRequireSuccessRequests:array];
            __block BOOL success3 = NO;
            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                success3 = YES;
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {

            }];

            [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(success3)) shouldAfterWaitOf(6)] beYes];

        });
        
        it(@"configRequireSuccessRequests,requests is only has request1,require request1 success,all request success", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success1 = NO;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success1 = YES;
                [[request should] equal:request1];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            //失败的网络请求
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.baseUrl = @"https://aacoioio.com";
            request2.requestUrl = @"/aaa";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestTimeoutInterval = 3;
            __block BOOL fail1 = NO;
            [JKBatchRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {
                
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail1 = YES;
                [[request should] equal:request2];

            }];
            NSArray *array = @[request1,request2];
            [batchRequest addRequestsWithArray:array];
            [batchRequest configRequireSuccessRequests:@[request1]];
            __block BOOL success3 = NO;
            __block BOOL fail2 = NO;

            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                success3 = YES;
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                fail2 = YES;
            }];

            [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(success3)) shouldAfterWaitOf(6)] beYes];
            

        });
        
        it(@"configRequireSuccessRequests,requests is equal requestArray,one request failed", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            //失败的网络请求
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.baseUrl = @"https://aacoioio.com";
            request2.requestUrl = @"/aaa";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestTimeoutInterval = 3;
            __block BOOL fail1 = NO;
            [JKBatchRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail1 = YES;
                [[request should] equal:request2];

            }];

            JKBaseRequest *request3 = [JKBaseRequest new];
            request3.requestUrl = @"/a2";
            request3.requestMethod = JKRequestMethodPOST;
            request3.requestSerializerType = JKRequestSerializerTypeHTTP;
            request3.responseSerializerType = JKResponseSerializerTypeJSON;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];

            NSArray *array = @[request1,request2,request3];
            [batchRequest addRequestsWithArray:array];
            [batchRequest configRequireSuccessRequests:array];
            __block BOOL fail2 = NO;
            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {

            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                fail2 = YES;
                [[theValue([batchRequest.failedRequests containsObject:request2]) should] beYes];
            }];

            [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beYes];
        });

        it(@"configRequireSuccessRequests,requests is nil,one request success", ^{
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            //失败的网络请求
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.baseUrl = @"https://aacoioio.com";
            request2.requestUrl = @"/aaa";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestTimeoutInterval = 3;
            __block BOOL fail1 = NO;
            [JKBatchRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail1 = YES;
                [[request should] equal:request2];

            }];
            //失败的网络请求
            JKBaseRequest *request3 = [JKBaseRequest new];
            request3.baseUrl = @"https://aacoioio.com";
            request3.requestUrl = @"/aaa1";
            request3.requestSerializerType = JKRequestSerializerTypeHTTP;
            request3.responseSerializerType = JKResponseSerializerTypeJSON;
            request3.requestTimeoutInterval = 3;
            __block BOOL fail2 = NO;
            [JKBatchRequest configNormalRequest:request3 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail2 = YES;
                [[request should] equal:request3];

            }];

            NSArray *array = @[request1,request2,request3];
            [batchRequest addRequestsWithArray:array];
            __block BOOL success = NO;
            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
                success = YES;
                [[expectFutureValue(theValue([batchRequest.failedRequests containsObject:request2])) shouldAfterWaitOf(5)] beYes];
                [[expectFutureValue(theValue([batchRequest.failedRequests containsObject:request3])) shouldAfterWaitOf(5)] beYes];
            } failure:^(JKBatchRequest * _Nonnull batchRequest) {

            }];

            [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beYes];


        });

        it(@"configRequireSuccessRequests,requests is nil,all requests failed", ^{
            //失败的网络请求
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.baseUrl = @"https://aacoioio.com";
            request1.requestUrl = @"/aaa1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            request1.requestTimeoutInterval = 3;
            __block BOOL fail1 = NO;
            [JKBatchRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail1 = YES;
                [[request should] equal:request1];

            }];
            //失败的网络请求
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.baseUrl = @"https://aacoioio.com";
            request2.requestUrl = @"/aaa2";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestTimeoutInterval = 3;
            __block BOOL fail2 = NO;
            [JKBatchRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail2 = YES;
                [[request should] equal:request2];

            }];
            //失败的网络请求
            JKBaseRequest *request3 = [JKBaseRequest new];
            request3.baseUrl = @"https://aacoioio.com";
            request3.requestUrl = @"/aaa3";
            request3.requestSerializerType = JKRequestSerializerTypeHTTP;
            request3.responseSerializerType = JKResponseSerializerTypeJSON;
            request3.requestTimeoutInterval = 3;
            __block BOOL fail3 = NO;
            [JKBatchRequest configNormalRequest:request3 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail3 = YES;
                [[request should] equal:request3];

            }];

            NSArray *array = @[request1,request2,request3];
            [batchRequest addRequestsWithArray:array];
            __block BOOL fail4 = NO;
            [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {

            } failure:^(JKBatchRequest * _Nonnull batchRequest) {
                fail4 = YES;
                [[expectFutureValue(theValue([batchRequest.failedRequests containsObject:request1])) shouldAfterWaitOf(5)] beYes];
                [[expectFutureValue(theValue([batchRequest.failedRequests containsObject:request2])) shouldAfterWaitOf(5)] beYes];
                [[expectFutureValue(theValue([batchRequest.failedRequests containsObject:request3])) shouldAfterWaitOf(5)] beYes];
            }];

            [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail3)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail4)) shouldAfterWaitOf(5)] beYes];

        });
        
    });
    
    context(@"chain request", ^{

        it(@"addRequest,request is not a JKBaseRequest", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBatchRequest *request = [JKBatchRequest new];
            [[theBlock(^{
                [chainRequest addRequest:request];
            }) should] raiseWithReason:@"makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
        });

        it(@"addRequest,request has added in", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            [chainRequest addRequest:request];
            [[chainRequest.requestArray should] haveCountOf:1];
            [[theBlock(^{
                [chainRequest addRequest:request];
            }) should] raiseWithReason:@"request was added"];
        });

        it(@"addRequestsWithArray,array has repeated requests", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            NSArray *array = @[request,request];
            [[theBlock(^{
                [chainRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"requestArray has duplicated requests"];
        });

        it(@"addRequestsWithArray,array has a request not a JKBaseRequest", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request = [JKBaseRequest new];
            JKBatchRequest *batchRequest = [JKBatchRequest new];
            NSArray *array = @[request,batchRequest];
            [[theBlock(^{
                [chainRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
        });

        it(@"addRequestsWithArray,array has a request add in", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            JKBaseRequest *request2 = [JKBaseRequest new];
            [chainRequest addRequest:request1];
            NSArray *array = @[request1,request2];
            [[theBlock(^{
                [chainRequest addRequestsWithArray:array];
            }) should] raiseWithReason:@"requestArray has common request with the added requests"];
        });

        it(@"addRequestsWithArray,normal", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            JKBaseRequest *request2 = [JKBaseRequest new];
            NSArray *array = @[request1,request2];
            [chainRequest addRequestsWithArray:array];
            [[chainRequest.requestArray should] haveCountOf:2];
        });

        it(@"all requests success", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success1 = NO;
            [JKChainRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success1 = YES;
                [[request should] equal:request1];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.requestUrl = @"/a2";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success2 = NO;
            [JKChainRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success2 = YES;
                [[request should] equal:request2];
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            NSArray *array = @[request1,request2];
            [chainRequest addRequestsWithArray:array];
            __block BOOL success3 = NO;
            [chainRequest startWithCompletionSuccess:^(JKChainRequest * _Nonnull chainRequest) {
                success3 = YES;
            } failure:^(JKChainRequest * _Nonnull chainRequest) {

            }];

            [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(6)] beYes];
            [[expectFutureValue(theValue(success3)) shouldAfterWaitOf(6)] beYes];
        });

        it(@"a request in requests not first,not last, failed", ^{
            JKChainRequest *chainRequest = [JKChainRequest new];
            JKBaseRequest *request1 = [JKBaseRequest new];
            request1.requestUrl = @"/a1";
            request1.requestSerializerType = JKRequestSerializerTypeHTTP;
            request1.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL success1 = NO;
            [JKChainRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success1 = YES;
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {

            }];
            //失败的网络请求
            JKBaseRequest *request2 = [JKBaseRequest new];
            request2.baseUrl = @"https://aacoioio.com";
            request2.requestUrl = @"/aaa";
            request2.requestSerializerType = JKRequestSerializerTypeHTTP;
            request2.responseSerializerType = JKResponseSerializerTypeJSON;
            request2.requestTimeoutInterval = 3;
            __block BOOL fail1 = NO;
            [JKChainRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {

            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail1 = YES;
                [[request should] equal:request2];

            }];

            JKBaseRequest *request3 = [JKBaseRequest new];
            request3.requestUrl = @"/a2";
            request3.requestMethod = JKRequestMethodPOST;
            request3.requestSerializerType = JKRequestSerializerTypeHTTP;
            request3.responseSerializerType = JKResponseSerializerTypeJSON;
            __block BOOL fail2 = NO;
            __block BOOL success2 = NO;
            [JKChainRequest configNormalRequest:request3 success:^(__kindof JKBaseRequest * _Nonnull request) {
                success2 = YES;
            } failure:^(__kindof JKBaseRequest * _Nonnull request) {
                fail2 = YES;
            }];

            NSArray *array = @[request1,request2,request3];
            [chainRequest addRequestsWithArray:array];
            __block BOOL fail3 = NO;
            [chainRequest startWithCompletionSuccess:^(JKChainRequest * _Nonnull chainRequest) {

            } failure:^(JKChainRequest * _Nonnull chainRequest) {
                fail3 = YES;
                [[expectFutureValue(theValue([chainRequest.failedRequest isEqual:request2])) shouldAfterWaitOf(5)] beYes];
            }];

            [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
            [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beNo];
            [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(5)] beNo];
            [[expectFutureValue(theValue(fail3)) shouldAfterWaitOf(5)] beYes];
        });
    });


});

SPEC_END


SPEC_BEGIN(JKNetworkAgentSpec)

describe(@"JKNetworkAgent", ^{
    beforeEach(^{
#if DEBUG
        AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
        policy.validatesDomainName = NO;
        policy.allowInvalidCertificates = YES;
        [JKNetworkConfig sharedConfig].securityPolicy = policy;
#endif
        [JKNetworkConfig sharedConfig].baseUrl = @"https://123/mock/17";
        [[JKNetworkAgent sharedAgent] cancelAllRequests];

    });

    it(@"addRequest,request is a single request", ^{
        JKBaseRequest *request = [JKBaseRequest new];
        request.requestUrl = @"/a1";
        request.requestSerializerType = JKRequestSerializerTypeHTTP;
        request.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addRequest:request];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:1];
        [[theValue([[[JKNetworkAgent sharedAgent] allRequests] containsObject:request]) should] beYes];
    });

    it(@"addRequest,request is not a single request", ^{
        JKBaseRequest *request = [JKBaseRequest new];
        request.requestUrl = @"/a1";
        request.requestSerializerType = JKRequestSerializerTypeHTTP;
        request.responseSerializerType = JKResponseSerializerTypeJSON;
        JKBatchRequest *batchRequest = [JKBatchRequest new];
        [batchRequest addRequest:request];
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addRequest:batchRequest];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
    });

    it(@"addRequest,request is nil", ^{

        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"cancelRequest,request is nil", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] cancelRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"cancelRequest,request is a single request", ^{
        JKBaseRequest *request = [JKBaseRequest new];
        request.requestUrl = @"/a1";
        request.requestSerializerType = JKRequestSerializerTypeHTTP;
        request.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addRequest:request];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:1];
        [[theValue([[[JKNetworkAgent sharedAgent] allRequests] containsObject:request]) should] beYes];
        [[JKNetworkAgent sharedAgent] cancelRequest:request];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:0];

    });

    it(@"cancelRequest,request is not a single request", ^{
        JKBaseRequest *request = [JKBaseRequest new];
        request.requestUrl = @"/a1";
        request.requestSerializerType = JKRequestSerializerTypeHTTP;
        request.responseSerializerType = JKResponseSerializerTypeJSON;
        JKBatchRequest *batchRequest = [JKBatchRequest new];
        [batchRequest addRequest:request];
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] cancelRequest:batchRequest];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKBaseRequest class]] be YES"];
    });

    it(@"addBatchRequest,request is nil", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addBatchRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"addBatchRequest,request is a batchRequest", ^{
        JKBatchRequest *batchRequest = [JKBatchRequest new];

        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [batchRequest addRequest:request1];
        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a1";
        request2.requestMethod = JKRequestMethodPOST;
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        [batchRequest addRequest:request2];
        [[JKNetworkAgent sharedAgent] addBatchRequest:batchRequest];
        [[theValue([[[JKNetworkAgent sharedAgent] allRequests] containsObject:request1]) should] beYes];
        [[theValue([[[JKNetworkAgent sharedAgent] allRequests] containsObject:request2]) should] beYes];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:2];
    });

    it(@"addBatchRequest,request is not a batchRequest", ^{
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addBatchRequest:request1];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKBatchRequest class]] be YES"];
    });

    it(@"removeBatchRequest,request is a batchRequest", ^{
       JKBatchRequest *batchRequest = [JKBatchRequest new];

       JKBaseRequest *request1 = [JKBaseRequest new];
       request1.requestUrl = @"/a1";
       request1.requestSerializerType = JKRequestSerializerTypeHTTP;
       request1.responseSerializerType = JKResponseSerializerTypeJSON;
       [batchRequest addRequest:request1];
       [[JKNetworkAgent sharedAgent] removeBatchRequest:batchRequest];
       [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:0];
    });

    it(@"removeBatchRequest,request is nil", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] removeBatchRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"removeBatchRequest,request is not a batchREquest", ^{

        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] removeBatchRequest:request1];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKBatchRequest class]] be YES"];
    });

    it(@"addChainRequest,request is nil", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addChainRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"addChainRequest,request is a chainRequest", ^{
        JKChainRequest *chainRequest = [JKChainRequest new];
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        __block BOOL success1 = NO;
        [JKChainRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
            success1 = YES;
            [[request should] equal:request1];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        __block BOOL success2 = NO;
        [JKChainRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[request should] equal:request2];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        NSArray *array = @[request1,request2];
        [chainRequest addRequestsWithArray:array];
        [[JKNetworkAgent sharedAgent] addChainRequest:chainRequest];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:3];
        [[JKNetworkAgent sharedAgent] removeChainRequest:chainRequest];

    });

    it(@"addChainRequest,request is not a chainRequest", ^{
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addChainRequest:request1];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKChainRequest class]] be YES"];
    });

    it(@"removeChainRequest,request is a chainRequest", ^{
        JKChainRequest *chainRequest = [JKChainRequest new];
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        __block BOOL success1 = NO;
        [JKChainRequest configNormalRequest:request1 success:^(__kindof JKBaseRequest * _Nonnull request) {
            success1 = YES;
            [[request should] equal:request1];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        __block BOOL success2 = NO;
        [JKChainRequest configNormalRequest:request2 success:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[request should] equal:request2];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        NSArray *array = @[request1,request2];
        [chainRequest addRequestsWithArray:array];
        [[JKNetworkAgent sharedAgent] addChainRequest:chainRequest];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:3];
        [[JKNetworkAgent sharedAgent] removeChainRequest:chainRequest];
        [[[[JKNetworkAgent sharedAgent] allRequests] should] haveCountOf:0];
    });

    it(@"removeChainRequest,request is nil", ^{

        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] removeChainRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"removeChainRequest,request is not a chainRequest", ^{
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] removeChainRequest:request1];
        }) should] raiseWithReason:@"please makesure [request isKindOfClass:[JKChainRequest class]] be YES"];
    });

    it(@"addPriorityFirstRequest,request is nil", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:nil];
        }) should] raiseWithReason:@"request can't be nil"];
    });

    it(@"addPriorityFirstRequest,request is unsupported", ^{
        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:[NSObject new]];
        }) should] raiseWithReason:@"no support this request as a PriorityFirstRequest"];
    });

    it(@"addPriorityFirstRequest,has request started", ^{
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addRequest:request1];
        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;

        [[theBlock(^{
            [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:request2];
        }) should] raiseWithReason:@"addPriorityFirstRequest func must use before any request started"];
    });

    it(@"addPriorityFirstRequest,request is a single request, success", ^{
        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:request1];

        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        __block BOOL success1 = NO;
        __block BOOL success2 = NO;
        [request2 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[theValue(success1) should] beYes];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        [request1 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success1 = YES;
            [[theValue(success2) should] beNo];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];
        [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(3)] beYes];
        [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(3)] beYes];
    });

    it(@"addPriorityFirstRequest,request is a single request, fail", ^{

        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.baseUrl = @"https://aacoioio.com";
        request1.requestUrl = @"/aaa1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;
        request1.requestTimeoutInterval = 3;

        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a1";
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:request1];

        __block BOOL success1 = NO;
        __block BOOL success2 = NO;
        __block BOOL fail1 = NO;
        __block BOOL fail2 = NO;
        [request2 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[theValue(success1) should] beYes];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {
            fail2 = YES;
        }];
        [request1 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success1 = YES;
            [[theValue(success2) should] beNo];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {
            fail1 = YES;
        }];
        [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(5)] beNo];
        [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(5)] beNo];
        [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
        [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beNo];
    });

    it(@"addPriorityFirstRequest,request is a batchRequest,success", ^{
        JKBatchRequest *batchRequest = [JKBatchRequest new];

        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;

        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestMethod = JKRequestMethodPOST;
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        [batchRequest addRequestsWithArray:@[request1,request2]];

        [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:batchRequest];

        JKBaseRequest *request3 = [JKBaseRequest new];
        request3.requestUrl = @"/a1";
        request3.requestSerializerType = JKRequestSerializerTypeHTTP;
        request3.responseSerializerType = JKResponseSerializerTypeJSON;

        __block BOOL success1 = NO;
        __block BOOL success2 = NO;
        [request3 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[theValue(success1) should] beYes];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];

        [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
            success1 = YES;
            [[theValue(success2) should] beNo];
        } failure:^(JKBatchRequest * _Nonnull batchRequest) {

        }];

       [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(3)] beYes];
        [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(3)] beYes];

    });

    it(@"addPriorityFirstRequest,request is a batchRequest,fail", ^{

      JKBatchRequest *batchRequest = [JKBatchRequest new];

      JKBaseRequest *request1 = [JKBaseRequest new];
      request1.baseUrl = @"https://aacoioio.com";
      request1.requestUrl = @"/aaa1";
      request1.requestSerializerType = JKRequestSerializerTypeHTTP;
      request1.responseSerializerType = JKResponseSerializerTypeJSON;
      request1.requestTimeoutInterval = 3;

      JKBaseRequest *request2 = [JKBaseRequest new];
      request2.requestUrl = @"/a2";
      request2.requestMethod = JKRequestMethodPOST;
      request2.requestSerializerType = JKRequestSerializerTypeHTTP;
      request2.responseSerializerType = JKResponseSerializerTypeJSON;
      [batchRequest addRequestsWithArray:@[request1,request2]];

      [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:batchRequest];


      JKBaseRequest *request3 = [JKBaseRequest new];
      request3.requestUrl = @"/a1";
      request3.requestSerializerType = JKRequestSerializerTypeHTTP;
      request3.responseSerializerType = JKResponseSerializerTypeJSON;

      __block BOOL success1 = NO;
      __block BOOL success2 = NO;
      __block BOOL fail1 = NO;
      __block BOOL fail2 = NO;
      [request3 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
          success2 = YES;
      } failure:^(__kindof JKBaseRequest * _Nonnull request) {
          fail2 = YES;
      }];

      [batchRequest startWithCompletionSuccess:^(JKBatchRequest * _Nonnull batchRequest) {
          success1 = YES;
      } failure:^(JKBatchRequest * _Nonnull batchRequest) {
          fail1 = YES;
      }];

      [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(5)] beNo];
      [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(5)] beNo];
      [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
      [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beNo];
    });

    it(@"addPriorityFirstRequest,request is a chainRequest,success", ^{
        JKChainRequest *chainRequest = [JKChainRequest new];

        JKBaseRequest *request1 = [JKBaseRequest new];
        request1.requestUrl = @"/a1";
        request1.requestSerializerType = JKRequestSerializerTypeHTTP;
        request1.responseSerializerType = JKResponseSerializerTypeJSON;

        JKBaseRequest *request2 = [JKBaseRequest new];
        request2.requestUrl = @"/a2";
        request2.requestMethod = JKRequestMethodPOST;
        request2.requestSerializerType = JKRequestSerializerTypeHTTP;
        request2.responseSerializerType = JKResponseSerializerTypeJSON;
        [chainRequest addRequestsWithArray:@[request1,request2]];

        JKBaseRequest *request3 = [JKBaseRequest new];
        request3.requestUrl = @"/a1";
        request3.requestSerializerType = JKRequestSerializerTypeHTTP;
        request3.responseSerializerType = JKResponseSerializerTypeJSON;
        [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:chainRequest];

        __block BOOL success1 = NO;
        __block BOOL success2 = NO;
        [request3 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
            success2 = YES;
            [[theValue(success1) should] beYes];
        } failure:^(__kindof JKBaseRequest * _Nonnull request) {

        }];

        [chainRequest startWithCompletionSuccess:^(JKChainRequest * _Nonnull chainRequest) {
            success1 = YES;
            [[theValue(success2) should] beNo];
        } failure:^(JKChainRequest * _Nonnull chainRequest) {

        }];

         [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(3)] beYes];
         [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(3)] beYes];
    });

    it(@"addPriorityFirstRequest,request is a chainRequest,fail", ^{
        JKChainRequest *chainRequest = [JKChainRequest new];

         JKBaseRequest *request1 = [JKBaseRequest new];
         request1.baseUrl = @"https://aacoioio.com";
         request1.requestUrl = @"/aaa1";
         request1.requestSerializerType = JKRequestSerializerTypeHTTP;
         request1.responseSerializerType = JKResponseSerializerTypeJSON;
        request1.requestTimeoutInterval = 3;

         JKBaseRequest *request2 = [JKBaseRequest new];
         request2.requestUrl = @"/a2";
         request2.requestMethod = JKRequestMethodPOST;
         request2.requestSerializerType = JKRequestSerializerTypeHTTP;
         request2.responseSerializerType = JKResponseSerializerTypeJSON;
         [chainRequest addRequestsWithArray:@[request1,request2]];

         [[JKNetworkAgent sharedAgent] addPriorityFirstRequest:chainRequest];


         JKBaseRequest *request3 = [JKBaseRequest new];
         request3.requestUrl = @"/a1";
         request3.requestSerializerType = JKRequestSerializerTypeHTTP;
         request3.responseSerializerType = JKResponseSerializerTypeJSON;

         __block BOOL success1 = NO;
         __block BOOL success2 = NO;
         __block BOOL fail1 = NO;
         __block BOOL fail2 = NO;
         [request3 startWithCompletionSuccess:^(__kindof JKBaseRequest * _Nonnull request) {
             success2 = YES;
         } failure:^(__kindof JKBaseRequest * _Nonnull request) {
             fail2 = YES;
         }];

        [chainRequest startWithCompletionSuccess:^(JKChainRequest * _Nonnull chainRequest) {
            success1 = YES;
        } failure:^(JKChainRequest * _Nonnull chainRequest) {
            fail1 = YES;
        }];

         [[expectFutureValue(theValue(success1)) shouldAfterWaitOf(5)] beNo];
         [[expectFutureValue(theValue(success2)) shouldAfterWaitOf(5)] beNo];
         [[expectFutureValue(theValue(fail1)) shouldAfterWaitOf(5)] beYes];
         [[expectFutureValue(theValue(fail2)) shouldAfterWaitOf(5)] beNo];
    });
    
   
});

SPEC_END
