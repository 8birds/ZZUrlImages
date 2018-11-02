/*
 * Copyright 2018 8 Birds Video Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZZImageLoader.h"


static NSString *const kErrDomain = @"ZZImageLoader";

static ZZLRUCache<UIImage*>* gImageCache;
static ZZLRUCache<NSData*>* gEncDataCache;

static UIImage* imageFor(NSString* url){
    UIImage* img = [gImageCache objectForKey:url];

    if(img)
        return img;

    NSData* encData = [gEncDataCache objectForKey:url];
    if(!encData)
        return nil;

    img = [UIImage imageWithData:encData];
    [gImageCache setObject:img forKey:url];

    return img;
}

@implementation ZZImageLoader

+(void) initialize{
    ZZLRUCache* cache = [ZZLRUCache new];
    gImageCache = cache;
    cache.cacheObjectLimit = 20;

    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification * _Nonnull note)
    {
        ZZLRUCache<UIImage*>* imageCache = gImageCache;
        ZZLRUCache<NSData*>* encCache = gEncDataCache;

        if(imageCache)
            [imageCache reduceObjectCountBy:0.75];

        if(encCache)
            [encCache reduceObjectCountBy:0.25];
    }];
}

+(ZZLRUCache<UIImage*>*) imageCache{
    return gImageCache;
}

+(void) setImageCache:(ZZLRUCache<UIImage *> *)imageCache{
    gImageCache = imageCache;
}

+(ZZLRUCache<NSData*>*) encodedImageDataCache{
    return gEncDataCache;
}

+(void) setEncodedImageDataCache:(ZZLRUCache<NSData *> *)encodedImageDataCache{
    gEncDataCache = encodedImageDataCache;
}

+(ZZPromise<UIImage*>*) loadImageWithURL:(NSURL*)url{
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    return [ZZImageLoader loadImageWithURLRequest:req];
}

+(ZZPromise<UIImage*>*) loadImageWithURLRequest:(NSURLRequest*)request{
    NSString* imageCacheKey = request.URL.absoluteString;
    UIImage* cachedImage = imageFor(imageCacheKey);
    if(cachedImage)
        return [ZZPromise promiseResolvedWith:cachedImage
                                         name:@"Have cached image"];

    return [[ZZNetPromises request:request
                  onUploadProgress:nil
                onDownloadProgress:nil]
      thenControlTask:^(ZZHTTPPromiseResponse *response, ZZPromiseControl<UIImage*>* ctrl) {
          int status = (int)response.httpResponse.statusCode;
          if(status < 200 || status >= 300){
              NSString* body = [[NSString alloc] initWithData:response.data
                                                     encoding:NSUTF8StringEncoding];
              NSError* err = [NSError errorWithDomain:kErrDomain
                                                 code:status
                                             userInfo:@{
                            NSLocalizedDescriptionKey: @"Failed to load image",
                            NSLocalizedFailureReasonErrorKey: body
                        }];

              [ctrl reject:err];
              return;
          }

          [gEncDataCache setObject:response.data
                            forKey:imageCacheKey];

          UIImage* img = [UIImage imageWithData:response.data];
          if(!img){
              NSError* err = [NSError errorWithDomain:kErrDomain
                                                 code:status
                                             userInfo:@{
                            NSLocalizedDescriptionKey: @"Failed to load image",
                            NSLocalizedFailureReasonErrorKey: @"Decode failure"
                        }];

              [ctrl reject:err];
              return;
          }

          [gImageCache setObject:img
                          forKey:imageCacheKey];

          [ctrl resolve:img];
      } name:@"Decode image"];
}

@end
