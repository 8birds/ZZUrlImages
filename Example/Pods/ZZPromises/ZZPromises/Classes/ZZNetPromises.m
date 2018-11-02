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

#import "ZZNetPromises.h"
#import <resolv.h>
#import <errno.h>


static NSString *const kErrDomain = @"Net Promise";

static NSError* makeError(NSString* domain, NSString* errorName, NSInteger code, NSString* reason){
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(errorName, nil),
                                NSLocalizedFailureReasonErrorKey: NSLocalizedString(reason, nil) };
    NSError* err = [NSError errorWithDomain:domain
                                       code:code
                                   userInfo:userInfo];
    return err;
}

@interface ZZHTTPPromiseResponse()
-(instancetype) initWithResponse:(NSURLResponse*)response
                            data:(NSData*)data;
@end

@implementation ZZHTTPPromiseResponse
-(instancetype) initWithResponse:(NSURLResponse*)response
                            data:(NSData*)data
{
    self = [super init];
    if(!self)
        return nil;

    _response = response;
    if([response.class isKindOfClass:NSHTTPURLResponse.class]
       || [response.class isSubclassOfClass:NSHTTPURLResponse.class])
    {
        _httpResponse = (NSHTTPURLResponse*)response;
    }

    _data = data;

    return self;
}
@end

@interface RequestInfo : NSObject
@property (nonatomic) ZZPromiseControl* promiseCtrl;
@property (nonatomic) NSMutableData* responseBody;
@property (nonatomic) NSURLRequest* request;
@property (nonatomic) void (^uploadProgressListener)(float progress);
@property (nonatomic) void (^downloadProgressListener)(float progress);
@end

@interface NetPromisesImpl : NSObject<NSURLSessionDelegate,
                                      NSURLSessionDataDelegate>

@property (nonatomic) NSURLSession* session;
@property (nonatomic) NSMutableDictionary<NSURLSessionTask*, RequestInfo*>* reqMap;

@end

@implementation RequestInfo
@end

@implementation NetPromisesImpl

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    RequestInfo* reqInfo = _reqMap[task];
    if(!reqInfo)
        return;

    if(reqInfo.uploadProgressListener)
        reqInfo.uploadProgressListener((float)totalBytesSent / totalBytesExpectedToSend);
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    RequestInfo* reqInfo = _reqMap[downloadTask];
    if(!reqInfo)
        return;

    if(reqInfo.downloadProgressListener)
        reqInfo.downloadProgressListener((float)totalBytesWritten / totalBytesExpectedToWrite);
}

-(void) URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{

    RequestInfo* reqInfo = _reqMap[dataTask];
    if(!reqInfo)
        return;

    if(!reqInfo.responseBody)
        reqInfo.responseBody = [NSMutableData new];

    [reqInfo.responseBody appendData:data];
}

-(void)   URLSession:(NSURLSession *)session
                task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    RequestInfo* info = _reqMap[task];
    if(!info)
        return;

    [_reqMap removeObjectForKey:task];

    if(error){
        [info.promiseCtrl reject:error];
        return;
    }

    ZZHTTPPromiseResponse* response = [[ZZHTTPPromiseResponse alloc] initWithResponse:task.response data:info.responseBody];

    if(response.httpResponse && response.httpResponse.statusCode >= 400){
        /*
        NSLog(@"Got error response from %@ - %d: %@",
              info.request.URL,
              (int)response.httpResponse.statusCode,
              [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
        */
        NSURLComponents* url = [NSURLComponents componentsWithURL:info.request.URL
                                          resolvingAgainstBaseURL:NO];
        url.queryItems = nil;
        url.query = nil;

        [info.promiseCtrl reject:makeError(kErrDomain,
                                           [NSString stringWithFormat:@"Request Failed to %@", url.URL],
                                           response.httpResponse.statusCode,
                                           nil)];

        return;
    }
/*
    NSLog(@"Got response from %@ - %d: %@",
          info.request.URL,
          (int)response.httpResponse.statusCode,
          [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
 */
    [info.promiseCtrl resolve:response];
}

-(void) URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didBecomeStreamTask:(NSURLSessionStreamTask *)streamTask
{
    RequestInfo* reqInfo = _reqMap[dataTask];
    if(!reqInfo)
        return;

    [_reqMap removeObjectForKey:dataTask];
    _reqMap[streamTask] = reqInfo;
}

-(void) URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    RequestInfo* reqInfo = _reqMap[dataTask];
    if(!reqInfo)
        return;

    [_reqMap removeObjectForKey:dataTask];
    _reqMap[downloadTask] = reqInfo;
}

@end


static NetPromisesImpl* gImpl;

