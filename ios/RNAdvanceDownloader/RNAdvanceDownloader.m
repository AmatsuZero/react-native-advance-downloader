//
//  RNAdvanceDownloader.m
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//
#import "RNAdvanceDownloader.h"
#import "RNAdvanceDownloadOperation.h"
#import "RNAdvanceDownloadReceipt+RNAdvanceDownloadReceiptExtension.h"
#import "RNAdvanceDownloader+RNAdvanceDownloaderExtension.h"
#import "RNAdvanceDownloadOperation+RNAdvanceDownloadOperationExtension.h"

void dispatch_main_async_safe(void (^block)(void)) {
    const char* currentLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char* mainLabLabel = dispatch_queue_get_label(dispatch_get_main_queue());
    if (strcmp(currentLabel, mainLabLabel) == 0) {// 判断是否在主线程
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@implementation RNAdvanceDownloader
{
    BOOL hasListeners;
}
RCT_EXPORT_MODULE(RNAdvanceDownloader)
-(NSMutableDictionary *)allDownloadRecepits {
    if (!_allDownloadRecepits) {
        NSDictionary* recepits = [NSKeyedUnarchiver unarchiveObjectWithFile:LocalRecepitsPath()];
        _allDownloadRecepits = recepits != nil ? [recepits mutableCopy] : [NSMutableDictionary dictionary];
    }
    return _allDownloadRecepits;
}

+(RNAdvanceDownloader *)sharedDownloader {
    static RNAdvanceDownloader* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

-(instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration {
    if (self = [super init]) {
        _operationClass = [RNAdvanceDownloadOperation class];
        _downloadPrioritization = RNAdvanceDownloadPrioritizationFIFO;
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 3;
        _downloadQueue.name = @"com.daubert.RNAdvanceDownloader";
        _URLOpertaions = [NSMutableDictionary dictionary];
        _barrierQueue = dispatch_queue_create("com.daubert.RNAdvanceDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;

        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;
        sessionConfiguration.HTTPMaximumConnectionsPerHost = 10;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:self];
    }
    return self;
}

-(NSString *)valueForHTTPHeaderField:(NSString *)field {
    return self.httpHeaders[field];
}

-(NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

-(NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

-(void)setOperationClass:(Class)operationClass {
    if (operationClass && [operationClass isSubclassOfClass:[NSOperation class]] && [operationClass conformsToProtocol:@protocol(RNAdvanceDownloadOperationProtocol)]) {
        _operationClass = operationClass;
    } else {
        _operationClass = [RNAdvanceDownloadOperation class];
    }
}

-(RNAdvanceDownloadReceipt *)downloadDataWithURL:(NSURL *)url
                                        progress:(RNAdvanceDownloaderProgressBlock)progressBlock
                                       completed:(RNAdvanceDownloaderCompletedBlock)completeBlock {
    RNAdvanceDownloadReceipt* recepit = [self downloadRecepitForURLString:url.absoluteString];
    if (recepit.state == RNAdvanceDownloadStateCompleted) {
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RNAdvanceDownloadFinishNotification
                                                                object:self];
            if (completeBlock) {
                completeBlock(recepit, nil, YES);
            }
            if (recepit.downloaderCompleteBlock) {
                recepit.downloaderCompleteBlock(recepit, nil, YES);
            }
        });
        return recepit;
    }
    __weak typeof(self) weakSelf = self;
    return [self addProgressCallBack:progressBlock completeBlock:completeBlock forURL:url createCallBack:^RNAdvanceDownloadOperation *{
        __strong typeof(self) strongSelf= weakSelf;
        NSTimeInterval timeoutInterval = strongSelf.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url];
        RNAdvanceDownloadReceipt* recepit = [strongSelf downloadRecepitForURLString:url.absoluteString];
        if (recepit.totalBytesWritten > 0) {
            NSString* range = [NSString stringWithFormat:@"bytes=%lld-",recepit.totalBytesWritten];
            [request setValue:range forKey:@"Range"];
        }
        request.HTTPShouldUsePipelining = YES;
        if (strongSelf.headersFilter) {
            request.allHTTPHeaderFields = strongSelf.headersFilter(url, [strongSelf.httpHeaders copy]);
        } else {
            request.allHTTPHeaderFields = strongSelf.httpHeaders;
        }
        RNAdvanceDownloadOperation* operation = [[strongSelf.operationClass alloc] initWithRequest:request
                                                                                         inSession:strongSelf.session];
        [strongSelf.downloadQueue addOperation:operation];
        if (strongSelf.downloadPrioritization == RNAdvanceDownloadPrioritizationLIFO) {
            // 如果是后进先出的顺序添加任务，需要将此任务添加到最后一个上
            [strongSelf.lastAddedOperation addDependency:operation];
            strongSelf.lastAddedOperation = operation;
        }
        return operation;
    }];
}

- (RNAdvanceDownloadReceipt *)downloadRecepitForURLString:(NSString *)URLString {
    if (!URLString) {
        return nil;
    }
    if (self.allDownloadRecepits[URLString]) {
        return self.allDownloadRecepits[URLString];
    } else {
        RNAdvanceDownloadReceipt* recepit = [[RNAdvanceDownloadReceipt alloc] initWithURLString:URLString
                                                                   downloadOperationCancelToken:nil
                                                                        downloaderProgressBlock:nil
                                                                       downloaderCompletedBlock:nil];
        self.allDownloadRecepits[URLString] = recepit;
        return recepit;
    }
    return nil;
}

- (RNAdvanceDownloadReceipt *)addProgressCallBack:(RNAdvanceDownloaderProgressBlock)progressBlock
                                    completeBlock:(RNAdvanceDownloaderCompletedBlock)completeBlock
                                           forURL:(NSURL *)url
                                   createCallBack:(RNAdvanceDownloadOperation *(^)(void))createCallback {
    if (!url) {
        if (completeBlock) {
            completeBlock(nil, nil, NO);
        }
        return nil;
    }
    __block RNAdvanceDownloadReceipt* token = nil;
    dispatch_barrier_sync(self.barrierQueue, ^{
        RNAdvanceDownloadOperation* operation = self.URLOpertaions[url];
        if (!operation) {
            operation = createCallback();
            self.URLOpertaions[url] = operation;

            __weak RNAdvanceDownloadOperation* weakOperaion = operation;
            operation.completionBlock = ^{
                if (!weakOperaion) {
                    return;
                }
                if (self.URLOpertaions[url] == weakOperaion) {
                    [self. URLOpertaions removeObjectForKey:url];
                }
            };
        }
        id downloadOpertaionCancelToken = [operation addHandlerForProgress:progressBlock completed:completeBlock];
        if (!self.allDownloadRecepits[url.absoluteString]) {
            token = [[RNAdvanceDownloadReceipt alloc] initWithURLString:url.absoluteString
                                           downloadOperationCancelToken:downloadOpertaionCancelToken
                                                downloaderProgressBlock:nil
                                               downloaderCompletedBlock:nil];
            self.allDownloadRecepits[url.absoluteString] = token;
        } else {
            token = self.allDownloadRecepits[url.absoluteString];
            if (!token.downloadOperationCancelToken) {
                [token setDownloadOperationCancelToken:downloadOpertaionCancelToken];
            }
        }
    });
    return token;
}

-(void)setAllStateToNone {
    [self.allDownloadRecepits enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[RNAdvanceDownloadReceipt class]]) {
            RNAdvanceDownloadReceipt* recepit = obj;
            if (recepit.state != RNAdvanceDownloadStateCompleted) {
                [recepit setState:RNAdvanceDownloadStateNone];
            }
        }
    }];
}

