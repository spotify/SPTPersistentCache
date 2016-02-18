#import <Foundation/Foundation.h>

typedef long long SPTPersistentDataCacheDiskSize;

extern const NSUInteger SPTPersistentDataCacheFileManagerSubDirNameLength;

@class SPTPersistentDataCacheOptions;


/**
 *  An object that encapsulates file-related operations of SPTPersistentDataCache.
 */
@interface SPTPersistentDataCacheFileManager : NSObject

@property (nonatomic, readonly) NSUInteger totalUsedSizeInBytes;

- (instancetype)init __unavailable;

/**
 *  Initializes a new file manager set with specific options. 
 *  
 *  @param options Options of the permanent cache.
 */
- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options;

/**
 *  Creates the directory that will be used to persist the cached data. Returns YES if the operation is successful, 
 *  Or NO otherwise.
 */
- (BOOL)createCacheDirectory;

/**
 *  Returns the path for the subdirectory containing the data associated to a specific key.
 *
 *  @param key Key of the data you are looking for.
 */
- (NSString *)subDirectoryPathForKey:(NSString *)key;

/**
 *  Returns the path for the data associated to a specific key.
 *
 *  @param key Key of the data you are looking for.
 */
- (NSString *)pathForKey:(NSString *)key;

/**
 *  Removes the associated cached file for a key.
 *  
 *  @param key Key of the data you are looking for.
 */
- (void)removeDataForKey:(NSString *)key;

- (SPTPersistentDataCacheDiskSize)optimizedDiskSizeForCacheSize:(SPTPersistentDataCacheDiskSize)currentCacheSize;

/**
 *  Returns the size of some data located at a specific path.
 *
 *  @param filePath Path of a specific file.
 */
- (NSUInteger)getFileSizeAtPath:(NSString *)filePath;

@end
