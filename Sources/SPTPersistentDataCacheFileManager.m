#import "SPTPersistentDataCacheFileManager.h"
#import "SPTPersistentDataCacheOptions.h"

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
