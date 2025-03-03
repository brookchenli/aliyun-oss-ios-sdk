//
//  OSSModel.m
//  oss_ios_sdk
//
//  Created by xx on 8/16/15.
//  Copyright (c) 2022 Inspur. All rights reserved.
//
#import "InspurOSSDefine.h"
#import "OSSModel.h"
#import "OSSBolts.h"
#import "InspurOSSUtil.h"
#import "InspurOSSNetworking.h"
#import "InspurOSSLog.h"
#import "InspurOSSXMLDictionary.h"
#if TARGET_OS_IOS
#import <UIKit/UIDevice.h>
#endif

#import "InspurOSSAllRequestNeededMessage.h"

@implementation NSDictionary (InspurOSS)

- (NSString *)base64JsonString {
    NSError * error;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                        options:0
                                                          error:&error];

    if (!jsonData) {
        return @"e30="; // base64("{}");
    } else {
        NSString * jsonStr = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        NSLog(@"callback json - %@", jsonStr);
        return [[jsonStr dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    }
}

@end

@implementation InspurOSSSyncMutableDictionary

- (instancetype)init {
    if (self = [super init]) {
        _dictionary = [NSMutableDictionary dictionary];
        _dispatchQueue = dispatch_queue_create("com.inspur.inpsursycmutabledictionary", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (NSArray *)allKeys {
    __block NSArray *allKeys = nil;
    dispatch_sync(self.dispatchQueue, ^{
        allKeys = [self.dictionary allKeys];
    });
    return allKeys;
}

- (id)objectForKey:(id)aKey {
    __block id returnObject = nil;

    dispatch_sync(self.dispatchQueue, ^{
        returnObject = [self.dictionary objectForKey:aKey];
    });

    return returnObject;
}

- (void)setObject:(id)anObject forKey:(id <NSCopying>)aKey {
    dispatch_sync(self.dispatchQueue, ^{
        [self.dictionary oss_setObject:anObject forKey:aKey];
    });
}

- (void)removeObjectForKey:(id)aKey {
    dispatch_sync(self.dispatchQueue, ^{
        [self.dictionary removeObjectForKey:aKey];
    });
}

@end

@implementation InspurOSSFederationToken

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSFederationToken<%p>:{AccessKeyId: %@\nAccessKeySecret: %@\nSecurityToken: %@\nExpiration: %@}", self, _tAccessKey, _tSecretKey, _tToken, _expirationTimeInGMTFormat];
}

@end

@implementation InspurOSSPlainTextAKSKPairCredentialProvider

- (instancetype)initWithPlainTextAccessKey:(nonnull NSString *)accessKey secretKey:(nonnull NSString *)secretKey {
    if (self = [super init]) {
        self.accessKey = [accessKey oss_trim];
        self.secretKey = [secretKey oss_trim];
    }
    return self;
}

- (nullable NSString *)sign:(NSString *)content error:(NSError **)error {
    if (![self.accessKey oss_isNotEmpty] || ![self.secretKey oss_isNotEmpty])
    {
        if (error != nil)
        {
            *error = [NSError errorWithDomain:InspurOSSClientErrorDomain
                                         code:InspurOSSClientErrorCodeSignFailed
                                     userInfo:@{InspurOSSErrorMessageTOKEN: @"accessKey or secretKey can't be null"}];
        }
        
        return nil;
    }
    NSString * sign = [InspurOSSUtil calBase64Sha1WithData:content withSecret:self.secretKey];
    return [NSString stringWithFormat:@"OSS %@:%@", self.accessKey, sign];
}

@end

@implementation InspurOSSCustomSignerCredentialProvider

- (instancetype)initWithImplementedSigner:(OSSCustomSignContentBlock)signContent
{
    NSParameterAssert(signContent);
    if (self = [super init])
    {
        _signContent = signContent;
    }
    return self;
}

- (NSString *)sign:(NSString *)content error:(NSError **)error
{
    NSString * signature = @"";
    @synchronized(self) {
        signature = self.signContent(content, error);
    }
    if (*error) {
        *error = [NSError errorWithDomain:InspurOSSClientErrorDomain
                                     code:InspurOSSClientErrorCodeSignFailed
                                 userInfo:[[NSDictionary alloc] initWithDictionary:[*error userInfo]]];
        return nil;
    }
    return signature;
}

@end

@implementation InspurOSSFederationCredentialProvider

- (instancetype)initWithFederationTokenGetter:(OSSGetFederationTokenBlock)federationTokenGetter {
    if (self = [super init]) {
        self.federationTokenGetter = federationTokenGetter;
    }
    return self;
}

- (nullable InspurOSSFederationToken *)getToken:(NSError **)error {
    InspurOSSFederationToken * validToken = nil;
    @synchronized(self) {
        if (self.cachedToken == nil) {

            self.cachedToken = self.federationTokenGetter();
        } else {
            if (self.cachedToken.expirationTimeInGMTFormat) {
                NSDateFormatter * fm = [NSDateFormatter new];
                fm.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                [fm setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
                self.cachedToken.expirationTimeInMilliSecond = [[fm dateFromString:self.cachedToken.expirationTimeInGMTFormat] timeIntervalSince1970] * 1000;
                self.cachedToken.expirationTimeInGMTFormat = nil;
                OSSLogVerbose(@"Transform GMT date to expirationTimeInMilliSecond: %lld", self.cachedToken.expirationTimeInMilliSecond);
            }

            NSDate * expirationDate = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)(self.cachedToken.expirationTimeInMilliSecond / 1000)];
            NSTimeInterval interval = [expirationDate timeIntervalSinceDate:[NSDate oss_clockSkewFixedDate]];
            /* if this token will be expired after less than 2min, we abort it in case of when request arrived oss server,
               it's expired already. */
            if (interval < 5 * 60) {
                OSSLogDebug(@"get federation token, but after %lf second it would be expired", interval);
                self.cachedToken = self.federationTokenGetter();
            }
        }

        validToken = self.cachedToken;
    }
    if (!validToken)
    {
        if (error != nil)
        {
            *error = [NSError errorWithDomain:InspurOSSClientErrorDomain
                                         code:InspurOSSClientErrorCodeSignFailed
                                     userInfo:@{InspurOSSErrorMessageTOKEN: @"Can't get a federation token"}];
        }
        
        return nil;
    }
    return validToken;
}

@end

@implementation InspurOSSStsTokenCredentialProvider

- (InspurOSSFederationToken *)getToken {
    InspurOSSFederationToken * token = [InspurOSSFederationToken new];
    token.tAccessKey = self.accessKeyId;
    token.tSecretKey = self.secretKeyId;
    token.tToken = self.securityToken;
    token.expirationTimeInMilliSecond = NSIntegerMax;
    return token;
}

- (instancetype)initWithAccessKeyId:(NSString *)accessKeyId secretKeyId:(NSString *)secretKeyId securityToken:(NSString *)securityToken {
    if (self = [super init]) {
        self.accessKeyId = [accessKeyId oss_trim];
        self.secretKeyId = [secretKeyId oss_trim];
        self.securityToken = [securityToken oss_trim];
    }
    return self;
}

- (NSString *)sign:(NSString *)content error:(NSError **)error {
    NSString * sign = [InspurOSSUtil calBase64Sha1WithData:content withSecret:self.secretKeyId];
    return [NSString stringWithFormat:@"OSS %@:%@", self.accessKeyId, sign];
}

@end

@implementation InspurOSSAuthCredentialProvider

- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl
{
    return [self initWithAuthServerUrl:authServerUrl responseDecoder:nil];
}

- (instancetype)initWithAuthServerUrl:(NSString *)authServerUrl responseDecoder:(nullable OSSResponseDecoderBlock)decoder
{
    self = [super initWithFederationTokenGetter:^InspurOSSFederationToken * {
        NSURL * url = [NSURL URLWithString:self.authServerUrl];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
        NSURLSession * session = [NSURLSession sharedSession];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                            [tcs setError:error];
                                                            return;
                                                        }
                                                        [tcs setResult:data];
                                                    }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSData* data = tcs.task.result;
            if(decoder){
                data = decoder(data);
            }
            NSDictionary * object = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:kNilOptions
                                                                      error:nil];
            int statusCode = [[object objectForKey:@"StatusCode"] intValue];
            if (statusCode == 200) {
                InspurOSSFederationToken * token = [InspurOSSFederationToken new];
                // All the entries below are mandatory.
                token.tAccessKey = [object objectForKey:@"AccessKeyId"];
                token.tSecretKey = [object objectForKey:@"AccessKeySecret"];
                token.tToken = [object objectForKey:@"SecurityToken"];
                token.expirationTimeInGMTFormat = [object objectForKey:@"Expiration"];
                OSSLogDebug(@"token: %@ %@ %@ %@", token.tAccessKey, token.tSecretKey, token.tToken, [object objectForKey:@"Expiration"]);
                return token;
            }else{
                return nil;
            }
            
        }
    }];
    if(self){
        self.authServerUrl = authServerUrl;
    }
    return self;
}

