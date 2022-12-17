//
//  OSSConfigurationTest.m
//  InspurOSSiOSTests
//
//  Created by ws on 2021/3/17.
//  Copyright © 2021 aliyun. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"

@interface OSSConfigurationTest : XCTestCase {
    NSString *host;
    NSString *scheme;
    NSString *endpoint;
    NSString *cname;
    NSString *cnameEndpoint;
    NSString *bucketEndpoint;
}

@end

@implementation OSSConfigurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    host = @"oss-cn-beijing.aliyuncs.com";
    cname = @"oss.cname.com";
    scheme = @"https://";
    endpoint = [NSString stringWithFormat:@"%@%@", scheme, host];
    cnameEndpoint = [NSString stringWithFormat:@"%@%@", scheme, cname];
    bucketEndpoint = [NSString stringWithFormat:@"%@.%@", OSS_BUCKET_PUBLIC, host];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDefault {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetObjectRequest *get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertTrue([task.error.userInfo[@"HostId"] isEqualToString:bucketEndpoint]);
        XCTAssertTrue([task.error.userInfo[@"Bucket"] isEqualToString:OSS_BUCKET_PUBLIC]);
        return task;
    }] waitUntilFinished];
}

- (void)testPathStyleAccessEnable {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[cname];
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetObjectRequest *get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@/%@/%@", scheme, cname, OSS_BUCKET_PUBLIC, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testSupportCnameEnable {
    NSArray *cnameExcludeList = @[cname];
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.cnameExcludeList = cnameExcludeList;
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetObjectRequest *get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@.%@/%@", scheme, OSS_BUCKET_PUBLIC, cname, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
    
    config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    client = [[InspurOSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@%@/%@", scheme, cname, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnable {
    NSString *endpointPath = [NSString stringWithFormat:@"%@/%@", cnameEndpoint, OSS_BUCKET_PUBLIC];
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isCustomPathPrefixEnable = YES;
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:endpointPath credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetObjectRequest *get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@/%@", endpointPath, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNoPathEndpont {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    config.isCustomPathPrefixEnable = YES;
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetObjectRequest *get = [InspurOSSGetObjectRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    get.objectKey = OSS_MULTIPART_UPLOADKEY;
    [[[client getObject:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        NSString *url = [NSString stringWithFormat:@"%@/%@", cnameEndpoint, OSS_MULTIPART_UPLOADKEY];
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:url]);
        return task;
    }] waitUntilFinished];
}

- (void)testCustomPathPrefixEnableWithNullObject {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.maxRetryCount = 0;
    InspurOSSAuthCredentialProvider *credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:cnameEndpoint credentialProvider:credentialProvider clientConfiguration:config];
    InspurOSSGetBucketRequest *get = [InspurOSSGetBucketRequest new];
    get.bucketName = OSS_BUCKET_PUBLIC;
    [[[client getBucket:get] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([task.error.userInfo[@"NSErrorFailingURLStringKey"] isEqualToString:[cnameEndpoint stringByAppendingString:@"/"]]);
        return task;
    }] waitUntilFinished];
}

@end
