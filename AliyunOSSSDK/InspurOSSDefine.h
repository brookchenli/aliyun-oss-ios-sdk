//
//  OSSDefine.h
//  InspurOSSiOS
//
//  Created by xx on 5/1/16.
//  Copyright © 2016 zhouzhuo. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef OSSDefine_h
#define OSSDefine_h

#if TARGET_OS_IOS
#define OSSUAPrefix                             @"inspur-sdk-ios"
#elif TARGET_OS_OSX
#define OSSUAPrefix                             @"inspur-sdk-mac"
#endif
#define InspurOSSSDKVersion                           @"1.0.0"

#define InspurOSSListBucketResultXMLTOKEN             @"ListBucketResult"
#define InspurOSSNameXMLTOKEN                         @"Name"
#define InspurOSSDelimiterXMLTOKEN                    @"Delimiter"
#define InspurOSSMarkerXMLTOKEN                       @"Marker"
#define InpsurOSSKeyMarkerXMLTOKEN                    @"KeyMarker"
#define InspurOSSNextMarkerXMLTOKEN                   @"NextMarker"
#define InspurOSSNextKeyMarkerXMLTOKEN                @"NextKeyMarker"
#define InspurOSSUploadIdMarkerXMLTOKEN               @"UploadIdMarker"
#define InspurOSSNextUploadIdMarkerXMLTOKEN           @"NextUploadIdMarker"
#define InspurOSSMaxKeysXMLTOKEN                      @"MaxKeys"
#define InspurOSSMaxUploadsXMLTOKEN                   @"MaxUploads"
#define InspurOSSIsTruncatedXMLTOKEN                  @"IsTruncated"
#define InspurOSSContentsXMLTOKEN                     @"Contents"
#define InspurOSSUploadXMLTOKEN                       @"Upload"
#define InspurOSSKeyXMLTOKEN                          @"Key"
#define InspurOSSLastModifiedXMLTOKEN                 @"LastModified"
#define InspurOSSETagXMLTOKEN                         @"ETag"
#define InspurOSSTypeXMLTOKEN                         @"Type"
#define InspurOSSSizeXMLTOKEN                         @"Size"
#define InspurOSSPageSizeXMLTOKEN                     @"PageSize"
#define InspurOSSPageNoXMLTOKEN                       @"PageNo"
#define InspurOSSTotalCountXMLTOKEN                   @"TotalCount"
#define InspurOSSStorageClassXMLTOKEN                 @"StorageClass"
#define InspurOSSCommonPrefixesXMLTOKEN               @"CommonPrefixes"
#define InspurOSSOwnerXMLTOKEN                        @"Owner"
#define InspurOSSAccessControlListXMLTOKEN            @"AccessControlList"
#define InspurOSSGrantXMLTOKEN                        @"Grant"
#define InspurOSSIDXMLTOKEN                           @"ID"
#define InspurOSSDisplayNameXMLTOKEN                  @"DisplayName"
#define InspurOSSBucketsXMLTOKEN                      @"Buckets"
#define InspurOSSBucketXMLTOKEN                       @"Bucket"
#define InspurOSSCreationDate                         @"CreationDate"
#define InspurOSSPrefixXMLTOKEN                       @"Prefix"
#define InspurOSSUploadIdXMLTOKEN                     @"UploadId"
#define InspurOSSLocationXMLTOKEN                     @"Location"
#define InspurOSSNextPartNumberMarkerXMLTOKEN         @"NextPartNumberMarker"
#define InspurOSSMaxPartsXMLTOKEN                     @"MaxParts"
#define InspurOSSPartXMLTOKEN                         @"Part"
#define InspurOSSPartNumberXMLTOKEN                   @"PartNumber"

#define InspurOSSClientErrorDomain                    @"com.inspur.oss.clientError"
#define InspurOSSServerErrorDomain                    @"com.inspur.oss.serverError"

#define InspurOSSErrorMessageTOKEN                    @"ErrorMessage"
#define InspurOSSTextTOKEN                    @"__text"
#define InspurOSSCORSRULETOKEN                    @"CORSRule"
#define InspurOSSSTATUSTOKEN                    @"Status"
#define InspurOSSRULETOKEN                    @"Rule"
#define InspurOSSServerSideEncryptionDefaultTOKEN                    @"ApplyServerSideEncryptionByDefault"
#define InspurOSSServerSSETOKEN                    @"SSEAlgorithm"
#define InspurOSSServerMasterIdTOKEN                    @"KMSMasterKeyID"

#define InspurOSSHttpHeaderContentDisposition         @"Content-Disposition"
#define InspurOSSHttpHeaderXOSSCallback               @"x-oss-callback"
#define InspurOSSHttpHeaderXOSSCallbackVar            @"x-oss-callback-var"
#define InspurOSSHttpHeaderContentEncoding            @"Content-Encoding"
#define InspurOSSHttpHeaderContentType                @"Content-Type"
#define InspurHttpHeaderContentMD5                 @"Content-MD5"
#define InspurOSSHttpHeaderCacheControl               @"Cache-Control"
#define InspurOSSHttpHeaderExpires                    @"Expires"
#define InspurOSSHttpHeaderHashSHA1                   @"x-oss-hash-sha1"
#define InspurOSSHttpHeaderBucketACL                  @"x-oss-acl"
#define InspurOSSHttpHeaderObjectACL                  @"x-oss-object-acl"
#define InspurOSSHttpHeaderCopySource                 @"x-oss-copy-source"
#define InspurOSSHttpHeaderSymlinkTarget              @"x-oss-symlink-target"
#define InspurOSSHttpHeaderRandomObjectName              @"random-object-name"

#define InspurOSSHttpQueryProcess                     @"x-oss-process"

#define InspurOSSDefaultRetryCount                    3
#define InspurOSSDefaultMaxConcurrentNum              5
#define InspurOSSDefaultTimeoutForRequestInSecond     15
#define InspurOSSDefaultTimeoutForResourceInSecond    7 * 24 * 60 * 60

#endif /* OSSDefine_h */
