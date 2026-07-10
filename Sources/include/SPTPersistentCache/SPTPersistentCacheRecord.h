// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 @brief SPTPersistentCacheRecord
 @discussion Class defines one record in cache that is returned in response.
             Each record is represented by single file on disk.
             If file deleted from disk then cache assumes its never existed and return 
             `SPTPersistentCacheResponseCodeNotFound` for load call.
 */
@interface SPTPersistentCacheRecord : NSObject

/*
 Defines the number of times external logical references to this cache item. Initially is 0 if locked flag on store is NO.
 Files with refCount > 0 is considered as locked by GC procedure. They also returned on load call regardless of expiration.
 */
@property (nonatomic, assign, readonly) NSUInteger refCount;
/**
 Defines ttl for given record if applicable. 0 means not applicable.
 */
@property (nonatomic, assign, readonly) NSUInteger ttl;
/**
 Key for that record.
 */
@property (nonatomic, copy, readonly) NSString *key;
/*
 Data that was initially passed into storeData:...
 */
@property (nonatomic, strong, readonly) NSData *data;

@end

NS_ASSUME_NONNULL_END