@end

NSString * const BACKGROUND_SESSION_IDENTIFIER = @"com.inspur.oss.backgroundsession";

@implementation InspurOSSClientConfiguration

- (instancetype)init {
    if (self = [super init]) {
        self.maxRetryCount = InspurOSSDefaultRetryCount;
        self.maxConcurrentRequestCount = InspurOSSDefaultMaxConcurrentNum;
        self.enableBackgroundTransmitService = NO;
        self.isHttpdnsEnable = NO;
        self.backgroundSesseionIdentifier = BACKGROUND_SESSION_IDENTIFIER;
        self.timeoutIntervalForRequest = InspurOSSDefaultTimeoutForRequestInSecond;
        self.timeoutIntervalForResource = InspurOSSDefaultTimeoutForResourceInSecond;
        self.isPathStyleAccessEnable = NO;
        self.isCustomPathPrefixEnable = NO;
        self.cnameExcludeList = @[];
        self.isAllowUACarrySystemInfo = YES;
        self.isFollowRedirectsEnable = YES;
    }
    return self;
}

- (void)setCnameExcludeList:(NSArray *)cnameExcludeList {
    NSMutableArray * array = [NSMutableArray new];
    [cnameExcludeList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * host = [(NSString *)obj lowercaseString];
        if ([host containsString:@"://"]) {
            NSString * trimHost = [host substringFromIndex:[host rangeOfString:@"://"].location + 3];
            [array addObject:trimHost];
        } else {
            [array addObject:host];
        }
    }];
    _cnameExcludeList = array.copy;
}

