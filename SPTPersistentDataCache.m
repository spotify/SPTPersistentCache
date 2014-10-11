#import "SPTPersistentDataCache.h"
#import "crc32iso3309.h"
#import "SPTPersistentDataHeader.h"

NSString *const SPTPersistentDataCacheErrorDomain = @"persistent.cache.error";
const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec = 6 * 60;
const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec = 10 * 60;
static const uint64_t kTTLUpperBoundInSec = 86400 * 31;

const MagicType kMagic = 0x46545053; // SPTF
const int kSPTPersistentRecordHeaderSize = sizeof(SPTPersistentRecordHeaderType);

#pragma mark - SPTDataCacheRecord
@interface SPTDataCacheRecord ()
@property (nonatomic, assign, readwrite) NSUInteger refCount;
@property (nonatomic, assign, readwrite) NSUInteger ttl;
@property (nonatomic, strong, readwrite) NSString *key;
@property (nonatomic, strong, readwrite) NSData *data;
@end

@implementation SPTDataCacheRecord
- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    refCount:(NSUInteger)refCount
                         ttl:(NSUInteger)ttl
{
    if (!(self = [super init])) {
        return nil;
    }

    _refCount = refCount;
    _ttl = ttl;
    _key = key;
    _data = data;

    return self;
}

@end

#pragma mark - SPTPersistentCacheResponse
@interface SPTPersistentCacheResponse ()
@property (nonatomic, assign, readwrite) SPTDataCacheResponseCode result;
@property (nonatomic, strong, readwrite) NSError *error;
@property (nonatomic, strong, readwrite) SPTDataCacheRecord *record;
@end

@implementation SPTPersistentCacheResponse
- (instancetype)initWithResult:(SPTDataCacheResponseCode)result
                         error:(NSError *)error
                        record:(SPTDataCacheRecord *)record
{
    if (!(self = [super init])) {
        return nil;
    }

    _result = result;
    _error = error;
    _record = record;

    return self;
}

@end

#pragma mark - SPTPersistentDataCacheOptions
@implementation SPTPersistentDataCacheOptions
- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    _defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationTimeSec;
    _collectionIntervalSec = SPTPersistentDataCacheDefaultGCIntervalSec;
    return self;
}
@end

typedef void (^FileProcessingBlockType)(int filedes);
typedef void (^RecordHeaderGetCallbackType)(SPTPersistentRecordHeaderType *header);

#pragma mark - SPTPersistentDataCache()
@interface SPTPersistentDataCache ()
@property (nonatomic, copy) SPTPersistentDataCacheOptions *options;
// Serial queue used to run all internall stuff
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSTimer *gcTimer;
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;

- (void)collectGarbageForceExpire:(BOOL)forceExpire forceLocked:(BOOL)forceLocked;
@end

@interface SPTTimerProxy : NSObject
@property (nonatomic, weak) SPTPersistentDataCache *dataCache;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation SPTTimerProxy
- (void)enqueueGC:(NSTimer *)timer
{
    dispatch_barrier_async(self.queue, ^{
        [self.dataCache collectGarbageForceExpire:NO forceLocked:NO];
    });
}
@end

#pragma mark - SPTPersistentDataCache
@implementation SPTPersistentDataCache

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    _options = [SPTPersistentDataCacheOptions new];
    self.options.defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationTimeSec;
    self.options.collectionIntervalSec = SPTPersistentDataCacheDefaultGCIntervalSec;
    self.fileManager = [NSFileManager defaultManager];
    NSParameterAssert(self.options.cachePath);
    
    NSString *name = [NSString stringWithFormat:@"persistent.cache.queue.%ld.%ld.%p",
                      (unsigned long)self.options.collectionIntervalSec, (unsigned long)self.options.defaultExpirationPeriodSec, self];
    _workQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_CONCURRENT);

    return self;
}

