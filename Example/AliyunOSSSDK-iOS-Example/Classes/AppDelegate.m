//
//  AppDelegate.m
//  InspurOSSSDK-Example
//
//  Created by xx on 2017/11/22.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import "AppDelegate.h"
#import "InspurOSSManager.h"
#import "OSSTestMacros.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // 针对只有一个region下bucket的数据上传下载操作时,可以将client实例给App单例持有。
    id<InspurOSSCredentialProvider> credentialProvider = [[InspurOSSAuthCredentialProvider alloc] initWithAuthServerUrl:OSS_STSTOKEN_URL];
    InspurOSSClientConfiguration *cfg = [[InspurOSSClientConfiguration alloc] init];
    cfg.maxRetryCount = 3;
    cfg.timeoutIntervalForRequest = 15;
    cfg.isHttpdnsEnable = NO;
    cfg.crc64Verifiable = YES;
    
    InspurOSSClient *defaultClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_ENDPOINT credentialProvider:credentialProvider clientConfiguration:cfg];
    [InspurOSSManager sharedManager].defaultClient = defaultClient;
    
    InspurOSSClient *defaultImgClient = [[InspurOSSClient alloc] initWithEndpoint:OSS_IMG_ENDPOINT credentialProvider:credentialProvider clientConfiguration:cfg];
    [InspurOSSManager sharedManager].imageClient = defaultImgClient;
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
