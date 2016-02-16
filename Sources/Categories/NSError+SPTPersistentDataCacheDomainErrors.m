#import "NSError+SPTPersistentDataCacheDomainErrors.h"


@implementation NSError (SPTPersistentDataCacheDomainErrors)

+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentDataCacheLoadingError)persistentDataCacheLoadingError
{
    return [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                               code:persistentDataCacheLoadingError
                           userInfo:nil];
}

@end
