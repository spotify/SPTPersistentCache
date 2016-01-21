#import "SPTPersistentCacheResponse.h"

@interface SPTPersistentCacheResponse (Private)

- (instancetype)initWithResult:(SPTDataCacheResponseCode)result
                         error:(NSError *)error
                        record:(SPTDataCacheRecord *)record;

@end
