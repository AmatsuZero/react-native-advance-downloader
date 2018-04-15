//
//  RNAdvanceDownloader.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "RNAdvanceDownloadReceipt.h"

void dispatch_main_async_safe(void (^block)(void));

FOUNDATION_EXPORT NSString* const RNAdvanceDownloadCacheFolderName;
FOUNDATION_EXPORT NSString* cacheFolder(void);

extern NSString* _Nonnull const RNAdvanceDownloadStartNotification;
extern NSString* _Nonnull const RNAdvanceDownloadStopNotification;

typedef NSDictionary<NSString*, NSString*> RNAdvanceHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString*, NSString*> RNAdvanceHTTPHeadersMutableDictionary;
typedef RNAdvanceHTTPHeadersDictionary * _Nonnull (^RNAdvanceDownloaderHeadersFilterBlock)(NSURL* _Nullable url,
                                                                                           RNAdvanceHTTPHeadersDictionary* _Nullable headers);

@interface RNAdvanceDownloader : RCTEventEmitter<RCTBridgeModule>

/**
 最大同时下载任务数
 */
@property(assign, nonatomic)NSInteger maxConcurrentDownloads;

/**
 当前任务数
 */
@property(readonly ,nonatomic)NSUInteger currentDownloadCount;

/**
 超时时间，默认时间为15.0
 */
@property(assign, nonatomic)NSTimeInterval downloadTimeout;

/**
 下载优先度
 */
@property(nonatomic, assign)RNAdvanceDownloadPrioritization downloadPrioritization;

/**
 单例
 */
@property(nonatomic, class, nonnull, readonly)RNAdvanceDownloader* sharedDownloader;

/**
 下载图片HTTP请求专用
 */
@property(nonatomic, copy, nullable)RNAdvanceDownloaderHeadersFilterBlock headersFilter;

- (nonnull instancetype)initWithSessionConfiguration: (nonnull NSURLSessionConfiguration*)sessionConfiguration NS_DESIGNATED_INITIALIZER;

- (void) setValue:(nonnull NSString*)value forHTTPHeaderField:(nonnull NSString *)field;

- (nullable NSString*) valueForHTTPHeaderField:(nullable NSString*)field;

- (void) setOperationClass: (nullable Class)operationClass;

- (nullable RNAdvanceDownloadReceipt*) downloadDataWithURL: (nullable NSURL*)url
                                                 progress: (nullable RNAdvanceDownloaderProgressBlock)progressBlock
                                                completed: (nullable RNAdvanceDownloaderCompletedBlock)completeBlock;

- (nullable RNAdvanceDownloadReceipt*) downloadRecepitForURLString: (nullable NSString*)URLString;

- (void) cancel: (nullable RNAdvanceDownloadReceipt*)token completed: (nullable void(^)(void))completed;
- (void) remove: (nullable RNAdvanceDownloadReceipt*)token completed: (nullable void(^)(void))completed;
- (void) setSuspend: (BOOL) suspend;
- (void) cancelAllDownloads;
- (void) removeAndClearAll;
@end