- (instancetype)initWithOptions:(SPTPersistentDataCacheOptions *)options
{
    if (!(self = [super init])) {
        return nil;
    }

    _options = options;
    NSString *name = [NSString stringWithFormat:@"persistent.cache.queue.%ld.%ld.%p",
                      (unsigned long)self.options.collectionIntervalSec, (unsigned long)self.options.defaultExpirationPeriodSec, self];
    _workQueue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_CONCURRENT);
    assert(_workQueue != nil);
    self.fileManager = [NSFileManager defaultManager];
    _debugOutput = self.options.debugOutput;

    NSParameterAssert(self.options.cachePath);

    BOOL isDir = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:self.options.cachePath isDirectory:&isDir];
    if (exist == NO) {
        NSError *error = nil;
        BOOL created = [self.fileManager createDirectoryAtPath:self.options.cachePath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error];
        if (created == NO) {
            [self debugOutput:@"PersistentDataCache: Unable to create dir: %@ with error:%@", self.options.cachePath, error];
            return nil;
        }
    }

    if (self.options.defaultExpirationPeriodSec < SPTPersistentDataCacheDefaultExpirationTimeSec) {
        [self debugOutput:@"PersistentDataCache: Forcing defaultExpirationPeriodSec to %ld sec", (unsigned long)SPTPersistentDataCacheDefaultExpirationTimeSec];
    }

    if (self.options.collectionIntervalSec < SPTPersistentDataCacheDefaultGCIntervalSec) {
        [self debugOutput:@"PersistentDataCache: Forcing collectionIntervalSec to %ld sec", (unsigned long)SPTPersistentDataCacheDefaultGCIntervalSec];
    }

    return self;
}

- (void)loadDataForKey:(NSString *)key
          withCallback:(SPTDataCacheResponseCallback)callback
               onQueue:(dispatch_queue_t)queue
{
    NSParameterAssert(callback != nil);
    if (callback == nil) {
        return;
    }

    callback = [callback copy];
    dispatch_async(self.workQueue, ^{

        NSString *filePath = [self pathForKey:key];

        // File not exist -> inform user
        if (![self.fileManager fileExistsAtPath:filePath]) {
            [self dispatchNotFoundCallback:callback onQueue:queue];
            return;
        } else {
            // File exist
            NSError *error = nil;
            NSMutableData *rawData = [NSMutableData dataWithContentsOfFile:filePath
                                                                   options:NSDataReadingMappedIfSafe
                                                                     error:&error];
            if (rawData == nil) {
                // File read with error -> inform user
                [self dispatchError:error result:PDC_DATA_LOADING_ERROR callback:callback onQueue:queue];
            } else {
                SPTPersistentRecordHeaderType *header = pdc_GetHeaderFromData([rawData bytes], [rawData length]);

                // If not enough dat to cast to header its not the file we can process
                if (header == NULL) {
                    NSError *headerError = [self nsErrorWithCode:ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER];
                    [self dispatchError:headerError result:PDC_DATA_LOADING_ERROR callback:callback onQueue:queue];
                    return;
                }

                // Check header is valid
                NSError *headerError = [self checkHeaderValid:header];
                if (headerError != nil) {
                    [self dispatchError:headerError result:PDC_DATA_LOADING_ERROR callback:callback onQueue:queue];
                    return;
                }

                const NSUInteger refCount = header->refCount;
                // We return locked files even if they expired, GC doesnt collect them too so they valuable to user
                if ([self isDataExpiredWithHeader:header] && refCount == 0) {
                    [self dispatchNotFoundCallback:callback onQueue:queue];
                    return;
                }

                assert(header->payloadSizeBytes == [rawData length] - kSPTPersistentRecordHeaderSize);

                // Check that payload is correct size
                if (header->payloadSizeBytes != [rawData length] - kSPTPersistentRecordHeaderSize) {
                    [self debugOutput:@"PersistentDataCache: Wrong payload size for key:%@ , Removing file...", key];
                    [self removeDataForKeys:@[key]];
                    [self dispatchError:[self nsErrorWithCode:ERROR_WRONG_PAYLOAD_SIZE]
                                 result:PDC_DATA_LOADING_ERROR
                               callback:callback onQueue:queue];
                    return;
                }

                NSRange payloadRange = NSMakeRange(kSPTPersistentRecordHeaderSize, header->payloadSizeBytes);
                NSData *payload = [rawData subdataWithRange:payloadRange];
                const NSUInteger ttl = header->ttl;


                SPTDataCacheRecord *record = [[SPTDataCacheRecord alloc] initWithData:payload
                                                                                  key:key
                                                                             refCount:refCount
                                                                                  ttl:ttl];

                SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:PDC_DATA_LOADED
                                                                                                    error:nil
                                                                                                   record:record];
                dispatch_async(queue, ^{
                    callback(response);
                });

                // If data ttl == 0 we apdate access time
                if (ttl == 0) {
                    header->updateTimeSec = (uint64_t)[[NSDate date] timeIntervalSince1970];
                    header->crc = pdc_CalculateHeaderCRC(header);

                    // Write back with update access attributes
                    NSError *werror = nil;
                    if (![rawData writeToFile:filePath options:NSDataWritingAtomic error:&werror]) {
                        [self debugOutput:@"PersistentDataCache: Error writing back file:%@, error:%@", filePath, werror];
                    }
                }
            } // if rawData
        } // file exist
    });
}

