//
//  OSSObjectTests.m
//  InspurOSSiOSTests
//
//  Created by xx on 2017/12/11.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSSTestMacros.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestUtils.h"
#import <AliyunOSSiOS/InspurOSSDefine.h>

#define SCHEME @"https://"
#define ENDPOINT @"oss-cn-hangzhou.aliyuncs.com"
#define CNAME_ENDPOINT @"oss.custom.com"
#define IP_ENDPOINT @"192.168.1.1:8080"
#define CUSTOMPATH(endpoint) [endpoint stringByAppendingString:@"/path"]
#define BUCKET_NAME @"BucketName"
#define OBJECT_KEY @"ObjectKey"


@interface InspurOSSClient(Test)

- (NSUInteger)judgePartSizeForMultipartRequest:(InspurOSSMultipartUploadRequest *)request fileSize:(unsigned long long)fileSize;
- (NSUInteger)ceilPartSize:(NSUInteger)partSize;

@end

@interface OSSObjectTests : XCTestCase
{
    InspurOSSClient *_client;
    NSArray<NSNumber *> *_fileSizes;
    NSArray<NSString *> *_fileNames;
    NSString *_privateBucketName;
    NSString *_publicBucketName;
    NSString *_testBucketName;
    InspurOSSClient *_specialClient;
    
}

@end

@implementation OSSObjectTests

- (void)setUp {
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSArray *array2 = [array1[1] componentsSeparatedByString:@"_"];
    NSString *testName = [[array2[1] substringToIndex:([array2[1] length] -1)] lowercaseString];
    
    _privateBucketName = [@"oss-ios-private-" stringByAppendingString:testName];
    _publicBucketName = [@"oss-ios-public-" stringByAppendingString:testName];
    _testBucketName = @"test-chenli3";
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpOSSClient];
    [self setUpLocalFiles];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    //[OSSTestUtils cleanBucket:_privateBucketName with:_client];
    //[OSSTestUtils cleanBucket:_publicBucketName with:_client];
}

/*
- (void)setUpOSSClient
{
    OSSClientConfiguration *config = [OSSClientConfiguration new];
//    config.crc64Verifiable = YES;
    
    //OSSAuthCredentialProvider *authProv = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    OSSPlainTextAKSKPairCredentialProvider *authProv = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    _client = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    
    _specialClient = [[OSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                      credentialProvider:authProv
                                     clientConfiguration:config];
    
    [OSSLog enableLog];
    
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _privateBucketName;
    [[_client createBucket:createBucket1] waitUntilFinished];
    
    OSSCreateBucketRequest *createBucket2 = [OSSCreateBucketRequest new];
    createBucket2.bucketName = _publicBucketName;
    createBucket2.xOssACL = @"public-read-write";
    [[_client createBucket:createBucket2] waitUntilFinished];
    
    //upload test image
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[_client putObject:put] waitUntilFinished];
}
*/

- (void)setUpOSSClient
{
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.timeoutIntervalForRequest = 120.0;
    
    InspurOSSCustomSignerCredentialProvider *provider = [[InspurOSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        
        // 用户应该在此处将需要签名的字符串发送到自己的业务服务器(AK和SK都在业务服务器保存中,从业务服务器获取签名后的字符串)
        InspurOSSFederationToken *token = [InspurOSSFederationToken new];
        token.tAccessKey = OSS_ACCESSKEY_ID;
        token.tSecretKey = OSS_SECRETKEY_ID;
        sleep(0.15);
        NSString *signedContent = [InspurOSSUtil sign:contentToSign withToken:token];
        return signedContent;
    }];
    
    _client = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:provider
                              clientConfiguration:config];
    
    [InspurOSSLog enableLog];
    /*
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _testBucketName;
    [[_client createBucket:createBucket1] waitUntilFinished];
     */
}

- (void)setUpOSSClient111
{
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.timeoutIntervalForRequest = 120.0;
    InspurOSSPlainTextAKSKPairCredentialProvider *authProv = [[InspurOSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    _client = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                               credentialProvider:authProv
                              clientConfiguration:config];
    
    [InspurOSSLog enableLog];
    /*
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = _testBucketName;
    [[_client createBucket:createBucket1] waitUntilFinished];
     */
}

- (void)setUpLocalFiles
{
    _fileNames = @[@"file1k", @"file10k", @"file100k", @"file1m", @"file5m", @"file10m", @"fileDirA/", @"fileDirB/"];
    _fileSizes = @[@1024, @10240, @102400, @(1024 * 1024 * 1), @(1024 * 1024 * 5), @(1024 * 1024 * 10), @1024, @1024];
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * documentDirectory = [NSString oss_documentDirectory];
    
    for (int i = 0; i < [_fileNames count]; i++)
    {
        NSMutableData * basePart = [NSMutableData dataWithCapacity:1024];
        for (int j = 0; j < 1024/4; j++)
        {
            u_int32_t randomBit = j;// arc4random();
            [basePart appendBytes:(void*)&randomBit length:4];
        }
        NSString * name = [_fileNames objectAtIndex:i];
        long size = [[_fileSizes objectAtIndex:i] longLongValue];
        NSString * newFilePath = [documentDirectory stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:newFilePath])
        {
            [fm removeItemAtPath:newFilePath error:nil];
        }
        [fm createFileAtPath:newFilePath contents:nil attributes:nil];
        NSFileHandle * f = [NSFileHandle fileHandleForWritingAtPath:newFilePath];
        for (int k = 0; k < size/1024; k++)
        {
            [f writeData:basePart];
        }
        [f closeFile];
    }
    OSSLogVerbose(@"document directory path is: %@", documentDirectory);
    
    
    
}

#pragma mark - 列举文件
- (void)testAPI_listObjects {
    InspurOSSGetBucketRequest * request = [InspurOSSGetBucketRequest new];
    request.bucketName = _testBucketName;
   
    InspurOSSTask * task = [_client getBucket:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}


- (void)testAPI_putObjectFromFileTest_local_file {
    
    NSURL * fileURL = [[NSBundle mainBundle] URLForResource:@"ceshi" withExtension:@"png"];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = @"ceshi.png";
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        /*
        BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
         */
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}


- (void)testAPI_putObjectFromFileTest {
    
    NSString *objectKey = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];

    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        /*
        BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
         */
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectFromFileTest_noKey {
    
    NSString *objectKey = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = nil;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];

    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}


- (void)testAPI_deleteObj {
    InspurOSSDeleteObjectRequest * delete = [InspurOSSDeleteObjectRequest new];
    delete.bucketName = _testBucketName;
    delete.objectKey = @"file1k";
    InspurOSSTask *task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_copyObject {
    InspurOSSCopyObjectRequest * copy = [InspurOSSCopyObjectRequest new];
    copy.bucketName = _testBucketName;
    copy.objectKey = @"file1k-copy";
    copy.sourceBucketName = _testBucketName;
    copy.sourceObjectKey = @"file1k";
    InspurOSSTask *task = [_client copyObject:copy];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_downloadObject{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = @"file1k";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

// 追加上传

- (void)testAPI_preSign{
    InspurOSSTask *task = [_client presignConstrainURLWithBucketName:_testBucketName withObjectKey:@"file1k" withExpirationInterval:30];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
}

- (void)testAPI_queryObjectExistWithExistObject{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_testBucketName objectKey:@"file1k" error:&error];
    XCTAssertEqual(isExist, YES);
    XCTAssertNil(error);
}

- (void)testAPI_queryObjectExistWithNoExistObject
{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_testBucketName objectKey:@"wrong-key" error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNil(error);
}

- (void)testAPI_removeMultipleObjects {
    InspurOSSDeleteMultipleObjectsRequest *request = [InspurOSSDeleteMultipleObjectsRequest new];
    request.bucketName = _testBucketName;
    request.keys = @[@"file1k",@"file1k-copy"];
    request.encodingType = @"url";
    
    InspurOSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
    
}


- (void)testAPI_tmpGetObjectACL{
    InspurOSSGetObjectACLRequest *request = [InspurOSSGetObjectACLRequest new];
    request.bucketName = _testBucketName;
    request.objectName = @"file1k";
    InspurOSSTask *task = [_client getObjectACL:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(t.error);
        return nil;
    }] waitUntilFinished];
    
}