@end

@implementation InspurOSSSignerInterceptor

- (instancetype)initWithCredentialProvider:(id<InspurOSSCredentialProvider>)credentialProvider {
    if (self = [super init]) {
        self.credentialProvider = credentialProvider;
    }
    return self;
}

- (InspurOSSTask *)interceptRequestMessage:(InspurOSSAllRequestNeededMessage *)requestMessage {
    OSSLogVerbose(@"signing intercepting - ");
    NSError * error = nil;

    /****************************************************************
    * define a constant array to contain all specified subresource */
    static NSArray * OSSSubResourceARRAY = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OSSSubResourceARRAY = @[@"acl", @"uploadId", @"partNumber", @"uploads", @"logging", @"website", @"location",
                                @"lifecycle", @"referer", @"cors", @"delete", @"append", @"position", @"security-token", @"x-oss-process", @"sequential",@"bucketInfo",@"symlink", @"restore", @"tagging", @"versioning", @"encryption", @"domain", @"policy", @"versions", @"versionId"];
    });
    /****************************************************************/

    /* initial each part of content to sign */
    NSString * method = requestMessage.httpMethod;
    NSString * contentType = @"";
    NSString * contentMd5 = @"";
    NSString * date = requestMessage.date;
    NSString * xossHeader = @"";
    NSString * resource = @"";

    InspurOSSFederationToken * federationToken = nil;

    if (requestMessage.contentType) {
        contentType = requestMessage.contentType;
    }
    if (requestMessage.contentMd5) {
        contentMd5 = requestMessage.contentMd5;
    }

    /* if credential provider is a federation token provider, it need to specially handle */
    if ([self.credentialProvider isKindOfClass:[InspurOSSFederationCredentialProvider class]]) {
        federationToken = [(InspurOSSFederationCredentialProvider *)self.credentialProvider getToken:&error];
        if (error) {
            return [InspurOSSTask taskWithError:error];
        }
        [requestMessage.headerParams oss_setObject:federationToken.tToken forKey:@"x-oss-security-token"];
    } else if ([self.credentialProvider isKindOfClass:[InspurOSSStsTokenCredentialProvider class]]) {
        federationToken = [(InspurOSSStsTokenCredentialProvider *)self.credentialProvider getToken];
        [requestMessage.headerParams oss_setObject:federationToken.tToken forKey:@"x-oss-security-token"];
    }
    
    [requestMessage.headerParams oss_setObject:requestMessage.contentSHA1 forKey:InspurOSSHttpHeaderHashSHA1];
        
    /* construct CanonicalizedOSSHeaders */
    if (requestMessage.headerParams) {
        NSMutableArray * params = [[NSMutableArray alloc] init];
        NSArray * sortedKey = [[requestMessage.headerParams allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        for (NSString * key in sortedKey) {
            if ([key hasPrefix:@"x-oss-"]) {
                [params addObject:[NSString stringWithFormat:@"%@:%@", key, [requestMessage.headerParams objectForKey:key]]];
            }
        }
        if ([params count]) {
            xossHeader = [NSString stringWithFormat:@"%@\n", [params componentsJoinedByString:@"\n"]];
        }
    }

    /* construct CanonicalizedResource */
    resource = @"/";
    if (requestMessage.bucketName) {
        resource = [NSString stringWithFormat:@"/%@", requestMessage.bucketName];
    }
    if (requestMessage.objectKey) {
        resource = [resource oss_stringByAppendingPathComponentForURL:requestMessage.objectKey];
    }
    if (requestMessage.params) {
        NSMutableArray * querys = [[NSMutableArray alloc] init];
        NSArray * sortedKey = [[requestMessage.params allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        for (NSString * key in sortedKey) {
            NSString * value = [requestMessage.params objectForKey:key];

            if (![OSSSubResourceARRAY containsObject:key]) { // notice it's based on content compare
                continue;
            }

            if ([value isEqualToString:@""]) {
                [querys addObject:[NSString stringWithFormat:@"%@", key]];
            } else {
                [querys addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
            }
        }
        if ([querys count]) {
            resource = [resource stringByAppendingString:[NSString stringWithFormat:@"?%@",[querys componentsJoinedByString:@"&"]]];
        }
    }

    /* now, join every part of content and sign */
    NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, contentMd5, contentType, date, xossHeader, resource];
    OSSLogDebug(@"string to sign: %@", stringToSign);
    if ([self.credentialProvider isKindOfClass:[InspurOSSFederationCredentialProvider class]]
        || [self.credentialProvider isKindOfClass:[InspurOSSStsTokenCredentialProvider class]])
    {
        NSString * signature = [InspurOSSUtil sign:stringToSign withToken:federationToken];
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }else if ([self.credentialProvider isKindOfClass:[InspurOSSCustomSignerCredentialProvider class]])
    {
        InspurOSSCustomSignerCredentialProvider *provider = (InspurOSSCustomSignerCredentialProvider *)self.credentialProvider;
        
        NSError *customSignError;
        NSString * signature = [provider sign:stringToSign error:&customSignError];
        if (customSignError) {
            OSSLogError(@"OSSCustomSignerError: %@", customSignError)
            return [InspurOSSTask taskWithError: customSignError];
        }
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }else
    {
        NSString * signature = [self.credentialProvider sign:stringToSign error:&error];
        if (error) {
            return [InspurOSSTask taskWithError:error];
        }
        [requestMessage.headerParams oss_setObject:signature forKey:@"Authorization"];
    }
    return [InspurOSSTask taskWithResult:nil];
}

@end

@implementation InspurOSSUASettingInterceptor

- (instancetype)initWithClientConfiguration:(InspurOSSClientConfiguration *)clientConfiguration{
    if (self = [super init]) {
        self.clientConfiguration = clientConfiguration;
    }
    return self;
}

- (InspurOSSTask *)interceptRequestMessage:(InspurOSSAllRequestNeededMessage *)request {
    NSString * userAgent = [self getUserAgent:self.clientConfiguration.userAgentMark];
    [request.headerParams oss_setObject:userAgent forKey:@"User-Agent"];
    return [InspurOSSTask taskWithResult:nil];
}


- (NSString *)getUserAgent:(NSString *)customUserAgent {
    static NSString * userAgent = nil;
    static dispatch_once_t once;
    NSString * tempUserAgent = nil;
    dispatch_once(&once, ^{
        NSString *localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
#if TARGET_OS_IOS
        if (self.clientConfiguration.isAllowUACarrySystemInfo) {
            NSString *systemName = [[[UIDevice currentDevice] systemName] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
            userAgent = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", InspurOSSUAPrefix, InspurOSSSDKVersion, systemName, systemVersion, localeIdentifier];
        } else {
            userAgent = [NSString stringWithFormat:@"%@/%@(/%@)", InspurOSSUAPrefix, InspurOSSSDKVersion, localeIdentifier];
        }
#elif TARGET_OS_OSX
        userAgent = [NSString stringWithFormat:@"%@/%@(/%@/%@/%@)", InspurOSSUAPrefix, InspurOSSSDKVersion, @"OSX", [NSProcessInfo processInfo].operatingSystemVersionString, localeIdentifier];
#endif
    });
    if(customUserAgent){
        if(userAgent){
            tempUserAgent = [[userAgent stringByAppendingString:@"/"] stringByAppendingString:customUserAgent];
        }else{
            tempUserAgent = customUserAgent;
        }
    }else{
        tempUserAgent = userAgent;
    }
    return tempUserAgent;
}

@end

@implementation InspurOSSTimeSkewedFixingInterceptor

- (InspurOSSTask *)interceptRequestMessage:(InspurOSSAllRequestNeededMessage *)request {
    request.date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    return [InspurOSSTask taskWithResult:nil];
}

@end

@implementation OSSRange

- (instancetype)initWithStart:(int64_t)start withEnd:(int64_t)end {
    if (self = [super init]) {
        self.startPosition = start;
        self.endPosition = end;
    }
    return self;
}

- (NSString *)toHeaderString {

    NSString * rangeString = nil;

    if (self.startPosition < 0 && self.endPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-%lld", self.startPosition, self.endPosition];
    } else if (self.startPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=-%lld", self.endPosition];
    } else if (self.endPosition < 0) {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-", self.startPosition];
    } else {
        rangeString = [NSString stringWithFormat:@"bytes=%lld-%lld", self.startPosition, self.endPosition];
    }

    return rangeString;
}

@end

#pragma mark request and result objects

@implementation InspurOSSGetServiceRequest

- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.marker forKey:@"marker"];
    if (self.maxKeys > 0) {
        [params oss_setObject:[@(self.maxKeys) stringValue] forKey:@"max-keys"];
    }
    return [params copy];
}

@end

@implementation InspurOSSGetServiceResult
@end

@implementation InspurOSSListPageServiceRequest

- (NSDictionary *)requestParams {
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"details"];
    [params oss_setObject:self.filterKey forKey:@"filterKey"];
    if (self.pageNo > 0) {
        [params oss_setObject:[@(self.pageNo) stringValue] forKey:@"pageNo"];
    }
    if (self.pageSize > 0) {
        [params oss_setObject:[@(self.pageSize) stringValue] forKey:@"pageSize"];
    }
    
    return [params copy];
}

@end

@implementation InspurOSSListServiceResult

@end

@implementation InspurOSSQueryBucketExistRequest

@end

@implementation InspurOSSQueryBucketExistResult

@end

@implementation InspurOSSGetBucketLocationRequest

- (NSDictionary *)requestParams {
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:@"" forKey:@"location"];
    return [params copy];
}

