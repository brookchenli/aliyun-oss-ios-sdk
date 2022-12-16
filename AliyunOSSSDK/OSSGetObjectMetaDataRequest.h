//
//  OSSGetObjectMetaDataRequest.h
//  AliyunOSSSDK
//
//  Created by 陈历 on 2022/12/16.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSSGetObjectMetaDataRequest : OSSRequest

@property (nonatomic, copy) NSString *bucketName;
@property (nonatomic, copy) NSString *objectName;

@end




NS_ASSUME_NONNULL_END
