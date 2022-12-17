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
    InspurOSSClient *_client;
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
    _client = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    [OSSLog enableLog];
}

- (void)testAPI_creatBucket_public
{
    NSString *bucket = @"test-cl-public";
    InspurOSSCreateBucketRequest *req = [InspurOSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"public-read-write";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_creatBucket_private
{
    NSString *bucket = @"test-cl-private";
    InspurOSSCreateBucketRequest *req = [InspurOSSCreateBucketRequest new];
    req.bucketName = bucket;
    req.xOssACL = @"private";
    OSSTask *task = [_client createBucket:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_deleteBucket
{
    NSString * bucket = @"test-cl-private";
    OSSDeleteBucketRequest *request = [OSSDeleteBucketRequest new];
    request.bucketName = bucket;
    OSSTask *task = [_client deleteBucket:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_listBuckets{
    InspurOSSGetServiceRequest *request = [InspurOSSGetServiceRequest new];
    OSSTask * task = [_client getService:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

//分页列举桶
- (void)testAPI_listPageService {
    InspurOSSListPageServiceRequest *request = [InspurOSSListPageServiceRequest new];
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

//查询桶是否存在, 存在
- (void)testAPI_queryBucketExistWhenExist {
    InspurOSSQueryBucketExistRequest *request = [InspurOSSQueryBucketExistRequest new];
    request.bucketName = @"test-cl-public";
    OSSTask *task = [_client queryBucketExist:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

//查询桶是否存在, 不存在
- (void)testAPI_queryBucketExistWhenNotExist {
    InspurOSSQueryBucketExistRequest *request = [InspurOSSQueryBucketExistRequest new];
    request.bucketName = @"test-cl-public-not-exist";
    OSSTask *task = [_client queryBucketExist:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

//查询桶的位置
- (void)testAPI_bucketLocation {
    InspurOSSGetBucketLocationRequest *request = [InspurOSSGetBucketLocationRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketLocation:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

/*
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
*/

- (void)testAPI_getBucketACL{
    InspurOSSGetBucketACLRequest * request = [InspurOSSGetBucketACLRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask * task = [_client getBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSGetBucketACLResult * result = task.result;
        XCTAssertEqualObjects(@"private", result.aclGranted);
        return nil;
    }] waitUntilFinished];
}

//设置桶权限, 共有
- (void)testAPI_putBucketACL_public {
    InspurOSSPutBucketACLRequest *request = [InspurOSSPutBucketACLRequest new];
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

//设置桶权限, 私有
- (void)testAPI_putBucketACL_privite {
    InspurOSSPutBucketACLRequest *request = [InspurOSSPutBucketACLRequest new];
    request.bucketName = @"test-chenli3";
    request.acl = @"private";
    OSSTask *task = [_client putBucketACL:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_getCORSList {
    InspurOSSGetBucketCORSRequest *request = [InspurOSSGetBucketCORSRequest new];
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
    InspurOSSPutBucketCORSRequest *request = [InspurOSSPutBucketCORSRequest new];
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
        rule1.maxAgeSeconds = @(200);
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

- (void)testAPI_deleteBucketCORS {
    NSString * bucket = @"test-chenli3";
    InspurOSSDeleteBucketCORSRequest *req = [InspurOSSDeleteBucketCORSRequest new];
    req.bucketName = bucket;
    OSSTask *task = [_client deleteBucketCORS:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putBucketVersioning_enabled {
    InspurOSSPutVersioningRequest *request = [InspurOSSPutVersioningRequest new];
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

- (void)testAPI_putBucketVersioning_suspend {
    InspurOSSPutVersioningRequest *request = [InspurOSSPutVersioningRequest new];
    request.bucketName = @"test-chenli3";
    request.enable = @"Suspended";
    
    OSSTask *task = [_client putBucketVersioning:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_getVersioning {
    InspurOSSGetVersioningRequest *request = [InspurOSSGetVersioningRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketVersioning:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_getService
{
    InspurOSSGetServiceRequest *request = [InspurOSSGetServiceRequest new];
    OSSTask * task = [_client getService:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    OSSGetServiceResult *result = nil;
    do {
        request = [InspurOSSGetServiceRequest new];
        request.maxKeys = 2;
        request.marker = result.nextMarker;
        task = [_client getService:request];
        [task waitUntilFinished];
        result = task.result;
    } while (result.isTruncated);
}

//查询桶加密
- (void)testAPI_getBucketEncryption {
    InspurOSSGetBucketEncryptionRequest *request = [InspurOSSGetBucketEncryptionRequest new];
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
    InspurOSSPutBucketEncryptionRequest *request = [InspurOSSPutBucketEncryptionRequest new];
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
    InspurOSSDeleteBucketEncryptionRequest *req = [InspurOSSDeleteBucketEncryptionRequest new];
    req.bucketName = bucket;
    OSSTask *task = [_client deleteBucketEncryption:req];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

//查询静态网站托管
- (void)testAPI_getBucketWebsite {
    InspurOSSGetBucketWebsiteRequest *request = [InspurOSSGetBucketWebsiteRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketWebsite:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

//设置静态网站托管
- (void)testAPI_putBucketWebsite {
    InspurOSSPutBucketWebsiteRequest *request = [InspurOSSPutBucketWebsiteRequest new];
    request.bucketName = @"test-chenli3";
    request.indexDocument = @"index.html";
    request.errroDocument = @"error.html";
    OSSTask *task = [_client putBucketWebsite:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deleteBucketWebsite {
    NSString * bucket = @"test-chenli3";
    InspurOSSDeleteBucketWebsiteRequest *req = [InspurOSSDeleteBucketWebsiteRequest new];
    req.bucketName = bucket;
    OSSTask *task = [_client deleteBucketWebsite:req];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
}

//自定义域名
- (void)testAPI_getBucketDomain{
    InspurOSSGetBucketDomainRequest *request = [InspurOSSGetBucketDomainRequest new];
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
    InspurOSSPutBucketDomainRequest *request = [InspurOSSPutBucketDomainRequest new];
    request.bucketName = @"test-chenli3";
    request.domainList = @[
        @{
            @"domainName" : @"www.ceshi.com",
            @"isWebsite" : @"false"
        }
    ];
    OSSTask *task = [_client putBucketDomain:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

/*
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
*/

//

- (void)testAPI_deleteDomain {
    InspurOSSDeleteBucketDomainRequest *request = [InspurOSSDeleteBucketDomainRequest new];
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
    InspurOSSGetBucketLifeCycleRequest *request = [InspurOSSGetBucketLifeCycleRequest new];
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
    InspurOSSPutBucketLifeCycleRequest *request = [InspurOSSPutBucketLifeCycleRequest new];
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
    InspurOSSDeleteBucketLifeCycleRequest *request = [InspurOSSDeleteBucketLifeCycleRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client deleteBucketLifeCycle:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

//自定义域名
- (void)testAPI_putBucketPolicy {
    InspurOSSPutBucketPolicyRequest *request = [InspurOSSPutBucketPolicyRequest new];
    request.bucketName = @"test-chenli3";
    request.policyVersion = @"2012-10-17";
    request.statementList = @[
        @{
            @"Action":@[@"s3:ListBucket", @"s3:GetObject"],
            @"Resource": @[@"arn:aws:s3:::test-chenli3", @"arn:aws:s3:::test-chenli3/*"],
            @"Effect": @"Allow",
            @"Principal": @{
                @"AWS":@[@"arn:aws:iam:::user/testid2", @"arn:aws:iam::tenanttwo:user/userthree"]
            }
        }
    ];
    OSSTask *task = [_client putBucketPolicy:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_getBucketPolicy{
    InspurOSSGetBucketPolicyRequest *request = [InspurOSSGetBucketPolicyRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client getBucketPolicy:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}

- (void)testAPI_deletePolicy {
    InspurOSSDeleteBucketPolicyRequest *request = [InspurOSSDeleteBucketPolicyRequest new];
    request.bucketName = @"test-chenli3";
    OSSTask *task = [_client deleteBucketPolicy:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSDDLogVerbose(@"%@",task.result);
        return nil;
    }] waitUntilFinished];
    NSLog(@"%@", task);
}


- (void)testListMultipartUploads{
    InspurOSSListMultipartUploadsRequest *listreq = [InspurOSSListMultipartUploadsRequest new];
    listreq.bucketName = @"test-chenli3";
    listreq.maxUploads = 1000;
    OSSTask *task = [_client listMultipartUploads:listreq];
    
    [[task continueWithBlock:^id(OSSTask *task) {
        XCTAssertNil(task.error);
        OSSListMultipartUploadsResult * result = task.result;
        XCTAssertTrue(result.maxUploads == 1000);
        return nil;
    }] waitUntilFinished];
    
}

@end
