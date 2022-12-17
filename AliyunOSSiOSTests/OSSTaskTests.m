//
//  OSSTaskTests.m
//  AliyunOSSiOSTests
//
//  Created by 怀叙 on 2017/11/15.
//  Copyright © 2017年 zhouzhuo. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AliyunOSSiOS/AliyunOSSiOS.h>

@interface OSSTaskTests : XCTestCase

@end

@implementation OSSTaskTests

- (void)testBasicOnSuccess {
    [[[InspurOSSTask taskWithResult:@"foo"] continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testBasicOnSuccessWithExecutor {
    __block BOOL completed = NO;
    InspurOSSTask *task = [[InspurOSSTask taskWithDelay:100] continueWithExecutor:[InspurOSSExecutor immediateExecutor]
                                                   withSuccessBlock:^id _Nullable(InspurOSSTask * _Nonnull _) {
                                                       completed = YES;
                                                       return nil;
                                                   }];
    [task waitUntilFinished];
    XCTAssertTrue(completed);
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.faulted);
    XCTAssertFalse(task.cancelled);
    XCTAssertNil(task.result);
}

- (void)testBasicOnSuccessWithToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSTask *task = [InspurOSSTask taskWithDelay:100];
    
    task = [task continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTFail(@"Success block should not be triggered");
        return nil;
    } cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled);
}

- (void)testBasicOnSuccessWithExecutorToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSTask *task = [InspurOSSTask taskWithDelay:100];
    
    task = [task continueWithExecutor:[InspurOSSExecutor immediateExecutor]
                         successBlock:^id(InspurOSSTask *t) {
                             XCTFail(@"Success block should not be triggered");
                             return nil;
                         }
                    cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled);
}

- (void)testBasicOnSuccessWithCancelledToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSTask *task = [InspurOSSTask taskWithResult:nil];
    
    [cts cancel];
    
    task = [task continueWithExecutor:[InspurOSSExecutor immediateExecutor]
                         successBlock:^id(InspurOSSTask *t) {
                             XCTFail(@"Success block should not be triggered");
                             return nil;
                         }
                    cancellationToken:cts.token];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testBasicContinueWithError {
    NSError *originalError = [NSError errorWithDomain:@"Bolts" code:22 userInfo:nil];
    [[[InspurOSSTask taskWithError:originalError] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error, @"Task should have failed.");
        XCTAssertEqual((NSInteger)22, t.error.code);
        return nil;
    }] waitUntilFinished];
}

- (void)testBasicContinueWithToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSTask *task = [InspurOSSTask taskWithDelay:100];
    
    task = [task continueWithExecutor:[InspurOSSExecutor immediateExecutor]
                                block:^id(InspurOSSTask *t) {
                                    XCTFail(@"Continuation block should not be triggered");
                                    return nil;
                                }
                    cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testBasicContinueWithCancelledToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    InspurOSSTask *task = [InspurOSSTask taskWithResult:nil];
    
    [cts cancel];
    
    task = [task continueWithExecutor:[InspurOSSExecutor immediateExecutor]
                                block:^id(InspurOSSTask *t) {
                                    XCTFail(@"Continuation block should not be triggered");
                                    return nil;
                                }
                    cancellationToken:cts.token];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testFinishLaterWithSuccess {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = @"bar";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testFinishLaterWithError {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testTransformConstantToConstant {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return @"bar";
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testTransformErrorToConstant {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return @"bar";
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnSuccessfulTaskFromContinuation {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        return [InspurOSSTask taskWithResult:@"bar"];
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnSuccessfulTaskFromContinuationAfterError {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        return [InspurOSSTask taskWithResult:@"bar"];
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"bar", t.result);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnErrorTaskFromContinuation {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        NSError *originalError = [NSError errorWithDomain:@"Bolts" code:24 userInfo:nil];
        return [InspurOSSTask taskWithError:originalError];
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)24, t.error.code);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnErrorTaskFromContinuationAfterError {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)23, t.error.code);
        NSError *originalError = [NSError errorWithDomain:@"Bolts" code:24 userInfo:nil];
        return [InspurOSSTask taskWithError:originalError];
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)24, t.error.code);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:23 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testReturnErrorTaskFromContinuationWithException {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[tcs.task continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"foo", t.result);
        NSArray *arr = @[];
        [arr objectAtIndex:1];
        NSError *originalError = [NSError errorWithDomain:@"Bolts" code:24 userInfo:nil];
        return [InspurOSSTask taskWithError:originalError];
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual(OSSClientErrorCodeExcpetionCatched, t.error.code);
        return nil;
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = @"foo";
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testPassOnError {
    NSError *originalError = [NSError errorWithDomain:@"Bolts" code:30 userInfo:nil];
    [[[[[[[[InspurOSSTask taskWithError:originalError] continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)30, t.error.code);
        NSError *newError = [NSError errorWithDomain:@"Bolts" code:31 userInfo:nil];
        return [InspurOSSTask taskWithError:newError];
    }] continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTFail(@"This callback should be skipped.");
        return nil;
    }] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertEqual((NSInteger)31, t.error.code);
        return [InspurOSSTask taskWithResult:@"okay"];
    }] continueWithSuccessBlock:^id(InspurOSSTask *t) {
        XCTAssertEqualObjects(@"okay", t.result);
        return nil;
    }] waitUntilFinished];
}

