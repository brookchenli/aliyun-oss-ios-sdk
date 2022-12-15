//
//  OSSBucketTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/12/11.
//  Copyright © 2017年 阿里云. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"

@interface OSSBucketTests : XCTestCase
{
    OSSClient *_client;
}

@end

@implementation OSSBucketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self initOSSClient];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)initOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    //OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSPlainTextAKSKPairCredentialProvider *authProv = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    [OSSLog enableLog];
}

- (void)testAPI_creatBucket
{
    NSString *bucket = @"test-brook-1114-2307";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"public-read";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucket with:_client];
}

- (void)testAPI_getBucketInfo {
    NSString *bucketName = @"oss-ios-get-bucket-info-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucketName;
    [[_client createBucket:req] waitUntilFinished];
    
    OSSGetBucketInfoRequest * request = [OSSGetBucketInfoRequest new];
    request.bucketName = bucketName;
    OSSTask * task = [_client getBucketInfo:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        XCTAssertNotNil(task.result);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucketName with:_client];
}

- (void)testAPI_getBucketACL
{
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = @"oss-ios-get-bucket-acl-test";
    [[_client createBucket:req] waitUntilFinished];
    
    OSSGetBucketACLRequest * request = [OSSGetBucketACLRequest new];
    request.bucketName = @"oss-ios-get-bucket-acl-test";
    OSSTask * task = [_client getBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetBucketACLResult * result = task.result;
        XCTAssertEqualObjects(@"private", result.aclGranted);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-get-bucket-acl-test" with:_client];
}

- (void)testAPI_getService
{
    OSSGetServiceRequest *request = [OSSGetServiceRequest new];
    OSSTask * task = [_client getService:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSGetServiceResult *result = nil;
    do {
        request = [OSSGetServiceRequest new];
        request.maxKeys = 2;
        request.marker = result.nextMarker;
        task = [_client getService:request];
        [task waitUntilFinished];
        result = task.result;
    } while (result.isTruncated);
}

//分类列举桶
- (void)testAPI_listPageService {
    OSSListPageServiceRequest *request = [OSSListPageServiceRequest new];
    request.pageNo = 2;
    request.pageSize = 8;
    OSSTask *task = [_client listService:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}


- (void)testAPI_deleteBucket
{
    NSString * bucket = @"oss-ios-delete-bucket-test";
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"public-read";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    
    OSSDeleteBucketRequest *request = [OSSDeleteBucketRequest new];
    request.bucketName = bucket;
    task = [_client deleteBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

//查询桶是否存在
- (void)testAPI_queryBucketExist {
    OSSQueryBucketExistRequest *request = [OSSQueryBucketExistRequest new];
    request.bucketName = @"test-chenli4";
    OSSTask *task = [_client queryBucketExist:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}


- (void)testListMultipartUploads
{
    OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    req.bucketName = @"oss-ios-bucket-list-multipart-uploads-test";
    [[_client createBucket:req] waitUntilFinished];
    
    OSSListMultipartUploadsRequest *listreq = [OSSListMultipartUploadsRequest new];
    listreq.bucketName = @"oss-ios-bucket-list-multipart-uploads-test";
    listreq.maxUploads = 1000;
    OSSTask *task = [_client listMultipartUploads:listreq];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSListMultipartUploadsResult * result = task.result;
        XCTAssertTrue(result.maxUploads == 1000);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-bucket-list-multipart-uploads-test" with:_client];
}

@end
