//
//  OSSManager.h
//  InspurOSSSDK-iOS-Example
//
//  Created by xx on 2018/10/23.
//  Copyright © 2018 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface InspurOSSManager : NSObject

@property (nonatomic, strong) InspurOSSClient *defaultClient;

@property (nonatomic, strong) InspurOSSClient *imageClient;

+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