@end

@implementation InspurOSSGetBucketLocationResult

@end

@implementation InspurOSSCreateBucketRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _storageClass = InspurOSSBucketStorageClassStandard;
    }
    return self;
}

- (NSString *)storageClassAsString {
    NSString *storageClassString = nil;
    switch (_storageClass) {
        case InspurOSSBucketStorageClassStandard:
            storageClassString = @"Standard";
            break;
        case InspurOSSBucketStorageClassIA:
            storageClassString = @"IA";
            break;
        case InspurOSSBucketStorageClassArchive:
            storageClassString = @"Archive";
            break;
        default:
            storageClassString = @"Unknown";
            break;
    }
    return storageClassString;
}

@end

@implementation InspurOSSCreateBucketResult
@end

@implementation InspurOSSDeleteBucketRequest
@end

@implementation InspurOSSDeleteBucketResult
@end

@implementation InspurOSSGetBucketRequest

- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.delimiter forKey:@"delimiter"];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.marker forKey:@"marker"];
    if (self.maxKeys > 0) {
        [params oss_setObject:[@(self.maxKeys) stringValue] forKey:@"max-keys"];
    }
    return [params copy];
}

@end

@implementation InspurOSSListMultipartUploadsRequest
- (NSDictionary *)requestParams {
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params oss_setObject:self.delimiter forKey:@"delimiter"];
    [params oss_setObject:self.prefix forKey:@"prefix"];
    [params oss_setObject:self.keyMarker forKey:@"key-marker"];
    [params oss_setObject:self.uploadIdMarker forKey:@"upload-id-marker"];
    [params oss_setObject:self.encodingType forKey:@"encoding-type"];
    
    if (self.maxUploads > 0) {
        [params oss_setObject:[@(self.maxUploads) stringValue] forKey:@"max-uploads"];
    }
    
    return [params copy];
}
@end

