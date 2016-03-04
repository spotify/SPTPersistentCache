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
#import "SPTPersistentCacheOptions.h"
#import "SPTPersistentCacheObjectDescription.h"
#import "SPTPersistentCacheDebugUtilities.h"


const NSUInteger SPTPersistentCacheDefaultExpirationTimeSec = 10 * 60;
const NSUInteger SPTPersistentCacheDefaultGCIntervalSec = 6 * 60 + 3;
const NSUInteger SPTPersistentCacheDefaultCacheSizeInBytes = 0; // unbounded

const NSUInteger SPTPersistentCacheMinimumGCIntervalLimit = 60;
const NSUInteger SPTPersistentCacheMinimumExpirationLimit = 60;



#pragma mark SPTPersistentCacheOptions

@interface SPTPersistentCacheOptions ()
@property (nonatomic) NSString *identifierForQueue;
@end


@implementation SPTPersistentCacheOptions

#pragma mark - Initializers

- (instancetype)init
{
    return [self initWithCachePath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"/com.spotify.temppersistent.image.cache"]
                        identifier:@"persistent.cache"
         defaultExpirationInterval:SPTPersistentCacheDefaultExpirationTimeSec
          garbageCollectorInterval:SPTPersistentCacheDefaultGCIntervalSec
                             debug:^(NSString *debugString) {
                                 NSLog(@"%@", debugString);
                             }];
}

- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(SPTPersistentCacheDebugCallback)debugCallback
{
    self = [super init];
    if (self) {
        _sizeConstraintBytes = SPTPersistentCacheDefaultCacheSizeInBytes;

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

        if (defaultExpirationInterval < SPTPersistentCacheMinimumExpirationLimit) {
            SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Forcing defaultExpirationPeriodSec to %lu sec", (unsigned long)SPTPersistentCacheMinimumExpirationLimit],
                                                debugCallback);
            _defaultExpirationPeriodSec = SPTPersistentCacheMinimumExpirationLimit;
        } else {
            _defaultExpirationPeriodSec = defaultExpirationInterval;
        }

        if (garbageCollectorInterval < SPTPersistentCacheMinimumGCIntervalLimit) {
            SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Forcing gcIntervalSec to %lu sec", (unsigned long)SPTPersistentCacheMinimumGCIntervalLimit], debugCallback);
            _gcIntervalSec = SPTPersistentCacheMinimumGCIntervalLimit;
        } else {
            _gcIntervalSec = garbageCollectorInterval;
        }

        _identifierForQueue = [NSString stringWithFormat:@"%@.queue.%lu.%lu.%p", _cacheIdentifier,
                               (unsigned long)_gcIntervalSec, (unsigned long)_defaultExpirationPeriodSec, (void *)self];
    }
    return self;
}

#pragma mark Describing Object

- (NSString *)description
{
    return SPTPersistentCacheObjectDescription(self, self.cacheIdentifier, @"cache-identifier");
}

- (NSString *)debugDescription
{
    return SPTPersistentCacheObjectDescription(self,
                                               self.cacheIdentifier, @"cache-identifier",
                                               self.cachePath, @"cache-path",
                                               self.identifierForQueue, @"identifier-for-queue",
                                               @(self.folderSeparationEnabled), @"folder-separation",
                                               @(self.gcIntervalSec), @"gc-interval-seconds",
                                               @(self.defaultExpirationPeriodSec), @"default-expiration-period-seconds",
                                               @(self.sizeConstraintBytes), @"size-constraint-bytes");
}

@end
