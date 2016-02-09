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
#import "SPTPersistentDataCache.h"

#import "crc32iso3309.h"
#import "SPTPersistentDataHeader.h"
#import "SPTDataCacheRecord+Private.h"
#import "SPTPersistentCacheResponse+Private.h"
#import "SPTPersistentDataCache+Private.h"
#import "SPTTimerProxy.h"
#include <sys/stat.h>

// Enable for more precise logging
//#define DEBUG_OUTPUT_ENABLED

/**
 * Converts the given `double` _value_ to an `uint64_t` value.
 *
 * @param value The value as a `double`.
 * @return The value as an `uint64_t`.
 */
NS_INLINE uint64_t spt_uint64rint(double value)
{
    return (uint64_t)llrint(value);
}

NSString *const SPTPersistentDataCacheErrorDomain = @"persistent.cache.error";
static const uint64_t kTTLUpperBoundInSec = 86400 * 31 * 2;
static const NSUInteger SPTPersistentDataCacheGCIntervalLimitSec = 60;
static const NSUInteger SPTPersistentDataCacheDefaultExpirationLimitSec = 60;

const MagicType kSPTPersistentDataCacheMagic = 0x46545053; // SPTF
const int kSPTPersistentRecordHeaderSize = sizeof(SPTPersistentRecordHeaderType);

typedef long long SPTDiskSizeType;
static const double SPTDataCacheMinimumFreeDiskSpace = 0.1;

static NSString * const SPTDataCacheFileNameKey = @"SPTDataCacheFileNameKey";
static NSString * const SPTDataCacheFileAttributesKey = @"SPTDataCacheFileAttributesKey";

typedef SPTPersistentCacheResponse* (^FileProcessingBlockType)(int filedes);
typedef void (^RecordHeaderGetCallbackType)(SPTPersistentRecordHeaderType *header);

#pragma mark - SPTPersistentDataCache()

@interface SPTPersistentDataCache ()

@property (nonatomic, copy) SPTPersistentDataCacheOptions *options;
// Serial queue used to run all internall stuff
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSTimer *gcTimer;
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
@property (nonatomic, copy) SPTDataCacheCurrentTimeSecCallback currentTime;
// Keys that are currently shouldn't be opened bcuz its busy by streams for example
@property (nonatomic, strong) NSMutableSet *busyKeys;

@end

#pragma mark - SPTPersistentDataCache
@implementation SPTPersistentDataCache

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    _options = [SPTPersistentDataCacheOptions new];
    self.options.defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationTimeSec;
    self.options.gcIntervalSec = SPTPersistentDataCacheDefaultGCIntervalSec;
    self.fileManager = [NSFileManager defaultManager];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/com.spotify.temppersistent.image.cache"];
    self.options.cachePath = cachePath;
    if (self.options.cacheIdentifier == nil) {
        self.options.cacheIdentifier = @"persistent.cache";
    }
    assert(self.options.cachePath != nil);
    
    NSString *name = [NSString stringWithFormat:@"%@.queue.%ld.%ld.%p", self.options.cacheIdentifier,
                      (unsigned long)self.options.gcIntervalSec, (unsigned long)self.options.defaultExpirationPeriodSec, (void *)self];
    _workQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_CONCURRENT);
    _busyKeys = [NSMutableSet set];

    self.currentTime = self.options.currentTimeSec;
    if (self.currentTime == nil) {
        self.currentTime = ^NSTimeInterval(){ return [[NSDate date] timeIntervalSince1970]; };
    }

    return self;
}

- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options
{
    if (!(self = [super init])) {
        return nil;
    }

    _options = options;
    if (self.options.cacheIdentifier == nil) {
        self.options.cacheIdentifier = @"persistent.cache";
    }
    NSString *name = [NSString stringWithFormat:@"%@.queue.%ld.%ld.%p", self.options.cacheIdentifier,
                      (unsigned long)self.options.gcIntervalSec, (unsigned long)self.options.defaultExpirationPeriodSec, (void *)self];
    _workQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_CONCURRENT);
    assert(_workQueue != nil);
    self.fileManager = [NSFileManager defaultManager];
    _debugOutput = self.options.debugOutput;
    _busyKeys = [NSMutableSet set];

    self.currentTime = self.options.currentTimeSec;
    if (self.currentTime == nil) {
        self.currentTime = ^NSTimeInterval(){ return [[NSDate date] timeIntervalSince1970]; };
    }

    assert(self.options.cachePath != nil);

    BOOL isDir = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:self.options.cachePath isDirectory:&isDir];
    if (exist == NO) {
        NSError *error = nil;
        BOOL created = [self.fileManager createDirectoryAtPath:self.options.cachePath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error];
        if (created == NO) {
            [self debugOutput:@"PersistentDataCache: Unable to create dir: %@ with error:%@", self.options.cachePath, error];
            return nil;
        }
    }

    if (self.options.defaultExpirationPeriodSec < SPTPersistentDataCacheDefaultExpirationLimitSec) {
        [self debugOutput:@"PersistentDataCache: Forcing defaultExpirationPeriodSec to %ld sec", (unsigned long)SPTPersistentDataCacheDefaultExpirationLimitSec];
        self.options.defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationLimitSec;
    }

    if (self.options.gcIntervalSec < SPTPersistentDataCacheGCIntervalLimitSec) {
        [self debugOutput:@"PersistentDataCache: Forcing gcIntervalSec to %ld sec", (unsigned long)SPTPersistentDataCacheGCIntervalLimitSec];
        self.options.gcIntervalSec = SPTPersistentDataCacheGCIntervalLimitSec;
    }

    return self;
}