@implementation InspurOSSListMultipartUploadsResult
@end

@implementation InspurOSSGetBucketResult
@end

@implementation InspurOSSGetBucketACLRequest

- (NSDictionary *)requestParams {
    return @{@"acl": @""};
}

@end

@implementation InspurOSSGetBucketACLResult
@end

@implementation InspurOSSPutBucketACLRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _acl = @"default";
    }
    return self;
}

@end

@implementation InspurOSSPutBucketACLResult

@end


@implementation InspurOSSGetBucketCORSRequest

- (NSDictionary *)requestParams {
    return @{@"cors": @""};
}

@end

@implementation InspurOSSGetBucketCORSResult

@end

@implementation InspurOSSPutBucketCORSRequest
- (NSDictionary *)requestParams {
    return @{@"cors": @""};
}
@end

@implementation InspurOSSPutBucketCORSResult

@end

@implementation InspurOSSDeleteBucketCORSRequest
- (NSDictionary *)requestParams {
    return @{@"cors": @""};
}
@end

@implementation InspurOSSDeleteBucketCORSResult

@end

@implementation InspurOSSGetVersioningRequest
- (NSDictionary *)requestParams {
    return @{@"versioning": @""};
}
@end

@implementation InspurOSSGetVersioningResult

@end

@implementation InspurOSSPutVersioningRequest
@end

