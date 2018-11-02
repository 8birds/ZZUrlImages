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

#import "ZZURLImageView.h"
#import <ZZPromises/ZZPromises.h>
#import "ZZImageLoader.h"


static NSString *const kErrDomain = @"ZZURLImageView";

@interface ZZURLImageView ()

@property (nonatomic) NSURL* url;
@property (nonatomic) ZZPromise<UIImage*>* pendingImagePromise;

@end



@implementation ZZURLImageView

-(void) dealloc{
    ZZPromise<UIImage*>* currPromise = _pendingImagePromise;
    if(currPromise)
        [currPromise cancel];
}

-(ZZPromise*) setImageURL:(NSURL*)url{
    NSURLRequest* req = [NSURLRequest requestWithURL:url];

    return [self setImageURLRequest:req];
}

-(ZZPromise*) setImageURLRequest:(NSURLRequest *)request{
    ZZPromise<UIImage*>* currPromise = _pendingImagePromise;
    if(currPromise)
    [currPromise cancel];

    __weak ZZURLImageView* weakSelf = self;

    return [[ZZImageLoader loadImageWithURLRequest:request]
            then:^id(UIImage* image)
            {
                ZZURLImageView* strongSelf = weakSelf;
                if(!strongSelf)
                return nil;

                strongSelf.pendingImagePromise = nil;
                strongSelf.image = image;

                return nil;
            }
            name:@"Image View Setting Image"
            onRunLoop:NSRunLoop.mainRunLoop];
}

@end
