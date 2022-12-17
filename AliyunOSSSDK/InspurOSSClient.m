//
//  OSSClient.m
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/16/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import "InspurOSSClient.h"
#import "OSSDefine.h"
#import "OSSModel.h"
#import "InspurOSSUtil.h"
#import "OSSLog.h"
#import "OSSBolts.h"
#import "InspurOSSNetworking.h"
#import "OSSXMLDictionary.h"
#import "OSSIPv6Adapter.h"
#import "InspurOSSImageProcess.h"

#import "InspurOSSNetworkingRequestDelegate.h"
#import "InspurOSSAllRequestNeededMessage.h"
#import "InspurOSSURLRequestRetryHandler.h"
#import "InspurOSSHttpResponseParser.h"
#import "InspurOSSGetObjectACLRequest.h"
#import "InspurOSSDeleteMultipleObjectsRequest.h"
#import "InspurOSSGetBucketInfoRequest.h"
#import "InspurOSSPutSymlinkRequest.h"
#import "InspurOSSGetSymlinkRequest.h"
#import "InspurOSSRestoreObjectRequest.h"
#import "InspurOSSGetObjectTaggingRequest.h"
#import "InspurOSSPutObjectTaggingRequest.h"
#import "InspurOSSDeleteObjectTaggingRequest.h"
#import "InspurOSSGetObjectMetaDataRequest.h"

static NSString * const kClientRecordNameWithCommonPrefix = @"oss_partInfos_storage_name";
static NSString * const kClientRecordNameWithCRC64Suffix = @"-crc64";
static NSString * const kClientRecordNameWithSequentialSuffix = @"-sequential";
static NSUInteger const kClientMaximumOfChunks = 5000;   //max part number
static NSUInteger const kPartSizeAlign = 4 * 1024;   // part size byte alignment

static NSString * const kClientErrorMessageForEmptyFile = @"the length of file should not be 0!";
static NSString * const kClientErrorMessageForCancelledTask = @"This task has been cancelled!";

/**
 * extend OSSRequest to include the ref to networking request object
 */
@interface InspurOSSRequest ()

@property (nonatomic, strong) InspurOSSNetworkingRequestDelegate * requestDelegate;

@end

@interface InspurOSSClient()

- (void)enableCRC64WithFlag:(OSSRequestCRCFlag)flag requestDelegate:(InspurOSSNetworkingRequestDelegate *)delegate;
- (InspurOSSTask *)preChecksForRequest:(InspurOSSMultipartUploadRequest *)request;
- (void)checkRequestCrc64Setting:(InspurOSSRequest *)request;
- (InspurOSSTask *)checkNecessaryParamsOfRequest:(InspurOSSMultipartUploadRequest *)request;
- (InspurOSSTask *)checkPartSizeForRequest:(InspurOSSMultipartUploadRequest *)request;
- (NSUInteger)judgePartSizeForMultipartRequest:(InspurOSSMultipartUploadRequest *)request fileSize:(unsigned long long)fileSize;
- (unsigned long long)getSizeWithFilePath:(nonnull NSString *)filePath error:(NSError **)error;
- (NSString *)readUploadIdForRequest:(InspurOSSResumableUploadRequest *)request recordFilePath:(NSString **)recordFilePath sequential:(BOOL)sequential;
- (NSMutableDictionary *)localPartInfosDictoryWithUploadId:(NSString *)uploadId;
- (InspurOSSTask *)persistencePartInfos:(NSDictionary *)partInfos withUploadId:(NSString *)uploadId;
- (InspurOSSTask *)checkFileSizeWithRequest:(InspurOSSMultipartUploadRequest *)request;
+ (NSError *)cancelError;

@end

@implementation InspurOSSClient

static NSObject *lock;

- (instancetype)initWithEndpoint:(NSString *)endpoint credentialProvider:(id<OSSCredentialProvider>)credentialProvider {
    return [self initWithEndpoint:endpoint credentialProvider:credentialProvider clientConfiguration:[OSSClientConfiguration new]];
}

- (instancetype)initWithEndpoint:(NSString *)endpoint
              credentialProvider:(id<OSSCredentialProvider>)credentialProvider
             clientConfiguration:(OSSClientConfiguration *)conf {
    if (self = [super init]) {
        if (!lock) {
            lock = [NSObject new];
        }

        NSOperationQueue * queue = [NSOperationQueue new];
        // using for resumable upload and compat old interface
        queue.maxConcurrentOperationCount = 3;
        _ossOperationExecutor = [InspurOSSExecutor executorWithOperationQueue:queue];
        
        if (![endpoint oss_isNotEmpty]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"endpoint should not be nil or empty!"];
        }
        
        if ([endpoint rangeOfString:@"://"].location == NSNotFound) {
            endpoint = [@"https://" stringByAppendingString:endpoint];
        }
        
        NSURL *endpointURL = [NSURL URLWithString:endpoint];
        if ([endpointURL.scheme.lowercaseString isEqualToString:@"https"]) {
            if ([[OSSIPv6Adapter getInstance] isIPv4Address: endpointURL.host] || [[OSSIPv6Adapter getInstance] isIPv6Address: endpointURL.host]) {
                [NSException raise:NSInvalidArgumentException
                            format:@"unsupported format of endpoint, please use right endpoint format!"];
            }
        }
        
        self.endpoint = [endpoint oss_trim];
        self.credentialProvider = credentialProvider;
        self.clientConfiguration = conf;
        
        _imageProcess = [[InspurOSSImageProcess alloc] initWithEndPoint:endpoint];

        InspurOSSNetworkingConfiguration * netConf = [InspurOSSNetworkingConfiguration new];
        if (conf) {
            netConf.maxRetryCount = conf.maxRetryCount;
            netConf.timeoutIntervalForRequest = conf.timeoutIntervalForRequest;
            netConf.timeoutIntervalForResource = conf.timeoutIntervalForResource;
            netConf.enableBackgroundTransmitService = conf.enableBackgroundTransmitService;
            netConf.backgroundSessionIdentifier = conf.backgroundSesseionIdentifier;
            netConf.proxyHost = conf.proxyHost;
            netConf.proxyPort = conf.proxyPort;
            netConf.maxConcurrentRequestCount = conf.maxConcurrentRequestCount;
            netConf.enableFollowRedirects = conf.isFollowRedirectsEnable;
        }
        self.networking = [[InspurOSSNetworking alloc] initWithConfiguration:netConf];
    }
    return self;
}

- (InspurOSSTask *)invokeRequest:(InspurOSSNetworkingRequestDelegate *)request requireAuthentication:(BOOL)requireAuthentication {
    /* if content-type haven't been set, we set one */
    if (!request.allNeededMessage.contentType.oss_isNotEmpty
        && ([request.allNeededMessage.httpMethod isEqualToString:@"POST"] || [request.allNeededMessage.httpMethod isEqualToString:@"PUT"])) {

        request.allNeededMessage.contentType = [InspurOSSUtil detemineMimeTypeForFilePath:request.uploadingFileURL.path               uploadName:request.allNeededMessage.objectKey];
    }

    // Checks if the endpoint is in the excluded CName list.
    [self.clientConfiguration.cnameExcludeList enumerateObjectsUsingBlock:^(NSString *exclude, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self.endpoint hasSuffix:exclude]) {
            request.allNeededMessage.isHostInCnameExcludeList = YES;
            *stop = YES;
        }
    }];

    id<OSSRequestInterceptor> uaSetting = [[OSSUASettingInterceptor alloc] initWithClientConfiguration:self.clientConfiguration];
    [request.interceptors addObject:uaSetting];

    /* check if the authentication is required */
    if (requireAuthentication) {
        id<OSSRequestInterceptor> signer = [[OSSSignerInterceptor alloc] initWithCredentialProvider:self.credentialProvider];
        [request.interceptors addObject:signer];
    }

    request.isHttpdnsEnable = self.clientConfiguration.isHttpdnsEnable;
    request.isPathStyleAccessEnable = self.clientConfiguration.isPathStyleAccessEnable;
    request.isCustomPathPrefixEnable = self.clientConfiguration.isCustomPathPrefixEnable;
    
    return [_networking sendRequest:request];
}


#pragma implement restful apis

- (InspurOSSTask *)getService:(InspurOSSGetServiceRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetService];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetService;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)listService:(InspurOSSListPageServiceRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeListService];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeListService;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)queryBucketExist:(InspurOSSQueryBucketExistRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeQueryBucketExist];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodHEAD;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeQueryBucketExist;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketLocation:(InspurOSSGetBucketLocationRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketLocation];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketLocation;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketACL:(InspurOSSPutBucketACLRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionary];
    [headerParams oss_setObject:request.acl forKey:OSSHttpHeaderBucketACL];

    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"acl"];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketACL];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    neededMsg.headerParams = headerParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketACL;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];

}

- (InspurOSSTask *)getBucketCORS:(InspurOSSGetBucketCORSRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketCORS];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketCORS;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketCORS:(InspurOSSPutBucketCORSRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketCORS];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"cors"];
    
    NSMutableString *rules = [NSMutableString new];
    for (OSSCORSRule *rule in request.bucketCORSRuleList) {
        [rules appendFormat:@"<CORSRule>%@</CORSRule>", [rule toRuleString]];
    }
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><CORSConfiguration>%@</CORSConfiguration>", rules];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketCORS;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketCORS:(InspurOSSDeleteBucketCORSRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketCORS];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"cors"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketCORS;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketVersioning:(InspurOSSGetVersioningRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketVersioning];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketVersioning;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketVersioning:(InspurOSSPutVersioningRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketVersioning];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"versioning"];
    
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><VersioningConfiguration><Status>%@</Status></VersioningConfiguration>", request.enable];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketVersioning;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketEncryption:(InspurOSSGetBucketEncryptionRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketEncryption];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketEncryption;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}
- (InspurOSSTask *)putBucketEncryption:(InspurOSSPutBucketEncryptionRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketEncryption];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"encryption"];
    
    NSMutableString *rule = [NSMutableString new];
    [rule appendFormat:@"<SSEAlgorithm>%@</SSEAlgorithm>", request.sseAlgorithm ? : @""];
    if (request.masterId) {
        [rule appendFormat:@"<KMSMasterKeyID>%@</KMSMasterKeyID>", request.masterId];
    }
    NSString *serverSideDefault = [NSString stringWithFormat:@"<ApplyServerSideEncryptionByDefault>%@</ApplyServerSideEncryptionByDefault>",rule];
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><ServerSideEncryptionConfiguration><Rule>%@</Rule></ServerSideEncryptionConfiguration>", serverSideDefault];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketEncryption;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketEncryption:(InspurOSSDeleteBucketEncryptionRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketEncryption];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"encryption"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketEncryption;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}