-(void)saveAllDownloadRecepits {
    [NSKeyedArchiver archiveRootObject:self.allDownloadRecepits toFile:LocalRecepitsPath()];
}

-(void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    [self.downloadQueue cancelAllOperations];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (RNAdvanceDownloadOperation*)operationWithTask:(NSURLSessionTask*)task {
    for (RNAdvanceDownloadOperation* operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            return operation;
        }
    }
    return nil;
}

#pragma Control Methods
- (void) cancel:(RNAdvanceDownloadReceipt *)token completed:(void (^)(void))completed {
    dispatch_barrier_async(self.barrierQueue, ^{
        NSURL* key = [NSURL URLWithString:token.url];
        RNAdvanceDownloadOperation* operation = self.URLOpertaions[key];
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOpertaions removeObjectForKey:key];
            [token setState:RNAdvanceDownloadStateNone];
        }
        dispatch_main_async_safe(^{
            if (completed) {
                completed();
            }
        });
    });
}

- (void) remove:(RNAdvanceDownloadReceipt *)token completed:(void (^)(void))completed {
    [token setState:RNAdvanceDownloadStateNone];
    [self cancel:token completed:^{
        NSFileManager* fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:token.filePath error:nil];
        dispatch_main_async_safe(^{
            if (completed) {
                completed();
            }
        });
    }];
}

