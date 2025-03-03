//
//  OSSModel.h
//  oss_ios_sdk
//
//  Created by xx on 8/16/15.
//  Copyright (c) 2022 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurOSSRequest.h"
#import "InspurOSSResult.h"

@class InspurOSSAllRequestNeededMessage;
@class InspurOSSFederationToken;
@class InspurOSSTask;
@class InspurOSSClientConfiguration;
@class InspurOSSCORSRule;

NS_ASSUME_NONNULL_BEGIN

typedef InspurOSSFederationToken * _Nullable (^OSSGetFederationTokenBlock) (void);

/**
 Categories NSDictionary
 */
@interface NSDictionary (InspurOSS)
- (NSString *)base64JsonString;
@end

/**
 A thread-safe dictionary
 */
@interface InspurOSSSyncMutableDictionary : NSObject
@property (nonatomic, strong) NSMutableDictionary *dictionary;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

- (id)objectForKey:(id)aKey;
- (NSArray *)allKeys;
- (void)setObject:(id)anObject forKey:(id <NSCopying>)aKey;
- (void)removeObjectForKey:(id)aKey;
@end

/**
 FederationToken class
 */
@interface InspurOSSFederationToken : NSObject
@property (nonatomic, copy) NSString * tAccessKey;
@property (nonatomic, copy) NSString * tSecretKey;
@property (nonatomic, copy) NSString * tToken;

/**
 Token's expiration time in milliseconds of the unix time.
 */
@property (atomic, assign) int64_t expirationTimeInMilliSecond;

/**
 Token's expiration time in GMT format string.
 */
@property (atomic, strong, nullable) NSString *expirationTimeInGMTFormat;
@end

/**
 CredentialProvider protocol, needs to implement sign API.
 */
@protocol InspurOSSCredentialProvider <NSObject>
@optional
- (nullable NSString *)sign:(NSString *)content error:(NSError **)error;
@end

/**
 The plaint text AK/SK credential provider for test purposely.
 */

__attribute__((deprecated("PLEASE DO NOT USE THIS CLASS AGAIN")))
@interface InspurOSSPlainTextAKSKPairCredentialProvider : NSObject <InspurOSSCredentialProvider>
@property (nonatomic, copy) NSString * accessKey;
@property (nonatomic, copy) NSString * secretKey;

- (instancetype)initWithPlainTextAccessKey:(NSString *)accessKey
                                 secretKey:(NSString *)secretKey __attribute__((deprecated("We recommend the STS authentication mode on mobile")));
@end

/**
TODOTODO
 The custom signed credential provider
 */
@interface InspurOSSCustomSignerCredentialProvider : NSObject <InspurOSSCredentialProvider>
@property (nonatomic, copy, readonly,) NSString * _Nonnull (^ _Nonnull signContent)( NSString * _Nonnull , NSError * _Nullable *_Nullable);

+ (instancetype _Nullable)new NS_UNAVAILABLE;
- (instancetype _Nullable)init NS_UNAVAILABLE;

/**
 * During the task execution, this API is called for signing
 * It's executed at the background thread instead of UI thread.
 */
- (instancetype _Nullable)initWithImplementedSigner:(OSSCustomSignContentBlock)signContent NS_DESIGNATED_INITIALIZER;
@end

/**
TODOTODO
 User's custom federation credential provider.
 */
@interface InspurOSSFederationCredentialProvider : NSObject <InspurOSSCredentialProvider>
@property (nonatomic, strong) InspurOSSFederationToken * cachedToken;
@property (nonatomic, copy) InspurOSSFederationToken * (^federationTokenGetter)(void);

/**
 During the task execution, this method is called to get the new STS token.
 It runs in the background thread, not the UI thread.
 */
- (instancetype)initWithFederationTokenGetter:(OSSGetFederationTokenBlock)federationTokenGetter;
- (nullable InspurOSSFederationToken *)getToken:(NSError **)error;
@end

/**
 The STS token's credential provider.
 */
@interface InspurOSSStsTokenCredentialProvider : NSObject <InspurOSSCredentialProvider>
@property (nonatomic, copy) NSString * accessKeyId;
@property (nonatomic, copy) NSString * secretKeyId;
@property (nonatomic, copy) NSString * securityToken;

- (InspurOSSFederationToken *)getToken;
- (instancetype)initWithAccessKeyId:(NSString *)accessKeyId
                        secretKeyId:(NSString *)secretKeyId
                      securityToken:(NSString *)securityToken;
@end

/**
 Auth credential provider require a STS INFO Server URL,also you can customize a decoder block which returns json data.
 
 
 OSSAuthCredentialProvider *acp = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:@"sts_server_url" responseDecoder:^NSData * (NSData * data) {
        // 1.hanle response from server.
 
 // 2.initialize json object from step 1. json object require message like {AccessKeyId:@"xxx",AccessKeySecret:@"xxx",SecurityToken:@"xxx",Expiration:@"xxx"}
 
        // 3.generate jsonData from step 2 and return it.
 }];
 
 */

