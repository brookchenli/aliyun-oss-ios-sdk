//
//  OSSAllRequestNeededMessage.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSAllRequestNeededMessage.h"

#import "InspurOSSDefine.h"
#import "InspurOSSUtil.h"

@implementation InspurOSSAllRequestNeededMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        _date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
        _headerParams = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setHeaderParams:(NSMutableDictionary *)headerParams {
    if (!headerParams || [headerParams isEqualToDictionary:_headerParams]) {
        return;
    }
    _headerParams = [headerParams mutableCopy];
}

- (InspurOSSTask *)validateRequestParamsInOperationType:(OSSOperationType)operType {
    NSString * errorMessage = nil;
    
    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }
    
    if (!self.bucketName && operType != OSSOperationTypeGetService && operType != OSSOperationTypeListService) {
        errorMessage = @"Bucket name should not be nil";
    }
    
    if (self.bucketName && ![InspurOSSUtil validateBucketName:self.bucketName]) {
        errorMessage = @"Bucket name invalid";
    }
    
    if (!self.objectKey &&
        (operType != OSSOperationTypeGetBucket && operType != OSSOperationTypeCreateBucket
         && operType != OSSOperationTypeDeleteBucket && operType != OSSOperationTypeGetService
         && operType != OSSOperationTypeGetBucketACL&& operType != OSSOperationTypeDeleteMultipleObjects
         && operType != OSSOperationTypeListMultipartUploads
         && operType != OSSOperationTypeGetBucketInfo
         && operType != OSSOperationTypeListService
         && operType != OSSOperationTypeQueryBucketExist
         && operType != OSSOperationTypeGetBucketLocation
         && operType != OSSOperationTypePutBucketACL
         && operType != OSSOperationTypeGetBucketCORS
         && operType != OSSOperationTypePutBucketCORS
         && operType != OSSOperationTypeDeleteBucketCORS
         && operType != OSSOperationTypeGetBucketVersioning
         && operType != OSSOperationTypePutBucketVersioning
         && operType != OSSOperationTypeGetBucketEncryption
         && operType != OSSOperationTypePutBucketEncryption
         && operType != OSSOperationTypeDeleteBucketEncryption
         && operType != OSSOperationTypeGetBucketWebsite
         && operType != OSSOperationTypePutBucketWebsite
         && operType != OSSOperationTypeDeleteBucketWebsite
         && operType != OSSOperationTypeGetBucketDomain
         && operType != OSSOperationTypePutBucketDomain
         && operType != OSSOperationTypeDeleteBucketDomain
         
         && operType != OSSOperationTypeGetBucketLifeCycle
         && operType != OSSOperationTypePutBucketLifeCycle
         && operType != OSSOperationTypeDeleteBucketLifeCycle
         
         && operType != OSSOperationTypeGetBucketPolicy
         && operType != OSSOperationTypePutBucketPolicy
         && operType != OSSOperationTypeDeleteBucketPolicy
         
         && operType != OSSOperationTypeGetObjectVersions
         && operType != OSSOperationTypeDeleteObjectVersions
         
         && operType != OSSOperationTypeInitMultipartUpload)) {
            errorMessage = @"Object key should not be nil";
        }
    
    
    
    if (self.objectKey && ![InspurOSSUtil validateObjectKey:self.objectKey]) {
        errorMessage = @"Object key invalid";
    }
    
    if (errorMessage) {
        return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                          code:OSSClientErrorCodeInvalidArgument
                                                      userInfo:@{OSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [InspurOSSTask taskWithResult:nil];
    }
}

@end