- (InspurOSSTask *)getBucketWebsite:(InspurOSSGetBucketWebsiteRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketWebsite];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketWebsite;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketWebsite:(InspurOSSPutBucketWebsiteRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketWebsite];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"website"];
    
    NSMutableString *rule = [NSMutableString new];
    if (request.indexDocument) {
        [rule appendFormat:@"<IndexDocument><Suffix>%@</Suffix></IndexDocument>", request.indexDocument];
    }
    
    if (request.errroDocument) {
        [rule appendFormat:@"<ErrorDocument><Key>%@</Key></ErrorDocument>", request.errroDocument];
    }
    
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><WebsiteConfiguration>%@</WebsiteConfiguration>", rule];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketEncryption;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketWebsite:(InspurOSSDeleteBucketWebsiteRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketWebsite];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"website"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketWebsite;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}


- (InspurOSSTask *)getBucketDomain:(InspurOSSGetBucketDomainRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketDomain];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketDomain;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketDomain:(InspurOSSPutBucketDomainRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketDomain];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"domain"];
        
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:request.domainList options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;
    if (jsonData) {
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    requestDelegate.uploadingData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketDomain;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketDomain:(InspurOSSDeleteBucketDomainRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketDomain];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"domain"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketDomain;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}


- (InspurOSSTask *)getBucketLifeCycle:(InspurOSSGetBucketLifeCycleRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketLifeCycle];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketLifeCycle;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketLifeCycle:(InspurOSSPutBucketLifeCycleRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketLifeCycle];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"lifecycle"];
    
    NSString *rule = @"";
    
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><LifecycleConfiguration>%@</LifecycleConfiguration>", rule];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketLifeCycle;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketLifeCycle:(InspurOSSDeleteBucketLifeCycleRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketLifeCycle];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"lifecycle"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketLifeCycle;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketPolicy:(InspurOSSGetBucketPolicyRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketPolicy];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.params = [request requestParams];
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketPolicy;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putBucketPolicy:(InspurOSSPutBucketPolicyRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];

    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutBucketPolicy];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"policy"];
    
    NSString *bodyString = @"";
    NSDictionary *dictionary = @{
        @"Version": request.policyVersion,
        @"Statement": request.statementList
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingSortedKeys
                                                         error:nil];
    if (jsonData) {
        bodyString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutBucketLifeCycle;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucketPolicy:(InspurOSSDeleteBucketPolicyRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"policy"];
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucketLifeCycle];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucketLifeCycle;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}



# pragma mark - Private Methods

- (void)enableCRC64WithFlag:(OSSRequestCRCFlag)flag requestDelegate:(InspurOSSNetworkingRequestDelegate *)delegate
{
    switch (flag) {
        case OSSRequestCRCOpen:
            delegate.crc64Verifiable = YES;
            break;
        case OSSRequestCRCClosed:
            delegate.crc64Verifiable = NO;
            break;
        default:
            delegate.crc64Verifiable = self.clientConfiguration.crc64Verifiable;
            break;
    }
}

- (InspurOSSTask *)preChecksForRequest:(InspurOSSMultipartUploadRequest *)request
{
    InspurOSSTask *preTask = [self checkFileSizeWithRequest:request];
    if (preTask) {
        return preTask;
    }
    
    preTask = [self checkNecessaryParamsOfRequest:request];
    if (preTask) {
        return preTask;
    }
    
    preTask = [self checkPartSizeForRequest:request];
    if (preTask) {
        return preTask;
    }
    
    
    return preTask;
}

- (void)checkRequestCrc64Setting:(InspurOSSRequest *)request
{
    if (request.crcFlag == OSSRequestCRCUninitialized)
    {
        if (self.clientConfiguration.crc64Verifiable)
        {
            request.crcFlag = OSSRequestCRCOpen;
        }else
        {
            request.crcFlag = OSSRequestCRCClosed;
        }
    }
}

- (InspurOSSTask *)checkNecessaryParamsOfRequest:(InspurOSSMultipartUploadRequest *)request
{
    NSError *error = nil;
    if (![request.bucketName oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"checkNecessaryParamsOfRequest requires nonnull bucketName!"}];
    }else if (![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"checkNecessaryParamsOfRequest requires nonnull uploadingFileURL!"}];
    }
    
    InspurOSSTask *errorTask = nil;
    if (error) {
        errorTask = [InspurOSSTask taskWithError:error];
    }
    
    return errorTask;
}

- (InspurOSSTask *)checkPartSizeForRequest:(InspurOSSMultipartUploadRequest *)request
{
    InspurOSSTask *errorTask = nil;
    unsigned long long fileSize = [self getSizeWithFilePath:request.uploadingFileURL.path error:nil];
    
    if (request.partSize == 0 || (fileSize > 102400 && request.partSize < 102400)) {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"Part size must be greater than equal to 100KB"}];
        errorTask = [InspurOSSTask taskWithError:error];
    }
    return errorTask;
}

- (NSUInteger)judgePartSizeForMultipartRequest:(InspurOSSMultipartUploadRequest *)request fileSize:(unsigned long long)fileSize
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
    BOOL divisible = (fileSize % request.partSize == 0);
    NSUInteger partCount = (fileSize / request.partSize) + (divisible? 0 : 1);
    
    if(partCount > kClientMaximumOfChunks)
    {
        NSUInteger partSize = fileSize / (kClientMaximumOfChunks - 1);
        request.partSize = [self ceilPartSize:partSize];
        partCount = (fileSize / request.partSize) + ((fileSize % request.partSize == 0) ? 0 : 1);
    }
    return partCount;
#pragma clang diagnostic pop
}

- (NSUInteger)ceilPartSize:(NSUInteger)partSize {
    partSize = (((partSize + (kPartSizeAlign - 1)) / kPartSizeAlign) * kPartSizeAlign);
    return partSize;
}

- (unsigned long long)getSizeWithFilePath:(nonnull NSString *)filePath error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attributes = [fm attributesOfItemAtPath:filePath error:error];
    return attributes.fileSize;
}

- (NSString *)readUploadIdForRequest:(InspurOSSResumableUploadRequest *)request recordFilePath:(NSString **)recordFilePath sequential:(BOOL)sequential
{
    NSString *uploadId = nil;
    NSString *record = [NSString stringWithFormat:@"%@%@%@%lu", request.md5String, request.bucketName, request.objectKey, (unsigned long)request.partSize];
    if (sequential) {
        record = [record stringByAppendingString:kClientRecordNameWithSequentialSuffix];
    }
    if (request.crcFlag == OSSRequestCRCOpen) {
        record = [record stringByAppendingString:kClientRecordNameWithCRC64Suffix];
    }
    
    NSData *data = [record dataUsingEncoding:NSUTF8StringEncoding];
    NSString *recordFileName = [InspurOSSUtil dataMD5String:data];
    *recordFilePath = [request.recordDirectoryPath stringByAppendingPathComponent: recordFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath: *recordFilePath]) {
        NSFileHandle * read = [NSFileHandle fileHandleForReadingAtPath:*recordFilePath];
        uploadId = [[NSString alloc] initWithData:[read readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        [read closeFile];
    } else {
        [fileManager createFileAtPath:*recordFilePath contents:nil attributes:nil];
    }
    return uploadId;
}

#pragma mark - sequential multipart upload

- (NSMutableDictionary *)localPartInfosDictoryWithUploadId:(NSString *)uploadId
{
    NSMutableDictionary *localPartInfoDict = nil;
    NSString *partInfosDirectory = [[NSString oss_documentDirectory] stringByAppendingPathComponent:kClientRecordNameWithCommonPrefix];
    NSString *partInfosPath = [partInfosDirectory stringByAppendingPathComponent:uploadId];
    BOOL isDirectory;
    NSFileManager *defaultFM = [NSFileManager defaultManager];
    if (!([defaultFM fileExistsAtPath:partInfosDirectory isDirectory:&isDirectory] && isDirectory))
    {
        if (![defaultFM createDirectoryAtPath:partInfosDirectory
                                       withIntermediateDirectories:NO
                                                        attributes:nil error:nil]) {
            OSSLogError(@"create Directory(%@) failed!",partInfosDirectory);
        };
    }
    
    if (![defaultFM fileExistsAtPath:partInfosPath])
    {
        if (![defaultFM createFileAtPath:partInfosPath
                               contents:nil
                             attributes:nil])
        {
            OSSLogError(@"create local partInfo file failed!");
        }
    }
    localPartInfoDict = [[NSMutableDictionary alloc] initWithContentsOfURL:[NSURL fileURLWithPath:partInfosPath]];
    return localPartInfoDict;
}

- (InspurOSSTask *)persistencePartInfos:(NSDictionary *)partInfos withUploadId:(NSString *)uploadId
{
    NSString *filePath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:kClientRecordNameWithCommonPrefix] stringByAppendingPathComponent:uploadId];
    if (![partInfos writeToFile:filePath atomically:YES])
    {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeFileCantWrite
                                         userInfo:@{OSSErrorMessageTOKEN: @"uploadId for this task can't be stored persistentially!"}];
        OSSLogDebug(@"[Error]: %@", error);
        return [InspurOSSTask taskWithError:error];
    }
    return nil;
}

