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

#pragma mark - Constants

const NSUInteger SPTPersistentCacheDefaultExpirationTimeSec = 10 * 60;
const NSUInteger SPTPersistentCacheDefaultGCIntervalSec = 6 * 60 + 3;
const NSUInteger SPTPersistentCacheDefaultCacheSizeInBytes = 0; // unbounded

const NSUInteger SPTPersistentCacheMinimumGCIntervalLimit = 60;
const NSUInteger SPTPersistentCacheMinimumExpirationLimit = 60;


#pragma mark Helper Functions

static NSUInteger SPTGuardedPropertyValue(NSUInteger proposedValue, NSUInteger minimumValue, SEL propertySelector, SPTPersistentCacheDebugCallback debugCallback);


#pragma mark - SPTPersistentCacheOptions Implementation

@implementation SPTPersistentCacheOptions

#pragma mark Object Life Cycle

- (instancetype)init
{
    self = [super init];

    if (self) {
        _cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/com.spotify.temppersistent.image.cache"];
        _cacheIdentifier = @"persistent.cache";
        _useDirectorySeparation = YES;

        _garbageCollectionInterval = SPTPersistentCacheDefaultGCIntervalSec;
        _defaultExpirationPeriod = SPTPersistentCacheDefaultExpirationTimeSec;
        _sizeConstraintBytes = SPTPersistentCacheDefaultCacheSizeInBytes;
        _maxConcurrentOperations = NSOperationQueueDefaultMaxConcurrentOperationCount;
        _writePriority = NSOperationQueuePriorityNormal;
        _writeQualityOfService = NSQualityOfServiceDefault;
        _readPriority = NSOperationQueuePriorityNormal;
        _readQualityOfService = NSQualityOfServiceDefault;
        _deletePriority = NSOperationQueuePriorityNormal;
        _deleteQualityOfService = NSQualityOfServiceDefault;
        _garbageCollectionPriority = NSOperationQueuePriorityLow;
        _garbageCollectionQualityOfService = NSQualityOfServiceBackground;
    }

    return self;
}

#pragma mark Queue Management Options

- (NSString *)identifierForQueue
{
    return [NSString stringWithFormat:@"%@.queue.%lu.%lu.%p",
            self.cacheIdentifier,
            (unsigned long)self.garbageCollectionInterval,
            (unsigned long)self.defaultExpirationPeriod,
            (void *)self];
}

#pragma mark Garbage Collection Options

- (void)setGarbageCollectionInterval:(NSUInteger)garbageCollectionInterval
{
    if (_garbageCollectionInterval == garbageCollectionInterval) {
        return;
    }
    _garbageCollectionInterval = SPTGuardedPropertyValue(garbageCollectionInterval,
                                                         SPTPersistentCacheMinimumGCIntervalLimit,
                                                         @selector(garbageCollectionInterval),
                                                         self.debugOutput);
}

- (void)setDefaultExpirationPeriod:(NSUInteger)defaultExpirationPeriod
{
    if (_defaultExpirationPeriod == defaultExpirationPeriod) {
        return;
    }
    _defaultExpirationPeriod = SPTGuardedPropertyValue(defaultExpirationPeriod,
                                                       SPTPersistentCacheMinimumExpirationLimit,
                                                       @selector(defaultExpirationPeriod),
                                                       self.debugOutput);
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    SPTPersistentCacheOptions * const copy = [[self.class allocWithZone:zone] init];

    copy.cacheIdentifier = self.cacheIdentifier;
    copy.cachePath = self.cachePath;
    copy.useDirectorySeparation = self.useDirectorySeparation;

    copy.garbageCollectionInterval = self.garbageCollectionInterval;
    copy.defaultExpirationPeriod = self.defaultExpirationPeriod;
    copy.sizeConstraintBytes = self.sizeConstraintBytes;

    copy.debugOutput = self.debugOutput;
    copy.timingCallback = self.timingCallback;

    return copy;
}

#pragma mark Describing an Object

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
                                               @(self.useDirectorySeparation), @"use-directory-separation",
                                               @(self.garbageCollectionInterval), @"garbage-collection-interval",
                                               @(self.defaultExpirationPeriod), @"default-expiration-period",
                                               @(self.sizeConstraintBytes), @"size-constraint-bytes");
}

@end


@implementation SPTPersistentCacheOptions (Deprectated)

- (instancetype)initWithCachePath:(NSString *)cachePath
                       identifier:(NSString *)cacheIdentifier
        defaultExpirationInterval:(NSUInteger)defaultExpirationInterval
         garbageCollectorInterval:(NSUInteger)garbageCollectorInterval
                            debug:(nullable SPTPersistentCacheDebugCallback)debugCallback
{
    self = [self init];

    if (self) {
        _cachePath = [cachePath copy];
        _cacheIdentifier = [cacheIdentifier copy];

        _defaultExpirationPeriod = SPTGuardedPropertyValue(defaultExpirationInterval, SPTPersistentCacheMinimumExpirationLimit, @selector(defaultExpirationPeriod), debugCallback);
        _garbageCollectionInterval = SPTGuardedPropertyValue(garbageCollectorInterval, SPTPersistentCacheMinimumGCIntervalLimit, @selector(garbageCollectionInterval), debugCallback);

        _debugOutput = [debugCallback copy];
    }

    return self;
}

- (BOOL)folderSeparationEnabled
{
    return self.useDirectorySeparation;
}

- (void)setFolderSeparationEnabled:(BOOL)folderSeparationEnabled
{
    self.useDirectorySeparation = folderSeparationEnabled;
}

- (NSUInteger)gcIntervalSec
{
    return self.garbageCollectionInterval;
}

- (NSUInteger)defaultExpirationPeriodSec
{
    return self.defaultExpirationPeriod;
}

@end


static NSUInteger SPTGuardedPropertyValue(NSUInteger proposedValue, NSUInteger minimumValue, SEL propertySelector, SPTPersistentCacheDebugCallback debugCallback)
{
    if (proposedValue >= minimumValue) {
        return proposedValue;
    }

    SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Forcing \"%@\" to %lu seconds", NSStringFromSelector(propertySelector), (unsigned long)SPTPersistentCacheMinimumExpirationLimit], debugCallback);
    return minimumValue;
}
