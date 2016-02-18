#import "NSError+SPTPersistentCacheDomainErrors.h"


@implementation NSError (SPTPersistentCacheDomainErrors)

+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentCacheLoadingError)persistentDataCacheLoadingError
{
    return [NSError errorWithDomain:SPTPersistentCacheErrorDomain
                               code:persistentDataCacheLoadingError
                           userInfo:nil];
}

@end
