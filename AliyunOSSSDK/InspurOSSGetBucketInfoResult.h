//
//  OSSGetBucketInfoResult.h
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/7/10.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "OSSResult.h"

@interface InspurOSSBucketOwner : NSObject

@property (nonatomic, copy) NSString *userName;

@property (nonatomic, copy) NSString *userId;

@end

@interface InspurOSSAccessControlList : NSObject

@property (nonatomic, copy) NSString *grant;

@end



@interface InspurOSSGetBucketInfoResult : OSSResult

/// Created date.
@property (nonatomic, copy) NSString *creationDate;

/// Bucket name.
@property (nonatomic, copy) NSString *bucketName;

/// Bucket location.
@property (nonatomic, copy) NSString *location;

/// Storage class (Standard, IA, Archive)
@property (nonatomic, copy) NSString *storageClass;

/**
 Internal endpoint. It could be accessed within AliCloud under the same
 location.
 */
@property (nonatomic, copy) NSString *intranetEndpoint;

/**
 External endpoint.It could be accessed from anywhere.
 */
@property (nonatomic, copy) NSString *extranetEndpoint;

/// Bucket owner.
@property (nonatomic, strong) InspurOSSBucketOwner *owner;

@property (nonatomic, strong) InspurOSSAccessControlList *acl;

@end
