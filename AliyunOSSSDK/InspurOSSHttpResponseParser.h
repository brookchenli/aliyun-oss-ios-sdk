//
//  OSSHttpResponseParser.h
//  InspurOSSSDK
//
//  Created by xx on 2018/1/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InspurOSSConstants.h"
#import "InspurOSSTask.h"

NS_ASSUME_NONNULL_BEGIN

/**
 HTTP response parser
 */
@interface InspurOSSHttpResponseParser : NSObject

@property (nonatomic, copy) OSSNetworkingOnRecieveDataBlock onRecieveBlock;

@property (nonatomic, strong) NSURL *downloadingFileURL;

/**
 *  A Boolean value that determines whether verfifying crc64.
 When set to YES, it will verify crc64 when transmission is completed normally.
 The default value of this property is NO.
 */
@property (nonatomic, assign) BOOL crc64Verifiable;

- (instancetype)initForOperationType:(InspurOSSOperationType)operationType;
- (void)consumeHttpResponse:(NSHTTPURLResponse *)response;
- (InspurOSSTask *)consumeHttpResponseBody:(NSData *)data;
- (nullable id)constructResultObject;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
