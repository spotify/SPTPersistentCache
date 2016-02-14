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

@class SPTPersistentDataCache;

@interface SPTPersistentDataCacheTimerProxy : NSObject

/**
 *  Persistent Data Cache that will be used for garbage collection operations.
 */
@property (nonatomic, weak, readonly) SPTPersistentDataCache *dataCache;

/**
 *  Dispatch queue where the operations will take place.
 */
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

/**
 *  Initializes the timer proxy on a specific queue using a specific data cache.
 *  
 *  @param dataCache Persistent Data Cache that will be used for garbage collection operations.
 *  @param queue Dispatch queue where the operations will take place.
 */
- (instancetype)initWithDataCache:(SPTPersistentDataCache *)dataCache
                            queue:(dispatch_queue_t)queue;

- (void)enqueueGC:(NSTimer *)timer;

@end
