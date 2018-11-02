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

#import "ZZURLImageButton.h"
#import "ZZLoadingAnimation.h"
#import "ZZImageLoader.h"
#import <ZZPromises/ZZPromises.h>


static const CGFloat kMaxLoadingAnimationDim = 50;


@interface ZZURLImageButton ()

@property (nonatomic) ZZPromise* cancellationSrc;
@property (nonatomic) ZZLoadingAnimation* loadingAnimation;

@end



@implementation ZZURLImageButton

-(id) initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(!self)
        return nil;

    return self;
}

-(id) initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    return self;
}

-(CGRect) imageRectForContentRect:(CGRect)contentRect{
    return [super imageRectForContentRect:contentRect];
}


-(void) setImage:(UIImage *)image forState:(UIControlState)state{
    @synchronized(self){
        if(_cancellationSrc){
            [_cancellationSrc cancel];
            _cancellationSrc = nil;
        }
    }

    [super setImage:image forState:state];
}

-(void) setScaleFitAspect{
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.contentHorizontalAlignment =
    UIControlContentHorizontalAlignmentFill;
    self.contentVerticalAlignment =
    UIControlContentVerticalAlignmentFill;
}

-(void) setScaleFillAspect{
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;

    self.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentFill;
    self.contentVerticalAlignment =
        UIControlContentVerticalAlignmentFill;
}

-(void) hideLoadingAnimation{
    if(!_loadingAnimation)
        return;

    [_loadingAnimation removeFromSuperview];
    _loadingAnimation = nil;
}

-(void) showLoadingAnimation{
    [self hideLoadingAnimation];

    CGFloat dim = MIN(self.bounds.size.width, self.bounds.size.height);
    dim = MIN(dim, kMaxLoadingAnimationDim);

    CGFloat cx = self.bounds.origin.x + self.bounds.size.width  / 2.0;
    CGFloat cy = self.bounds.origin.y + self.bounds.size.height / 2.0;
    CGRect frame;
    frame.origin.x = cx - dim / 2.0;
    frame.origin.y = cy - dim / 2.0;
    frame.size = CGSizeMake(dim, dim);

    ZZLoadingAnimation* anim = [[ZZLoadingAnimation alloc] initWithFrame:frame];
    [self addSubview:anim];
    _loadingAnimation = anim;
}

-(ZZPromise*) setImageURL:(NSURL*)url
                 forState:(UIControlState)state
{
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    return [self setImageURLRequest:req forState:state];
}

-(ZZPromise*) setImageURLRequest:(NSURLRequest*)request
                        forState:(UIControlState)state
{
    [self setImage:nil forState:state]; //cancels any existing loads
    [self showLoadingAnimation];

    __weak ZZURLImageButton* weakSelf = self;

    ZZPromise<UIImage*>* cancellablePromise = [ZZImageLoader loadImageWithURLRequest:request];
    ZZPromise* promiseChain = [[cancellablePromise
     then:^id(UIImage* image)
    {
        ZZURLImageButton* strongSelf = weakSelf;
        if(!strongSelf)
            return nil;

        if(!strongSelf.cancellationSrc){
            NSLog(@"<URLImageButton %p> gone", strongSelf);
        }
        if(strongSelf.cancellationSrc.cancelled){
            NSLog(@"<URLImageButton %p> Already cancelled %p.", strongSelf, strongSelf.cancellationSrc);
            return nil;
        }
        [strongSelf hideLoadingAnimation];
        [strongSelf setScaleFitAspect];

        [strongSelf setImage:image
                    forState:state];

        [strongSelf setScaleFitAspect];

        return nil;
    } name:@"Set URL Button's Image"
      onRunLoop:NSRunLoop.mainRunLoop]
     catchWithControlTask:^(NSError *err, ZZPromiseControl *ctrl) {
         ZZURLImageButton* strongSelf = weakSelf;
         if(strongSelf)
            [strongSelf hideLoadingAnimation];

         [ctrl reject:err]; //pass it along
     } name:@"Stop loading animation on failure"];

    _cancellationSrc = cancellablePromise;

    return promiseChain;
}

@end
