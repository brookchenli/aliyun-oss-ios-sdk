//
//  OSSModelTests.m
//  InspurOSSiOSTests
//
//  Created by xx on 2017/11/20.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/OSSModel.h>
#import <AliyunOSSiOS/InspurOSSUtil.h>

@import AliyunOSSiOS.InspurOSSAllRequestNeededMessage;
@import AliyunOSSiOS.InspurOSSDefine;

@interface OSSModelTests : XCTestCase

@end

@implementation OSSModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testForCategoryForNSString {
    NSString *urlString = @"https://www.aliyun.com";
    urlString = [urlString oss_stringByAppendingPathComponentForURL:@"oss/sdk/ios"];
    
    NSString *urlString1 = @"https://www.aliyun.com/";
    urlString1 = [urlString1 oss_stringByAppendingPathComponentForURL:@"oss/sdk/ios"];
    
    XCTAssertEqualObjects(urlString,urlString1);
}

- (void)testForOSSSyncMutableDictionary
{
    InspurOSSSyncMutableDictionary *syncMutableDict = [[InspurOSSSyncMutableDictionary alloc] init];
    [syncMutableDict setObject:@"hello" forKey:@"verb"];
    [syncMutableDict setObject:@"world" forKey:@"noun"];
    XCTAssertNotNil(syncMutableDict.allKeys);
}

- (void)testForOSSUASettingInterceptorWithNotAllowUACarrySystemInfo {
    NSString *ua = @"User-Agent";
    NSString *location = [[NSLocale currentLocale] localeIdentifier];

    InspurOSSClientConfiguration *clientConfig = [InspurOSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = NO;
    InspurOSSUASettingInterceptor *interceptor = [[InspurOSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    InspurOSSAllRequestNeededMessage *allRequestMessage = [InspurOSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    NSString *expectValue = [NSString stringWithFormat:@"%@/%@(/%@)", InspurOSSUAPrefix, InspurOSSSDKVersion, location];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
    
    clientConfig = [InspurOSSClientConfiguration new];
    clientConfig.isAllowUACarrySystemInfo = NO;
    clientConfig.userAgentMark = @"userAgent";
    interceptor = [[InspurOSSUASettingInterceptor alloc] initWithClientConfiguration:clientConfig];
    
    allRequestMessage = [InspurOSSAllRequestNeededMessage new];
    [interceptor interceptRequestMessage:allRequestMessage];
    expectValue = [NSString stringWithFormat:@"%@/%@(/%@)/%@", InspurOSSUAPrefix, InspurOSSSDKVersion, location, clientConfig.userAgentMark];
    XCTAssertTrue([allRequestMessage.headerParams[ua] isEqualToString:expectValue]);
}

@end
