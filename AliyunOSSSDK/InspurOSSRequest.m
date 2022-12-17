//
//  OSSRequest.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSRequest.h"
#import "InspurOSSNetworkingRequestDelegate.h"

@interface InspurOSSRequest ()

@property (nonatomic, strong) InspurOSSNetworkingRequestDelegate *requestDelegate;

@end


@implementation InspurOSSRequest

- (instancetype)init {
    if (self = [super init]) {
        self.requestDelegate = [InspurOSSNetworkingRequestDelegate new];
        self.isAuthenticationRequired = YES;
    }
    return self;
}

- (void)cancel {
    self.isCancelled = YES;
    
    if (self.requestDelegate) {
        [self.requestDelegate cancel];
    }
}

- (NSDictionary *)requestParams {
    return nil;
}

@end
