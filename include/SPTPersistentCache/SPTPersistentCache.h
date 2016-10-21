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

#ifndef SPT_BUILDING_FRAMEWORK
#define SPT_BUILDING_FRAMEWORK 0
#endif
#if SPT_BUILDING_FRAMEWORK
//! Project version number for SPTDataLoader.
FOUNDATION_EXPORT double SPTDataLoaderVersionNumber;

//! Project version string for SPTDataLoader.
FOUNDATION_EXPORT const unsigned char SPTDataLoaderVersionString[];
#endif // SPT_BUILDING_FRAMEWORK

#import <SPTPersistentCache/SPTPersistentCacheOptions.h>
#import <SPTPersistentCache/SPTPersistentCacheHeader.h>
#import <SPTPersistentCache/SPTPersistentCacheRecord.h>
#import <SPTPersistentCache/SPTPersistentCacheResponse.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Persistent Cache Errors

/**
 * The SPTPersistentCacheLoadingError enum defines constants that identify NSError's in SPTPersistentCacheErrorDomain.
 */
typedef NS_ENUM(NSInteger, SPTPersistentCacheLoadingError) {
    /**
     * Magic number in record header is not as expected which means file is not readable by this cache.
     */
    SPTPersistentCacheLoadingErrorMagicMismatch = 100,
    /**
     * Alignment of pointer which casted to header is not compatible with alignment of first header field.
     */
    SPTPersistentCacheLoadingErrorHeaderAlignmentMismatch,
    /**
     * Size of header is not as expected. This is possibly because of a version change.
     */
    SPTPersistentCacheLoadingErrorWrongHeaderSize,
    /**
     * Payload size in header is not the same as stored in cache record.
     */
    SPTPersistentCacheLoadingErrorWrongPayloadSize,
    /**
     * CRC calculated for reader and contained in header are different.
     */
    SPTPersistentCacheLoadingErrorInvalidHeaderCRC,
    /**
     * Binary data size read as header is less then current header size which means we can't proceed further with this
     * file.
     */
    SPTPersistentCacheLoadingErrorNotEnoughDataToGetHeader,
    /**
     * Record is opened as stream and busy right now.
     */
    SPTPersistentCacheLoadingErrorRecordIsStreamAndBusy,
    /**
     * Something bad has happened that shouldn't.
     */
    SPTPersistentCacheLoadingErrorInternalInconsistency
};

/**
 * The error domain for errors produced by the persistent cache.
 */
FOUNDATION_EXPORT NSString *const SPTPersistentCacheErrorDomain;


#pragma mark - Callback Types

/**
 *  Type off callback for load/store calls
 */
typedef void (^SPTPersistentCacheResponseCallback)(SPTPersistentCacheResponse *response);
/**
 *  Type of callback that is used to give caller a chance to choose which key to open if any.
 */
typedef NSString * _Nonnull(^SPTPersistentCacheChooseKeyCallback)(NSArray<NSString *> *keys);


#pragma mark - SPTPersistentCache Interface

/**
 * @brief SPTPersistentCache
 * @discussion Class defines persistent cache that manage files on disk. This class is threadsafe.
 * Except methods for scheduling/unscheduling GC which must be called on main thread.
 * It is obligatory that one instanse of that class manage one path branch on disk. In other case behavior is undefined.
 * Cache uses own queue for all operations.
 * Cache GC procedure evicts all not locked files for which current_gc_time - access_time > defaultExpirationPeriodSec.
 * Cache GC procedure evicts all not locked files for which current_gc_time - creation_time > fileTTL.
 * Files that are locked not evicted by GC procedure and returned by the cache even if they already expired. 
 * Once unlocked, expired files would be collected by following GC
 * Req.#1.3 record opened as stream couldn't be altered by usual cache methods and doesn't take part in locked size
 * calculation.
 */
@interface SPTPersistentCache : NSObject

/**
 * Designated initialiser.
 * @param options The options to use for the cache parameters.
 */
- (instancetype)initWithOptions:(SPTPersistentCacheOptions *)options NS_DESIGNATED_INITIALIZER;

