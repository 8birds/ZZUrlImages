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

#import <Foundation/Foundation.h>

@class ZZPromise<__covariant T>;

@interface ZZPromiseControl<__covariant T> : NSObject

-(void) resolve:(T)result;
-(void) reject:(NSError*)e;
-(void) inject:(ZZPromise<T>*)promise;

@end

/**
 * The task is scheduled on the main thread.
 * resolve and reject schedule a call to then: or catchError: on the main thread.
 *
 * Tasks return the result object, or throw an NSException.
 */
@interface ZZPromise<__covariant T> : NSObject

@property (readonly) NSRunLoop* runLoop;
@property (readonly) T result;
@property (readonly) NSError* error;
@property (readonly) BOOL finished;
@property (readonly) BOOL cancelled;

+(ZZPromise<T>*) delayedPromiseWithTask:(void (^)(ZZPromiseControl<T>* ctrl))task
                                   name:(NSString*)promiseName;

+(ZZPromise<T>*) delayedPromiseWithTask:(void (^)(ZZPromiseControl<T>* ctrl))task
                                   name:(NSString*)promiseName
                              onRunLoop:(NSRunLoop*)runLoop;

+(ZZPromise<T>*) delayedPromise:(ZZPromise<T>* (^)(void))createPromiseFnc
                           name:(NSString*)promiseName;

+(ZZPromise<T>*) delayedPromise:(ZZPromise<T>* (^)(void))createPromiseFnc
                           name:(NSString*)promiseName
                      onRunLoop:(NSRunLoop*)runLoop;

+(ZZPromise<T>*) promiseWithTask:(void (^)(ZZPromiseControl<T>* ctrl))task
                            name:(NSString*)promiseName;

+(ZZPromise<T>*) promiseWithTask:(void (^)(ZZPromiseControl<T>* ctrl))task
                            name:(NSString*)promiseName
                       onRunLoop:(NSRunLoop*)runLoop;

+(ZZPromise<T>*) promiseResolvedWith:(T)result
                                name:(NSString*)promiseName;

+(ZZPromise<T>*) promiseRejectedWith:(NSError*)err
                                name:(NSString*)promiseName;

-(ZZPromise*) then:(id (^)(T result))onResult
              name:(NSString*)promiseName;

-(ZZPromise*) then:(id (^)(T result))onResult
              name:(NSString*)promiseName
         onRunLoop:(NSRunLoop*)runLoop;

-(ZZPromise*) thenControlTask:(void (^)(T result,
                                        ZZPromiseControl* ctrl))task
                         name:(NSString*)promiseName;

-(ZZPromise*) thenControlTask:(void (^)(T result,
                                        ZZPromiseControl* ctrl))task
                         name:(NSString*)promiseName
                    onRunLoop:(NSRunLoop*)runLoop;

/**
 * Returned Promise wraps the Promise returned by the factory.
 */
-(ZZPromise*) thenPromiseFactory:(ZZPromise* (^)(T result))factory
                            name:(NSString*)promiseName;

-(ZZPromise*) thenPromiseFactory:(ZZPromise* (^)(T result))factory
                            name:(NSString*)promiseName
                       onRunLoop:(NSRunLoop*)runLoop;

-(ZZPromise*) catchWithTask:(id (^)(NSError*))exBlock
                       name:(NSString*)promiseName;

-(ZZPromise*) catchWithTask:(id (^)(NSError *))exBlock
                       name:(NSString*)promiseName
                  onRunLoop:(NSRunLoop*)runLoop;

-(ZZPromise*) catchWithControlTask:(void (^)(NSError* err,
                                             ZZPromiseControl* ctrl))task
                              name:(NSString*)promiseName;
-(ZZPromise*) catchWithControlTask:(void (^)(NSError* err,
                                             ZZPromiseControl* ctrl))task
                              name:(NSString*)promiseName
                         onRunLoop:(NSRunLoop*)runLoop;

-(ZZPromise*) catchWithPromiseFactory:(ZZPromise* (^)(NSError*))factory
                                 name:(NSString*)promiseName;

-(ZZPromise*) catchWithPromiseFactory:(ZZPromise *(^)(NSError *))factory
                                 name:(NSString*)promiseName
                            onRunLoop:(NSRunLoop*)runLoop;
/**
 * Only needed for delayed Promises.
 */
-(void) start;

/**
 * If the Promise's task is not executing, it will not be executed.
 * @return YES if task will not run and has not run.
 *         NO if not cancelled and the task has run or will continue running.
 */
-(BOOL) cancel;

-(void) waitUntilFinished;

-(void) printChain;

@end