- (void)loadDataForKey:(NSString *)key
          withCallback:(SPTDataCacheResponseCallback)callback
               onQueue:(dispatch_queue_t)queue
{
    assert(callback != nil);
    assert(queue != nil);
    if (callback == nil || queue == nil) {
        return;
    }

    callback = [callback copy];
    dispatch_async(self.workQueue, ^{
        [self loadDataForKeySync:key withCallback:callback onQueue:queue];
    });
}

- (void)loadDataForKeysWithPrefix:(NSString *)prefix
                chooseKeyCallback:(SPTDataCacheChooseKeyCallback)chooseKeyCallback
                     withCallback:(SPTDataCacheResponseCallback)callback
                          onQueue:(dispatch_queue_t)queue
{
    assert(callback != nil);
    assert(chooseKeyCallback != nil);
    assert(queue != nil);
    if (callback == nil || queue == nil) {
        return;
    }

    if (chooseKeyCallback == nil) {
        return;
    }

    dispatch_async(self.workQueue, ^{

        NSString *path = [self subDirectoryPathForKey:prefix];
        NSMutableArray * __block keys = [NSMutableArray array];

        // WARNING: Do not use enumeratorAtURL never ever. Its unsafe bcuz gets locked forever
        NSError *error = nil;
        NSArray *content = [self.fileManager contentsOfDirectoryAtPath:path error:&error];

        if (content == nil) {
            // If no directory is exist its fine, say not found to user
            if (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError) {
                [self dispatchEmptyResponseWithResult:SPTDataCacheResponseCodeNotFound callback:callback onQueue:queue];
            } else {
                [self debugOutput:@"PersistentDataCache: Unable to get dir contents: %@, error: %@", path, [error localizedDescription]];
                [self dispatchError:error result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];
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
            NSString *filePath = [self pathForKey:key];

            // WARNING: We may skip return result here bcuz in that case we will skip the key as invalid
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header) {
                                     assert(header != nil);

                                     // Satisfy Req.#1.2
                                     if ([self isDataCanBeReturnedWithHeader:header]) {
                                         [keysToConsider addObject:key];
                                     }
                                 }
                                 writeBack:NO
                                  complain:YES];

        }

        // If not keys left after validation we are done with not found callback
        if (keysToConsider.count == 0) {
            [self dispatchEmptyResponseWithResult:SPTDataCacheResponseCodeNotFound callback:callback onQueue:queue];
            return;
        }

        NSString *keyToOpen = chooseKeyCallback(keysToConsider);

        // If user told us 'nil' he didnt found abything interesting in keys so we are done wiht not found
        if (keyToOpen == nil) {
            [self dispatchEmptyResponseWithResult:SPTDataCacheResponseCodeNotFound callback:callback onQueue:queue];
            return;
        }

        [self loadDataForKeySync:keyToOpen withCallback:callback onQueue:queue];
    });
}

- (void)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue

{
    [self storeData:data forKey:key ttl:0 locked:locked withCallback:callback onQueue:queue];
}

- (void)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue

{
    assert(data != nil);
    assert(key != nil);

    if (callback != nil) {
        assert(queue != nil);
    }

    if (data == nil || key == nil) {
        return;
    }
    if (callback != nil && queue == nil) {
        return;
    }

    callback = [callback copy];
    dispatch_barrier_async(self.workQueue, ^{
        // That satisfies Req.#1.3
        if ([self processKeyIfBusy:key callback:callback queue:queue]) {
            return;
        }

        [self storeDataSync:data forKey:key ttl:ttl locked:locked withCallback:callback onQueue:queue];
    });
}


