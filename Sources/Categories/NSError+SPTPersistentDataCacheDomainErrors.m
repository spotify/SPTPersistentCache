#import "NSError+SPTPersistentDataCacheDomainErrors.h"


@implementation NSError (SPTPersistentDataCacheDomainErrors)

+ (instancetype)spt_errorWithCode:(SPTPersistentDataCacheLoadingError)errorCode
{
    return [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                               code:errorCode
                           userInfo:nil];
}

@end
