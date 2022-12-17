//
//  GetObjectTaggingResult.h
//  InspurOSSSDK
//
//  Created by xx on 2021/5/25.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurOSSGetObjectTaggingResult : InspurOSSResult

@property (nonatomic, strong) NSDictionary *tags;

@end

NS_ASSUME_NONNULL_END
