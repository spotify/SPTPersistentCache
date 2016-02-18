#import "SPTPersistentDataCacheFileManager.h"
#import "SPTPersistentDataCacheOptions.h"


static const double SPTPersistentDataCacheFileManagerMinFreeDiskSpace = 0.1;

const NSUInteger SPTPersistentDataCacheFileManagerSubDirNameLength = 2;


@interface SPTPersistentDataCacheFileManager ()
@property (nonatomic, strong) SPTPersistentDataCacheOptions *options;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
@end

@implementation SPTPersistentDataCacheFileManager

#pragma mark - Initializer

- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options
{
    if (!(self = [super init ])) {
        return nil;
    }
    
    _options = options;
    _fileManager = [NSFileManager defaultManager];
    _debugOutput = options.debugOutput;
    
    return self;
}

#pragma mark -

- (BOOL)createCacheDirectory
{
    BOOL isDirectory = NO;
    
    BOOL didFileExist = [self.fileManager fileExistsAtPath:self.options.cachePath isDirectory:&isDirectory];
    if (didFileExist == NO) {
        NSError *error = nil;
        BOOL didCreateDirectory = [self.fileManager createDirectoryAtPath:self.options.cachePath
                                              withIntermediateDirectories:YES
                                                               attributes:nil
                                                                    error:&error];
        if (didCreateDirectory == NO) {
            [self debugOutput:@"PersistentDataCache: Unable to create dir: %@ with error:%@", self.options.cachePath, error];
            return NO;
        }
    }
    
    return YES;
}

/**
 * 2 letter separation is handled only by this method. All other code is agnostic to this fact.
 */
- (NSString *)subDirectoryPathForKey:(NSString *)key
{
    // make folder tree: xx/  zx/  xy/  yz/ etc.
    NSString *subDir = self.options.cachePath;
    
    if (self.options.folderSeparationEnabled &&
        [key length] >= SPTPersistentDataCacheFileManagerSubDirNameLength) {
        NSString *subDirectoryName = [key substringToIndex:SPTPersistentDataCacheFileManagerSubDirNameLength];
        subDir = [self.options.cachePath stringByAppendingPathComponent:subDirectoryName];
    }
    
    return subDir;
}

- (NSString *)pathForKey:(NSString *)key
{
    NSString *subDirectoryPathForKey = [self subDirectoryPathForKey:key];
    
    return [subDirectoryPathForKey stringByAppendingPathComponent:key];
}

- (void)removeDataForKey:(NSString *)key
{
    NSError *error = nil;
    
    NSString *filePath = [self pathForKey:key];
    
    if (![self.fileManager removeItemAtPath:filePath error:&error]) {
        [self debugOutput:@"PersistentDataCache: Error removing data for Key:%@ , error:%@", key, error];
    }
}

- (NSUInteger)getFileSizeAtPath:(NSString *)filePath
{
    NSError *error = nil;
    NSDictionary *attrs = [self.fileManager attributesOfItemAtPath:filePath error:&error];
    if (attrs == nil) {
        [self debugOutput:@"PersistentDataCache: Error getting attributes for file: %@, error: %@", filePath, error];
    }
    return (NSUInteger)[attrs fileSize];
}

- (NSUInteger)totalUsedSizeInBytes
{
    NSUInteger size = 0;
    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];
    
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {
        
        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {
                NSString *key = theURL.lastPathComponent;
                
                NSString *filePath = [self pathForKey:key];
                size += [self getFileSizeAtPath:filePath];
            }
        } else {
            [self debugOutput:@"Unable to fetch isDir#2 attribute:%@", theURL];
        }
    }
    
    return size;
}

- (SPTPersistentDataCacheDiskSize)optimizedDiskSizeForCacheSize:(SPTPersistentDataCacheDiskSize)currentCacheSize
{
    SPTPersistentDataCacheDiskSize tempCacheSize = (SPTPersistentDataCacheDiskSize)self.options.sizeConstraintBytes;
    
    NSError *error = nil;
    
    NSDictionary *fileSystemAttributes = [self.fileManager attributesOfFileSystemForPath:self.options.cachePath
                                                                                   error:&error];
    if (fileSystemAttributes) {
        // Never use the last SPTImageLoaderMinimumFreeDiskSpace of the disk for caching
        NSNumber *fileSystemSize = fileSystemAttributes[NSFileSystemSize];
        NSNumber *fileSystemFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];
        
        SPTPersistentDataCacheDiskSize totalSpace = fileSystemSize.longLongValue;
        SPTPersistentDataCacheDiskSize freeSpace = fileSystemFreeSpace.longLongValue + currentCacheSize;
        SPTPersistentDataCacheDiskSize proposedCacheSize = freeSpace - llrint(totalSpace *
                                                                              SPTPersistentDataCacheFileManagerMinFreeDiskSpace);
        
        tempCacheSize = MAX(0, proposedCacheSize);
        
    } else {
        [self debugOutput:@"PersistentDataCache: %@ ERROR %@", @(__PRETTY_FUNCTION__), [error localizedDescription]];
    }
    
    return MIN(tempCacheSize, (SPTPersistentDataCacheDiskSize)self.options.sizeConstraintBytes);
}

#pragma mark - Debugger

- (void)debugOutput:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
    va_list list;
    va_start(list, format);
    NSString * str = [[NSString alloc ] initWithFormat:format arguments:list];
    va_end(list);
    if (self.debugOutput) {
        self.debugOutput(str);
    }
}


@end
