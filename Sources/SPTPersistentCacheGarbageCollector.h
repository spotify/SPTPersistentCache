// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

@class SPTPersistentCache;
@class SPTPersistentCacheOptions;

@interface SPTPersistentCacheGarbageCollector : NSObject

/**
 Persistent Cache that will be used for garbage collection operations.
 */
@property (nonatomic, weak, readonly) SPTPersistentCache *cache;

/**
 Dispatch queue where the operations will take place.
 */
@property (nonatomic, strong, readonly) NSOperationQueue *queue;

/**
 Returns YES if the internal timer of proxy is scheduled to perform garbage collection of the cache.
 */
@property (nonatomic, readonly, getter=isGarbageCollectionScheduled) BOOL garbageCollectionScheduled;

/**
 Initializes the timer proxy on a specific queue using a specific data cache.

 @param cache Persistent Cache that will be used for garbage collection operations.
 @param options Cache options to configure this garbage collector.
 @param queue NSOperation queue where the operations will take place.
 */
- (instancetype)initWithCache:(SPTPersistentCache *)cache
                      options:(SPTPersistentCacheOptions *)options
                        queue:(NSOperationQueue *)queue;

/**
 Schedules the garbage collection operation.

 @warning The owner of the reference to this object should call 
 unscheduleGarbageCollection on its dealloc method to prevent a retain cycle 
 caused by an internal timer.
 */
- (void)schedule;

/**
 Unschedules the garbage collection operation.

 @warning Ensure the garbage collector is unscheduled to break the retain
 cycle that could be caused by the internal timer in this class.
 */
- (void)unschedule;

@end