@interface InspurOSSAuthCredentialProvider : InspurOSSFederationCredentialProvider
@property (nonatomic, copy) NSString * authServerUrl;
@property (nonatomic, copy) NSData * (^responseDecoder)(NSData *);
- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl;
- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl responseDecoder:(nullable OSSResponseDecoderBlock)decoder;
@end

/**
 OSSClient side configuration.
 */
@interface InspurOSSClientConfiguration : NSObject

/**
 Max retry count
 */
@property (nonatomic, assign) uint32_t maxRetryCount;

/**
 Max concurrent requests
 */
@property (nonatomic, assign) uint32_t maxConcurrentRequestCount;

/**
 Flag of enabling background file transmit service.
 Note: it's only applicable for file upload.
 */
@property (nonatomic, assign) BOOL enableBackgroundTransmitService;

/**
 Flag of using Http request for DNS resolution.
 */
@property (nonatomic, assign) BOOL isHttpdnsEnable;

/**
Sets the session Id for background file transmission
 */
@property (nonatomic, copy) NSString * backgroundSesseionIdentifier;

/**
 Sets request timeout
 */
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;

/**
 Sets single object download's max time
 */
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;

/**
 Sets proxy host and port.
 */
@property (nonatomic, copy) NSString * proxyHost;
@property (nonatomic, strong) NSNumber * proxyPort;

/**
 Sets UA
 */
@property (nonatomic, copy) NSString * userAgentMark;

/**
 Sets the flag of using Second Level Domain style to access the endpoint. By default it's false.
 */
@property (nonatomic, assign) BOOL isPathStyleAccessEnable;

/**
 Sets  the flag of using custom path prefix to access the endpoint. By default it's false.
 */
@property (nonatomic, assign) BOOL isCustomPathPrefixEnable;

/**
 Sets CName excluded list.
 */
@property (nonatomic, strong, setter=setCnameExcludeList:) NSArray * cnameExcludeList;

/**
 是否开启crc校验(当同时设置了此选项和请求中的checkCRC开关时，以请求中的checkCRC开关为准)
 */
@property (nonatomic, assign) BOOL crc64Verifiable;

/// Set whether to allow UA to carry system information
@property (nonatomic, assign) BOOL isAllowUACarrySystemInfo;

/// Set whether to allow the redirection with a modified request
@property (nonatomic, assign) BOOL isFollowRedirectsEnable;

@end

@protocol InspurOSSRequestInterceptor <NSObject>
- (InspurOSSTask *)interceptRequestMessage:(InspurOSSAllRequestNeededMessage *)request;
@end

/**
 Signs the request when it's being created.
 */
@interface InspurOSSSignerInterceptor : NSObject <InspurOSSRequestInterceptor>
@property (nonatomic, strong) id<InspurOSSCredentialProvider> credentialProvider;

- (instancetype)initWithCredentialProvider:(id<InspurOSSCredentialProvider>)credentialProvider;
@end

/**
 Updates the UA when creating the request.
 */
@interface InspurOSSUASettingInterceptor : NSObject <InspurOSSRequestInterceptor>
@property (nonatomic, weak) InspurOSSClientConfiguration *clientConfiguration;
- (instancetype)initWithClientConfiguration:(InspurOSSClientConfiguration *) clientConfiguration;
@end

/**
 Fixes the time skew issue when creating the request.
 */
@interface InspurOSSTimeSkewedFixingInterceptor : NSObject <InspurOSSRequestInterceptor>
@end

/**
 The download range of OSS object
 */
@interface OSSRange : NSObject
@property (nonatomic, assign) int64_t startPosition;
@property (nonatomic, assign) int64_t endPosition;

- (instancetype)initWithStart:(int64_t)start
                      withEnd:(int64_t)end;

/**
 * Converts the header to string: 'bytes=${start}-${end}'
 */
- (NSString *)toHeaderString;
@end

#pragma mark RequestAndResultClass

/**
 The request to list all buckets of current user.
 */
@interface InspurOSSGetServiceRequest : InspurOSSRequest

/**
 The prefix filter for listing buckets---optional.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker filter for listing buckets----optional.
 The marker filter is to ensure any returned bucket name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries to return. By default it's 100 and max value of this property is 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;


@end

@interface InspurOSSListPageServiceRequest : InspurOSSRequest

/**
 
 */
@property (nonatomic, copy) NSString * filterKey;

/**
 
 */
@property (nonatomic, assign) int32_t pageNo;

/**
 
 */
@property (nonatomic, assign) int32_t pageSize;

@end


/**
 The result class of listing all buckets
 */
