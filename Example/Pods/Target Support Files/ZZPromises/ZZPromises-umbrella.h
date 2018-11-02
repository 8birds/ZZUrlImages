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

#import "ZZNetPromises.h"
#import "ZZPromise.h"
#import "ZZPromises.h"
#import "ZZRunLoopManager.h"

FOUNDATION_EXPORT double ZZPromisesVersionNumber;
FOUNDATION_EXPORT const unsigned char ZZPromisesVersionString[];

