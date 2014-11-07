#import "SPTPersistentDataStreamImpl.h"
#import "SPTPersistentCacheTypes.h"
#import "SPTPersistentDataHeader.h"

typedef NSError* (^FileProcessingBlockType)(int filedes);

@interface SPTPersistentDataStreamImpl ()
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) dispatch_io_t source;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, strong) dispatch_queue_t cleanupQueue;
@property (nonatomic, copy) CleanupHeandlerCallback cleanupHandler;
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
@property (nonatomic, assign) SPTPersistentRecordHeaderType header;
@property (nonatomic, assign) off_t writeOffset;
@end

@implementation SPTPersistentDataStreamImpl

- (instancetype)initWithPath:(NSString *)filePath
                         key:(NSString *)key
                cleanupQueue:(dispatch_queue_t)cleanupQueue
              cleanupHandler:(CleanupHeandlerCallback)cleanupHandler
               debugCallback:(SPTDataCacheDebugCallback)debugCalback
{
    if (!(self = [super init])) {
        return nil;
    }

    assert(cleanupQueue != nil);
    assert(cleanupHandler != nil);

    _filePath = filePath;
    _key = key;
    _workQueue = dispatch_queue_create(key.UTF8String, DISPATCH_QUEUE_SERIAL);
    _cleanupQueue = cleanupQueue;
    _cleanupHandler = cleanupHandler;
    _debugOutput = debugCalback;

    return self;
}

- (void)dealloc
{
    dispatch_io_close(self.source, 0);
}

