
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const SPTPersistentDataCacheErrorDomain;

/**
 * Default garbage collection interval. Some sane implementation defined value you should not care about.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec;

/**
 * Default exparation interval for all cache items. Particular record's TTL takes precedence over this value.
 * Items stored without (tt=0) TTL considered as expired if following is true: current_time - update_time > ExpInterval.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec;


/**
 @enum SPTDataCacheResponseCode

 @discussion The SPTDataCacheResponseCode enum defines constants that
             is used to identify what kind of response would be given in callback to
             loadDataForKey:withCallback: method.

 @constant PDC_DATA_LOADED Indicates that file have been found, been correct and data been loaded.
           record field of SPTPersistentCacheResponse mustn't be nil. error would be nil.

 @constant PDC_DATA_STORED Indicates that data was successfuly stored. error and record would be nil.

 @constant PDC_DATA_NOT_FOUND Indicates that no file found for given key in cache or is expired.
           record and error field of SPTPersistentCacheResponse is nil in this case.

 @constant PDC_DATA_LOADING_ERROR Indicates that file have been found but error occured during its loading.
           record field of SPTPersistentCacheResponse would be nil. error mustn't be nil and specify exact error.
 
 @constant PDC_DATA_STORE_ERROR Indicates that error occured while trying to store the data.
           record would be nil. error mustn't be nil and specify exact error.
 */
typedef NS_ENUM(NSInteger, SPTDataCacheResponseCode)
{
    PDC_DATA_LOADED,
    PDC_DATA_STORED,
    PDC_DATA_NOT_FOUND,
    PDC_DATA_LOADING_ERROR,
    PDC_DATA_STORE_ERROR
};


/**
 @enum SPTDataCacheLoadingError

 @discussion The SPTDataCacheLoadingError enum defines constants that
             identify NSError's in SPTPersistentDataCacheErrorDomain.

 @constant PDC_ERROR_MAGIC_MISSMATCH Magic number in record header is not as expected which means 
           file is not readable by this cache.

 @constant PDC_ERROR_HEADER_ALIGNMENT_MISSMATCH Alignment of pointer which casted to header
           is not compatible with alignment of first header field. This actually is insane but who knows.

 @constant PDC_ERROR_WRONG_HEADER_SIZE Size of header is not as expected. Possibly bcuz of version change.
 
 @constant PDC_ERROR_WRONG_PAYLOAD_SIZE Payload size in header is not the same as stored in cache record.
 
 @constant PDC_ERROR_INVALID_HEADER_CRC CRC calculated for reader and contained in header are different.
 
 @constant PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER Binary data size read as header is less then current header size
           which means we can't proceed further with this file.
 
 @constant PDC_ERROR_INTERNAL_INCONSISTENCY Something bad has happened that shouldn't.
 */
typedef NS_ENUM(NSInteger, SPTDataCacheLoadingError)
{
    PDC_ERROR_MAGIC_MISSMATCH = 100,
    PDC_ERROR_HEADER_ALIGNMENT_MISSMATCH,
    PDC_ERROR_WRONG_HEADER_SIZE,
    PDC_ERROR_WRONG_PAYLOAD_SIZE,
    PDC_ERROR_INVALID_HEADER_CRC,
    PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER,
    PDC_ERROR_INTERNAL_INCONSISTENCY
};


/**
 * @brief SPTDataCacheRecord
 *
 * @discussion Class defines one record in cache that is returned in response. 
 *             Each record is represented by single file on disk.
 *             If file deleted from disk then cache assumes its never existed and return PDC_DATA_NOT_FOUND for load call.
 */
@interface SPTDataCacheRecord : NSObject
/*
 * Defines the number of times external logical references to this cache item. Initially is 0 if locked flag on store is NO.
 * Files with refCount > 0 is considered as locked by GC procedure. They also returned on load call regardless of expiration.
 */
@property (nonatomic, assign, readonly) NSUInteger refCount;
/**
 * Defines ttl for given record if applicable. 0 means not applicable.
 */
@property (nonatomic, assign, readonly) NSUInteger ttl;
/**
 * Key for that record.
 */
@property (nonatomic, strong, readonly) NSString *key;
/*
 * Data that was initially passed into storeData:...
 */
@property (nonatomic, strong, readonly) NSData *data;
@end


/**
 * @brief SPTPersistentCacheResponse
 *
 * @discussion Class defines one response passed in callback to call loadDataForKey:
 */
@interface SPTPersistentCacheResponse : NSObject
/**
 * @see SPTDataCacheResponseCode
 */
@property (nonatomic, assign, readonly) SPTDataCacheResponseCode result;
/**
 * Defines error of response if appliable
 */
@property (nonatomic, strong, readonly) NSError *error;
/**
 * @see SPTDataCacheRecord
 */
@property (nonatomic, strong, readonly) SPTDataCacheRecord *record;
@end


/**
 * Type off callback for load/store calls
 */
typedef void (^SPTDataCacheResponseCallback)(SPTPersistentCacheResponse *response);

/**
 * Type of callback that can be used ot get debug messages from cache.
 */
typedef void (^SPTDataCacheDebugCallback)(NSString *string);

/**
 *
 */
typedef NSString *(^SPTDataCacheChooseKeyCallback)(NSArray *keys);

/**
 * Type of callback that is used to provide current time for that cache. Mainly for testing.
 */
typedef NSTimeInterval (^SPTDataCacheCurrentTimeSecCallback)(void);


