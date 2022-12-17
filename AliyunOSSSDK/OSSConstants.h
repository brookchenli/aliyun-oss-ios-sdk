//
//  OSSConstants.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* _Nullable (^OSSCustomSignContentBlock) (NSString * contentToSign, NSError **error);
typedef NSData * _Nullable (^OSSResponseDecoderBlock) (NSData * data);

typedef void (^OSSNetworkingUploadProgressBlock) (int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^OSSNetworkingDownloadProgressBlock) (int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^OSSNetworkingRetryBlock) (void);
typedef void (^OSSNetworkingCompletionHandlerBlock) (id _Nullable responseObject, NSError * _Nullable error);
typedef void (^OSSNetworkingOnRecieveDataBlock) (NSData * data);

/**
 The flag of verification about crc64
 */
typedef NS_ENUM(NSUInteger, OSSRequestCRCFlag) {
    OSSRequestCRCUninitialized,
    OSSRequestCRCOpen,
    OSSRequestCRCClosed
};

/**
 Retry type definition
 */
typedef NS_ENUM(NSInteger, OSSNetworkingRetryType) {
    OSSNetworkingRetryTypeUnknown,
    OSSNetworkingRetryTypeShouldRetry,
    OSSNetworkingRetryTypeShouldNotRetry,
    OSSNetworkingRetryTypeShouldRefreshCredentialsAndRetry,
    OSSNetworkingRetryTypeShouldCorrectClockSkewAndRetry
};

/**
 * @brief: The following constants are provided by OSSNetworking as possible operation types.
 */
typedef NS_ENUM(NSInteger, OSSOperationType) {
    OSSOperationTypeGetService,
    OSSOperationTypeListService,
    OSSOperationTypeQueryBucketExist,
    OSSOperationTypeCreateBucket,
    OSSOperationTypeDeleteBucket,
    OSSOperationTypeGetBucket,
    OSSOperationTypeGetBucketLocation,
    OSSOperationTypeGetBucketInfo,
    OSSOperationTypeGetBucketACL,
    OSSOperationTypePutBucketACL,
    OSSOperationTypeGetBucketCORS,
    OSSOperationTypePutBucketCORS,
    OSSOperationTypeDeleteBucketCORS,
    OSSOperationTypeGetBucketVersioning,
    OSSOperationTypePutBucketVersioning,
    
    OSSOperationTypeGetBucketEncryption,
    OSSOperationTypePutBucketEncryption,
    OSSOperationTypeDeleteBucketEncryption,
    
    OSSOperationTypeGetBucketWebsite,
    OSSOperationTypePutBucketWebsite,
    OSSOperationTypeDeleteBucketWebsite,
    
    OSSOperationTypeGetBucketDomain,
    OSSOperationTypePutBucketDomain,
    OSSOperationTypeDeleteBucketDomain,
    
    OSSOperationTypeGetBucketLifeCycle,
    OSSOperationTypePutBucketLifeCycle,
    OSSOperationTypeDeleteBucketLifeCycle,
    
    OSSOperationTypeGetBucketPolicy,
    OSSOperationTypePutBucketPolicy,
    OSSOperationTypeDeleteBucketPolicy,
    
    OSSOperationTypeHeadObject,
    OSSOperationTypeGetObject,
    OSSOperationTypeGetObjectACL,
    OSSOperationTypePutObject,
    OSSOperationTypePutObjectACL,
    OSSOperationTypePutObjectMetaData,
    OSSOperationTypeAppendObject,
    OSSOperationTypeDeleteObject,
    OSSOperationTypeDeleteMultipleObjects,
    OSSOperationTypeCopyObject,
    OSSOperationTypeInitMultipartUpload,
    OSSOperationTypeUploadPart,
    OSSOperationTypeCompleteMultipartUpload,
    OSSOperationTypeAbortMultipartUpload,
    OSSOperationTypeListMultipart,
    OSSOperationTypeListMultipartUploads,
    OSSOperationTypeTriggerCallBack,
    OSSOperationTypeImagePersist,
    OSSOperationTypeRestoreObject,
    OSSOperationTypePutSymlink,
    OSSOperationTypeGetSymlink,
    OSSOperationTypeGetObjectTagging,
    OSSOperationTypePutObjectTagging,
    OSSOperationTypeDeleteObjectTagging,
    OSSOperationTypeGetObjectVersions,
    OSSOperationTypeDeleteObjectVersions
};

/**
 * @brief: The following constants are provided by OSSClient as possible error codes.
 */
typedef NS_ENUM(NSInteger, OSSClientErrorCODE) {
    OSSClientErrorCodeNetworkingFailWithResponseCode0,
    OSSClientErrorCodeSignFailed,
    OSSClientErrorCodeFileCantWrite,
    OSSClientErrorCodeInvalidArgument,
    OSSClientErrorCodeNilUploadid,
    OSSClientErrorCodeTaskCancelled,
    OSSClientErrorCodeNetworkError,
    OSSClientErrorCodeInvalidCRC,
    OSSClientErrorCodeCannotResumeUpload,
    OSSClientErrorCodeExcpetionCatched,
    OSSClientErrorCodeNotKnown,
    OSSClientErrorCodeFileCantRead
};

typedef NS_ENUM(NSInteger, OSSXMLDictionaryAttributesMode)
{
    OSSXMLDictionaryAttributesModePrefixed = 0, //default
    OSSXMLDictionaryAttributesModeDictionary,
    OSSXMLDictionaryAttributesModeUnprefixed,
    OSSXMLDictionaryAttributesModeDiscard
};


typedef NS_ENUM(NSInteger, OSSXMLDictionaryNodeNameMode)
{
    OSSXMLDictionaryNodeNameModeRootOnly = 0, //default
    OSSXMLDictionaryNodeNameModeAlways,
    OSSXMLDictionaryNodeNameModeNever
};

typedef NS_ENUM(NSInteger, OSSBucketStorageClass)
{
    OSSBucketStorageClassStandard,
    OSSBucketStorageClassIA,
    OSSBucketStorageClassArchive
};

typedef NSString * OSSXMLDictionaryAttributeName NS_EXTENSIBLE_STRING_ENUM;

OBJC_EXTERN OSSXMLDictionaryAttributeName const OSSXMLDictionaryAttributesKey;
OBJC_EXTERN OSSXMLDictionaryAttributeName const OSSXMLDictionaryCommentsKey;
OBJC_EXTERN OSSXMLDictionaryAttributeName const OSSXMLDictionaryTextKey;
OBJC_EXTERN OSSXMLDictionaryAttributeName const OSSXMLDictionaryNodeNameKey;
OBJC_EXTERN OSSXMLDictionaryAttributeName const OSSXMLDictionaryAttributePrefix;

OBJC_EXTERN NSString * const OSSHTTPMethodHEAD;
OBJC_EXTERN NSString * const OSSHTTPMethodGET;
OBJC_EXTERN NSString * const OSSHTTPMethodPUT;
OBJC_EXTERN NSString * const OSSHTTPMethodPOST;
OBJC_EXTERN NSString * const OSSHTTPMethodDELETE;


NS_ASSUME_NONNULL_END
