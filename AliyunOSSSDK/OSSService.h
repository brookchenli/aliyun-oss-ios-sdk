//
//  OSSService.h
//  oss_ios_sdk
//
//  Created by zhouzhuo on 8/20/15.
//  Copyright (c) 2015 aliyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define OSS_IOS_SDK_VERSION OSSSDKVersion

#import "OSSDefine.h"
#import "OSSConstants.h"

#import "InspurOSSNetworking.h"
#import "InspurOSSNetworkingRequestDelegate.h"
#import "InspurOSSAllRequestNeededMessage.h"
#import "InspurOSSURLRequestRetryHandler.h"
#import "InspurOSSHttpResponseParser.h"
#import "InspurOSSRequest.h"
#import "InspurOSSGetObjectACLRequest.h"
#import "InspurOSSGetObjectACLResult.h"
#import "InspurOSSDeleteMultipleObjectsRequest.h"
#import "InspurOSSDeleteMultipleObjectsResult.h"
#import "InspurOSSGetBucketInfoRequest.h"
#import "InspurOSSGetBucketInfoResult.h"
#import "InspurOSSPutSymlinkRequest.h"
#import "InspurOSSPutSymlinkResult.h"
#import "InspurOSSGetSymlinkRequest.h"
#import "InspurOSSGetSymlinkResult.h"
#import "InspurOSSRestoreObjectRequest.h"
#import "InspurOSSRestoreObjectResult.h"
#import "InspurOSSGetObjectTaggingRequest.h"
#import "InspurOSSGetObjectTaggingResult.h"
#import "InspurOSSPutObjectTaggingRequest.h"
#import "InspurOSSPutObjectTaggingResult.h"
#import "InspurOSSDeleteObjectTaggingRequest.h"
#import "InspurOSSDeleteObjectTaggingResult.h"

#import "InspurOSSImageProcess.h"

#import "InspurOSSClient.h"
#import "OSSModel.h"
#import "InspurOSSUtil.h"
#import "OSSLog.h"

#import "OSSBolts.h"