/**
 * @discussion Load data from cache for specified key. 
 *             Req.#1.2. Expired records treated as not found on load. (And open stream)
 * @param key Key used to access the data. It MUST MUST MUST be unique for different data. 
 *            It could be used as a part of file name. It up to a cache user to define algorithm to form a key.
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback. Mustn't be nil.
 */
- (BOOL)loadDataForKey:(NSString *)key
          withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
               onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Load data for key which has specified prefix. chooseKeyCallback is called with array of matching keys.
 *             Req.#1.1a. To load the data user needs to pick one key and return it.
 *             Req.#1.1b. If non of those are match then return nil and cache will return not found error.
 *             chooseKeyCallback is called on any thread and caller should not do any heavy job in it.
 *             Req.#1.2. Expired records treated as not found on load. (And open stream)
 * @param prefix Prefix which key should have to be candidate for loading.
 * @param chooseKeyCallback callback to call to define which key to use to load the data. 
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback. Mustn't be nil.
 */
- (BOOL)loadDataForKeysWithPrefix:(NSString *)prefix
                chooseKeyCallback:(SPTPersistentCacheChooseKeyCallback _Nullable)chooseKeyCallback
                     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
                          onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Req.#1.0. If data already exist for that key it will be overwritten otherwise created.
 * Its access time will be updated. RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > defaultExpirationPeriodSec.
 * @param data Data to store. Mustn't be nil
 * @param key Key to associate the data with.
 * @param locked If YES then data refCount is set to 1. If NO then set to 0.
 * @param callback Callback to call once data is loaded. Could be nil.
 * @param queue Queue on which to run the callback. Couldn't be nil if callback is specified.
 */
- (BOOL)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
          onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Req.#1.0. If data already exist for that key it will be overwritten otherwise created.
 * Its access time will be apdated. Its TTL will be updated if applicable.
 * RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > TTL.
 * @param data Data to store. Mustn't be nil.
 * @param key Key to associate the data with.
 * @param ttl TTL value for a file. 0 is equivalent to storeData:forKey: behavior.
 * @param locked If YES then data refCount is set to 1. If NO then set to 0.
 * @param callback Callback to call once data is loaded. Could be nil.
 * @param queue Queue on which to run the callback. Couldn't be nil if callback is specified.
 */
- (BOOL)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
          onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Update last access time in header of the record. Only applies for default expiration policy (ttl == 0).
 *             Locked files could be touched even if they are expired.
 *             Success callback is given if file was found and no errors occured even though nothing was changed due to
 *             ttl == 0.
 *             Req.#1.2. Expired records treated as not found on touch.
 * @param key Key which record header to update. Mustn't be nil.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)touchDataForKey:(NSString *)key
               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @brief Removes data for keys unconditionally even if expired.
 * @param keys The keys corresponding to the data to remove.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)removeDataForKeys:(NSArray<NSString *> *)keys
                 callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                  onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Increment ref count for given keys. Give callback with result for each key in input array.
 *             Req.#1.2. Expired records treated as not found on lock.
 * @param keys Non nil non empty array of keys.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (BOOL)lockDataForKeys:(NSArray<NSString *> *)keys
               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * @discussion Decrement ref count for given keys. Give callback with result for each key in input array.
 *             If decrements exceeds increments assertion is given.
 * @param keys Non nil non empty array of keys.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (BOOL)unlockDataForKeys:(NSArray<NSString *> *)keys
                 callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                  onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * Schedule garbage collection. If already scheduled then this method does nothing.
 */
- (void)scheduleGarbageCollector;
/**
 * Stop garbage collection. If already stopped this method does nothing.
 */
- (void)unscheduleGarbageCollector;
/**
 * Delete all files files in managed folder unconditionaly.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)pruneWithCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
                  onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * Wipe only files that locked regardless of refCount value.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)wipeLockedFilesWithCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
                            onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * Wipe only files that are not locked regardles of their expiration time.
 * @param callback May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)wipeNonLockedFilesWithCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
                               onQueue:(dispatch_queue_t _Nullable)queue;
/**
 * Returns size occupied by cache.
 * @warning This method does synchronous calculations.
 */
- (NSUInteger)totalUsedSizeInBytes;
/**
 * Returns size occupied by locked items.
 * @warning This method does synchronous calculations.
 */
- (NSUInteger)lockedItemsSizeInBytes;

@end

NS_ASSUME_NONNULL_END
