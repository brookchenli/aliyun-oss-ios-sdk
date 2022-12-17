//
//  OSSHttpResponseParser.m
//  AliyunOSSSDK
//
//  Created by huaixu on 2018/1/22.
//  Copyright © 2018年 aliyun. All rights reserved.
//

#import "InspurOSSHttpResponseParser.h"

#import "NSMutableData+OSS_CRC.h"
#import "OSSXMLDictionary.h"
#import "OSSDefine.h"
#import "OSSModel.h"
#import "InspurOSSUtil.h"
#import "OSSLog.h"
#import "InspurOSSGetObjectACLResult.h"
#import "InspurOSSDeleteMultipleObjectsResult.h"
#import "InspurOSSGetBucketInfoResult.h"
#import "InspurOSSRestoreObjectResult.h"
#import "InspurOSSPutSymlinkResult.h"
#import "InspurOSSGetSymlinkResult.h"
#import "InspurOSSGetObjectTaggingResult.h"
#import "InspurOSSPutObjectTaggingResult.h"
#import "InspurOSSDeleteObjectTaggingResult.h"


@implementation InspurOSSHttpResponseParser {
    
    OSSOperationType _operationTypeForThisParser;
    
    NSFileHandle * _fileHandle;
    NSMutableData * _collectingData;
    NSHTTPURLResponse * _response;
    uint64_t _crc64ecma;
}

- (void)reset {
    _collectingData = nil;
    _fileHandle = nil;
    _response = nil;
}

- (instancetype)initForOperationType:(OSSOperationType)operationType {
    if (self = [super init]) {
        _operationTypeForThisParser = operationType;
    }
    return self;
}

- (void)consumeHttpResponse:(NSHTTPURLResponse *)response {
    _response = response;
}

- (InspurOSSTask *)consumeHttpResponseBody:(NSData *)data
{
    if (_crc64Verifiable&&(_operationTypeForThisParser == OSSOperationTypeGetObject))
    {
        NSMutableData *mutableData = [NSMutableData dataWithData:data];
        if (_crc64ecma != 0)
        {
            _crc64ecma = [InspurOSSUtil crc64ForCombineCRC1:_crc64ecma
                                                 CRC2:[mutableData oss_crc64]
                                               length:mutableData.length];
        }else
        {
            _crc64ecma = [mutableData oss_crc64];
        }
    }
    
    if (self.onRecieveBlock) {
        self.onRecieveBlock(data);
        return [InspurOSSTask taskWithResult:nil];
    }
    
    NSError * error;
    if (self.downloadingFileURL)
    {
        if (!_fileHandle)
        {
            NSFileManager * fm = [NSFileManager defaultManager];
            NSString * dirName = [[self.downloadingFileURL path] stringByDeletingLastPathComponent];
            if (![fm fileExistsAtPath:dirName])
            {
                [fm createDirectoryAtPath:dirName withIntermediateDirectories:YES attributes:nil error:&error];
            }
            if (![fm fileExistsAtPath:dirName] || error)
            {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Can't create dir at %@", dirName]}]];
            }
            [fm createFileAtPath:[self.downloadingFileURL path] contents:nil attributes:nil];
            if (![fm fileExistsAtPath:[self.downloadingFileURL path]])
            {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [NSString stringWithFormat:@"Can't create file at %@", [self.downloadingFileURL path]]}]];
            }
            _fileHandle = [NSFileHandle fileHandleForWritingToURL:self.downloadingFileURL error:&error];
            if (error)
            {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:[error userInfo]]];
            }
            [_fileHandle writeData:data];
        } else
        {
            @try {
                [_fileHandle writeData:data];
            }
            @catch (NSException *exception) {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:OSSServerErrorDomain
                                                                  code:OSSClientErrorCodeFileCantWrite
                                                              userInfo:@{OSSErrorMessageTOKEN: [exception description]}]];
            }
        }
    } else
    {
        if (!_collectingData)
        {
            _collectingData = [[NSMutableData alloc] initWithData:data];
        }
        else
        {
            [_collectingData appendData:data];
        }
    }
    return [InspurOSSTask taskWithResult:nil];
}

