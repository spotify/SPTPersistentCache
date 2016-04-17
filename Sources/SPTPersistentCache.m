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
#import "SPTPersistentCache+Private.h"

#import <SPTPersistentCache/SPTPersistentCacheHeader.h>

#import "SPTPersistentCacheRecord+Private.h"
#import "SPTPersistentCacheResponse+Private.h"
#import "SPTPersistentCache+Private.h"
#import "SPTPersistentCacheGarbageCollector.h"
#import "NSError+SPTPersistentCacheDomainErrors.h"
#import "SPTPersistentCacheFileManager.h"
#import "SPTPersistentCacheTypeUtilities.h"
#import "SPTPersistentCacheDebugUtilities.h"
#import "SPTPersistentCachePosixWrapper.h"

#include <sys/stat.h>

#include "crc32iso3309.h"

// Enable for more precise logging
//#define DEBUG_OUTPUT_ENABLED

typedef SPTPersistentCacheResponse* (^SPTPersistentCacheFileProcessingBlockType)(int filedes);
typedef void (^SPTPersistentCacheRecordHeaderGetCallbackType)(SPTPersistentCacheRecordHeader *header);

NSString *const SPTPersistentCacheErrorDomain = @"persistent.cache.error";
static NSString * const SPTDataCacheFileNameKey = @"SPTDataCacheFileNameKey";
static NSString * const SPTDataCacheFileAttributesKey = @"SPTDataCacheFileAttributesKey";

static const uint64_t SPTPersistentCacheTTLUpperBoundInSec = 86400 * 31 * 2;

void SPTPersistentCacheSafeDispatch(_Nullable dispatch_queue_t queue, _Nullable dispatch_block_t block)
{
    if (!block) {
        return;
    }
    const dispatch_queue_t dispatchQueue = queue ?: dispatch_get_main_queue();
    if (dispatchQueue == dispatch_get_main_queue() && [NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatchQueue, block);
    }
}

// Class extension exists in SPTPersistentCache+Private.h

#pragma mark - SPTPersistentCache

@implementation SPTPersistentCache

- (instancetype)init
{
    return [self initWithOptions:[SPTPersistentCacheOptions new]];
}

- (instancetype)initWithOptions:(SPTPersistentCacheOptions *)options
{
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create(options.identifierForQueue.UTF8String, DISPATCH_QUEUE_CONCURRENT);
        NSAssert(_workQueue, @"The work queue couldn’t be created using the given options: %@", options);

        _options = [options copy];
        _fileManager = [NSFileManager defaultManager];
        _debugOutput = [self.options.debugOutput copy];
        _dataCacheFileManager = [[SPTPersistentCacheFileManager alloc] initWithOptions:_options];
        _posixWrapper = [SPTPersistentCachePosixWrapper new];
        _garbageCollector = [[SPTPersistentCacheGarbageCollector alloc] initWithCache:self
                                                                              options:_options
                                                                                queue:_workQueue];


        if (![_dataCacheFileManager createCacheDirectory]) {
            return nil;
        }
    }
    return self;
}

- (BOOL)loadDataForKey:(NSString *)key
          withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
               onQueue:(dispatch_queue_t _Nullable)queue
{
    if (callback == nil || queue == nil) {
        return NO;
    }

    callback = [callback copy];
    [self doWork:^{
        [self loadDataForKeySync:key withCallback:callback onQueue:queue];
    }];
    return YES;
}

