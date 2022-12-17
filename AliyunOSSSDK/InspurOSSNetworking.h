//
//  OSSNetworking.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSModel.h"

@class InspurOSSSyncMutableDictionary;
@class InspurOSSNetworkingRequestDelegate;
@class InspurOSSExecutor;



/**
 Network parameters
 */
@interface InspurOSSNetworkingConfiguration : NSObject
@property (nonatomic, assign) uint32_t maxRetryCount;
@property (nonatomic, assign) uint32_t maxConcurrentRequestCount;
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;
@property (nonatomic, strong) NSString * backgroundSessionIdentifier;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@property (nonatomic, strong) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;
@property (nonatomic, assign) BOOL enableFollowRedirects;
@end


/**
 The network interface which OSSClient uses for network read and write operations.
 */
@interface InspurOSSNetworking : NSObject <NSURLSessionDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, assign) BOOL isUsingBackgroundSession;
@property (nonatomic, strong) InspurOSSSyncMutableDictionary * sessionDelagateManager;
@property (nonatomic, strong) InspurOSSNetworkingConfiguration * configuration;
@property (nonatomic, strong) InspurOSSExecutor * taskExecutor;

- (instancetype)initWithConfiguration:(InspurOSSNetworkingConfiguration *)configuration;
- (InspurOSSTask *)sendRequest:(InspurOSSNetworkingRequestDelegate *)request;
@end