- (void)storeData:(NSData *)data
           forKey:(NSString *)key
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue

{
    [self storeData:data forKey:key ttl:0 locked:locked withCallback:callback onQueue:queue];
}

- (void)storeData:(NSData *)data
           forKey:(NSString *)key
              ttl:(NSUInteger)ttl
           locked:(BOOL)locked
     withCallback:(SPTDataCacheResponseCallback)callback
          onQueue:(dispatch_queue_t)queue

{
    assert(data != nil);
    assert(key != nil);
    assert(callback != nil);

    if (data == nil) {
        return;
    }
    if (key == nil) {
        return;
    }
    if (callback == nil) {
        return;
    }

    callback = [callback copy];
    dispatch_barrier_async(self.workQueue, ^{

        NSString *filePath = [self pathForKey:key];

        uint32_t __block oldRefCount = 0;

        // If file already exit satisfy requirement to preserv its refCount for futher possible modification
        if ([self.fileManager fileExistsAtPath:filePath]) {
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header){
                                     assert(header != nil);
                                     oldRefCount = header->refCount;
                                 }
                                 writeBack:NO];
        }

        const NSUInteger payloadLen = [data length];
        const CFIndex rawdataLen = kSPTPersistentRecordHeaderSize + payloadLen;

        NSMutableData *rawData = [NSMutableData dataWithCapacity:rawdataLen];
        const uint8_t *bytes = (uint8_t *)[rawData bytes];

        SPTPersistentRecordHeaderType dummy;
        memset(&dummy, 0, kSPTPersistentRecordHeaderSize);
        [rawData appendBytes:&dummy length:kSPTPersistentRecordHeaderSize];

        SPTPersistentRecordHeaderType *header = (SPTPersistentRecordHeaderType *)(bytes);

        header->magic = kMagic;
        header->headerSize = kSPTPersistentRecordHeaderSize;
        header->refCount = oldRefCount + (locked ? 1 : 0);
        header->ttl = ttl;
        header->payloadSizeBytes = payloadLen;
        header->updateTimeSec = (uint64_t)[[NSDate date] timeIntervalSince1970];
        header->crc = pdc_CalculateHeaderCRC(header);

        [rawData appendData:data];

        NSError *error = nil;

        if (![rawData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
            [self debugOutput:@"PersistentDataCache: Error writting to file:%@ , for key:%@. Removing it...", filePath, key];
            [self removeDataForKeysSync:@[key]];
            [self dispatchError:error result:PDC_DATA_STORE_ERROR callback:callback onQueue:queue];
        } else {
            SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:PDC_DATA_STORED
                                                                                                error:nil
                                                                                               record:nil];
            dispatch_async(queue, ^{
                callback(response);
            });
        }
    });
}

- (void)removeDataForKeysSync:(NSArray *)keys
{
    for (NSString *key in keys) {
        NSError *error = nil;
        NSString *filePath = [self pathForKey:key];
        if (![self.fileManager removeItemAtPath:filePath error:&error]) {
            [self debugOutput:@"PersistentDataCache: Error removing data for Key:%@ , error:%@", key, error];
        }
    }
}

