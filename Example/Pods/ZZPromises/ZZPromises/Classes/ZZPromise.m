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

#import "ZZPromise.h"
#include <pthread.h>
#import "ZZRunLoopManager.h"



static const BOOL kPromiseTracing = NO;



static NSString *const kErrDomain = @"Promise";

static ZZRunLoopManager* defaultRunLoop;



static NSError* errorFromException(NSString* errDomain, NSException* ex){
    return [NSError errorWithDomain:errDomain
                               code:-1
                           userInfo:
            @{
              NSLocalizedDescriptionKey: ex.description,
              NSLocalizedFailureReasonErrorKey: @"Exception thrown"
              }];
}

@interface ZZPromiseControl(){
    pthread_mutex_t lock;
    pthread_cond_t finishedCV;
    NSMutableArray* nameChain;
}

@property (nonatomic) void (^taskBlock)(id result, ZZPromiseControl* ctrl);
@property (nonatomic) void (^errorBlock)(NSError* err, ZZPromiseControl* ctrl);

@property (readonly, nonatomic) ZZPromise* nextPromise;
@property (nonatomic) NSRunLoop* runLoop;

@property (nonatomic) NSMutableArray* promiseNameChain;
@property (nonatomic) NSString* promiseName;

@property (nonatomic) BOOL scheduled;
@property (nonatomic) BOOL beganExecuting;
@property (nonatomic) BOOL finished; //true when resolve: or reject: called

@property (nonatomic) NSError* rejectError;
@property (nonatomic) id result;

@property (nonatomic) BOOL cancelled;

@property (nonatomic) BOOL passedControl;

-(void) setNextPromise:(ZZPromise *)nextPromise;

@end



@interface ZZPromise()
@property (nonatomic) ZZPromiseControl* params;
@end



@implementation ZZPromise

+(void) initialize{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultRunLoop = [[ZZRunLoopManager alloc] init];
    });
}

-(instancetype) initWithName:(NSString*)name
                   onRunLoop:(NSRunLoop*)runLoop
{
    self = [super init];
    if(!self)
        return nil;

    ZZPromiseControl* params = [ZZPromiseControl new];
    _params = params;
    params.runLoop = runLoop ? runLoop : defaultRunLoop.runLoop;
    params.promiseName = name;

    return self;
}

-(instancetype) initWithTask:(void (^)(id result,
                                       ZZPromiseControl*))task
                        name:(NSString*)name
                   onRunLoop:(NSRunLoop*)runLoop
{
    self = [super init];
    if(!self)
        return nil;

    ZZPromiseControl* params = [ZZPromiseControl new];
    _params = params;

    params.taskBlock = task;
    params.runLoop = runLoop ? runLoop : defaultRunLoop.runLoop;
    params.promiseName = name;

    return self;
}

-(BOOL) cancelled{
    return _params.cancelled;
}

+(ZZPromise*) promiseWithBareTask:(id (^)(id incomingResult))task
                           name:(NSString*)promiseName
                      onRunLoop:(NSRunLoop*)runLoop
{
    ZZPromise* promise = [[ZZPromise alloc] initWithTask:^(id incomingResult, ZZPromiseControl* ctrl) {
        @try{
            @synchronized(ctrl){
                if(ctrl.cancelled)
                    return;
            }

            id result = task(incomingResult);
            [ctrl resolve:result];
        }
        @catch(NSException* ex){
            [ctrl reject:errorFromException(kErrDomain, ex)];
        }
    }
    name:promiseName
    onRunLoop:runLoop];

    return promise;
}

+(ZZPromise*) promiseResolvedWith:(id)result
                             name:(NSString*)name
{
    ZZPromise* promise = [[ZZPromise alloc] initWithName:name
                                              onRunLoop:nil];

    promise.params.promiseNameChain = [NSMutableArray new];
    [promise.params resolve:result];

    return promise;
}

+(ZZPromise*) promiseRejectedWith:(NSError*)err
                             name:(NSString*)name
{
    ZZPromise* promise = [[ZZPromise alloc] initWithName:name
                                               onRunLoop:nil];

    promise.params.promiseNameChain = [NSMutableArray new];
    [promise.params reject:err];

    return promise;
}

-(instancetype) initErrorCatcher:(void (^)(NSError*,
                                           ZZPromiseControl*))errorCatcher
                            name:(NSString*)name
                       onRunLoop:(NSRunLoop*)runLoop
{
    self = [super init];
    if(!self)
        return nil;

    ZZPromiseControl* params = [ZZPromiseControl new];
    _params = params;

    params.errorBlock = errorCatcher;
    params.runLoop = runLoop ? runLoop : defaultRunLoop.runLoop;
    params.promiseName = name;

    return self;
}