@implementation InspurOSSPutVersioningResult
@end

@implementation InspurOSSGetBucketEncryptionRequest
- (NSDictionary *)requestParams {
    return @{@"encryption": @""};
}
@end

@implementation InspurOSSGetBucketEncryptionResult
@end

@implementation InspurOSSPutBucketEncryptionRequest
@end

@implementation InspurOSSPutBucketEncryptionResult
@end

@implementation InspurOSSDeleteBucketEncryptionRequest
@end

@implementation InspurOSSDeleteBucketEncryptionResult
@end


@implementation InspurOSSGetBucketWebsiteRequest
- (NSDictionary *)requestParams {
    return @{@"website": @""};
}
@end

@implementation InspurOSSGetBucketWebsiteResult
@end

@implementation InspurOSSPutBucketWebsiteRequest
@end

@implementation InspurOSSPutBucketWebsiteResult
@end

@implementation InspurOSSDeleteBucketWebsiteRequest
@end

@implementation InspurOSSDeleteBucketWebsiteResult
@end

@implementation InspurOSSGetBucketDomainRequest
- (NSDictionary *)requestParams {
    return @{@"domain": @""};
}
@end

@implementation InspurOSSGetBucketDomainResult
@end

@implementation InspurOSSPutBucketDomainRequest
@end

