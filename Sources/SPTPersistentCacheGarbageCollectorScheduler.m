/*
 * Copyright (c) 2016 Spotify AB.
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
#import "SPTPersistentCacheGarbageCollectorScheduler.h"
#import "SPTPersistentCacheTypeUtilities.h"
#import "SPTPersistentCache+Private.h"

static BOOL SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue(void);

static const NSTimeInterval SPTPersistentCacheGarbageCollectorSchedulerTimerTolerance = 300;

@interface SPTPersistentCacheGarbageCollectorScheduler ()
@property (nonatomic, strong) SPTPersistentCacheDebugCallback debugOutput;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) SPTPersistentCacheOptions *options;
@end


@implementation SPTPersistentCacheGarbageCollectorScheduler

#pragma mark - Initializer

- (instancetype)initWithDataCache:(SPTPersistentCache *)dataCache
                          options:(SPTPersistentCacheOptions *)options
                            queue:(dispatch_queue_t)queue
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _options = options;
    _dataCache = dataCache;
    _queue = queue;
    _debugOutput = options.debugOutput;
    
    return self;
}

- (void)dealloc
{
    NSTimer *timer = _timer;
    
    void (^invalidateTimerBlock)(void) = ^{
        [timer invalidate];
    };
    
    if (!SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue()) {
        dispatch_async(dispatch_get_main_queue(), invalidateTimerBlock);
    } else {
        invalidateTimerBlock();
    }
}

#pragma mark -

- (void)enqueueGarbageCollection:(NSTimer *)timer
{
    __weak __typeof(self) const weakSelf = self;
    dispatch_barrier_async(self.queue, ^{
        // We want to shadow `self` in this case.
        _Pragma("clang diagnostic push");
        _Pragma("clang diagnostic ignored \"-Wshadow\"");
        __typeof(weakSelf) const self = weakSelf;
        _Pragma("clang diagnostic pop");

        SPTPersistentCache * const dataCache = self.dataCache;

        [dataCache runRegularGC];
        [dataCache pruneBySize];
    });
}

- (void)scheduleGarbageCollection
{
    if (!SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scheduleGarbageCollection];
        });
    }
                       
    SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"runGarbageCollector:%@", self.timer],
                                        self.debugOutput);
    
    if (self.isGarbageCollectionScheduled) {
        return;
    }

    self.timer = [NSTimer timerWithTimeInterval:self.options.gcIntervalSec
                                         target:self
                                       selector:@selector(enqueueGarbageCollection:)
                                       userInfo:nil
                                        repeats:YES];
    
    self.timer.tolerance = SPTPersistentCacheGarbageCollectorSchedulerTimerTolerance;
    
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)unscheduleGarbageCollection
{
    if (!SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unscheduleGarbageCollection];
        });
    }
    
    SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"stopGarbageCollector:%@", self.timer],
                                        self.debugOutput);
    
    [self.timer invalidate];
    
    self.timer = nil;
}

- (BOOL)isGarbageCollectionScheduled
{
    return (self.timer != nil);
}
@end

static BOOL SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue(void) {
    return (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue()));
}

