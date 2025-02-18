//
//  OSSURLRequestRetryHandler.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSURLRequestRetryHandler.h"
#import "InspurOSSNetworkingRequestDelegate.h"
#import "InspurOSSDefine.h"

@implementation InspurOSSURLRequestRetryHandler

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(InspurOSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error {
    
    if (currentRetryCount >= self.maxRetryCount) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    /**
     When onRecieveData is set, no retry.
     When the error is task cancellation, no retry.
     */
    if (delegate.onRecieveData != nil) {
        return OSSNetworkingRetryTypeShouldNotRetry;
    }
    
    if ([error.domain isEqualToString:InspurOSSClientErrorDomain]) {
        if (error.code == InspurOSSClientErrorCodeTaskCancelled) {
            return OSSNetworkingRetryTypeShouldNotRetry;
        } else {
            return OSSNetworkingRetryTypeShouldRetry;
        }
    }
    
    switch (response.statusCode) {
        case 403:
            if ([[[error userInfo] objectForKey:@"Code"] isEqualToString:@"RequestTimeTooSkewed"]) {
                return OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry;
            }
            break;
            
        default:
            break;
    }
    
    return OSSNetworkingRetryTypeShouldNotRetry;
}

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount retryType:(OSSNetworkingRetryType)retryType {
    switch (retryType) {
        case OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry:
        case OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry:
            return 0;
            
        default:
            return pow(2, currentRetryCount) * 200 / 1000;
    }
}

+ (instancetype)defaultRetryHandler {
    InspurOSSURLRequestRetryHandler * retryHandler = [InspurOSSURLRequestRetryHandler new];
    retryHandler.maxRetryCount = InspurOSSDefaultRetryCount;
    return retryHandler;
}

@end
