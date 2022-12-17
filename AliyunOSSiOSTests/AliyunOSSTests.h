//
//  AliyunOSSTests.h
//  InspurOSSiOSTests
//
//  Created by xx on 2018/1/18.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import "OSSTestMacros.h"

@interface AliyunOSSTests : XCTestCase

@property (nonatomic, strong) InspurOSSClient *client;
@property (nonatomic, copy) NSArray<NSString *> *fileNames;
@property (nonatomic, copy) NSArray<NSNumber *> *fileSizes;

@end
