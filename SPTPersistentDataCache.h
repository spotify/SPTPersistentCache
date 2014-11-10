#import <Foundation/Foundation.h>
#import "SPTPersistentCacheTypes.h"
#import "SPTPersistentDataStream.h"

/**
 * Type off callback for load/store calls
 */
typedef void (^SPTDataCacheResponseCallback)(SPTPersistentCacheResponse *response);

/**
 * Type of callback that is used to give caller a chance to choose which key to open if any.
 */
typedef NSString *(^SPTDataCacheChooseKeyCallback)(NSArray *keys);

/**
 * Type of callback that is used to provide current time for that cache. Mainly for testing.
 */
typedef NSTimeInterval (^SPTDataCacheCurrentTimeSecCallback)(void);

/**
 * Type of callback that is used  to provide a stream access for particular cache record.
 */
typedef void (^SPTDataCacheStreamCallback)(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error);


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
@property (nonatomic, assign) NSUInteger gcIntervalSec;
/**
 * Default time which have to pass since last file access so file could be candidate for pruning on next GC.
 * Its recommended to use SPTPersistentDataCacheDefaultExpirationTimeSec if not sure.
 * Internal guarding is applied.
 */
@property (nonatomic, assign) NSUInteger defaultExpirationPeriodSec;
/**
 * Size in bytes to which cache should adjust itself when performing GC. 0 - no size constraint (default)
 */
@property (nonatomic, assign) NSUInteger sizeConstraintBytes;
/**
 * Callback used to supply debug/internal information usually about errors.
 */
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
/**
 * Callback to provide current time in seconds. This time shouldn't depend on time zone etc. 
 * So its better to use fixed time scale i.e. UNIX. If not specified then current unix time is used.
 */
@property (nonatomic, copy) SPTDataCacheCurrentTimeSecCallback currentTimeSec;
/**
 * Any string that identifies the cache and used in naming of internal queue. 
 * It is important to put sane string to be able identify queue during debug and in crash dumps.
 * Default is "persistent.cache".
 */
@property (nonatomic, copy) NSString *cacheIdentifier;
/**
 * Use 2 first letter of key for folder names to separate recodrs into. Default: YES
 */
@property (nonatomic, assign) BOOL folderSeparationEnabled;
@end


/**
 * @brief SPTPersistentDataCache
 *
 * @discussion Class defines persistent cache that manage files on disk. This class is threadsafe.
 * Except methods for scheduling/unscheduling GC which must be called on main thread.
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
 * @param queue Queue on which to run the callback. Mustn't be nil.
 */
- (void)loadDataForKey:(NSString *)key
          withCallback:(SPTDataCacheResponseCallback)callback
               onQueue:(dispatch_queue_t)queue;


/**
 * @discussion Load data for key which has specified prefix. chooseKeyCallback is called with array of matching keys.
 *             To load the data user needs to pick one key and return it. Req.#1.1a
 *             If non of those are match then return nil and cache will return not found error. Req.#1.1b
 *             chooseKeyCallback is called on any thread and caller should not do any heavy job in it.
 * @param prefix Prefix which key should have to be candidate for loading.
 * @param chooseKeyCallback callback to call to define which key to use to load the data. 
 * @param callback callback to call once data is loaded. It mustn't be nil.
 * @param queue Queue on which to run the callback. Mustn't be nil.
 */
- (void)loadDataForKeysWithPrefix:(NSString *)prefix
                chooseKeyCallback:(SPTDataCacheChooseKeyCallback)chooseKeyCallback
                     withCallback:(SPTDataCacheResponseCallback)callback
                          onQueue:(dispatch_queue_t)queue;