// TODO: return NOT_PERMITTED on try to touch TLL>0
- (void)touchDataForKey:(NSString *)key
               callback:(SPTDataCacheResponseCallback)callback
                onQueue:(dispatch_queue_t)queue
{
    if (callback != nil) {
        assert(queue);
    }


    dispatch_barrier_async(self.workQueue, ^{
        // That satisfies Req.#1.3
        if ([self processKeyIfBusy:key callback:callback queue:queue]) {
            return;
        }

        NSString *filePath = [self pathForKey:key];

        BOOL __block expired = NO;
        SPTPersistentCacheResponse *response =
        [self alterHeaderForFileAtPath:filePath
                             withBlock:^(SPTPersistentRecordHeaderType *header) {
                                 assert(header != nil);

                                 // Satisfy Req.#1.2 and Req.#1.3
                                 if (![self isDataCanBeReturnedWithHeader:header]) {
                                     expired = YES;
                                     return;
                                 }

                                 // Touch files that have default expiration policy
                                 if (header->ttl == 0) {
                                     header->updateTimeSec = spt_uint64rint(self.currentTime());
                                 }
                             }
                             writeBack:YES
                              complain:NO];

        // Satisfy Req.#1.2
        if (expired) {
            response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeNotFound error:nil record:nil];
        }

        if (callback) {
            dispatch_async(queue, ^{
                callback(response);
            });
        }
    });
}

- (void)removeDataForKeysSync:(NSArray *)keys
{
    for (NSString *key in keys) {

        // That satisfies Req.#1.3
        if ([self processKeyIfBusy:key callback:nil queue:nil]) {
            continue;
        }

        NSError *error = nil;
        NSString *filePath = [self pathForKey:key];
        if (![self.fileManager removeItemAtPath:filePath error:&error]) {
            [self debugOutput:@"PersistentDataCache: Error removing data for Key:%@ , error:%@", key, error];
        }
    }
}

- (void)removeDataForKeys:(NSArray *)keys
{
    dispatch_barrier_async(self.workQueue, ^{
        [self removeDataForKeysSync:keys];
    });
}

- (void)lockDataForKeys:(NSArray *)keys
               callback:(SPTDataCacheResponseCallback)callback
                onQueue:(dispatch_queue_t)queue
{
    if (callback != nil) {
        assert(queue);
    }
    assert([keys count] > 0);
    
    dispatch_barrier_async(self.workQueue, ^{
        for (NSString *key in keys) {

            // That satisfies Req.#1.3
            if ([self processKeyIfBusy:key callback:callback queue:queue]) {
                continue;
            }

            NSString *filePath = [self pathForKey:key];

            BOOL __block expired = NO;
            SPTPersistentCacheResponse *response =
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header) {
                                     assert(header != nil);

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
                response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeNotFound error:nil record:nil];
            }

            if (callback) {
                dispatch_async(queue, ^{
                    callback(response);
                });
            }

        } // for
    });
}

- (void)unlockDataForKeys:(NSArray *)keys
                 callback:(SPTDataCacheResponseCallback)callback
                  onQueue:(dispatch_queue_t)queue
{
    if (callback != nil) {
        assert(queue);
    }
    assert([keys count] > 0);

    dispatch_barrier_async(self.workQueue, ^{
        for (NSString *key in keys) {

            // That satisfies Req.#1.3
            if ([self processKeyIfBusy:key callback:callback queue:queue]) {
                continue;
            }

            NSString *filePath = [self pathForKey:key];

            SPTPersistentCacheResponse *response =
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header){
                                     assert(header != nil);

                                     if (header->refCount > 0) {
                                         --header->refCount;
                                     } else {
                                         [self debugOutput:@"PersistentDataCache: Error trying to decrement refCount below 0 for file at path:%@", filePath];
                                     }
                                 }
                                 writeBack:YES
                                  complain:YES];

            if (callback) {
                dispatch_async(queue, ^{
                    callback(response);
                });
            }
        } // for
    });
}

- (void)scheduleGarbageCollector
{
    assert([NSThread isMainThread]);

    [self debugOutput:@"runGarbageCollector:%@", self.gcTimer];

    // if gc process already running to nothing
    if (self.gcTimer != nil) {
        return;
    }

    SPTTimerProxy *proxy = [SPTTimerProxy new];
    proxy.dataCache = self;
    proxy.queue = self.workQueue;

    NSTimeInterval interval = self.options.gcIntervalSec;
    // clang diagnostics to workaround http://www.openradar.appspot.com/17806477 (-Wselector)
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wselector\"");
    self.gcTimer = [NSTimer timerWithTimeInterval:interval target:proxy selector:@selector(enqueueGC:) userInfo:nil repeats:YES];
    _Pragma("clang diagnostic pop");
    self.gcTimer.tolerance = 300;
    
    [[NSRunLoop mainRunLoop] addTimer:self.gcTimer forMode:NSDefaultRunLoopMode];
}

