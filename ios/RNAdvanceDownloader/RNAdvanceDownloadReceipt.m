//
//  RNAdvanceDownloadReceipt.m
//  RNAdvanceDownloader
//
//  Created by modao on 2018/4/14.
//  Copyright © 2018年 MockingBot. All rights reserved.
//
#import <CommonCrypto/CommonDigest.h>
#import "RNAdvanceDownloadReceipt.h"
#import "RNAdvanceDownloadReceipt+RNAdvanceDownload.h"

extern NSString* cacheFolder(void);

unsigned long long fileSizeForPath(NSString* _Nonnull path) {
    signed long long fileSize = 0;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        NSError* error = nil;
        NSDictionary* fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if(!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

NSString* _Nullable getMD5String(NSString* _Nullable str) {
    if (str == nil) return nil;
    const char* cString = [str UTF8String];
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cString, (CC_LONG)strlen(cString), bytes);
    NSMutableString* md5String = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x", bytes[i]];
    }
    return [md5String copy];
}

@implementation RNAdvanceDownloadReceipt

-(NSString *)filePath {
    if (!_filePath) {
        NSString* path = [cacheFolder() stringByAppendingPathComponent:self.fileName];
        if (![path isEqualToString:_filePath]) {
            NSString* dir = [_filePath stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        _filePath = path;
    }
    return _filePath;
}

-(void)setCustomFilePathBlock:(RNAdvanceDownloaderReceiptCustomFilePathBlock)customFilePathBlock {
    _customFilePathBlock = customFilePathBlock;
    if (_customFilePathBlock) {
        NSString* path = customFilePathBlock(self);
        if (path && ![path isEqualToString:_filePath]) {
            _filePath = path;
            if (_filePath && ![[NSFileManager defaultManager] fileExistsAtPath:_filePath]) {
                NSString* dir = [_filePath stringByDeletingLastPathComponent];
                [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:nil];
            }
        }
    }
}

-(NSString *)fileName {
    if(!_fileName) {
        NSString* pathExtension = self.url.pathExtension;
        if (pathExtension.length > 0) {
            _fileName = [NSString stringWithFormat:@"%@.%@", getMD5String(self.url), pathExtension];
        } else {
            _fileName = getMD5String(self.url);
        }
    }
    return _fileName;
}

-(NSString *)trueName {
    if (!_trueName) {
        _trueName = self.url.lastPathComponent;
    }
    return _trueName;
}

-(NSProgress *)progress {
    if (!_progress) {
        _progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    }
    @try {
        _progress.totalUnitCount = self.totalBytesExpectedToWrite;
        _progress.completedUnitCount = self.totalBytesWritten;
    } @catch(NSException* exception) {

    }
    return _progress;
}

-(long long)totalBytesWritten {
    return fileSizeForPath(self.filePath);
}

-(instancetype)initURL: (NSString* _Nonnull)url {
    if (self = [super init]) {
        _url = url;
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.url forKey:NSStringFromSelector(@selector(url))];
    [aCoder encodeObject:self.filePath forKey:NSStringFromSelector(@selector(filePath))];
    [aCoder encodeObject:@(self.state) forKey:NSStringFromSelector(@selector(state))];
    [aCoder encodeObject:self.fileName forKey:NSStringFromSelector(@selector(fileName))];
    [aCoder encodeObject:@(self.totalBytesWritten) forKey:NSStringFromSelector(@selector(totalBytesWritten))];
    [aCoder encodeObject:@(self.totalBytesExpectedToWrite) forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))];
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _url = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(url))];
        _filePath = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filePath))];
        _state = [[aDecoder decodeObjectOfClass:[NSNumber class]
                                         forKey:NSStringFromSelector(@selector(state))]
                  unsignedIntegerValue];
        _fileName = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(fileName))];
        _totalBytesWritten = [[aDecoder decodeObjectOfClass:[NSNumber class]
                                                     forKey:NSStringFromSelector(@selector(totalBytesWritten))]
                              unsignedIntegerValue];
        _totalBytesExpectedToWrite = [[aDecoder decodeObjectOfClass:[NSNumber class]
                                                             forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))]
                                      unsignedIntegerValue];
    }
    return self;
}

@end