/**
 * @discussion If data already exist for that key it will be overwritten otherwise created. Req.#1.0
 * Its access time will be updated. RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > defaultExpirationPeriodSec.
 *
 * @param data Data to store. Mustn't be nil
 * @param key Key to associate the data with.
 * @param locked If YES then data refCount is set to 1. If NO then set to 0.
 * @param callback Callback to call once data is loaded. Could be nil.
 * @param queue Queue on which to run the callback. Couldn't be nil if callback is specified.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;


/**
 * @discussion If data already exist for that key it will be overwritten otherwise created. Req.#1.0
 * Its access time will be apdated. Its TTL will be updated if applicable.
 * RefCount depends on locked parameter.
 * Data is expired when current_gc_time - access_time > TTL.
 *
 * @param data Data to store. Mustn't be nil.
 * @param key Key to associate the data with.
 * @param ttl TTL value for a file. 0 is equivalent to storeData:forKey: behavior.
 * @param locked If YES then data refCount is set to 1. If NO then set to 0.
 * @param callback Callback to call once data is loaded. Could be nil.
 * @param queue Queue on which to run the callback. Couldn't be nil if callback is specified.
 */
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue;


/**
 * @discussion Open cache record for appending data. If record is not exist and createIfNotExist is YES then record will
 *             be created, if already exist and createIfNotExist is YES will be overwritten. Req.#1.0
 *             In that case ttl and locked is taken into accout, otherwise is ignored.
 *             TLL could be specified if known, otherwise put 0 as TTL meaning default expiration rule applies.
 *             Record could be created as locked initially specifying YES to locked: argument. refCount is set according to rules
 *             specified for -storeData:. TLL is set to new ttl value.
 * @param key Key to associate the data with.
 * @param needCreate If YES file is created, otherwise just opened.
 * @param ttl TTL value for a file. 0 is equivalent to storeData:forKey:locked:... behavior.
 * @param locked If YES then data refCount is incremented by 1.
 *        If NO then remain unchanged (for new created file set to 0 and incremented if YES).
 * @param callback Callback to call once data is loaded. Could not be nil.
 * @param queue Queue on which to run the callback. Could not be nil .
 */
- (void)openDataStreamForKey:(NSString *)key
            createIfNotExist:(BOOL)needCreate
                         ttl:(NSUInteger)ttl
                      locked:(BOOL)locked
                withCallback:(SPTDataCacheStreamCallback)callback
                     onQueue:(dispatch_queue_t)queue;

/**
 * Update last access time in header of the record. Only applies for default expiration policy (ttl == 0).
 * Success callback is given if file was found and no errors occured even though nothing was changed due to ttl == 0.
 * @param key Key which record header to update. Mustn't be nil.
 * @param callback. May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)touchDataForKey:(NSString *)key
               callback:(SPTDataCacheResponseCallback)callback
                onQueue:(dispatch_queue_t)queue;

/**
 * @brief Removes data for keys unconditionally.
 */
- (void)removeDataForKeys:(NSArray *)keys;

/**
 * @brief Increment ref count for given keys. Give callback with result for each key in input array.
 * @param keys Non nil non empty array of keys.
 * @param callback. May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)lockDataForKeys:(NSArray *)keys
               callback:(SPTDataCacheResponseCallback)callback
                onQueue:(dispatch_queue_t)queue;

/**
 * @brief Decrement ref count for given keys. Give callback with result for each key in input array.
 * If decrements exceeds increments assertion is given.
 * @param keys Non nil non empty array of keys.
 * @param callback. May be nil if not interested in result.
 * @param queue Queue on which to run the callback. If callback is nil this is ignored otherwise mustn't be nil.
 */
- (void)unlockDataForKeys:(NSArray *)keys
                 callback:(SPTDataCacheResponseCallback)callback
                  onQueue:(dispatch_queue_t)queue;

/**
 * Schedule ragbage collection. If already scheduled then this method does nothing.
 * WARNING: This method has to be called on main thread.
 */
- (void)scheduleGarbageCollector;

/**
 * Stop ragbage collection. If already stopped this method does nothing.
 * WARNING: This method has to be called on main thread.
 */
- (void)unscheduleGarbageCollector;

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
 * WARNING: Files opened as streams are accounted in this calculations.
 */
- (NSUInteger)totalUsedSizeInBytes;

/**
 * Returns size occupied by locked items.
 * WARNING: This method does synchronous calculations.
 * WARNING: Files opened as streams are NOT accounted in this calculations.
 */
- (NSUInteger)lockedItemsSizeInBytes;

@end
