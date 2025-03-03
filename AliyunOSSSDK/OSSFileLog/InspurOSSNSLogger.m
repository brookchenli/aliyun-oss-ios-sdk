//
//  OSSNSLogger.m
//  InspurOSSiOS
//
//  Created by xx on 2017/10/24.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSNSLogger.h"

static InspurOSSNSLogger *sharedInstance;

@implementation InspurOSSNSLogger
+ (instancetype)sharedInstance {
    static dispatch_once_t OSSNSLoggerOnceToken;
    
    dispatch_once(&OSSNSLoggerOnceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    return sharedInstance;
}

- (void)logMessage:(OSSDDLogMessage *)logMessage {
    NSString * message = _logFormatter ? [_logFormatter formatLogMessage:logMessage] : logMessage->_message;
    
    if (message) {
        NSLog(@"%@",message);
    }
}

@end