- (void)testCancellation {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [[InspurOSSTask taskWithDelay:100] continueWithBlock:^id(InspurOSSTask *t) {
        return tcs.task;
    }];
    
    [tcs cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.isCancelled);
}

- (void)testCompleteWithSuccess {
    InspurOSSResult *putResult = [InspurOSSPutObjectResult new];
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task completed:^(BOOL isSuccess, NSError * _Nullable error, InspurOSSResult * _Nullable result) {
        XCTAssertTrue(isSuccess);
        XCTAssertNotNil(result);
        XCTAssertEqual(result, putResult);
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.result = putResult;
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testCompleteWithError {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task completed:^(BOOL isSuccess, NSError * _Nullable error, InspurOSSResult * _Nullable result) {
        XCTAssertFalse(isSuccess);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, @"Bolts");
        XCTAssertEqual(error.code, 33);
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.error = [NSError errorWithDomain:@"Bolts" code:33 userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testCompleteWithException {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task completed:^(BOOL isSuccess, NSError * _Nullable error, InspurOSSResult * _Nullable result) {
        XCTAssertFalse(isSuccess);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, OSSClientErrorDomain);
        XCTAssertEqual(error.code, OSSClientErrorCodeExcpetionCatched);
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        tcs.exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                reason:@"test"
                                              userInfo:nil];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testCompleteWithCancel {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    InspurOSSTask *task = [tcs.task completed:^(BOOL isSuccess, NSError * _Nullable error, InspurOSSResult * _Nullable result) {
        XCTAssertFalse(isSuccess);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, OSSClientErrorDomain);
        XCTAssertEqual(error.code, OSSClientErrorCodeTaskCancelled);
    }];
    [[InspurOSSTask taskWithDelay:0] continueWithBlock:^id(InspurOSSTask *t) {
        [tcs cancel];
        return nil;
    }];
    [task waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksSuccess {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[InspurOSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(InspurOSSTask *t) {
            return @(i);
        }]];
    }
    
    [[[InspurOSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        for (int i = 0; i < kTaskCount; ++i) {
            XCTAssertEqual(i, [((InspurOSSTask *)[tasks objectAtIndex:i]).result intValue]);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksOneError {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[InspurOSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(InspurOSSTask *t) {
            if (i == 10) {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:@"BoltsTests"
                                                                 code:35
                                                             userInfo:nil]];
            }
            return @(i);
        }]];
    }
    
    [[[InspurOSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        XCTAssertEqualObjects(@"BoltsTests", t.error.domain);
        XCTAssertEqual(35, (int)t.error.code);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10) {
                XCTAssertNotNil(((InspurOSSTask *)[tasks objectAtIndex:i]).error);
            } else {
                XCTAssertEqual(i, [((InspurOSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksTwoErrors {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[InspurOSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(InspurOSSTask *t) {
            if (i == 10 || i == 11) {
                return [InspurOSSTask taskWithError:[NSError errorWithDomain:@"BoltsTests"
                                                                 code:35
                                                             userInfo:nil]];
            }
            return @(i);
        }]];
    }
    
    [[[InspurOSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNotNil(t.error);
        XCTAssertFalse(t.isCancelled);
        
        XCTAssertEqualObjects(@"bolts", t.error.domain);
        XCTAssertEqual(kOSSMultipleErrorsError, t.error.code);
        
        NSArray *errors = [t.error.userInfo objectForKey:OSSTaskMultipleErrorsUserInfoKey];
        XCTAssertEqualObjects(@"BoltsTests", [[errors objectAtIndex:0] domain]);
        XCTAssertEqual(35, (int)[[errors objectAtIndex:0] code]);
        XCTAssertEqualObjects(@"BoltsTests", [[errors objectAtIndex:1] domain]);
        XCTAssertEqual(35, (int)[[errors objectAtIndex:1] code]);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10 || i == 11) {
                XCTAssertNotNil(((InspurOSSTask *)[tasks objectAtIndex:i]).error);
            } else {
                XCTAssertEqual(i, [((InspurOSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksCancelled {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = rand() % 100;
        [tasks addObject:[[InspurOSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(InspurOSSTask *t) {
            if (i == 10) {
                return [InspurOSSTask cancelledTask];
            }
            return @(i);
        }]];
    }
    
    [[[InspurOSSTask taskForCompletionOfAllTasks:tasks] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertNil(t.error);
        XCTAssertTrue(t.isCancelled);
        
        for (int i = 0; i < kTaskCount; ++i) {
            if (i == 10) {
                XCTAssertTrue(((InspurOSSTask *)[tasks objectAtIndex:i]).isCancelled);
            } else {
                XCTAssertEqual(i, [((InspurOSSTask *)[tasks objectAtIndex:i]).result intValue]);
            }
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksNoTasksImmediateCompletion {
    NSMutableArray *tasks = [NSMutableArray array];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAllTasks:tasks];
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.cancelled);
    XCTAssertFalse(task.faulted);
}

- (void)testTaskForCompletionOfAllTasksWithResultsSuccess {
    NSMutableArray *tasks = [NSMutableArray array];
    
    const int kTaskCount = 20;
    for (int i = 0; i < kTaskCount; ++i) {
        double sleepTimeInMs = i * 10;
        int result = i + 1;
        [tasks addObject:[[InspurOSSTask taskWithDelay:(int)sleepTimeInMs] continueWithBlock:^id(InspurOSSTask *__unused t) {
            return @(result);
        }]];
    }
    
    [[[InspurOSSTask taskForCompletionOfAllTasksWithResults:tasks] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertFalse(t.cancelled);
        XCTAssertFalse(t.faulted);
        
        NSArray *results = t.result;
        for (int i = 0; i < kTaskCount; ++i) {
            NSNumber *individualResult = [results objectAtIndex:i];
            XCTAssertEqual([individualResult intValue], [((InspurOSSTask *)[tasks objectAtIndex:i]).result intValue]);
        }
        return nil;
    }] waitUntilFinished];
}

- (void)testTaskForCompletionOfAllTasksErrorCancelledSuccess {
    InspurOSSTask *errorTask = [InspurOSSTask taskWithError:[NSError new]];
    InspurOSSTask *cancelledTask = [InspurOSSTask cancelledTask];
    InspurOSSTask *successfulTask = [InspurOSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    InspurOSSTask *allTasks = [InspurOSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}

- (void)testTaskForCompletionOfAllTasksExceptionErrorCancelledSuccess {
    InspurOSSTask *errorTask = [InspurOSSTask taskWithError:[NSError new]];
    InspurOSSTask *cancelledTask = [InspurOSSTask cancelledTask];
    InspurOSSTask *successfulTask = [InspurOSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    InspurOSSTask *allTasks = [InspurOSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
    XCTAssertNotNil(allTasks.error, @"Task should have error");
}

- (void)testTaskForCompletionOfAllTasksErrorCancelled {
    InspurOSSTask *errorTask = [InspurOSSTask taskWithError:[NSError new]];
    InspurOSSTask *cancelledTask = [InspurOSSTask cancelledTask];
    
    InspurOSSTask *allTasks = [InspurOSSTask taskForCompletionOfAllTasks:@[ cancelledTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}

- (void)testTaskForCompletionOfAllTasksSuccessCancelled {
    InspurOSSTask *cancelledTask = [InspurOSSTask cancelledTask];
    InspurOSSTask *successfulTask = [InspurOSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    InspurOSSTask *allTasks = [InspurOSSTask taskForCompletionOfAllTasks:@[ successfulTask, cancelledTask ]];
    
    XCTAssertTrue(allTasks.cancelled, @"Task should be cancelled");
}

- (void)testTaskForCompletionOfAllTasksSuccessError {
    InspurOSSTask *errorTask = [InspurOSSTask taskWithError:[NSError new]];
    InspurOSSTask *successfulTask = [InspurOSSTask taskWithResult:[NSNumber numberWithInt:2]];
    
    InspurOSSTask *allTasks = [InspurOSSTask taskForCompletionOfAllTasks:@[ successfulTask, errorTask ]];
    
    XCTAssertTrue(allTasks.faulted, @"Task should be faulted");
}


- (void)testTaskForCompletionOfAllTasksWithResultsNoTasksImmediateCompletion {
    NSMutableArray *tasks = [NSMutableArray array];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAllTasksWithResults:tasks];
    XCTAssertTrue(task.completed);
    XCTAssertFalse(task.cancelled);
    XCTAssertFalse(task.faulted);
    XCTAssertTrue(task.result != nil);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithSuccess {
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:@[[InspurOSSTask taskWithDelay:20], [InspurOSSTask taskWithResult:@"success"]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"success", task.result);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithRacing {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    InspurOSSExecutor *executor = [InspurOSSExecutor executorWithDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    InspurOSSTask *first = [InspurOSSTask taskFromExecutor:executor withBlock:^id _Nullable {
        return @"first";
    }];
    InspurOSSTask *second = [InspurOSSTask taskFromExecutor:executor withBlock:^id _Nullable {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        return @"second";
    }];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:@[first, second]];
    [task waitUntilFinished];
    
    dispatch_semaphore_signal(semaphore);
    
    XCTAssertEqualObjects(@"first", task.result);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithErrorAndSuccess {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:@[[InspurOSSTask taskWithError:error], [InspurOSSTask taskWithResult:@"success"]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"success", task.result);
    XCTAssertNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithError {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:@[[InspurOSSTask taskWithError:error]]];
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(error, task.error);
    XCTAssertNotNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksWithNilArray {
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:nil];
    [task waitUntilFinished];
    
    XCTAssertNil(task.result);
    XCTAssertNil(task.error);
}

- (void)testTasksForTaskForCompletionOfAnyTasksAllErrors {
    NSError *error = [NSError errorWithDomain:@"BoltsTests"
                                         code:35
                                     userInfo:nil];
    
    InspurOSSTask *task = [InspurOSSTask taskForCompletionOfAnyTask:@[[InspurOSSTask taskWithError:error], [InspurOSSTask taskWithError:error]]];
    [task waitUntilFinished];
    
    XCTAssertNil(task.result);
    XCTAssertNotNil(task.error);
    XCTAssertNotNil(task.error.userInfo);
    XCTAssertEqualObjects(@"bolts", task.error.domain);
    XCTAssertTrue([task.error.userInfo[@"errors"] isKindOfClass:[NSArray class]]);
    XCTAssertEqual(2, [task.error.userInfo[@"errors"] count]);
}

- (void)testWaitUntilFinished {
    InspurOSSTask *task = [[InspurOSSTask taskWithDelay:50] continueWithBlock:^id(InspurOSSTask *t) {
        return @"foo";
    }];
    
    [task waitUntilFinished];
    
    XCTAssertEqualObjects(@"foo", task.result);
}

- (void)testDelayWithToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    InspurOSSTask *task = [InspurOSSTask taskWithDelay:100 cancellationToken:cts.token];
    
    [cts cancel];
    [task waitUntilFinished];
    
    XCTAssertTrue(task.cancelled, @"Task should be cancelled immediately");
}

- (void)testDelayWithCancelledToken {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    [cts cancel];
    
    InspurOSSTask *task = [InspurOSSTask taskWithDelay:100 cancellationToken:cts.token];
    
    XCTAssertTrue(task.cancelled, @"Task should be cancelled immediately");
}

- (void)testTaskFromExecutor {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L);
    InspurOSSExecutor *queueExecutor = [InspurOSSExecutor executorWithDispatchQueue:queue];
    
    InspurOSSTask *task = [InspurOSSTask taskFromExecutor:queueExecutor withBlock:^id() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        XCTAssertEqual(queue, dispatch_get_current_queue());
#pragma clang diagnostic pop
        return @"foo";
    }];
    [task waitUntilFinished];
    XCTAssertEqual(@"foo", task.result);
}

- (void)testDescription {
    InspurOSSTask *task = [InspurOSSTask taskWithResult:nil];
    NSString *expected = [NSString stringWithFormat:@"<OSSTask: %p; completed = YES; cancelled = NO; faulted = NO; result = (null)>", task];
    
    NSString *description = task.description;
    
    XCTAssertTrue([expected isEqualToString:description]);
}

- (void)testReturnTaskFromContinuationWithCancellation {
    InspurOSSCancellationTokenSource *cts = [InspurOSSCancellationTokenSource cancellationTokenSource];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"task"];
    [[[InspurOSSTask taskWithDelay:1] continueWithBlock:^id(InspurOSSTask *t) {
        [cts cancel];
        return [InspurOSSTask taskWithDelay:10];
    } cancellationToken:cts.token] continueWithBlock:^id(InspurOSSTask *t) {
        XCTAssertTrue(t.cancelled);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSetResult {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    taskCompletionSource.result = @"a";
    XCTAssertThrowsSpecificNamed([taskCompletionSource setResult:@"b"], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertEqualObjects(taskCompletionSource.task.result, @"a");
}

- (void)testTrySetResult {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    [taskCompletionSource trySetResult:@"a"];
    [taskCompletionSource trySetResult:@"b"];
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertEqualObjects(taskCompletionSource.task.result, @"a");
}

- (void)testSetError {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    NSError *error = [NSError errorWithDomain:@"TestDomain" code:100500 userInfo:nil];
    taskCompletionSource.error = error;
    XCTAssertThrowsSpecificNamed([taskCompletionSource setError:error], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.error, error);
}

- (void)testTrySetError {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    NSError *error = [NSError errorWithDomain:@"TestDomain" code:100500 userInfo:nil];
    [taskCompletionSource trySetError:error];
    [taskCompletionSource trySetError:error];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.error, error);
}

- (void)testSetException {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    NSException *exception = [NSException exceptionWithName:@"testExceptionName" reason:@"testExceptionReason" userInfo:nil];
    taskCompletionSource.exception = exception;
    XCTAssertThrowsSpecificNamed([taskCompletionSource setException:exception], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.exception, exception);
}

- (void)testTrySetException {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    NSException *exception = [NSException exceptionWithName:@"testExceptionName" reason:@"testExceptionReason" userInfo:nil];
    [taskCompletionSource trySetException:exception];
    [taskCompletionSource trySetException:exception];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.faulted);
    XCTAssertEqualObjects(taskCompletionSource.task.exception, exception);
}

- (void)testSetCancelled {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    [taskCompletionSource cancel];
    XCTAssertThrowsSpecificNamed([taskCompletionSource cancel], NSException, NSInternalInconsistencyException);
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.cancelled);
}

- (void)testTrySetCancelled {
    InspurOSSTaskCompletionSource *taskCompletionSource = [InspurOSSTaskCompletionSource taskCompletionSource];
    
    [taskCompletionSource trySetCancelled];
    [taskCompletionSource trySetCancelled];
    
    XCTAssertTrue(taskCompletionSource.task.completed);
    XCTAssertTrue(taskCompletionSource.task.cancelled);
}

- (void)testMultipleWaitUntilFinished {
    InspurOSSTask *task = [[InspurOSSTask taskWithDelay:50] continueWithBlock:^id(InspurOSSTask *t) {
        return @"foo";
    }];
    
    [task waitUntilFinished];
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [task waitUntilFinished];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testMultipleThreadsWaitUntilFinished {
    InspurOSSTask *task = [[InspurOSSTask taskWithDelay:500] continueWithBlock:^id(InspurOSSTask *t) {
        return @"foo";
    }];
    
    dispatch_queue_t queue = dispatch_queue_create("com.bolts.tests.wait", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_async(group, queue, ^{
            [task waitUntilFinished];
        });
        dispatch_group_async(group, queue, ^{
            [task waitUntilFinished];
        });
        [task waitUntilFinished];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