- (void)removeDataForKeys:(NSArray *)keys
{
    dispatch_barrier_async(self.workQueue, ^{
        [self removeDataForKeysSync:keys];
    });
}

- (void)lockDataForKeys:(NSArray *)keys
{
    dispatch_barrier_async(self.workQueue, ^{
        for (NSString *key in keys) {
            NSString *filePath = [self pathForKey:key];
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header) {
                                     assert(header != nil);

                                     ++header->refCount;
            }
                                 writeBack:YES];
        }
    });
}

- (void)unlockDataForKeys:(NSArray *)keys
{
    dispatch_barrier_async(self.workQueue, ^{
        for (NSString *key in keys) {
            NSString *filePath = [self pathForKey:key];
            [self alterHeaderForFileAtPath:filePath
                                 withBlock:^(SPTPersistentRecordHeaderType *header){
                                     assert(header != nil);

                                     if (header->refCount > 0) {
                                         --header->refCount;
                                     } else {
                                         [self debugOutput:@"PersistentDataCache: Error trying to decrement refCount below 0 for file at path:%@", filePath];
                                     }
                                     
                                 }
                                 writeBack:YES];
        }
    });
}

- (void)runGarbageCollector
{
    assert([NSThread isMainThread]);

    [self debugOutput:@"runGarbageCollector:%@", self.gcTimer];

    // if gc process already running to nothing
    if (self.gcTimer != nil) {
        return;
    }

    SPTTimerProxy *proxy = [SPTTimerProxy new];
    proxy.dataCache = self;
    proxy.queue = self.workQueue;

    NSTimeInterval interval = self.options.collectionIntervalSec;
    self.gcTimer = [NSTimer timerWithTimeInterval:interval target:proxy selector:@selector(enqueueGC:) userInfo:nil repeats:YES];
    self.gcTimer.tolerance = 300;
    
    [[NSRunLoop mainRunLoop] addTimer:self.gcTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopGarbageCollector
{
    assert([NSThread isMainThread]);

    [self debugOutput:@"stopGarbageCollector:%@", self.gcTimer];

    [self.gcTimer invalidate];
    self.gcTimer = nil;
}

- (void)prune
{
    dispatch_barrier_async(self.workQueue, ^{
        [self cleanCacheData];
    });
}

- (void)wipeLockedFiles;
{
    dispatch_barrier_async(self.workQueue, ^{
        [self collectGarbageForceExpire:NO forceLocked:YES];
    });
}

- (void)wipeNonLockedFiles{
    dispatch_barrier_async(self.workQueue, ^{
        [self collectGarbageForceExpire:YES forceLocked:NO];
    });
}

- (NSUInteger)totalUsedSizeInBytes
{
    NSUInteger size = 0;
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtPath:self.options.cachePath];
    for (NSString *file in dirEnumerator) {
        NSString *filePath = [self pathForKey:file];
        size += [self getFileSizeAtPath:filePath];
    }

    return size;
}

- (NSUInteger)lockedItemsSizeInBytes
{
    NSUInteger size = 0;
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtPath:self.options.cachePath];
    for (NSString *file in dirEnumerator) {
        NSString *filePath = [self pathForKey:file];

        BOOL __block locked = NO;
        [self alterHeaderForFileAtPath:filePath withBlock:^(SPTPersistentRecordHeaderType *header) {
            locked = header->refCount > 0;
        }
                             writeBack:NO];
        if (locked) {
            size += [self getFileSizeAtPath:filePath];
        }
    }

    return size;
}

- (void)dealloc
{
    [self stopGarbageCollector];
}