- (BOOL)loadDataForKeysWithPrefix:(NSString *)prefix
                chooseKeyCallback:(SPTPersistentCacheChooseKeyCallback _Nullable)chooseKeyCallback
                     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
                          onQueue:(dispatch_queue_t _Nullable)queue
{
    if (callback == nil || queue == nil || chooseKeyCallback == nil) {
        return NO;
    }

    [self doWork:^{
        NSString *path = [self.dataCacheFileManager subDirectoryPathForKey:prefix];
        NSMutableArray * __block keys = [NSMutableArray array];

        // WARNING: Do not use enumeratorAtURL never ever. Its unsafe bcuz gets locked forever
        NSError *error = nil;
        NSArray *content = [self.fileManager contentsOfDirectoryAtPath:path error:&error];

        if (content == nil) {
            // If no directory is exist its fine, say not found to user
            if (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError) {
                [self dispatchEmptyResponseWithResult:SPTPersistentCacheResponseCodeNotFound
                                             callback:callback
                                              onQueue:queue];
            } else {
                [self debugOutput:@"PersistentDataCache: Unable to get dir contents: %@, error: %@", path, [error localizedDescription]];
                [self dispatchError:error
                             result:SPTPersistentCacheResponseCodeOperationError
                           callback:callback
                            onQueue:queue];
            }
            return;
        }

        [content enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            NSString *file = key;
            if ([file hasPrefix:prefix]) {
                [keys addObject:file];
            }
        }];

        NSMutableArray * __block keysToConsider = [NSMutableArray array];

        // Validate keys for expiration before giving it back to caller. Its important since giving expired keys
        // is wrong since caller can miss data that are no expired by picking expired key.
        for (NSString *key in keys) {
            NSString *filePath = [self.dataCacheFileManager pathForKey:key];

            // WARNING: We may skip return result here bcuz in that case we will skip the key as invalid
            [self alterHeaderForFileAtPath:filePath withBlock:^(SPTPersistentCacheRecordHeader *header) {
                // Satisfy Req.#1.2
                if ([self isDataCanBeReturnedWithHeader:header]) {
                    [keysToConsider addObject:key];
                }
            } writeBack:NO complain:YES];
        }

        // If not keys left after validation we are done with not found callback
        if (keysToConsider.count == 0) {
            [self dispatchEmptyResponseWithResult:SPTPersistentCacheResponseCodeNotFound
                                         callback:callback
                                          onQueue:queue];
            return;
        }

        NSString *keyToOpen = chooseKeyCallback(keysToConsider);

        // If user told us 'nil' he didnt found abything interesting in keys so we are done wiht not found
        if (keyToOpen == nil) {
            [self dispatchEmptyResponseWithResult:SPTPersistentCacheResponseCodeNotFound
                                         callback:callback
                                          onQueue:queue];
            return;
        }
        
        [self loadDataForKeySync:keyToOpen withCallback:callback onQueue:queue];
    }];

    return YES;
}

- (BOOL)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
          onQueue:(dispatch_queue_t _Nullable)queue

{
    return [self storeData:data forKey:key ttl:0 locked:locked withCallback:callback onQueue:queue];
}

- (BOOL)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTPersistentCacheResponseCallback _Nullable)callback
          onQueue:(dispatch_queue_t _Nullable)queue

{
    if (data == nil || key == nil || (callback != nil && queue == nil)) {
        return NO;
    }

    callback = [callback copy];
    [self doWork:^{
        [self storeDataSync:data forKey:key ttl:ttl locked:locked withCallback:callback onQueue:queue];
    }];
    return YES;
}


// TODO: return NOT_PERMITTED on try to touch TLL>0
- (void)touchDataForKey:(NSString *)key
               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                onQueue:(dispatch_queue_t _Nullable)queue
{
    if (callback != nil) {
        NSAssert(queue, @"You must specify the queue");
    }


    [self doWork:^{
        NSString *filePath = [self.dataCacheFileManager pathForKey:key];

        BOOL __block expired = NO;

        SPTPersistentCacheResponse *response = [self alterHeaderForFileAtPath:filePath
                                                                    withBlock:^(SPTPersistentCacheRecordHeader *header) {
                                                                        // Satisfy Req.#1.2 and Req.#1.3
                                                                        if (![self isDataCanBeReturnedWithHeader:header]) {
                                                                            expired = YES;
                                                                            return;
                                                                        }
                                                                        // Touch files that have default expiration policy
                                                                        if (header->ttl == 0) {
                                                                            header->updateTimeSec = spt_uint64rint(self.currentDateTimeInterval);
                                                                        }
                                                                    }
                                                                    writeBack:YES
                                                                     complain:NO];

        // Satisfy Req.#1.2
        if (expired) {
            response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeNotFound
                                                                    error:nil
                                                                   record:nil];
        }

        if (callback) {
            SPTPersistentCacheSafeDispatch(queue, ^{
                callback(response);
            });
        }
    }];
}

- (void)removeDataForKeysSync:(NSArray<NSString *> *)keys
{
    for (NSString *key in keys) {
        [self.dataCacheFileManager removeDataForKey:key];
    }
}