@interface InspurOSSGetServiceResult : InspurOSSResult

/**
 The owner Id
 */
@property (nonatomic, copy) NSString * ownerId;

/**
 Bucket owner name---currently it's same as owner Id.
 */
@property (nonatomic, copy) NSString * ownerDispName;

/**
 The prefix of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker of this query. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max buckets to return. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 Flag of the result is truncated. If it's truncated, it means there's remaining buckets to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The marker for the next ListBucket call. It's only set when there's remaining buckets to return.
 */
@property (nonatomic, copy) NSString * nextMarker;

/**
 The container of the buckets. It's a dictionary array, in which every element has keys "Name", "CreationDate" and "Location".
 */
@property (nonatomic, strong, nullable) NSArray * buckets;
@end

@interface InspurOSSListServiceResult : InspurOSSResult

/**
 The owner Id
 */
@property (nonatomic, copy) NSString * ownerId;

/**
 Bucket owner name---currently it's same as owner Id.
 */
@property (nonatomic, copy) NSString * ownerDispName;

@property (nonatomic, assign) int  pageNo;
@property (nonatomic, assign) int  totalCount;
@property (nonatomic, assign) int  pageSize;


/**
 The container of the buckets. It's a dictionary array, in which every element has keys "Name", "CreationDate" and "Location".
 */
@property (nonatomic, strong, nullable) NSArray * buckets;
@end

@interface InspurOSSQueryBucketExistRequest : InspurOSSRequest

@property (nonatomic, copy) NSString * bucketName;

@end

@interface InspurOSSQueryBucketExistResult : InspurOSSResult

@end

@interface InspurOSSGetBucketLocationRequest : InspurOSSRequest

@property (nonatomic, copy) NSString * bucketName;

@end

@interface InspurOSSGetBucketLocationResult : InspurOSSResult

@property (nonatomic, copy) NSString * region;

@end



/**
 The request to create bucket
 */
@interface InspurOSSCreateBucketRequest : InspurOSSRequest

/**
 *  存储空间,命名规范如下:(1)只能包括小写字母、数字和短横线(-);(2)必须以小写字母或者数字开头和结尾;(3)长度必须在3-63字节之间.
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The bucket location
 For more information about OSS datacenter and endpoint, please check out <a></a>
 */
@property (nonatomic, copy) NSString * location __attribute__ ((deprecated));

/**
 Sets Bucket access permission. For now there're three permissions:public-read-write，public-read and private. if this key is not set, the default value is private
 */
@property (nonatomic, copy) NSString * xOssACL;

@property (nonatomic, assign) InspurOSSBucketStorageClass storageClass;


- (NSString *)storageClassAsString;

@end

/**
 Result class of bucket creation
 */
@interface InspurOSSCreateBucketResult : InspurOSSResult

/**
 Bucket datacenter
 */
@property (nonatomic, copy) NSString * location;
@end

/**
 The request class of deleting bucket
 */
@interface InspurOSSDeleteBucketRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;
@end

/**
 Result class of deleting bucket
 */
@interface InspurOSSDeleteBucketResult : InspurOSSResult
@end

/**
 The request class of listing objects under a bucket
 */
@interface InspurOSSGetBucketRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The delimiter is very important and it determines the behavior of common prefix.
 For most cases, use the default '/' as the delimiter. 
 For example, if a bucket has folder 'prefix/' and a file 'abc'. And inside the folder it has file '123.txt'
 If the delimiter is '/', then the ListObject will return a common prefix 'prefix/' and a file 'abc'.
 If the delimiter is something else, then ListObject will return three files: prefix/, abc and prefix/123.txt. No common prefix!.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The marker filter for listing objects----optional.
 The marker filter is to ensure any returned object name must be greater than the marker in the lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries count to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The filter prefix of the objects to return----the returned objects' name must have the prefix.
 */
@property (nonatomic, copy) NSString * prefix;


@end

/**
 The result class of listing objects.
 */
@interface InspurOSSGetBucketResult : InspurOSSResult

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The prefix of the objects returned----the returned objects must have this prefix.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The marker filter of the objects returned---all objects returned are greater than this marker in lexicographic order.
 */
@property (nonatomic, copy) NSString * marker;

/**
 The max entries to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxKeys;

/**
 The delimiter to differentiate the folder object and file object.
 For object whose name ends with the delimiter, then it's treated as folder or common prefixes.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The maker for the next call. If no more entries to return, it's null.
 */
@property (nonatomic, copy) NSString * nextMarker;

/**
 Flag of truncated result. If it's truncated, it means there's more entries to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The dictionary arrary, in which each dictionary has keys of "Key", "LastModified", "ETag", "Type", "Size", "StorageClass" and "Owner".
 */
@property (nonatomic, strong, nullable) NSArray * contents;