- (InspurOSSTask *)checkPutObjectFileURL:(InspurOSSPutObjectRequest *)request {
    NSError *error = nil;
    if (!request.uploadingFileURL || ![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"Please check your request's uploadingFileURL!"}];
    } else {
        NSFileManager *dfm = [NSFileManager defaultManager];
        NSDictionary *attributes = [dfm attributesOfItemAtPath:request.uploadingFileURL.path error:&error];
        unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
        if (!error && fileSize == 0) {
            error = [NSError errorWithDomain:OSSClientErrorDomain
                                        code:OSSClientErrorCodeInvalidArgument
                                    userInfo:@{OSSErrorMessageTOKEN: kClientErrorMessageForEmptyFile}];
        }
    }
    
    if (error) {
        return [InspurOSSTask taskWithError:error];
    } else {
        return [InspurOSSTask taskWithResult:nil];
    }
}

- (InspurOSSTask *)checkFileSizeWithRequest:(InspurOSSMultipartUploadRequest *)request {
    NSError *error = nil;
    if (!request.uploadingFileURL || ![request.uploadingFileURL.path oss_isNotEmpty]) {
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeInvalidArgument
                                userInfo:@{OSSErrorMessageTOKEN: @"Please check your request's uploadingFileURL!"}];
    }
    else
    {
        NSFileManager *dfm = [NSFileManager defaultManager];
        NSDictionary *attributes = [dfm attributesOfItemAtPath:request.uploadingFileURL.path error:&error];
        unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
        if (!error && fileSize == 0) {
            error = [NSError errorWithDomain:OSSClientErrorDomain
                                        code:OSSClientErrorCodeInvalidArgument
                                    userInfo:@{OSSErrorMessageTOKEN: kClientErrorMessageForEmptyFile}];
        }
    }
    
    if (error) {
        return [InspurOSSTask taskWithError:error];
    } else {
        return nil;
    }
}

+ (NSError *)cancelError{
    static NSError *error = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        error = [NSError errorWithDomain:OSSClientErrorDomain
                                    code:OSSClientErrorCodeTaskCancelled
                                userInfo:@{OSSErrorMessageTOKEN: kClientErrorMessageForCancelledTask}];
    });
    return error;
}

- (void)dealloc{
    [self.networking.session invalidateAndCancel];
}

@end


@implementation InspurOSSClient (Bucket)

- (InspurOSSTask *)createBucket:(InspurOSSCreateBucketRequest *)request {
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *headerParams = [NSMutableDictionary dictionary];
    [headerParams oss_setObject:request.xOssACL forKey:OSSHttpHeaderBucketACL];
    
    if (request.location) {
        requestDelegate.uploadingData = [InspurOSSUtil constructHttpBodyForCreateBucketWithLocation:request.location];
    }
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCreateBucket];
    
    /*
    NSString *bodyString = [NSString stringWithFormat:@"<?xml version='1.0' encoding='UTF-8'?><CreateBucketConfiguration><StorageClass>%@</StorageClass></CreateBucketConfiguration>", request.storageClassAsString];
    requestDelegate.uploadingData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
     */
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.headerParams = headerParams;
    neededMsg.contentMd5 = md5String;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeCreateBucket;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteBucket:(InspurOSSDeleteObjectRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteBucket];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteBucket;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucket:(InspurOSSGetBucketRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucket];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucket;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketInfo:(InspurOSSGetBucketInfoRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketInfo];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketInfo;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getBucketACL:(InspurOSSGetBucketACLRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetBucketACL];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetBucketACL;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}



@end

@implementation InspurOSSClient (Object)

- (InspurOSSTask *)headObject:(InspurOSSHeadObjectRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeHeadObject];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodHEAD;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeHeadObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getObject:(InspurOSSGetObjectRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSString * rangeString = nil;
    if (request.range) {
        rangeString = [request.range toHeaderString];
    }
    if (request.downloadProgress) {
        requestDelegate.downloadProgress = request.downloadProgress;
    }
    if (request.onRecieveData) {
        requestDelegate.onRecieveData = request.onRecieveData;
    }
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:request.xOssProcess forKey:OSSHttpQueryProcess];
    
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    
    requestDelegate.responseParser = responseParser;
    requestDelegate.responseParser.downloadingFileURL = request.downloadToFileURL;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.range = rangeString;
    neededMsg.params = params;
    neededMsg.headerParams = request.headerFields;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getObjectACL:(InspurOSSGetObjectACLRequest *)request
{
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObjectACL];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"acl"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetObjectACL;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putObject:(InspurOSSPutObjectRequest *)request
{
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    
    if (request.uploadingData) {
        requestDelegate.uploadingData = request.uploadingData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadingData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadingFileURL) {
        InspurOSSTask *checkIfEmptyTask = [self checkPutObjectFileURL:request];
        if (checkIfEmptyTask.error) {
            return checkIfEmptyTask;
        }
        requestDelegate.uploadingFileURL = request.uploadingFileURL;
    }
    
    if (request.uploadProgress) {
        requestDelegate.uploadProgress = request.uploadProgress;
    }
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    
    [headerParams oss_setObject:[request.callbackParam base64JsonString] forKey:OSSHttpHeaderXOSSCallback];
    [headerParams oss_setObject:[request.callbackVar base64JsonString] forKey:OSSHttpHeaderXOSSCallbackVar];
    [headerParams oss_setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    [headerParams oss_setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    [headerParams oss_setObject:request.expires forKey:OSSHttpHeaderExpires];
    [headerParams oss_setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    if (!request.objectKey || ![request.objectKey oss_isNotEmpty]) {
        [params oss_setObject:@"true" forKey:OSSHttpHeaderRandomObjectName];
    }
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = params;
    if (!request.objectKey || ![request.objectKey oss_isNotEmpty]) {
        neededMsg.objectKey = [InspurOSSUtil randomObjectName];
    }
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.contentType = request.contentType;
    neededMsg.headerParams = headerParams;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putObjectACL:(InspurOSSPutObjectACLRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionary];
    [headerParams oss_setObject:request.acl forKey:OSSHttpHeaderBucketACL];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary]; 
    [params oss_setObject:@"" forKey:@"acl"];
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObjectACL];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = params;
    neededMsg.headerParams = headerParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutObjectACL;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putObjectMetaData:(InspurOSSPutObjectMetaRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    if (request.uploadRetryCallback) {
        requestDelegate.retryCallback = request.uploadRetryCallback;
    }
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObjectMetaData];
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"metadata"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = params;
    neededMsg.headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutObjectMetaData;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)appendObject:(InspurOSSAppendObjectRequest *)request
{
    return [self appendObject:request withCrc64ecma:nil];
}

- (InspurOSSTask *)appendObject:(InspurOSSAppendObjectRequest *)request withCrc64ecma:(nullable NSString *)crc64ecma
{
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.lastCRC = crc64ecma;
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    
    if (request.uploadingData)
    {
        requestDelegate.uploadingData = request.uploadingData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadingData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadingFileURL) {
        requestDelegate.uploadingFileURL = request.uploadingFileURL;
    }
    if (request.uploadProgress) {
        requestDelegate.uploadProgress = request.uploadProgress;
    }
    
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    [headerParams oss_setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    [headerParams oss_setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    [headerParams oss_setObject:request.expires forKey:OSSHttpHeaderExpires];
    [headerParams oss_setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"append"];
    [params oss_setObject:[@(request.appendPosition) stringValue] forKey:@"position"];
    
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeAppendObject];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.contentType = request.contentType;
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.headerParams = headerParams;
    neededMsg.params = params;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeAppendObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteObject:(InspurOSSDeleteObjectRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObject];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteMultipleObjects:(InspurOSSDeleteMultipleObjectsRequest *)request
{
    if ([request.keys count] == 0) {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"keys should not be empty"}];
        return [InspurOSSTask taskWithError:error];
    }
    
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    request.quiet = NO;
    requestDelegate.uploadingData = [InspurOSSUtil constructHttpBodyForDeleteMultipleObjects:request.keys quiet:request.quiet];
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteMultipleObjects];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"delete"];
    [params oss_setObject:request.encodingType forKey:@"encoding-type"];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.bucketName;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteMultipleObjects;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)copyObject:(InspurOSSCopyObjectRequest *)request {
    NSString *copySourceHeader = nil;
    if (request.sourceCopyFrom) {
        copySourceHeader = request.sourceCopyFrom;
    } else {
        if (![request.sourceBucketName oss_isNotEmpty]) {
            NSError *error = [NSError errorWithDomain:OSSClientErrorDomain code:OSSClientErrorCodeInvalidArgument userInfo:@{NSLocalizedDescriptionKey: @"sourceBucketName should not be empty!"}];
            return [InspurOSSTask taskWithError:error];
        }
        
        if (![request.sourceObjectKey oss_isNotEmpty]) {
            NSError *error = [NSError errorWithDomain:OSSClientErrorDomain code:OSSClientErrorCodeInvalidArgument userInfo:@{NSLocalizedDescriptionKey: @"sourceObjectKey should not be empty!"}];
            return [InspurOSSTask taskWithError:error];
        }
        
        copySourceHeader = [NSString stringWithFormat:@"/%@/%@",request.bucketName, request.sourceObjectKey.oss_urlEncodedString];
    }
    
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    [headerParams oss_setObject:copySourceHeader forKey:OSSHttpHeaderCopySource];
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCopyObject];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.contentType = request.contentType;
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.headerParams = headerParams;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeCopyObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putSymlink:(InspurOSSPutSymlinkRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutSymlink];
    
    NSMutableDictionary *headerFields = [NSMutableDictionary dictionary];
    [headerFields oss_setObject:[request.targetObjectName oss_urlEncodedString] forKey:OSSHttpHeaderSymlinkTarget];
    if (request.objectMeta) {
        [headerFields addEntriesFromDictionary:request.objectMeta];
    }
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    neededMsg.headerParams = headerFields;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypePutSymlink;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getSymlink:(InspurOSSGetSymlinkRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetSymlink];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetSymlink;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)restoreObject:(InspurOSSRestoreObjectRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeRestoreObject];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeRestoreObject;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getObjectTagging:(InspurOSSGetObjectTaggingRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObjectTagging];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetObjectTagging;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)putObjectTagging:(InspurOSSPutObjectTaggingRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypePutObjectTagging];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    NSString *xmlString = [[request entityToDictionary] oss_XMLString];
    requestDelegate.uploadingData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
    requestDelegate.operType = OSSOperationTypePutObjectTagging;

    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteObjectTagging:(InspurOSSDeleteObjectTaggingRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteObjectTagging];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteObjectTagging;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)getObjectVersions:(InspurOSSGetObjectVersionRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeGetObjectVersions];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = request.requestParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeGetObjectVersions;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)deleteObjectVersion:(InspurOSSDeleteObjectVersionRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeDeleteObjectVersions];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:[request requestParams]];
    [params oss_setObject:request.versionId forKey:@"versionId"];
    [params oss_setObject:@"" forKey:@"versions"];

    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeDeleteObjectVersions;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

