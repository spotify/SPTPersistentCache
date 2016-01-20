#import "SPTTimerProxy.h"

#import "SPTPersistentDataCache+Private.h"

@implementation SPTTimerProxy

- (void)enqueueGC:(NSTimer *)timer
{
    dispatch_barrier_async(self.queue, ^{
        [self.dataCache runRegularGC];
        [self.dataCache pruneBySize];
    });
}

@end
