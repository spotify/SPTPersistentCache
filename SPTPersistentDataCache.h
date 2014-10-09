
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const SPTPersistentDataCacheErrorDomain;
/**
 * Default garbage collection interval. Some sane implementation defined value you should not care about.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec;
/**
 * Default TTL for all cache items. Particular record TTL takes precedence of this value.
 */
FOUNDATION_EXPORT const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec;


/**
 @enum SPTDataCacheResponseCode

 @discussion The SPTDataCacheResponseCode enum defines constants that
             can be used to identify what kind of response been given in callback to
             loadDataForKey:withCallback: method.

 @constant PDC_DATA_LOADED Indicates that file have been found, been correct and data been loaded.
           record field of SPTPersistentCacheResponse mustn't be nil. error would be nil.

 @constant PDC_DATA_STORED Indicates that data was successfuly stored. error and record would be nil.

 @constant PDC_DATA_NOT_FOUND Indicates that no file found for given key.
           record and error field of SPTPersistentCacheResponse is nil in this case.
 
 @constant PDC_DATA_LOADING_ERROR Indicates that file have been found but error occured.
           record field of SPTPersistentCacheResponse would be nil. error mustn't be nil.
 
 @constant PDC_DATA_STORE_ERROR Indicates that error occured while trying to store the data.
           error mustn'y be nil. record would be nil.
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

 @constant ERROR_MAGIC_MISSMATCH Magic number in record header is not as expected.

 @constant ERROR_HEADER_ALIGNMENT_MISSMATCH Alignment of pointer which casted to header
           is not compatible with first header field.
 @constant ERROR_WRONG_HEADER_SIZE Size of header is not as expected. Possibly bcuz of version change.
 
 @constant ERROR_WRONG_PAYLOAD_SIZE Payload size in header is not the same as stored in cache record.
 
 @constant ERROR_INVALID_HEADER_CRC CRC calculated for reader and contained in header missmatch
 */
typedef NS_ENUM(NSInteger, SPTDataCacheLoadingError)
{
    ERROR_MAGIC_MISSMATCH = 100,
    ERROR_HEADER_ALIGNMENT_MISSMATCH,
    ERROR_WRONG_HEADER_SIZE,
    ERROR_WRONG_PAYLOAD_SIZE,
    ERROR_INVALID_HEADER_CRC
};

/**
 * @brief SPTDataCacheRecord
 *
 * @discussion Class defines one record in cache. Each record is represented by single file on disk.
 * If file deleted from disk cache assumes its never existed and return PDC_DATA_NOT_FOUND for lookup.
 */
@interface SPTDataCacheRecord : NSObject
/*
 * Defines the number of times lockDataForKey: had been called for given key. Initially 0.
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

typedef void (^SPTDataCacheResponseCallback)(SPTPersistentCacheResponse *response);
typedef void (^SPTDataCacheDebugCallback)(NSString *string);
typedef NSTimeInterval (^SPTDataCacheCurrentTimeSecCallback)(void);

/**
 * @brief SPTPersistentDataCacheOptions
 *
 * @discussion Class defines cache creation options
 */
@interface SPTPersistentDataCacheOptions : NSObject
/**
 * Path to a folder in which to store that files. If folder doesn't exist it will be created.
 */
@property (nonatomic, copy) NSString *cachePath;
/**
 * Garbage collection interval. It is guaranteed that once started GC runs with this interval.
 * Its recommended to use SPTPersistentDataCacheDefaultGCIntervalSec constant
 * Internal guarding is applied to this value.
 */
@property (nonatomic, assign) NSUInteger collectionIntervalSec;
/**
 * Default time which have to pass since last file access so file could be candidate for prune on next GC.
 * Its recommended to use SPTPersistentDataCacheDefaultExpirationTimeSec.
 */
@property (nonatomic, assign) NSUInteger defaultExpirationPeriodSec;
/**
 * Callback used to supply debug information usually about errors
 */
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
/**
 * Callback to provide current time in seconds. This time shouldn't depend on time zone etc. 
 * So its better to use fixed time scale i.e. UNIX
 */
@property (nonatomic, copy) SPTDataCacheCurrentTimeSecCallback currentTimeSec;
@end


/**
 * @brief SPTPersistentDataCache
 *
 * @discussion Class defines persistent cache that manages file on disk. This class is threadsafe.
 * It is obligatory that one instanse of that class manages one path branch on disk. In other case behavior is undefined.
 * Cache GC procedure evicts all not locked files for which current_gc_time - access_time > defaultExpirationPeriodSec.
 * Cache GC procedure evicts all not locked files for which current_gc_time - creation_time > fileTTL.
 * Files that are locked not evicted by GC procedure.
 */
@interface SPTPersistentDataCache : NSObject

- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options;

/**
 * @brief loadDataForKey:withCallback:
 * @param key Key used to access the data. It MUST MUST MUST be unique for different data. 
 *            It could be used as file name. It up to a cache user to define algorithm to form a key.
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)loadDataForKey:(NSString *)key
          withCallback:(SPTDataCacheResponseCallback)callback
               onQueue:(dispatch_queue_t)queue;

/**
 * @brief storeData:forKey:
 * @discussion If data already exist for that key it will be updated. 
 * Its access time will be apdated. Data is expired when current_gc_time - access_time > defaultExpirationPeriodSec.
 * RefCount depends on locked parameter.
 *
 * @param data Data to store
 * @param key key to associate the data with.
 * @param locked if YES then data refCount is incremented by 1. If NO then remain unchanged.
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;


/**
 * @brief storeData:forKey:
 * @discussion If data already exist for that key it will be updated. 
 * Its access time will be apdated. Its TTL will be updated if applicable.
 * RefCount depends on locked parameter.
 *
 * @param data Data to store
 * @param key key to associate the data with.
 * @param ttl TTL value for a file. 0 is equivalent to storeData:forKey: behavior.
 * @param locked if YES then data refCount is incremented by 1. If NO then remain unchanged.
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;

/**
 * @brief Removes data for keys unconditionally.
 */
- (void)removeDataForKeys:(NSArray *)keys;

/**
 * @brief Increment ref count for given keys
 */
- (void)lockDataForKeys:(NSArray *)keys;

/**
 * @brief Decrement ref count for given keys.
 * If decrements exceeds increments assertion is given.
 */
- (void)unlockDataForKeys:(NSArray *)keys;

/**
 * @brief Simply update access time on data with given keys
 */
- (void)touchDataForKeys:(NSArray *)keys;

/**
 * Return is data is locke for given key
 */
//- (void)isDataLockedForKey:(NSString *)key withCallback:(void(^)(BOOL))calback onQueue:(dispatch_queue_t)queue;

/**
 * Run ragbage collection. If already running this method does nothing.
 */
- (void)runGarbageCollector;

/**
 * Stop ragbage collection. If already stopped this method does nothing.
 */
- (void)stopGarbageCollector;

/**
 * Delete all files except locked regardless of expiration and TTL
 */
- (void)prune;

/**
 * Returns size occupied by cache
 */
- (NSUInteger)occupiedCacheSizeInBytes;

@end
