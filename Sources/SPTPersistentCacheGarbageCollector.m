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
#import "SPTPersistentCacheGarbageCollector.h"
#import "SPTPersistentCacheDebugUtilities.h"
#import "SPTPersistentCache+Private.h"

static BOOL SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue(void);

static const NSTimeInterval SPTPersistentCacheGarbageCollectorSchedulerTimerTolerance = 300;

@interface SPTPersistentCacheGarbageCollector ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) SPTPersistentCacheOptions *options;
@end


@implementation SPTPersistentCacheGarbageCollector

#pragma mark - Initializer

- (instancetype)initWithCache:(SPTPersistentCache *)cache
                      options:(SPTPersistentCacheOptions *)options
                        queue:(NSOperationQueue *)queue
{
    self = [super init];
    if (self) {
        _options = [options copy];
        _cache = cache;
        _queue = queue;
    }
    return self;
}

- (void)dealloc
{
    /**
     *  Intentionally Left Blank
     *
     *  Our timer should be invalidated by unscheduling this garbage collector
     *  on the -dealloc method of the object owning the reference.
     */
}

#pragma mark -

- (void)enqueueGarbageCollection:(NSTimer *)timer
{
    __weak __typeof(self) const weakSelf = self;
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        // We want to shadow `self` in this case.
        _Pragma("clang diagnostic push");
        _Pragma("clang diagnostic ignored \"-Wshadow\"");
        __typeof(weakSelf) const self = weakSelf;
        _Pragma("clang diagnostic pop");

        SPTPersistentCache * const cache = self.cache;

        [cache runRegularGC];
        [cache pruneBySize];
    }];
    operation.queuePriority = self.options.garbageCollectionPriority;
    operation.qualityOfService = self.options.garbageCollectionQualityOfService;
    [self.queue addOperation:operation];
}

- (void)schedule
{
    if (!SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self schedule];
        });
        
        return;
    }
                       
    SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"runGarbageCollector:%@", self.timer],
                                        self.options.debugOutput);
    
    if (self.isGarbageCollectionScheduled) {
        return;
    }

    self.timer = [NSTimer timerWithTimeInterval:self.options.garbageCollectionInterval
                                         target:self
                                       selector:@selector(enqueueGarbageCollection:)
                                       userInfo:nil
                                        repeats:YES];
    
    self.timer.tolerance = SPTPersistentCacheGarbageCollectorSchedulerTimerTolerance;
    
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)unschedule
{
    if (!SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unschedule];
        });
        
        return;
    }
    
    SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"stopGarbageCollector:%@", self.timer],
                                        self.options.debugOutput);
    
    [self.timer invalidate];
    
    self.timer = nil;
}

- (BOOL)isGarbageCollectionScheduled
{
    return (self.timer != nil);
}
@end

static BOOL SPTPersistentCacheGarbageCollectorSchedulerIsInMainQueue(void)
{
    NSString *currentQueueLabelString = [NSString stringWithUTF8String:dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)];
    NSString *mainQueueLabelString = [NSString stringWithUTF8String:dispatch_queue_get_label(dispatch_get_main_queue())];
    return [currentQueueLabelString isEqualToString:mainQueueLabelString];
}