+(ZZPromise*) delayedPromiseWithTask:(void (^)(ZZPromiseControl<id>*))task
                                name:(NSString*)name{
    return [ZZPromise delayedPromiseWithTask:task
                                        name:name
                                   onRunLoop:nil];
}

+(ZZPromise*) delayedPromiseWithTask:(void (^)(ZZPromiseControl<id>*))task
                                name:(NSString*)name
                           onRunLoop:(NSRunLoop*)runLoop
{
    return [[ZZPromise alloc] initWithTask:^(id result, ZZPromiseControl *ctrl) {
        @synchronized (ctrl) {
            if(ctrl.cancelled)
                return;
        }

        task(ctrl);
    }
    name:name
    onRunLoop:runLoop];
}

+(ZZPromise*) delayedPromise:(ZZPromise<id>* (^)(void))task
                        name:(NSString*)name
{
    return [ZZPromise delayedPromise:task
                                name:name
                           onRunLoop:defaultRunLoop.runLoop];
}

+(ZZPromise*) delayedPromise:(ZZPromise<id>* (^)(void))createPromiseFnc
                        name:(NSString*)name
                   onRunLoop:(NSRunLoop*)runLoop
{
    return [[ZZPromise alloc] initWithTask:^(id result, ZZPromiseControl *outerCtrl){
        @synchronized (outerCtrl) {
            if(outerCtrl.cancelled)
                return;
        }

        ZZPromise* promise = createPromiseFnc();
        if(!promise){
            [outerCtrl resolve:nil];
            return;
        }

        [[promise
          then:^id(id result)
          {
              @synchronized(outerCtrl){
                  if(outerCtrl.cancelled)
                      return nil;
              }

             [outerCtrl resolve:result];
             return nil;
          }
          name:[name stringByAppendingString:@" (result forwarder)"]
          onRunLoop:runLoop]
         catchWithTask:^id(NSError *err) {
             @synchronized(outerCtrl){
                 if(outerCtrl.cancelled)
                     return nil;
             }

             [outerCtrl reject:err];
             return nil;
         }
          name:[name stringByAppendingString:@" (error forwarder)"]
          onRunLoop:runLoop];
    }
    name:name
    onRunLoop:runLoop];
}

+(ZZPromise*) promiseWithTask:(void (^)(ZZPromiseControl<id>*))task
                         name:(NSString*)name
{
    return [ZZPromise promiseWithTask:task
                                 name:name
                            nameChain:@[ name ]
                            onRunLoop:nil];
}

+(ZZPromise*) promiseWithTask:(void (^)(ZZPromiseControl<id>*))task
                         name:(NSString*)name
                    onRunLoop:(NSRunLoop*)runLoop
{
    return [ZZPromise promiseWithTask:task
                                 name:name
                            nameChain:@[ name ]
                            onRunLoop:runLoop];
}

+(ZZPromise*) promiseWithTask:(void (^)(ZZPromiseControl<id>*))task
                         name:(NSString*)name
                    nameChain:(NSArray*)nameChain
                    onRunLoop:(NSRunLoop *)runLoop
{
    ZZPromise* promise = [[ZZPromise alloc] initWithTask:^(id result, ZZPromiseControl* ctrl) {
        task(ctrl);
    }
    name:name
    onRunLoop:runLoop];

    [promise performPromise:nil];

    return promise;
}

-(void) performErrorBlock:(NSError*)err
{
    if(_params.scheduled)
        return;

    _params.scheduled = YES;
    if(![err isKindOfClass:NSError.class])
        NSLog(@"WARNING: Performing error block with non-error object.");

    ZZPromiseControl* params = _params;

    [params.runLoop performBlock:^{
        if(params.cancelled)
            return;

        @try{
            if(!params.errorBlock){
                if(kPromiseTracing)
                    NSLog(@"Skipping error block '%@'", params.promiseName);

                if(params.nextPromise){
                    params.passedControl = YES;
                    [params.nextPromise performErrorBlock:err];
                } else if(kPromiseTracing) {
                    NSLog(@"Dropped error %@ %@.", err, params.promiseNameChain);
                }

                return;
            }

            if(kPromiseTracing)
                NSLog(@"Performing error block '%@'", params.promiseName);

            if(![err isKindOfClass:NSError.class])
                NSLog(@"WARNING: Performing error block with non-error object.");

            params.errorBlock(err, params);
        }
        @catch(NSException* ex){
            if(params.nextPromise){
                NSError* err = errorFromException(kErrDomain, ex);
                params.passedControl = YES;
                [params.nextPromise performErrorBlock:err];
            }
        }
    }];
}