/**
 * @brief SPTPersistentDataCacheOptions
 *
 * @discussion Class defines cache creation options
 */
@interface SPTPersistentDataCacheOptions : NSObject
/**
 * Path to a folder in which to store that files. If folder doesn't exist it will be created.
 * This mustn't be nil.
 */
@property (nonatomic, copy) NSString *cachePath;
/**
 * Garbage collection interval. It is guaranteed that once started GC runs with this interval.
 * Its recommended to use SPTPersistentDataCacheDefaultGCIntervalSec constant if not sure.
 * Internal guarding is applied to this value.
 */
@property (nonatomic, assign) NSUInteger collectionIntervalSec;
/**
 * Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 * Its recommended to use SPTPersistentDataCacheDefaultExpirationTimeSec if not sure.
 * Internal guarding is applied.
 */
@property (nonatomic, assign) NSUInteger defaultExpirationPeriodSec;
/**
 * Callback used to supply debug/internal information usually about errors.
 */
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
/**
 * Callback to provide current time in seconds. This time shouldn't depend on time zone etc. 
 * So its better to use fixed time scale i.e. UNIX.
 */
@property (nonatomic, copy) SPTDataCacheCurrentTimeSecCallback currentTimeSec;
/**
 * Any string that identifies the cache and used in naming of internal queue.
 */
@property (nonatomic, copy) NSString *cacheIdentifier;
@end


/**
 * @brief SPTPersistentDataCache
 *
 * @discussion Class defines persistent cache that manage files on disk. This class is threadsafe.
 * It is obligatory that one instanse of that class manage one path branch on disk. In other case behavior is undefined.
 * Cache uses own queue for all operations.
 * Cache GC procedure evicts all not locked files for which current_gc_time - access_time > defaultExpirationPeriodSec.
 * Cache GC procedure evicts all not locked files for which current_gc_time - creation_time > fileTTL.
 * Files that are locked not evicted by GC procedure and returned by the cache even if they already expired. 
 * Once unlocked, expired files would be collected by following GC
 */
@interface SPTPersistentDataCache : NSObject

- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options;

/**
 * @discussion Load data from cache for specified key
 * @param key Key used to access the data. It MUST MUST MUST be unique for different data. 
 *            It could be used as a part of file name. It up to a cache user to define algorithm to form a key.
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)loadDataForKey:(NSString *)key
          withCallback:(SPTDataCacheResponseCallback)callback
               onQueue:(dispatch_queue_t)queue;


/**
 * @discussion Load data for key which has specified prefix. chooseKeyCallback is called with array of matching keys.
 *             To load the data user needs to pick one key and return it. If non of those are match then return nil.
 *             chooseKeyCallback is called on any thread and caller should not do any heavy job in it.
 * @param prefix Prefix which key should have to be candidate for loading.
 * @param chooseKeyCallback callback to call to define which key to use to load the data. 
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)loadDataForKeysWithPrefix:(NSString *)prefix
                chooseKeyCallback:(SPTDataCacheChooseKeyCallback)chooseKeyCallback
                     withCallback:(SPTDataCacheResponseCallback)callback
                          onQueue:(dispatch_queue_t)queue;

/**
 * @discussion If data already exist for that key it will be updated.
 * Its access time will be updated. RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > defaultExpirationPeriodSec.
 *
 * @param data Data to store. Mustn't be nil
 * @param key Key to associate the data with.
 * @param locked If YES then data refCount is incremented by 1. 
          If NO then remain unchanged (for new created file set to 0 and incremented if YES).
 * @param callback Callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;


/**
 * @discussion If data already exist for that key it will be updated. 
 * Its access time will be apdated. Its TTL will be updated if applicable.
 * RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > TTL.
 *
 * @param data Data to store. Mustn't be nil.
 * @param key Key to associate the data with.
 * @param ttl TTL value for a file. 0 is equivalent to storeData:forKey: behavior.
 * @param locked If YES then data refCount is incremented by 1.
 *        If NO then remain unchanged (for new created file set to 0 and incremented if YES).
 * @param callback Callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;

/**
 * Update last access time in header of the record.
 * @param key Key which record header to update
 */
- (void)touchDataForKey:(NSString *)key;

/**
 * @brief Removes data for keys unconditionally.
 */
- (void)removeDataForKeys:(NSArray *)keys;

/**
 * @brief Increment ref count for given keys.
 */
- (void)lockDataForKeys:(NSArray *)keys;

/**
 * @brief Decrement ref count for given keys.
 * If decrements exceeds increments assertion is given.
 */
- (void)unlockDataForKeys:(NSArray *)keys;

/**
 * Schedule ragbage collection. If already scheduled then this method does nothing.
 */
- (void)runGarbageCollector;

/**
 * Stop ragbage collection. If already stopped this method does nothing.
 */
- (void)stopGarbageCollector;

/**
 * Delete all files files in managed folder unconditionaly.
 */
- (void)prune;

/**
 * Wipe only files that locked regardless of refCount value.
 */
- (void)wipeLockedFiles;

/**
 * Wipe only files that are not locked regardles of their expiration time.
 */
- (void)wipeNonLockedFiles;

/**
 * Returns size occupied by cache.
 * WARNING: This method does synchronous calculations.
 */
- (NSUInteger)totalUsedSizeInBytes;

/**
 * Returns size occupied by locked items.
 * WARNING: This method does synchronous calculations.
 */
- (NSUInteger)lockedItemsSizeInBytes;

@end
