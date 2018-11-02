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

#import "ZZLoadingAnimation.h"

static NSTimer* timer = nil;
static NSMutableArray<ZZLoadingAnimation*>* animations = nil;
static int startIndex = 0;
const int kDotCount = 12;

@interface ZZLoadingAnimation(){
    NSArray<CALayer*>* dots;
}
@end

@implementation ZZLoadingAnimation

+(void) initialize{
    animations = [NSMutableArray new];
}

+(void) updateLoadingAnimations{
    int startIdx = startIndex;
    int endIdx = startIdx + kDotCount;

    for(int i = 0; i < animations.count; i++){
        ZZLoadingAnimation* anim = animations[i];

        if(anim.superview == nil){
            __weak ZZLoadingAnimation* weakAnim = anim;
            @autoreleasepool{
                anim = nil;
                [animations removeObjectAtIndex:i];
            }
            anim = weakAnim;
            if(anim)
                [animations insertObject:anim atIndex:i];
            else{
                i--;
                continue;
            }
        }

        for(int i = startIdx; i < endIdx; i++){
            CGFloat opacity = 0.1 + 0.9 * (i - startIdx) / kDotCount;
            int dotIdx = i % kDotCount;
            anim->dots[dotIdx].opacity = opacity;
        }
    }

    startIndex++;
    startIndex %= kDotCount;

    if(animations.count == 0){
        [timer invalidate];
        timer = nil;
        return;
    }
}

-(instancetype) initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if(!self)
        return nil;

    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
    CGFloat cx = self.bounds.size.width  / 2.0;
    CGFloat cy = self.bounds.size.height / 2.0;
    CGFloat dotRadius = radius * 0.1;
    CGFloat dotDiameter = dotRadius * 2.0;
    CGFloat distanceBetweenCenters = radius - dotRadius;

    NSMutableArray<CALayer*>* layers = [NSMutableArray new];
    CGColorRef gray = UIColor.lightGrayColor.CGColor;
    for(int i = 0; i < kDotCount; i++){
        CALayer* layer = [CALayer layer];
        layer.backgroundColor = gray;

        CGFloat angle = M_PI * 2.0 * i / kDotCount;
        CGRect dotFrame;
        dotFrame.size = CGSizeMake(dotDiameter, dotDiameter);
        dotFrame.origin.x = cx + distanceBetweenCenters * cos(angle);
        dotFrame.origin.y = cy + distanceBetweenCenters * sin(angle);
        layer.frame = dotFrame;
        layer.cornerRadius = dotRadius;

        layer.opacity = 0.1 + 0.9 * i / kDotCount;

        [layers addObject:layer];
        [self.layer addSublayer:layer];
    }
    self->dots = layers.copy;

    [animations addObject:self];

    if(timer == nil){
        timer = [NSTimer timerWithTimeInterval:1.0 / 8.0 repeats:YES block:^(NSTimer * _Nonnull timer)
         {
             [ZZLoadingAnimation updateLoadingAnimations];
         }];

        [NSRunLoop.mainRunLoop addTimer:timer
                                forMode:NSDefaultRunLoopMode];
    }

    return self;
}

@end
