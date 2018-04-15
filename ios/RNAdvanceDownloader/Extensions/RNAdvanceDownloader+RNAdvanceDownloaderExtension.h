//
//  RNAdvanceDownloader+RNAdvanceDownloaderExtension.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/15.
//  Copyright © 2018年 MockingBot. All rights reserved.
//
@import UIKit;
#import "RNAdvanceDownloader.h"

NSString* const RNAdvanceDownloadCacheFolderName = @"RNAdvanceDownloadCache";

static NSString* cacheFolderPath;

NSString* cacheFolder() {
    if (!cacheFolderPath) {
        NSString* cacheDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        cacheFolderPath = [cacheDir stringByAppendingPathComponent:RNAdvanceDownloadCacheFolderName];
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;
        if (![fileManager createDirectoryAtPath:cacheFolderPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            cacheFolderPath = nil;
        }
    }
    return cacheFolderPath;
}

void clearCacheFolder() {
    cacheFolderPath = nil;
}

NSString* LocalRecepitsPath() {
    return [cacheFolder() stringByAppendingPathComponent:@"receipts.data"];
}

@interface RNAdvanceDownloader ()
<
NSURLSessionTaskDelegate,
NSURLSessionDataDelegate
>

@property(strong, nonatomic, nonnull)NSOperationQueue* downloadQueue;
@property(nonatomic, weak, nullable)NSOperation* lastAddedOperation;
@property(assign, nonatomic, nullable)Class operationClass;
@property(strong, nonatomic, nonnull)NSMutableDictionary<NSURL*, RNAdvanceDownloadOperation*>* URLOpertaions;
@property(strong, nonatomic, nullable)RNAdvanceHTTPHeadersMutableDictionary* httpHeaders;
@property(strong, nonatomic, nullable)dispatch_queue_t barrierQueue;
@property(strong, nonatomic, nullable)NSURLSession* session;
@property(strong, nonatomic, nonnull)NSMutableDictionary* allDownloadRecepits;
@property(assign, nonatomic)UIBackgroundTaskIdentifier backgroundTaskId;

-(nullable RNAdvanceDownloadReceipt*)addProgressCallBack: (RNAdvanceDownloaderProgressBlock)progressBlock
                                           completeBlock:(RNAdvanceDownloaderCompletedBlock)completeBlock
                                                  forURL:(nullable NSURL*)url
                                          createCallBack:(RNAdvanceDownloadOperation*(^)(void))createCallback;

- (void) setAllStateToNone;
- (void) saveAllDownloadRecepits;

@end