- (void)removeDataForKeys:(NSArray<NSString *> *)keys
{
    dispatch_barrier_async(self.workQueue, ^{
        [self removeDataForKeysSync:keys];
    });
}

- (BOOL)lockDataForKeys:(NSArray<NSString *> *)keys
               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                onQueue:(dispatch_queue_t _Nullable)queue
{
    if ((callback != nil && queue == nil) || keys.count == 0) {
        return NO;
    }

    [self doWork:^{
        for (NSString *key in keys) {
            NSString *filePath = [self.dataCacheFileManager pathForKey:key];
            BOOL __block expired = NO;
            SPTPersistentCacheResponse *response = [self alterHeaderForFileAtPath:filePath
                                                                        withBlock:^(SPTPersistentCacheRecordHeader *header) {
                                                                            // Satisfy Req.#1.2
                                                                            if ([self isDataExpiredWithHeader:header]) {
                                                                                expired = YES;
                                                                                return;
                                                                            }
                                                                            ++header->refCount;
                                                                            // Do not update access time since file is locked
                                                                        }
                                                                        writeBack:YES
                                                                         complain:YES];
            // Satisfy Req.#1.2
            if (expired) {
                response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeNotFound
                                                                        error:nil
                                                                       record:nil];
            }
            if (callback) {
                SPTPersistentCacheSafeDispatch(queue, ^{
                    callback(response);
                });
            }
            
        } // for
    }];
    return YES;
}

- (BOOL)unlockDataForKeys:(NSArray<NSString *> *)keys
                 callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                  onQueue:(dispatch_queue_t _Nullable)queue
{
    if ((callback != nil && queue == nil) || keys.count == 0) {
        return NO;
    }

    [self doWork:^{
        for (NSString *key in keys) {
            NSString *filePath = [self.dataCacheFileManager pathForKey:key];
            SPTPersistentCacheResponse *response = [self alterHeaderForFileAtPath:filePath
                                                                        withBlock:^(SPTPersistentCacheRecordHeader *header){
                                                                            if (header->refCount > 0) {
                                                                                --header->refCount;
                                                                            } else {
                                                                                [self debugOutput:@"PersistentDataCache: Error trying to decrement refCount below 0 for file at path:%@", filePath];
                                                                            }
                                                                        }
                                                                        writeBack:YES
                                                                         complain:YES];
            if (callback) {
                SPTPersistentCacheSafeDispatch(queue, ^{
                    callback(response);
                });
            }
        } // for
    }];
    return YES;
}

- (void)scheduleGarbageCollector
{
    [self.garbageCollector schedule];
}

- (void)unscheduleGarbageCollector
{
    [self.garbageCollector unschedule];
}

- (void)prune
{
    dispatch_barrier_async(self.workQueue, ^{
        [self.dataCacheFileManager removeAllData];
    });
}

- (void)wipeLockedFiles
{
    dispatch_barrier_async(self.workQueue, ^{
        [self collectGarbageForceExpire:NO forceLocked:YES];
    });
}

- (void)wipeNonLockedFiles{
    dispatch_barrier_async(self.workQueue, ^{
        [self collectGarbageForceExpire:YES forceLocked:NO];
    });
}

- (NSUInteger)totalUsedSizeInBytes
{
    return self.dataCacheFileManager.totalUsedSizeInBytes;
}

- (NSUInteger)lockedItemsSizeInBytes
{
    NSUInteger size = 0;
    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];

    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {

        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        NSError *error = nil;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            if ([isDirectory boolValue] == NO) {

                NSString *key = theURL.lastPathComponent;
                // That satisfies Req.#1.3
                NSString *filePath = [self.dataCacheFileManager pathForKey:key];
                BOOL __block locked = NO;
                // WARNING: We may skip return result here bcuz in that case we will not count file as locked
                [self alterHeaderForFileAtPath:filePath withBlock:^(SPTPersistentCacheRecordHeader *header) {
                    locked = header->refCount > 0;
                } writeBack:NO complain:YES];
                if (locked) {
                    size += [self.dataCacheFileManager getFileSizeAtPath:filePath];
                }
            }
        } else {
            [self debugOutput:@"Unable to fetch isDir#3 attribute:%@ error: %@", theURL, error];
        }
    }

    return size;
}