#pragma mark - Private methods
- (void)guardOpenFileWithPath:(NSString *)filePath jobBlock:(FileProcessingBlockType)jobBlock
{
    assert(jobBlock != nil);
    if (jobBlock == nil) {
        return;
    }

    if (![self.fileManager fileExistsAtPath:filePath]) {
        [self debugOutput:@"PersistentDataCache: File not exist at path:%@", filePath];
        return;
    } else {
        int fd = open([filePath UTF8String], O_RDONLY);
        if (fd == -1) {
            const char* serr = strerror(errno);
            [self debugOutput:@"PersistentDataCache: Error opening file:%@ , error:%s", filePath, serr];
            return;
        }

        jobBlock(fd);

        fd = close(fd);
        if (fd == -1) {
            const char* serr = strerror(errno);
            [self debugOutput:@"PersistentDataCache: Error closing file:%@ , error:%s", filePath, serr];
        }
    }
}

- (void)alterHeaderForFileAtPath:(NSString *)filePath
                       withBlock:(RecordHeaderGetCallbackType)modifyBlock
                       writeBack:(BOOL)needWriteBack
{
    assert(modifyBlock != nil);
    if (modifyBlock == nil) {
        return;
    }

    [self guardOpenFileWithPath:filePath jobBlock:^(int filedes) {

        SPTPersistentRecordHeaderType header;
        ssize_t readBytes = read(filedes, &header, kSPTPersistentRecordHeaderSize);
        if (readBytes != kSPTPersistentRecordHeaderSize) {
            const char* serr = strerror(errno);
            [self debugOutput:@"PersistentDataCache: Error reading header at file path:%@ , error:%s", filePath, serr];
            return;
        }

        NSError *nsError = [self checkHeaderValid:&header];
        if (nsError != nil) {
            [self debugOutput:@"PersistentDataCache: Error checking header at file path:%@ , error:%@", filePath, nsError];
            return;
        }

        modifyBlock(&header);

        if (needWriteBack) {

            header.crc = spt_crc32((uint8_t*)&header, kSPTPersistentRecordHeaderSize - sizeof(header.crc));

            ssize_t writtenBytes = write(filedes, &header, kSPTPersistentRecordHeaderSize);
            if (writtenBytes != kSPTPersistentRecordHeaderSize) {
                const char* serr = strerror(errno);
                [self debugOutput:@"PersistentDataCache: Error writting header at file path:%@ , error:%s", filePath, serr];
                return;
            }

            int result = fsync(filedes);
            if (result == -1) {
                const char* serr = strerror(errno);
                [self debugOutput:@"PersistentDataCache: Error flushing file:%@ , error:%s", filePath, serr];
            }
        }
    }];
}

- (NSString *)pathForKey:(NSString *)key
{
    return [self.options.cachePath stringByAppendingPathComponent:key];
}

- (NSError *)nsErrorWithCode:(SPTDataCacheLoadingError)errorCode
{
    return [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                               code:errorCode
                           userInfo:nil];
}

- (NSError *)checkHeaderValid:(SPTPersistentRecordHeaderType *)header
{
    int code = pdc_ValidateHeader(header);
    if (code == -1) { // No error
        return nil;
    }
    
    return [self nsErrorWithCode:code];
}

- (BOOL)isDataExpiredWithHeader:(SPTPersistentRecordHeaderType *)header
{
    assert(header != nil);
    uint64_t ttl = header->ttl;
    uint64_t current = (uint64_t)[[NSDate date] timeIntervalSince1970];
    uint64_t threshold = (ttl > 0) ? ttl : self.options.defaultExpirationPeriodSec;

    if (ttl > kTTLUpperBoundInSec) {
        [self debugOutput:@"PersistentDataCache: WARNING: TTL seems too big: %llu > %llu sec", ttl, kTTLUpperBoundInSec];
    }

    return (current - header->updateTimeSec) > threshold;
}

/**
 * forceExpire = YES treat all unlocked files like they expired
 * forceLocked = YES ignore lock status
 */
