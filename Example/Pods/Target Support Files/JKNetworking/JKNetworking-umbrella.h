#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "JKBaseRequest.h"
#import "JKBatchRequest.h"
#import "JKNetworkAgent.h"
#import "JKNetworkConfig.h"
#import "JKNetworking.h"
#import "JKNetworkingMacro.h"

FOUNDATION_EXPORT double JKNetworkingVersionNumber;
FOUNDATION_EXPORT const unsigned char JKNetworkingVersionString[];

