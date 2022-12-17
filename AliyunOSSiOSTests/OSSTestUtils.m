//
//  OSSTestUtils.m
//  InspurOSSiOSTests
//
//  Created by xx on 2018/2/24.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "OSSTestUtils.h"
#import <XCTest/XCTest.h>

@implementation OSSTestUtils
+ (void)cleanBucket: (NSString *)bucket with: (InspurOSSClient *)client {
    //delete object
    InspurOSSGetBucketRequest *listObject = [InspurOSSGetBucketRequest new];
    listObject.bucketName = bucket;
    listObject.maxKeys = 1000;
    InspurOSSTask *listObjectTask = [client getBucket:listObject];
    [[listObjectTask continueWithBlock:^id(InspurOSSTask * task) {
        InspurOSSGetBucketResult * listObjectResult = task.result;
        for (NSDictionary *dict in listObjectResult.contents) {
            NSString * objectKey = [dict objectForKey:@"Key"];
            NSLog(@"delete object %@", objectKey);
            InspurOSSDeleteObjectRequest * deleteObj = [InspurOSSDeleteObjectRequest new];
            deleteObj.bucketName = bucket;
            deleteObj.objectKey = objectKey;
            [[client deleteObject:deleteObj] waitUntilFinished];
        }
        return nil;
    }] waitUntilFinished];
    
    //delete multipart uploads
    InspurOSSListMultipartUploadsRequest *listMultipartUploads = [InspurOSSListMultipartUploadsRequest new];
    listMultipartUploads.bucketName = bucket;
    listMultipartUploads.maxUploads = 1000;
    InspurOSSTask *listMultipartUploadsTask = [client listMultipartUploads:listMultipartUploads];
    
    [[listMultipartUploadsTask continueWithBlock:^id(InspurOSSTask *task) {
        InspurOSSListMultipartUploadsResult * result = task.result;
        for (NSDictionary *dict in result.uploads) {
            NSString * uploadId = [dict objectForKey:@"UploadId"];
            NSString * objectKey = [dict objectForKey:@"Key"];
            NSLog(@"delete multipart uploadId %@", uploadId);
            InspurOSSAbortMultipartUploadRequest *abort = [InspurOSSAbortMultipartUploadRequest new];
            abort.bucketName = bucket;
            abort.objectKey = objectKey;
            abort.uploadId = uploadId;
            [[client abortMultipartUpload:abort] waitUntilFinished];
        }
        return nil;
    }] waitUntilFinished];
    //delete bucket
    InspurOSSDeleteBucketRequest *deleteBucket = [InspurOSSDeleteBucketRequest new];
    deleteBucket.bucketName = bucket;
    [[client deleteBucket:deleteBucket] waitUntilFinished];
}

+ (void) putTestDataWithKey: (NSString *)key withClient: (InspurOSSClient *)client withBucket: (NSString *)bucket
{
    NSString *objectKey = key;
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    InspurOSSPutObjectRequest * request = [InspurOSSPutObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    InspurOSSTask * task = [client putObject:request];
    [task waitUntilFinished];
}

@end

@interface OSSProgressTestUtils()

@property (nonatomic, assign) int64_t totalBytesSent;
@property (nonatomic, assign) int64_t totalBytesExpectedToSend;

@end

@implementation OSSProgressTestUtils

- (void)updateTotalBytes:(int64_t)totalBytesSent totalBytesExpected:(int64_t)totalBytesExpectedToSend {
    XCTAssertTrue(totalBytesSent <= totalBytesExpectedToSend);
    self.totalBytesSent = totalBytesSent;
    self.totalBytesExpectedToSend = totalBytesExpectedToSend;
}
- (BOOL)completeValidateProgress {
    return self.totalBytesSent == self.totalBytesExpectedToSend;
}

@end
