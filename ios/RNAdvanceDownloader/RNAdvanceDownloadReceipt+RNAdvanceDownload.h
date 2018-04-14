//
//  RNAdvanceDownloadReceipt+RNAdvanceDownload.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import "RNAdvanceDownloadReceipt.h"

@interface RNAdvanceDownloadReceipt ()<NSCoding>

@property(nonatomic, assign) NSUInteger totalRead;
@property(nonatomic, strong, nullable) NSDate* date;
@property(nonatomic, copy) NSString* url;
@property(nonatomic, copy) NSString* fileName;
@property(nonatomic, assign) RNAdvanceDownloadState state;
@property(nonatomic, copy) NSString* filePath;
@property(nonatomic, copy) NSString* trueName;
@property(nonatomic, strong) NSProgress* progress;
@property(nonatomic, assign) long long totalBytesWritten;

@property(nonatomic, strong, nullable)id downloadOperationCancelToken;

- (nonnull instancetype) initWithURLString:(nonnull NSString*)URLString
            downloadOperationCancelToken:(nullable id)downloadOperationCancelToken
                 downloaderProgressBlock:(nullable RNAdvanceDownloaderProgressBlock)downloadProgressBlock
                downloaderCompletedBlock:(nullable RNAdvanceDownloaderCompletedBlock)downloaderCompleteBlock;

- (void) setTotalBytesExpectedToWrite:(long long)totalBytesExpectedToWrite;
- (void) setState:(RNAdvanceDownloadState)state;
- (void) setDownloaderOperationCancelToken: (nullable id)downloadOperationCancelToken;
- (void) setDownloaderOperationProgressBlock: (nullable RNAdvanceDownloaderProgressBlock)downloaderProgressBlock;
- (void) setDownloaderCompleteBlock: (nullable RNAdvanceDownloaderCompletedBlock)downloaderCompleteBlock;
- (void) setSpeed: (NSString* _Nullable)speed;

@end