- (NSError *)open
{
    return [self guardOpenFileWithPath:self.filePath jobBlock:^NSError *(int filedes) {

        int intError = 0;

        int bytesRead = read(filedes, &_header, kSPTPersistentRecordHeaderSize);
        if (bytesRead == kSPTPersistentRecordHeaderSize) {

            NSError *nsError = [self checkHeaderValid:&_header];
            if (nsError != nil) {
                return nsError;
            }

            // Get write offset right after last byte of file
            self.writeOffset = lseek(filedes, SEEK_END, 0) - kSPTPersistentRecordHeaderSize;
            if (self.writeOffset < 0) {
                intError = errno;
                const char *strErr = strerror(intError);
                [self debugOutput:@"PersistentDataCache: Error getting file size key:%@, (%d) %s", self.key, intError, strErr];

                return [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
            }

            off_t offset = lseek(filedes, SEEK_SET, kSPTPersistentRecordHeaderSize);
            if (offset < 0) {
                intError = errno;
                const char *strErr = strerror(intError);
                [self debugOutput:@"PersistentDataCache: Error setting header offset for file key:%@, %s", self.key, strErr];

                return [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
            }

            self.source = dispatch_io_create(DISPATCH_IO_RANDOM, filedes, self.cleanupQueue, ^(int posix_error) {
                if (posix_error != 0) {
                    const char *strErr = strerror(posix_error);
                    [self debugOutput:@"PersistentDataCache: Error in handler for key:%@, %s", self.key, strErr];
                }

                fsync(filedes);
                close(filedes);

                if (self.cleanupHandler)
                    self.cleanupHandler();
            });

            if (self.source != NULL) {
                // Prevent getting partial result in read/write callbacks to make life easier
                dispatch_io_set_low_water(self.source, SIZE_MAX);
                return nil;
            }

            return [self nsErrorWithCode:PDC_ERROR_UNABLE_TO_CREATE_IO_SOURCE];

        } else if (bytesRead != -1 && bytesRead < kSPTPersistentRecordHeaderSize) {
            // Migration

        } else {
            // -1 error
            intError = errno;
        }

        assert(intError != 0);
        const char *strErr = strerror(intError);
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
    }];
}

#pragma mrk - Public API
- (void)appendData:(NSData *)data
          callback:(DataWriteCallback)callback
             queue:(dispatch_queue_t)queue
{
    [self appendBytes:data.bytes length:data.length callback:callback queue:queue];
}

- (void)appendBytes:(const void *)bytes
             length:(NSUInteger)length
           callback:(DataWriteCallback)callback
              queue:(dispatch_queue_t)queue
{
    off_t offset = 0;
//    @synchronized(self.source) {
        offset = self.writeOffset;
        self.writeOffset += length;
//    }

    dispatch_data_t data = dispatch_data_create(bytes, length, self.workQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(self.source, offset, data, self.workQueue, ^(bool done, dispatch_data_t dataRemained, int error) {

        NSError *nsError = nil;
        if (done == YES && error == 0) {
            // Success: Mark record as incomplete
//            @synchronized(self.source) {
                _header.flags |= PDC_HEADER_FLAGS_STREAM_INCOMPLETE;
//            }

        } else if (done == YES && error > 0) {
            const char *strerr = strerror(error);
            nsError = [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                                          code:PDC_ERROR_STREAM_WRITE_FAILED
                                      userInfo:@{NSLocalizedDescriptionKey : @(strerr)}];
        } else if (done == NO) {
            // We do not expect it
            assert(!"Not expected");
        }

        if (callback != nil) {
            dispatch_async(queue, ^{
                callback(nsError);
            });
        }
    });
}

- (void)readDataWithOffset:(off_t)offset
                    length:(NSUInteger)length
                  callback:(DataReadCallback)callback
                     queue:(dispatch_queue_t)queue
{
    assert(callback != nil);
    assert(queue != nil);
    if (callback == nil || queue == nil) {
        return;
    }

    dispatch_io_read(self.source, offset, length, self.workQueue, ^(bool done, dispatch_data_t dataRead, int error) {

        NSError *nsError = nil;
        NSMutableData * __block payload = nil;

        if (done == YES && error == 0) {
            payload = [NSMutableData data];

            dispatch_data_apply(dataRead, ^bool(dispatch_data_t region, size_t regionOffset, const void *buffer, size_t size) {
                [payload appendBytes:buffer length:size];
                return YES;
            });

        } else if (done == YES && error > 0) {
            const char *strerr = strerror(error);
            nsError = [NSError errorWithDomain:SPTPersistentDataCacheErrorDomain
                                          code:PDC_ERROR_STREAM_WRITE_FAILED
                                      userInfo:@{NSLocalizedDescriptionKey : @(strerr)}];
        } else if (done == NO) {
            // Partial data read which we do not expect
            assert(!"Not expected");
        }

        dispatch_async(queue, ^{
            callback(payload, nsError);
        });
    });
}

- (void)readAllDataWithCallback:(DataReadCallback)callback
                          queue:(dispatch_queue_t)queue
{
    [self readDataWithOffset:0 length:SIZE_MAX callback:callback queue:queue];
}

- (BOOL)isComplete
{
    uint32_t flags = 0;
//    @synchronized(self.source) {
        flags = self.header.flags;
//    }

    return (flags & PDC_HEADER_FLAGS_STREAM_INCOMPLETE) > 0;
}

// WARNING: This operation is not thread safe against append methods
- (void)finalize
{
    assert(self.writeOffset > 0);
    _header.payloadSizeBytes = (uint64_t)self.writeOffset;
    _header.flags = 0;
    _header.crc = pdc_CalculateHeaderCRC(&_header);

    dispatch_data_t data = dispatch_data_create(&_header, kSPTPersistentRecordHeaderSize, self.workQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    off_t offset = -kSPTPersistentRecordHeaderSize;
    dispatch_io_write(self.source, offset, data, self.workQueue, ^(bool done, dispatch_data_t dataRemained, int error) {
        if (done == YES && error == 0) {
            // Success: done
        } else if (done == YES && error > 0) {
            const char *strerr = strerror(error);
            [self debugOutput:@"PersistentDataStream: Error finilizing file: (%d) %s", error, strerr];
        } else if (done == NO) {
            // Partial data read which we do not expect
            assert(!"Not expected");
        }
    });
}

#pragma mark - Private Methods
- (NSError *)guardOpenFileWithPath:(NSString *)filePath
                          jobBlock:(FileProcessingBlockType)jobBlock
{
    assert(jobBlock != nil);
    if (jobBlock == nil) {
        return nil;
    }

    int fd = open([filePath UTF8String], O_RDWR);
    if (fd == -1) {
        const int errn = errno;
        const char* serr = strerror(errn);

        [self debugOutput:@"PersistentDataStream: Error opening file:%@ , error:%s", filePath, serr];
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:errn userInfo:@{NSLocalizedDescriptionKey: @(serr)}];
    }

    NSError * nsError = jobBlock(fd);

    // If there is no error we leave ownership to caller. otherwise we close file
    if (nsError != nil) {
        fd = close(fd);
        if (fd == -1) {
            const int errn = errno;
            const char* serr = strerror(errn);
            [self debugOutput:@"PersistentDataStream: Error closing file:%@ , error:%s", filePath, serr];
        }
    }

    return nsError;
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
