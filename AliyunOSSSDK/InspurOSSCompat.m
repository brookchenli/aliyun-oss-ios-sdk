//
//  OSSCompat.m
//  oss_ios_sdk_new
//
//  Created by xx on 9/10/15.
//  Copyright (c) 2022 Inspur. All rights reserved.
//

#import "InspurOSSDefine.h"
#import "InspurOSSCompat.h"
#import "OSSBolts.h"
#import "OSSModel.h"

@implementation InspurOSSClient (Compat)

- (OSSTaskHandler *)uploadData:(NSData *)data
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void(^)(BOOL, NSError *))onCompleted
                    onProgress:(void(^)(float progress))onProgress {

    OSSTaskHandler * bcts = [InspurOSSCancellationTokenSource cancellationTokenSource];

    [[[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withSuccessBlock:^id(InspurOSSTask *task) {
        InspurOSSPutObjectRequest * put = [InspurOSSPutObjectRequest new];
        put.bucketName = bucketName;
        put.objectKey = objectKey;
        put.objectMeta = meta;
        put.uploadingData = data;
        put.contentType = contentType;

        put.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            if (totalBytesExpectedToSend) {
                onProgress((float)totalBytesSent / totalBytesExpectedToSend);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [put cancel];
        }];

        InspurOSSTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (OSSTaskHandler *)downloadToDataFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                               onCompleted:(void (^)(NSData *, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [InspurOSSCancellationTokenSource cancellationTokenSource];

    [[[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(InspurOSSTask *task) {
        InspurOSSGetObjectRequest * get = [InspurOSSGetObjectRequest new];
        get.bucketName = bucketName;
        get.objectKey = objectKey;

        get.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if (totalBytesExpectedToWrite) {
                onProgress((float)totalBytesWritten / totalBytesExpectedToWrite);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [get cancel];
        }];

        InspurOSSTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.error) {
            onCompleted(nil, task.error);
        } else {
            InspurOSSGetObjectResult * result = task.result;
            onCompleted(result.downloadedData, nil);
        }
        return nil;
    }];

    return bcts;
}

- (OSSTaskHandler *)downloadToFileFromBucket:(NSString *)bucketName
                                 objectKey:(NSString *)objectKey
                                    toFile:(NSString *)filePath
                               onCompleted:(void (^)(BOOL, NSError *))onCompleted
                                onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [InspurOSSCancellationTokenSource cancellationTokenSource];

    [[[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(InspurOSSTask *task) {
        InspurOSSGetObjectRequest * get = [InspurOSSGetObjectRequest new];
        get.bucketName = bucketName;
        get.objectKey = objectKey;
        get.downloadToFileURL = [NSURL fileURLWithPath:filePath];

        get.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if (totalBytesExpectedToWrite) {
                onProgress((float)totalBytesWritten / totalBytesExpectedToWrite);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [get cancel];
        }];

        InspurOSSTask * getTask = [self getObject:get];
        [getTask waitUntilFinished];
        onProgress(1.0f);
        return getTask;
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    
    return bcts;
}

- (void)deleteObjectInBucket:(NSString *)bucketName
                   objectKey:(NSString *)objectKey
                 onCompleted:(void (^)(BOOL, NSError *))onCompleted {

    [[[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(InspurOSSTask *task) {
        InspurOSSDeleteObjectRequest * delete = [InspurOSSDeleteObjectRequest new];
        delete.bucketName = bucketName;
        delete.objectKey = objectKey;

        InspurOSSTask * deleteTask = [self deleteObject:delete];
        [deleteTask waitUntilFinished];
        return deleteTask;
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
}

- (OSSTaskHandler *)uploadFile:(NSString *)filePath
               withContentType:(NSString *)contentType
                withObjectMeta:(NSDictionary *)meta
                  toBucketName:(NSString *)bucketName
                   toObjectKey:(NSString *)objectKey
                   onCompleted:(void (^)(BOOL, NSError *))onCompleted
                    onProgress:(void (^)(float))onProgress {

    OSSTaskHandler * bcts = [InspurOSSCancellationTokenSource cancellationTokenSource];

    [[[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withSuccessBlock:^id(InspurOSSTask *task) {
        InspurOSSPutObjectRequest * put = [InspurOSSPutObjectRequest new];
        put.bucketName = bucketName;
        put.objectKey = objectKey;
        put.objectMeta = meta;
        put.uploadingFileURL = [NSURL fileURLWithPath:filePath];
        put.contentType = contentType;

        put.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            if (totalBytesExpectedToSend) {
                onProgress((float)totalBytesSent / totalBytesExpectedToSend);
            }
        };

        [bcts.token registerCancellationObserverWithBlock:^{
            [put cancel];
        }];

        InspurOSSTask * putTask = [self putObject:put];
        [putTask waitUntilFinished];
        onProgress(1.0f);
        return putTask;
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.error) {
            onCompleted(NO, task.error);
        } else {
            onCompleted(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

- (OSSTaskHandler *)resumableUploadFile:(NSString *)filePath
                        withContentType:(NSString *)contentType
                         withObjectMeta:(NSDictionary *)meta
                           toBucketName:(NSString *)bucketName
                            toObjectKey:(NSString *)objectKey
                            onCompleted:(void(^)(BOOL, NSError *))onComplete
                             onProgress:(void(^)(float progress))onProgress {

    OSSTaskHandler * bcts = [InspurOSSCancellationTokenSource cancellationTokenSource];

    [[[InspurOSSTask taskWithResult:nil] continueWithBlock:^id(InspurOSSTask *task) {
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        NSDate * lastModified;
        NSError * error;
        [fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
        if (error) {
            return [InspurOSSTask taskWithError:error];
        }
        InspurOSSResumableUploadRequest * resumableUpload = [InspurOSSResumableUploadRequest new];
        resumableUpload.bucketName = bucketName;
        resumableUpload.deleteUploadIdOnCancelling = NO;//cancel not delete record file
        resumableUpload.contentType = contentType;
        resumableUpload.completeMetaHeader = meta;
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        resumableUpload.recordDirectoryPath = cachesDir; //default record file path
        resumableUpload.uploadingFileURL = fileURL;
        resumableUpload.objectKey = objectKey;
        resumableUpload.uploadId = task.result;
        resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:filePath];
        __weak InspurOSSResumableUploadRequest * weakRef = resumableUpload;
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            onProgress((float)totalBytesSent/totalBytesExpectedToSend);
            if (bcts.token.isCancellationRequested || bcts.isCancellationRequested) {
                [weakRef cancel];
            }
            OSSLogDebugNoFile(@"%lld %lld %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
        };
        return [self resumableUpload:resumableUpload];
    }] continueWithBlock:^id(InspurOSSTask *task) {
        if (task.cancelled) {
            onComplete(NO, [NSError errorWithDomain:InspurOSSClientErrorDomain
                                               code:InspurOSSClientErrorCodeTaskCancelled
                                           userInfo:@{InspurOSSErrorMessageTOKEN: @"This task is cancelled"}]);
        } else if (task.error) {
            onComplete(NO, task.error);
        } else if (task.faulted) {
            onComplete(NO, [NSError errorWithDomain:InspurOSSClientErrorDomain
                                               code:InspurOSSClientErrorCodeExcpetionCatched
                                           userInfo:@{InspurOSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", task.exception]}]);
        } else {
            onComplete(YES, nil);
        }
        return nil;
    }];
    return bcts;
}

@end
