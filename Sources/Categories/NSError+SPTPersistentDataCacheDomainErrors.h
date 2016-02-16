#import <Foundation/Foundation.h>
#import <SPTPersistentDataCache/SPTPersistentDataCacheTypes.h>


/**
 *  Category to instantiate NSError objects with a specific domain for SPTPersistentDataCache.
 */
@interface NSError (SPTPersistentDataCacheDomainErrors)
/**
 *  Returns a new instance of NSError with a SPTPersistentDataCache domain and an error code.
 *
 *  @param persistentDataCacheLoadingError The error code for the NSError object.
 */
+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentDataCacheLoadingError)persistentDataCacheLoadingError;


@end
