//
//  OSSInputStreamHelper.h
//  InspurOSSSDK
//
//  Created by xx on 2017/12/7.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface InspurOSSInputStreamHelper : NSObject

@property (nonatomic, assign) uint64_t crc64;

- (instancetype)initWithFileAtPath:(nonnull NSString *)path;
- (instancetype)initWithURL:(nonnull NSURL *)URL;

- (void)syncReadBuffers;

@end
NS_ASSUME_NONNULL_END
