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
#import "SPTPersistentDataCacheOptions.h"

void SPTPersistentDataCacheOptionsDebug(NSString *debugMessage, SPTDataCacheDebugCallback debugCallback);

const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec = 10 * 60;
const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec = 6 * 60 + 3;
const NSUInteger SPTPersistentDataCacheDefaultCacheSizeInBytes = 0; // unbounded

const NSUInteger SPTPersistentDataCacheMinimumGCIntervalLimit = 60;
const NSUInteger SPTPersistentDataCacheMinimumExpirationLimit = 60;



#pragma mark SPTPersistentDataCacheOptions

@interface SPTPersistentDataCacheOptions ()
@property (nonatomic) NSString *identifierForQueue;
@property (nonatomic, copy) SPTDataCacheCurrentTimeSecCallback currentTimeSec;
@end


@implementation SPTPersistentDataCacheOptions

#pragma mark - Initializers

- (instancetype)init
{
    return [self initWithCachePath:nil
                        identifier:nil
               currentTimeCallback:nil
                             debug:nil];
}

- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
              currentTimeCallback:(SPTDataCacheCurrentTimeSecCallback)currentTimeBlock
                            debug:(SPTDataCacheDebugCallback)debugCallback
{
    return [self initWithCachePath:nil
                        identifier:nil
               currentTimeCallback:nil
         defaultExpirationInterval:SPTPersistentDataCacheDefaultExpirationTimeSec
          garbageCollectorInterval:SPTPersistentDataCacheDefaultGCIntervalSec
                             debug:nil];
}

- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
              currentTimeCallback:(SPTDataCacheCurrentTimeSecCallback)currentTimeBlock
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(SPTDataCacheDebugCallback)debugCallback
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _sizeConstraintBytes = SPTPersistentDataCacheDefaultCacheSizeInBytes;
    
    _cachePath = (cachePath ?
                  [cachePath copy] :
                  [NSTemporaryDirectory() stringByAppendingPathComponent:@"/com.spotify.temppersistent.image.cache"]);
    
    _cacheIdentifier = (cacheIdentifier ?
                        [cacheIdentifier copy] :
                        @"persistent.cache");
    
    _defaultExpirationPeriodSec = defaultExpirationInterval;
    _gcIntervalSec = garbageCollectorInterval;
    _folderSeparationEnabled = YES;
    
    _debugOutput = [debugCallback copy];
    
    self.currentTimeSec = (currentTimeBlock ?
                           currentTimeBlock :
                           ^NSTimeInterval() { return [[NSDate date] timeIntervalSince1970]; });
    
    if (defaultExpirationInterval < SPTPersistentDataCacheMinimumExpirationLimit) {
        SPTPersistentDataCacheOptionsDebug([NSString stringWithFormat:@"PersistentDataCache: Forcing defaultExpirationPeriodSec to %lu sec", (unsigned long)SPTPersistentDataCacheMinimumExpirationLimit],
                                            debugCallback);
        _defaultExpirationPeriodSec = SPTPersistentDataCacheMinimumExpirationLimit;
    } else {
        _defaultExpirationPeriodSec = defaultExpirationInterval;
    }
    
    if (garbageCollectorInterval < SPTPersistentDataCacheMinimumGCIntervalLimit) {
        SPTPersistentDataCacheOptionsDebug([NSString stringWithFormat:@"PersistentDataCache: Forcing gcIntervalSec to %lu sec", (unsigned long)SPTPersistentDataCacheMinimumGCIntervalLimit], debugCallback);
        _gcIntervalSec = SPTPersistentDataCacheMinimumGCIntervalLimit;
    } else {
        _gcIntervalSec = garbageCollectorInterval;
    }
    
    _identifierForQueue = [NSString stringWithFormat:@"%@.queue.%lu.%lu.%p", _cacheIdentifier,
                           (unsigned long)_gcIntervalSec, (unsigned long)_defaultExpirationPeriodSec, (void *)self];
    
    return self;
}

@end

#pragma mark - Logging

void SPTPersistentDataCacheOptionsDebug(NSString *debugMessage, SPTDataCacheDebugCallback debugCallback)
{
    if (debugCallback) {
        debugCallback(debugMessage);
    }
}
