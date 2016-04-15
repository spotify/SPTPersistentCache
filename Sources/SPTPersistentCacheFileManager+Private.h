#import "SPTPersistentCacheFileManager.h"
#import <SPTPersistentCache/SPTPersistentCacheOptions.h>

NS_ASSUME_NONNULL_BEGIN

/// Private interface exposed for testability.
@interface SPTPersistentCacheFileManager ()

@property (nonatomic, copy, readonly) SPTPersistentCacheOptions *options;
@property (nonatomic, copy, readonly, nullable) SPTPersistentCacheDebugCallback debugOutput;
@property (nonatomic, strong, readonly) NSFileManager *fileManager;

@end

NS_ASSUME_NONNULL_END
