//
//  OSSCredentialProviderTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/20.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"
#import "OSSTestUtils.h"

@interface OSSCredentialProviderTests : XCTestCase
{
    InspurOSSFederationToken *_token;
    NSString *_privateBucketName;
}

@end

@implementation OSSCredentialProviderTests

- (void)setUp
{
    [super setUp];
    NSArray *array1 = [self.name componentsSeparatedByString:@" "];
    NSString *testName = [[array1[1] substringToIndex:([array1[1] length] -1)] lowercaseString];
    _privateBucketName = [@"oss-ios-" stringByAppendingString:testName];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setUpFederationToken];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)setUpFederationToken
{
    NSURL * url = [NSURL URLWithString:OSS_STSTOKEN_URL];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    InspurOSSTaskCompletionSource * tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                     XCTAssertNil(error);
                                                     [tcs setResult:data];
                                                 }];
    [dataTask resume];
    [tcs.task waitUntilFinished];
    
    NSDictionary * result = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                            options:kNilOptions
                                                              error:nil];
    XCTAssertNotNil(result);
    _token = [InspurOSSFederationToken new];
    _token.tAccessKey = result[@"AccessKeyId"];
    _token.tSecretKey = result[@"AccessKeySecret"];
    _token.tToken = result[@"SecurityToken"];
    _token.expirationTimeInGMTFormat = result[@"Expiration"];
    
    NSLog(@"tokenInfo: %@", _token);
}

- (void)headObjectWithBackgroundSessionIdentifier:(nonnull NSString *)identifier provider:(id<InspurOSSCredentialProvider>)provider
{
    InspurOSSClientConfiguration *config = [InspurOSSClientConfiguration new];
    config.backgroundSesseionIdentifier = identifier;
    config.enableBackgroundTransmitService = YES;
    
    InspurOSSClient *client = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:provider];
    InspurOSSCreateBucketRequest *createBucket1 = [InspurOSSCreateBucketRequest new];
    createBucket1.bucketName = _privateBucketName;
    [[client createBucket:createBucket1] waitUntilFinished];
    InspurOSSPutObjectRequest * put = [InspurOSSPutObjectRequest new];
    put.bucketName = _privateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[client putObject:put] waitUntilFinished];
    
    InspurOSSHeadObjectRequest *request = [InspurOSSHeadObjectRequest new];
    request.bucketName = _privateBucketName;
    request.objectKey = OSS_IMAGE_KEY;
    InspurOSSTask *task = [client headObject:request];
    [task waitUntilFinished];
    
    XCTAssertNil(task.error);
    
    [OSSTestUtils cleanBucket:_privateBucketName with:client];
}

- (void)testForFederationCredentialProvider
{
    InspurOSSFederationCredentialProvider *provider = [[InspurOSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^InspurOSSFederationToken *{
        return _token;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.federationprovider.identifier" provider:provider];
}

- (void)testGetStsTokenCredentialProvider
{
    InspurOSSStsTokenCredentialProvider *provider = [[InspurOSSStsTokenCredentialProvider alloc] initWithAccessKeyId:_token.tAccessKey secretKeyId:_token.tSecretKey securityToken:_token.tToken];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.ststokencredentialprovider.identifier" provider:provider];
}

- (void)testCustomSignerCredentialProvider
{
    InspurOSSCustomSignerCredentialProvider *provider = [[InspurOSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        
        InspurOSSFederationToken *token = [InspurOSSFederationToken new];
        token.tAccessKey = OSS_ACCESSKEY_ID;
        token.tSecretKey = OSS_SECRETKEY_ID;
        
        NSString *signedContent = [InspurOSSUtil sign:contentToSign withToken:token];
        return signedContent;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.customsignercredentialprovider.identifier" provider:provider];
}

-(void)testPlainTextAKSKPairCredentialProvider
{
    // invalid credentialProvider
    InspurOSSPlainTextAKSKPairCredentialProvider *provider = [[InspurOSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:OSS_ACCESSKEY_ID secretKey:OSS_SECRETKEY_ID];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.plainakskpaircredentialprovider.identifier" provider:provider];
}

-(void)testAuthCredentialProvider
{
    // invalid credentialProvider
    InspurOSSAuthCredentialProvider *provider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.authcredentialprovider.identifier" provider:provider];
}

- (void)testAuthCredentialProviderWithDecoder
{
    id<InspurOSSCredentialProvider> provider =
    [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL responseDecoder:^NSData *(NSData *data) {
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSData* decodeData = [str dataUsingEncoding:NSUTF8StringEncoding];
        if (decodeData) {
            return decodeData;
        }
        return data;
    }];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.authcredentialproviderwithdecoder.identifier" provider:provider];
}

@end
