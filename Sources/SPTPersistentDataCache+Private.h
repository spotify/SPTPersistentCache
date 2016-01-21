#import "SPTPersistentDataCache.h"

@interface SPTPersistentDataCache (Private)

- (void)runRegularGC;
- (void)pruneBySize;

@end