- (void)collectGarbageForceExpire:(BOOL)forceExpire forceLocked:(BOOL)forceLocked
{
    [self debugOutput:@"PersistentDataCache: Run GC with forceExpire:%d forceLock:%d", forceExpire, forceLocked];
    
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtPath:self.options.cachePath];
    for (NSString *file in dirEnumerator) {
        NSString *filePath = [self pathForKey:file];
        BOOL __block needRemove = NO;
        [self alterHeaderForFileAtPath:filePath
                             withBlock:^(SPTPersistentRecordHeaderType *header) {

                                 if ((([self isDataExpiredWithHeader:header] || forceExpire) && header->refCount == 0) ||
                                     (forceLocked && header->refCount > 0)) {
                                     needRemove = YES;
                                 }
                             } writeBack:NO];
        if (needRemove) {
            [self debugOutput:@"PersistentDataCache: gc removing file: %@", filePath];

            NSError *error= nil;
            if (![self.fileManager removeItemAtPath:filePath error:&error]) {
                [self debugOutput:@"PersistentDataCache: Error gc file:%@ ,error:%@", filePath, error];
            }
        }
    }
}

- (void)cleanCacheData
{
    NSError *error = nil;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:self.options.cachePath
                                                           error:&error];
    if (!files) {
        [self debugOutput:@"PersistentDataCache: Error cleaning cache: %@", error];
        return;
    }

    for (NSString *file in files) {
        if (![self.fileManager removeItemAtPath:file error:&error]) {
            [self debugOutput:@"PersistentDataCache: Error cleaning file: %@ , %@", file, error];
        }
    }
}

- (void)dispatchNotFoundCallback:(SPTDataCacheResponseCallback)callback
                         onQueue:(dispatch_queue_t)queue
{
    SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:PDC_DATA_NOT_FOUND
                                                                                        error:nil
                                                                                       record:nil];
    dispatch_async(queue, ^{
        callback(response);
    });
}

- (void)dispatchError:(NSError *)error
               result:(SPTDataCacheResponseCode)result
             callback:(SPTDataCacheResponseCallback)callback
              onQueue:(dispatch_queue_t)queue
{
    SPTPersistentCacheResponse *response = [[SPTPersistentCacheResponse alloc] initWithResult:result
                                                                                        error:error
                                                                                       record:nil];
    dispatch_async(queue, ^{
        callback(response);
    });
}

- (NSUInteger)getFileSizeAtPath:(NSString *)filePath
{
    NSError *error = nil;
    NSDictionary *attrs = [self.fileManager attributesOfItemAtPath:filePath error:&error];
    if (attrs == nil) {
        [self debugOutput:@"PersistentDataCache: Error getting attributes for file: %@, error: %@", filePath, error];
    }
    return [attrs fileSize];
}

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

NS_INLINE BOOL PointerMagicAlignCheck(const void *ptr)
{
    const unsigned shift = _Alignof(MagicType)-1;
    const unsigned long mask = ~(((unsigned long)(-1) >> shift) << shift);
    assert( !((unsigned long)ptr & mask) );
    return !((unsigned long)ptr & mask);
}

SPTPersistentRecordHeaderType* pdc_GetHeaderFromData(const void* data, size_t size)
{
    if (size < kSPTPersistentRecordHeaderSize) {
        return NULL;
    }

    return (SPTPersistentRecordHeaderType*)data;
}

int /*SPTDataCacheLoadingError*/ pdc_ValidateHeader(const SPTPersistentRecordHeaderType *header)
{
    assert(header != NULL);
    if (header == NULL) {
        return ERROR_INTERNAL_INCONSISTENCY;
    }

    // Check that header could be read according to alignment
    if (!PointerMagicAlignCheck(header)) {
        return ERROR_HEADER_ALIGNMENT_MISSMATCH;
    }

    // Check magic
    if (header->magic != kMagic) {
        return ERROR_MAGIC_MISSMATCH;
    }

    if (header->headerSize != kSPTPersistentRecordHeaderSize) {
        return ERROR_WRONG_HEADER_SIZE;
    }

    uint32_t crc = pdc_CalculateHeaderCRC(header);

    if (crc != header->crc) {
        return ERROR_INVALID_HEADER_CRC;
    }
    
    return -1;
}

uint32_t pdc_CalculateHeaderCRC(const SPTPersistentRecordHeaderType *header)
{
    assert(header != NULL);
    if (header == NULL) {
        return 0;
    }

    return spt_crc32((uint8_t*)header, kSPTPersistentRecordHeaderSize - sizeof(header->crc));
}
