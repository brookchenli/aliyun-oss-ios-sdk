//
//  OSSCancellationTests.m
//  InspurOSSiOSTests
//
//  Created by xx on 2017/11/15.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AliyunOSSiOS/InspurOSSCancellationTokenSource.h>
#import <AliyunOSSiOS/InspurOSSCancellationTokenRegistration.h>
#import <AliyunOSSiOS/InspurOSSCancellationToken.h>

@interface OSSCancellationTests : XCTestCase

@end

@implementation OSSCancellationTests

- (void)testCancel {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancel];
    
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
}

- (void)testCancelMultipleTimes {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
    
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testCancellationBlock {
    __block BOOL cancelled = NO;
    
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts.token registerCancellationObserverWithBlock:^{
        cancelled = YES;
    }];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancel];
    
    XCTAssertTrue(cancelled, @"Source should be cancelled");
}

- (void)testCancellationAfterDelay {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested, @"Source should not be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should not be cancelled");
    
    [cts cancelAfterDelay:200];
    XCTAssertFalse(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertFalse(cts.token.cancellationRequested, @"Token should be cancelled");
    
    // Spin the run loop for half a second, since `delay` is in milliseconds, not seconds.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
}

- (void)testCancellationAfterDelayValidation {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    XCTAssertThrowsSpecificNamed([cts cancelAfterDelay:-2], NSException, NSInvalidArgumentException);
}

- (void)testCancellationAfterZeroDelay {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    XCTAssertFalse(cts.cancellationRequested);
    XCTAssertFalse(cts.token.cancellationRequested);
    
    [cts cancelAfterDelay:0];
    
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testCancellationAfterDelayOnCancelled {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
    
    [cts cancelAfterDelay:1];
    
    XCTAssertTrue(cts.cancellationRequested);
    XCTAssertTrue(cts.token.cancellationRequested);
}

- (void)testDispose {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts dispose];
    XCTAssertThrowsSpecificNamed([cts cancel], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.cancellationRequested, NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.token.cancellationRequested, NSException, NSInternalInconsistencyException);
    
    cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    XCTAssertTrue(cts.cancellationRequested, @"Source should be cancelled");
    XCTAssertTrue(cts.token.cancellationRequested, @"Token should be cancelled");
    
    [cts dispose];
    XCTAssertThrowsSpecificNamed(cts.cancellationRequested, NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(cts.token.cancellationRequested, NSException, NSInternalInconsistencyException);
}

- (void)testDisposeMultipleTimes {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts dispose];
    XCTAssertNoThrow([cts dispose]);
}

- (void)testDisposeRegistration {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{
        XCTFail();
    }];
    XCTAssertNoThrow([registration dispose]);
    
    [cts cancel];
}

- (void)testDisposeRegistrationMultipleTimes {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{
        XCTFail();
    }];
    XCTAssertNoThrow([registration dispose]);
    XCTAssertNoThrow([registration dispose]);
    
    [cts cancel];
}

- (void)testDisposeRegistrationAfterCancellationToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{ }];
    
    [registration dispose];
    [cts dispose];
}

- (void)testDisposeRegistrationBeforeCancellationToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSCancellationTokenRegistration *registration = [cts.token registerCancellationObserverWithBlock:^{ }];
    
    [cts dispose];
    XCTAssertNoThrow([registration dispose]);
}

@end
