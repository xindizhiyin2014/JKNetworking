//
//  JKBaseRequestSpec.m
//  JKNetworking
//
//  Created by JackLee on 2019/11/14.
//  Copyright 2019 xindizhiyin2014. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "JKBaseRequest.h"
#import "JKNetworking.h"
#import <JKDataHelper/JKDataHelper.h>

SPEC_BEGIN(JKBaseRequestSpec)

describe(@"JKBaseRequest", ^{
         context(@"test JkBaseRequest", ^{
    beforeAll(^{
        [JKNetworkConfig sharedConfig].baseUrl = @"https://www.baidu.com/mock/17";
    });
    it(@"single GET request", ^{
        JKBaseRequest *request = [JKBaseRequest new];
        request.requestUrl = @"/a1";
        request.requestSerializerType = JKResponseSerializerTypeJSON;
        [request startWithCompletionBlockWithSuccess:^(__kindof JKBaseRequest * request) {
            [[request.responseJSONObject should] beNonNil];
            [[[request.responseJSONObject jk_stringForKey:@"name"] should] beNonNil];
        } failure:^(__kindof JKBaseRequest * request) {
            [[request.error should] beNil];
        }];
    });

});

});

SPEC_END