@implementation ZZNetPromises


+(void) initialize{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gImpl = [NetPromisesImpl new];
        gImpl.reqMap = [NSMutableDictionary new];
        gImpl.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:gImpl delegateQueue:NSOperationQueue.mainQueue];
    });
}

+(ZZPromise<ZZHTTPPromiseResponse*>*) requestWithURL:(NSURL*)url
                                              method:(NSString*)method
                                             headers:(NSDictionary<NSString *,NSString *> *)headers
                                                body:(NSData*)body
{
    return [ZZNetPromises requestWithURL:url
                                  method:method
                                 headers:headers
                                    body:body
                        onUploadProgress:nil
                      onDownloadProgress:nil];
}


+(ZZPromise<ZZHTTPPromiseResponse*>*) requestWithURL:(NSURL*)url
                                              method:(NSString*)method
                                             headers:(NSDictionary<NSString *,NSString *> *)headers
                                                body:(NSData*)body
                                    onUploadProgress:(void (^)(float progress))onUploadProgress
                                  onDownloadProgress:(void (^)(float progress))onDownloadProgress
{
    NSMutableURLRequest* req = [NSMutableURLRequest new];
    req.URL = url;
    req.HTTPMethod = method;
    req.allHTTPHeaderFields = [headers copy];
    req.HTTPBody = body;

    return [ZZNetPromises request:req
                 onUploadProgress:onUploadProgress
               onDownloadProgress:onDownloadProgress];
}

static NSError* httpError(NSURL* toURL,
                          NSHTTPURLResponse* res,
                          NSString* body)
{
    return [NSError errorWithDomain:kErrDomain code:res.statusCode userInfo:@{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP error %d to %@", (int)res.statusCode, toURL],
        NSLocalizedFailureReasonErrorKey: body
    }];
}

+(ZZPromise<NSData*>*) dataBodyFromURL:(NSURL *)url
                                method:(NSString *)method
                               headers:(NSDictionary<NSString *,NSString *> *)headers
                                  body:(NSData *)body
{
    return [ZZNetPromises dataBodyFromURL:url
                                   method:method
                                  headers:headers
                                     body:body
                         onUploadProgress:nil
                       onDownloadProgress:nil];
}

+(ZZPromise<NSData*>*) dataBodyFromURL:(NSURL *)url
                                method:(NSString *)method
                               headers:(NSDictionary<NSString *,NSString *> *)headers
                                  body:(NSData *)body
                      onUploadProgress:(void (^)(float progress))onUploadProgress
                    onDownloadProgress:(void (^)(float progress))onDownloadProgress
{
    return [[ZZNetPromises requestWithURL:url
                                 method:method
                                headers:headers
                                   body:body]
            thenControlTask:^(ZZHTTPPromiseResponse *response,
                              ZZPromiseControl* ctrl)
            {
                if(response.httpResponse.statusCode >= 400){
                    NSString* bodyStr = !response.data ? @"" : [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding];

                    [ctrl reject:httpError(url, response.httpResponse, bodyStr)];
                    return;
                }

                [ctrl resolve:body];
            } name:@"Data body from URL"];
}

+(ZZPromise<NSData*>*) dataBodyFromRequest:(NSURLRequest *)request{
    return [ZZNetPromises dataBodyFromRequest:request
                             onUploadProgress:nil
                           onDownloadProgress:nil];
}

+(ZZPromise<NSData*>*) dataBodyFromRequest:(NSURLRequest*)request
                          onUploadProgress:(void (^)(float progress))onUploadProgress
                        onDownloadProgress:(void (^)(float progress))onDownloadProgress
{
    return [[ZZNetPromises request:request
                onUploadProgress:onUploadProgress
              onDownloadProgress:onDownloadProgress]
            thenControlTask:^(ZZHTTPPromiseResponse *response,
                              ZZPromiseControl* ctrl)
            {
                if(response.httpResponse.statusCode >= 400){
                    NSString* bodyStr = !response.data
                                            ? @""
                                            : [[NSString alloc] initWithData:response.data
                                                                    encoding:NSUTF8StringEncoding];

                    [ctrl reject:httpError(request.URL, response.httpResponse, bodyStr)];
                    return;
                }

                [ctrl resolve:response.data];
            } name:@"Data body from request"];
}

+(ZZPromise<NSString*>*) stringBodyFromURL:(NSURL *)url
                                    method:(NSString *)method
                                   headers:(NSDictionary<NSString *,NSString *> *)headers
                                      body:(NSData *)body
{
    return [ZZNetPromises stringBodyFromURL:url
                                      method:method
                                    headers:headers
                                       body:body
                           onUploadProgress:nil
                         onDownloadProgress:nil];
}