- (void)dealloc
{
    [_garbageCollector unschedule];
}

/**
 * Load method used internally to load data. Called on work queue.
 */
- (void)loadDataForKeySync:(NSString *)key
              withCallback:(SPTPersistentCacheResponseCallback)callback
                   onQueue:(dispatch_queue_t)queue
{
    NSString *filePath = [self.dataCacheFileManager pathForKey:key];

    // File not exist -> inform user
    if (![self.fileManager fileExistsAtPath:filePath]) {
        [self dispatchEmptyResponseWithResult:SPTPersistentCacheResponseCodeNotFound callback:callback onQueue:queue];
        return;
    }
    // File exist
    SPTPersistentCacheRecordHeader header;
    NSError *headerError = SPTPersistentCacheGetHeaderFromFileWithPath(filePath, &header);
    if (headerError != nil) {
        [self dispatchError:headerError
                     result:SPTPersistentCacheResponseCodeOperationError
                   callback:callback
                    onQueue:queue];
        return;
    }

    const NSUInteger refCount = header.refCount;

    // We return locked files even if they expired, GC doesnt collect them too so they valuable to user
    // Satisfy Req.#1.2
    if (![self isDataCanBeReturnedWithHeader:&header]) {
#ifdef DEBUG_OUTPUT_ENABLED
        [self debugOutput:@"PersistentDataCache: Record with key: %@ expired, t:%llu, TTL:%llu", key, localHeader.updateTimeSec, localHeader.ttl];
#endif
        [self dispatchEmptyResponseWithResult:SPTPersistentCacheResponseCodeNotFound
                                     callback:callback
                                      onQueue:queue];
        return;
    }

    NSError *error = nil;
    NSData *rawData = [NSData dataWithContentsOfFile:filePath
                                             options:NSDataReadingMappedIfSafe
                                               error:&error];
    if (rawData == nil) {
        // File read with error -> inform user
        [self dispatchError:error
                     result:SPTPersistentCacheResponseCodeOperationError
                   callback:callback
                    onQueue:queue];
        return;
    }
    NSData *payload = [self payloadFromRawData:rawData];
    // Check that payload is correct size
    if (header.payloadSizeBytes != payload.length) {
        [self debugOutput:@"PersistentDataCache: Error: Wrong payload size for key:%@ , will return error", key];
        [self dispatchError:[NSError spt_persistentDataCacheErrorWithCode:SPTPersistentCacheLoadingErrorWrongPayloadSize]
                     result:SPTPersistentCacheResponseCodeOperationError
                   callback:callback onQueue:queue];
        return;
    }

    const NSUInteger ttl = (NSUInteger)header.ttl;

    SPTPersistentCacheRecord *record = [[SPTPersistentCacheRecord alloc] initWithData:payload
                                                                                  key:key
                                                                             refCount:refCount
                                                                                  ttl:ttl];

    SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationSucceeded
                                                                                        error:nil
                                                                                       record:record];
    // If data ttl == 0 we update access time
    if (ttl == 0) {
        header.updateTimeSec = spt_uint64rint(self.currentDateTimeInterval);
        header.crc = SPTPersistentCacheCalculateHeaderCRC(&header);

        // Write back with updated access attributes
        NSError* headerSetError = SPTPersistentCacheSetHeaderForFileWithPath(filePath, &header);
        if (headerSetError != nil) {
            [self debugOutput:@"PersistentDataCache: Error writing back record:%@ error:%@", filePath.lastPathComponent, [headerSetError localizedDescription]];
        } else {
#ifdef DEBUG_OUTPUT_ENABLED
            [self debugOutput:@"PersistentDataCache: Writing back file header:%@ OK", filePath.lastPathComponent];
#endif
        }
    }


    // Callback only after we finished everyhing to avoid situation when user gets notified and we are still writting
    SPTPersistentCacheSafeDispatch(queue, ^{
        callback(response);
    });
}

/**
 *  Gets payload from the raw data. Removes the legacy header if needed.
 */
- (NSData*)payloadFromRawData:(NSData*)data
{
    NSMutableData* rawData = [data mutableCopy];
    SPTPersistentCacheRecordHeader *legacyHeader = SPTPersistentCacheGetHeaderFromData(rawData.mutableBytes, rawData.length);
    BOOL hasLegacyHeader = legacyHeader != NULL && SPTPersistentCacheCheckValidHeader(legacyHeader) == nil;
    return hasLegacyHeader ? [data subdataWithRange:NSMakeRange(SPTPersistentCacheRecordHeaderSize, data.length - SPTPersistentCacheRecordHeaderSize)] : data;
}

