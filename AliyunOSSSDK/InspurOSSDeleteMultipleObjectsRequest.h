//
//  OSSDeleteMultipleObjectsRequest.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "InspurOSSRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurOSSDeleteMultipleObjectsRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSArray<NSString *> *keys;

/**
 invalid value is @"url"
 */
@property (nonatomic, copy, nullable) NSString *encodingType;

/**
 whether to show verbose result,the default value is YES.
 */
@property (nonatomic, assign) BOOL quiet;

@end

NS_ASSUME_NONNULL_END
