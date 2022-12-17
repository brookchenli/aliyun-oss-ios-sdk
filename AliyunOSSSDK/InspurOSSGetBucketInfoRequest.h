//
//  OSSGetBucketInfoRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2018/7/10.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSRequest.h"

@interface InspurOSSGetBucketInfoRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@end
