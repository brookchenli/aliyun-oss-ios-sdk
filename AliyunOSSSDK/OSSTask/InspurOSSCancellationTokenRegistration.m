/*
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "InspurOSSCancellationTokenRegistration.h"

#import "InspurOSSCancellationToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface InspurOSSCancellationTokenRegistration ()

@property (nonatomic, weak) InspurOSSCancellationToken *token;
@property (nullable, nonatomic, strong) OSSCancellationBlock cancellationObserverBlock;
@property (nonatomic, strong) NSObject *lock;
@property (nonatomic) BOOL disposed;

@end

@interface InspurOSSCancellationToken (OSSCancellationTokenRegistration)

- (void)unregisterRegistration:(InspurOSSCancellationTokenRegistration *)registration;

@end

@implementation InspurOSSCancellationTokenRegistration

+ (instancetype)registrationWithToken:(InspurOSSCancellationToken *)token delegate:(OSSCancellationBlock)delegate {
    InspurOSSCancellationTokenRegistration *registration = [InspurOSSCancellationTokenRegistration new];
    registration.token = token;
    registration.cancellationObserverBlock = delegate;
    return registration;
}

- (instancetype)init {
    self = [super init];
    if (!self) return self;

    _lock = [NSObject new];
    
    return self;
}

- (void)dispose {
    @synchronized(self.lock) {
        if (self.disposed) {
            return;
        }
        self.disposed = YES;
    }

    InspurOSSCancellationToken *token = self.token;
    if (token != nil) {
        [token unregisterRegistration:self];
        self.token = nil;
    }
    self.cancellationObserverBlock = nil;
}

- (void)notifyDelegate {
    @synchronized(self.lock) {
        [self throwIfDisposed];
        self.cancellationObserverBlock();
    }
}

- (void)throwIfDisposed {
    NSAssert(!self.disposed, @"Object already disposed");
}

@end

NS_ASSUME_NONNULL_END