/**
 * Store method used internaly. Called on work queue.
 */
- (NSError *)storeDataSync:(NSData *)data
                    forKey:(NSString *)key
                       ttl:(NSUInteger)ttl
                    locked:(BOOL)isLocked
              withCallback:(SPTPersistentCacheResponseCallback)callback
                   onQueue:(dispatch_queue_t)queue
{
    NSString *filePath = [self.dataCacheFileManager pathForKey:key];

    NSString *subDir = [self.dataCacheFileManager subDirectoryPathForKey:key];
    [self.fileManager createDirectoryAtPath:subDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSError *error = nil;

    if (![data writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        [self debugOutput:@"PersistentDataCache: Error writting to file:%@ , for key:%@. Removing it...", filePath, key];
        [self removeDataForKeysSync:@[key]];
        [self dispatchError:error result:SPTPersistentCacheResponseCodeOperationError callback:callback onQueue:queue];
    } else {
        const NSUInteger payloadLength = [data length];
        SPTPersistentCacheRecordHeader header = SPTPersistentCacheRecordHeaderMake(ttl,
                                                                                   payloadLength,
                                                                                   spt_uint64rint(self.currentDateTimeInterval),
                                                                                   isLocked);
        NSError* headerSetError = SPTPersistentCacheSetHeaderForFileWithPath(filePath, &header);
        if (headerSetError != nil) {
            [self debugOutput:@"PersistentDataCache: Error writting header at file path:%@ , error:%@", filePath, [headerSetError localizedDescription]];
            [self removeDataForKeysSync:@[key]];
            [self dispatchError:headerSetError result:SPTPersistentCacheResponseCodeOperationError callback:callback onQueue:queue];
            return headerSetError;
        }

        if (callback != nil) {
            SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationSucceeded
                                                                                                error:nil
                                                                                               record:nil];

            SPTPersistentCacheSafeDispatch(queue, ^{
                callback(response);
            });
        }
    }

    return error;
}

/**
 * Method used to read/write file header.
 */
- (SPTPersistentCacheResponse *)alterHeaderForFileAtPath:(NSString *)filePath
                                               withBlock:(SPTPersistentCacheRecordHeaderGetCallbackType)modifyBlock
                                               writeBack:(BOOL)needWriteBack
                                                complain:(BOOL)needComplains
{
    if (![self.fileManager fileExistsAtPath:filePath]) {
        if (needComplains) {
            [self debugOutput:@"PersistentDataCache: Record not exist at path:%@", filePath];
        }
        return [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeNotFound error:nil record:nil];

    }
    SPTPersistentCacheRecordHeader header;
    NSError *headerGetError = SPTPersistentCacheGetHeaderFromFileWithPath(filePath, &header);
    if (headerGetError != nil) {
        [self debugOutput:@"PersistentDataCache: Failed to read the header of file path:%@ , error:%@", filePath, [headerGetError localizedDescription]];
        return [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationError
                                                            error:headerGetError
                                                           record:nil];
    }

    modifyBlock(&header);

    if (needWriteBack) {

        uint32_t oldCRC = header.crc;
        header.crc = SPTPersistentCacheCalculateHeaderCRC(&header);

        // If nothing has changed we do nothing then
        if (oldCRC == header.crc) {
            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationSucceeded
                                                                error:nil
                                                               record:nil];
        }

        NSError* headerSetError = SPTPersistentCacheSetHeaderForFileWithPath(filePath, &header);
        if (headerSetError != nil) {
            [self debugOutput:@"PersistentDataCache: Error writting header at file path:%@ , error:%@", filePath, [headerSetError localizedDescription]];
            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationError
                                                                error:headerSetError
                                                               record:nil];
        }
    }

    return [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseCodeOperationSucceeded
                                                        error:nil
                                                       record:nil];
}

/**
 * Only this method check data expiration. Past check is also supported.
 */
