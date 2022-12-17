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

#import "OSSNetworking.h"
#import "OSSNetworkingRequestDelegate.h"
#import "OSSAllRequestNeededMessage.h"
#import "OSSURLRequestRetryHandler.h"
#import "OSSHttpResponseParser.h"
#import "OSSRequest.h"
#import "InspurOSSGetObjectACLRequest.h"
#import "OSSGetObjectACLResult.h"
#import "InspurOSSDeleteMultipleObjectsRequest.h"
#import "OSSDeleteMultipleObjectsResult.h"
#import "InspurOSSGetBucketInfoRequest.h"
#import "OSSGetBucketInfoResult.h"
#import "InspurOSSPutSymlinkRequest.h"
#import "OSSPutSymlinkResult.h"
#import "InspurOSSGetSymlinkRequest.h"
#import "OSSGetSymlinkResult.h"
#import "InspurOSSRestoreObjectRequest.h"
#import "OSSRestoreObjectResult.h"
#import "InspurOSSGetObjectTaggingRequest.h"
#import "OSSGetObjectTaggingResult.h"
#import "InspurOSSPutObjectTaggingRequest.h"
#import "OSSPutObjectTaggingResult.h"
#import "InspurOSSDeleteObjectTaggingRequest.h"
#import "OSSDeleteObjectTaggingResult.h"

#import "OSSImageProcess.h"

#import "InspurOSSClient.h"
#import "OSSModel.h"
#import "OSSUtil.h"
#import "OSSLog.h"

#import "OSSBolts.h"
