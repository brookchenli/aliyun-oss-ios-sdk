//
//  OSSNetworkingRequestDelegate.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurOSSConstants.h"
#import "InspurOSSTask.h"

@class InspurOSSAllRequestNeededMessage;
@class InspurOSSURLRequestRetryHandler;
@class InspurOSSHttpResponseParser;

/**
 The proxy object class for each OSS request.
 */
@interface InspurOSSNetworkingRequestDelegate : NSObject

@property (nonatomic, strong) NSMutableArray * interceptors;

@property (nonatomic, strong) NSMutableURLRequest *internalRequest;
@property (nonatomic, assign) InspurOSSOperationType operType;
@property (nonatomic, assign) BOOL isAccessViaProxy;

@property (nonatomic, assign) BOOL isRequestCancelled;

@property (nonatomic, strong) InspurOSSAllRequestNeededMessage *allNeededMessage;
@property (nonatomic, strong) InspurOSSURLRequestRetryHandler *retryHandler;
@property (nonatomic, strong) InspurOSSHttpResponseParser *responseParser;

@property (nonatomic, strong) NSData * uploadingData;
@property (nonatomic, strong) NSURL * uploadingFileURL;

@property (nonatomic, assign) int64_t payloadTotalBytesWritten;

@property (nonatomic, assign) BOOL isBackgroundUploadFileTask;
@property (nonatomic, assign) BOOL isHttpdnsEnable;

@property (nonatomic, assign) BOOL isPathStyleAccessEnable;
@property (nonatomic, assign) BOOL isCustomPathPrefixEnable;
@property (nonatomic, copy) NSArray * cnameExcludeList;

@property (nonatomic, assign) uint32_t currentRetryCount;
@property (nonatomic, strong) NSError * error;
@property (nonatomic, assign) BOOL isHttpRequestNotSuccessResponse;
@property (nonatomic, strong) NSMutableData *httpRequestNotSuccessResponseBody;

@property (atomic, strong) NSURLSessionDataTask *currentSessionTask;

@property (nonatomic, copy) OSSNetworkingUploadProgressBlock uploadProgress;
@property (nonatomic, copy) OSSNetworkingDownloadProgressBlock downloadProgress;
@property (nonatomic, copy) OSSNetworkingRetryBlock retryCallback;
@property (nonatomic, copy) OSSNetworkingCompletionHandlerBlock completionHandler;
@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveData;

/**
 * when put object to server,client caculate crc64 code and assigns it to
 * this property.
 */
@property (nonatomic, copy) NSString *contentCRC;

/** last crc64 code */
@property (nonatomic, copy) NSString *lastCRC;

/**
 * determine whether to verify crc64 code
 */
@property (nonatomic, assign) BOOL crc64Verifiable;



- (InspurOSSTask *)buildInternalHttpRequest;
- (void)reset;
- (void)cancel;

@end
