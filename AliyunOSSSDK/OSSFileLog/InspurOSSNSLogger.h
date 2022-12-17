//
//  OSSNSLogger.h
//  InspurOSSiOS
//
//  Created by xx on 2017/10/24.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSSDDLog.h"

@interface InspurOSSNSLogger : OSSDDAbstractLogger <OSSDDLogger>
@property (class, readonly, strong) InspurOSSNSLogger *sharedInstance;
@end
