//
//  NSMutableData+OSS_CRC.m
//  InspurOSSSDK
//
//  Created by xx on 2017/11/29.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "NSMutableData+Inspur_OSS_CRC.h"
#include "aos_crc64.h"

@implementation NSMutableData (InspurOSS_CRC)

- (uint64_t)oss_crc64
{
    return aos_crc64(0, self.mutableBytes, self.length);
}

@end