- (void)parseResponseHeader:(NSHTTPURLResponse *)response toResultObject:(InspurOSSResult *)result
{
    result.httpResponseCode = [_response statusCode];
    result.httpResponseHeaderFields = [NSDictionary dictionaryWithDictionary:[_response allHeaderFields]];
    [[_response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString * keyString = (NSString *)key;
        if ([keyString isEqualToString:@"x-oss-request-id"])
        {
            result.requestId = obj;
        }
        else if ([keyString isEqualToString:@"x-oss-hash-crc64ecma"])
        {
            result.remoteCRC64ecma = obj;
        }
        else if ([keyString isEqualToString:@"object-name"])
        {
            result.objectName = obj;
        }
    }];
}

- (NSDictionary *)parseResponseHeaderToGetMeta:(NSHTTPURLResponse *)response
{
    NSMutableDictionary * meta = [NSMutableDictionary new];
    
    /* define a constant array to contain all meta header name */
    static NSArray * OSSObjectMetaFieldNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OSSObjectMetaFieldNames = @[@"Content-Type", @"Content-Length", @"Etag", @"Last-Modified", @"x-oss-request-id", @"x-oss-object-type",
                                    @"If-Modified-Since", @"If-Unmodified-Since", @"If-Match", @"If-None-Match"];
    });
    /****************************************************************/
    
    [[_response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString * keyString = (NSString *)key;
        if ([OSSObjectMetaFieldNames containsObject:keyString] || [keyString hasPrefix:@"x-oss-meta"]) {
            [meta setObject:obj forKey:key];
        }
    }];
    return meta;
}