- (void)unscheduleGarbageCollector
{
    assert([NSThread isMainThread]);

    [self debugOutput:@"stopGarbageCollector:%@", self.gcTimer];

    [self.gcTimer invalidate];
    self.gcTimer = nil;
}

- (void)prune
{
    dispatch_barrier_async(self.workQueue, ^{
        [self cleanCacheData];
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
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {
                NSString *key = theURL.lastPathComponent;

                NSString *filePath = [self pathForKey:key];
                size += [self getFileSizeAtPath:filePath];
            }
        } else {
            [self debugOutput:@"Unable to fetch isDir#2 attribute:%@", theURL];
        }
    }

    return size;
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
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {

                NSString *key = theURL.lastPathComponent;
                // That satisfies Req.#1.3
                if (![self.busyKeys containsObject:key]) {
                    NSString *filePath = [self pathForKey:key];

                    BOOL __block locked = NO;
                    // WARNING: We may skip return result here bcuz in that case we will not count file as locked
                    [self alterHeaderForFileAtPath:filePath withBlock:^(SPTPersistentRecordHeaderType *header) {
                        locked = header->refCount > 0;
                    }
                                         writeBack:NO
                                          complain:YES];
                    if (locked) {
                        size += [self getFileSizeAtPath:filePath];
                    }
                }
            }
        } else {
            [self debugOutput:@"Unable to fetch isDir#3 attribute:%@", theURL];
        }
    }

    return size;
}

- (void)dealloc
{
    NSTimer *timer = self.gcTimer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [timer invalidate];
    });
}

#pragma mark - Private methods
/**
 * Load method used internally to load data. Called on work queue.
 */
- (void)loadDataForKeySync:(NSString *)key withCallback:(SPTDataCacheResponseCallback)callback onQueue:(dispatch_queue_t)queue
{
    NSString *filePath = [self pathForKey:key];

    // File not exist -> inform user
    if (![self.fileManager fileExistsAtPath:filePath]) {
        [self dispatchEmptyResponseWithResult:SPTDataCacheResponseCodeNotFound callback:callback onQueue:queue];
        return;
    } else {

        // That satisfies Req.#1.3
        if ([self processKeyIfBusy:key callback:callback queue:queue]) {
            return;
        }

        // File exist
        NSError *error = nil;
        NSMutableData *rawData = [NSMutableData dataWithContentsOfFile:filePath
                                                               options:NSDataReadingMappedIfSafe
                                                                 error:&error];
        if (rawData == nil) {
            // File read with error -> inform user
            [self dispatchError:error result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];
        } else {
            SPTPersistentRecordHeaderType *header = pdc_GetHeaderFromData(rawData.mutableBytes, rawData.length);

            // If not enough data to cast to header, its not the file we can process
            if (header == NULL) {
                NSError *headerError = [self nsErrorWithCode:SPTDataCacheLoadingErrorNotEnoughDataToGetHeader];
                [self dispatchError:headerError result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];
                return;
            }

            SPTPersistentRecordHeaderType localHeader;
            memcpy(&localHeader, header, sizeof(localHeader));

            // Check header is valid
            NSError *headerError = [self checkHeaderValid:&localHeader];
            if (headerError != nil) {
                [self dispatchError:headerError result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];
                return;
            }

            const NSUInteger refCount = localHeader.refCount;

            // We return locked files even if they expired, GC doesnt collect them too so they valuable to user
            // Satisfy Req.#1.2
            if (![self isDataCanBeReturnedWithHeader:&localHeader]) {
#ifdef DEBUG_OUTPUT_ENABLED
                [self debugOutput:@"PersistentDataCache: Record with key: %@ expired, t:%llu, TTL:%llu", key, localHeader.updateTimeSec, localHeader.ttl];
#endif
                [self dispatchEmptyResponseWithResult:SPTDataCacheResponseCodeNotFound callback:callback onQueue:queue];
                return;
            }

            // Check that payload is correct size
            if (localHeader.payloadSizeBytes != [rawData length] - kSPTPersistentRecordHeaderSize) {
                [self debugOutput:@"PersistentDataCache: Error: Wrong payload size for key:%@ , will return error", key];
                [self dispatchError:[self nsErrorWithCode:SPTDataCacheLoadingErrorWrongPayloadSize]
                             result:SPTDataCacheResponseCodeOperationError
                           callback:callback onQueue:queue];
                return;
            }

            NSRange payloadRange = NSMakeRange(kSPTPersistentRecordHeaderSize, localHeader.payloadSizeBytes);
            NSData *payload = [rawData subdataWithRange:payloadRange];
            const NSUInteger ttl = localHeader.ttl;


            SPTDataCacheRecord *record = [[SPTDataCacheRecord alloc] initWithData:payload
                                                                              key:key
                                                                         refCount:refCount
                                                                              ttl:ttl];

            SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationSucceeded
                                                                                                error:nil
                                                                                               record:record];
            // If data ttl == 0 we update access time
            if (ttl == 0) {
                localHeader.updateTimeSec = spt_uint64rint(self.currentTime());
                localHeader.crc = pdc_CalculateHeaderCRC(&localHeader);
                memcpy(header, &localHeader, sizeof(localHeader));

                // Write back with updated access attributes
                NSError *werror = nil;
                if (![rawData writeToFile:filePath options:NSDataWritingAtomic error:&werror]) {
                    [self debugOutput:@"PersistentDataCache: Error writing back record:%@, error:%@", filePath.lastPathComponent, werror];
                } else {
#ifdef DEBUG_OUTPUT_ENABLED
                    [self debugOutput:@"PersistentDataCache: Writing back record:%@ OK", filePath.lastPathComponent];
#endif
                }
            }

            // Callback only after we finished everyhing to avoid situation when user gets notified and we are still writting
            dispatch_async(queue, ^{
                callback(response);
            });

        } // if rawData
    } // file exist
}

