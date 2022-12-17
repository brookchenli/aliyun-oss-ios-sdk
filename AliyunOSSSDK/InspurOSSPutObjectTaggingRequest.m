//
//  OSSPutObjectTaggingRequest.m
//  InspurOSSSDK
//
//  Created by xx on 2021/5/25.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurOSSPutObjectTaggingRequest.h"

@implementation InspurOSSPutObjectTaggingRequest

- (NSDictionary *)requestParams {
    return @{@"tagging": @""};
}

- (NSDictionary *)entityToDictionary {
    NSMutableArray *tags = [NSMutableArray array];
    for (NSString *key in [self.tags allKeys]) {
        NSString *value = self.tags[key];
        NSDictionary *tag = @{@"Tag": @{@"Key":key,
                                        @"Value": value}};
        [tags addObject:tag];
    }
    NSDictionary *entity = @{@"Tagging": @{@"TagSet": tags}};
    return entity;
}

@end
