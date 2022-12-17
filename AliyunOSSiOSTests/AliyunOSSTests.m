
//
//  AliyunOSSTests.m
//  InspurOSSiOSTests
//
//  Created by xx on 2018/1/18.
//  Copyright © 2022年 Inspur. All rights reserved.
//
#import "AliyunOSSTests.h"
@implementation AliyunOSSTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setupContainer];
    [self setupClient];
    [self setupTestFiles];
    [self createBucket];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [self deleteBucket];
    
}

- (void)setupClient {
    //    OSSAuthCredentialProvider *provider = [OSSAuthCredentialProvider new];
    InspurOSSPlainTextAKSKPairCredentialProvider *provider = [[InspurOSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    InspurOSSClientConfiguration * conf = [InspurOSSClientConfiguration new];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    conf.maxConcurrentRequestCount = 5;
    
    // switches to another credential provider.
    _client = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:provider
                              clientConfiguration:conf];
}

- (void)setupContainer{
    _fileNames = @[@"file1k", @"file10k", @"file100k", @"file1m", @"file5m", @"file10m", @"fileDirA/", @"fileDirB/"];
    _fileSizes = @[@1024, @10240, @102400, @(1024 * 1024 * 1), @(1024 * 1024 * 5), @(1024 * 1024 * 10), @1024, @1024];
}

- (void)setupTestFiles {
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * mainDir = [NSString oss_documentDirectory];
    
    for (int i = 0; i < [_fileNames count]; i++) {
        NSMutableData * basePart = [NSMutableData dataWithCapacity:1024];
        for (int j = 0; j < 1024/4; j++) {
            u_int32_t randomBit = j;// arc4random();
            [basePart appendBytes:(void*)&randomBit length:4];
        }
        NSString * name = [_fileNames objectAtIndex:i];
        long size = [[_fileSizes objectAtIndex:i] longValue];
        NSString * newFilePath = [mainDir stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:newFilePath]) {
            [fm removeItemAtPath:newFilePath error:nil];
        }
        [fm createFileAtPath:newFilePath contents:nil attributes:nil];
        NSFileHandle * f = [NSFileHandle fileHandleForWritingAtPath:newFilePath];
        for (int k = 0; k < size/1024; k++) {
            [f writeData:basePart];
        }
        [f closeFile];
    }
    OSSLogDebug(@"main bundle: %@", mainDir);
}

- (void)createBucket {
    InspurOSSCreateBucketRequest *createBucket1 = [InspurOSSCreateBucketRequest new];
    createBucket1.bucketName = OSS_BUCKET_PUBLIC;
    [[_client createBucket:createBucket1] waitUntilFinished];
    
    InspurOSSCreateBucketRequest *createBucket2 = [InspurOSSCreateBucketRequest new];
    createBucket2.bucketName = OSS_BUCKET_PRIVATE;
    createBucket2.xOssACL = @"public-read-write";
    [[_client createBucket:createBucket2] waitUntilFinished];
}

- (void)deleteBucket {
    InspurOSSDeleteBucketRequest *deleteBucket1 = [InspurOSSDeleteBucketRequest new];
    deleteBucket1.bucketName = OSS_BUCKET_PUBLIC;
    [[_client deleteBucket:deleteBucket1] waitUntilFinished];
    
    InspurOSSDeleteBucketRequest *deleteBucket2 = [InspurOSSDeleteBucketRequest new];
    deleteBucket2.bucketName = OSS_BUCKET_PRIVATE;
    [[_client deleteBucket:deleteBucket2] waitUntilFinished];
}

@end

