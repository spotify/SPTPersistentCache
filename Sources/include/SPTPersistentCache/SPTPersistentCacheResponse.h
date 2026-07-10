// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

@class SPTPersistentCacheRecord;

NS_ASSUME_NONNULL_BEGIN

/**
 The SPTPersistentCacheResponseCode enum defines constants that is used to identify what kind of response would be
 given in callback to loadDataForKey:withCallback: method.
 */
typedef NS_ENUM(NSInteger, SPTPersistentCacheResponseCode) {
    /**
     Indicates success of requested operation with data. The record field of SPTPersistentCacheResponse mustn't be nil
     if it was load operation otherwise it could be. The error would be nil.
     */
    SPTPersistentCacheResponseCodeOperationSucceeded,
    /**
     Indicates that no file found for given key in cache or is expired. The record and error field of
     SPTPersistentCacheResponse is nil in this case.
     */
    SPTPersistentCacheResponseCodeNotFound,
    /**
     Indicates error occured during requested operation. The record field of SPTPersistentCacheResponse would be nil.
     The error mustn't be nil and specify exact error.
     */
    SPTPersistentCacheResponseCodeOperationError
};

/**
 @brief SPTPersistentCacheResponse
 @discussion Class defines one response passed in callback to call loadDataForKey:
 */
@interface SPTPersistentCacheResponse : NSObject

/**
 The result of the cache request.
 @seealso SPTPersistentCacheResponseCode
 */
@property (nonatomic, assign, readonly) SPTPersistentCacheResponseCode result;
/**
 Defines error of response, if applicable.
 */
@property (nonatomic, strong, readonly, nullable) NSError *error;
/**
 The record of the cached data, if found.
 @seealso SPTPersistentCacheRecord
 */
@property (nonatomic, strong, readonly, nullable) SPTPersistentCacheRecord *record;

@end

NS_ASSUME_NONNULL_END
