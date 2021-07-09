//
//  JKNetworkingMacro.h
//  JKNetworking
//
//  Created by JackLee on 2019/10/29.
//

#ifndef JKNetworkingMacro_h
#define JKNetworkingMacro_h

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

/// when the background task completed while the app not run,and the invoke the app,then post the notification,the object posted is an NSURLSessionTask
static NSString * const JKBackgroundTaskCompleteAndInvokeAppNotification = @"JKBackgroundTaskCompleteAndInvokeAppNotification";



#endif /* JKNetworkingMacro_h */
