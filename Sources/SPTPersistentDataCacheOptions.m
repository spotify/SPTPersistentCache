#import "SPTPersistentDataCacheOptions.h"

const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec = 10 * 60;
const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec = 6 * 60 + 3;

#pragma mark SPTPersistentDataCacheOptions

@implementation SPTPersistentDataCacheOptions

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationTimeSec;
    _gcIntervalSec = SPTPersistentDataCacheDefaultGCIntervalSec;
    _folderSeparationEnabled = YES;
    
    return self;
}

@end