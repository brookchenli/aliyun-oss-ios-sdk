//
//  NSDate+OSS.h
//  InspurOSSSDK
//
//  Created by xx on 2018/7/31.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Categories NSDate
 */
@interface NSDate (InspurOSS)
+ (void)oss_setClockSkew:(NSTimeInterval)clockSkew;
+ (NSDate *)oss_dateFromString:(NSString *)string;
+ (NSDate *)oss_clockSkewFixedDate;
- (NSString *)oss_asStringValue;
@end