/**
 * Store method used internaly. Called on work queue.
 */
- (NSError *)storeDataSync:(NSData *)data
                    forKey:(NSString *)key
                       ttl:(NSUInteger)ttl
                    locked:(BOOL)locked
              withCallback:(SPTDataCacheResponseCallback)callback
                   onQueue:(dispatch_queue_t)queue
{
    NSString *filePath = [self pathForKey:key];

    NSString *subDir = [self subDirectoryPathForKey:key];
    [self.fileManager createDirectoryAtPath:subDir withIntermediateDirectories:YES attributes:nil error:nil];

    uint32_t __block oldRefCount = 0;
    const NSUInteger payloadLen = [data length];
    const NSUInteger rawdataLen = kSPTPersistentRecordHeaderSize + payloadLen;

    NSMutableData *rawData = [NSMutableData dataWithCapacity:rawdataLen];

    SPTPersistentRecordHeaderType dummy;
    memset(&dummy, 0, kSPTPersistentRecordHeaderSize);
    SPTPersistentRecordHeaderType *header = &dummy;

    header->magic = kSPTPersistentDataCacheMagic;
    header->headerSize = kSPTPersistentRecordHeaderSize;
    header->refCount = oldRefCount + (locked ? 1 : 0);
    header->ttl = ttl;
    header->payloadSizeBytes = payloadLen;
    header->updateTimeSec = spt_uint64rint(self.currentTime());
    header->crc = pdc_CalculateHeaderCRC(header);

    [rawData appendBytes:&dummy length:kSPTPersistentRecordHeaderSize];
    [rawData appendData:data];

    NSError *error = nil;

    if (![rawData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        [self debugOutput:@"PersistentDataCache: Error writting to file:%@ , for key:%@. Removing it...", filePath, key];
        [self removeDataForKeysSync:@[key]];
        [self dispatchError:error result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];

    } else {

        if (callback != nil) {
            SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationSucceeded
                                                                                                error:nil
                                                                                               record:nil];

            dispatch_async(queue, ^{
                callback(response);
            });
        }
    }

    return error;
}

/**
 * Method to work safely with opened file referenced by file descriptor. 
 * Method handles file closing properly in case of errors.
 * Descriptor is passed to a jobBlock for further usage.
 */
- (SPTPersistentCacheResponse *)guardOpenFileWithPath:(NSString *)filePath
                                             jobBlock:(FileProcessingBlockType)jobBlock
                                             complain:(BOOL)needComplains
                                            writeBack:(BOOL)writeBack
{
    assert(jobBlock != nil);
    if (jobBlock == nil) {
        return nil;
    }

    if (![self.fileManager fileExistsAtPath:filePath]) {
        if (needComplains) {
            [self debugOutput:@"PersistentDataCache: Record not exist at path:%@", filePath];
        }
        return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeNotFound error:nil record:nil];

    } else {
        const int flags = (writeBack ? O_RDWR : O_RDONLY);

        int fd = open([filePath UTF8String], flags);
        if (fd == -1) {
            const int errn = errno;
            NSString *serr = @(strerror(errn));
            [self debugOutput:@"PersistentDataCache: Error opening file:%@ , error:%@", filePath, serr];
            NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: serr}];
            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];
        }

        SPTPersistentCacheResponse *response = jobBlock(fd);

        fd = close(fd);
        if (fd == -1) {
            const int errn = errno;
            NSString *serr = @(strerror(errn));
            [self debugOutput:@"PersistentDataCache: Error closing file:%@ , error:%@", filePath, serr];
            NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: serr}];
            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];
        }

        return response;
    }
}

