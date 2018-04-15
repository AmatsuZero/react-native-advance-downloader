//
//  RCTConvert+RNAdvanceDownloadState.m
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/15.
//  Copyright © 2018年 MockingBot. All rights reserved.
//

#import "RCTConvert+RNAdvanceDownloadState.h"
#import "RNAdvanceDownloadReceipt.h"

@implementation RCTConvert (RNAdvanceDownloadState)

RCT_ENUM_CONVERTER(RNAdvanceDownloadState,
                   (@{@"none": @(RNAdvanceDownloadStateNone),
                      @"resume": @(RNAdvanceDownloadStateWillResume),
                      @"downloading": @(RNAdvanceDownloadStateDownloading),
                      @"suspend": @(RNAdvanceDownloadStateSuspend),
                      @"fail": @(RNAdvanceDownloadStateFailed),
                      @"completed": @(RNAdvanceDownloadStateCompleted)}),
                   RNAdvanceDownloadStateNone,
                   integerValue);

@end
