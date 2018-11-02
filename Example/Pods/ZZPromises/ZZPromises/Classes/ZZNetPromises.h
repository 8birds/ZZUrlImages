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
#import "ZZPromise.h"

@interface ZZHTTPPromiseResponse : NSObject
@property (readonly) NSURLResponse* response;
@property (readonly) NSHTTPURLResponse* httpResponse;
@property (readonly) NSData* data;
@end

@interface ZZNetPromises : NSObject

+(ZZPromise<ZZHTTPPromiseResponse*>*) request:(NSURLRequest*)req
                             onUploadProgress:(void (^)(float progress))onUploadProgress
                           onDownloadProgress:(void (^)(float progress))onDownloadProgress;

+(ZZPromise<ZZHTTPPromiseResponse*>*) requestWithURL:(NSURL*)url
                                              method:(NSString*)method
                                             headers:(NSDictionary<NSString*, NSString*>*)headers
                                                body:(NSData*)body;

+(ZZPromise<ZZHTTPPromiseResponse*>*) requestWithURL:(NSURL*)url
                                              method:(NSString*)method
                                             headers:(NSDictionary<NSString*, NSString*>*)headers
                                                body:(NSData*)body
                                    onUploadProgress:(void (^)(float progress))onUploadProgress
                                  onDownloadProgress:(void (^)(float progress))onDownloadProgress;

+(ZZPromise<NSData*>*) dataBodyFromURL:(NSURL *)url
                                method:(NSString *)method
                               headers:(NSDictionary<NSString *,NSString *> *)headers
                                  body:(NSData *)body;

+(ZZPromise<NSData*>*) dataBodyFromURL:(NSURL *)url
                                method:(NSString *)method
                               headers:(NSDictionary<NSString *,NSString *> *)headers
                                  body:(NSData *)body
                      onUploadProgress:(void (^)(float progress))onUploadProgress
                    onDownloadProgress:(void (^)(float progress))onDownloadProgress;

+(ZZPromise<NSString*>*) stringBodyFromURL:(NSURL*)url
                                    method:(NSString*)method
                                   headers:(NSDictionary<NSString*, NSString*>*)headers
                                      body:(NSData*)body;

+(ZZPromise<NSString*>*) stringBodyFromURL:(NSURL*)url
                                    method:(NSString*)method
                                   headers:(NSDictionary<NSString*, NSString*>*)headers
                                      body:(NSData*)body
                          onUploadProgress:(void (^)(float progress))onUploadProgress
                        onDownloadProgress:(void (^)(float progress))onDownloadProgress;

+(ZZPromise<NSData*>*) dataBodyFromRequest:(NSURLRequest*)request;

+(ZZPromise<NSData*>*) dataBodyFromRequest:(NSURLRequest*)request
                          onUploadProgress:(void (^)(float progress))onUploadProgress
                        onDownloadProgress:(void (^)(float progress))onDownloadProgress;

+(ZZPromise<NSString*>*) nsTXTLookup:(NSString*)name;

@end
