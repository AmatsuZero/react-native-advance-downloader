//
//  RNAdvanceDownloadOperation+RNAdvanceDownloadOperationExtension.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/15.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import "RNAdvanceDownloadOperation.h"

NSString* const RNAdvanceDownloadStartNotification = @"RNAdvanceDownloadStartNotification";
NSString* const RNAdvanceDownloadReceiveResponseNotifcation = @"RNAdvanceDownloadReceiveResponseNotifcation";
NSString* const RNAdvanceDownloadStopNotification = @"RNAdvanceDownloadStopNotification";
NSString* const RNAdvanceDownloadFinishNotification = @"RNAdvanceDownloadFinishNotification";

static NSString* const kProgressCallbackKey = @"progress";
static NSString* const kCompleteCallbackKey = @"completed";

typedef NSMutableDictionary<NSString*, id> RNAdvanceDownloadCallbacksDictionary;

@interface RNAdvanceDownloadOperation ()

@property(strong, nonatomic, nonnull) NSMutableArray<RNAdvanceDownloadCallbacksDictionary*>* callbackBlocks;
@property(weak, nonatomic, nullable) NSURLSession* unownedSession;
@property(strong, nonatomic, nullable) NSURLSession* ownedSession;
@property(strong, nonatomic, readwrite, nullable) NSURLSessionTask* dataTask;
@property(strong, nonatomic, nullable) dispatch_queue_t barrierQueue;
@property(assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
@property(assign, nonatomic) long long totalbytesWritten;
@property(assign, nonatomic) RNAdvanceDownloadReceipt* receipt;

@end
