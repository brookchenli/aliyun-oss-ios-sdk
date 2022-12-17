//
//  NSMutableData+OSS_CRC.h
//  InspurOSSSDK
//
//  Created by xx on 2017/11/29.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableData (InspurOSS_CRC)

- (uint64_t)oss_crc64;

@end
