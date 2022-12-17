//
//  OSSReachabilityTests.m
//  InspurOSSiOSTests
//
//  Created by xx on 2017/11/16.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/InspurOSSReachability.h>

@interface OSSReachabilityTests : XCTestCase

@end

@implementation OSSReachabilityTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testReachabilityWithHostName
{
    struct sockaddr sockaddr = {0};
    
    InspurOSSReachability *reachability = [InspurOSSReachability reachabilityWithAddress:&sockaddr];
    
    reachability = [InspurOSSReachability reachabilityForInternetConnection];
    [reachability startNotifier];
    [reachability connectionRequired];
}

@end
