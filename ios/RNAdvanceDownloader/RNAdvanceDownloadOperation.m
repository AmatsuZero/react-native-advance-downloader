//
//  RNAdvanceDownloadOperation.m
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/15.
//  Copyright © 2018年 MockingBot. All rights reserved.
//
@import UIKit;
#import "RNAdvanceDownloadOperation.h"
#import "RNAdvanceDownloadOperation+RNAdvanceDownloadOperationExtension.h"
#import "RNAdvanceDownloadReceipt+RNAdvanceDownloadReceiptExtension.h"

NSString* const RNAdvanceDownloadStartNotification = @"RNAdvanceDownloadStartNotification";
NSString* const RNAdvanceDownloadReceiveResponseNotifcation = @"RNAdvanceDownloadReceiveResponseNotifcation";
NSString* const RNAdvanceDownloadStopNotification = @"RNAdvanceDownloadStopNotification";
NSString* const RNAdvanceDownloadFinishNotification = @"RNAdvanceDownloadFinishNotification";

static NSString* const kProgressCallbackKey = @"progress";
static NSString* const kCompleteCallbackKey = @"completed";

@interface RNAdvanceDownloadOperation()

@property(assign, nonatomic, getter=isExecuting) BOOL executing;
@property(assign, nonatomic, getter=isFinished) BOOL finished;

@end

@implementation RNAdvanceDownloadOperation
{
    BOOL responseFromCached;
}

@synthesize executing = _executing;
@synthesize finished = _finished;

- (RNAdvanceDownloadReceipt *)receipt {
    if (!_receipt) {
        _receipt = [[RNAdvanceDownloader sharedDownloader] downloadRecepitForURLString:self.request.URL.absoluteString];
    }
    return _receipt;
}

-(instancetype)init {
    return [self initWithRequest:nil inSession:nil];
}

-(instancetype)initWithRequest:(NSURLRequest *)request inSession:(NSURLSession *)session {
    if (self = [super init]) {
        _request = [request copy];
        _callbackBlocks = [NSMutableArray array];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        responseFromCached = YES;
        _barrierQueue = dispatch_queue_create("com.daubert.RNAdvanceDownloaderOperationQueue", DISPATCH_QUEUE_CONCURRENT);
        [self.receipt setState:RNAdvanceDownloadStateWillResume];
    }
    return self;
}

- (nullable id)addHandlerForProgress:(nullable RNAdvanceDownloaderProgressBlock)progresBlock
                           completed:(nullable RNAdvanceDownloaderCompletedBlock)completedBlock {
    RNAdvanceDownloadCallbacksDictionary* callbacks = [NSMutableDictionary dictionary];
    if (progresBlock) {
        callbacks[kProgressCallbackKey] = [progresBlock copy];
    }
    if (completedBlock) {
        callbacks[kCompleteCallbackKey] = [completedBlock copy];
    }
    return callbacks;
}

- (nullable NSArray<id>*) callbacksForKey: (NSString*)key {
    __block NSMutableArray<id> *callbacks = nil;
    dispatch_sync(self.barrierQueue, ^{
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });
    return [callbacks copy];
}

-(void) start {
    @synchronized(self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
#if TARGET_OS_IOS
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplication respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEnterBackground]) {
            __weak typeof(self) weakSelf = self;
            UIApplication* app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf cancel];
                    [app endBackgroundTask:strongSelf.backgroundTaskId];
                    strongSelf.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
#endif
        NSURLSession* session = self.unownedSession;
        if (!self.unownedSession) {
            NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:nil];
            session = self.ownedSession;
        }
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }
    [self.dataTask resume];
    if (self.dataTask) {
        for (RNAdvanceDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, NSURLResponseUnknownLength, 0, self.request.URL);
        }
        [self.receipt setState:RNAdvanceDownloadStateDownloading];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadStartNotification
                                                                object:self];
        });
    } else {
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                code:0
                                                            userInfo:@{NSLocalizedDescriptionKey:@"Connection can't be initialized"}]];
    }
#if TARGET_OS_IOS
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication* app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}

-(BOOL)cancel:(id)token {
    __block BOOL shouldCancel = NO;
    dispatch_barrier_sync(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
        shouldCancel = self.callbackBlocks.count == 0;
    });
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}

-(void) cancel {
    @synchronized(self) {
        [self cancelInternal];
    }
}

- (void) cancelInternal {
    if (self.isFinished) {
        return;
    }
    [super cancel];
    if (self.dataTask) {
        [self.dataTask cancel];
        [self.receipt setState:RNAdvanceDownloadStateNone];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadStopNotification
                                                                object:self];
        });
        if (self.isExecuting) {
            self.executing = NO;
        }
        if (!self.isFinished) {
            self.finished = YES;
        }
    }
}

-(void) done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void) reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

