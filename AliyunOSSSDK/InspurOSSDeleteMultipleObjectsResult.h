//
//  OSSDeleteMultipleObjectsResult.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSResult.h"

@interface InspurOSSDeleteMultipleObjectsResult : InspurOSSResult

@property (nonatomic, copy) NSArray<NSString *> *deletedObjects;

@property (nonatomic, copy) NSString *encodingType;

@end