/**
 The arrary of common prefixes. Each element is one common prefix.
 */
@property (nonatomic, strong) NSArray * commentPrefixes;
@end

/**
 The request class to get the bucket ACL.
 */
@interface InspurOSSGetBucketACLRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;
@end

/**
 The result class to get the bucket ACL.
 */
@interface InspurOSSGetBucketACLResult : InspurOSSResult

/**
 The bucket ACL. It could be one of the three values: private/public-read/public-read-write.
 */
@property (nonatomic, copy) NSString * aclGranted;
@end

@interface InspurOSSPutBucketACLRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *acl;
@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSPutBucketACLResult : InspurOSSResult

@end


@interface InspurOSSGetBucketCORSRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketCORSResult : InspurOSSResult

@property (nonatomic, copy, nullable) NSArray *bucketCORSRuleList;

@end

@interface InspurOSSPutBucketCORSRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;
@property (nonatomic, copy, nullable) NSArray <InspurOSSCORSRule *>*bucketCORSRuleList;

@end

@interface InspurOSSPutBucketCORSResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketCORSRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketCORSResult : InspurOSSResult

@end

@interface InspurOSSGetVersioningRequest : InspurOSSRequest
@property (nonatomic, copy, nullable) NSString *bucketName;
@end

@interface InspurOSSGetVersioningResult : InspurOSSResult

@property (nonatomic, copy) NSString *enabled;

@end

@interface InspurOSSPutVersioningRequest : InspurOSSRequest
@property (nonatomic, copy) NSString *enable;
@property (nonatomic, copy, nullable) NSString *bucketName;
@end

@interface InspurOSSPutVersioningResult : InspurOSSResult

@end

@interface InspurOSSGetBucketEncryptionRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketEncryptionResult : InspurOSSResult

@property (nonatomic, copy, nullable) NSString *sseAlgorithm;
@property (nonatomic, copy, nullable) NSString *masterId;

@end

@interface InspurOSSPutBucketEncryptionRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;
@property (nonatomic, copy, nullable) NSString *sseAlgorithm;
@property (nonatomic, copy, nullable) NSString *masterId;

@end

@interface InspurOSSPutBucketEncryptionResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketEncryptionRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketEncryptionResult : InspurOSSResult

@end

@interface InspurOSSGetBucketWebsiteRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketWebsiteResult : InspurOSSResult

@property (nonatomic, copy, nullable) NSString *indexDocument;
@property (nonatomic, copy, nullable) NSString *errroDocument;

@end

@interface InspurOSSPutBucketWebsiteRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;
@property (nonatomic, copy, nullable) NSString *indexDocument;
@property (nonatomic, copy, nullable) NSString *errroDocument;

@end

@interface InspurOSSPutBucketWebsiteResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketWebsiteRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketWebsiteResult : InspurOSSResult

@end

@interface InspurOSSGetBucketDomainRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketDomainResult : InspurOSSResult

@property (nonatomic, copy, nullable) NSString *domainJsonString;

@end

@interface InspurOSSPutBucketDomainRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;
@property (nonatomic, copy, nullable) NSArray <NSDictionary <NSString *, NSString *>*> *domainList;

@end

@interface InspurOSSPutBucketDomainResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketDomainRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketDomainResult : InspurOSSResult

@end

@interface InspurOSSGetBucketLifeCycleRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketLifeCycleResult : InspurOSSResult

@property (nonatomic, copy, nullable) NSString *lifeCycleConfigDictionary;

@end

@interface InspurOSSPutBucketLifeCycleRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSPutBucketLifeCycleResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketLifeCycleRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketLifeCycleResult : InspurOSSResult

@end

@interface InspurOSSGetBucketPolicyRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSGetBucketPolicyResult : InspurOSSResult

@property (nonatomic, strong, nonnull) NSString* jsonString;

@end

@interface InspurOSSPutBucketPolicyRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;
@property (nonatomic, strong, nonnull) NSString* policyVersion;
@property (nonatomic, strong, nonnull) NSArray *statementList;

@end

@interface InspurOSSPutBucketPolicyResult : InspurOSSResult

@end

@interface InspurOSSDeleteBucketPolicyRequest : InspurOSSRequest

@property (nonatomic, copy, nullable) NSString *bucketName;

@end

@interface InspurOSSDeleteBucketPolicyResult : InspurOSSResult

@end


/**
 The request class to get object metadata
 */
@interface InspurOSSHeadObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;
@end

/**
 The result class of getting object metadata.
 */
@interface InspurOSSHeadObjectResult : InspurOSSResult

/**
 Object metadata
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end

/**
 The request class to get object
 */
@interface InspurOSSGetObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 OSS Download Range: For example, bytes=0-9 means uploading the first to the tenth's character.
 */
