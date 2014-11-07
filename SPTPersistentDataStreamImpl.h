#import <Foundation/Foundation.h>
#import "SPTPersistentDataStream.h"
#import "SPTPersistentDataHeader.h"
#import "SPTPersistentCacheTypes.h"

typedef dispatch_block_t CleanupHeandlerCallback;

@interface SPTPersistentDataStreamImpl : NSObject <SPTPersistentDataStream>

- (instancetype)initWithPath:(NSString *)filePath
                         key:(NSString *)key
                cleanupQueue:(dispatch_queue_t)cleanupQueue
              cleanupHandler:(CleanupHeandlerCallback)cleanupHandler
               debugCallback:(SPTDataCacheDebugCallback)debugCalback;

- (NSError *)open;

@end
