#import <Foundation/Foundation.h>
#import <SPTPersistentCache/SPTPersistentCacheTypes.h>


/**
 *  Category to instantiate NSError objects with a specific domain for SPTPersistentCache.
 */
@interface NSError (SPTPersistentCacheDomainErrors)
/**
 *  Returns a new instance of NSError with a SPTPersistentCache domain and an error code.
 *
 *  @param persistentDataCacheLoadingError The error code for the NSError object.
 */
+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentCacheLoadingError)persistentDataCacheLoadingError;


@end
