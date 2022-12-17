//
//  OSSLog.m
//  oss_ios_sdk
//
//  Created by xx on 8/16/15.
//  Copyright (c) 2022 Inspur. All rights reserved.
//

#import "InspurOSSLog.h"
#import "InspurOSSUtil.h"

@implementation InspurOSSLog
+ (void)enableLog {
    if([InspurOSSUtil hasPhoneFreeSpace]){
        isEnable = YES;
        [OSSDDLog removeAllLoggers];
        [OSSDDLog addLogger:[InspurOSSNSLogger sharedInstance]];
        OSSDDFileLogger *fileLogger = [[OSSDDFileLogger alloc] init];
        [OSSDDLog addLogger:fileLogger];
    }
}

+ (void)disableLog {
    isEnable = NO;
}

+ (BOOL)isLogEnable {
    return isEnable;
}

@end
