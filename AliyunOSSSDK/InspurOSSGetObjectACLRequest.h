//
//  OSSGetObjectACLRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSRequest.h"

NS_ASSUME_NONNULL_BEGIN
@interface InspurOSSGetObjectACLRequest : InspurOSSRequest

/**
 the bucket's name which object stored
 */
@property (nonatomic, copy) NSString *bucketName;

/**
 the name of object
 */
@property (nonatomic, copy) NSString *objectName;


@end
NS_ASSUME_NONNULL_END
