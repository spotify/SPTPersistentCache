// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

#import <SPTPersistentCache/SPTPersistentCacheImplementation.h>

/**
 Category to instantiate NSError objects with a specific domain for SPTPersistentCache.
 */
@interface NSError (SPTPersistentCacheDomainErrors)

/**
 Returns a new instance of NSError with a SPTPersistentCache domain and an error code.
 @param persistentDataCacheLoadingError The error code for the NSError object.
 */
+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentCacheLoadingError)persistentDataCacheLoadingError;

@end