@implementation InspurOSSPutBucketDomainResult
@end

@implementation InspurOSSDeleteBucketDomainRequest
@end

@implementation InspurOSSDeleteBucketDomainResult
@end

@implementation InspurOSSGetBucketLifeCycleRequest
- (NSDictionary *)requestParams {
    return @{@"lifecycle": @""};
}
@end

@implementation InspurOSSGetBucketLifeCycleResult
@end

@implementation InspurOSSPutBucketLifeCycleRequest
@end

@implementation InspurOSSPutBucketLifeCycleResult
@end

@implementation InspurOSSDeleteBucketLifeCycleRequest
@end

@implementation InspurOSSDeleteBucketLifeCycleResult
@end

@implementation InspurOSSGetBucketPolicyRequest
- (NSDictionary *)requestParams {
    return @{@"policy": @""};
}
@end

@implementation InspurOSSGetBucketPolicyResult
@end

@implementation InspurOSSPutBucketPolicyRequest
@end

@implementation InspurOSSPutBucketPolicyResult
@end

@implementation InspurOSSDeleteBucketPolicyRequest
- (NSDictionary *)requestParams {
    return @{@"policy": @""};
}
@end

@implementation InspurOSSDeleteBucketPolicyResult
@end


@implementation InspurOSSHeadObjectRequest
@end

@implementation InspurOSSHeadObjectResult
@end

@implementation InspurOSSGetObjectRequest
@end

@implementation InspurOSSGetObjectResult
@end

@implementation InspurOSSPutObjectACLRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _acl = @"default";
    }
    return self;
}

@end

@implementation InspurOSSPutObjectMetaRequest
- (NSDictionary *)requestParams {
    return @{@"metadata": @""};
}
@end

@implementation InspurOSSPutObjectACLResult
@end

@implementation InspurOSSPutObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation InspurOSSPutObjectResult
@end

@implementation InspurOSSAppendObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation InspurOSSAppendObjectResult
@end

@implementation InspurOSSDeleteObjectRequest
@end

@implementation InspurOSSDeleteObjectResult
@end

@implementation InspurOSSCopyObjectRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation InspurOSSCopyObjectResult
@end

@implementation InspurOSSInitMultipartUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.objectMeta = [NSDictionary new];
    }
    return self;
}

@end

@implementation InspurOSSInitMultipartUploadResult
@end

@implementation InspurOSSUploadPartRequest
@end

@implementation InspurOSSUploadPartResult
@end

@implementation InspurOSSPartInfo

+ (instancetype)partInfoWithPartNum:(int32_t)partNum
                               eTag:(NSString *)eTag
                               size:(int64_t)size {
    return [self partInfoWithPartNum:partNum
                                eTag:eTag
                                size:size
                               crc64:0];
}

