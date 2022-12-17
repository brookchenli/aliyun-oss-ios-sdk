/*
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "InspurOSSTask.h"
#import "InspurOSSLog.h"
#import "InspurOSSConstants.h"
#import "InspurOSSDefine.h"

#import <libkern/OSAtomic.h>

#import "OSSBolts.h"

NS_ASSUME_NONNULL_BEGIN

__attribute__ ((noinline)) void ossWarnBlockingOperationOnMainThread() {
    NSLog(@"Warning: A long-running operation is being executed on the main thread. \n"
          " Break on warnBlockingOperationOnMainThread() to debug.");
}

NSString *const OSSTaskErrorDomain = @"bolts";
NSInteger const kOSSMultipleErrorsError = 80175001;
NSString *const OSSTaskMultipleExceptionsException = @"OSSMultipleExceptionsException";

NSString *const OSSTaskMultipleErrorsUserInfoKey = @"errors";
NSString *const OSSTaskMultipleExceptionsUserInfoKey = @"exceptions";

@interface InspurOSSTask () {
    id _result;
    NSError *_error;
    NSException *_exception;
}

@property (nonatomic, assign, readwrite, getter=isCancelled) BOOL cancelled;
@property (nonatomic, assign, readwrite, getter=isFaulted) BOOL faulted;
@property (nonatomic, assign, readwrite, getter=isCompleted) BOOL completed;

@property (nonatomic, strong) NSObject *lock;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, strong) NSMutableArray *callbacks;

@end

@implementation InspurOSSTask

#pragma mark - Initializer

- (instancetype)init {
    self = [super init];
    if (!self) return self;

    _lock = [[NSObject alloc] init];
    _condition = [[NSCondition alloc] init];
    _callbacks = [NSMutableArray array];

    return self;
}

- (instancetype)initWithResult:(_Nullable id)result {
    self = [super init];
    if (self) {
        [self trySetResult:result];
    }
    return self;
}

- (instancetype)initWithError:(NSError *)error {
    self = [super init];
    if (!self) return self;

    [self trySetError:error];

    return self;
}

- (instancetype)initWithException:(NSException *)exception {
    self = [super init];
    if (!self) return self;

    [self trySetException:exception];

    return self;
}

- (instancetype)initCancelled {
    self = [super init];
    if (!self) return self;

    [self trySetCancelled];

    return self;
}

#pragma mark - Task Class methods

+ (instancetype)taskWithResult:(_Nullable id)result {
    return [[self alloc] initWithResult:result];
}

+ (instancetype)taskWithError:(NSError *)error {
    return [[self alloc] initWithError:error];
}

+ (instancetype)taskWithException:(NSException *)exception {
    return [[self alloc] initWithException:exception];
}

+ (instancetype)cancelledTask {
    return [[self alloc] initCancelled];
}

+ (instancetype)taskForCompletionOfAllTasks:(nullable NSArray<InspurOSSTask *> *)tasks {
    __block int32_t total = (int32_t)tasks.count;
    if (total == 0) {
        return [self taskWithResult:nil];
    }

    __block int32_t cancelled = 0;
    NSObject *lock = [[NSObject alloc] init];
    NSMutableArray *errors = [NSMutableArray array];
    NSMutableArray *exceptions = [NSMutableArray array];

    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    for (InspurOSSTask *task in tasks) {
        [task continueWithBlock:^id(InspurOSSTask *task) {
            if (task.exception) {
                @synchronized (lock) {
                    [exceptions addObject:task.exception];
                }
            } else if (task.error) {
                @synchronized (lock) {
                    [errors addObject:task.error];
                }
            } else if (task.cancelled) {
                OSAtomicIncrement32Barrier(&cancelled);
            }

            if (OSAtomicDecrement32Barrier(&total) == 0) {
                if (exceptions.count > 0) {
                    if (exceptions.count == 1) {
                        tcs.exception = [exceptions firstObject];
                    } else {
                        NSException *exception =
                        [NSException exceptionWithName:OSSTaskMultipleExceptionsException
                                                reason:@"There were multiple exceptions."
                                              userInfo:@{ OSSTaskMultipleExceptionsUserInfoKey: exceptions }];
                        tcs.exception = exception;
                    }
                } else if (errors.count > 0) {
                    if (errors.count == 1) {
                        tcs.error = [errors firstObject];
                    } else {
                        NSError *error = [NSError errorWithDomain:OSSTaskErrorDomain
                                                             code:kOSSMultipleErrorsError
                                                         userInfo:@{ OSSTaskMultipleErrorsUserInfoKey: errors }];
                        tcs.error = error;
                    }
                } else if (cancelled > 0) {
                    [tcs cancel];
                } else {
                    tcs.result = nil;
                }
            }
            return nil;
        }];
    }
    return tcs.task;
}

+ (instancetype)taskForCompletionOfAllTasksWithResults:(nullable NSArray<InspurOSSTask *> *)tasks {
    return [[self taskForCompletionOfAllTasks:tasks] continueWithSuccessBlock:^id(InspurOSSTask *task) {
        return [tasks valueForKey:@"result"];
    }];
}

+ (instancetype)taskForCompletionOfAnyTask:(nullable NSArray<InspurOSSTask *> *)tasks
{
    __block int32_t total = (int32_t)tasks.count;
    if (total == 0) {
        return [self taskWithResult:nil];
    }
    
    __block int completed = 0;
    __block int32_t cancelled = 0;
    
    NSObject *lock = [NSObject new];
    NSMutableArray<NSError *> *errors = [NSMutableArray new];
    NSMutableArray<NSException *> *exceptions = [NSMutableArray new];
    
    InspurOSSTaskCompletionSource *source = [InspurOSSTaskCompletionSource taskCompletionSource];
    for (InspurOSSTask *task in tasks) {
        [task continueWithBlock:^id(InspurOSSTask *task) {
            if (task.exception != nil) {
                @synchronized(lock) {
                    [exceptions addObject:task.exception];
                }
            } else if (task.error != nil) {
                @synchronized(lock) {
                    [errors addObject:task.error];
                }
            } else if (task.cancelled) {
                OSAtomicIncrement32Barrier(&cancelled);
            } else {
                if(OSAtomicCompareAndSwap32Barrier(0, 1, &completed)) {
                    [source setResult:task.result];
                }
            }
            
            if (OSAtomicDecrement32Barrier(&total) == 0 &&
                OSAtomicCompareAndSwap32Barrier(0, 1, &completed)) {
                if (cancelled > 0) {
                    [source cancel];
                } else if (exceptions.count > 0) {
                    if (exceptions.count == 1) {
                        source.exception = exceptions.firstObject;
                    } else {
                        NSException *exception =
                        [NSException exceptionWithName:OSSTaskMultipleExceptionsException
                                                reason:@"There were multiple exceptions."
                                              userInfo:@{ @"exceptions": exceptions }];
                        source.exception = exception;
                    }
                } else if (errors.count > 0) {
                    if (errors.count == 1) {
                        source.error = errors.firstObject;
                    } else {
                        NSError *error = [NSError errorWithDomain:OSSTaskErrorDomain
                                                             code:kOSSMultipleErrorsError
                                                         userInfo:@{ @"errors": errors }];
                        source.error = error;
                    }
                }
            }
            // Abort execution of per tasks continuations
            return nil;
        }];
    }
    return source.task;
}


+ (instancetype)taskWithDelay:(int)millis {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, millis * NSEC_PER_MSEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        tcs.result = nil;
    });
    return tcs.task;
}

+ (instancetype)taskWithDelay:(int)millis cancellationToken:(nullable InspurOSSCancellationToken *)token {
    if (token.cancellationRequested) {
        return [InspurOSSTask cancelledTask];
    }

    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, millis * NSEC_PER_MSEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        if (token.cancellationRequested) {
            [tcs cancel];
            return;
        }
        tcs.result = nil;
    });
    return tcs.task;
}

+ (instancetype)taskFromExecutor:(InspurOSSExecutor *)executor withBlock:(nullable id (^)(void))block {
    return [[self taskWithResult:nil] continueWithExecutor:executor withBlock:^id(InspurOSSTask *task) {
        return block();
    }];
}

#pragma mark - Custom Setters/Getters

- (nullable id)result {
    @synchronized(self.lock) {
        return _result;
    }
}

- (BOOL)trySetResult:(nullable id)result {
    @synchronized(self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        _result = result;
        [self runContinuations];
        return YES;
    }
}

- (nullable NSError *)error {
    @synchronized(self.lock) {
        return _error;
    }
}

- (BOOL)trySetError:(NSError *)error {
    @synchronized(self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        self.faulted = YES;
        _error = error;
        [self runContinuations];
        return YES;
    }
}

- (nullable NSException *)exception {
    @synchronized(self.lock) {
        return _exception;
    }
}

- (BOOL)trySetException:(NSException *)exception {
    @synchronized(self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        self.faulted = YES;
        _exception = exception;
        [self runContinuations];
        return YES;
    }
}

- (BOOL)isCancelled {
    @synchronized(self.lock) {
        return _cancelled;
    }
}

- (BOOL)isFaulted {
    @synchronized(self.lock) {
        return _faulted;
    }
}

- (BOOL)trySetCancelled {
    @synchronized(self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        self.cancelled = YES;
        [self runContinuations];
        return YES;
    }
}

- (BOOL)isCompleted {
    @synchronized(self.lock) {
        return _completed;
    }
}

- (void)runContinuations {
    @synchronized(self.lock) {
        [self.condition lock];
        [self.condition broadcast];
        [self.condition unlock];
        for (void (^callback)(void) in self.callbacks) {
            callback();
        }
        [self.callbacks removeAllObjects];
    }
}

#pragma mark - Chaining methods

- (InspurOSSTask *)continueWithExecutor:(InspurOSSExecutor *)executor withBlock:(OSSContinuationBlock)block {
    return [self continueWithExecutor:executor block:block cancellationToken:nil];
}

- (InspurOSSTask *)continueWithExecutor:(InspurOSSExecutor *)executor
                           block:(OSSContinuationBlock)block
               cancellationToken:(nullable InspurOSSCancellationToken *)cancellationToken {
    InspurOSSTaskCompletionSource *tcs = [InspurOSSTaskCompletionSource taskCompletionSource];

    // Capture all of the state that needs to used when the continuation is complete.
    dispatch_block_t executionBlock = ^{
        if (cancellationToken.cancellationRequested) {
            [tcs cancel];
            return;
        }

        id result = nil;
        @try {
            result = block(self);
        } @catch (NSException *exception) {
            NSError *error = [NSError errorWithDomain:InspurOSSClientErrorDomain
                                                 code:InspurOSSClientErrorCodeExcpetionCatched
                                             userInfo:@{InspurOSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", exception]}];
            tcs.error = error;
            OSSLogError(@"exception name: %@",[exception name]);
            OSSLogError(@"exception reason: %@",[exception reason]);
            return;
        }

        if ([result isKindOfClass:[InspurOSSTask class]]) {

            id (^setupWithTask) (InspurOSSTask *) = ^id(InspurOSSTask *task) {
                if (cancellationToken.cancellationRequested || task.cancelled) {
                    [tcs cancel];
                } else if (task.exception) {
                    NSError *error = [NSError errorWithDomain:InspurOSSClientErrorDomain
                                                         code:InspurOSSClientErrorCodeExcpetionCatched
                                                     userInfo:@{InspurOSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", task.exception]}];
                    tcs.error = error;
                } else if (task.error) {
                    tcs.error = task.error;
                } else {
                    tcs.result = task.result;
                }
                return nil;
            };

            InspurOSSTask *resultTask = (InspurOSSTask *)result;

            if (resultTask.completed) {
                setupWithTask(resultTask);
            } else {
                [resultTask continueWithBlock:setupWithTask];
            }

        } else {
            tcs.result = result;
        }
    };

    BOOL completed;
    @synchronized(self.lock) {
        completed = self.completed;
        if (!completed) {
            [self.callbacks addObject:[^{
                [executor execute:executionBlock];
            } copy]];
        }
    }
    if (completed) {
        [executor execute:executionBlock];
    }

    return tcs.task;
}

- (InspurOSSTask *)continueWithBlock:(OSSContinuationBlock)block {
    return [self continueWithExecutor:[InspurOSSExecutor defaultExecutor] block:block cancellationToken:nil];
}

- (InspurOSSTask *)continueWithBlock:(OSSContinuationBlock)block cancellationToken:(nullable InspurOSSCancellationToken *)cancellationToken {
    return [self continueWithExecutor:[InspurOSSExecutor defaultExecutor] block:block cancellationToken:cancellationToken];
}

- (InspurOSSTask *)continueWithExecutor:(InspurOSSExecutor *)executor
                withSuccessBlock:(OSSContinuationBlock)block {
    return [self continueWithExecutor:executor successBlock:block cancellationToken:nil];
}

- (InspurOSSTask *)continueWithExecutor:(InspurOSSExecutor *)executor
                    successBlock:(OSSContinuationBlock)block
               cancellationToken:(nullable InspurOSSCancellationToken *)cancellationToken {
    if (cancellationToken.cancellationRequested) {
        return [InspurOSSTask cancelledTask];
    }

    return [self continueWithExecutor:executor block:^id(InspurOSSTask *task) {
        if (task.faulted || task.cancelled) {
            return task;
        } else {
            return block(task);
        }
    } cancellationToken:cancellationToken];
}

- (InspurOSSTask *)continueWithSuccessBlock:(OSSContinuationBlock)block {
    return [self continueWithExecutor:[InspurOSSExecutor defaultExecutor] successBlock:block cancellationToken:nil];
}

- (InspurOSSTask *)continueWithSuccessBlock:(OSSContinuationBlock)block cancellationToken:(nullable InspurOSSCancellationToken *)cancellationToken {
    return [self continueWithExecutor:[InspurOSSExecutor defaultExecutor] successBlock:block cancellationToken:cancellationToken];
}

#pragma mark - Syncing Task (Avoid it)

- (void)warnOperationOnMainThread {
    ossWarnBlockingOperationOnMainThread();
}

- (void)waitUntilFinished {
    if ([NSThread isMainThread]) {
        [self warnOperationOnMainThread];
    }

    @synchronized(self.lock) {
        if (self.completed) {
            return;
        }
        [self.condition lock];
    }
    while (!self.completed) {
        [self.condition wait];
    }
    [self.condition unlock];
}

#pragma mark - NSObject

- (NSString *)description {
    // Acquire the data from the locked properties
    BOOL completed;
    BOOL cancelled;
    BOOL faulted;
    NSString *resultDescription = nil;

    @synchronized(self.lock) {
        completed = self.completed;
        cancelled = self.cancelled;
        faulted = self.faulted;
        resultDescription = completed ? [NSString stringWithFormat:@" result = %@", self.result] : @"";
    }

    // Description string includes status information and, if available, the
    // result since in some ways this is what a promise actually "is".
    return [NSString stringWithFormat:@"<%@: %p; completed = %@; cancelled = %@; faulted = %@;%@>",
            NSStringFromClass([self class]),
            self,
            completed ? @"YES" : @"NO",
            cancelled ? @"YES" : @"NO",
            faulted ? @"YES" : @"NO",
            resultDescription];
}

@end

@implementation InspurOSSTask(InspurOSS)

- (BOOL)isSuccessful {
    if (self.cancelled || self.faulted) {
        return false;
    }
    return true;
}

- (NSError *)toError {
    if (self.cancelled) {
        return [NSError errorWithDomain:InspurOSSClientErrorDomain
                                   code:InspurOSSClientErrorCodeTaskCancelled
                               userInfo:@{InspurOSSErrorMessageTOKEN: @"This task is cancelled"}];
    } else if (self.error) {
        return self.error;
    } else if (self.exception) {
        return [NSError errorWithDomain:InspurOSSClientErrorDomain
                                   code:InspurOSSClientErrorCodeExcpetionCatched
                               userInfo:@{InspurOSSErrorMessageTOKEN: [NSString stringWithFormat:@"Catch exception - %@", self.exception]}];
    }
    return nil;
}

- (InspurOSSTask *)completed:(OSSCompleteBlock)block {
    return [self continueWithBlock:^id _Nullable(InspurOSSTask * _Nonnull task) {
        if ([task isSuccessful]) {
            block(YES, nil, task.result);
        } else {
            block(NO, [task toError], nil);
        }
        return nil;
    }];
}

@end

NS_ASSUME_NONNULL_END
