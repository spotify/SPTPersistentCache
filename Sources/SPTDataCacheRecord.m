#import "SPTDataCacheRecord.h"

@implementation SPTDataCacheRecord

#pragma mark SPTDataCacheRecord

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    refCount:(NSUInteger)refCount
                         ttl:(NSUInteger)ttl
{
    if (!(self = [super init])) {
        return nil;
    }

    _refCount = refCount;
    _ttl = ttl;
    _key = key;
    _data = data;

    return self;
}

@end