/**
 * Method used to read/write file header.
 */
- (SPTPersistentCacheResponse *)alterHeaderForFileAtPath:(NSString *)filePath
                                               withBlock:(RecordHeaderGetCallbackType)modifyBlock
                                               writeBack:(BOOL)needWriteBack
                                                complain:(BOOL)needComplains
{
    assert(modifyBlock != nil);
    if (modifyBlock == nil) {
        return nil;
    }

    return [self guardOpenFileWithPath:filePath jobBlock:^SPTPersistentCacheResponse*(int filedes) {

        SPTPersistentRecordHeaderType header;
        ssize_t readBytes = read(filedes, &header, kSPTPersistentRecordHeaderSize);
        if (readBytes != kSPTPersistentRecordHeaderSize) {
            NSError *error = [self nsErrorWithCode:SPTDataCacheLoadingErrorNotEnoughDataToGetHeader];
            if (readBytes == -1) {
                const int errn = errno;
                const char* serr = strerror(errn);
                error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: @(serr)}];
            }

            [self debugOutput:@"PersistentDataCache: Error not enough data to read the header of file path:%@ , error:%@",
             filePath, [error localizedDescription]];

            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];
        }

        NSError *nsError = [self checkHeaderValid:&header];
        if (nsError != nil) {
            [self debugOutput:@"PersistentDataCache: Error checking header at file path:%@ , error:%@", filePath, nsError];
            return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:nsError record:nil];
        }

        modifyBlock(&header);

        if (needWriteBack) {

            uint32_t oldCRC = header.crc;
            header.crc = pdc_CalculateHeaderCRC(&header);

            // If nothing has changed we do nothing then
            if (oldCRC == header.crc) {
                return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationSucceeded error:nil record:nil];
            }

            // Set file pointer to the beginning of the file
            off_t ret = lseek(filedes, SEEK_SET, 0);
            if (ret != 0) {
                const int errn = errno;
                NSString *serr = @(strerror(errn));
                [self debugOutput:@"PersistentDataCache: Error seeking to begin of file path:%@ , error:%@", filePath, serr];
                NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: serr}];
                return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];

            } else {
                ssize_t writtenBytes = write(filedes, &header, kSPTPersistentRecordHeaderSize);
                if (writtenBytes != kSPTPersistentRecordHeaderSize) {
                    const int errn = errno;
                    NSString *serr = @(strerror(errn));
                    [self debugOutput:@"PersistentDataCache: Error writting header at file path:%@ , error:%@", filePath, serr];
                    NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: serr}];
                    return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];

                } else {
                    int result = fsync(filedes);
                    if (result == -1) {
                        const int errn = errno;
                        NSString *serr = @(strerror(errn));
                        [self debugOutput:@"PersistentDataCache: Error flushing file:%@ , error:%@", filePath, serr];
                        NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: serr}];
                        return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationError error:error record:nil];
                    }
                }
            }
        }

        return [[SPTPersistentCacheResponse alloc] initWithResult:SPTDataCacheResponseCodeOperationSucceeded error:nil record:nil];
    }
                              complain:needComplains
                             writeBack:needWriteBack];
}

/**
 * 2 letter separation is handled only by this method. All other code is agnostic to this fact.
 */
- (NSString *)subDirectoryPathForKey:(NSString *)key
{
    // make folder tree: xx/  zx/  xy/  yz/ etc.
    NSString *subDir = self.options.cachePath;

    if (self.options.folderSeparationEnabled && [key length] >= 2) {
        subDir = [self.options.cachePath stringByAppendingPathComponent:[key substringToIndex:2]];
    }

    return subDir;
}

- (NSString *)pathForKey:(NSString *)key
{
    NSString *subDir = [self subDirectoryPathForKey:key];
    return [subDir stringByAppendingPathComponent:key];
}

- (NSError *)nsErrorWithCode:(SPTDataCacheLoadingError)errorCode
{
    return [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                               code:errorCode
                           userInfo:nil];
}

- (NSError *)checkHeaderValid:(SPTPersistentRecordHeaderType *)header
{
    int code = pdc_ValidateHeader(header);
    if (code == -1) { // No error
        return nil;
    }
    
    return [self nsErrorWithCode:code];
}

/**
 * Only this method check data expiration. Past check is also supported.
 */
