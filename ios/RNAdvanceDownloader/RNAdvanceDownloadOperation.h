//
//  RNAdvanceDownloadOperation.h
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/15.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import "RNAdvanceDownloader.h"

extern NSString* _Nonnull const RNAdvanceDownloadStartNotification;
extern NSString* _Nonnull const RNAdvanceDownloadReceiveResponseNotifcation;
extern NSString* _Nonnull const RNAdvanceDownloadStopNotification;
extern NSString* _Nonnull const RNAdvanceDownloadFinishNotification;

@protocol RNAdvanceDownloadOperationProtocol<NSObject>

- (nonnull instancetype) initWithRequest:(nullable NSURLRequest*)request
                                inSession:(nullable NSURLSession*)session;

- (nullable id) addHandlerForProgress:(nullable RNAdvanceDownloaderProgressBlock)progresBlock
                           completed:(nullable RNAdvanceDownloaderCompletedBlock)completedBlock;

@end

@interface RNAdvanceDownloadOperation : NSOperation
<
RNAdvanceDownloadOperationProtocol,
NSURLSessionTaskDelegate,
NSURLSessionDataDelegate
>

/**
 下载请求
 */
@property(nonatomic, nullable, strong)NSURLRequest* request;

/**
 下载任务
 */
@property(strong, nonatomic, readonly, nullable)NSURLSessionTask* dataTask;

/**
 数据估计大小
 */
@property(assign, nonatomic)NSInteger expectedSize;

/**
 下载任务返回的响应体
 */
@property(strong, nonatomic, nullable)NSURLResponse* response;

-(nonnull instancetype) initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session NS_DESIGNATED_INITIALIZER;

-(nullable id) addHandlerForProgress:(nullable RNAdvanceDownloaderProgressBlock)progresBlock
                          completed:(nullable RNAdvanceDownloaderCompletedBlock)completedBlock;

- (BOOL) cancel:(nullable id)token;
@end
