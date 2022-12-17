//
//  OSSNetworkingRequestDelegate.m
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "InspurOSSNetworkingRequestDelegate.h"

#import "InspurOSSAllRequestNeededMessage.h"
#import "InspurOSSURLRequestRetryHandler.h"
#import "InspurOSSHttpResponseParser.h"
#import "InspurOSSDefine.h"
#import "InspurOSSUtil.h"
#import "OSSLog.h"
#import "OSSIPv6Adapter.h"

@implementation InspurOSSNetworkingRequestDelegate

- (instancetype)init {
    if (self = [super init]) {
        self.retryHandler = [InspurOSSURLRequestRetryHandler defaultRetryHandler];
        self.interceptors = [[NSMutableArray alloc] init];
        self.isHttpdnsEnable = YES;
    }
    return self;
}

- (void)reset {
    self.isHttpRequestNotSuccessResponse = NO;
    self.error = nil;
    self.payloadTotalBytesWritten = 0;
    self.isRequestCancelled = NO;
    [self.responseParser reset];
}

- (void)cancel {
    self.isRequestCancelled = YES;
    if (self.currentSessionTask) {
        OSSLogDebug(@"this task is cancelled now!");
        [self.currentSessionTask cancel];
    }
}

- (InspurOSSTask *)validateRequestParams {
    NSString * errorMessage = nil;
    
    if ((self.operType == InspurOSSOperationTypeAppendObject || self.operType == InspurOSSOperationTypePutObject || self.operType == InspurOSSOperationTypeUploadPart)
        && !self.uploadingData && !self.uploadingFileURL) {
        errorMessage = @"This operation need data or file to upload but none is set";
    }
    
    if (self.uploadingFileURL && ![[NSFileManager defaultManager] fileExistsAtPath:[self.uploadingFileURL path]]) {
        errorMessage = @"File doesn't exist";
    }
    
    if (errorMessage) {
        return [InspurOSSTask taskWithError:[NSError errorWithDomain:InspurOSSClientErrorDomain
                                                          code:InspurOSSClientErrorCodeInvalidArgument
                                                      userInfo:@{InspurOSSErrorMessageTOKEN: errorMessage}]];
    } else {
        return [self.allNeededMessage validateRequestParamsInOperationType:self.operType];
    }
}

- (InspurOSSTask *)buildInternalHttpRequest {
    
    InspurOSSTask * validateParam = [self validateRequestParams];
    if (validateParam.error) {
        return validateParam;
    }
    
#define URLENCODE(a) [InspurOSSUtil encodeURL:(a)]
    OSSLogDebug(@"start to build request")
    // build base url string
    NSString *bucketName = self.allNeededMessage.bucketName;
    NSString *objectKey = self.allNeededMessage.objectKey;
    NSString *urlString = self.allNeededMessage.endpoint;
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithString:urlString];
    NSString *headerHost = nil;
    BOOL isPathStyle = NO;
    
    NSURLComponents *temComs = [NSURLComponents new];
    temComs.scheme = urlComponents.scheme;
    temComs.host = urlComponents.host;
    temComs.port = urlComponents.port;
    if (self.isCustomPathPrefixEnable) {
        temComs.path = urlComponents.path;
    }
    
    if ([self.allNeededMessage.bucketName oss_isNotEmpty]) {
        OSSIPv6Adapter *ipAdapter = [OSSIPv6Adapter getInstance];
        if ([InspurOSSUtil isOssOriginBucketHost:temComs.host]) {
            // eg. insert bucket to the begining of host.
            temComs.host = [NSString stringWithFormat:@"%@.%@", self.allNeededMessage.bucketName, temComs.host];
            headerHost = temComs.host;
            if ([temComs.scheme.lowercaseString isEqualToString:@"http"] && self.isHttpdnsEnable) {
                NSString *dnsResult = [InspurOSSUtil getIpByHost: temComs.host];
                temComs.host = dnsResult;
            }
        } else if (self.allNeededMessage.isHostInCnameExcludeList) {
            if (self.isPathStyleAccessEnable) {
                isPathStyle = YES;
            } else {
                temComs.host = [NSString stringWithFormat:@"%@.%@", self.allNeededMessage.bucketName, temComs.host];
            }
        } else if ([ipAdapter isIPv4Address:temComs.host] || [ipAdapter isIPv6Address:temComs.host]) {
            isPathStyle = YES;
        }
    }
    
    urlString = temComs.string;
    
    if (isPathStyle) {
        urlString = [NSString stringWithFormat:@"%@/%@", urlString, bucketName];
    }
    // join object name
    if ([self.allNeededMessage.objectKey oss_isNotEmpty]) {
        urlString = [urlString oss_stringByAppendingPathComponentForURL:URLENCODE(self.allNeededMessage.objectKey)];
    }
    
    // join query string
    if (self.allNeededMessage.params) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        for (NSString * key in [self.allNeededMessage.params allKeys]) {
            NSString * value = [self.allNeededMessage.params objectForKey:key];
            if (value) {
                if ([value isEqualToString:@""]) {
                    [querys addObject:URLENCODE(key)];
                } else {
                    [querys addObject:[NSString stringWithFormat:@"%@=%@", URLENCODE(key), URLENCODE(value)]];
                }
            }
        }
        if (querys && [querys count]) {
            NSString * queryString = [querys componentsJoinedByString:@"&"];
            urlString = [NSString stringWithFormat:@"%@?%@", urlString, queryString];
        }
    }
    
    OSSLogDebug(@"built full url: %@", urlString)
    
    // generate internal request For NSURLSession
    self.internalRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    // set http method of request
    if (self.allNeededMessage.httpMethod) {
        [self.internalRequest setHTTPMethod:self.allNeededMessage.httpMethod];
    }
    
    // set host of header fields
    if ([headerHost oss_isNotEmpty]) {
        [self.internalRequest setValue:headerHost forHTTPHeaderField:@"Host"];
    }
    
    if (self.allNeededMessage.contentType) {
        [self.internalRequest setValue:self.allNeededMessage.contentType forHTTPHeaderField:@"Content-Type"];
    }
    if (self.allNeededMessage.contentMd5) {
        [self.internalRequest setValue:self.allNeededMessage.contentMd5 forHTTPHeaderField:@"Content-MD5"];
    }
    if (self.allNeededMessage.date) {
        [self.internalRequest setValue:self.allNeededMessage.date forHTTPHeaderField:@"Date"];
    }
    if (self.allNeededMessage.range) {
        [self.internalRequest setValue:self.allNeededMessage.range forHTTPHeaderField:@"Range"];
    }
    if (self.allNeededMessage.contentSHA1) {
        [self.internalRequest setValue:_allNeededMessage.contentSHA1 forHTTPHeaderField:@"x-oss-hash-sha1"];
    }
    if (self.allNeededMessage.headerParams) {
        for (NSString * key in [self.allNeededMessage.headerParams allKeys]) {
            [self.internalRequest setValue:[self.allNeededMessage.headerParams objectForKey:key] forHTTPHeaderField:key];
        }
    }
    
    
    OSSLogVerbose(@"buidlInternalHttpRequest -\nmethod: %@\nurl: %@\nheader: %@", self.internalRequest.HTTPMethod,
                  self.internalRequest.URL, self.internalRequest.allHTTPHeaderFields)
    
#undef URLENCODE//(a)
    return [InspurOSSTask taskWithResult:nil];
}

@end
