#import <Foundation/Foundation.h>

@class SPTPersistentDataCache;

@interface SPTTimerProxy : NSObject

@property (nonatomic, weak) SPTPersistentDataCache *dataCache;
@property (nonatomic, strong) dispatch_queue_t queue;

- (void)enqueueGC:(NSTimer *)timer;

@end
