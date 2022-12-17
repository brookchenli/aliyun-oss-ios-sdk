//
//  OSSHttpdns.h
//  InspurOSSiOS
//
//  Created by xx on 5/1/16.
//  Copyright © 2016 zhouzhuo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InspurOSSHttpdns : NSObject

+ (instancetype)sharedInstance;

- (NSString *)asynGetIpByHost:(NSString *)host;
@end
