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
 *  Type of callback that can be used to get debug messages from cache.
 *  @param message The debug message.
 */
typedef void (^SPTPersistentCacheDebugCallback)(NSString *message);

/**
 * The different states that provide recording of timing.
 */
typedef NS_ENUM(NSUInteger, SPTPersistentCacheDebugTimingType) {
    SPTPersistentCacheDebugTimingTypeQueued,
    SPTPersistentCacheDebugTimingTypeStarting,
    SPTPersistentCacheDebugTimingTypeFinished
};

/**
 * The operation types that support recording of timing.
 */
typedef NS_ENUM(NSUInteger, SPTPersistentCacheDebugMethodType) {
    SPTPersistentCacheDebugMethodTypeStore,
    SPTPersistentCacheDebugMethodTypeLock,
    SPTPersistentCacheDebugMethodTypeUnlock,
    SPTPersistentCacheDebugMethodTypeRemove,
    SPTPersistentCacheDebugMethodTypeRead
};

/**
 *  Type of callback that can be used to get information on the execution time of various methods.
 *  @param key The cache key for the item
 *  @param method Which cache method this callback is refering to
 *  @param type Which state at which this timing was recorded
 *  @param machTime The absolute mach time
 */
typedef void (^SPTPersistentCacheDebugTimingCallback)(NSString *key, SPTPersistentCacheDebugMethodType method, SPTPersistentCacheDebugTimingType type, uint64_t machTime);


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

#pragma mark Priority Options

/**
 * Max concurrent operations that the cache can perform. Defaults to NSOperationQueueDefaultMaxConcurrentOperationCount.
 */
@property (nonatomic) NSInteger maxConcurrentOperations;
/**
 * The queue priority for writes. Will also be used for touch and lock. Defaults to NSOperationQueuePriorityNormal.
 */
@property (nonatomic) NSOperationQueuePriority writePriority;
/**
 * The queue priority for reads. Defaults to NSOperationQueuePriorityNormal.
 */
@property (nonatomic) NSOperationQueuePriority readPriority;
/**
 * The queue priority for deletes. Will also be used for unlock, prune, and wipe. Defaults to NSOperationQueuePriorityNormal.
 */
@property (nonatomic) NSOperationQueuePriority deletePriority;

/**
 * The queue quality of service for writes. Will also be used for touch and lock. Defaults to NSQualityOfServiceDefault.
 */
@property (nonatomic) NSQualityOfService writeQualityOfService;
/**
 * The queue quality of service for reads. Defaults to NSQualityOfServiceDefault.
 */
@property (nonatomic) NSQualityOfService readQualityOfService;
/**
 * The queue quality of service for deletes. Will also be used for unlock, prune, and wipe. Defaults to NSQualityOfServiceDefault.
 */
@property (nonatomic) NSQualityOfService deleteQualityOfService;

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
/**
 * The queue priority for garbage collection. Defaults to NSOperationQueuePriorityLow.
 */
@property (nonatomic) NSOperationQueuePriority garbageCollectionPriority;
/**
 * The queue quality of service for garbage collection. Defaults to NSQualityOfServiceBackground.
 */
@property (nonatomic) NSQualityOfService garbageCollectionQualityOfService;

#pragma mark Debugging

/**
 *  Callback used to supply debug/internal information usually about errors.
 *  @warning The block might be executed on any thread or queue. Make sure your code is thread-safe or dispatches out
 *  to a thread safe for you.
 */
@property (nonatomic, copy, nullable) SPTPersistentCacheDebugCallback debugOutput;

/**
 *  Callback used to supply debug/internal information on queue and execution times for caching operations.
 *  @warning The block might be executed on any thread or queue. Make sure your code is thread-safe or dispatches out
 *  to a thread safe for you.
 */
@property (nonatomic, copy, nullable) SPTPersistentCacheDebugTimingCallback timingCallback;

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
 *  @deprecated
 *  @see garbageCollectionInterval
 */
@property (nonatomic, assign, readonly) NSUInteger gcIntervalSec DEPRECATED_MSG_ATTRIBUTE("Use the garbageCollectionInterval property instead");
/**
 *  Compatibility alias for `defaultExpirationPeriod`.
 *  @deprecated
 *  @see defaultExpirationPeriod
 */
@property (nonatomic, assign, readonly) NSUInteger defaultExpirationPeriodSec DEPRECATED_MSG_ATTRIBUTE("Use the defaultExpirationPeriod property instead");

@end

NS_ASSUME_NONNULL_END
