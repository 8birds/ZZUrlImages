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

#import "ZZRunLoopManager.h"
#import <pthread.h>

static NSRunLoop* gRunLoopTmp;
static pthread_mutex_t gLock;
static pthread_cond_t gCV;

@interface ZZRunLoopManager(){
    BOOL stopped;
}

-(void) runLoopMethod;

@end


static void* runLoopFnc(void* ctx){
    @autoreleasepool{
        ZZRunLoopManager* mgr = (__bridge ZZRunLoopManager*)ctx;

        pthread_mutex_lock(&gLock);
        gRunLoopTmp = NSRunLoop.currentRunLoop;
        pthread_cond_broadcast(&gCV);
        pthread_mutex_unlock(&gLock);

        [mgr runLoopMethod];
    }

    pthread_exit(NULL);
}

@implementation ZZRunLoopManager

-(instancetype) init{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gRunLoopTmp = nil;
        pthread_mutex_init(&gLock, NULL);
        pthread_cond_init(&gCV, NULL);
    });

    pthread_mutex_lock(&gLock);
    pthread_t thread;
    pthread_create(&thread, NULL, runLoopFnc, (__bridge void*)self);
    pthread_detach(thread);

    pthread_cond_wait(&gCV, &gLock);

    _runLoop = gRunLoopTmp;
    gRunLoopTmp = nil;

    pthread_mutex_unlock(&gLock);

    return self;
}

-(void) runLoopMethod{
    while(!stopped){
        @autoreleasepool{
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1, YES);
        }
    }
}

-(void) stop{
    stopped = YES;
}

@end
