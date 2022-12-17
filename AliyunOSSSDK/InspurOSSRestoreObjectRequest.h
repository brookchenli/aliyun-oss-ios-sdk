//
//  OSSRestoreObjectRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2018/8/1.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSRequest.h"

@interface InspurOSSRestoreObjectRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectKey;

@end
