#import "SPTDataCacheRecord.h"

@interface SPTDataCacheRecord (Private)

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    refCount:(NSUInteger)refCount
                         ttl:(NSUInteger)ttl;

@end