+(ZZPromise<NSString*>*) stringBodyFromURL:(NSURL *)url
                                    method:(NSString *)method
                                   headers:(NSDictionary<NSString *,NSString *> *)headers
                                      body:(NSData *)body
                          onUploadProgress:(void (^)(float progress))onUploadProgress
                        onDownloadProgress:(void (^)(float progress))onDownloadProgress
{
    return [[ZZNetPromises dataBodyFromURL:url
                                    method:method
                                   headers:headers
                                      body:body]
    thenControlTask:^(NSData *bodyData, ZZPromiseControl* ctrl) {
        NSString* bodyStr = !bodyData
                                ? @""
                                : [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        [ctrl resolve:bodyStr];
    } name:@"String body from URL"];
}

+(ZZPromise<NSURLResponse*>*) request:(NSURLRequest *)req
                     onUploadProgress:(void (^)(float progress))onUploadProgress
                   onDownloadProgress:(void (^)(float progress))onDownloadProgress
{
    //NSLog(@"Making request to %@", req.URL);
    if(!req){
        return [ZZPromise promiseRejectedWith:makeError(kErrDomain,
                                                        @"Cannot make request",
                                                        EINVAL,
                                                        @"Request object is nil.")
                                         name:@"URL Request (not set)"];
    }

    return [ZZPromise promiseWithTask:^(ZZPromiseControl* ctrl) {

        NSURLSessionDataTask* dataTask = [gImpl.session dataTaskWithRequest:req];

        RequestInfo* reqInfo = [RequestInfo new];
        reqInfo.request = req;
        reqInfo.promiseCtrl = ctrl;
        reqInfo.uploadProgressListener = onUploadProgress;
        reqInfo.downloadProgressListener = onDownloadProgress;
        gImpl.reqMap[dataTask] = reqInfo;

        [dataTask resume];
    } name:@"URL Request"];
}

static NSError* errFromErrno(NSString* description, NSString* reason){
    return makeError(kErrDomain,
                     description,
                     errno,
                     reason);
}

+(ZZPromise<NSString*>*) nsTXTLookup:(NSString*)name{
    return [ZZPromise promiseWithTask:^(ZZPromiseControl *ctrl) {
        int status = res_init();
        if(status != 0){
            [ctrl reject:errFromErrno(@"Cannot lookup TXT record.",
                                      @"Cannot init resolver.")];
            return;
        }

        const size_t ANSWER_SIZE = 8192;
        NSMutableData* answerMemDeleter = [NSMutableData dataWithLength:ANSWER_SIZE];
        u_char* answer = (u_char*)answerMemDeleter.mutableBytes;

        int len = res_query(name.UTF8String,
                            ns_c_in,
                            ns_t_txt,
                            answer,
                            ANSWER_SIZE);

        if(len == -1){
            [ctrl reject:errFromErrno(@"Cannot lookup TXT record.",
                                      @"Query error.")];
            return;
        }

        ns_msg txtRecords;
        status = ns_initparse(answer, len, &txtRecords);
        if(status < 0){
            [ctrl reject:errFromErrno(@"Cannot lookup TXT record.",
                                      @"Response parse error.")];
            return;
        }

        int messageCount = ns_msg_count(txtRecords, ns_s_an);
        if(messageCount == 0){
            [ctrl reject:errFromErrno(@"Cannot lookup TXT record.",
                                      @"No messages.")];
            return;
        }

        NSMutableArray<NSString*>* txtRecordsContents = [NSMutableArray new];
        for(int i = 0; i < messageCount; i++){
            ns_rr parsedRecord;
            status = ns_parserr(&txtRecords, ns_s_an, i, &parsedRecord);

            if(status != 0)
                continue;

            int txtLen = ns_rr_rdlen(parsedRecord);
            const u_char* txtData = ns_rr_rdata(parsedRecord);

            const u_char* txtDataEnd = txtData + txtLen;

            NSMutableString* txtContents = [NSMutableString new];
            while(txtData < txtDataEnd){
                //1-byte length, string of that length, continue until full length accounted for.
                int len = txtData[0];
                txtData++;

                [txtContents appendFormat:@"%.*s",
                                          len,
                                          txtData];
                txtData += len;
            }

            [txtRecordsContents addObject:txtContents.copy];
        }

        if(txtRecordsContents.count == 0){
            [ctrl reject:errFromErrno(@"Cannot lookup TXT record.",
                                      @"Message parse error.")];
            return;
        }

        [ctrl resolve:txtRecordsContents[0]];
    } name:@"DNS TXT Lookup"];
}

@end
