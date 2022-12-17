//
//  OSSHttp2Test.m
//  InspurOSSiOSTests
//
//  Created by 王铮 on 2018/8/3.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"
@interface OSSHttp2Tests : XCTestCase
{
    InspurOSSClient *_client;
    NSString *_bucketName;
    NSString *_http2endpoint;
}

@end

@implementation OSSHttp2Tests

- (void)setUp {
    [super setUp];
    
    [InspurOSSLog enableLog];
    _bucketName = @"aliyun-oss-ios-test-http2";
    _http2endpoint = @"https://oss-cn-shanghai.aliyuncs.com";
    [self setUpOSSClient];
    [self createBucket];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    [self deleteBucket];
}

- (void)setUpOSSClient
{
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    _client = [[InspurOSSClient alloc] initWithEndpoint:_http2endpoint
                               credentialProvider:authProv
                              clientConfiguration:config];
}

- (void)createBucket
{
    InspurOSSCreateBucketRequest *createBucket = [InspurOSSCreateBucketRequest new];
    createBucket.bucketName = _bucketName;
    
    [[_client createBucket:createBucket] waitUntilFinished];
}

- (void)deleteBucket
{
    [OSSTestUtils cleanBucket:_bucketName with:_client];
}

#pragma mark - putObject


//批量操作测试
- (void)testAPI_putObjectMultiTimes
{
    NSMutableArray<InspurOSSTask *> *allTasks = [NSMutableArray array];
    int max = 30;
    for (int i = 0; i < max; i++){
        NSString *objectKey = @"http2-wangwang.zip";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        InspurOSSPutObjectRequest * putRequest = [InspurOSSPutObjectRequest new];
        putRequest.bucketName = _bucketName;
        putRequest.objectKey = objectKey;
        putRequest.uploadingFileURL = fileURL;
        
        InspurOSSTask *putTask = [_client putObject:putRequest];
        [allTasks addObject:putTask];
    }
    
    InspurOSSTask *complexTask = [InspurOSSTask taskForCompletionOfAllTasks:allTasks];
    [complexTask waitUntilFinished];
    XCTAssertTrue(complexTask.error == nil);
    
    [allTasks removeAllObjects];
    
    for (int i = 0; i < max; i++){
        NSString *objectKey = @"http2-wangwang.zip";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        InspurOSSGetObjectRequest * getRequest = [InspurOSSGetObjectRequest new];
        getRequest.bucketName = _bucketName;
        getRequest.objectKey = objectKey;
        NSString *diskFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"local_test%zd.zip", i]];
        
        getRequest.downloadToFileURL = [NSURL fileURLWithPath:diskFilePath];
        
        InspurOSSTask *getTask = [_client getObject:getRequest];
        [allTasks addObject:getTask];
    }
    
    complexTask = [InspurOSSTask taskForCompletionOfAllTasks:allTasks];
    [complexTask waitUntilFinished];
    XCTAssertTrue(complexTask.error == nil);
}



@end
