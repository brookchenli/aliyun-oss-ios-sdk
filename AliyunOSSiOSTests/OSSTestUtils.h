//
//  OSSTestUtils.h
//  AliyunOSSiOSTests
//
//  Created by jingdan on 2018/2/24.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

@interface OSSTestUtils : NSObject
+ (void)cleanBucket: (NSString *)bucket with: (InspurOSSClient *)client;
+ (void) putTestDataWithKey: (NSString *)key withClient: (InspurOSSClient *)client withBucket: (NSString *)bucket;
@end

@interface OSSProgressTestUtils : NSObject

- (void)updateTotalBytes:(int64_t)totalBytesSent totalBytesExpected:(int64_t)totalBytesExpectedToSend;
- (BOOL)completeValidateProgress;

@end