-(void) start{
    //Only affects delayed promises (returned by init methods).
    //If already started (start: or a non-delayed promise), this method has no effect.
    [self performPromise:nil];
}

-(void) performPromise:(id)incomingResult
{
    if(_params.scheduled)
        return;

    _params.scheduled = YES;

    ZZPromiseControl* params = _params;

    [params.runLoop performInModes:@[NSRunLoopCommonModes, NSDefaultRunLoopMode] block:^{
        @synchronized(params){
            if(params.cancelled)
                return;

            params.beganExecuting = YES;
        }

        if(!params.taskBlock){
            if(kPromiseTracing)
                NSLog(@"Skipping promise '%@'",  params.promiseName);

            if(params.nextPromise){
                params.passedControl = YES;
                if(params.cancelled && kPromiseTracing){
                    NSLog(@"Running a cancelled promise.");
                }
                [params.nextPromise performPromise:incomingResult];
            }

            return;
        }

        @try{
            if(kPromiseTracing)
                NSLog(@"Performing promise '%@'",  params.promiseName);

            if(params.taskBlock)
                params.taskBlock(incomingResult, params);
        }
        @catch(NSException* ex){
            if(params.nextPromise){
                params.passedControl = YES;
                [params.nextPromise performErrorBlock:errorFromException(kErrDomain, ex)];
            }
        }
    }];
}

-(ZZPromise*) then:(id (^)(id))task
              name:(NSString*)name
{
    return [self then:task
                 name:name
            onRunLoop:_params.runLoop];
}

-(ZZPromise*) then:(id (^)(id))onResult
            name:(NSString*)name
       onRunLoop:(NSRunLoop *)runLoop
{
    ZZPromise* nextPromise = [ZZPromise promiseWithBareTask:onResult
                                                       name:name
                                                  onRunLoop:runLoop];

    [_params setNextPromise:nextPromise];

    if(_params.finished){
        _params.passedControl = YES;

        if(!_params.rejectError)
            [nextPromise performPromise:_params.result];
        else
            [nextPromise performErrorBlock:_params.rejectError];
    }

    return nextPromise;
}

-(ZZPromise*) thenControlTask:(void (^)(id, ZZPromiseControl*))onResult
                         name:(NSString*)name
                    onRunLoop:(NSRunLoop *)runLoop
{
    ZZPromise* nextPromise = [[ZZPromise alloc] initWithTask:onResult
                                                        name:name
                                                   onRunLoop:runLoop];

    [_params setNextPromise:nextPromise];

    if(_params.finished){
        _params.passedControl = YES;

        if(!_params.rejectError)
            [nextPromise performPromise:_params.result];
        else
            [nextPromise performErrorBlock:_params.rejectError];
    }

    return nextPromise;
}

-(ZZPromise*) thenControlTask:(void (^)(id, ZZPromiseControl*))onResult
                         name:(NSString*)name
{
    return [self thenControlTask:onResult
                            name:name
                       onRunLoop:_params.runLoop];
}

-(ZZPromise*) thenPromiseFactory:(ZZPromise *(^)(id))factory
                            name:(NSString*)name
{
    return [self thenPromiseFactory:factory
                               name:name
                          onRunLoop:_params.runLoop];
}

- (ZZPromise *)thenPromiseFactory:(ZZPromise *(^)(id))factory
                             name:(NSString*)name
                        onRunLoop:(NSRunLoop*)runLoop
{
    NSMutableArray* subChain = [NSMutableArray new];
    [_params.promiseNameChain addObject:subChain];
    ZZPromise* nextPromise = [[ZZPromise alloc] initWithTask:^(id result, ZZPromiseControl* outerCtrl){
        @synchronized(outerCtrl){
            if(outerCtrl.cancelled)
                return;
        }

        ZZPromise* createdPromise = factory(result);
        createdPromise.params.promiseNameChain = subChain;

        [[createdPromise
         then:^id(id result) {
             [outerCtrl resolve:result];
             return nil;
         } name:[name stringByAppendingString:@" (promise factory wrapper)"]]
         catchWithTask:^id(NSError *factoryErr) {
             [outerCtrl reject:factoryErr];
             return nil;
         } name:[name stringByAppendingString:@" (promise factory wrapper error handler)"]];
    }
    name:name
    onRunLoop:runLoop];

    [_params setNextPromise:nextPromise];

    if(_params.finished){
        _params.passedControl = YES;

        if(!_params.rejectError)
            [nextPromise performPromise:_params.result];
        else
            [nextPromise performErrorBlock:_params.rejectError];
    }

    return nextPromise;
}

