#import <Foundation/Foundation.h>

#import "SPTPersistentDataStream.h"
#import "SPTPersistentDataHeader.h"
#import "SPTPersistentCacheTypes.h"
#import "SPTPersistentDataCacheOptions.h"

typedef dispatch_block_t CleanupHeandlerCallback;

@interface SPTPersistentDataStreamImpl : NSObject <SPTPersistentDataStream>

- (instancetype)initWithPath:(NSString *)filePath
                         key:(NSString *)key
              cleanupHandler:(CleanupHeandlerCallback)cleanupHandler
               debugCallback:(SPTDataCacheDebugCallback)debugCalback;

- (void)open:(SPTDataCacheStreamCallback)callback;

@end
