//
//  NSMutableDictionary+OSS.h
//  InspurOSSSDK
//
//  Created by xx on 2018/8/1.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (InspurOSS)

- (void)oss_setObject:(id)anObject forKey:(id <NSCopying>)aKey;

@end