-(ZZPromise*) catchWithTask:(id (^)(NSError *))exBlock
                       name:(NSString*)name
{
    return [self catchWithTask:exBlock
                          name:name
                     onRunLoop:_params.runLoop];
}

-(ZZPromise*) catchWithTask:(id (^)(NSError *))errBlock
                       name:(NSString*)name
                  onRunLoop:(NSRunLoop *)runLoop
{
    ZZPromise* nextPromise = [[ZZPromise alloc] initErrorCatcher:^(NSError *err,
                                                                   ZZPromiseControl* ctrl)
                           {
                               @synchronized(ctrl){
                                   if(ctrl.cancelled)
                                       return;
                               }

                               @try{
                                   id result = errBlock(err);
                                   [ctrl resolve:result];
                               }
                               @catch(NSException* ex){
                                   [ctrl reject:errorFromException(kErrDomain, ex)];
                               }
                           }
                            name:name
                            onRunLoop:runLoop];

    [_params setNextPromise:nextPromise];

    if(_params.finished){
        _params.passedControl = YES;

        if(!_params.rejectError)
            [nextPromise performPromise:_params.result];
        else
            [nextPromise performErrorBlock:_params.rejectError];
    }

    return _params.nextPromise;
}

-(ZZPromise*) catchWithControlTask:(void (^)(NSError *, ZZPromiseControl *))task
                              name:(NSString*)name
{
    return [self catchWithControlTask:task
                                 name:name
                            onRunLoop:_params.runLoop];
}

-(ZZPromise*) catchWithControlTask:(void (^)(NSError* err,
                                             ZZPromiseControl* ctrl))task
                              name:(NSString*)name
                         onRunLoop:(NSRunLoop *)runLoop
{
    [_params setNextPromise:[[ZZPromise alloc] initErrorCatcher:task
                                                           name:name
                                                      onRunLoop:runLoop]];

    return _params.nextPromise;
}

-(ZZPromise*) catchWithPromiseFactory:(ZZPromise *(^)(NSError *))factory
                                 name:(NSString*)name
{
    return [self catchWithPromiseFactory:factory
                                    name:name
                               onRunLoop:_params.runLoop];
}

-(ZZPromise*) catchWithPromiseFactory:(ZZPromise *(^)(NSError *))factory
                                 name:(NSString*)name
                            onRunLoop:(NSRunLoop *)runLoop
{
    NSMutableArray* subChain;

    if(kPromiseTracing){
        subChain = [NSMutableArray new];
        [_params.promiseNameChain addObject:subChain];
    }

    ZZPromise* nextPromise = [[ZZPromise alloc] initErrorCatcher:^(NSError *err,
                                                                   ZZPromiseControl *outerCtrl)
    {
        @synchronized(outerCtrl){
            if(outerCtrl.cancelled)
                return;
        }

        //The factory catches the error and returns a new Promise
        ZZPromise* createdPromise = factory(err);

        if(kPromiseTracing)
            createdPromise.params.promiseNameChain = subChain;

        [[createdPromise
         then:^id(id result) {
             [outerCtrl resolve:result];
             return nil;
         } name:[name stringByAppendingString:@" (promise factory error handler)"]]
         catchWithTask:^id(NSError *factoryErr) {
             [outerCtrl reject:factoryErr];
             return nil;
         } name:[name stringByAppendingString:@" (promise factory internal error)"]];
    }
    name:name
    onRunLoop:runLoop];

    [_params setNextPromise:nextPromise];

    if(_params.finished){
        _params.passedControl = YES;

        if(!_params.rejectError)
            [nextPromise performPromise:_params.result];
        else
            [nextPromise performErrorBlock:_params.rejectError];
    }

    return nextPromise;
}

