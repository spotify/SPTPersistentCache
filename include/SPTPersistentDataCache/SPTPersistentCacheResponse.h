#import <Foundation/Foundation.h>

#import "SPTPersistentCacheTypes.h"

@class SPTDataCacheRecord;

/**
 * @brief SPTPersistentCacheResponse
 *
 * @discussion Class defines one response passed in callback to call loadDataForKey:
 */
@interface SPTPersistentCacheResponse : NSObject

/**
 * @see SPTDataCacheResponseCode
 */
@property (nonatomic, assign, readonly) SPTDataCacheResponseCode result;
/**
 * Defines error of response if appliable
 */
@property (nonatomic, strong, readonly) NSError *error;
/**
 * @see SPTDataCacheRecord
 */
@property (nonatomic, strong, readonly) SPTDataCacheRecord *record;

@end