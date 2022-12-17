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

- (InspurOSSTask *)validateRequestParamsInOperationType:(InspurOSSOperationType)operType {
    NSString * errorMessage = nil;
    
    if (!self.endpoint) {
        errorMessage = @"Endpoint should not be nil";
    }
    
    if (!self.bucketName && operType != InspurOSSOperationTypeGetService && operType != InspurOSSOperationTypeListService) {
        errorMessage = @"Bucket name should not be nil";
    }
    
    if (self.bucketName && ![InspurOSSUtil validateBucketName:self.bucketName]) {
        errorMessage = @"Bucket name invalid";
    }
    
    if (!self.objectKey &&
        (operType != InspurOSSOperationTypeGetBucket && operType != InspurOSSOperationTypeCreateBucket
         && operType != InspurOSSOperationTypeDeleteBucket && operType != InspurOSSOperationTypeGetService
         && operType != InspurOSSOperationTypeGetBucketACL&& operType != InspurOSSOperationTypeDeleteMultipleObjects
         && operType != InspurOSSOperationTypeListMultipartUploads
         && operType != InspurOSSOperationTypeGetBucketInfo
         && operType != InspurOSSOperationTypeListService
         && operType != InspurOSSOperationTypeQueryBucketExist
         && operType != InspurOSSOperationTypeGetBucketLocation
         && operType != InspurOSSOperationTypePutBucketACL
         && operType != InspurOSSOperationTypeGetBucketCORS
         && operType != InspurOSSOperationTypePutBucketCORS
         && operType != InspurOSSOperationTypeDeleteBucketCORS
         && operType != InspurOSSOperationTypeGetBucketVersioning
         && operType != InspurOSSOperationTypePutBucketVersioning
         && operType != InspurOSSOperationTypeGetBucketEncryption
         && operType != InspurOSSOperationTypePutBucketEncryption
         && operType != InspurOSSOperationTypeDeleteBucketEncryption
         && operType != InspurOSSOperationTypeGetBucketWebsite
         && operType != InspurOSSOperationTypePutBucketWebsite
         && operType != InspurOSSOperationTypeDeleteBucketWebsite
         && operType != InspurOSSOperationTypeGetBucketDomain
         && operType != InspurOSSOperationTypePutBucketDomain
         && operType != InspurOSSOperationTypeDeleteBucketDomain
         
         && operType != InspurOSSOperationTypeGetBucketLifeCycle
         && operType != InspurOSSOperationTypePutBucketLifeCycle
         && operType != InspurOSSOperationTypeDeleteBucketLifeCycle
         
         && operType != InspurOSSOperationTypeGetBucketPolicy
         && operType != InspurOSSOperationTypePutBucketPolicy
         && operType != InspurOSSOperationTypeDeleteBucketPolicy
         
         && operType != InspurOSSOperationTypeGetObjectVersions
         && operType != InspurOSSOperationTypeDeleteObjectVersions
         
         && operType != InspurOSSOperationTypeInitMultipartUpload)) {
            errorMessage = @"Object key should not be nil";
        }
    
    
    
    if (self.objectKey && ![InspurOSSUtil validateObjectKey:self.objectKey]) {
        errorMessage = @"Object key invalid";
    }
    
    if (errorMessage) {
        return [InspurOSSTask taskWithError:[NSError errorWithDomain:InspurOSSClientErrorDomain
                                                          code:InspurOSSClientErrorCodeInvalidArgument
                                                      userInfo:@{InspurOSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [InspurOSSTask taskWithResult:nil];
    }
}

@end