-(BOOL) cancel{
    @synchronized(_params){
        if(_params.cancelled){
            if(kPromiseTracing)
                NSLog(@"Already cancelled Promise %p PromiseCtrl %p", self, _params);
            return NO;
        }

        _params.cancelled = YES;

        ZZPromise* next = _params.nextPromise;
        if(next)
            [next cancel];

        if(_params.beganExecuting){
            if(kPromiseTracing){
                NSLog(@"Cannot cancel Promise %p PromiseCtrl %p. Began executing. Finished? %d",
                      self,
                      _params,
                      _params.finished);
            }

            return NO;
        }

        if(kPromiseTracing)
            NSLog(@"Cancelling Promise %p PromiseCtrl %p", self, _params);

        return YES;
    }
}

-(void) printChain{
    if(!kPromiseTracing)
        NSLog(@"%@", _params.promiseName);
    else
        NSLog(@"%@", _params.promiseNameChain);
}

-(void) waitUntilFinished{
    @synchronized(_params){
        if(_params.finished)
            return;
    }
}

-(NSRunLoop*) runLoop{
    return _params.runLoop;
}

-(BOOL) finished{
    return _params.finished;
}

-(id) result{
    return _params.result;
}

-(id) error{
    return _params.rejectError;
}

@end

@implementation ZZPromiseControl

-(id) init{
    self = [super init];
    if(!self)
        return nil;

    _scheduled = NO;
    _finished = NO;
    _beganExecuting = NO;

    int status = pthread_mutex_init(&lock, NULL);
    if(status != 0)
        [NSException raise:NSGenericException format:@"Mutex init failed: %d", status];

    status = pthread_cond_init(&finishedCV, NULL);
    if(status != 0)
        [NSException raise:NSGenericException format:@"CV init failed: %d", status];

    return self;
}

-(void) dealloc{
    if(!_passedControl && kPromiseTracing){
        if(_result)
            NSLog(@"Dropping result (%@): %@", self.promiseNameChain, _result);
        else if(_rejectError)
            NSLog(@"Dropping error (%@): %@", self.promiseNameChain, _rejectError);
    }
}

-(NSMutableArray*) promiseNameChain{
    return nameChain;
}

-(void) setPromiseNameChain:(NSMutableArray *)promiseNameChain{
    if(!kPromiseTracing)
        return;

    nameChain = promiseNameChain;
    [nameChain addObject:_promiseName];
}

-(void) resolve:(id)result{
    if(kPromiseTracing){
        NSLog(@"Resolving promise %@ params %p with result %p", self.promiseNameChain, self, result);

        if(result == nil)
            NSLog(@"Nil result (%@)", self.promiseNameChain);
    }

    @synchronized(self){
        if(_finished || _cancelled)
            return;

        _finished = YES;
        _result = result;
    }

    [_runLoop performBlock:^{
        //self retained intentionally to prevent Promise from going away.
        @synchronized(self){
            if(self.cancelled)
                return;
        }

        ZZPromise* nextPromise = self.nextPromise;
        if(nextPromise){
            self.passedControl = YES;

            [nextPromise performPromise:result];
        }
    }];
}

-(void) reject:(NSError *)err{
    if(![err isKindOfClass:NSError.class])
        NSLog(@"WARNING: Performing error block with non-error object.");

    if(kPromiseTracing){
        NSLog(@"Rejecting promise params %p (%@) with error %p %@", self, self.promiseNameChain, err, err);


        if(err == nil)
            NSLog(@"Nil error (%@)", self.promiseNameChain);
    }

    @synchronized(self){
        if(_finished)
            return;

        _finished = YES;
        _rejectError = err;
    }

    [_runLoop performBlock:^{
        //self retained intentionally to prevent Promise from going away.
        @synchronized(self){
            if(self.cancelled)
                return;
        }

        if(self.nextPromise){
            self.passedControl = YES;
            [self.nextPromise performErrorBlock:err];
        } else if(kPromiseTracing) {
            NSLog(@"No error handler for %@", self.promiseNameChain);
        }
    }];
}

-(void) inject:(ZZPromise*)promise{
    if(!promise)
        return;

    @synchronized(self){
        if(_finished)
            return;
    }

    ZZPromise* tailPromise = promise;
    while(tailPromise.params.nextPromise)
        tailPromise = tailPromise.params.nextPromise;

    tailPromise.params.nextPromise = _nextPromise;
    _nextPromise = promise;
}

-(void) setNextPromise:(ZZPromise *)nextPromise{
    if(_nextPromise)
        [NSException raise:@"Invalid State"
                    format:@"Cannot call 'then' and/or 'catch' variants more than once."];

    _nextPromise = nextPromise;
    if(_nextPromise)
        _nextPromise.params.promiseNameChain = self.promiseNameChain;
}

@end