@end

@implementation InspurOSSClient (MultipartUpload)

- (InspurOSSTask *)listMultipartUploads:(InspurOSSListMultipartUploadsRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:[request requestParams]];
    [params oss_setObject:@"" forKey:@"uploads"];
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeListMultipartUploads];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeListMultipartUploads;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)multipartUploadInit:(InspurOSSInitMultipartUploadRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionaryWithDictionary:request.objectMeta];
    
    [headerParams oss_setObject:request.contentDisposition forKey:OSSHttpHeaderContentDisposition];
    [headerParams oss_setObject:request.contentEncoding forKey:OSSHttpHeaderContentEncoding];
    [headerParams oss_setObject:request.expires forKey:OSSHttpHeaderExpires];
    [headerParams oss_setObject:request.cacheControl forKey:OSSHttpHeaderCacheControl];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"uploads"];
    if (request.sequential) {
        [params oss_setObject:@"" forKey:@"sequential"];
    }
    if (!request.objectKey) {
        [params oss_setObject:@"true" forKey:OSSHttpHeaderRandomObjectName];
    }
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeInitMultipartUpload];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey ? : [InspurOSSUtil randomObjectName];
    neededMsg.contentType = request.contentType;
    neededMsg.params = params;
    neededMsg.headerParams = headerParams;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeInitMultipartUpload;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)uploadPart:(InspurOSSUploadPartRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:[@(request.partNumber) stringValue] forKey:@"partNumber"];
    [params oss_setObject:request.uploadId forKey:@"uploadId"];
    
    [self enableCRC64WithFlag:request.crcFlag requestDelegate:requestDelegate];
    if (request.uploadPartData) {
        requestDelegate.uploadingData = request.uploadPartData;
        if (requestDelegate.crc64Verifiable)
        {
            NSMutableData *mutableData = [NSMutableData dataWithData:request.uploadPartData];
            requestDelegate.contentCRC = [NSString stringWithFormat:@"%llu",[mutableData oss_crc64]];
        }
    }
    if (request.uploadPartFileURL) {
        requestDelegate.uploadingFileURL = request.uploadPartFileURL;
    }
    if (request.uploadPartProgress) {
        requestDelegate.uploadProgress = request.uploadPartProgress;
    }
    
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeUploadPart];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPUT;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectkey;
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.params = params;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeUploadPart;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)completeMultipartUpload:(InspurOSSCompleteMultipartUploadRequest *)request
{
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    NSMutableDictionary * headerParams = [NSMutableDictionary dictionary];
    if (request.partInfos) {
        requestDelegate.uploadingData = [InspurOSSUtil constructHttpBodyFromPartInfos:request.partInfos];
    }
    
    [headerParams oss_setObject:[request.callbackParam base64JsonString] forKey:OSSHttpHeaderXOSSCallback];
    [headerParams oss_setObject:[request.callbackVar base64JsonString] forKey:OSSHttpHeaderXOSSCallbackVar];
    
    if (request.completeMetaHeader) {
        [headerParams addEntriesFromDictionary:request.completeMetaHeader];
    }
    NSMutableDictionary * params = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.uploadId, @"uploadId", nil];
    
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeCompleteMultipartUpload];
    responseParser.crc64Verifiable = requestDelegate.crc64Verifiable;
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.contentMd5 = request.contentMd5;
    neededMsg.headerParams = headerParams;
    neededMsg.params = params;
    neededMsg.contentSHA1 = request.contentSHA1;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeCompleteMultipartUpload;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)listParts:(InspurOSSListPartsRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject: request.uploadId forKey: @"uploadId"];
    [params oss_setObject: [NSString stringWithFormat:@"%d",request.partNumberMarker] forKey: @"part-number-marker"];
    
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeListMultipart];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodGET;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeListMultipart;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)abortMultipartUpload:(InspurOSSAbortMultipartUploadRequest *)request {
    InspurOSSNetworkingRequestDelegate * requestDelegate = request.requestDelegate;
    
    NSMutableDictionary * params = [NSMutableDictionary dictionaryWithObjectsAndKeys:request.uploadId, @"uploadId", nil];
    requestDelegate.responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeAbortMultipartUpload];
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodDELETE;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectKey;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeAbortMultipartUpload;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

- (InspurOSSTask *)abortResumableMultipartUpload:(InspurOSSResumableUploadRequest *)request
{
    return [self abortMultipartUpload:request sequential:NO resumable:YES];
}

- (InspurOSSTask *)abortMultipartUpload:(InspurOSSMultipartUploadRequest *)request sequential:(BOOL)sequential resumable:(BOOL)resumable {
    
    InspurOSSTask *errorTask = nil;
    if(resumable) {
        InspurOSSResumableUploadRequest *resumableRequest = (InspurOSSResumableUploadRequest *)request;
        NSString *nameInfoString = [NSString stringWithFormat:@"%@%@%@%lu",request.md5String, resumableRequest.bucketName, resumableRequest.objectKey, (unsigned long)resumableRequest.partSize];
        if (sequential) {
            nameInfoString = [nameInfoString stringByAppendingString:kClientRecordNameWithSequentialSuffix];
        }
        if (request.crcFlag == OSSRequestCRCOpen) {
            nameInfoString = [nameInfoString stringByAppendingString:kClientRecordNameWithCRC64Suffix];
        }
        
        NSData *data = [nameInfoString dataUsingEncoding:NSUTF8StringEncoding];
        NSString *recordFileName = [InspurOSSUtil dataMD5String:data];
        NSString *recordFilePath = [NSString stringWithFormat:@"%@/%@",resumableRequest.recordDirectoryPath,recordFileName];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *partInfosFilePath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:kClientRecordNameWithCommonPrefix] stringByAppendingPathComponent:resumableRequest.uploadId];
        
        if([fileManager fileExistsAtPath:recordFilePath])
        {
            NSError *error;
            if (![fileManager removeItemAtPath:recordFilePath error:&error])
            {
                OSSLogDebug(@"[OSSSDKError]: %@", error);
            }
        }
        
        if ([fileManager fileExistsAtPath:partInfosFilePath]) {
            NSError *error;
            if (![fileManager removeItemAtPath:partInfosFilePath error:&error])
            {
                OSSLogDebug(@"[OSSSDKError]: %@", error);
            }
        }
        
        InspurOSSAbortMultipartUploadRequest * abort = [InspurOSSAbortMultipartUploadRequest new];
        abort.bucketName = request.bucketName;
        abort.objectKey = request.objectKey;
        if (request.uploadId) {
            abort.uploadId = request.uploadId;
        } else {
            abort.uploadId = [[NSString alloc] initWithData:[[NSFileHandle fileHandleForReadingAtPath:recordFilePath] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        }
        
        errorTask = [self abortMultipartUpload:abort];
    }else
    {
        InspurOSSAbortMultipartUploadRequest * abort = [InspurOSSAbortMultipartUploadRequest new];
        abort.bucketName = request.bucketName;
        abort.objectKey = request.objectKey;
        abort.uploadId = request.uploadId;
        errorTask = [self abortMultipartUpload:abort];
    }
    
    return errorTask;
}

- (InspurOSSTask *)multipartUpload:(InspurOSSMultipartUploadRequest *)request {
    return [self multipartUpload: request resumable: NO sequential: NO];
}