- (void)testAPI_setObjectACL_private{
    
    InspurOSSPutObjectACLRequest * putAclRequest = [InspurOSSPutObjectACLRequest new];
    putAclRequest.bucketName = _testBucketName;
    putAclRequest.objectKey = @"file1k";
    //putAclRequest.acl = @"public-read-write";
    putAclRequest.acl = @"private";
    InspurOSSTask *task = [_client putObjectACL:putAclRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_setObjectACL_public{
    
    InspurOSSPutObjectACLRequest * putAclRequest = [InspurOSSPutObjectACLRequest new];
    putAclRequest.bucketName = _testBucketName;
    putAclRequest.objectKey = @"file1k";
    putAclRequest.acl = @"public-read-write";
    InspurOSSTask *task = [_client putObjectACL:putAclRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}




- (void)testAPI_getMetaData{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = @"file1k";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_setMetaData {
    InspurOSSPutObjectMetaRequest * putObjectRequest = [InspurOSSPutObjectMetaRequest new];
    putObjectRequest.bucketName = _testBucketName;
    putObjectRequest.objectKey = @"file1k";
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"meta2", @"x-oss-meta-test1", nil];
    
    InspurOSSTask * task = [_client putObjectMetaData:putObjectRequest];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getVersions{
    InspurOSSGetObjectVersionRequest * request = [[InspurOSSGetObjectVersionRequest alloc] init];
    
    request.bucketName = _testBucketName;
    InspurOSSTask * task = [_client getObjectVersions:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_deleteVersion{
    InspurOSSGetObjectVersionRequest * request = [[InspurOSSGetObjectVersionRequest alloc] init];
    request.bucketName = _testBucketName;
    InspurOSSTask * task = [_client getObjectVersions:request];
    [task waitUntilFinished];
    XCTAssertNil(task.error);
    
    InspurOSSGetObjectVersionResult *result = (InspurOSSGetObjectVersionResult *)task.result;
    NSArray *versionList = result.versionList;
    NSMutableArray *versionIds = [NSMutableArray array];
    [versionList enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *key = [obj objectForKey:@"Key"];
        NSString *versionId = [obj objectForKey:@"VersionId"];

        if (key && [key isEqualToString:@"file1k"] && versionId && versionId.length > 0 && ![versionId isEqualToString:@"null"]) {
            [versionIds addObject:versionId];
        }
    }];
    
    NSString *lastVersionId = [versionIds lastObject];
    
    InspurOSSDeleteObjectVersionRequest *deleteRequest = [InspurOSSDeleteObjectVersionRequest new];
    deleteRequest.bucketName = _testBucketName;
    deleteRequest.versionId = lastVersionId;
    deleteRequest.objectName = @"file1k";
    InspurOSSTask *deleteTask = [_client deleteObjectVersion:deleteRequest];
    [[deleteTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_MultipartUploadNormal {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
//    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = @"test-chenli3";
    multipartUploadRequest.objectKey = @"test.txt";
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 8 * 1024 * 1024;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };

    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"txt"];
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            NSLog(@"error: %@", task.error);
            if ([task.error.domain isEqualToString:InspurOSSClientErrorDomain] && task.error.code == InspurOSSClientErrorCodeCannotResumeUpload) {
                // The upload cannot be resumed. Needs to re-initiate a upload.
            }
        } else {
            BOOL isEqual = YES;
            XCTAssertTrue(isEqual);
        }
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

//断点续传
- (void)testAPI_ResumbleUpload {
    __block bool cancel = NO;
    InspurOSSResumableUploadRequest * resumableUpload = [InspurOSSResumableUploadRequest new];
    resumableUpload.bucketName = _testBucketName;
    resumableUpload.objectKey = @"wf.pdf";
    resumableUpload.deleteUploadIdOnCancelling = NO;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 2 * 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(totalByteSent >= totalBytesExpectedToSend /2){
            cancel = YES;
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wf" withExtension:@"pdf"];
    InspurOSSTask * resumeTask = [_client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    while (!cancel) {
        [NSThread sleepForTimeInterval:0.1];
    }
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
}

//取消后终止
- (void)testAPI_ResumbleUploadAbort {
    __block bool cancel = NO;
    InspurOSSResumableUploadRequest * resumableUpload = [InspurOSSResumableUploadRequest new];
    resumableUpload.bucketName = _testBucketName;
    resumableUpload.objectKey = @"wf.pdf";
    resumableUpload.deleteUploadIdOnCancelling = YES;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 2 * 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(totalByteSent >= 6 * 1024 * 1024){
            cancel = YES;
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wf" withExtension:@"pdf"];
    InspurOSSTask * resumeTask = [_client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    while (!cancel) {
        [NSThread sleepForTimeInterval:0.1];
    }
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
}

//
- (void)testAPI_listParts {
    __block bool cancel = NO;
    InspurOSSResumableUploadRequest * resumableUpload = [InspurOSSResumableUploadRequest new];
    resumableUpload.bucketName = _testBucketName;
    resumableUpload.objectKey = @"wf.pdf";
    resumableUpload.deleteUploadIdOnCancelling = NO;
    NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    resumableUpload.recordDirectoryPath = cachesDir;
    resumableUpload.contentType = @"application/octet-stream";
    resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    resumableUpload.partSize = 1 * 1024 * 1024;
    resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        if(totalByteSent >= 3 * 1024 * 1024){
            cancel = YES;
        }
    };
    resumableUpload.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wf" withExtension:@"pdf"];
    InspurOSSTask * resumeTask = [_client resumableUpload:resumableUpload];
    [resumeTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    while (!cancel) {
        [NSThread sleepForTimeInterval:0.1];
    }
    [resumableUpload cancel];
    [resumeTask waitUntilFinished];
    NSString *uploadId = resumableUpload.uploadId;
    NSString *objectName = resumableUpload.objectKey;
    
    InspurOSSListPartsRequest * listParts = [InspurOSSListPartsRequest new];
    listParts.bucketName = _testBucketName;
    listParts.objectKey = objectName;
    listParts.uploadId = uploadId;
    InspurOSSTask * listPartsTask = [_client listParts:listParts];
    [[listPartsTask continueWithBlock:^id(InspurOSSTask *task) {
            XCTAssertNotNil(task.error);
            NSLog(@"error: %@", task.error);
            return nil;
        }] waitUntilFinished] ;
    
}

- (void)testAPI_MultipartUploadCancel {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.bucketName = @"test-chenli3";
    multipartUploadRequest.objectKey = @"wf.pdf";
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.partSize = 8 * 1024 * 1024;
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        XCTAssertTrue(totalByteSent <= totalBytesExpectedToSend);
    };
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wf" withExtension:@"pdf"];
    InspurOSSTask * resumeTask = [_client multipartUpload:multipartUploadRequest];
    [resumeTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"error: %@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        return nil;
    }];
    
    [NSThread sleepForTimeInterval:3];
    
    [multipartUploadRequest cancel];
    [resumeTask waitUntilFinished];
}

#pragma mark - putObject

- (void)testAPI_putObjectFromNSData
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    XCTAssertNil(readError);
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectFromFile{
    for (NSUInteger pIdx = 0; pIdx < _fileNames.count; pIdx++)
    {
        NSString *objectKey = _fileNames[pIdx];
        NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        
        InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
        request.bucketName = _privateBucketName;
        request.objectKey = objectKey;
        request.uploadingFileURL = fileURL;
        request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
//  在统一config 中修改
//        request.crcFlag = OSSRequestCRCOpen;
        
        OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
        request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
            [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
        };
        
        InspurOSSTask * task = [_client putObject:request];
        [[task continueWithBlock:^id(InspurOSSTask *task) {
            XCTAssertNil(task.error);
            BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                              objectKey:objectKey
                                          localFilePath:filePath];
            XCTAssertTrue(isEqual);
            return nil;
        }] waitUntilFinished];
        XCTAssertTrue([progressTest completeValidateProgress]);
    }
}

- (void)testAPI_putObjectFromFileWithCRC
{
    NSString *objectKey = @"putObject-wangwang.zip";
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"wangwang" ofType:@"zip"];;
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
//  在统一config 中修改
//    request.crcFlag = OSSRequestCRCOpen;
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                          objectKey:objectKey
                                      localFilePath:filePath];
        XCTAssertTrue(isEqual);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithoutContentType
{
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    NSString *objectKeyWithoutContentType = @"objectWithoutContentType";
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKeyWithoutContentType;
//    request.crcFlag = OSSRequestCRCOpen;
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"bytesSent: %lld, totalByteSent: %lld, totalBytesExpectedToSend: %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    request.contentType = @"";
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
    
    InspurOSSHeadObjectRequest * head = [InspurOSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = objectKeyWithoutContentType;
    [[[_client headObject:head] continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSHeadObjectResult * headResult = task.result;
        XCTAssertNotNil([headResult.objectMeta objectForKey:@"Content-Type"]);
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:objectKeyWithoutContentType
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithContentType
{
    NSString *fileName = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = fileName;
    
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentType = @"application/special";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        if (task.error) {
            OSSLogError(@"%@", task.error);
        }
        InspurOSSPutObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
    
    InspurOSSHeadObjectRequest * head = [InspurOSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = fileName;
    
    [[[_client headObject:head] continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSHeadObjectResult * headResult = task.result;
        XCTAssertEqualObjects([headResult.objectMeta objectForKey:@"Content-Type"], @"application/special");
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_putObjectWithServerCallback
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.callbackParam = @{
                              @"callbackUrl": OSS_CALLBACK_URL,
                              @"callbackBody": @"test"
                              };
    request.callbackVar = @{
                            @"var1": @"value1",
                            @"var2": @"value2"
                            };
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectACL
{
    [OSSTestUtils putTestDataWithKey:_fileNames[0] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    InspurOSSTask * task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
    XCTAssertEqual(-403, task.error.code);
    
    InspurOSSPutObjectACLRequest * putAclRequest = [InspurOSSPutObjectACLRequest new];
    putAclRequest.bucketName = _privateBucketName;
    putAclRequest.objectKey = _fileNames[0];
    putAclRequest.acl = @"public-read-write";
    task = [_client putObjectACL:putAclRequest];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
    
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.isAuthenticationRequired = NO;
    task = [_client getObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_appendObject
{
    InspurOSSDeleteObjectRequest * delete = [InspurOSSDeleteObjectRequest new];
    delete.bucketName = _testBucketName;
    delete.objectKey = @"appendObject";
    InspurOSSTask * task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    InspurOSSAppendObjectRequest * request = [InspurOSSAppendObjectRequest new];
    request.bucketName = _testBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = 0;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    __block int64_t nextAppendPosition = 0;
    __block NSString *lastCrc64ecma;
    task = [_client appendObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSAppendObjectResult * result = task.result;
        nextAppendPosition = result.xOssNextAppendPosition;
        lastCrc64ecma = result.remoteCRC64ecma;
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
    
    request.bucketName = _testBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = nextAppendPosition;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    task = [_client appendObject:request withCrc64ecma:lastCrc64ecma];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

#pragma mark - getObject
- (void)testAPI_getObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[0] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[0];
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectACL
{
    InspurOSSGetObjectACLRequest * request = [InspurOSSGetObjectACLRequest new];
    request.bucketName = _privateBucketName;
    request.objectName = OSS_IMAGE_KEY;
    
    InspurOSSTask * task = [_client getObjectACL:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(task.error);
        if (t.result != nil) {
            InspurOSSGetObjectACLResult *result = (InspurOSSGetObjectACLResult *)t.result;
            XCTAssertEqualObjects(result.grant, @"default");
        }
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getImage
{
    InspurOSSPutObjectRequest * put = [InspurOSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    [[_client putObject:put] waitUntilFinished];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = OSS_IMAGE_KEY;
    request.xOssProcess = @"image/resize,m_lfit,w_100,h_100";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    InspurOSSTask * task = [_client getObject:request];

    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRecieveDataBlock
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    request.onRecieveData = ^(NSData * data) {
        NSLog(@"onRecieveData: %lu", [data length]);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        
        InspurOSSGetObjectResult * result = task.result;
        // if onRecieveData is setting, it will not return whole data
        XCTAssertEqual(0, [result.downloadedData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRecieveDataBlockAndNoRetry
{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"wrong-key";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    request.onRecieveData = ^(NSData * data) {
        NSLog(@"onRecieveData: %lu", [data length]);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithRange
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    request.range = [[OSSRange alloc] initWithStart:0 withEnd:99]; // bytes=0-99
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertEqual(206, result.httpResponseCode);
        XCTAssertEqual(100, [result.downloadedData length]);
        XCTAssertEqualObjects(@"100", [result.objectMeta objectForKey:@"Content-Length"]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectByPartiallyRecieveData
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    NSMutableData * recieveData = [NSMutableData data];
    
    request.onRecieveData = ^(NSData * data) {
        [recieveData appendData:data];
        NSLog(@"recieveData %ld", [recieveData length]);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024 * 1024, [recieveData length]);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectFromPublicBucket
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = _fileNames[3];
    
    NSString * saveToFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads/temp/file1m"];
    request.downloadToFileURL = [NSURL fileURLWithPath:saveToFilePath];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        NSFileManager * fm = [NSFileManager defaultManager];
        XCTAssertTrue([fm fileExistsAtPath:request.downloadToFileURL.path]);
        int64_t fileLength = [[[fm attributesOfItemAtPath:request.downloadToFileURL.path
                                                    error:nil] objectForKey:NSFileSize] longLongValue];
        XCTAssertEqual(1024 * 1024, fileLength);
        [fm removeItemAtPath:saveToFilePath error:nil];
        [fm removeItemAtPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads/temp"] error:nil];
        [fm removeItemAtPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"downloads"] error:nil];
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectOverwriteOldFile
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    [OSSTestUtils putTestDataWithKey:_fileNames[2] withClient:_client withBucket:_publicBucketName];
    NSString *tmpFilePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile"];
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[3];
    request.downloadToFileURL = [NSURL fileURLWithPath:tmpFilePath];
    
    InspurOSSTask * task = [_client getObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertNil(result.downloadedData);
        return nil;
    }] waitUntilFinished];
    
    uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:tmpFilePath error:nil] fileSize];
    XCTAssertEqual(1024 * 1024, fileSize);
    
    request = [InspurOSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[2];
    request.downloadToFileURL = [NSURL fileURLWithPath:tmpFilePath];
    
    task = [_client getObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertNil(result.downloadedData);
        return nil;
    }] waitUntilFinished];
    
    fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:tmpFilePath error:nil] fileSize];
    XCTAssertEqual(102400, fileSize);
    [[NSFileManager defaultManager] removeItemAtPath:tmpFilePath error:nil];
}

- (void)testAPI_putSymlink {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * putObjectRequest = [InspurOSSPutObjectRequest new];
    putObjectRequest.bucketName = _publicBucketName;
    putObjectRequest.objectKey = @"test-symlink-targetObjectName";
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"test-symlink-target", @"x-oss-meta-name", nil];
    
    InspurOSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    InspurOSSPutSymlinkRequest * putSymlinkRequest = [InspurOSSPutSymlinkRequest new];
    putSymlinkRequest.bucketName = _publicBucketName;
    putSymlinkRequest.objectKey = @"test-symlink-objectName";
    putSymlinkRequest.targetObjectName = @"test-symlink-targetObjectName";
    putSymlinkRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"HONGKONG", @"x-oss-meta-location", nil];
    
    InspurOSSTask * putSymlinktask = [_client putSymlink:putSymlinkRequest];
    
    [[putSymlinktask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    InspurOSSGetSymlinkRequest * getSymlinkRequest = [InspurOSSGetSymlinkRequest new];
    getSymlinkRequest.bucketName = _publicBucketName;
    getSymlinkRequest.objectKey = @"test-symlink-objectName";
    
    InspurOSSTask * getSymlinktask = [_client getSymlink:getSymlinkRequest];
    
    [[getSymlinktask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetSymlinkResult *result = (InspurOSSGetSymlinkResult *)task.result;
        NSString *targetObjectName = (NSString *)[result.httpResponseHeaderFields valueForKey:InspurOSSHttpHeaderSymlinkTarget];
        NSString *metaLocation = (NSString *)[result.httpResponseHeaderFields valueForKey:@"x-oss-meta-location"];
        
        XCTAssertTrue([targetObjectName isEqualToString:@"test-symlink-targetObjectName"]);
        XCTAssertTrue([metaLocation isEqualToString:@"HONGKONG"]);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getSymlink {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * putObjectRequest = [InspurOSSPutObjectRequest new];
    putObjectRequest.bucketName = _publicBucketName;
    putObjectRequest.objectKey = @"test-symlink-targetObjectName";
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"test-symlink-target", @"x-oss-meta-name", nil];
    
    InspurOSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    InspurOSSPutSymlinkRequest * putSymlinkRequest = [InspurOSSPutSymlinkRequest new];
    putSymlinkRequest.bucketName = _publicBucketName;
    putSymlinkRequest.objectKey = @"test-symlink-objectName";
    putSymlinkRequest.targetObjectName = @"test-symlink-targetObjectName";
    putSymlinkRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"HONGKONG", @"x-oss-meta-location", nil];
    
    InspurOSSTask * putSymlinktask = [_client putSymlink:putSymlinkRequest];
    
    [[putSymlinktask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    InspurOSSGetSymlinkRequest * getSymlinkRequest = [InspurOSSGetSymlinkRequest new];
    getSymlinkRequest.bucketName = _publicBucketName;
    getSymlinkRequest.objectKey = @"test-symlink-objectName";
    
    InspurOSSTask * getSymlinktask = [_client getSymlink:getSymlinkRequest];
    
    [[getSymlinktask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetSymlinkResult *result = (InspurOSSGetSymlinkResult *)task.result;
        NSString *targetObjectName = (NSString *)[result.httpResponseHeaderFields valueForKey:InspurOSSHttpHeaderSymlinkTarget];
        NSString *metaLocation = (NSString *)[result.httpResponseHeaderFields valueForKey:@"x-oss-meta-location"];
        
        XCTAssertTrue([targetObjectName isEqualToString:@"test-symlink-targetObjectName"]);
        XCTAssertTrue([metaLocation isEqualToString:@"HONGKONG"]);
        
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_restoreObject {
    NSString *bucketName = @"aliyun-oss-ios-restore-object-test";
    NSString *objectName = @"test-restore-objectName";
    
    InspurOSSCreateBucketRequest *createBucketRequest = [InspurOSSCreateBucketRequest new];
    createBucketRequest.bucketName = bucketName;
    createBucketRequest.storageClass = InspurOSSBucketStorageClassArchive;
    [[_client createBucket:createBucketRequest] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[2]];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * putObjectRequest = [InspurOSSPutObjectRequest new];
    putObjectRequest.bucketName = bucketName;
    putObjectRequest.objectKey = objectName;
    putObjectRequest.uploadingFileURL = fileURL;
    putObjectRequest.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:objectName, @"x-oss-meta-name", nil];
    
    InspurOSSTask * task = [_client putObject:putObjectRequest];
    [task waitUntilFinished];
    
    InspurOSSRestoreObjectRequest * restoreObjectRequest = [InspurOSSRestoreObjectRequest new];
    restoreObjectRequest.bucketName = bucketName;
    restoreObjectRequest.objectKey = objectName;
    
    InspurOSSTask * restoreObjecTtask = [_client restoreObject:restoreObjectRequest];
    [[restoreObjecTtask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSRestoreObjectResult *result = (InspurOSSRestoreObjectResult *)task.result;
        XCTAssertEqual(result.httpResponseCode, 202);
        
        return nil;
    }] waitUntilFinished];
    
    InspurOSSTask * restoreObjectTask1 = [_client restoreObject:restoreObjectRequest];
    [[restoreObjectTask1 continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucketName with:_client];
}

#pragma mark - Tagging

- (void)testAPI_put_tagging {
    NSDictionary *tags = @{@"key1":@"value1", @"key2":@"value2"};
    InspurOSSPutObjectTaggingRequest *putTaggingRequest = [InspurOSSPutObjectTaggingRequest new];
    putTaggingRequest.bucketName = _privateBucketName;
    putTaggingRequest.objectKey = OSS_IMAGE_KEY;
    putTaggingRequest.tags = tags;
    [[[_client putObjectTagging:putTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSGetObjectTaggingRequest *getTaggingRequest = [InspurOSSGetObjectTaggingRequest new];
    getTaggingRequest.bucketName = _privateBucketName;
    getTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client getObjectTagging:getTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectTaggingResult *result = task.result;
        for (NSString *key in [tags allKeys]) {
            XCTAssertTrue([tags[key] isEqualToString:result.tags[key]]);
        }
        return nil;
    }] waitUntilFinished];
    
    InspurOSSDeleteObjectTaggingRequest *deleteTaggingRequest = [InspurOSSDeleteObjectTaggingRequest new];
    deleteTaggingRequest.bucketName = _privateBucketName;
    deleteTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client deleteObjectTagging:deleteTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    getTaggingRequest = [InspurOSSGetObjectTaggingRequest new];
    getTaggingRequest.bucketName = _privateBucketName;
    getTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client getObjectTagging:getTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectTaggingResult *result = task.result;
        XCTAssertTrue([[result.tags allKeys] count] == 0);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_null_tagging {
    InspurOSSPutObjectTaggingRequest *putTaggingRequest = [InspurOSSPutObjectTaggingRequest new];
    putTaggingRequest.bucketName = _privateBucketName;
    putTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client putObjectTagging:putTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSGetObjectTaggingRequest *getTaggingRequest = [InspurOSSGetObjectTaggingRequest new];
    getTaggingRequest.bucketName = _privateBucketName;
    getTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client getObjectTagging:getTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectTaggingResult *result = task.result;
        XCTAssertTrue([[result.tags allKeys] count] == 0);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSDeleteObjectTaggingRequest *deleteTaggingRequest = [InspurOSSDeleteObjectTaggingRequest new];
    deleteTaggingRequest.bucketName = _privateBucketName;
    deleteTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client deleteObjectTagging:deleteTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
}

- (void)testAPI_deleteNotExistObjectTagging {
    InspurOSSDeleteObjectTaggingRequest *deleteTaggingRequest = [InspurOSSDeleteObjectTaggingRequest new];
    deleteTaggingRequest.bucketName = _privateBucketName;
    deleteTaggingRequest.objectKey = OSS_IMAGE_KEY;
    [[[_client deleteObjectTagging:deleteTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    deleteTaggingRequest = [InspurOSSDeleteObjectTaggingRequest new];
    deleteTaggingRequest.bucketName = _privateBucketName;
    deleteTaggingRequest.objectKey = @"existObject";
    [[[_client deleteObjectTagging:deleteTaggingRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, -404);
        return nil;
    }] waitUntilFinished];
}


#pragma mark - others

- (void)testAPI_get_Bucket_list_Objects
{
    NSString * bucket = @"test-chenli3";
    InspurOSSCreateBucketRequest *req = [InspurOSSCreateBucketRequest new];
    req.bucketName = bucket;
    [[_client createBucket:req] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[0]];
    InspurOSSPutObjectRequest * put = [InspurOSSPutObjectRequest new];
    put.bucketName = bucket;
    put.objectKey = _fileNames[0];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    put.uploadingData = [readFile readDataToEndOfFile];
    [[_client putObject:put] waitUntilFinished];
    
    InspurOSSGetBucketRequest * request = [InspurOSSGetBucketRequest new];
    request.bucketName = bucket;
    request.delimiter = @"";
    request.marker = @"";
    request.maxKeys = 1000;
    request.prefix = @"";
    
    InspurOSSTask * task = [_client getBucket:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    request = [InspurOSSGetBucketRequest new];
    request.bucketName = bucket;
    request.delimiter = @"";
    request.marker = @"";
    request.maxKeys = 2;
    request.prefix = @"";
    
    task = [_client getBucket:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    request = [InspurOSSGetBucketRequest new];
    request.bucketName = bucket;
    request.prefix = @"fileDir";
    request.delimiter = @"/";
    
    task = [_client getBucket:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    [OSSTestUtils cleanBucket:bucket with:_client];
}

- (void)testAPI_headObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];
    
    InspurOSSHeadObjectRequest * request = [InspurOSSHeadObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = _fileNames[3];
    
    InspurOSSTask * task = [_client headObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_doesObjectExistWithExistObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_privateBucketName objectKey:_fileNames[3] error:&error];
    XCTAssertEqual(isExist, YES);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithNoExistObject
{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:_privateBucketName objectKey:@"wrong-key" error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNil(error);
}

- (void)testAPI_doesObjectExistWithError
{
    NSError * error = nil;
    // invalid credentialProvider
    id<InspurOSSCredentialProvider> c = [[InspurOSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"" secretKey:@""];
    InspurOSSClient * tClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:c];
    BOOL isExist = [tClient doesObjectExistInBucket:_privateBucketName objectKey:_fileNames[3] error:&error];
    XCTAssertEqual(isExist, NO);
    XCTAssertNotNil(error);
}

- (void)testAPI_copyAndDeleteObject
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSHeadObjectRequest * head = [InspurOSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"file1m_copyTo";
    InspurOSSTask * task = [_client headObject:head];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSCopyObjectRequest * copy = [InspurOSSCopyObjectRequest new];
    copy.bucketName = _privateBucketName;
    copy.objectKey = @"file1m_copyTo";
    copy.sourceCopyFrom = [NSString stringWithFormat:@"/%@/%@", _privateBucketName, _fileNames[3]];
    task = [_client copyObject:copy];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSDeleteObjectRequest * delete = [InspurOSSDeleteObjectRequest new];
    delete.bucketName = _privateBucketName;
    delete.objectKey = @"file1m_copyTo";
    task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_copyObjectWithZhongWenAndDeleteObject
{
    NSString *objectKey = @"中文";
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file1m"];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    InspurOSSTask * putTask = [_client putObject:request];
    [putTask waitUntilFinished];
    
    InspurOSSHeadObjectRequest * head = [InspurOSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = @"中文_copyTo";
    InspurOSSTask * headTask = [_client headObject:head];
    [[headTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-404, task.error.code);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSCopyObjectRequest * copy = [InspurOSSCopyObjectRequest new];
    copy.bucketName = _privateBucketName;
    copy.objectKey = @"中文_copyTo";
    copy.sourceBucketName = _privateBucketName;
    copy.sourceObjectKey = objectKey;
    InspurOSSTask *cpTask = [_client copyObject:copy];
    [[cpTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    InspurOSSDeleteObjectRequest * delete = [InspurOSSDeleteObjectRequest new];
    delete.bucketName = _privateBucketName;
    delete.objectKey = @"中文_copyTo";
    InspurOSSTask *dTask = [_client deleteObject:delete];
    [[dTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSDeleteObjectResult * result = task.result;
        XCTAssertEqual(204, result.httpResponseCode);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_DeleteMultipleObjects {
    InspurOSSDeleteMultipleObjectsRequest *request = [InspurOSSDeleteMultipleObjectsRequest new];
    request.bucketName = _publicBucketName;
    request.keys = @[@"file1k",@"file10k",@"file100k",@"file1m"];
    request.encodingType = @"url";
    
    InspurOSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(t.error);

        return nil;
    }] waitUntilFinished];
    
}

#pragma mark - retry operations
- (void)testAPI_PutObjectWithErrorRetry
{
    [NSDate oss_setClockSkew: 30 * 60];
    NSString *fileName = _fileNames[0];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    NSError *readError;
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    
    XCTAssertNil(readError);
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = fileName;
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [InspurOSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    request.uploadRetryCallback = ^{
        NSLog(@"put object call retry");
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);

    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:fileName
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_timeSkewedButAutoRetry
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_privateBucketName];
    
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    [NSDate oss_setClockSkew: 30 * 60];
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
}

#pragma mark - md5 check

- (void)testAPI_putObjectWithCheckingDataMd5
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = _fileNames[3];
    
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:_fileNames[3]]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.contentMd5 = [InspurOSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectWithCheckingFileMd5
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = _fileNames[3];
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:_fileNames[3]]];
    
    request.uploadingFileURL = fileURL;
    request.contentMd5 = [InspurOSSUtil base64Md5ForFilePath:fileURL.path];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectWithInvalidMd5
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _publicBucketName;
    request.isAuthenticationRequired = NO;
    request.objectKey = @"file1m";
    request.contentType = @"application/octet-stream";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    request.contentMd5 = @"invliadmd5valuetotest";
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
         NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(-1 * 400, task.error.code);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_customExcludeCname
{
    [OSSTestUtils putTestDataWithKey:_fileNames[3] withClient:_client withBucket:_publicBucketName];

    InspurOSSClientConfiguration * conf = [InspurOSSClientConfiguration new];
    conf.cnameExcludeList = @[@"oss-cn-hangzhou.aliyuncs.com", @"vpc.sample.com"];
    id<InspurOSSCredentialProvider> provider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];

    InspurOSSClient * tClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT
                                           credentialProvider:provider
                                          clientConfiguration:conf];

    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _publicBucketName;
    request.objectKey = @"file1m";

    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };

    InspurOSSTask * task = [tClient getObject:request];

    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSGetObjectResult * result = task.result;
        XCTAssertEqual(200, result.httpResponseCode);
        XCTAssertEqual(1024 * 1024, [result.downloadedData length]);
        XCTAssertEqualObjects(@"1048576", [result.objectMeta objectForKey:@"Content-Length"]);

        return nil;
    }] waitUntilFinished];
}

#pragma mark cancel

- (void)testAPI_cancelPutObejct
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file5m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file5m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    request.uploadingData = [readFile readDataToEndOfFile];
    
    request.contentMd5 = [InspurOSSUtil base64Md5ForData:request.uploadingData];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    __block BOOL cancelled = NO;
    InspurOSSTask * task = [_client putObject:request];
    [task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSLogError(@"error should be raised:%@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        cancelled = YES;
        return nil;
    }];

    [NSThread sleepForTimeInterval:0.1];
    [request cancel];
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(cancelled);
}

- (void)testAPI_cancelGetObject
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file5m";
    
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    __block BOOL completed = NO;
    InspurOSSTask * task = [_client getObject:request];
    
    [task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        OSSLogError(@"error should be raise: %@", task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeTaskCancelled, task.error.code);
        completed = YES;
        return nil;
    }];
    
    [NSThread sleepForTimeInterval:0.1];
    [request cancel];
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(completed);
}

- (void)testAPI_cancelGetObjectWithNoSessionTask
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSGetObjectRequest * getRequest = [InspurOSSGetObjectRequest new];
    getRequest.bucketName = _privateBucketName;
    getRequest.objectKey = @"file5m";
    InspurOSSTask * getTask = [_client getObject:getRequest];
    [getTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, InspurOSSClientErrorCodeTaskCancelled);
        [tcs setResult:nil];
        return nil;
    }];
    [getRequest cancel];
    [tcs.task waitUntilFinished];
}

- (void)testAPI_cancelGetObjectAndContinue
{
    [OSSTestUtils putTestDataWithKey:@"file5m" withClient:_client withBucket:_privateBucketName];
    
    InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSGetObjectRequest * getRequest = [InspurOSSGetObjectRequest new];
    getRequest.bucketName = _privateBucketName;
    getRequest.objectKey = @"file5m";
    InspurOSSTask * getTask = [_client getObject:getRequest];
    [getTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(task.error.code, InspurOSSClientErrorCodeTaskCancelled);
        [tcs setResult:nil];
        return nil;
    }];
    [getRequest cancel];
    [tcs.task waitUntilFinished];
    InspurOSSTask * getTaskAgain = [_client getObject:getRequest];
    [getTaskAgain waitUntilFinished];
    XCTAssertNil(getTaskAgain.error);
}

#pragma mark - exceptional tests

- (void)testAPI_DeleteMultipleObjects_withoutBucketName {
    InspurOSSDeleteMultipleObjectsRequest *request = [InspurOSSDeleteMultipleObjectsRequest new];
    request.keys = @[@"file1k",@"file10k",@"file100k",@"file1m"];
    request.encodingType = @"url";
    
    InspurOSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        
        return nil;
    }] waitUntilFinished];
    
}

- (void)testAPI_DeleteMultipleObjects_withoutKeys {
    InspurOSSDeleteMultipleObjectsRequest *request = [InspurOSSDeleteMultipleObjectsRequest new];
    request.bucketName = OSS_BUCKET_PRIVATE;
    request.encodingType = @"url";
    
    InspurOSSTask *task = [_client deleteMultipleObjects:request];
    [[task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        
        return nil;
    }] waitUntilFinished];
    
}

- (void)testAPI_getObjectWithServerErrorNotExistObject
{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"not_exist_ttt";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([InspurOSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithServerErrorNotExistBucket
{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = @"not-exist-bucket-dfadsfd";
    request.objectKey = @"file1m";
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([InspurOSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 404, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfInvalidBucketName
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = @"-invalid_bucket";
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectWithErrorOfInvalidKey
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"/file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    
    request.uploadingFileURL = fileURL;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertEqual(InspurOSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_getObjectWithErrorOfAccessDenied
{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([InspurOSSServerErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(-1 * 403, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_getObjectWithErrorOfInvalidParam
{
    InspurOSSGetObjectRequest * request = [InspurOSSGetObjectRequest new];
    request.objectKey = @"file1m";
    request.isAuthenticationRequired = NO;
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    InspurOSSTask * task = [_client getObject:request];
    
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([InspurOSSClientErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(InspurOSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testAPI_putObjectWithErrorOfNoSource
{
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [_client putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        XCTAssertTrue([InspurOSSClientErrorDomain isEqualToString:task.error.domain]);
        XCTAssertEqual(InspurOSSClientErrorCodeInvalidArgument, task.error.code);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_putObjectWithErrorOfNoCredentialProvier
{
    InspurOSSClient * tempClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:nil];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file1m";
    
    NSString * docDir = [NSString oss_documentDirectory];
    NSURL * fileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    NSFileHandle * readFile = [NSFileHandle fileHandleForReadingFromURL:fileURL error:nil];
    
    request.uploadingData = [readFile readDataToEndOfFile];
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    
    InspurOSSTask * task = [tempClient putObject:request];
    [[task continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
        XCTAssertEqualObjects(InspurOSSClientErrorDomain, task.error.domain);
    }] waitUntilFinished];
    
    task = [tempClient presignConstrainURLWithBucketName:_privateBucketName withObjectKey:@"file1m" withExpirationInterval:3600];
    [task waitUntilFinished];
    XCTAssertTrue([InspurOSSClientErrorDomain isEqualToString:task.error.domain]);
    XCTAssertTrue([progressTest completeValidateProgress]);
}

#pragma mark - cname
- (void)testAPI_cnameUrlCheck
{
    id<InspurOSSCredentialProvider> provider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient * tClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_CNAME_URL
                                           credentialProvider:provider];
    InspurOSSTask * tk = [tClient presignConstrainURLWithBucketName:_privateBucketName
                                 withObjectKey:@"file1k"
                        withExpirationInterval:30 * 60];
    [tk waitUntilFinished];
    XCTAssertNotNil(tk.result);
    XCTAssertTrue([tk.result hasPrefix:OSS_CNAME_URL]);
}

#pragma mark - presign

- (void)testAPI_presignConstrainURL
{
    InspurOSSTask * tk = [_client presignConstrainURLWithBucketName:_privateBucketName
                                               withObjectKey:@"file1k"
                                      withExpirationInterval:30 * 60];
    XCTAssertNil(tk.error);
}

- (void)testAPI_presignPublicURL
{
    InspurOSSTask * task = [_client presignPublicURLWithBucketName:_publicBucketName withObjectKey:@"file1m"];
    XCTAssertNil(task.error);
}

- (void)testAPI_PresignImageConstrainURL
{
    InspurOSSTask * tk = [_client presignConstrainURLWithBucketName:_privateBucketName
                                                withObjectKey:@"hasky.jpeg"
                                       withExpirationInterval:30 * 60
                                               withParameters:@{@"x-oss-process": @"image/resize,w_50"}];
    XCTAssertNil(tk.error);
}

- (void)testAPI_PublicImageURL
{
    InspurOSSTask * task = [_client presignPublicURLWithBucketName:_publicBucketName
                                              withObjectKey:@"hasky.jpeg"
                                             withParameters:@{@"x-oss-process": @"image/resize,w_50"}];
    XCTAssertNil(task.error);
}

- (void)testAPI_presignConstrainURLWithDefaultConfig {
    
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignConstrainURLWithPathStyleConfig {
    
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[CNAME_ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    urlString = [NSString stringWithFormat:@"%@%@/%@/%@", SCHEME, CNAME_ENDPOINT, BUCKET_NAME, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
}

- (void)testAPI_presignConstrainURLWithCname {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.cnameExcludeList = @[CNAME_ENDPOINT];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignConstrainURLWithCustomPath {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.isCustomPathPrefixEnable = YES;
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:CUSTOMPATH(ENDPOINT) credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, CUSTOMPATH(ENDPOINT), OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignConstrainURLWithIpEndpoint {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:[@"http://" stringByAppendingString:IP_ENDPOINT] credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignConstrainURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY
                                      withExpirationInterval:30 * 60];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@/%@", IP_ENDPOINT, BUCKET_NAME, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}


- (void)testAPI_presignPublicURLWithDefaultConfig {
    
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignPublicURLWithPathStyleConfig {
    
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[CNAME_ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    urlString = [NSString stringWithFormat:@"%@%@/%@/%@", SCHEME, CNAME_ENDPOINT, BUCKET_NAME, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
}

- (void)testAPI_presignPublicURLWithCname {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.cnameExcludeList = @[CNAME_ENDPOINT];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
    
    config = [InspurOSSClientConfiguration new];
    config.isPathStyleAccessEnable = YES;
    config.cnameExcludeList = @[ENDPOINT];
    authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    client = [[InspurOSSClient alloc] initWithEndpoint:CNAME_ENDPOINT credentialProvider:authProv clientConfiguration:config];
    tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    urlString = [NSString stringWithFormat:@"%@%@/%@", SCHEME, CNAME_ENDPOINT, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignPublicURLWithCustomPath {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.isCustomPathPrefixEnable = YES;
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:CUSTOMPATH(ENDPOINT) credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    NSString *urlString = [NSString stringWithFormat:@"%@%@.%@/%@", SCHEME, BUCKET_NAME, CUSTOMPATH(ENDPOINT), OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignPublicURLWithIpEndpoint {
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    InspurOSSAuthCredentialProvider *authProv = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:[@"http://" stringByAppendingString:IP_ENDPOINT] credentialProvider:authProv clientConfiguration:config];
    InspurOSSTask * tk = [client presignPublicURLWithBucketName:BUCKET_NAME
                                               withObjectKey:OBJECT_KEY];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/%@/%@", IP_ENDPOINT, BUCKET_NAME, OBJECT_KEY];
    XCTAssertTrue([tk.result hasPrefix:urlString]);
}

- (void)testAPI_presignURLToPutObject {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[3]];
    NSString *bucketName = _privateBucketName;
    NSString *objectKey = OBJECT_KEY;
    NSString *method = @"PUT";
    NSString *contentType = @"image/png";
    NSString *contentMd5 = [InspurOSSUtil base64Md5ForFilePath:filePath];

    InspurOSSTask *task = [_client presignConstrainURLWithBucketName:bucketName
                                                 withObjectKey:objectKey
                                                    httpMethod:method
                                        withExpirationInterval:30 * 60
                                                withParameters:@{}
                                                   contentType:contentType
                                                    contentMd5:contentMd5];

    NSString *url = task.result;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;
    [request setValue:contentType forHTTPHeaderField:InspurOSSHttpHeaderContentType];
    [request setValue:contentMd5 forHTTPHeaderField:InspurHttpHeaderContentMD5];
    NSURLSession *session = [NSURLSession sharedSession];
    InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    NSURLSessionTask *sesstionTask = [session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:filePath] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResoponse = (NSHTTPURLResponse *)response;
        if (!error && httpResoponse.statusCode == 200) {
            NSLog(@"上传成功");
            [tcs setError:error];
        } else {
            NSLog(@"上传失败 \n%@ \n%@", error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [tcs setResult:data];
        }
    }];
    [sesstionTask resume];
    [tcs.task waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:OBJECT_KEY
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}

- (void)testAPI_presignURLWithHeaderTypeToPutObject {
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:_fileNames[3]];
    NSString *bucketName = _privateBucketName;
    NSString *objectKey = OBJECT_KEY;
    NSString *method = @"PUT";
    NSString *contentType = @"image/png";
    NSString *contentMd5 = [InspurOSSUtil base64Md5ForFilePath:filePath];
    NSDictionary *headers = @{@"x-oss-meta-text-key": @"test-value",
                              InspurOSSHttpHeaderContentType: contentType,
                              InspurHttpHeaderContentMD5: contentMd5};

    InspurOSSTask *task = [_client presignConstrainURLWithBucketName:bucketName
                                                 withObjectKey:objectKey
                                                    httpMethod:method
                                        withExpirationInterval:30 * 60
                                                withParameters:@{}
                                                   withHeaders:headers];

    NSString *url = task.result;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = method;
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:contentMd5 forHTTPHeaderField:InspurHttpHeaderContentMD5];
    [request setValue:@"test-value" forHTTPHeaderField:@"x-oss-meta-text-key"];
    NSURLSession *session = [NSURLSession sharedSession];
    InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    NSURLSessionTask *sesstionTask = [session uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:filePath] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResoponse = (NSHTTPURLResponse *)response;
        if (!error && httpResoponse.statusCode == 200) {
            NSLog(@"上传成功");
            [tcs setError:error];
        } else {
            NSLog(@"上传失败 \n%@ \n%@", error, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [tcs setResult:data];
        }
    }];
    [sesstionTask resume];
    [tcs.task waitUntilFinished];
    
    InspurOSSHeadObjectRequest * head = [InspurOSSHeadObjectRequest new];
    head.bucketName = _privateBucketName;
    head.objectKey = OBJECT_KEY;
    [[[_client headObject:head] continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        InspurOSSHeadObjectResult * headResult = task.result;
        [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if (![key isEqualToString:InspurHttpHeaderContentMD5]) {
                XCTAssertTrue([[headResult.objectMeta objectForKey:key] isEqualToString:obj]);
            }
        }];
        return nil;
    }] waitUntilFinished];
    
    BOOL isEqual = [self checkMd5WithBucketName:_privateBucketName
                                      objectKey:OBJECT_KEY
                                  localFilePath:filePath];
    XCTAssertTrue(isEqual);
}


#pragma mark - utils

- (BOOL)checkMd5WithBucketName:(nonnull NSString *)bucketName objectKey:(nonnull NSString *)objectKey localFilePath:(nonnull NSString *)filePath
{
    NSString * tempFile = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"tempfile_for_check"];
    
    InspurOSSGetObjectRequest * get = [InspurOSSGetObjectRequest new];
    get.bucketName = bucketName;
    get.objectKey = objectKey;
    get.downloadToFileURL = [NSURL fileURLWithPath:tempFile];
    [[[_client getObject:get] continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    
    NSString *remoteMD5 = [InspurOSSUtil fileMD5String:tempFile];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempFile
                                                   error:nil];
    }
    
    NSString *localMD5 = [InspurOSSUtil fileMD5String:filePath];
    return [remoteMD5 isEqualToString:localMD5];
}

- (void)testAPI_multipartRequestWithoutUploadingURL {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_multipartRequest_concurrently {
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 5;
    
    for (int pIndex = 0; pIndex < 5; pIndex++) {
        InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
        multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        multipartUploadRequest.bucketName = _privateBucketName;
        multipartUploadRequest.objectKey = [NSString stringWithFormat:@"multipart-concurrently-%d", pIndex];
        multipartUploadRequest.contentType = @"application/octet-stream";
        multipartUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:[[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file5m"]];
        multipartUploadRequest.partSize = 256 * 1024;
        OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
        multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            XCTAssertTrue(totalBytesExpectedToSend >= totalByteSent);
            [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
       };
        
        [queue addOperationWithBlock:^{
            InspurOSSTask * task = [_client multipartUpload:multipartUploadRequest];
            [task waitUntilFinished];
            XCTAssertNotNil(task.result);
            XCTAssertTrue([progressTest completeValidateProgress]);
        }];
    }
    [queue waitUntilAllOperationsAreFinished];
}

- (void)testAPI_multipartRequestWithWrongFileURL {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        XCTAssertTrue(totalByteSent <= totalBytesExpectedToSend);
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    multipartUploadRequest.uploadingFileURL = [NSURL URLWithString:@"http://www.alibaba-inc.com"];
    
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        NSLog(@"Error: %@", task.error);
        
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_multipartRequestWithUnexistFileURL {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    NSString * docDir = [NSString oss_documentDirectory];
    multipartUploadRequest.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"unexistfile"]];
    
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_multipartRequestWithoutPartSize {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNil(task.error);
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_multipartRequestWithoutObjectKey {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.bucketName = _privateBucketName;
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_multipartRequestWithoutBucketName {
    InspurOSSMultipartUploadRequest * multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    multipartUploadRequest.contentType = @"application/octet-stream";
    multipartUploadRequest.objectKey = OSS_MULTIPART_UPLOADKEY;
    multipartUploadRequest.partSize = 1024 * 1024;
    multipartUploadRequest.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    OSSProgressTestUtils *progressTest = [OSSProgressTestUtils new];
    multipartUploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [progressTest updateTotalBytes:totalByteSent totalBytesExpected:totalBytesExpectedToSend];
    };
    InspurOSSTask * multipartTask = [_client multipartUpload:multipartUploadRequest];
    
    [[multipartTask continueWithBlock:^id(InspurOSSTask *task) {
        XCTAssertNotNil(task.error);
        
        return nil;
    }] waitUntilFinished];
    XCTAssertTrue([progressTest completeValidateProgress]);
}

- (void)testAPI_dataTaskAndUploadTaskSimultaneously {
    [OSSTestUtils putTestDataWithKey:@"file10k" withClient:_client withBucket:_privateBucketName];
    
    InspurOSSPutObjectRequest *putObjectRequest = [InspurOSSPutObjectRequest new];
    putObjectRequest.bucketName = _privateBucketName;
    putObjectRequest.objectKey = @"test-bucket";
    putObjectRequest.uploadingFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"xml"]];
    
    InspurOSSHeadObjectRequest *headObjectRequest = [InspurOSSHeadObjectRequest new];
    headObjectRequest.bucketName = _privateBucketName;
    headObjectRequest.objectKey = @"file10k";
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_group_enter(group);
    
    [[_specialClient putObject:putObjectRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    [[_specialClient headObject:headObjectRequest] continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        XCTAssertNil(task.error);
        dispatch_group_leave(group);
        return nil;
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    XCTAssertTrue(YES);
}

- (void)testAPI_multipartUploadWithFileSizeLessThan100k {
    InspurOSSMultipartUploadRequest *request = [InspurOSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.bucketName = _privateBucketName;
    request.objectKey = @"file10k";
    
    InspurOSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_multipartUploadWithPartSizeLessThan100k {
    InspurOSSMultipartUploadRequest *request = [InspurOSSMultipartUploadRequest new];
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"wangwang" withExtension:@"zip"];
    request.uploadingFileURL = fileURL;
    request.partSize = 51200;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    InspurOSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

- (void)testAPI_multipartUploadWithFileAndPartSizeLessThan100k {
    InspurOSSMultipartUploadRequest *request = [InspurOSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.partSize = 51200;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    InspurOSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
}

- (void)testAPI_multipartUploadWithPartSizeEqualToZero {
    InspurOSSMultipartUploadRequest *request = [InspurOSSMultipartUploadRequest new];
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file10k"];
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.partSize = 0;
    request.bucketName = _privateBucketName;
    request.objectKey = @"test-part-size-less-than-100k";
    
    InspurOSSTask *task = [_client multipartUpload:request];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

- (void)testAPI_putObjectWithEmptyFile {
    InspurOSSPutObjectRequest *req = [InspurOSSPutObjectRequest new];
    req.bucketName = OSS_BUCKET_PUBLIC;
    req.objectKey = @"test-empty-file";
    req.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"empty-file" withExtension:nil];
    
    InspurOSSTask *task = [_client putObject:req];
    [task waitUntilFinished];
    
    XCTAssertNotNil(task.error);
}

- (void)testAPI_judgePartSize {
    NSInteger partSize = 100 * 1024;
    NSInteger fileSize = partSize * 5001;
    InspurOSSMultipartUploadRequest *multipartUploadRequest = [InspurOSSMultipartUploadRequest new];
    multipartUploadRequest.partSize = partSize;
    
    NSInteger partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    NSInteger expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(0, multipartUploadRequest.partSize % (4 * 1024));

    fileSize = partSize * 5000;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(5000, expectPartCount);

    fileSize = partSize * 4999;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(4999, expectPartCount);

    fileSize = partSize * 1 + 1;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(2, expectPartCount);
    
    fileSize = partSize * 1;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(1, expectPartCount);

    fileSize = 1;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(1, expectPartCount);
    
    
    fileSize = 200 * 1024 * 4999;
    multipartUploadRequest.partSize = partSize;
    partCount = [_client judgePartSizeForMultipartRequest:multipartUploadRequest fileSize:fileSize];
    expectPartCount = fileSize / multipartUploadRequest.partSize;
    expectPartCount += fileSize % multipartUploadRequest.partSize > 0 ? 1 : 0;
    XCTAssertEqual(partCount, expectPartCount);
    XCTAssertEqual(4999, expectPartCount);
}

- (void)testAPI_ceilPartSize {
    
    NSUInteger partSizeAlign = 4 * 1024;
    NSUInteger partSize = 1;
    partSize = [_client ceilPartSize:partSize];
    XCTAssertEqual(partSizeAlign, partSize);

    partSize = 4 * 1024;
    partSize = [_client ceilPartSize:partSize];
    XCTAssertEqual(partSizeAlign, partSize);

    partSize = 4 * 1024 + 1;
    partSize = [_client ceilPartSize:partSize];
    XCTAssertEqual(partSizeAlign * 2, partSize);
}

- (void)testAPI_image {
    NSString * url =  [_client.imageProcess getURL:@"key" bucket:@"bucket" process:^(InspurImageAttributeMaker * _Nonnull maker) {
        maker.rotato(30).flip(InspurImageFlipHorizontal);
    }];
    NSLog(@"url:%@", url);
    XCTAssertNotNil(url);
}

- (void)testAPI_averageHue {
    NSString *bucket = @"test-chenli3";
    NSString *key = @"ceshi.png";
    __block BOOL wait = YES;
    [_client.imageProcess averageHue:key
                              bucket:bucket
                          completion:^(id  _Nullable obj, NSError * _Nullable error) {
        NSLog(@"obj:%@", obj);
        XCTAssertNotNil(obj);
        wait = NO;
    }];
    
    while (wait) {
        [NSThread sleepForTimeInterval:0.1];
    };
}

- (void)testAPI_exInfo {
    NSString *bucket = @"test-chenli3";
    NSString *key = @"ceshi.png";
    __block BOOL wait = YES;
    [_client.imageProcess exifInfo:key
                            bucket:bucket
                        completion:^(id  _Nullable obj, NSError * _Nullable error) {
        NSLog(@"obj:%@", obj);
        XCTAssertNotNil(obj);
        wait = NO;
    }];
    
    while (wait) {
        [NSThread sleepForTimeInterval:0.1];
    };
}


- (NSString *)getRecordFilePath:(InspurOSSResumableUploadRequest *)resumableUpload {
    NSString *recordPathMd5 = [InspurOSSUtil fileMD5String:[resumableUpload.uploadingFileURL path]];
    NSData *data = [[NSString stringWithFormat:@"%@%@%@%lu",recordPathMd5, resumableUpload.bucketName, resumableUpload.objectKey, resumableUpload.partSize] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *recordFileName = [InspurOSSUtil dataMD5String:data];
    NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",resumableUpload.recordDirectoryPath,recordFileName];
    return recordFilePath;
}

@end
