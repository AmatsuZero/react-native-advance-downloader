//
//  RNAdvanceDownloadReceipt.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import <React/RCTBridgeModule.h>

@class RNAdvanceDownloadReceipt;

/**
 下载状态

 - RNAdvanceDownloadStateNone: 默认
 - RNAdvanceDownloadStateWillResume: 等待
 - RNAdvanceDownloadStateDownloading: 下载中
 - RNAdvanceDownloadStateSuspend: 暂停
 - RNAdvanceDownloadStateCompleted: 下载完成
 - RNAdvanceDownloadStateFailed: 下载失败
 */
typedef NS_ENUM(NSUInteger, RNAdvanceDownloadState) {
    RNAdvanceDownloadStateNone,
    RNAdvanceDownloadStateWillResume,
    RNAdvanceDownloadStateDownloading,
    RNAdvanceDownloadStateSuspend,
    RNAdvanceDownloadStateCompleted,
    RNAdvanceDownloadStateFailed
};

/**
 下载优先度

 - RNAdvanceDownloadPrioritizationFIFO: 先进先出
 - RNAdvanceDownloadPrioritizationLIFO: 后进先出
 */
typedef NS_ENUM(NSUInteger, RNAdvanceDownloadPrioritization) {
    RNAdvanceDownloadPrioritizationFIFO,
    RNAdvanceDownloadPrioritizationLIFO
};

typedef void (^RNAdvanceDownloaderProgressBlock)(NSInteger receivedSize,
                                                 NSInteger expectedSize,
                                                 NSInteger speed,
                                                 NSURL* _Nullable targetURL);
typedef void (^RNAdvanceDownloaderCompletedBlock)(RNAdvanceDownloadReceipt* _Nullable receipt,
                                                  NSError* _Nullable error,
                                                  BOOL isFinished);
typedef NSString* _Nullable (^RNAdvanceDownloaderReceiptCustomFilePathBlock)(RNAdvanceDownloadReceipt * _Nullable receipt);

@interface RNAdvanceDownloadReceipt : NSObject

/**
 下载状态
 */
@property(nonatomic, assign, readonly) RNAdvanceDownloadState state;

/**
 下载地址URL
 */
@property(nonatomic, copy, readonly, nonnull) NSString* url;

/**
文件路径，你可以借此获得已经下载的数据
 */
@property(nonatomic, copy, readonly, nullable) NSString* filePath;

/**
 经MD5转换后的url路径
 */
@property(nonatomic, copy, readonly, nullable) NSString* fileName;

/**
 未经MD5转换的真实url路径
 */
@property(nonatomic, copy, readonly, nullable) NSString* trueName;

/**
 自定义下载路径回调
 */
@property(nonatomic, copy, nullable)RNAdvanceDownloaderReceiptCustomFilePathBlock customFilePathBlock;

/**
 下载速度：KB/s
 */
@property(nonatomic, copy, readonly, nullable) NSString* speed;

/**
 已下载数量
 */
@property(assign, nonatomic, readonly) long long totalBytesWritten;

/**
 下载总量
 */
@property(assign, nonatomic, readonly) long long totalBytesExpectedToWrite;

@property(nonatomic, copy, nullable, readonly) RNAdvanceDownloaderProgressBlock downloaderProgressBlock;
@property(nonatomic, copy, nullable, readonly) RNAdvanceDownloaderCompletedBlock downloaderCompleteBlock;
@end