@property (nonatomic, strong) OSSRange * range;

/**
 The local file path to download to.
 */
@property (nonatomic, strong) NSURL * downloadToFileURL;

/**
 Image processing configuration.
 */
@property (nonatomic, copy) NSString * xOssProcess;

/**
 Download progress callback.
 It runs at background thread.
 */
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;

/**
 During the object download, the callback is called upon response is received.
 It runs under background thread (not UI thread)
 */
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;

/**
 * set request headers
 */
@property (nonatomic, copy) NSDictionary *headerFields;

@end

/**
 Result class of downloading an object.
 */
@interface InspurOSSGetObjectResult : InspurOSSResult

/**
 The in-memory content of the downloaded object, if the local file path is not specified.
 */
@property (nonatomic, strong) NSData * downloadedData;

/**
 The object metadata dictionary
 */
@property (nonatomic, copy) NSDictionary * objectMeta;
@end


/**
 The response class to update the object ACL.
 */
@interface InspurOSSPutObjectACLResult : InspurOSSResult
@end

/**
 The request class to upload an object.
 */
@interface InspurOSSPutObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The in-memory data to upload.
 */
@property (nonatomic, strong) NSData * uploadingData;

/**
 The local file path to upload.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 The callback parameters.
 */
@property (nonatomic, copy) NSDictionary * callbackParam;

/**
 The callback variables.
 */
@property (nonatomic, copy) NSDictionary * callbackVar;

/**
 The content type.
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The content's MD5 digest. 
 It's calculated on the request body (not headers) according to RFC 1864 to get the 128 bit digest data.
 Then use base64 encoding on the 128bit result to get this MD5 value.
 This header is for integrity check on the data. And it's recommended to turn on for every body.
 */
@property (nonatomic, copy) NSString * contentMd5;

/**
 Specifies the download name of the object. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * contentDisposition;

/**
 Specifies the content encoding during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * contentEncoding;

/**
 Specifies the cache behavior during the download. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC2616 for more details.
 */
@property (nonatomic, copy) NSString * expires;

/**
 The object's metadata.
 When the object is being uploaded, it could be specified with http headers prefixed with x-oss-meta for user metadata.
 The total size of all user metadata cannot be more than 8K. 
 It also could include standard HTTP headers in this object.
 */
@property (nonatomic, copy) NSDictionary * objectMeta;

/**
 The upload progress callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The upload retry callback.
 It runs in background thread (not UI thread).
 */
@property (nonatomic, copy) OSSNetworkingRetryBlock uploadRetryCallback;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;
 
@end

/**
 The request class to update the object ACL.
 */
@interface InspurOSSPutObjectACLRequest : InspurOSSPutObjectRequest

/**
 *@brief:指定oss创建object时的访问权限,合法值:public-read、private、public-read-write
 */
@property (nonatomic, copy, nullable) NSString *acl;

@end

@interface InspurOSSPutObjectMetaRequest : InspurOSSPutObjectRequest

@end

/**
 The result class to put an object
 */
@interface InspurOSSPutObjectResult : InspurOSSResult

/**
ETag (entity tag) is the tag during the object creation in OSS server side.
It's the MD5 value for put object request. If the object is created by other APIs, the ETag is the UUID of the content.
 ETag could be used to check if the object has been updated.
 */
@property (nonatomic, copy) NSString * eTag;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, copy) NSString * serverReturnJsonString;

@property (nonatomic, copy) NSString * objectName;

@end

/**
 * append object request
 */
@interface InspurOSSAppendObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Specifies which position to append. For a new file, the first append should start from 0. And the subsequential calls will start from the current length of the object.
 For example, if the first append's size is 65536, then the appendPosition value in the next call will be 65536.
 In its response, the header x-oss-next-append-position is included for next call.
 */
@property (nonatomic, assign) int64_t appendPosition;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong) NSData * uploadingData;

/**
 The local file path to upload from.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 Sets the content type
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The content's MD5 digest value.
 It's calculated from the MD5 value of the request body according to RFC 1864 and then encoded by base64.
 */
@property (nonatomic, copy) NSString *contentMd5;

/**
 The object's name during the download according to RFC 2616.
 */
@property (nonatomic, copy) NSString * contentDisposition;

/**
 The content encoding during the object upload. Checks out RFC2616 for more detail.
 */
@property (nonatomic, copy) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's being downloaded.Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy) NSString * cacheControl;

/**
 Expiration time. Checks out RFC2616 for more information.
 */
@property (nonatomic, copy) NSString * expires;

/**
 The object's metadata, which start with x-oss-meta-, such as x-oss-meta-location.
 Each request can have multiple metadata as long as the total size of all metadata is no bigger than 8KB.
 It could include standard headers as well.
 */
