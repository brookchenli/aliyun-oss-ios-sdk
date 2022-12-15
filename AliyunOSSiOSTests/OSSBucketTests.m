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
    //OSSCreateBucketRequest *req = [OSSCreateBucketRequest new];
    //req.bucketName = @"test-chenli3";
    //[[_client createBucket:req] waitUntilFinished];
    
    OSSGetBucketACLRequest * request = [OSSGetBucketACLRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask * task = [_client getBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetBucketACLResult * result = task.result;
        XCTAssertEqualObjects(@"private", result.aclGranted);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:@"oss-ios-get-bucket-acl-test" with:_client];
}

//设置桶权限
- (void)testAPI_putBucketACL {
    OSSPutBucketACLRequest *request = [OSSPutBucketACLRequest new];
    request.bucketName = @"test-chenli3";
    request.acl = @"public-read";
    OSSTask *task = [_client putBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
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

//
- (void)testAPI_getCORSList {
    OSSGetBucketCORSRequest *request = [OSSGetBucketCORSRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketCORS:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putCORSList {
    OSSPutBucketCORSRequest *request = [OSSPutBucketCORSRequest new];
    request.bucketName = @"test-chenli3";
    
    NSMutableArray <OSSCORSRule *>* tmpArray = [NSMutableArray array];
    {
        OSSCORSRule *rule1 = [OSSCORSRule new];
        rule1.ID = @"123";
        rule1.allowedOriginList = @[@"*"];
        rule1.allowedMethodList = @[@"PUT", @"GET"];
        rule1.allowedHeaderList = @[@"*"];
        rule1.exposeHeaderList = @[@"x-oss-test"];
        rule1.maxAgeSeconds = @(100);
        [tmpArray addObject:rule1];
    }
    {
        OSSCORSRule *rule1 = [OSSCORSRule new];
        rule1.ID = @"456";
        rule1.allowedOriginList = @[@"*"];
        rule1.allowedMethodList = @[@"PUT", @"GET", @"DELETE"];
        rule1.allowedHeaderList = @[@"*"];
        rule1.exposeHeaderList = @[@"x-oss-test"];
        rule1.maxAgeSeconds = @(100);
        [tmpArray addObject:rule1];
    }
    request.bucketCORSRuleList = tmpArray;
    OSSTask *task = [_client putBucketCORS:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putBucketVersioning {
    OSSPutVersioningRequest *request = [OSSPutVersioningRequest new];
    request.bucketName = @"test-chenli3";
    //request.enable = @"Suspended";
    request.enable = @"Enabled";
    
    OSSTask *task = [_client putBucketVersioning:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_getVersioning {
    OSSGetVersioningRequest *request = [OSSGetVersioningRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketVersioning:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deleteBucketCORS {
    NSString * bucket = @"test-chenli3";
    OSSDeleteBucketCORSRequest *req = [OSSDeleteBucketCORSRequest new];
    req.bucketName = bucket;
    OSSTask *task = [_client deleteBucketCORS:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

//查询桶加密
- (void)testAPI_getBucketEncryption {
    OSSGetBucketEncryptionRequest *request = [OSSGetBucketEncryptionRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketEncryption:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putBucketEncrytion {
    OSSPutBucketEncryptionRequest *request = [OSSPutBucketEncryptionRequest new];
    request.bucketName = @"test-chenli3";
    request.sseAlgorithm = @"AES256";
    OSSTask *task = [_client putBucketEncryption:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deleteBucketEncryption {
    NSString * bucket = @"test-chenli3";
    OSSDeleteBucketEncryptionRequest *req = [OSSDeleteBucketEncryptionRequest new];
    req.bucketName = bucket;
    OSSTask *task = [_client deleteBucketEncryption:req];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
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

//查询桶的位置
- (void)testAPI_bucketLocation {
    OSSGetBucketLocationRequest *request = [OSSGetBucketLocationRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketLocation:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

//查询桶加密
- (void)testAPI_getBucketWebsite {
    OSSGetBucketWebsiteRequest *request = [OSSGetBucketWebsiteRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketWebsite:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putBucketWebsite {
    OSSPutBucketWebsiteRequest *request = [OSSPutBucketWebsiteRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client putBucketWebsite:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}


//自定义域名
- (void)testAPI_getBucketDomain{
    OSSGetBucketDomainRequest *request = [OSSGetBucketDomainRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketDomain:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putBucketDomain {
    OSSPutBucketDomainRequest *request = [OSSPutBucketDomainRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client putBucketDomain:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deleteDomain {
    OSSDeleteBucketDomainRequest *request = [OSSDeleteBucketDomainRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client deleteBucketDomain:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}


//自定义域名
- (void)testAPI_getBucketLifeCycle{
    OSSGetBucketLifeCycleRequest *request = [OSSGetBucketLifeCycleRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketLifeCycle:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_putBucketLifeCycle {
    OSSPutBucketLifeCycleRequest *request = [OSSPutBucketLifeCycleRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client putBucketLifeCycle:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deleteLifeCycle {
    OSSDeleteBucketLifeCycleRequest *request = [OSSDeleteBucketLifeCycleRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client deleteBucketLifeCycle:request];
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
