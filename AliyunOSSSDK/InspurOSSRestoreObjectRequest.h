//
//  OSSRestoreObjectRequest.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/8/1.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "InspurOSSRequest.h"

@interface InspurOSSRestoreObjectRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectKey;

@end
