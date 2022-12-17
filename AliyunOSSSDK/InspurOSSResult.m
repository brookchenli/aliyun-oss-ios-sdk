//
//  OSSResult.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/26.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSResult.h"

@implementation InspurOSSResult

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSResult<%p> : {httpResponseCode: %ld, requestId: %@, httpResponseHeaderFields: %@, local_crc64ecma: %@}",self,(long)self.httpResponseCode,self.requestId,self.httpResponseHeaderFields,self.localCRC64ecma];
}

@end
