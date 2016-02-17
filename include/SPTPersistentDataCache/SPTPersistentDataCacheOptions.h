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

extern const NSUInteger SPTPersistentDataCacheMinimumGCIntervalLimit;
extern const NSUInteger SPTPersistentDataCacheMinimumExpirationLimit;

/**
 * Type off callback for load/store calls
 */
typedef void (^SPTDataCacheResponseCallback)(SPTPersistentCacheResponse *response);

/**
 * Type of callback that is used to give caller a chance to choose which key to open if any.
 */
typedef NSString *(^SPTDataCacheChooseKeyCallback)(NSArray *keys);

/**
 * Type of callback that is used to provide current time for that cache. Mainly for testing.
 */
typedef NSTimeInterval (^SPTDataCacheCurrentTimeSecCallback)(void);

/**
 * Type of callback that can be used ot get debug messages from cache.
 */
typedef void (^SPTDataCacheDebugCallback)(NSString *string);

/**
 * @brief SPTPersistentDataCacheOptions
 *
 * @discussion Class defines cache creation options
 */
@interface SPTPersistentDataCacheOptions : NSObject

/**
 *  Returns a new instance of the class setup with specific values.
 *
 *  @param cachePath Path in the system file for the cache. May be nil.
 *  @param cacheIdentifier An identifier for the cache. May be nil.
 *  @param currentTimeBlock A block that should return the current time. May be nil
 *  @param defaultExpirationInterval Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 *  @param garbageCollectorInterval It is guaranteed that once started GC runs with this interval.
 *  @param debugCallback A callback used for debugging purposes.
 */
- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
              currentTimeCallback:(SPTDataCacheCurrentTimeSecCallback)currentTimeBlock
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(SPTDataCacheDebugCallback)debugCallback;

/**
 *  Returns a new instance of the class setup with specific values.
 *
 *  @param cachePath Path in the system file for the cache. May be nil.
 *  @param cacheIdentifier An identifier for the cache. May be nil.
 *  @param currentTimeBlock A block that should return the current time. May be nil
 *  @param debugCallback A callback used for debugging purposes.
 */
- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
              currentTimeCallback:(SPTDataCacheCurrentTimeSecCallback)currentTimeBlock
                            debug:(SPTDataCacheDebugCallback)debugCallback;

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
 * Its recommended to use SPTPersistentDataCacheDefaultGCIntervalSec constant if not sure.
 * Internal guarding is applied to this value.
 */
@property (nonatomic, assign, readonly) NSUInteger gcIntervalSec;
/**
 * Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 * Its recommended to use SPTPersistentDataCacheDefaultExpirationTimeSec if not sure.
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
@property (nonatomic, copy, readonly) SPTDataCacheDebugCallback debugOutput;
/**
 * Callback to provide current time in seconds. This time shouldn't depend on time zone etc.
 * So its better to use fixed time scale i.e. UNIX. If not specified then current unix time is used.
 */
@property (nonatomic, copy, readonly) SPTDataCacheCurrentTimeSecCallback currentTimeSec;
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

@end