#pragma mark - Notifications
- (void) applicationWillTerminate: (NSNotification*)notification {
    [self setAllStateToNone];
    [self saveAllDownloadRecepits];
}

- (void) applicationDidReceiveMemoryWarning:(NSNotification*)notification {
    [self saveAllDownloadRecepits];
}

- (void) applicationWillResignActive:(NSNotification*)notification {
    [self saveAllDownloadRecepits];
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    if (hasApplication) {
        __weak typeof(self) weakSelf = self;
        UIApplication* app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf setAllStateToNone];
                [strongSelf saveAllDownloadRecepits];
                [app endBackgroundTask:strongSelf.backgroundTaskId];
                strongSelf.backgroundTaskId = UIBackgroundTaskInvalid;
            }
        }];
    }
}

- (void) applicationDidBecomeActive:(NSNotification*)notification {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication* app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
    NSString* cacheDir = [NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) firstObject];
    NSString* cachePath = [cacheDir stringByAppendingPathComponent:RNAdvanceDownloadCacheFolderName];
    NSString* existedCacheFolerPath = cacheFolder();
    if (existedCacheFolerPath && ![existedCacheFolerPath isEqualToString:cachePath]) {
        clearCacheFolder();
        [self.allDownloadRecepits enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[RNAdvanceDownloadReceipt class]]) {
                RNAdvanceDownloadReceipt* receipt = obj;
                receipt.filePath = nil;
            }
        }];
    }
}

#pragma mark - NSURLSessionDataDelegate
- (void) URLSession:(NSURLSession *)session
           dataTask:(NSURLSessionDataTask *)dataTask
 didReceiveResponse:(NSURLResponse *)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    RNAdvanceDownloadOperation* dataoperation = [self operationWithTask:dataTask];
    [dataoperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void) URLSession:(NSURLSession *)session
           dataTask:(NSURLSessionDataTask *)dataTask
     didReceiveData:(NSData *)data {
    RNAdvanceDownloadOperation* dataoperation = [self operationWithTask:dataTask];
    [dataoperation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void) URLSession:(NSURLSession *)session
           dataTask:(NSURLSessionDataTask *)dataTask
  willCacheResponse:(NSCachedURLResponse *)proposedResponse
  completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    RNAdvanceDownloadOperation* dataoperation = [self operationWithTask:dataTask];
    [dataoperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    RNAdvanceDownloadOperation* dataoperation = [self operationWithTask:task];
    [dataoperation URLSession:session task:task didCompleteWithError:error];
}

#pragma mark - RN Methods

RCT_EXPORT_METHOD(cancelAllDownloads) {
    [self.downloadQueue cancelAllOperations];
    [self setAllStateToNone];
    [self saveAllDownloadRecepits];
}

RCT_EXPORT_METHOD(setDownloadPrioritization:(RNAdvanceDownloadPrioritization)downloadPrioritization) {
    _downloadPrioritization = downloadPrioritization;
}

RCT_EXPORT_METHOD(getMaxConcurrentDownloads: (RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], @(self.maxConcurrentDownloads)]);
}

RCT_EXPORT_METHOD(setMaxConcurrentDownloads:(NSInteger)num) {
    _downloadQueue.maxConcurrentOperationCount = num;
}

RCT_EXPORT_METHOD(getCurrentDownloadCount: (RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], @(self.maxConcurrentDownloads)]);
}

RCT_EXPORT_METHOD(getTimeout: (RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], @(self.downloadTimeout)]);
}

RCT_EXPORT_METHOD(setDownloadTimeout:(NSTimeInterval)downloadTimeout) {
    _downloadTimeout = downloadTimeout;
}

RCT_EXPORT_METHOD(setValue:(NSString *)value forHTTPHeaderField:(NSString *)field) {
    if (value) {
        [self.httpHeaders setValue:value forKey:field];
    } else {
        [self.httpHeaders removeObjectForKey:field];
    }
}

RCT_EXPORT_METHOD(valueForHTTPHeaderField:(nullable NSString*)field callback:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], [self valueForHTTPHeaderField:field] ?: [NSNull null]]);
}
RCT_EXPORT_METHOD(setSuspend:(BOOL)suspend) {
    self.downloadQueue.suspended = suspend;
}