- (BOOL)isDataExpiredWithHeader:(SPTPersistentCacheRecordHeader *)header
{
    assert(header != nil);
    uint64_t ttl = header->ttl;
    uint64_t current = spt_uint64rint(self.currentDateTimeInterval);
    int64_t threshold = (int64_t)((ttl > 0) ? ttl : self.options.defaultExpirationPeriod);

    if (ttl > SPTPersistentCacheTTLUpperBoundInSec) {
        [self debugOutput:@"PersistentDataCache: WARNING: TTL seems too big: %llu > %llu sec", ttl, SPTPersistentCacheTTLUpperBoundInSec];
    }

    return (int64_t)(current - header->updateTimeSec) > threshold;
}

/**
 * Methos checks whether data can be given to caller with accordance to API.
 */
- (BOOL)isDataCanBeReturnedWithHeader:(SPTPersistentCacheRecordHeader *)header
{
    return !([self isDataExpiredWithHeader:header] && header->refCount == 0);
}

- (void)runRegularGC
{
    [self collectGarbageForceExpire:NO forceLocked:NO];
}

- (void)collectGarbageForceExpire:(BOOL)forceExpire forceLocked:(BOOL)forceLocked
{
    [self debugOutput:@"PersistentDataCache: Run GC with forceExpire:%d forceLock:%d", forceExpire, forceLocked];

    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];

    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {

        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {

                NSString *key = theURL.lastPathComponent;
                // That satisfies Req.#1.3
                NSString *filePath = [self.dataCacheFileManager pathForKey:key];
                BOOL __block needRemove = NO;
                int __block reason = 0;
                // WARNING: We may skip return result here bcuz in that case we won't remove file we do not know what is it
                [self alterHeaderForFileAtPath:filePath withBlock:^(SPTPersistentCacheRecordHeader *header) {
                    if (forceExpire && forceLocked) {
                        // delete all
                        needRemove = YES;
                        reason = 1;
                    } else if (forceExpire && !forceLocked) {
                        // delete those: header->refCount == 0
                        needRemove = header->refCount == 0;
                        reason = 2;
                    } else if (!forceExpire && forceLocked) {
                        // delete those: header->refCount > 0
                        needRemove = header->refCount > 0;
                        reason = 3;
                    } else {
                        // delete those: [self isDataExpiredWithHeader:header] && header->refCount == 0
                        needRemove = ![self isDataCanBeReturnedWithHeader:header];
                        reason = 4;
                    }
                } writeBack:NO complain:YES];
                if (needRemove) {
                    [self debugOutput:@"PersistentDataCache: gc removing record: %@, reason:%d", filePath.lastPathComponent, reason];
                    [self.dataCacheFileManager removeDataForKey:key];
                }
            } // is dir
        } else {
            [self debugOutput:@"Unable to fetch isDir#4 attribute:%@", theURL];
        }
    } // for
}

- (void)dispatchEmptyResponseWithResult:(SPTPersistentCacheResponseCode)result
                               callback:(SPTPersistentCacheResponseCallback _Nullable)callback
                                onQueue:(dispatch_queue_t _Nullable)queue
{
    if (callback == nil) {
        return;
    }

    SPTPersistentCacheSafeDispatch(queue, ^{
        SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:result
                                                                                            error:nil
                                                                                           record:nil];
        callback(response);
    });
}

- (void)dispatchError:(NSError *)error
               result:(SPTPersistentCacheResponseCode)result
             callback:(SPTPersistentCacheResponseCallback _Nullable)callback
              onQueue:(dispatch_queue_t _Nullable)queue
{
    if (callback == nil) {
        return;
    }

    SPTPersistentCacheSafeDispatch(queue, ^{
        SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:result
                                                                                            error:error
                                                                                           record:nil];
        callback(response);
    });
}

- (void)debugOutput:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
    SPTPersistentCacheDebugCallback const debugOutput = self.debugOutput;

    if (debugOutput && format.length > 0) {
        va_list list;
        va_start(list, format);
        NSString * const message = [[NSString alloc] initWithFormat:format arguments:list];
        va_end(list);

        debugOutput(message);
    }
}

