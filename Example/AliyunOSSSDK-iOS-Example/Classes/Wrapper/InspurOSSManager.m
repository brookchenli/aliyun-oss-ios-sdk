//
//  OSSManager.m
//  InspurOSSSDK-iOS-Example
//
//  Created by xx on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import "InspurOSSManager.h"

@implementation InspurOSSManager

+ (instancetype)sharedManager {
    static InspurOSSManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[InspurOSSManager alloc] init];
    });
    
    return _manager;
}

@end