RCT_EXPORT_METHOD(setCacheFolder:(NSString*)path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        cacheFolderPath = path;
        resolve(path);
    } else {
        NSString* message = @"Path dosen't exist yet";
        reject(message, @"-101", [NSError errorWithDomain:NSURLErrorDomain
                                                     code:-101
                                                 userInfo:@{NSLocalizedDescriptionKey:message}]);
    }
}

RCT_EXPORT_METHOD(removeAndClearAll) {
    [self cancelAllDownloads];
    [[NSFileManager defaultManager] removeItemAtPath:cacheFolder() error:nil];
    clearCacheFolder();
}

RCT_EXPORT_METHOD(cancelTask: (nonnull NSString*)url callback:(RCTResponseSenderBlock)callback) {
    RNAdvanceDownloadReceipt* receipt = self.allDownloadRecepits[url];
    if (!receipt) {
        return;
    }
    [self cancel:receipt completed:^{
        callback(@[[NSNull null], @(YES)]);
    }];
}

RCT_EXPORT_METHOD(removeTask: (nonnull NSString*)url callback:(RCTResponseSenderBlock)callback) {
    RNAdvanceDownloadReceipt* receipt = self.allDownloadRecepits[url];
    if (!receipt) {
        return;
    }
    [self remove:receipt completed:^{
        callback(@[[NSNull null], @(YES)]);
    }];
}

-(NSDictionary *)constantsToExport {
    return  @{@"none": @(RNAdvanceDownloadStateNone),
              @"resume": @(RNAdvanceDownloadStateWillResume),
              @"downloading": @(RNAdvanceDownloadStateDownloading),
              @"suspend": @(RNAdvanceDownloadStateSuspend),
              @"fail": @(RNAdvanceDownloadStateFailed),
              @"completed": @(RNAdvanceDownloadStateCompleted),
              @"FIFO":@(RNAdvanceDownloadPrioritizationFIFO),
              @"LIFO":@(RNAdvanceDownloadPrioritizationLIFO)};
}

RCT_EXPORT_METHOD(taskState:(NSString*)url callback:(RCTResponseSenderBlock)callback) {
    RNAdvanceDownloadReceipt* receipt = self.allDownloadRecepits[url];
    if (!receipt) {
        callback(@[[NSNull null], @"none"]);
    } else {
        NSString* state = @"none";
        switch (receipt.state) {
            case RNAdvanceDownloadStateNone: state = @"none";
                break;
            case RNAdvanceDownloadStateWillResume: state = @"resume";
                break;
            case RNAdvanceDownloadStateDownloading: state = @"downloading";
                break;
            case RNAdvanceDownloadStateSuspend: state = @"suspend";
                break;
            case RNAdvanceDownloadStateFailed: state = @"fail";
                break;
            case RNAdvanceDownloadStateCompleted: state = @"completed";
                break;
        }
        callback(@[[NSNull null], state]);
    }
}

#pragma mark - Download Events
-(NSArray<NSString *> *)supportedEvents {
    return @[@"Downloading", @"Completed"];
}

RCT_EXPORT_METHOD(addDownloadTask:(nonnull NSString*)url) {
    __weak typeof(self) weakSelf = self;
    [self downloadDataWithURL:[NSURL URLWithString:url] progress:^(NSInteger receivedSize, NSInteger expectedSize, NSInteger speed, NSURL * _Nullable targetURL) {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf->hasListeners) {
            [self sendEventWithName:@"Downloading" body:@{@"receivedSize": @(receivedSize),
                                                          @"expectedSize": @(expectedSize),
                                                          @"speed": @(speed),
                                                          @"url": targetURL ?: [NSNull null]}];
        }
    } completed:^(RNAdvanceDownloadReceipt * _Nullable receipt, NSError * _Nullable error, BOOL isFinished) {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf->hasListeners) {
            [self sendEventWithName:@"Completed" body:@{@"fileName": receipt.fileName ?:[NSNull null],
                                                        @"filePath": receipt.filePath ?:[NSNull null],
                                                        @"url": receipt.url ?: [NSNull null],
                                                        @"error": error.localizedDescription ?: [NSNull null],
                                                        @"isFinished": @(isFinished)
                                                        }];
        }
    }];
}

-(void)startObserving {
    hasListeners = YES;
}

-(void)stopObserving {
    hasListeners = NO;
}

@end