- (BOOL)isDataExpiredWithHeader:(SPTPersistentRecordHeaderType *)header
{
    assert(header != nil);
    uint64_t ttl = header->ttl;
    uint64_t current = spt_uint64rint(self.currentTime());
    int64_t threshold = (int64_t)((ttl > 0) ? ttl : self.options.defaultExpirationPeriodSec);

    if (ttl > kTTLUpperBoundInSec) {
        [self debugOutput:@"PersistentDataCache: WARNING: TTL seems too big: %llu > %llu sec", ttl, kTTLUpperBoundInSec];
    }

    return (int64_t)(current - header->updateTimeSec) > threshold;
}

/**
 * Methos checks whether data can be given to caller with accordance to API.
 */
- (BOOL)isDataCanBeReturnedWithHeader:(SPTPersistentRecordHeaderType *)header
{
    return !([self isDataExpiredWithHeader:header] && header->refCount == 0);
}

- (void)runRegularGC
{
    [self collectGarbageForceExpire:NO forceLocked:NO];
}

/**
 * forceExpire = YES treat all unlocked files like they expired
 * forceLocked = YES ignore lock status
 */
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
                if (![self.busyKeys containsObject:key]) {

                    NSString *filePath = [self pathForKey:key];

                    BOOL __block needRemove = NO;
                    int __block reason = 0;
                    // WARNING: We may skip return result here bcuz in that case we won't remove file we do not know what is it
                    [self alterHeaderForFileAtPath:filePath
                                         withBlock:^(SPTPersistentRecordHeaderType *header) {

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
                                                 needRemove = (![self isDataCanBeReturnedWithHeader:header]);
                                                 reason = 4;
                                             }

                                         } writeBack:NO
                                          complain:YES];

                    if (needRemove) {
                        [self debugOutput:@"PersistentDataCache: gc removing record: %@, reason:%d", filePath.lastPathComponent, reason];

                        NSError *error= nil;
                        if (![self.fileManager removeItemAtPath:filePath error:&error]) {
                            [self debugOutput:@"PersistentDataCache: GC error removing record:%@ ,error:%@", filePath.lastPathComponent, error];
                        }
                    }
                }
            } // is dir
        } else {
            [self debugOutput:@"Unable to fetch isDir#4 attribute:%@", theURL];
        }
    } // for
}

- (void)cleanCacheData
{
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
                if (![self.busyKeys containsObject:key]) {
                    NSString *filePath = [self pathForKey:key];
                    NSError *error = nil;
                    if (![self.fileManager removeItemAtPath:filePath error:&error]) {
                        [self debugOutput:@"PersistentDataCache: Error cleaning record: %@ , %@", filePath.lastPathComponent, error];
                    }
                }
            }
        }
    }
}

- (void)dispatchEmptyResponseWithResult:(SPTDataCacheResponseCode)result
                               callback:(SPTDataCacheResponseCallback)callback
                                onQueue:(dispatch_queue_t)queue
{
    if (callback != nil) {
        SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:result
                                                                                            error:nil
                                                                                           record:nil];
        dispatch_async(queue, ^{
            callback(response);
        });
    }
}

- (void)dispatchError:(NSError *)error
               result:(SPTDataCacheResponseCode)result
             callback:(SPTDataCacheResponseCallback)callback
              onQueue:(dispatch_queue_t)queue
{
    if (callback != nil) {
        SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:result
                                                                                            error:error
                                                                                           record:nil];
        dispatch_async(queue, ^{
            callback(response);
        });
    }
}

- (NSUInteger)getFileSizeAtPath:(NSString *)filePath
{
    NSError *error = nil;
    NSDictionary *attrs = [self.fileManager attributesOfItemAtPath:filePath error:&error];
    if (attrs == nil) {
        [self debugOutput:@"PersistentDataCache: Error getting attributes for file: %@, error: %@", filePath, error];
    }
    return [attrs fileSize];
}

- (void)debugOutput:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
    va_list list;
    va_start(list, format);
    NSString * str = [[NSString alloc ] initWithFormat:format arguments:list];
    va_end(list);
    if (self.debugOutput) {
        self.debugOutput(str);
    }
}

- (void)pruneBySize
{
    if (self.options.sizeConstraintBytes == 0) {
        return;
    }

    // Find all the image names and attributes and sort oldest last
    NSMutableArray *images = [self storedImageNamesAndAttributes];

    // Find the free space on the disk
    SPTDiskSizeType currentCacheSize = (SPTDiskSizeType)[self lockedItemsSizeInBytes];
    for (NSDictionary *image in images) {
        currentCacheSize += [image[SPTDataCacheFileAttributesKey][NSFileSize] integerValue];
    }

    SPTDiskSizeType optimalCacheSize = [self optimalSizeForCache:currentCacheSize];

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
}