@property (nonatomic, copy) NSDictionary * objectMeta;

/**
 Upload progress callback.
 It's called on the background thread.
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;


@end

/**
 * append object result
 */
@interface InspurOSSAppendObjectResult : InspurOSSResult

/**
 TODOTODO
 ETag (entity tag). It's created for every object when it's created.
 For Objects created by PUT, ETag is the MD5 value of the content data. For others, ETag is the UUID of the content.
 ETag is used for checking data integrity.
 */
@property (nonatomic, copy) NSString * eTag;

/**
 Specifies the next starting position. It's essentially the current object size.
 This header is included in the successful response or the error response when the start position does not match the object size.
 */
@property (nonatomic, assign, readwrite) int64_t xOssNextAppendPosition;
@end

/**
 The request of deleting an object.
 */
@interface InspurOSSDeleteObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, copy) NSString * objectKey;
@end

/**
 Result class of deleting an object
 */
@interface InspurOSSDeleteObjectResult : InspurOSSResult
@end

/**
 Request class of copying an object in OSS.
 */
@interface InspurOSSCopyObjectRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 * Source object's address (the caller needs the read permission on this object)
 */
@property (nonatomic, copy) NSString * sourceCopyFrom DEPRECATED_MSG_ATTRIBUTE("please use sourceBucketName & sourceObjectKey instead!it will be removed in next version.");

@property (nonatomic, copy) NSString * sourceBucketName;

@property (nonatomic, copy) NSString * sourceObjectKey;

/**
 The content type
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The content's MD5 digest.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, copy) NSString * contentMd5;

/**
 The user metadata dictionary, which starts with x-oss-meta-. 
 The total size of user metadata can be no more than 8KB.
 It could include standard http headers as well.
 */
@property (nonatomic, copy) NSDictionary * objectMeta;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;


@end

/**
 The result class of copying an object
 */
@interface InspurOSSCopyObjectResult : InspurOSSResult

/**
 The last modified time
 */
@property (nonatomic, copy) NSString * lastModifed;

/**
 The ETag of the new object.
 */
@property (nonatomic, copy) NSString * eTag;
@end

/**
 Request class of initiating a multipart upload.
 */
@interface InspurOSSInitMultipartUploadRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Content type
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The object's download name. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy) NSString * contentDisposition;

/**
 The content encoding. Checks out RFC 2616.
 */
@property (nonatomic, copy) NSString * contentEncoding;

/**
 Specifies the cache control behavior when it's downloaded. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy) NSString * cacheControl;

/**
 Expiration time in milliseconds. Checks out RFC 2616 for more details.
 */
@property (nonatomic, copy) NSString * expires;

/**
 The dictionary of object's custom metadata, which starts with x-oss-meta-. 
 The total size of user metadata is no more than 8KB.
 It could include other standard http headers.
 */
@property (nonatomic, copy) NSDictionary * objectMeta;

/**
 * When Setting this value to YES , parts will be uploaded in order. Default value is NO.
 */
@property (nonatomic, assign) BOOL sequential;

@end

/**
 The resutl class of initiating a multipart upload.
 */
@interface InspurOSSInitMultipartUploadResult : InspurOSSResult

/**
 The upload Id of the multipart upload
 */
@property (nonatomic, copy) NSString * uploadId;
@end

/**
 The request class of uploading one part.
 */
@interface InspurOSSUploadPartRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectkey;

/**
 Multipart Upload id.
 */
@property (nonatomic, copy) NSString * uploadId;

@property (nonatomic, copy) NSString * randomObjectName;

/**
 The part number of this part.
 */
@property (nonatomic, assign) int partNumber;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check.
 */
@property (nonatomic, copy) NSString * contentMd5;

/**
 The in-memory data to upload from.
 */
@property (nonatomic, strong) NSData * uploadPartData;

/**
 The local file path to upload from
 */
@property (nonatomic, strong) NSURL * uploadPartFileURL;

/**
 The upload progress callback.
 It runs in background thread (not UI thread);
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadPartProgress;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;

@end

/**
 The result class of uploading one part.
 */
@interface InspurOSSUploadPartResult : InspurOSSResult
@property (nonatomic, copy) NSString * eTag;
@end

/**
 The Part information. It's called by CompleteMultipartUpload().
 */
@interface InspurOSSPartInfo : NSObject<NSCopying>

/**
 The part number in this part upload.
 */
@property (nonatomic, assign) int32_t partNum;

/**
 ETag value of this part returned by OSS.
 */
@property (nonatomic, copy) NSString * eTag;

/**
 The part size.
 */
@property (nonatomic, assign) int64_t size;

@property (nonatomic, assign) uint64_t crc64;

+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size __attribute__((deprecated("Use partInfoWithPartNum:eTag:size:crc64: to instead!")));
+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size crc64:(uint64_t)crc64;

