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
typedef NS_ENUM(NSInteger, InspurOSSOperationType) {
    InspurOSSOperationTypeGetService,
    InspurOSSOperationTypeListService,
    InspurOSSOperationTypeQueryBucketExist,
    InspurOSSOperationTypeCreateBucket,
    InspurOSSOperationTypeDeleteBucket,
    InspurOSSOperationTypeGetBucket,
    InspurOSSOperationTypeGetBucketLocation,
    InspurOSSOperationTypeGetBucketInfo,
    InspurOSSOperationTypeGetBucketACL,
    InspurOSSOperationTypePutBucketACL,
    InspurOSSOperationTypeGetBucketCORS,
    InspurOSSOperationTypePutBucketCORS,
    InspurOSSOperationTypeDeleteBucketCORS,
    InspurOSSOperationTypeGetBucketVersioning,
    InspurOSSOperationTypePutBucketVersioning,
    
    InspurOSSOperationTypeGetBucketEncryption,
    InspurOSSOperationTypePutBucketEncryption,
    InspurOSSOperationTypeDeleteBucketEncryption,
    
    InspurOSSOperationTypeGetBucketWebsite,
    InspurOSSOperationTypePutBucketWebsite,
    InspurOSSOperationTypeDeleteBucketWebsite,
    
    InspurOSSOperationTypeGetBucketDomain,
    InspurOSSOperationTypePutBucketDomain,
    InspurOSSOperationTypeDeleteBucketDomain,
    
    InspurOSSOperationTypeGetBucketLifeCycle,
    InspurOSSOperationTypePutBucketLifeCycle,
    InspurOSSOperationTypeDeleteBucketLifeCycle,
    
    InspurOSSOperationTypeGetBucketPolicy,
    InspurOSSOperationTypePutBucketPolicy,
    InspurOSSOperationTypeDeleteBucketPolicy,
    
    InspurOSSOperationTypeHeadObject,
    InspurOSSOperationTypeGetObject,
    InspurOSSOperationTypeGetObjectACL,
    InspurOSSOperationTypePutObject,
    InspurOSSOperationTypePutObjectACL,
    InspurOSSOperationTypePutObjectMetaData,
    InspurOSSOperationTypeAppendObject,
    InspurOSSOperationTypeDeleteObject,
    InspurOSSOperationTypeDeleteMultipleObjects,
    InspurOSSOperationTypeCopyObject,
    InspurOSSOperationTypeInitMultipartUpload,
    InspurOSSOperationTypeUploadPart,
    InspurOSSOperationTypeCompleteMultipartUpload,
    InspurOSSOperationTypeAbortMultipartUpload,
    InspurOSSOperationTypeListMultipart,
    InspurOSSOperationTypeListMultipartUploads,
    InspurOSSOperationTypeTriggerCallBack,
    InspurOSSOperationTypeImagePersist,
    InspurOSSOperationTypeRestoreObject,
    InspurOSSOperationTypePutSymlink,
    InspurOSSOperationTypeGetSymlink,
    InspurOSSOperationTypeGetObjectTagging,
    InspurOSSOperationTypePutObjectTagging,
    InspurOSSOperationTypeDeleteObjectTagging,
    InspurOSSOperationTypeGetObjectVersions,
    InspurOSSOperationTypeDeleteObjectVersions
};

/**
 * @brief: The following constants are provided by OSSClient as possible error codes.
 */
typedef NS_ENUM(NSInteger, InspurOSSClientErrorCode) {
    InspurOSSClientErrorCodeNetworkingFailWithResponseCode0,
    InspurOSSClientErrorCodeSignFailed,
    InspurOSSClientErrorCodeFileCantWrite,
    InspurOSSClientErrorCodeInvalidArgument,
    InspurOSSClientErrorCodeNilUploadid,
    InspurOSSClientErrorCodeTaskCancelled,
    InspurOSSClientErrorCodeNetworkError,
    InspurOSSClientErrorCodeInvalidCRC,
    InspurOSSClientErrorCodeCannotResumeUpload,
    InspurOSSClientErrorCodeExcpetionCatched,
    InspurOSSClientErrorCodeNotKnown,
    InspurOSSClientErrorCodeFileCantRead
};

typedef NS_ENUM(NSInteger, InspurOSSXMLDictionaryAttributesMode)
{
    InspurOSSXMLDictionaryAttributesModePrefixed = 0, //default
    InspurOSSXMLDictionaryAttributesModeDictionary,
    InspurOSSXMLDictionaryAttributesModeUnprefixed,
    InspurOSSXMLDictionaryAttributesModeDiscard
};


typedef NS_ENUM(NSInteger, InspurOSSXMLDictionaryNodeNameMode)
{
    InspurOSSXMLDictionaryNodeNameModeRootOnly = 0, //default
    InspurOSSXMLDictionaryNodeNameModeAlways,
    InspurOSSXMLDictionaryNodeNameModeNever
};

typedef NS_ENUM(NSInteger, InspurOSSBucketStorageClass)
{
    InspurOSSBucketStorageClassStandard,
    InspurOSSBucketStorageClassIA,
    InspurOSSBucketStorageClassArchive
};

typedef NSString * InspurOSSXMLDictionaryAttributeName NS_EXTENSIBLE_STRING_ENUM;

OBJC_EXTERN InspurOSSXMLDictionaryAttributeName const InspurOSSXMLDictionaryAttributesKey;
OBJC_EXTERN InspurOSSXMLDictionaryAttributeName const InspurOSSXMLDictionaryCommentsKey;
OBJC_EXTERN InspurOSSXMLDictionaryAttributeName const InspurOSSXMLDictionaryTextKey;
OBJC_EXTERN InspurOSSXMLDictionaryAttributeName const InspurOSSXMLDictionaryNodeNameKey;
OBJC_EXTERN InspurOSSXMLDictionaryAttributeName const InspurXMLDictionaryAttributePrefix;

OBJC_EXTERN NSString * const InspurOSSHTTPMethodHEAD;
OBJC_EXTERN NSString * const InspurHTTPMethodGET;
OBJC_EXTERN NSString * const InspurHTTPMethodPUT;
OBJC_EXTERN NSString * const InspurOSSHTTPMethodPOST;
OBJC_EXTERN NSString * const InspurOSSHTTPMethodDELETE;


NS_ASSUME_NONNULL_END