- (SPTDiskSizeType)optimalSizeForCache:(SPTDiskSizeType)currentCacheSize
{
    SPTDiskSizeType tempCacheSize = (SPTDiskSizeType)self.options.sizeConstraintBytes;

    NSError *error = nil;
    NSDictionary *fileSystemAttributes = [self.fileManager attributesOfFileSystemForPath:self.options.cachePath
                                                                                   error:&error];
    if (fileSystemAttributes) {
        // Never use the last SPTImageLoaderMinimumFreeDiskSpace of the disk for caching
        NSNumber *fileSystemSize = fileSystemAttributes[NSFileSystemSize];
        NSNumber *fileSystemFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];

        SPTDiskSizeType totalSpace = fileSystemSize.longLongValue;
        SPTDiskSizeType freeSpace = fileSystemFreeSpace.longLongValue + currentCacheSize;
        SPTDiskSizeType proposedCacheSize = freeSpace - llrint(totalSpace * SPTDataCacheMinimumFreeDiskSpace);

        tempCacheSize = MAX(0, proposedCacheSize);

    } else {
        [self debugOutput:@"PersistentDataCache: %@ ERROR %@", @(__PRETTY_FUNCTION__), [error localizedDescription]];
    }

    return MIN(tempCacheSize, (SPTDiskSizeType)self.options.sizeConstraintBytes);
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

                // Here we skip streams
                NSString *key = [NSString stringWithUTF8String:theURL.fileSystemRepresentation].lastPathComponent;
                // That satisfies Req.#1.3
                if ([self.busyKeys containsObject:key]) {
                    continue;
                }

                // WARNING: We may skip return result here bcuz in that case we will remove unknown file as unlocked trash
                [self alterHeaderForFileAtPath:[NSString stringWithUTF8String:theURL.fileSystemRepresentation]
                                     withBlock:^(SPTPersistentRecordHeaderType *header) {
                                         locked = (header->refCount > 0);
                                     } writeBack:NO
                                      complain:YES];

                if (locked) {
                    continue;
                }

                /* We use this since this is most reliable method to get file info and URL stuff fails sometimes
                 which is described in apple doc and its our case here */

                struct stat fileStat;
                int ret = stat([theURL fileSystemRepresentation], &fileStat);
                if (ret == -1)
                    continue;

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

// That satisfies Req.#1.3
- (BOOL)processKeyIfBusy:(NSString *)key callback:(SPTDataCacheResponseCallback)callback queue:(dispatch_queue_t)queue
{
    if ([self.busyKeys containsObject:key]) {
        NSError *nsError = [self nsErrorWithCode:SPTDataCacheLoadingErrorRecordIsStreamAndBusy];
        [self dispatchError:nsError result:SPTDataCacheResponseCodeOperationError callback:callback onQueue:queue];
        return YES;
    }

    return NO;
}

@end

NS_INLINE BOOL PointerMagicAlignCheck(const void *ptr)
{
    const unsigned align = _Alignof(MagicType);
    uint64_t v = (uint64_t)(ptr);
    assert(v%align == 0);
    return (v%align == 0);
}

SPTPersistentRecordHeaderType *pdc_GetHeaderFromData(void *data, size_t size)
{
    if (size < kSPTPersistentRecordHeaderSize) {
        return NULL;
    }

    return (SPTPersistentRecordHeaderType *)data;
}

int /*SPTDataCacheLoadingError*/ pdc_ValidateHeader(const SPTPersistentRecordHeaderType *header)
{
    assert(header != NULL);
    if (header == NULL) {
        return SPTDataCacheLoadingErrorInternalInconsistency;
    }

    // Check that header could be read according to alignment
    if (!PointerMagicAlignCheck(header)) {
        return SPTDataCacheLoadingErrorHeaderAlignmentMismatch;
    }

    // 1. Check magic
    if (header->magic != kSPTPersistentDataCacheMagic) {
        return SPTDataCacheLoadingErrorMagicMismatch;
    }

    // 2. Check CRC
    uint32_t crc = pdc_CalculateHeaderCRC(header);
    if (crc != header->crc) {
        return SPTDataCacheLoadingErrorInvalidHeaderCRC;
    }

    // 3. Check header size
    if (header->headerSize != kSPTPersistentRecordHeaderSize) {
        return SPTDataCacheLoadingErrorWrongHeaderSize;
    }

    return -1;
}

uint32_t pdc_CalculateHeaderCRC(const SPTPersistentRecordHeaderType *header)
{
    assert(header != NULL);
    if (header == NULL) {
        return 0;
    }

    return spt_crc32((const uint8_t *)header, kSPTPersistentRecordHeaderSize - sizeof(header->crc));
}