- (InspurOSSTask *)processCompleteMultipartUpload:(InspurOSSMultipartUploadRequest *)request partInfos:(NSArray<OSSPartInfo *> *)partInfos clientCrc64:(uint64_t)clientCrc64 recordFilePath:(NSString *)recordFilePath localPartInfosPath:(NSString *)localPartInfosPath
{
    InspurOSSCompleteMultipartUploadRequest * complete = [InspurOSSCompleteMultipartUploadRequest new];
    complete.bucketName = request.bucketName;
    complete.objectKey = request.objectKey ?: request.randomObjectName;
    complete.uploadId = request.uploadId;
    complete.partInfos = partInfos;
    complete.crcFlag = request.crcFlag;
    complete.contentSHA1 = request.contentSHA1;
    
    if (request.completeMetaHeader != nil) {
        complete.completeMetaHeader = request.completeMetaHeader;
    }
    if (request.callbackParam != nil) {
        complete.callbackParam = request.callbackParam;
    }
    if (request.callbackVar != nil) {
        complete.callbackVar = request.callbackVar;
    }
    
    InspurOSSTask * completeTask = [self completeMultipartUpload:complete];
    [completeTask waitUntilFinished];
    
    if (completeTask.error) {
        OSSLogVerbose(@"completeTask.error %@: ",completeTask.error);
        return completeTask;
    } else
    {
        if(recordFilePath && [[NSFileManager defaultManager] fileExistsAtPath:recordFilePath])
        {
            NSError *deleteError;
            if (![[NSFileManager defaultManager] removeItemAtPath:recordFilePath error:&deleteError])
            {
                OSSLogError(@"delete localUploadIdPath failed!Error: %@",deleteError);
            }
        }
        
        if (localPartInfosPath && [[NSFileManager defaultManager] fileExistsAtPath:localPartInfosPath])
        {
            NSError *deleteError;
            if (![[NSFileManager defaultManager] removeItemAtPath:localPartInfosPath error:&deleteError])
            {
                OSSLogError(@"delete localPartInfosPath failed!Error: %@",deleteError);
            }
        }
        OSSCompleteMultipartUploadResult * completeResult = completeTask.result;
        if (complete.crcFlag == OSSRequestCRCOpen && completeResult.remoteCRC64ecma)
        {
            uint64_t remote_crc64 = 0;
            NSScanner *scanner = [NSScanner scannerWithString:completeResult.remoteCRC64ecma];
            if ([scanner scanUnsignedLongLong:&remote_crc64])
            {
                OSSLogVerbose(@"resumableUpload local_crc64 %llu",clientCrc64);
                OSSLogVerbose(@"resumableUpload remote_crc64 %llu", remote_crc64);
                if (remote_crc64 != clientCrc64)
                {
                    NSString *errorMessage = [NSString stringWithFormat:@"local_crc64(%llu) is not equal to remote_crc64(%llu)!",clientCrc64,remote_crc64];
                    NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                                         code:OSSClientErrorCodeInvalidCRC
                                                     userInfo:@{OSSErrorMessageTOKEN:errorMessage}];
                    return [InspurOSSTask taskWithError:error];
                }
            }
        }
        
        OSSResumableUploadResult * result = [OSSResumableUploadResult new];
        result.requestId = completeResult.requestId;
        result.httpResponseCode = completeResult.httpResponseCode;
        result.httpResponseHeaderFields = completeResult.httpResponseHeaderFields;
        result.serverReturnJsonString = completeResult.serverReturnJsonString;
        result.remoteCRC64ecma = completeResult.remoteCRC64ecma;
        
        return [InspurOSSTask taskWithResult:result];
    }
}


- (InspurOSSTask *)resumableUpload:(InspurOSSResumableUploadRequest *)request
{
    return [self multipartUpload: request resumable: YES sequential: NO];
}

- (InspurOSSTask *)processListPartsWithObjectKey:(nonnull NSString *)objectKey bucket:(nonnull NSString *)bucket uploadId:(NSString * _Nonnull *)uploadId uploadedParts:(nonnull NSMutableArray *)uploadedParts uploadedLength:(NSUInteger *)uploadedLength totalSize:(unsigned long long)totalSize partSize:(NSUInteger)partSize
{
    BOOL isTruncated = NO;
    int nextPartNumberMarker = 0;
    NSUInteger bUploadedLength = 0;
    
    do {
        InspurOSSListPartsRequest * listParts = [InspurOSSListPartsRequest new];
        listParts.bucketName = bucket;
        listParts.objectKey = objectKey;
        listParts.uploadId = *uploadId;
        listParts.partNumberMarker = nextPartNumberMarker;
        InspurOSSTask * listPartsTask = [self listParts:listParts];
        [listPartsTask waitUntilFinished];
        
        if (listPartsTask.error)
        {
            isTruncated = NO;
            [uploadedParts removeAllObjects];
            if ([listPartsTask.error.domain isEqualToString: OSSServerErrorDomain] && labs(listPartsTask.error.code) == 404)
            {
                OSSLogVerbose(@"local record existes but the remote record is deleted");
                *uploadId = nil;
            } else
            {
                return listPartsTask;
            }
        }
        else
        {
            OSSListPartsResult *res = listPartsTask.result;
            isTruncated = res.isTruncated;
            nextPartNumberMarker = res.nextPartNumberMarker;
            OSSLogVerbose(@"resumableUpload listpart ok");
            if (res.parts.count > 0) {
                for (NSDictionary *part in res.parts) {
                    unsigned long long iPartSize = 0;
                    NSString *partSizeString = [part objectForKey:OSSSizeXMLTOKEN];
                    NSScanner *scanner = [NSScanner scannerWithString:partSizeString];
                    [scanner scanUnsignedLongLong:&iPartSize];
                    if (partSize == iPartSize) {
                        [uploadedParts addObject:part];
                        bUploadedLength += iPartSize;
                    }
                }
            }
        }
    } while (isTruncated);
    *uploadedLength = bUploadedLength;
    
    if (totalSize < bUploadedLength)
    {
        NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                             code:OSSClientErrorCodeCannotResumeUpload
                                         userInfo:@{OSSErrorMessageTOKEN: @"The uploading file is inconsistent with before"}];
        return [InspurOSSTask taskWithError: error];
    }
    return nil;
}

- (InspurOSSTask *)processResumableInitMultipartUpload:(InspurOSSInitMultipartUploadRequest *)request recordFilePath:(NSString *)recordFilePath
{
    InspurOSSTask *task = [self multipartUploadInit:request];
    [task waitUntilFinished];
    
    if(task.result && [recordFilePath oss_isNotEmpty])
    {
        OSSInitMultipartUploadResult *result = task.result;
        if (![result.uploadId oss_isNotEmpty])
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Can not get uploadId!"];
            NSError *error = [NSError errorWithDomain:OSSServerErrorDomain
                                                 code:OSSClientErrorCodeNilUploadid userInfo:@{OSSErrorMessageTOKEN:   errorMessage}];
            return [InspurOSSTask taskWithError:error];
        }
        
        NSFileManager *defaultFM = [NSFileManager defaultManager];
        if (![defaultFM fileExistsAtPath:recordFilePath])
        {
            if (![defaultFM createFileAtPath:recordFilePath contents:nil attributes:nil]) {
                NSError *error = [NSError errorWithDomain:OSSClientErrorDomain
                                                     code:OSSClientErrorCodeFileCantWrite
                                                 userInfo:@{OSSErrorMessageTOKEN: @"uploadId for this task can't be stored persistentially!"}];
                OSSLogDebug(@"[Error]: %@", error);
                return [InspurOSSTask taskWithError:error];
            }
        }
        NSFileHandle * write = [NSFileHandle fileHandleForWritingAtPath:recordFilePath];
        [write writeData:[result.uploadId dataUsingEncoding:NSUTF8StringEncoding]];
        [write closeFile];
    }
    return task;
}

- (InspurOSSTask *)upload:(InspurOSSMultipartUploadRequest *)request
        uploadIndex:(NSMutableArray *)alreadyUploadIndex
         uploadPart:(NSMutableArray *)alreadyUploadPart
              count:(NSUInteger)partCout
     uploadedLength:(NSUInteger *)uploadedLength
           fileSize:(unsigned long long)uploadFileSize
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount: 5];
    
    NSObject *localLock = [[NSObject alloc] init];
    
    OSSRequestCRCFlag crcFlag = request.crcFlag;
    __block InspurOSSTask *errorTask;
    __block NSMutableDictionary *localPartInfos = nil;
    
    if (crcFlag == OSSRequestCRCOpen) {
        localPartInfos = [self localPartInfosDictoryWithUploadId:request.uploadId];
    }
    
    if (!localPartInfos) {
        localPartInfos = [NSMutableDictionary dictionary];
    }
    
    NSError *readError;
    NSFileHandle *fileHande = [NSFileHandle fileHandleForReadingFromURL:request.uploadingFileURL error:&readError];
    if (readError) {
        return [InspurOSSTask taskWithError: readError];
    }
    
    NSData * uploadPartData;
    NSInteger realPartLength = request.partSize;
    __block BOOL hasError = NO;
    
    for (NSUInteger idx = 1; idx <= partCout; idx++)
    {
        if (request.isCancelled)
        {
            [queue cancelAllOperations];
            break;
        }
        
        if ([alreadyUploadIndex containsObject:@(idx)])
        {
            continue;
        }
        
        // while operationCount >= 5,the loop will stay here
        while (queue.operationCount >= 5) {
            [NSThread sleepForTimeInterval: 0.15f];
        }
        
        if (idx == partCout) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
            realPartLength = uploadFileSize - request.partSize * (idx - 1);
#pragma clang diagnostic pop
        }
        @autoreleasepool
        {
            
            if (@available(iOS 13.0, *)) {
                NSError *error = nil;
                [fileHande seekToOffset:request.partSize * (idx - 1) error:&error];
                if (error) {
                    hasError = YES;
                    errorTask = [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                           code:OSSClientErrorCodeFileCantRead
                                                                       userInfo:[error userInfo]]];
                    break;
                }
                error = nil;
                uploadPartData = [fileHande readDataUpToLength:realPartLength error:&error];
                if (error) {
                    hasError = YES;
                    errorTask = [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                           code:OSSClientErrorCodeFileCantRead
                                                                       userInfo:[error userInfo]]];
                    break;
                }
            } else {
                [fileHande seekToFileOffset: request.partSize * (idx - 1)];
                uploadPartData = [fileHande readDataOfLength:realPartLength];
            }
            
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                InspurOSSTask *uploadPartErrorTask = nil;
                
                [self executePartUpload:request
               totalBytesExpectedToSend:uploadFileSize
                         totalBytesSent:uploadedLength
                                  index:idx
                               partData:uploadPartData
                      alreadyUploadPart:alreadyUploadPart
                             localParts:localPartInfos
                              errorTask:&uploadPartErrorTask];
                
                if (uploadPartErrorTask != nil) {
                    @synchronized(localLock) {
                        if (!hasError) {
                            hasError = YES;
                            errorTask = uploadPartErrorTask;
                        }
                    }
                    uploadPartErrorTask = nil;
                }
            }];
            [queue addOperation:operation];
        }
    }
    [fileHande closeFile];
    [queue waitUntilAllOperationsAreFinished];
    
    localLock = nil;
    
    if (!errorTask && request.isCancelled) {
        errorTask = [InspurOSSTask taskWithError:[InspurOSSClient cancelError]];
    }
    
    return errorTask;
}