+ (instancetype)partInfoWithPartNum:(int32_t)partNum eTag:(NSString *)eTag size:(int64_t)size crc64:(uint64_t)crc64
{
    InspurOSSPartInfo *parInfo = [InspurOSSPartInfo new];
    parInfo.partNum = partNum;
    parInfo.eTag = eTag;
    parInfo.size = size;
    parInfo.crc64 = crc64;
    return parInfo;
}

- (nonnull NSDictionary *)entityToDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(_partNum) forKey:@"partNum"];
    if (_eTag)
    {
        [dict setValue:_eTag forKey:@"eTag"];
    }
    [dict setValue:@(_size) forKey:@"size"];
    [dict setValue:@(_crc64) forKey:@"crc64"];
    return [dict copy];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSSPartInfo<%p>:{partNum: %d,eTag: %@,partSize: %lld,crc64: %llu}",self,self.partNum,self.eTag,self.size,self.crc64];
}

#pragma marks - Protocol Methods
- (id)copyWithZone:(nullable NSZone *)zone
{
    InspurOSSPartInfo *instance = [[[self class] allocWithZone:zone] init];
    instance.partNum = self.partNum;
    instance.eTag = self.eTag;
    instance.size = self.size;
    instance.crc64 = self.crc64;
    return instance;
}

@end

@implementation InspurOSSCompleteMultipartUploadRequest
@end

@implementation OSSCompleteMultipartUploadResult
@end

@implementation InspurOSSAbortMultipartUploadRequest
@end

@implementation InspurOSSAbortMultipartUploadResult
@end

@implementation InspurOSSListPartsRequest
@end

@implementation InspurOSSListPartsResult
@end

@implementation InspurOSSMultipartUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.partSize = 256 * 1024;
    }
    return self;
}

- (void)cancel {
    [super cancel];
}

@end

@implementation InspurOSSResumableUploadRequest

- (instancetype)init {
    if (self = [super init]) {
        self.deleteUploadIdOnCancelling = YES;
        self.partSize = 256 * 1024;
    }
    return self;
}

- (void)cancel {
    [super cancel];
    if(_runningChildrenRequest){
        [_runningChildrenRequest cancel];
    }
}

@end

@implementation InspurOSSResumableUploadResult
@end

@implementation InspurOSSCallBackRequest
@end

@implementation InspurOSSCallBackResult
@end

@implementation InspurOSSImagePersistRequest
@end

@implementation InspurOSSImagePersistResult
@end

@implementation InspurOSSCORSRule

- (NSString *)toRuleString {
    NSMutableString *string = [NSMutableString new];
    if (self.ID.length > 0) {
        [string appendFormat:@"<ID>%@</ID>", self.ID];
    }
    for (NSString *origion in self.allowedOriginList) {
        [string appendFormat:@"<AllowedOrigin>%@</AllowedOrigin>", origion];
    }
    for (NSString *method in self.allowedMethodList) {
        [string appendFormat:@"<AllowedMethod>%@</AllowedMethod>", method];
    }
    for (NSString *header in self.allowedHeaderList) {
        [string appendFormat:@"<AllowedHeader>%@</AllowedHeader>", header];
    }
    for (NSString *expose in self.exposeHeaderList) {
        [string appendFormat:@"<ExposeHeader>%@</ExposeHeader>", expose];
    }
    [string appendFormat:@"<MaxAgeSeconds>%@</MaxAgeSeconds>", self.maxAgeSeconds];
    return string;
}


@end

@implementation InspurOSSDomainConfig

- (NSString *)toRuleString {
    return [NSString stringWithFormat:@""];
}


@end

@implementation InspurOSSPolicyStatement

@end

@implementation InspurOSSGetObjectVersionRequest
- (NSDictionary *)requestParams {
    return @{@"versions": @""};
}

@end

@implementation InspurOSSGetObjectVersionResult

@end

@implementation InspurOSSDeleteObjectVersionRequest

@end

@implementation InspurOSSDeleteObjectVersionResult

@end

