//
//  RNAdvanceDownloader.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import <React/RCTBridgeModule.h>

void dispatch_main_async_safe(void (^block)(void)) {
    const char* currentLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char* mainLabLabel = dispatch_queue_get_label(dispatch_get_main_queue());
    if (strcmp(currentLabel, mainLabLabel) == 0) {// 判断是否在主线程
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

FOUNDATION_EXPORT NSString* const RNAdvanceDownloadFolderName;
FOUNDATION_EXPORT NSString* cacheFolder(void);

extern NSString* _Nonnull const RNAdvanceDownloadStartNotification;
extern NSString* _Nonnull const RNAdvanceDownloadStopNotification;

typedef NSDictionary<NSString*, NSString*> RNAdvanceHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString*, NSString*> RNAdvanceHTTPHeadersMutableDictionary;
typedef RNAdvanceHTTPHeadersDictionary * _Nonnull (^RNAdvanceDownloaderHeadersFilterBlock)(NSURL* _Nullable url,
                                                                                           RNAdvanceHTTPHeadersDictionary* _Nullable headers);

@interface RNAdvanceDownloader : NSObject<RCTBridgeModule>

@end