- (BOOL)pruneBySize
{
    if (self.options.sizeConstraintBytes == 0) {
        return NO;
    }

    // Find all the image names and attributes and sort oldest last
    NSMutableArray *images = [self storedImageNamesAndAttributes];

    // Find the free space on the disk
    SPTPersistentCacheDiskSize currentCacheSize = (SPTPersistentCacheDiskSize)[self lockedItemsSizeInBytes];
    for (NSDictionary *image in images) {
        currentCacheSize += [image[SPTDataCacheFileAttributesKey][NSFileSize] integerValue];
    }

    SPTPersistentCacheDiskSize optimalCacheSize = [self.dataCacheFileManager optimizedDiskSizeForCacheSize:currentCacheSize];

    // Remove oldest data until we reach acceptable cache size
    while (currentCacheSize > optimalCacheSize && images.count) {
        NSDictionary *image = images.lastObject;
        [images removeLastObject];

        NSString *fileName = image[SPTDataCacheFileNameKey];
        NSError *localError = nil;
        if (fileName.length > 0 && ![self.fileManager removeItemAtPath:fileName error:&localError]) {
            [self debugOutput:@"PersistentDataCache: %@ ERROR %@", @(__PRETTY_FUNCTION__), [localError localizedDescription]];
            continue;
        } else {
            [self debugOutput:@"PersistentDataCache: evicting by size key:%@", fileName.lastPathComponent];
        }

        currentCacheSize -= [image[SPTDataCacheFileAttributesKey][NSFileSize] integerValue];
    }
    return YES;
}

- (NSMutableArray *)storedImageNamesAndAttributes
{
    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];

    // Enumerate the directory (specified elsewhere in your code)
    // Ignore hidden files
    // The errorHandler: parameter is set to nil. Typically you'd want to present a panel
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];

    // An array to store the all the enumerated file names in
    NSMutableArray *images = [NSMutableArray array];

    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {

        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {

            if ([isDirectory boolValue] == NO) {

                // We skip locked files always
                BOOL __block locked = NO;

                // WARNING: We may skip return result here bcuz in that case we will remove unknown file as unlocked trash
                [self alterHeaderForFileAtPath:[NSString stringWithUTF8String:theURL.fileSystemRepresentation]
                                     withBlock:^(SPTPersistentCacheRecordHeader *header) {
                                         locked = (header->refCount > 0);
                                     } writeBack:NO
                                      complain:YES];

                if (locked) {
                    continue;
                }

                /* We use this since this is most reliable method to get file info and URL stuff fails sometimes
                 which is described in apple doc and its our case here */

                struct stat fileStat;
                int ret = [self.posixWrapper stat:[theURL fileSystemRepresentation] statStruct:&fileStat];
                if (ret == -1) {
                    [self debugOutput:@"Cannot find the stats of file: %@", theURL.absoluteString];
                    continue;
                }

                /*
                 Use modification time even for files with TTL
                 Files with TTL have updateTime set once on creation.
                 */
                NSDate *mdate = [NSDate dateWithTimeIntervalSince1970:(fileStat.st_mtimespec.tv_sec + fileStat.st_mtimespec.tv_nsec*1e9)];
                NSNumber *fsize = [NSNumber numberWithLongLong:fileStat.st_size];
                NSDictionary *values = @{NSFileModificationDate : mdate, NSFileSize: fsize};

                [images addObject:@{ SPTDataCacheFileNameKey : [NSString stringWithUTF8String:[theURL fileSystemRepresentation]],
                                     SPTDataCacheFileAttributesKey : values }];
            }
        } else {
            [self debugOutput:@"Unable to fetch isDir#5 attribute:%@", theURL];
        }
    }

    // Oldest goes last
    NSComparisonResult(^SPTSortFilesByModificationDate)(id, id) = ^NSComparisonResult(NSDictionary *file1, NSDictionary *file2) {
        NSDate *date1 = file1[SPTDataCacheFileAttributesKey][NSFileModificationDate];
        NSDate *date2 = file2[SPTDataCacheFileAttributesKey][NSFileModificationDate];
        return [date2 compare:date1];
    };

    NSArray *sortedImages = [images sortedArrayUsingComparator:SPTSortFilesByModificationDate];

    return [sortedImages mutableCopy];
}

- (NSTimeInterval)currentDateTimeInterval
{
    return [[NSDate date] timeIntervalSince1970];
}

- (void)doWork:(dispatch_block_t)block
{
    SPTPersistentCacheSafeDispatch(self.workQueue, block);
}

@end
