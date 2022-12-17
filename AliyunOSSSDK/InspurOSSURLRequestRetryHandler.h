//
//  OSSURLRequestRetryHandler.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSConstants.h"

@class InspurOSSNetworkingRequestDelegate;


NS_ASSUME_NONNULL_BEGIN

/**
 The retry handler interface
 */
@interface InspurOSSURLRequestRetryHandler : NSObject

@property (nonatomic, assign) uint32_t maxRetryCount;


+ (instancetype)defaultRetryHandler;

- (OSSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                      requestDelegate:(InspurOSSNetworkingRequestDelegate *)delegate
                             response:(NSHTTPURLResponse *)response
                                error:(NSError *)error;

- (NSTimeInterval)timeIntervalForRetry:(uint32_t)currentRetryCount
                             retryType:(OSSNetworkingRetryType)retryType;
@end

NS_ASSUME_NONNULL_END
