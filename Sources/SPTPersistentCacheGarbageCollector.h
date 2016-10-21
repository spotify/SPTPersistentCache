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

@class SPTPersistentCache;
@class SPTPersistentCacheOptions;

@interface SPTPersistentCacheGarbageCollector : NSObject

/**
 *  Persistent Cache that will be used for garbage collection operations.
 */
@property (nonatomic, weak, readonly) SPTPersistentCache *cache;

/**
 *  Dispatch queue where the operations will take place.
 */
@property (nonatomic, strong, readonly) NSOperationQueue *queue;

/**
 *  Returns YES if the internal timer of proxy is scheduled to perform garbage collection of the cache.
 */
@property (nonatomic, readonly, getter=isGarbageCollectionScheduled) BOOL garbageCollectionScheduled;

/**
 *  Initializes the timer proxy on a specific queue using a specific data cache.
 *  
 *  @param cache Persistent Cache that will be used for garbage collection operations.
 *  @param options Cache options to configure this garbage collector.
 *  @param queue NSOperation queue where the operations will take place.
 */
- (instancetype)initWithCache:(SPTPersistentCache *)cache
                      options:(SPTPersistentCacheOptions *)options
                        queue:(NSOperationQueue *)queue;

/**
 *  Schedules the garbage collection operation.
 *
 *  @warning The owner of the reference to this object should call 
 *  unscheduleGarbageCollection on its dealloc method to prevent a retain cycle 
 *  caused by an internal timer.
 */
- (void)schedule;

/**
 *  Unschedules the garbage collection operation.
 *
 *  @warning Ensure the garbage collector is unscheduled to break the retain
 *  cycle that could be caused by the internal timer in this class.
 */
- (void)unschedule;

@end
