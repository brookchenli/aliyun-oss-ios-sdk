//
//  NSDate+OSS.m
//  InspurOSSSDK
//
//  Created by xx on 2018/7/31.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "NSDate+InspurOSS.h"

@implementation NSDate (InspurOSS)

NSString * const serverReturnDateFormat = @"EEE, dd MMM yyyy HH:mm:ss z";

static NSTimeInterval _clockSkew = 0.0;

+ (void)oss_setClockSkew:(NSTimeInterval)clockSkew {
    @synchronized(self) {
        _clockSkew = clockSkew;
    }
}

+ (NSDate *)oss_clockSkewFixedDate {
    NSTimeInterval skew = 0.0;
    @synchronized(self) {
        skew = _clockSkew;
    }
    return [[NSDate date] dateByAddingTimeInterval:(-1 * skew)];
}

+ (NSDate *)oss_dateFromString:(NSString *)string {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    dateFormatter.dateFormat = serverReturnDateFormat;
    
    return [dateFormatter dateFromString:string];
}

- (NSString *)oss_asStringValue {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    dateFormatter.dateFormat = serverReturnDateFormat;
    
    return [dateFormatter stringFromDate:self];
}

@end