- (nullable id)constructResultObject
{
    if (self.onRecieveBlock)
    {
        return nil;
    }
    
    switch (_operationTypeForThisParser)
    {
        case OSSOperationTypeGetObjectVersions: {
            InspurOSSGetObjectVersionResult *result = [InspurOSSGetObjectVersionResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.versionList = [parseDict objectForKey:@"Version"];
                }
            }
            return result;
        }
        case OSSOperationTypeGetBucketPolicy: {
            InspurOSSGetBucketPolicyResult *result = [InspurOSSGetBucketPolicyResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                result.jsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
                
            }
            return result;
        }
        case OSSOperationTypePutBucketPolicy: {
            InspurOSSPutBucketPolicyResult *result = [InspurOSSPutBucketPolicyResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketPolicy: {
            InspurOSSDeleteBucketPolicyResult *result = [InspurOSSDeleteBucketPolicyResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
            
        case OSSOperationTypeGetBucketDomain: {
            InspurOSSGetBucketDomainResult *result = [InspurOSSGetBucketDomainResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                result.domainJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
            }
            return result;
        }
        case OSSOperationTypePutBucketDomain: {
            InspurOSSPutBucketDomainResult *result = [InspurOSSPutBucketDomainResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketDomain: {
            InspurOSSDeleteBucketDomainResult *result = [InspurOSSDeleteBucketDomainResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
            
        case OSSOperationTypeGetBucketLifeCycle: {
            InspurOSSGetBucketLifeCycleResult *result = [InspurOSSGetBucketLifeCycleResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.lifeCycleConfigDictionary = [parseDict objectForKey:@"Rule"];
                }
            }
            return result;
        }
        case OSSOperationTypePutBucketLifeCycle: {
            InspurOSSPutBucketLifeCycleResult *result = [InspurOSSPutBucketLifeCycleResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketLifeCycle: {
            InspurOSSDeleteBucketLifeCycleResult *result = [InspurOSSDeleteBucketLifeCycleResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
            
        case OSSOperationTypeGetBucketWebsite: {
            InspurOSSGetBucketWebsiteResult *result = [InspurOSSGetBucketWebsiteResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.errroDocument = [[parseDict objectForKey:@"ErrorDocument"] objectForKeyedSubscript:@"Key"];
                    result.indexDocument = [[parseDict objectForKey:@"IndexDocument"] objectForKeyedSubscript:@"Suffix"];
                }
            }
            return result;
        }
        case OSSOperationTypePutBucketWebsite: {
            InspurOSSPutBucketWebsiteResult *result = [InspurOSSPutBucketWebsiteResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketWebsite: {
            InspurOSSDeleteBucketWebsiteResult *result = [InspurOSSDeleteBucketWebsiteResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
            
        case OSSOperationTypeGetBucketEncryption: {
            InspurOSSGetBucketEncryptionResult *result = [InspurOSSGetBucketEncryptionResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.sseAlgorithm = [[[parseDict objectForKey:OSSRULETOKEN] objectForKey:OSSServerSideEncryptionDefaultTOKEN] objectForKey:OSSServerSSETOKEN];
                    result.masterId = [[[parseDict objectForKey:OSSRULETOKEN] objectForKey:OSSServerSideEncryptionDefaultTOKEN] objectForKey:OSSServerMasterIdTOKEN];
                }
            }
            return result;
        }
        case OSSOperationTypePutBucketEncryption: {
            InspurOSSPutBucketEncryptionResult *result = [InspurOSSPutBucketEncryptionResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketEncryption: {
            InspurOSSDeleteBucketEncryptionResult *result = [InspurOSSDeleteBucketEncryptionResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
            
        case OSSOperationTypePutBucketVersioning: {
            InspurOSSPutVersioningResult *result = [InspurOSSPutVersioningResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeGetBucketVersioning: {
            InspurOSSGetVersioningResult *result = [InspurOSSGetVersioningResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.enabled = [parseDict objectForKey:OSSSTATUSTOKEN];
                }
            }
            return result;
        }
        case OSSOperationTypeGetBucketCORS: {
            InspurOSSGetBucketCORSResult *result = [InspurOSSGetBucketCORSResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.bucketCORSRuleList = [parseDict objectForKey:OSSCORSRULETOKEN];
                }
            }
            return result;
        }
        case OSSOperationTypePutBucketCORS: {
            InspurOSSPutBucketCORSResult *result = [InspurOSSPutBucketCORSResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteBucketCORS: {
            InspurOSSPutBucketCORSResult *result = [InspurOSSPutBucketCORSResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypePutBucketACL: {
            InspurOSSPutBucketACLResult *result = [InspurOSSPutBucketACLResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeGetBucketLocation:{
            InspurOSSGetBucketLocationResult *result = [InspurOSSGetBucketLocationResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:result];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parseDict) {
                    result.region = [parseDict objectForKey:OSSTextTOKEN];
                }
            }
            return result;
        }
        case OSSOperationTypeQueryBucketExist:{
            InspurOSSQueryBucketExistResult *queryResult = [InspurOSSQueryBucketExistResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:queryResult];
            }
            return queryResult;
        }
        case OSSOperationTypeListService:{
            InspurOSSListServiceResult *listServiceResult = [InspurOSSListServiceResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:listServiceResult];
            }
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"List service dict: %@", parseDict);
                if (parseDict) {
                    listServiceResult.ownerId = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSIDXMLTOKEN];
                    listServiceResult.ownerDispName = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSDisplayNameXMLTOKEN];
                    listServiceResult.pageNo = [[parseDict objectForKey:OSSPageNoXMLTOKEN] intValue];
                    listServiceResult.pageSize = [[parseDict objectForKey:OSSPageSizeXMLTOKEN] intValue];
                    listServiceResult.totalCount = [[parseDict objectForKey:OSSTotalCountXMLTOKEN] intValue];

                    id bucketObject = [[parseDict objectForKey:OSSBucketsXMLTOKEN] objectForKey:OSSBucketXMLTOKEN];
                    if ([bucketObject isKindOfClass:[NSArray class]]) {
                        listServiceResult.buckets = bucketObject;
                    } else if ([bucketObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:bucketObject];
                        listServiceResult.buckets = arr;
                    } else {
                        listServiceResult.buckets = nil;
                    }
                }
            }
            
            return listServiceResult;
        }
        case OSSOperationTypeGetService:
        {
            InspurOSSGetServiceResult * getServiceResult = [InspurOSSGetServiceResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getServiceResult];
            }
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get service dict: %@", parseDict);
                if (parseDict)
                {
                    getServiceResult.ownerId = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSIDXMLTOKEN];
                    getServiceResult.ownerDispName = [[parseDict objectForKey:OSSOwnerXMLTOKEN] objectForKey:OSSDisplayNameXMLTOKEN];
                    getServiceResult.prefix = [parseDict objectForKey:OSSPrefixXMLTOKEN];
                    getServiceResult.marker = [parseDict objectForKey:OSSMarkerXMLTOKEN];
                    getServiceResult.maxKeys = [[parseDict objectForKey:OSSMaxKeysXMLTOKEN] intValue];
                    getServiceResult.isTruncated = [[parseDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    getServiceResult.nextMarker = [parseDict objectForKey:OSSNextMarkerXMLTOKEN];

                    id bucketObject = [[parseDict objectForKey:OSSBucketsXMLTOKEN] objectForKey:OSSBucketXMLTOKEN];
                    if ([bucketObject isKindOfClass:[NSArray class]]) {
                        getServiceResult.buckets = bucketObject;
                    } else if ([bucketObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:bucketObject];
                        getServiceResult.buckets = arr;
                    } else {
                        getServiceResult.buckets = nil;
                    }
                }
            }
            return getServiceResult;
        }
            
        case OSSOperationTypeCreateBucket:
        {
            InspurOSSCreateBucketResult * createBucketResult = [InspurOSSCreateBucketResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:createBucketResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Location"]) {
                        createBucketResult.location = obj;
                        *stop = YES;
                    }
                }];
            }
            return createBucketResult;
        }
            
        case OSSOperationTypeGetBucketACL:
        {
            InspurOSSGetBucketACLResult * getBucketACLResult = [InspurOSSGetBucketACLResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getBucketACLResult];
            }
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get service dict: %@", parseDict);
                if (parseDict)
                {
                    getBucketACLResult.aclGranted = [[parseDict objectForKey:OSSAccessControlListXMLTOKEN] objectForKey:OSSGrantXMLTOKEN];
                }
            }
            return getBucketACLResult;
        }
            
        case OSSOperationTypeDeleteBucket:
        {
            InspurOSSDeleteBucketResult * deleteBucketResult = [InspurOSSDeleteBucketResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:deleteBucketResult];
            }
            return deleteBucketResult;
        }
            
        case OSSOperationTypeGetBucket:
        {
            InspurOSSGetBucketResult * getBucketResult = [InspurOSSGetBucketResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:getBucketResult];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get bucket dict: %@", parsedDict);
                
                if (parsedDict) {
                    getBucketResult.bucketName = [parsedDict objectForKey:OSSNameXMLTOKEN];
                    getBucketResult.prefix = [parsedDict objectForKey:OSSPrefixXMLTOKEN];
                    getBucketResult.marker = [parsedDict objectForKey:OSSMarkerXMLTOKEN];
                    getBucketResult.nextMarker = [parsedDict objectForKey:OSSNextMarkerXMLTOKEN];
                    getBucketResult.maxKeys = (int32_t)[[parsedDict objectForKey:OSSMaxKeysXMLTOKEN] integerValue];
                    getBucketResult.delimiter = [parsedDict objectForKey:OSSDelimiterXMLTOKEN];
                    getBucketResult.isTruncated = [[parsedDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    
                    id contentObject = [parsedDict objectForKey:OSSContentsXMLTOKEN];
                    if ([contentObject isKindOfClass:[NSArray class]]) {
                        getBucketResult.contents = contentObject;
                    } else if ([contentObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:contentObject];
                        getBucketResult.contents = arr;
                    } else {
                        getBucketResult.contents = nil;
                    }
                    
                    NSMutableArray * commentPrefixesArr = [NSMutableArray new];
                    id commentPrefixes = [parsedDict objectForKey:OSSCommonPrefixesXMLTOKEN];
                    if ([commentPrefixes isKindOfClass:[NSArray class]]) {
                        for (NSDictionary * prefix in commentPrefixes) {
                            [commentPrefixesArr addObject:[prefix objectForKey:@"Prefix"]];
                        }
                    } else if ([commentPrefixes isKindOfClass:[NSDictionary class]]) {
                        [commentPrefixesArr addObject:[(NSDictionary *)commentPrefixes objectForKey:@"Prefix"]];
                    } else {
                        commentPrefixesArr = nil;
                    }
                    
                    getBucketResult.commentPrefixes = commentPrefixesArr;
                }
            }
            return getBucketResult;
        }
            
        case OSSOperationTypeListMultipartUploads:
        {
            InspurOSSListMultipartUploadsResult * listMultipartUploadsResult = [InspurOSSListMultipartUploadsResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:listMultipartUploadsResult];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"List multipart uploads dict: %@", parsedDict);
                
                if (parsedDict) {
                    listMultipartUploadsResult.bucketName = [parsedDict objectForKey:OSSBucketXMLTOKEN];
                    listMultipartUploadsResult.prefix = [parsedDict objectForKey:OSSPrefixXMLTOKEN];
                    listMultipartUploadsResult.uploadIdMarker = [parsedDict objectForKey:OSSUploadIdMarkerXMLTOKEN];
                    listMultipartUploadsResult.nextUploadIdMarker = [parsedDict objectForKey:OSSUploadIdMarkerXMLTOKEN];
                    listMultipartUploadsResult.keyMarker = [parsedDict objectForKey:OSSKeyMarkerXMLTOKEN];
                    listMultipartUploadsResult.nextKeyMarker = [parsedDict objectForKey:OSSNextKeyMarkerXMLTOKEN];
                    listMultipartUploadsResult.maxUploads = (int32_t)[[parsedDict objectForKey:OSSMaxUploadsXMLTOKEN] integerValue];
                    listMultipartUploadsResult.delimiter = [parsedDict objectForKey:OSSDelimiterXMLTOKEN];
                    listMultipartUploadsResult.isTruncated = [[parsedDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    
                    id contentObject = [parsedDict objectForKey:OSSUploadXMLTOKEN];
                    if ([contentObject isKindOfClass:[NSArray class]]) {
                        listMultipartUploadsResult.uploads = contentObject;
                    } else if ([contentObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:contentObject];
                        listMultipartUploadsResult.uploads = arr;
                    } else {
                        listMultipartUploadsResult.uploads = nil;
                    }
                    
                    NSMutableArray * commentPrefixesArr = [NSMutableArray new];
                    id commentPrefixes = [parsedDict objectForKey:OSSCommonPrefixesXMLTOKEN];
                    if ([commentPrefixes isKindOfClass:[NSArray class]]) {
                        for (NSDictionary * prefix in commentPrefixes) {
                            [commentPrefixesArr addObject:[prefix objectForKey:@"Prefix"]];
                        }
                    } else if ([commentPrefixes isKindOfClass:[NSDictionary class]]) {
                        [commentPrefixesArr addObject:[(NSDictionary *)commentPrefixes objectForKey:@"Prefix"]];
                    } else {
                        commentPrefixesArr = nil;
                    }
                    
                    listMultipartUploadsResult.commonPrefixes = commentPrefixesArr;
                }
            }
            return listMultipartUploadsResult;
        }
            
        case OSSOperationTypeHeadObject:
        {
            InspurOSSHeadObjectResult * headObjectResult = [InspurOSSHeadObjectResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:headObjectResult];
                headObjectResult.objectMeta = [self parseResponseHeaderToGetMeta:_response];
            }
            return headObjectResult;
        }
            
        case OSSOperationTypeGetObject:
        {
            InspurOSSGetObjectResult * getObejctResult = [InspurOSSGetObjectResult new];
            OSSLogDebug(@"GetObjectResponse: %@", _response);
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getObejctResult];
                getObejctResult.objectMeta = [self parseResponseHeaderToGetMeta:_response];
                if (_crc64ecma != 0)
                {
                    getObejctResult.localCRC64ecma = [NSString stringWithFormat:@"%llu",_crc64ecma];
                }
            }
            if (_fileHandle) {
                [_fileHandle closeFile];
            }
            
            if (_collectingData) {
                getObejctResult.downloadedData = _collectingData;
            }
            return getObejctResult;
        }
        case OSSOperationTypeGetObjectACL:
        {
            InspurOSSGetObjectACLResult * getObjectACLResult = [InspurOSSGetObjectACLResult new];
            OSSLogDebug(@"GetObjectResponse: %@", _response);
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:getObjectACLResult];
            }
            
            if (_collectingData) {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"Get service dict: %@", parseDict);
                getObjectACLResult.grant = parseDict[@"AccessControlList"][@"Grant"];
            }
            
            
            return getObjectACLResult;
        }
            
        case OSSOperationTypePutObject:
        {
            InspurOSSPutObjectResult * putObjectResult = [InspurOSSPutObjectResult new];
            if (_response)
            {
                [self parseResponseHeader:_response toResultObject:putObjectResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        putObjectResult.eTag = obj;
                    }
                    else if ([((NSString *)key) isEqualToString:@"object-name"]) {
                        putObjectResult.objectName = obj;
                    }
                }];
            }
            if (_collectingData) {
                putObjectResult.serverReturnJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
            }
            return putObjectResult;
        }
            
        case OSSOperationTypeAppendObject:
        {
            InspurOSSAppendObjectResult * appendObjectResult = [InspurOSSAppendObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:appendObjectResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        appendObjectResult.eTag = obj;
                    }
                    if ([((NSString *)key) isEqualToString:@"x-oss-next-append-position"]) {
                        appendObjectResult.xOssNextAppendPosition = [((NSString *)obj) longLongValue];
                    }
                }];
            }
            return appendObjectResult;
        }
            
        case OSSOperationTypeDeleteObject: {
            InspurOSSDeleteObjectResult * deleteObjectResult = [InspurOSSDeleteObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:deleteObjectResult];
            }
            return deleteObjectResult;
        }
        case OSSOperationTypeDeleteMultipleObjects: {
            InspurOSSDeleteMultipleObjectsResult * deleteObjectResult = [InspurOSSDeleteMultipleObjectsResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:deleteObjectResult];
            }
            
            if (_collectingData) {
                NSDictionary *dict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                deleteObjectResult.encodingType = dict[@"EncodingType"];
                deleteObjectResult.deletedObjects = dict[@"Deleted"];
            }
            
            return deleteObjectResult;
        }
        case OSSOperationTypePutObjectACL: {
            InspurOSSPutObjectACLResult * putObjectACLResult = [InspurOSSPutObjectACLResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:putObjectACLResult];
            }
            return putObjectACLResult;
        }
            
        case OSSOperationTypeCopyObject: {
            InspurOSSCopyObjectResult * copyObjectResult = [InspurOSSCopyObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:copyObjectResult];
            }
            if (_collectingData) {
                OSSLogVerbose(@"copy object dict: %@", [NSDictionary oss_dictionaryWithXMLData:_collectingData]);
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if (parsedDict) {
                    copyObjectResult.lastModifed = [parsedDict objectForKey:OSSLastModifiedXMLTOKEN];
                    copyObjectResult.eTag = [parsedDict objectForKey:OSSETagXMLTOKEN];
                }
            }
            return copyObjectResult;
        }
            
        case OSSOperationTypeInitMultipartUpload: {
            InspurOSSInitMultipartUploadResult * initMultipartUploadResult = [InspurOSSInitMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:initMultipartUploadResult];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"init multipart upload result: %@", parsedDict);
                if (parsedDict) {
                    initMultipartUploadResult.uploadId = [parsedDict objectForKey:OSSUploadIdXMLTOKEN];
                }
            }
            return initMultipartUploadResult;
        }
            
        case OSSOperationTypeUploadPart: {
            InspurOSSUploadPartResult * uploadPartResult = [InspurOSSUploadPartResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:uploadPartResult];
                [_response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([((NSString *)key) isEqualToString:@"Etag"]) {
                        uploadPartResult.eTag = obj;
                        *stop = YES;
                    }
                }];
            }
            return uploadPartResult;
        }
            
        case OSSOperationTypeCompleteMultipartUpload: {
            OSSCompleteMultipartUploadResult * completeMultipartUploadResult = [OSSCompleteMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:completeMultipartUploadResult];
            }
            if (_collectingData) {
                if ([[[_response.allHeaderFields objectForKey:OSSHttpHeaderContentType] description] isEqual:@"application/xml"]) {
                    OSSLogVerbose(@"complete multipart upload result: %@", [NSDictionary oss_dictionaryWithXMLData:_collectingData]);
                    NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                    if (parsedDict) {
                        completeMultipartUploadResult.location = [parsedDict objectForKey:OSSLocationXMLTOKEN];
                        completeMultipartUploadResult.eTag = [parsedDict objectForKey:OSSETagXMLTOKEN];
                    }
                } else {
                    completeMultipartUploadResult.serverReturnJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
                }
            }
            return completeMultipartUploadResult;
        }
            
        case OSSOperationTypeListMultipart: {
            InspurOSSListPartsResult * listPartsReuslt = [InspurOSSListPartsResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:listPartsReuslt];
            }
            if (_collectingData) {
                NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                OSSLogVerbose(@"list multipart upload result: %@", parsedDict);
                if (parsedDict) {
                    listPartsReuslt.nextPartNumberMarker = [[parsedDict objectForKey:OSSNextPartNumberMarkerXMLTOKEN] intValue];
                    listPartsReuslt.maxParts = [[parsedDict objectForKey:OSSMaxPartsXMLTOKEN] intValue];
                    listPartsReuslt.isTruncated = [[parsedDict objectForKey:OSSIsTruncatedXMLTOKEN] boolValue];
                    
                    id partsObject = [parsedDict objectForKey:OSSPartXMLTOKEN];
                    if ([partsObject isKindOfClass:[NSArray class]]) {
                        listPartsReuslt.parts = partsObject;
                    } else if ([partsObject isKindOfClass:[NSDictionary class]]) {
                        NSArray * arr = [NSArray arrayWithObject:partsObject];
                        listPartsReuslt.parts = arr;
                    } else {
                        listPartsReuslt.parts = nil;
                    }
                }
            }
            return listPartsReuslt;
        }
            
        case OSSOperationTypeAbortMultipartUpload: {
            InspurOSSAbortMultipartUploadResult * abortMultipartUploadResult = [InspurOSSAbortMultipartUploadResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:abortMultipartUploadResult];
            }
            return abortMultipartUploadResult;
        }
        case OSSOperationTypeTriggerCallBack: {
            InspurOSSCallBackResult *callbackResult = [InspurOSSCallBackResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:callbackResult];
            }
            
            if (_collectingData) {
                if ([[[_response.allHeaderFields objectForKey:OSSHttpHeaderContentType] description] isEqual:@"application/xml"]) {
                    NSDictionary * parsedDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                    OSSLogVerbose(@"callback trigger result<xml>: %@", parsedDict);
                    callbackResult.serverReturnXML = parsedDict;
                } else if ([[[_response.allHeaderFields objectForKey:OSSHttpHeaderContentType] description] isEqual:@"application/json"]) {
                    callbackResult.serverReturnJsonString = [[NSString alloc] initWithData:_collectingData encoding:NSUTF8StringEncoding];
                    OSSLogVerbose(@"callback trigger result<json>: %@", callbackResult.serverReturnJsonString);
                }
            }
            return callbackResult;
        }
        case OSSOperationTypeImagePersist: {
            InspurOSSImagePersistResult *imagePersistResult = [InspurOSSImagePersistResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:imagePersistResult];
            }
            return imagePersistResult;
        }
        case OSSOperationTypeGetBucketInfo: {
            InspurOSSGetBucketInfoResult *bucketInfoResult = [[InspurOSSGetBucketInfoResult alloc] init];
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                if ([parseDict valueForKey:@"Bucket"])
                {
                    NSDictionary *result = [parseDict valueForKey:@"Bucket"];
                    OSSLogVerbose(@"Get bucketInfo dict: %@", parseDict);
                    bucketInfoResult.bucketName = [result valueForKey:@"Name"];
                    bucketInfoResult.storageClass = [result valueForKey:@"StorageClass"];
                    bucketInfoResult.location = [result valueForKey:@"Location"];
                    bucketInfoResult.intranetEndpoint = [result valueForKey:@"IntranetEndpoint"];
                    bucketInfoResult.extranetEndpoint = [result valueForKey:@"ExtranetEndpoint"];
                    bucketInfoResult.creationDate = [result valueForKey:@"CreationDate"];
                    
                    if ([result valueForKey:@"Owner"]) {
                        bucketInfoResult.owner = [[InspurOSSBucketOwner alloc] init];
                        bucketInfoResult.owner.userName = [[result valueForKey:@"Owner"] valueForKey:@"DisplayName"];
                        bucketInfoResult.owner.userId = [[result valueForKey:@"Owner"] valueForKey:@"ID"];
                    }
                    
                    if ([result valueForKey:@"AccessControlList"]) {
                        bucketInfoResult.acl = [InspurOSSAccessControlList new];
                        bucketInfoResult.acl.grant = [[result valueForKey:@"AccessControlList"] valueForKey:@"Grant"];
                    }
                }
            }
            if (_response) {
                [self parseResponseHeader:_response toResultObject:bucketInfoResult];
            }
            return bucketInfoResult;
        }
        case OSSOperationTypeRestoreObject: {
            InspurOSSRestoreObjectResult * restoreObjectResult = [InspurOSSRestoreObjectResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:restoreObjectResult];
            }
            return restoreObjectResult;
        }
        case OSSOperationTypePutSymlink: {
            InspurOSSPutSymlinkResult * putSymlinkResult = [InspurOSSPutSymlinkResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:putSymlinkResult];
            }
            return putSymlinkResult;
        }
        case OSSOperationTypeGetSymlink: {
            InspurOSSGetSymlinkResult * getSymlinkResult = [InspurOSSGetSymlinkResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:getSymlinkResult];
            }
            return getSymlinkResult;
        }
        case OSSOperationTypeGetObjectTagging: {
            InspurOSSGetObjectTaggingResult *result = [InspurOSSGetObjectTaggingResult new];
            NSMutableDictionary *tags = [NSMutableDictionary dictionary];
            if (_collectingData)
            {
                NSDictionary * parseDict = [NSDictionary oss_dictionaryWithXMLData:_collectingData];
                NSDictionary *tagSet = [parseDict objectForKey:@"TagSet"];
                if (tagSet) {
                    if ([tagSet[@"Tag"] isKindOfClass:[NSArray class]]) {
                        for (NSDictionary * tag in tagSet[@"Tag"]) {
                            NSString *key = tag[@"Key"];
                            NSString *value = tag[@"Value"];
                            if (key && value) {
                                [tags setObject:value forKey:key];
                            }
                        }
                    } else if ([tagSet[@"Tag"] isKindOfClass:[NSDictionary class]]) {
                        NSString *key = tagSet[@"Tag"][@"Key"];
                        NSString *value = tagSet[@"Tag"][@"Value"];
                        if (key && value) {
                            [tags setObject:value forKey:key];
                        }
                    }
                }
            }
            result.tags = tags;
            if (_response) {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypePutObjectTagging: {
            InspurOSSPutObjectTaggingResult *result = [InspurOSSPutObjectTaggingResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        case OSSOperationTypeDeleteObjectTagging: {
            InspurOSSDeleteObjectTaggingResult *result = [InspurOSSDeleteObjectTaggingResult new];
            if (_response) {
                [self parseResponseHeader:_response toResultObject:result];
            }
            return result;
        }
        default: {
            OSSLogError(@"unknown operation type");
            break;
        }
    }
    return nil;
}

@end