- (void)executePartUpload:(InspurOSSMultipartUploadRequest *)request totalBytesExpectedToSend:(unsigned long long)totalBytesExpectedToSend totalBytesSent:(NSUInteger *)totalBytesSent index:(NSUInteger)idx partData:(NSData *)partData alreadyUploadPart:(NSMutableArray *)uploadedParts localParts:(NSMutableDictionary *)localParts errorTask:(InspurOSSTask **)errorTask
{
    NSUInteger bytesSent = partData.length;
    
    InspurOSSUploadPartRequest * uploadPart = [InspurOSSUploadPartRequest new];
    uploadPart.bucketName = request.bucketName;
    uploadPart.objectkey = request.objectKey ?: request.randomObjectName;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
    uploadPart.partNumber = idx;
#pragma clang diagnostic pop
    uploadPart.uploadId = request.uploadId;
    uploadPart.uploadPartData = partData;
    uploadPart.contentMd5 = [InspurOSSUtil base64Md5ForData:partData];
    uploadPart.crcFlag = request.crcFlag;
    
    InspurOSSTask * uploadPartTask = [self uploadPart:uploadPart];
    [uploadPartTask waitUntilFinished];
    if (uploadPartTask.error) {
        if (labs(uploadPartTask.error.code) != 409) {
            *errorTask = uploadPartTask;
        }
    } else {
        OSSUploadPartResult * result = uploadPartTask.result;
        OSSPartInfo * partInfo = [OSSPartInfo new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
        partInfo.partNum = idx;
#pragma clang diagnostic pop
        partInfo.eTag = result.eTag;
        partInfo.size = bytesSent;
        uint64_t crc64OfPart;
        @try {
            NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
            [scanner scanUnsignedLongLong:&crc64OfPart];
            partInfo.crc64 = crc64OfPart;
        } @catch (NSException *exception) {
            OSSLogError(@"multipart upload error with nil remote crc64!");
        }
        
        @synchronized(lock){
            [uploadedParts addObject:partInfo];
            
            if (request.crcFlag == OSSRequestCRCOpen)
            {
                [self processForLocalPartInfos:localParts
                                      partInfo:partInfo
                                      uploadId:request.uploadId];
                [self persistencePartInfos:localParts
                              withUploadId:request.uploadId];
            }
            
            *totalBytesSent += bytesSent;
            if (request.uploadProgress)
            {
                request.uploadProgress(bytesSent, *totalBytesSent, totalBytesExpectedToSend);
            }
        }
    }
}

- (void)processForLocalPartInfos:(NSMutableDictionary *)localPartInfoDict partInfo:(OSSPartInfo *)partInfo uploadId:(NSString *)uploadId
{
    NSDictionary *partInfoDict = [partInfo entityToDictionary];
    NSString *keyString = [NSString stringWithFormat:@"%i",partInfo.partNum];
    [localPartInfoDict oss_setObject:partInfoDict forKey:keyString];
}

- (InspurOSSTask *)sequentialMultipartUpload:(InspurOSSResumableUploadRequest *)request
{
    return [self multipartUpload:request resumable:YES sequential:YES];
}

- (InspurOSSTask *)multipartUpload:(InspurOSSMultipartUploadRequest *)request resumable:(BOOL)resumable sequential:(BOOL)sequential
{
    if (resumable) {
        if (![request isKindOfClass:[InspurOSSResumableUploadRequest class]]) {
            NSError *typoError = [NSError errorWithDomain:OSSClientErrorDomain
                                                     code:OSSClientErrorCodeInvalidArgument
                                                 userInfo:@{OSSErrorMessageTOKEN: @"resumable multipart request should use instance of class OSSMultipartUploadRequest!"}];
            return [InspurOSSTask taskWithError: typoError];
        }
    }
    
    [self checkRequestCrc64Setting:request];
    InspurOSSTask *preTask = [self preChecksForRequest:request];
    if (preTask) {
        return preTask;
    }
    
    return [[InspurOSSTask taskWithResult:nil] continueWithExecutor:self.ossOperationExecutor withBlock:^id(InspurOSSTask *task) {
        
        __block NSUInteger uploadedLength = 0;
        uploadedLength = 0;
        __block InspurOSSTask * errorTask;
        __block NSString *uploadId;
        __block NSString *randomObjectName;

        NSError *error;
        unsigned long long uploadFileSize = [self getSizeWithFilePath:request.uploadingFileURL.path error:&error];
        if (error) {
            return [InspurOSSTask taskWithError:error];
        }
        
        NSUInteger partCount = [self judgePartSizeForMultipartRequest:request fileSize:uploadFileSize];
        
        if (partCount > 1 && request.partSize < 102400) {
            NSError *checkPartSizeError = [NSError errorWithDomain:OSSClientErrorDomain
                                                 code:OSSClientErrorCodeInvalidArgument
                                             userInfo:@{OSSErrorMessageTOKEN: @"Part size must be greater than equal to 100KB"}];
            return [InspurOSSTask taskWithError:checkPartSizeError];
        }
        
        if (request.isCancelled) {
            return [InspurOSSTask taskWithError:[InspurOSSClient cancelError]];
        }
        
        NSString *recordFilePath = nil;
        NSMutableArray * uploadedPart = [NSMutableArray array];
        NSString *localPartInfosPath = nil;
        NSDictionary *localPartInfos = nil;
        
        NSMutableArray<OSSPartInfo *> *uploadedPartInfos = [NSMutableArray array];
        NSMutableArray * alreadyUploadIndex = [NSMutableArray array];
        
        if (resumable) {
            InspurOSSResumableUploadRequest *resumableRequest = (InspurOSSResumableUploadRequest *)request;
            NSString *recordDirectoryPath = resumableRequest.recordDirectoryPath;
            request.md5String = [InspurOSSUtil fileMD5String:request.uploadingFileURL.path];
            if ([recordDirectoryPath oss_isNotEmpty])
            {
                uploadId = [self readUploadIdForRequest:resumableRequest recordFilePath:&recordFilePath sequential:sequential];
                OSSLogVerbose(@"local uploadId: %@,recordFilePath: %@",uploadId, recordFilePath);
            }
            
            if([uploadId oss_isNotEmpty])
            {
                localPartInfosPath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:kClientRecordNameWithCommonPrefix] stringByAppendingPathComponent:uploadId];
                
                localPartInfos = [[NSDictionary alloc] initWithContentsOfFile:localPartInfosPath];
                
                InspurOSSTask *listPartTask = [self processListPartsWithObjectKey:request.objectKey
                                                                     bucket:request.bucketName
                                                                   uploadId:&uploadId
                                                              uploadedParts:uploadedPart
                                                             uploadedLength:&uploadedLength
                                                                  totalSize:uploadFileSize
                                                                   partSize:request.partSize];
                if (listPartTask.error)
                {
                    return listPartTask;
                }
            }
            
            [uploadedPart enumerateObjectsUsingBlock:^(NSDictionary *partInfo, NSUInteger idx, BOOL * _Nonnull stop) {
                unsigned long long remotePartNumber = 0;
                NSString *partNumberString = [partInfo objectForKey: OSSPartNumberXMLTOKEN];
                NSScanner *scanner = [NSScanner scannerWithString: partNumberString];
                [scanner scanUnsignedLongLong: &remotePartNumber];
                
                NSString *remotePartEtag = [partInfo objectForKey:OSSETagXMLTOKEN];
                
                unsigned long long remotePartSize = 0;
                NSString *partSizeString = [partInfo objectForKey:OSSSizeXMLTOKEN];
                scanner = [NSScanner scannerWithString:partSizeString];
                [scanner scanUnsignedLongLong:&remotePartSize];
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
                
                OSSPartInfo * info = [[OSSPartInfo alloc] init];
                info.partNum = remotePartNumber;
                info.size = remotePartSize;
                info.eTag = remotePartEtag;
                
#pragma clang diagnostic pop
            
                NSDictionary *tPartInfo = [localPartInfos objectForKey: [@(remotePartNumber) stringValue]];
                if (request.crcFlag == OSSRequestCRCOpen) {
                    if (tPartInfo == nil) {
                        uploadedLength -= remotePartSize;
                        return;
                    }
                    info.crc64 = [tPartInfo[@"crc64"] unsignedLongLongValue];
                }

                [uploadedPartInfos addObject:info];
                [alreadyUploadIndex addObject:@(remotePartNumber)];
            }];
            
            if ([alreadyUploadIndex count] > 0 && request.uploadProgress && uploadFileSize) {
                request.uploadProgress(0, uploadedLength, uploadFileSize);
            }
        }
        
        if (![uploadId oss_isNotEmpty]) {
            InspurOSSInitMultipartUploadRequest *initRequest = [InspurOSSInitMultipartUploadRequest new];
            initRequest.bucketName = request.bucketName;
            initRequest.objectKey = request.objectKey;
            initRequest.contentType = request.contentType;
            initRequest.objectMeta = request.completeMetaHeader;
            initRequest.sequential = sequential;
            initRequest.crcFlag = request.crcFlag;
            
            InspurOSSTask *task = [self processResumableInitMultipartUpload:initRequest
                                                       recordFilePath:recordFilePath];
            if (task.error)
            {
                return task;
            }
            OSSInitMultipartUploadResult *initResult = (OSSInitMultipartUploadResult *)task.result;
            uploadId = initResult.uploadId;
            randomObjectName = initResult.objectName;
        }
        
        request.uploadId = uploadId;
        request.randomObjectName = randomObjectName;
        localPartInfosPath = [[[NSString oss_documentDirectory] stringByAppendingPathComponent:kClientRecordNameWithCommonPrefix] stringByAppendingPathComponent:uploadId];
        
        if (request.isCancelled)
        {
            if(resumable)
            {
                InspurOSSResumableUploadRequest *resumableRequest = (InspurOSSResumableUploadRequest *)request;
                if (resumableRequest.deleteUploadIdOnCancelling) {
                    InspurOSSTask *abortTask = [self abortMultipartUpload:request sequential:sequential resumable:resumable];
                    [abortTask waitUntilFinished];
                }
            }
            
            return [InspurOSSTask taskWithError:[InspurOSSClient cancelError]];
        }
        
        if (sequential) {
            errorTask = [self sequentialUpload:request
                                   uploadIndex:alreadyUploadIndex
                                    uploadPart:uploadedPartInfos
                                         count:partCount
                                uploadedLength:&uploadedLength
                                      fileSize:uploadFileSize];
        } else {
            errorTask = [self upload:request
                         uploadIndex:alreadyUploadIndex
                          uploadPart:uploadedPartInfos
                               count:partCount
                      uploadedLength:&uploadedLength
                            fileSize:uploadFileSize];
        }
        
        if(errorTask.error)
        {
            InspurOSSTask *abortTask;
            if(resumable)
            {
                InspurOSSResumableUploadRequest *resumableRequest = (InspurOSSResumableUploadRequest *)request;
                if (resumableRequest.deleteUploadIdOnCancelling || errorTask.error.code == OSSClientErrorCodeFileCantWrite) {
                    abortTask = [self abortMultipartUpload:request sequential:sequential resumable:resumable];
                }
            }else
            {
                abortTask =[self abortMultipartUpload:request sequential:sequential resumable:resumable];
            }
            [abortTask waitUntilFinished];
            
            return errorTask;
        }
        
        [uploadedPartInfos sortUsingComparator:^NSComparisonResult(OSSPartInfo *part1,OSSPartInfo* part2) {
            if(part1.partNum < part2.partNum){
                return NSOrderedAscending;
            }else if(part1.partNum > part2.partNum){
                return NSOrderedDescending;
            }else{
                return NSOrderedSame;
            }
        }];
        
        // 如果开启了crc64的校验
        uint64_t local_crc64 = 0;
        if (request.crcFlag == OSSRequestCRCOpen)
        {
            for (NSUInteger index = 0; index< uploadedPartInfos.count; index++)
            {
                uint64_t partCrc64 = uploadedPartInfos[index].crc64;
                int64_t partSize = uploadedPartInfos[index].size;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
                local_crc64 = [InspurOSSUtil crc64ForCombineCRC1:local_crc64 CRC2:partCrc64 length:partSize];
#pragma clang diagnostic pop
            }
        }
        return [self processCompleteMultipartUpload:request
                                          partInfos:uploadedPartInfos
                                        clientCrc64:local_crc64
                                     recordFilePath:recordFilePath
                                 localPartInfosPath:localPartInfosPath];
    }];
}

