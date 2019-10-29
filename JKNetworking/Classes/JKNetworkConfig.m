//
//  JKNetworkConfig.m
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#import "JKNetworkConfig.h"

@interface JKNetworkConfig()

@property (nonatomic, strong, readwrite, nullable) id<JKRequestHelperProtocol> requestHelper;

@end


@implementation JKNetworkConfig

+ (instancetype)sharedConfig
{
    static JKNetworkConfig *_networkConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _networkConfig = [[self alloc] init];
    });
    return _networkConfig;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _host = @"";
        _cdnHost = @"";
        _securityPolicy = [AFSecurityPolicy defaultPolicy];
    }
    return self;
}

- (void)configRequestHelper:(id<JKRequestHelperProtocol>)requestHelper
{
    self.requestHelper = requestHelper;
}

@end
