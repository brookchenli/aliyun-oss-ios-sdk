//
//  OSSDeleteMultipleObjectsRequest.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSDeleteMultipleObjectsRequest.h"

@implementation InspurOSSDeleteMultipleObjectsRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _quiet = YES;
    }
    return self;
}

@end
