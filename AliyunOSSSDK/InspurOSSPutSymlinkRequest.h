//
//  OSSPutSymlinkRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2018/8/1.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSRequest.h"

@interface InspurOSSPutSymlinkRequest : InspurOSSRequest

/* bucket name */
@property (nonatomic, copy) NSString *bucketName;

/* object name */
@property (nonatomic, copy) NSString *objectKey;

/* target object name */
@property (nonatomic, copy) NSString *targetObjectName;

/* meta info in request header fields */
@property (nonatomic, copy) NSDictionary *objectMeta;

@end