- (NSDictionary *)entityToDictionary;

@end

/**
 The request class of completing a multipart upload.
 */
@interface InspurOSSCompleteMultipartUploadRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 Multipart upload Id
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 The content MD5 value.
 It's calculated according to RFC 1864 and encoded in base64.
 Though it's optional, it's recommended to turn it on for integrity check. 
 */
@property (nonatomic, copy) NSString * contentMd5;

/**
 All parts' information.
 */
@property (nonatomic, strong) NSArray * partInfos;

/**
 Server side callback parameter
 */
@property (nonatomic, copy) NSDictionary * callbackParam;

/**
 Callback variables 
 */
@property (nonatomic, copy) NSDictionary * callbackVar;

/**
 The metadata header
 */
@property (nonatomic, copy) NSDictionary * completeMetaHeader;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;

@end

/**
 The resutl class of completing a multipart upload.
 */
@interface OSSCompleteMultipartUploadResult : InspurOSSResult

/**
 The object's URL
 */
@property (nonatomic, copy) NSString * location;

/**
 ETag (entity tag).
 It's generated when the object is created. 
 */
@property (nonatomic, copy) NSString * eTag;

/**
 The callback response if the callback is specified.
 The resutl class of initiating a multipart upload.
 */
@property (nonatomic, copy) NSString * serverReturnJsonString;
@end

/**
 The request class of listing all parts that have been uploaded.
 */
@interface InspurOSSListPartsRequest : InspurOSSRequest

/**
 Bucket name
 The request class of uploading one part.*/
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 The max part count to return
 */
@property (nonatomic, assign) int maxParts;

/**
 The part number marker filter---only parts whose part number is greater than this value will be returned.
 */
@property (nonatomic, assign) int partNumberMarker;
@end

/**
The result class of listing uploaded parts.
*/
@interface InspurOSSListPartsResult : InspurOSSResult

/**
 The next part number marker. If the response does not include all data, this header specifies what's the start point for the next list call.
 */
@property (nonatomic, assign) int nextPartNumberMarker;

/**
 The max parts count to return.
 */
@property (nonatomic, assign) int maxParts;

/**
 Flag of truncated data in the response. If it's true, it means there're more data to come.
 If it's false, it means all data have been returned.
 */
@property (nonatomic, assign) BOOL isTruncated;

/**
 The array of the part information.
 */
@property (nonatomic, strong, nullable) NSArray * parts;
@end

/**
 The request class of listing all multipart uploads.
 */
@interface InspurOSSListMultipartUploadsRequest : InspurOSSRequest
/**
 Bucket name.
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The delimiter.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The prefix.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The max number of uploads.
 */
@property (nonatomic, assign) int32_t maxUploads;

/**
 The key marker filter.
 */
@property (nonatomic, copy) NSString * keyMarker;

/**
 The upload Id marker.
 */
@property (nonatomic, copy) NSString * uploadIdMarker;

/**
 The encoding type of the object in the response body.
 */
@property (nonatomic, copy) NSString * encodingType;

@end

/**
 The result class of listing multipart uploads.
 */
@interface InspurOSSListMultipartUploadsResult : InspurOSSResult
/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 The marker filter of the objects returned---all objects returned are greater than this marker in lexicographic order.
 */
@property (nonatomic, copy) NSString * keyMarker;

/**
 The delimiter to differentiate the folder object and file object.
 For object whose name ends with the delimiter, then it's treated as folder or common prefixes.
 */
@property (nonatomic, copy) NSString * delimiter;

/**
 The prefix of the objects returned----the returned objects must have this prefix.
 */
@property (nonatomic, copy) NSString * prefix;

/**
 The upload Id marker.
 */
@property (nonatomic, copy) NSString * uploadIdMarker;

/**
 The max entries to return. By default it's 100 and it could be up to 1000.
 */
@property (nonatomic, assign) int32_t maxUploads;

/**
 If not all results are returned this time, the response request includes the NextKeyMarker element to indicate the value of KeyMarker in the next request.
 */
@property (nonatomic, copy) NSString * nextKeyMarker;

/**
 If not all results are returned this time, the response request includes the NextUploadMarker element to indicate the value of UploadMarker in the next request.
 */
@property (nonatomic, copy) NSString * nextUploadIdMarker;

/**
 Flag of truncated result. If it's truncated, it means there's more entries to return.
 */
@property (nonatomic, assign) BOOL isTruncated;

@property (nonatomic, strong, nullable) NSArray * uploads;

/**
 The arrary of common prefixes. Each element is one common prefix.
 */
@property (nonatomic, strong) NSArray * commonPrefixes;
@end

/**
 Request to abort a multipart upload
 */
@interface InspurOSSAbortMultipartUploadRequest : InspurOSSRequest

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object name
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The multipart upload Id.
 */
