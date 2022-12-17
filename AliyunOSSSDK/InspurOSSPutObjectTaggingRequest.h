//
//  OSSPutObjectTaggingRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2021/5/25.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurOSSPutObjectTaggingRequest : InspurOSSRequest

/* bucket name */
@property (nonatomic, copy) NSString *bucketName;

/* object name */
@property (nonatomic, copy) NSString *objectKey;

@property (nonatomic, copy) NSDictionary *tags;

- (NSDictionary *)entityToDictionary;

@end

NS_ASSUME_NONNULL_END
