//
//  OSSGetObjectACLResult.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSResult.h"

@interface InspurOSSGetObjectACLResult : InspurOSSResult

/**
 the ACL of object,valid values: @"private",@"public-read",@"public-read-write".
 if object's ACL inherit from bucket,it will return @"default".
 */
@property (nonatomic, copy) NSString *grant;

@end
