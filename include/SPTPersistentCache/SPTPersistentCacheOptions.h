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

#pragma mark - Callback Types

/**
 *  Type of callback that can be used ot get debug messages from cache.
 *  @param message The debug message.
 */
typedef void (^SPTPersistentCacheDebugCallback)(NSString *message);


#pragma mark - Garbage Collection Constants

/**
 *  Default garbage collection interval. Some sane implementation defined value you should not care about.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheDefaultGCIntervalSec;
/**
 *  The minimum amount of time between garbage collection intervals.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheMinimumGCIntervalLimit;

/**
 *  Default exparation interval for all cache items. Particular record's TTL takes precedence over this value.
 *
 *  @discussion Items stored without a TTL value (i.e. ttl = 0) will be considered to have expired if the following
 *  expressing is true: `current_time - update_time > ExpInterval`.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheDefaultExpirationTimeSec;
/**
 *  The minimum TTL of cache records.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentCacheMinimumExpirationLimit;


#pragma mark - SPTPersistentCacheOptions Interface

/**
 *  Class which defines options used by a cache instance.
 */
@interface SPTPersistentCacheOptions : NSObject <NSCopying>

#pragma mark Queue Management Options

/**
 *  A unique identifier for a work queue based on this instance of options.
 *  @note The value is derived from the `cacheIdentifier`.
 */
@property (nonatomic, copy, readonly) NSString *identifierForQueue;

#pragma mark Cache Options

/**
 *  Any string that identifies the cache and used in naming of internal queue.
 *  @discussion It is important to use a stable cache identifier to be able identify the queue during debug and in
 *  crash dumps.
 *  @note Defaults to `persistent.cache`.
 */
@property (nonatomic, copy) NSString *cacheIdentifier;
/**
 *  Path to a folder in which to store that files. If folder doesn't exist it will be created.
 *  @note Defaults to a sub-directory in the current user’s temporary directory.
 */
@property (nonatomic, copy) NSString *cachePath;

/**
 *  Whether directory separation of cache records should be used.
 *  @discussion When enabled cached records are separate into direcectories based on the first two (2) characters in
 *  the key.
 *  @note Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL useDirectorySeparation;

#pragma mark Garbage Collection Options

/**
 *  Garbage collection (GC) interval in seconds. It is guaranteed that once started the GC runs with this interval.
 *  @discussion Its recommended to use `SPTPersistentCacheDefaultGCIntervalSec` constant if unsure. The
 *  implementation will make sure the value isn’t below the minimum (`SPTPersistentCacheMinimumGCIntervalLimit`).
 *  @note Defaults to `SPTPersistentCacheDefaultGCIntervalSec`.
 */
@property (nonatomic, assign) NSUInteger garbageCollectionInterval;
/**
 *  Default time perioid, in seconds, which needs to pass since last access for a file to be conisdered for pruning
 *  during the next garbage collection run.
 *  @discussion It’s recommended to use `SPTPersistentCacheDefaultExpirationTimeSec` if unsure. The
 *  implementation will make sure the value isn’t below the minimum (`SPTPersistentCacheMinimumExpirationLimit`).
 *  @note Defaults to `SPTPersistentCacheDefaultExpirationTimeSec`.
 */
@property (nonatomic, assign) NSUInteger defaultExpirationPeriod;
/**
 *  Size in bytes to which cache should adjust itself when performing GC. `0` - no size constraint.
 *  @note Defaults to `0` (unbounded).
 */
@property (nonatomic, assign) NSUInteger sizeConstraintBytes;

#pragma mark Debugging

/**
 *  Callback used to supply debug/internal information usually about errors.
 *  @warning The block might be executed on any thread or queue. Make sure your code is thread-safe or dispatches out
 *  to a thread safe for you.
 */
@property (nonatomic, copy, nullable) SPTPersistentCacheDebugCallback debugOutput;

@end


#pragma mark - Deprecation Category

/**
 * Methods on `SPTPersistentCacheOptions` that are deprecated and will be removed in a later release.
 */
@interface SPTPersistentCacheOptions (Deprectated)

/**
 *  Returns a new instance of the class setup with specific values.
 *  @deprecated
 *  @param cachePath Path in the system file for the cache.
 *  @param cacheIdentifier An identifier for the cache.
 *  @param defaultExpirationInterval Default time which have to pass since last file access so file could be candidate
 *  for pruning on next GC.
 *  @param garbageCollectorInterval It is guaranteed that once started GC runs with this interval.
 *  @param debugCallback A callback used for debugging purposes. May be nil.
 */
- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(nullable SPTPersistentCacheDebugCallback)debugCallback DEPRECATED_MSG_ATTRIBUTE("Configure the option instance’s properties instead.");

/**
 *  Compatibility alias for `useDirectorySeparation`.
 *  @see useDirectorySeparation
 */
@property (nonatomic, assign) BOOL folderSeparationEnabled DEPRECATED_MSG_ATTRIBUTE("Use the useDirectorySeparation property instead");
/**
 *  Compatibility alias for `garbageCollectionInterval`.
 *  @see garbageCollectionInterval
 */
@property (nonatomic, assign) NSUInteger gcIntervalSec DEPRECATED_MSG_ATTRIBUTE("Use the garbageCollectionInterval property instead");
/**
 *  Compatibility alias for `defaultExpirationPeriod`.
 *  @see defaultExpirationPeriod
 */
@property (nonatomic, assign) NSUInteger defaultExpirationPeriodSec DEPRECATED_MSG_ATTRIBUTE("Use the defaultExpirationPeriod property instead");

@end

NS_ASSUME_NONNULL_END