@property (nonatomic, copy) NSString * uploadId;
@end

/**
 The result class of aborting a multipart upload
 */
@interface InspurOSSAbortMultipartUploadResult : InspurOSSResult
@end

/**
 The request class of multipart upload.
 */
@interface InspurOSSMultipartUploadRequest : InspurOSSRequest

/**
 The upload Id
 */
@property (nonatomic, copy) NSString * uploadId;

/**
 Bucket name
 */
@property (nonatomic, copy) NSString * bucketName;

/**
 Object object
 */
@property (nonatomic, copy) NSString * objectKey;

/**
 The local file path to upload from.
 */
@property (nonatomic, strong) NSURL * uploadingFileURL;

/**
 The part size, minimal value is 100KB.
 */
@property (nonatomic, assign) NSUInteger partSize;

/**
 Upload progress callback.
 It runs at the background thread (not UI thread).
 */
@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;

/**
 The callback parmeters
 */
@property (nonatomic, copy) NSDictionary * callbackParam;

/**
 The callback variables
 */
@property (nonatomic, copy) NSDictionary * callbackVar;

/**
 Content type
 */
@property (nonatomic, copy) NSString * contentType;

/**
 The metadata header
 */
@property (nonatomic, copy) NSDictionary * completeMetaHeader;

/**
 * the sha1 of content
 */
@property (nonatomic, copy) NSString *contentSHA1;

/**
 * the md5 of content
 */
@property (nonatomic, copy) NSString *md5String;

@property (nonatomic, copy) NSString * randomObjectName;


- (void)cancel;
@end

/**
 The request class of resumable upload.
 */
@interface InspurOSSResumableUploadRequest : InspurOSSMultipartUploadRequest


/**
 directory path about create record uploadId file 
 */
@property (nonatomic, copy) NSString * recordDirectoryPath;


/**
 need or not delete uploadId with cancel
 */
@property (nonatomic, assign) BOOL deleteUploadIdOnCancelling;

/**
 All running children requests
 */
@property (atomic, weak) InspurOSSRequest * runningChildrenRequest;

@end


/**
 The result class of resumable uploading
 */
@interface InspurOSSResumableUploadResult : InspurOSSResult

/**
 The callback response, if the callback is specified.
 */
@property (nonatomic, copy) NSString * serverReturnJsonString;

@end


/**
 for more information,Please refer to the link
 */
@interface InspurOSSCallBackRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@property (nonatomic, copy) NSString *objectName;
/**
 The callback parameters.when you set this value,there are required params as below:
 {
    "callbackUrl": xxx
    "callbackBody": xxx
 }
 */
@property (nonatomic, copy) NSDictionary *callbackParam;
/**
 The callback variables.
 */
@property (nonatomic, copy) NSDictionary *callbackVar;

@end



@interface InspurOSSCallBackResult : InspurOSSResult

@property (nonatomic, copy) NSDictionary *serverReturnXML;

/**
 If the callback is specified, this is the callback response result.
 */
@property (nonatomic, copy) NSString *serverReturnJsonString;

@end


/**
 for more information,Please refer to the link
 */
@interface InspurOSSImagePersistRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *fromBucket;

@property (nonatomic, copy) NSString *fromObject;

@property (nonatomic, copy) NSString *toBucket;

@property (nonatomic, copy) NSString *toObject;

@property (nonatomic, copy) NSString *action;

@end

@interface InspurOSSImagePersistResult : InspurOSSResult

@end

@interface InspurOSSCORSRule : NSObject

@property (nonatomic, strong, nonnull) NSString *ID;
@property (nonatomic, strong, nonnull) NSArray<NSString*> *allowedMethodList;
@property (nonatomic, strong, nonnull) NSArray<NSString*> *allowedOriginList;
@property (nonatomic, strong, nonnull) NSArray<NSString*> *allowedHeaderList;
@property (nonatomic, strong, nonnull) NSNumber *maxAgeSeconds;
@property (nonatomic, strong, nonnull) NSArray<NSString*> *exposeHeaderList;

- (NSString *)toRuleString;

@end

@interface InspurOSSDomainConfig : NSObject

@end

@interface InspurOSSPolicyStatement : NSObject

@end


@interface InspurOSSGetObjectVersionRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;

@end

@interface InspurOSSGetObjectVersionResult : InspurOSSResult

@property (nonatomic, strong, nonnull) NSArray* versionList;

@end


@interface InspurOSSDeleteObjectVersionRequest : InspurOSSRequest

@property (nonatomic, copy) NSString *bucketName;
@property (nonatomic, copy) NSString *objectName;
@property (nonatomic, copy) NSString *versionId;

@end

@interface InspurOSSDeleteObjectVersionResult : InspurOSSResult

@end


NS_ASSUME_NONNULL_END