- (InspurOSSTask *)sequentialUpload:(InspurOSSMultipartUploadRequest *)request
                  uploadIndex:(NSMutableArray *)alreadyUploadIndex
                   uploadPart:(NSMutableArray *)alreadyUploadPart
                        count:(NSUInteger)partCout
               uploadedLength:(NSUInteger *)uploadedLength
                     fileSize:(unsigned long long)uploadFileSize
{
    OSSRequestCRCFlag crcFlag = request.crcFlag;
    __block InspurOSSTask *errorTask;
    __block NSMutableDictionary *localPartInfos = nil;
    
    if (crcFlag == OSSRequestCRCOpen) {
        localPartInfos = [self localPartInfosDictoryWithUploadId:request.uploadId];
    }
    
    if (!localPartInfos) {
        localPartInfos = [NSMutableDictionary dictionary];
    }
    
    NSError *readError;
    NSFileHandle *fileHande = [NSFileHandle fileHandleForReadingFromURL:request.uploadingFileURL error:&readError];
    if (readError) {
        return [InspurOSSTask taskWithError: readError];
    }
    
    NSUInteger realPartLength = request.partSize;
    
    for (int i = 1; i <= partCout; i++) {
        if (errorTask) {
            break;
        }
        
        if (request.isCancelled) {
            errorTask = [InspurOSSTask taskWithError:[InspurOSSClient cancelError]];
            break;
        }
        
        if ([alreadyUploadIndex containsObject:@(i)]) {
            continue;
        }
        
        realPartLength = request.partSize;
        [fileHande seekToFileOffset:request.partSize * (i - 1)];
        if (i == partCout) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
            realPartLength = uploadFileSize - request.partSize * (i - 1);
#pragma clang diagnostic pop
        }
        NSData *uploadPartData = [fileHande readDataOfLength:realPartLength];
        
        @autoreleasepool {
            InspurOSSUploadPartRequest * uploadPart = [InspurOSSUploadPartRequest new];
            uploadPart.bucketName = request.bucketName;
            uploadPart.objectkey = request.objectKey;
            uploadPart.partNumber = i;
            uploadPart.uploadId = request.uploadId;
            uploadPart.uploadPartData = uploadPartData;
            uploadPart.contentMd5 = [InspurOSSUtil base64Md5ForData:uploadPartData];
            uploadPart.crcFlag = request.crcFlag;
            
            InspurOSSTask * uploadPartTask = [self uploadPart:uploadPart];
            [uploadPartTask waitUntilFinished];
            
            if (uploadPartTask.error) {
                if (labs(uploadPartTask.error.code) != 409) {
                    errorTask = uploadPartTask;
                    break;
                } else {
                    NSDictionary *partDict = uploadPartTask.error.userInfo;
                    OSSPartInfo *partInfo = [[OSSPartInfo alloc] init];
                    partInfo.eTag = partDict[@"PartEtag"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
                    partInfo.partNum = [(NSString *)partDict[@"PartNumber"] integerValue];
                    partInfo.size = realPartLength;
#pragma clang diagnostic push
                    partInfo.crc64 = [[uploadPartData mutableCopy] oss_crc64];

                    [alreadyUploadPart addObject:partInfo];
                }
            } else {
                OSSUploadPartResult * result = uploadPartTask.result;
                OSSPartInfo * partInfo = [OSSPartInfo new];
                partInfo.partNum = i;
                partInfo.eTag = result.eTag;
                partInfo.size = realPartLength;
                uint64_t crc64OfPart;
                @try {
                    NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
                    [scanner scanUnsignedLongLong:&crc64OfPart];
                    partInfo.crc64 = crc64OfPart;
                } @catch (NSException *exception) {
                    OSSLogError(@"multipart upload error with nil remote crc64!");
                }
                
                [alreadyUploadPart addObject:partInfo];
                if (crcFlag == OSSRequestCRCOpen)
                {
                    [self processForLocalPartInfos:localPartInfos
                                          partInfo:partInfo
                                          uploadId:request.uploadId];
                    [self persistencePartInfos:localPartInfos
                                  withUploadId:request.uploadId];
                }
                
                @synchronized(lock) {
                    *uploadedLength += realPartLength;
                    if (request.uploadProgress)
                    {
                        request.uploadProgress(realPartLength, *uploadedLength, uploadFileSize);
                    }
                }
            }
        }
    }
    [fileHande closeFile];
    
    return errorTask;
}

@end

@implementation InspurOSSClient (PresignURL)

