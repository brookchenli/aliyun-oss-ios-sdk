//
//  NSMutableDictionary+OSS.m
//  InspurOSSSDK
//
//  Created by xx on 2018/8/1.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "NSMutableDictionary+InspurOSS.h"

@implementation NSMutableDictionary (InspurOSS)

- (void)oss_setObject:(id)anObject forKey:(id <NSCopying>)aKey {
    if (anObject && aKey) {
        [self setObject:anObject forKey:aKey];
    }
}

@end
