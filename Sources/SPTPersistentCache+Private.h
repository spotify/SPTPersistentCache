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

#import <SPTPersistentCache/SPTPersistentCache.h>

@class SPTPersistentCacheFileManager;
@class SPTPersistentCacheGarbageCollector;
@class SPTPersistentCachePosixWrapper;

void SPTPersistentCacheSafeDispatch(_Nullable dispatch_queue_t queue, _Nonnull dispatch_block_t block);

NS_ASSUME_NONNULL_BEGIN

/// Private interface exposed for testability.
@interface SPTPersistentCache ()

@property (nonatomic, copy, readonly) SPTPersistentCacheOptions *options;

@property (nonatomic, copy, readonly, nullable) SPTPersistentCacheDebugCallback debugOutput;

/// Serial queue used to run all internal stuff
@property (nonatomic, strong, readonly) NSOperationQueue *workQueue;

@property (nonatomic, strong, readonly) NSFileManager *fileManager;
@property (nonatomic, strong, readonly) SPTPersistentCacheFileManager *dataCacheFileManager;

@property (nonatomic, strong, readonly) SPTPersistentCacheGarbageCollector *garbageCollector;

@property (nonatomic, assign, readonly) NSTimeInterval currentDateTimeInterval;
@property (nonatomic, strong, readonly) SPTPersistentCachePosixWrapper *posixWrapper;

- (void)runRegularGC;
- (BOOL)pruneBySize;

/**
 * forceExpire = YES treat all unlocked files like they expired
 * forceLocked = YES ignore lock status
 */
- (void)collectGarbageForceExpire:(BOOL)forceExpire forceLocked:(BOOL)forceLocked;

- (void)dispatchEmptyResponseWithResult:(SPTPersistentCacheResponseCode)result
                               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                                onQueue:(dispatch_queue_t _Nullable)queue;

- (void)dispatchError:(NSError *)error
               result:(SPTPersistentCacheResponseCode)result
             callback:(SPTPersistentCacheResponseCallback _Nullable)callback
              onQueue:(dispatch_queue_t _Nullable)queue;

- (void)doWork:(void (^)(void))block priority:(NSOperationQueuePriority)priority qos:(NSQualityOfService)qos;

- (void)logTimingForKey:(NSString *)key method:(SPTPersistentCacheDebugMethodType)method type:(SPTPersistentCacheDebugTimingType)type;

@end

NS_ASSUME_NONNULL_END