-(void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

-(void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExectuing"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

-(BOOL)isConcurrent {
    return YES;
}

-(BOOL)shouldContinueWhenAppEnterBackground {
    return YES;
}

-(void)callCompletionBlocksWithError:(nullable NSError*)error {
    [self callCompletionBlocksWithFileURL:nil data:nil error:error finished:YES];
}

-(void)callCompletionBlocksWithFileURL:(nullable NSURL*)fileURL
                                  data:(nullable NSData*)data
                                 error:(nullable NSError*)error
                              finished:(BOOL)finished {
    if (error) {
        [self.receipt setState:RNAdvanceDownloadStateFailed];
    } else {
        [self.receipt setState:RNAdvanceDownloadStateCompleted];
    }
    NSArray<id> * completionBlocks = [self callbacksForKey:kCompleteCallbackKey];
    dispatch_main_async_safe(^{
        for (RNAdvanceDownloaderCompletedBlock completedBlock in completionBlocks) {
            completedBlock(self.receipt, error, finished);
        }
        if (self.receipt.downloaderCompleteBlock) {
            self.receipt.downloaderCompleteBlock(self.receipt, error, YES);
        }
    });
}

-(NSString*)formatByteCount:(long long)size {
    return [NSByteCountFormatter stringFromByteCount:size
                                          countStyle:NSByteCountFormatterCountStyleFile];
}

#pragma mark - NSURLSessionDataDelegate
-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (![response respondsToSelector:@selector(statusCode)] ||
        (((NSHTTPURLResponse*)response).statusCode < 400 && ((NSHTTPURLResponse*)response).statusCode != 304)) {
        NSInteger expected = response.expectedContentLength > 0 ? (NSInteger)response.expectedContentLength : 0;
        RNAdvanceDownloadReceipt* receipt = [[RNAdvanceDownloader sharedDownloader] downloadRecepitForURLString:self.request.URL.absoluteString];
        [receipt setTotalBytesWritten:expected + receipt.totalBytesWritten];
        receipt.date = [NSDate date];

        self.expectedSize = expected;
        for (RNAdvanceDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, expected, 0, self.request.URL);
        }
        self.response = response;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadFinishNotification
                                                                object:self];
        });
    } else if (![response respondsToSelector:@selector(statusCode)] || ((NSHTTPURLResponse*)response).statusCode == 416) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadFinishNotification
                                                            object:self];
        [self callCompletionBlocksWithFileURL:[NSURL fileURLWithPath:self.receipt.filePath]
                                         data:[NSData dataWithContentsOfFile:self.receipt.filePath]
                                        error:nil
                                     finished:YES];
        [self done];
    } else {
        NSInteger code = ((NSHTTPURLResponse*)response).statusCode;
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
            [self.receipt setState:RNAdvanceDownloadStateNone];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadStopNotification
                                                                object:self];
        });
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                code:code
                                                            userInfo:nil]];
        [self.receipt setState:RNAdvanceDownloadStateNone];
        [self done];
    }
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
   didReceiveData:(NSData *)data {
    __block NSError* error = nil;
    RNAdvanceDownloadReceipt* receipt = [[RNAdvanceDownloader sharedDownloader] downloadRecepitForURLString:self.request.URL.absoluteString];
    //Speed
    receipt.totalRead += data.length;
    NSDate* currentDate = [NSDate date];
    if ([currentDate timeIntervalSinceDate:receipt.date] >= 1) {
        double time = [currentDate timeIntervalSinceDate:receipt.date];
        long long speed = receipt.totalRead/time;
        receipt.speed = [self formatByteCount:speed];
        receipt.totalRead = 0.0;
        receipt.date = currentDate;
    }
    //Write Data
    NSInputStream* inputStream = [[NSInputStream alloc] initWithData:data];
    NSOutputStream* outputStream = [[NSOutputStream alloc] initWithURL:[NSURL fileURLWithPath:receipt.filePath]
                                                                append:YES];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    [inputStream open];
    [outputStream open];

    while ([inputStream hasBytesAvailable] && [outputStream hasSpaceAvailable]) {
        uint8_t buffer[1024];

        NSInteger bytesRead = [inputStream read:buffer maxLength:1024];
        if (inputStream.streamError || bytesRead < 0) {
            error = inputStream.streamError;
            break;
        }

        NSInteger bytesWritten = [outputStream write:buffer maxLength:bytesRead];
        if (outputStream.streamError || bytesWritten < 0) {
            error = outputStream.streamError;
            break;
        }

        if (bytesRead == 0 && bytesWritten == 0) {
            break;
        }
    }

    [outputStream close];
    [outputStream close];

    receipt.progress.totalUnitCount = receipt.totalBytesExpectedToWrite;
    receipt.progress.completedUnitCount = receipt.totalBytesWritten;

    dispatch_main_async_safe(^{
        for (RNAdvanceDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(receipt.progress.completedUnitCount,
                          receipt.progress.totalUnitCount,
                          receipt.speed.integerValue,
                          self.request.URL);
        }
        if (self.receipt.downloaderProgressBlock) {
            self.receipt.downloaderProgressBlock(receipt.progress.completedUnitCount,
                                                 receipt.progress.totalUnitCount,
                                                 receipt.speed.integerValue,
                                                 self.request.URL);
        }
    });
}

-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
willCacheResponse:(NSCachedURLResponse *)proposedResponse
completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    responseFromCached = NO; // 说明响应体来自缓存
    NSCachedURLResponse* cachedResponse = proposedResponse;
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized(self) {
        self.dataTask = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadStopNotification
                                                                object:self];
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadFinishNotification
                                                                    object:self];
            }
        });
        if (error) {
            [self callCompletionBlocksWithError:error];
        } else {
            RNAdvanceDownloadReceipt* recepit = self.receipt;
            [recepit setState:RNAdvanceDownloadStateCompleted];
            if ([self callbacksForKey:kCompleteCallbackKey].count > 0) {
                [self callCompletionBlocksWithFileURL:[NSURL fileURLWithPath:recepit.filePath]
                                                 data:[NSData dataWithContentsOfFile:recepit.filePath]
                                                error:nil
                                             finished:YES];
            }
            dispatch_main_async_safe(^{
                if (self.receipt.downloaderCompleteBlock) {
                    self.receipt.downloaderCompleteBlock(recepit, nil, YES);
                }
            });
        }
    }
    [self done];
}

@end
