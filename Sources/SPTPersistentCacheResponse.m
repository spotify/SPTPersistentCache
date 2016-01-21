#import "SPTPersistentCacheResponse.h"

@interface SPTPersistentCacheResponse ()

@property (nonatomic, assign, readwrite) SPTDataCacheResponseCode result;
@property (nonatomic, strong, readwrite) NSError *error;
@property (nonatomic, strong, readwrite) SPTDataCacheRecord *record;

@end

@implementation SPTPersistentCacheResponse

- (instancetype)initWithResult:(SPTDataCacheResponseCode)result
                         error:(NSError *)error
                        record:(SPTDataCacheRecord *)record
{
    if (!(self = [super init])) {
        return nil;
    }

    _result = result;
    _error = error;
    _record = record;

    return self;
}

@end