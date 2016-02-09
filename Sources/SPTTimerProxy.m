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
#import "SPTTimerProxy.h"

#import "SPTPersistentDataCache+Private.h"

@implementation SPTTimerProxy

- (instancetype)initWithDataCache:(SPTPersistentDataCache *)dataCache
                            queue:(dispatch_queue_t)queue
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _dataCache = dataCache;
    _queue = queue;
    
    return self;
}

- (void)enqueueGC:(NSTimer *)timer
{
    __weak __typeof(self) const weakSelf = self;
    dispatch_barrier_async(self.queue, ^{
        // We want to shadow `self` in this case.
        _Pragma("clang diagnostic push");
        _Pragma("clang diagnostic ignored \"-Wshadow\"");
        __typeof(weakSelf) const self = weakSelf;
        _Pragma("clang diagnostic pop");

        SPTPersistentDataCache * const dataCache = self.dataCache;

        [dataCache runRegularGC];
        [dataCache pruneBySize];
    });
}

@end
