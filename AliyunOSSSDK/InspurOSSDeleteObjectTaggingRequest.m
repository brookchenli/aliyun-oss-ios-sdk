//
//  OSSDeleteObjectTaggingRequest.m
//  InspurOSSSDK
//
//  Created by xx on 2021/5/25.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurOSSDeleteObjectTaggingRequest.h"

@implementation InspurOSSDeleteObjectTaggingRequest

- (NSDictionary *)requestParams {
    return @{@"tagging": @""};
}

@end