- (InspurOSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval {
    
    return [self presignConstrainURLWithBucketName:bucketName
                                     withObjectKey:objectKey
                            withExpirationInterval:interval
                                    withParameters:@{}];
}

- (InspurOSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters {
    
    return [self presignConstrainURLWithBucketName: bucketName
                                     withObjectKey: objectKey
                                        httpMethod: @"GET"
                            withExpirationInterval: interval
                                    withParameters: parameters];
}

- (InspurOSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters {
    return [self presignConstrainURLWithBucketName:bucketName
                                     withObjectKey:objectKey
                                        httpMethod:method
                            withExpirationInterval:interval
                                    withParameters:parameters
                                       withHeaders:@{}];
}

- (InspurOSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters
                                   contentType:(nullable NSString *)contentType
                                    contentMd5:(nullable NSString *)contentMd5 {
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    [header oss_setObject:contentType forKey:OSSHttpHeaderContentType];
    [header oss_setObject:contentMd5 forKey:OSSHttpHeaderContentMD5];

    return [self presignConstrainURLWithBucketName:bucketName
                                     withObjectKey:objectKey
                                        httpMethod:method
                            withExpirationInterval:interval
                                    withParameters:parameters
                                       withHeaders:header];
}

- (InspurOSSTask *)presignConstrainURLWithBucketName:(NSString *)bucketName
                                 withObjectKey:(NSString *)objectKey
                                    httpMethod:(NSString *)method
                        withExpirationInterval:(NSTimeInterval)interval
                                withParameters:(NSDictionary *)parameters
                                   withHeaders:(NSDictionary *)headers
{
    return [[InspurOSSTask taskWithResult:nil] continueWithBlock:^id(InspurOSSTask *task) {
        NSString * resource = [NSString stringWithFormat:@"/%@/%@", bucketName, objectKey];
        NSString * expires = [@((int64_t)[[NSDate oss_clockSkewFixedDate] timeIntervalSince1970] + interval) stringValue];
        NSString * xossHeader = @"";
        NSString * contentType = headers[OSSHttpHeaderContentType];
        NSString * contentMd5 = headers[OSSHttpHeaderContentMD5];
        NSString * patchContentType = contentType == nil ? @"" : contentType;
        NSString * patchContentMd5 = contentMd5 == nil ? @"" : contentMd5;

        NSMutableDictionary * params = [NSMutableDictionary dictionary];
        if (parameters.count > 0) {
            [params addEntriesFromDictionary:parameters];
        }
        
        if (headers) {
            NSMutableArray * params = [[NSMutableArray alloc] init];
            NSArray * sortedKey = [[headers allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj1 compare:obj2];
            }];
            for (NSString * key in sortedKey) {
                if ([key hasPrefix:@"x-oss-"]) {
                    [params addObject:[NSString stringWithFormat:@"%@:%@", key, [headers objectForKey:key]]];
                }
            }
            if ([params count]) {
                xossHeader = [NSString stringWithFormat:@"%@\n", [params componentsJoinedByString:@"\n"]];
            }
        }
        
        NSString * wholeSign = nil;
        OSSFederationToken *token = nil;
        NSError *error = nil;
        
        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]) {
            token = [(OSSFederationCredentialProvider *)self.credentialProvider getToken:&error];
            if (error) {
                return [InspurOSSTask taskWithError:error];
            }
        } else if ([self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]]) {
            token = [(OSSStsTokenCredentialProvider *)self.credentialProvider getToken];
        }
        
        if ([self.credentialProvider isKindOfClass:[OSSFederationCredentialProvider class]]
            || [self.credentialProvider isKindOfClass:[OSSStsTokenCredentialProvider class]])
        {
            [params oss_setObject:token.tToken forKey:@"security-token"];
            resource = [NSString stringWithFormat:@"%@?%@", resource, [InspurOSSUtil populateSubresourceStringFromParameter:params]];
            NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, patchContentMd5, patchContentType, expires, xossHeader, resource];
            wholeSign = [InspurOSSUtil sign:stringToSign withToken:token];
        } else {
            NSString * subresource = [InspurOSSUtil populateSubresourceStringFromParameter:params];
            if ([subresource length] > 0) {
                resource = [NSString stringWithFormat:@"%@?%@", resource, [InspurOSSUtil populateSubresourceStringFromParameter:params]];
            }
            NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, patchContentMd5, patchContentType, expires, xossHeader, resource];
            wholeSign = [self.credentialProvider sign:stringToSign error:&error];
            if (error) {
                return [InspurOSSTask taskWithError:error];
            }
        }
        
        NSArray * splitResult = [wholeSign componentsSeparatedByString:@":"];
        if ([splitResult count] != 2
            || ![((NSString *)[splitResult objectAtIndex:0]) hasPrefix:@"OSS "]) {
            return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeSignFailed
                                                          userInfo:@{OSSErrorMessageTOKEN: @"the returned signature is invalid"}]];
        }
        NSString * accessKey = [(NSString *)[splitResult objectAtIndex:0] substringFromIndex:4];
        NSString * signature = [splitResult objectAtIndex:1];
        
        BOOL isPathStyle = false;
        NSURL * endpointURL = [NSURL URLWithString:self.endpoint];
        NSString * host = endpointURL.host;
        NSString * port = @"";
        NSString * path = @"";
        NSString * pathStylePath = @"";
        if ([InspurOSSUtil isOssOriginBucketHost:host]) {
            host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
        } else if ([InspurOSSUtil isIncludeCnameExcludeList:self.clientConfiguration.cnameExcludeList host:host]) {
            if (self.clientConfiguration.isPathStyleAccessEnable) {
                isPathStyle = true;
            } else {
                host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
            }
        } else if ([[OSSIPv6Adapter getInstance] isIPv4Address:host] ||
                   [[OSSIPv6Adapter getInstance] isIPv6Address:host]) {
            isPathStyle = true;
        }
        if (endpointURL.port) {
            port = [NSString stringWithFormat:@":%@", endpointURL.port];
        }
        if (self.clientConfiguration.isCustomPathPrefixEnable) {
            path = endpointURL.path;
        }
        if (isPathStyle) {
            pathStylePath = [@"/" stringByAppendingString:bucketName];
        }
        
        [params oss_setObject:signature forKey:@"Signature"];
        [params oss_setObject:accessKey forKey:@"OSSAccessKeyId"];
        [params oss_setObject:expires forKey:@"Expires"];
        NSString * stringURL = [NSString stringWithFormat:@"%@://%@%@%@%@/%@?%@",
                                endpointURL.scheme,
                                host,
                                port,
                                path,
                                pathStylePath,
                                [InspurOSSUtil encodeURL:objectKey],
                                [InspurOSSUtil populateQueryStringFromParameter:params]];
        return [InspurOSSTask taskWithResult:stringURL];
    }];
}

- (InspurOSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                              withObjectKey:(NSString *)objectKey {
    
    return [self presignPublicURLWithBucketName:bucketName
                                  withObjectKey:objectKey
                                 withParameters:@{}];
}

- (InspurOSSTask *)presignPublicURLWithBucketName:(NSString *)bucketName
                              withObjectKey:(NSString *)objectKey
                             withParameters:(NSDictionary *)parameters {
    
    return [[InspurOSSTask taskWithResult:nil] continueWithBlock:^id(InspurOSSTask *task) {
        BOOL isPathStyle = false;
        NSURL * endpointURL = [NSURL URLWithString:self.endpoint];
        NSString * host = endpointURL.host;
        NSString * port = @"";
        NSString * path = @"";
        NSString * pathStylePath = @"";
        if ([InspurOSSUtil isOssOriginBucketHost:host]) {
            host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
        } else if ([InspurOSSUtil isIncludeCnameExcludeList:self.clientConfiguration.cnameExcludeList host:host]) {
            if (self.clientConfiguration.isPathStyleAccessEnable) {
                isPathStyle = true;
            } else {
                host = [NSString stringWithFormat:@"%@.%@", bucketName, host];
            }
        } else if ([[OSSIPv6Adapter getInstance] isIPv4Address:host] ||
                   [[OSSIPv6Adapter getInstance] isIPv6Address:host]) {
            isPathStyle = true;
        }
        if (endpointURL.port) {
            port = [NSString stringWithFormat:@":%@", endpointURL.port];
        }
        if (self.clientConfiguration.isCustomPathPrefixEnable) {
            path = endpointURL.path;
        }
        if (isPathStyle) {
            pathStylePath = [@"/" stringByAppendingString:bucketName];
        }
        if ([parameters count] > 0) {
            NSString * stringURL = [NSString stringWithFormat:@"%@://%@%@%@%@/%@?%@",
                                    endpointURL.scheme,
                                    host,
                                    port,
                                    path,
                                    pathStylePath,
                                    [InspurOSSUtil encodeURL:objectKey],
                                    [InspurOSSUtil populateQueryStringFromParameter:parameters]];
            return [InspurOSSTask taskWithResult:stringURL];
        } else {
            NSString * stringURL = [NSString stringWithFormat:@"%@://%@%@%@%@/%@",
                                    endpointURL.scheme,
                                    host,
                                    port,
                                    path,
                                    pathStylePath,
                                    [InspurOSSUtil encodeURL:objectKey]];
            return [InspurOSSTask taskWithResult:stringURL];
        }
    }];
}

@end

@implementation InspurOSSClient (Utilities)

- (BOOL)doesObjectExistInBucket:(NSString *)bucketName
                      objectKey:(NSString *)objectKey
                          error:(const NSError **)error {
    
    InspurOSSHeadObjectRequest * headRequest = [InspurOSSHeadObjectRequest new];
    headRequest.bucketName = bucketName;
    headRequest.objectKey = objectKey;
    InspurOSSTask * headTask = [self headObject:headRequest];
    [headTask waitUntilFinished];
    NSError *headError = headTask.error;
    if (!headError) {
        return YES;
    } else {
        if ([headError.domain isEqualToString: OSSServerErrorDomain] && labs(headError.code) == 404) {
            return NO;
        } else {
            if (error != nil) {
                *error = headError;
            }
            return NO;
        }
    }
}

@end

@implementation InspurOSSClient (ImageService)

- (InspurOSSTask *)imageActionPersist:(InspurOSSImagePersistRequest *)request
{
    if (![request.fromBucket oss_isNotEmpty]
        || ![request.fromObject oss_isNotEmpty]
        || ![request.toBucket oss_isNotEmpty]
        || ![request.toObject oss_isNotEmpty]
        || ![request.action oss_isNotEmpty]) {
        NSError *error = [NSError errorWithDomain:OSSTaskErrorDomain
                                             code:OSSClientErrorCodeInvalidArgument
                                         userInfo:@{OSSErrorMessageTOKEN: @"imagePersist parameters not be empty!"}];
        return [InspurOSSTask taskWithError:error];
    }
    
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:OSSHttpQueryProcess];
    
    requestDelegate.uploadingData = [InspurOSSUtil constructHttpBodyForImagePersist:request.action toBucket:request.toBucket toObjectKey:request.toObject];
    
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeImagePersist];
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.fromBucket;
    neededMsg.objectKey = request.fromObject;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeImagePersist;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

@end

@implementation InspurOSSClient (Callback)

- (InspurOSSTask *)triggerCallBack:(InspurOSSCallBackRequest *)request
{
    InspurOSSNetworkingRequestDelegate *requestDelegate = request.requestDelegate;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:OSSHttpQueryProcess];
    NSString *paramString = [request.callbackParam base64JsonString];
    NSString *variblesString = [request.callbackVar base64JsonString];
    requestDelegate.uploadingData = [InspurOSSUtil constructHttpBodyForTriggerCallback:paramString callbackVaribles:variblesString];
    NSString *md5String = [InspurOSSUtil base64Md5ForData:requestDelegate.uploadingData];
    
    InspurOSSHttpResponseParser *responseParser = [[InspurOSSHttpResponseParser alloc] initForOperationType:OSSOperationTypeTriggerCallBack];
    requestDelegate.responseParser = responseParser;
    
    InspurOSSAllRequestNeededMessage *neededMsg = [[InspurOSSAllRequestNeededMessage alloc] init];
    neededMsg.endpoint = self.endpoint;
    neededMsg.httpMethod = OSSHTTPMethodPOST;
    neededMsg.bucketName = request.bucketName;
    neededMsg.objectKey = request.objectName;
    neededMsg.contentMd5 = md5String;
    neededMsg.params = params;
    requestDelegate.allNeededMessage = neededMsg;
    
    requestDelegate.operType = OSSOperationTypeTriggerCallBack;
    
    return [self invokeRequest:requestDelegate requireAuthentication:request.isAuthenticationRequired];
}

@end
