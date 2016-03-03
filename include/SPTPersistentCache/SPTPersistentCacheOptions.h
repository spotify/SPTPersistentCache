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
#import <Foundation/Foundation.h>

@class SPTPersistentCacheResponse;

NS_ASSUME_NONNULL_BEGIN

/**
 * Type off callback for load/store calls
 */
typedef void (^SPTPersistentCacheResponseCallback)(SPTPersistentCacheResponse *response);
/**
 * Type of callback that is used to provide current time for that cache. Mainly for testing.
 */
typedef NSTimeInterval (^SPTPersistentCacheCurrentTimeSecCallback)(void);
/**
 * Type of callback that can be used ot get debug messages from cache.
 */
typedef void (^SPTPersistentCacheDebugCallback)(NSString *string);

/**
 * Default garbage collection interval. Some sane implementation defined value you should not care about.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheDefaultGCIntervalSec;
/**
 * Default exparation interval for all cache items. Particular record's TTL takes precedence over this value.
 * Items stored without (tt=0) TTL considered as expired if following is true: current_time - update_time > ExpInterval.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheDefaultExpirationTimeSec;
/**
 * The minimum amount of time between garbage collection intervals.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheMinimumGCIntervalLimit;
/**
 * The minimum TTL of cache records.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheMinimumExpirationLimit;

/**
 * @brief SPTPersistentCacheOptions
 * @discussion Class defines cache creation options
 */
@interface SPTPersistentCacheOptions : NSObject

/**
 *  A unique identifier for a work queue based on this instance of options.
 */
@property (nonatomic, readonly) NSString *identifierForQueue;
/**
 * Path to a folder in which to store that files. If folder doesn't exist it will be created.
 * This mustn't be nil.
 */
@property (nonatomic, copy, readonly) NSString *cachePath;
/**
 * Garbage collection interval. It is guaranteed that once started GC runs with this interval.
 * Its recommended to use SPTPersistentCacheDefaultGCIntervalSec constant if not sure.
 * Internal guarding is applied to this value.
 */
@property (nonatomic, assign, readonly) NSUInteger gcIntervalSec;
/**
 * Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 * Its recommended to use SPTPersistentCacheDefaultExpirationTimeSec if not sure.
 * Internal guarding is applied.
 */
@property (nonatomic, assign, readonly) NSUInteger defaultExpirationPeriodSec;
/**
 * Size in bytes to which cache should adjust itself when performing GC. 0 - no size constraint (default)
 */
@property (nonatomic, assign) NSUInteger sizeConstraintBytes;
/**
 * Callback used to supply debug/internal information usually about errors.
 */
@property (nonatomic, copy, readonly) SPTPersistentCacheDebugCallback debugOutput;

/**
 * Any string that identifies the cache and used in naming of internal queue.
 * It is important to put sane string to be able identify queue during debug and in crash dumps.
 * Default is "persistent.cache".
 */
@property (nonatomic, copy, readonly) NSString *cacheIdentifier;
/**
 * Use 2 first letter of key for folder names to separate recodrs into. Default: YES
 */
@property (nonatomic, assign) BOOL folderSeparationEnabled;

/**
 * Returns a new instance of the class setup with specific values.
 * @param cachePath Path in the system file for the cache. May be nil.
 * @param cacheIdentifier An identifier for the cache. May be nil.
 * @param defaultExpirationInterval Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 * @param garbageCollectorInterval It is guaranteed that once started GC runs with this interval.
 * @param debugCallback A callback used for debugging purposes.
 */
- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(SPTPersistentCacheDebugCallback)debugCallback NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
