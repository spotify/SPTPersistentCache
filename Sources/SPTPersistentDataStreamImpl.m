#import "SPTPersistentDataStreamImpl.h"
#import "SPTPersistentCacheTypes.h"
#import "SPTPersistentDataHeader.h"
#import "SPTPersistentDataCacheOptions.h"

typedef NSError* (^FileProcessingBlockType)(int filedes);

@interface SPTPersistentDataStreamImpl ()
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@property (nonatomic, copy) CleanupHeandlerCallback cleanupHandler;
@property (nonatomic, copy) SPTDataCacheDebugCallback debugOutput;
@property (nonatomic, assign) SPTPersistentRecordHeaderType header;
@property (nonatomic, assign) off_t currentOffset;
@property (nonatomic, assign) int fileDesc;
@end

@implementation SPTPersistentDataStreamImpl

- (instancetype)initWithPath:(NSString *)filePath
                         key:(NSString *)key
              cleanupHandler:(CleanupHeandlerCallback)cleanupHandler
               debugCallback:(SPTDataCacheDebugCallback)debugCalback
{
    if (!(self = [super init])) {
        return nil;
    }

    assert(cleanupHandler != nil);

    _filePath = filePath;
    _key = key;
    _workQueue = dispatch_queue_create(key.UTF8String, DISPATCH_QUEUE_SERIAL);
    _cleanupHandler = cleanupHandler;
    _debugOutput = debugCalback;
    _fileDesc = -1;

    return self;
}

- (void)dealloc
{
    [self closeStream];
}

- (void)open:(SPTDataCacheStreamCallback)callback
{
    assert(callback != nil);
    if (callback == nil) {
        return;
    }

    // stream was successfully opened if error is nil
    NSError *openError = [self guardOpenFileWithPath:self.filePath jobBlock:^NSError *(int filedes) {

        // Save file descriptor for futher usage
        self.fileDesc = filedes;

        int intError = 0;
        ssize_t bytesRead = read(filedes, &_header, kSPTPersistentRecordHeaderSize);
        if (bytesRead == kSPTPersistentRecordHeaderSize) {

            NSError *nsError = [self checkHeaderValid:&_header];
            if (nsError != nil) {
                return nsError;
            }

            // Get write offset right after last byte of file
            nsError = nil;
            self.currentOffset = [self seekToOffset:0 withOrigin:SEEK_END error:&nsError] - kSPTPersistentRecordHeaderSize;
            if (self.currentOffset < 0 || nsError != nil) {
                [self debugOutput:@"PersistentDataCache: Error getting file size key:%@", self.key];
                return nsError;
            }

            // Req.#1.4. If there is no data in the file mark it as incomplete
            if (_header.payloadSizeBytes == 0) {
                _header.flags |= SPTPersistentRecordHeaderFlagsStreamIncomplete;
            }

            // success
            return nil;

        } else if (bytesRead != -1 && bytesRead < kSPTPersistentRecordHeaderSize) {
            // Migration in future

            NSError *nsError = [self nsErrorWithCode:SPTDataCacheLoadingErrorNotEnoughDataToGetHeader];
            return nsError;
        } else {
            // -1 error
            intError = errno;
        }

        assert(intError != 0);
        const char *strErr = strerror(intError);

        NSError *nsError = [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
        return nsError;
    }];

    // execute callback
    if (openError != nil) {
        callback(SPTDataCacheResponseCodeOperationError, nil, openError);
    } else {
        callback(SPTDataCacheResponseCodeOperationSucceeded, self, nil);
    }
}

#pragma mark - Public API
- (void)appendData:(NSData *)data
          callback:(DataWriteCallback)callback
             queue:(dispatch_queue_t)queue
{
    dispatch_async(self.workQueue, ^{
        _header.flags |= SPTPersistentRecordHeaderFlagsStreamIncomplete;

        NSError *nsError = nil;
        [self writeBytes:data.bytes length:data.length error:&nsError];
        
        if (callback && queue) {
            dispatch_async(queue, ^{
                callback(nsError);
            });
        }
    });
}

- (void)appendBytes:(const void *)bytes
             length:(NSUInteger)length
           callback:(DataWriteCallback)callback
              queue:(dispatch_queue_t)queue
{
    NSMutableData *data = [NSMutableData dataWithBytes:bytes length:length];
    [self appendData:data callback:callback queue:queue];
}

- (void)readDataWithOffset:(off_t)offset
                    length:(NSUInteger)length
                  callback:(DataReadCallback)callback
                     queue:(dispatch_queue_t)queue
{
    assert(callback != nil);
    assert(queue != nil);
    assert(offset >= 0);

    if (callback == nil || queue == nil) {
        return;
    }

    dispatch_async(self.workQueue, ^{

        NSUInteger newLength = length;
        NSError *nsError = nil;
        // If we want all data try to find current size
        if (newLength == SIZE_MAX) {

            // Just sanity check which MUST be holded
            const off_t currentOff = [self seekToOffset:0 withOrigin:SEEK_CUR error:&nsError];
//            [self debugOutput:@"%@: currentOff:%lld, off:%lld", self.key, currentOff, self.currentOffset];
            assert(currentOff == self.currentOffset+kSPTPersistentRecordHeaderSize);

            if (nsError != nil) {
                dispatch_async(queue, ^{
                    callback(nil, nsError);
                });
                return;
            }

            // Get last byte offset as file size
            off_t offSize = [self seekToOffset:0 withOrigin:SEEK_END error:&nsError];
            if (nsError != nil) {
                dispatch_async(queue, ^{
                    callback(nil, nsError);
                });
                return;
            }

            // Put file pointer back in place
            [self seekToOffset:self.currentOffset+kSPTPersistentRecordHeaderSize withOrigin:SEEK_SET error:&nsError];
            if (nsError != nil) {
                dispatch_async(queue, ^{
                    callback(nil, nsError);
                });
                return;
            }

            // Calculate payload size as whole file size minus header size
            newLength = offSize - kSPTPersistentRecordHeaderSize;
        }

        // Prepare buffer of appropriate size
        NSMutableData *data = [NSMutableData dataWithCapacity:newLength];
        [data setLength:newLength];

        // Convert read offset to file offset
        off_t readOffset = offset + kSPTPersistentRecordHeaderSize;

        [self readBytes:data.mutableBytes length:newLength offset:readOffset error:&nsError];

        if (nsError != nil) {
            data = nil;
        }

        dispatch_async(queue, ^{
            callback(data, nsError);
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
    uint32_t __block flags = 0;
    dispatch_sync(self.workQueue, ^{
        flags = self.header.flags;
    });
    return (flags & SPTPersistentRecordHeaderFlagsStreamIncomplete) == 0;
}

- (void)finalize:(dispatch_block_t)completion
{
    assert(self.currentOffset >= 0);
    assert(self.fileDesc != -1);

    dispatch_async(self.workQueue, ^{
        _header.payloadSizeBytes = (uint64_t)self.currentOffset;
        _header.flags = 0;
        _header.crc = pdc_CalculateHeaderCRC(&_header);

        ssize_t ret = pwrite(self.fileDesc, &_header, kSPTPersistentRecordHeaderSize, 0);
        if (ret == -1) {
            const int errn = errno;
            const char* serr = strerror(errn);
            [self debugOutput:@"PersistentDataStream: Error finilizing key:%@ , error:%s", self.key, serr];
        }

        fsync(self.fileDesc);

        if (completion) {
            completion();
        }
    });
}

- (void)dataSizeWithCallback:(DataSizeCallback)callback queue:(dispatch_queue_t)queue
{
    assert(callback != nil);
    assert(queue != nil);

    if (callback == nil || queue == nil) {
        return;
    }

    dispatch_async(self.workQueue, ^{
        const NSUInteger bytesSize = self.currentOffset;
        dispatch_async(queue, ^{
            callback(bytesSize);
        });
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

    int fd = open([filePath UTF8String], O_RDWR|O_EXLOCK);
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

- (void)closeStream
{
    CleanupHeandlerCallback cleanupCallback = [self.cleanupHandler copy];
    dispatch_queue_t queue = self.workQueue;
    int filedesc = self.fileDesc;

//    [self debugOutput:@"PersistentDataStream: Closing stream for key:%@, cleanup:0x%p", self.key, cleanupCallback];

    dispatch_async(queue, ^{
        fsync(filedesc);
        close(filedesc);

        if (cleanupCallback)
            cleanupCallback();
    });
}

- (off_t)seekToOffset:(off_t)offset withOrigin:(int)origin error:(NSError * __autoreleasing *)error
{
    assert(self.fileDesc != -1);

    off_t newOffset = lseek(self.fileDesc, offset, origin);
    if (newOffset < 0) {
        int intError = errno;
        const char *strErr = strerror(intError);
        [self debugOutput:@"PersistentDataStream: Error while lseek, key:%@, (%d) %s", self.key, intError, strErr];

        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
        }
    }

    return newOffset;
}

- (ssize_t)writeBytes:(const void*)bytes length:(size_t)length error:(NSError * __autoreleasing *)error
{
    assert(bytes != NULL);
    assert(self.fileDesc != -1);

    ssize_t ret = write(self.fileDesc, bytes, length);
    fsync(self.fileDesc);
    if (ret == -1) {
        int intError = errno;
        const char *strErr = strerror(intError);
        [self debugOutput:@"PersistentDataStream: Error while write, key:%@, (%d) %s", self.key, intError, strErr];

        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
        }
    } else {
        self.currentOffset += length;
//        [self debugOutput:@"PersistentDataStream: key:%@, written: %ld", self.key, length];
    }

    return ret;
}

/**
 * Read data from specified offset not modifying file pointer.
 * offset is file offset
 */
- (ssize_t)readBytes:(void *)buffer length:(size_t)length offset:(off_t)offset error:(NSError * __autoreleasing *)error
{
    assert(buffer != NULL);
    assert(self.fileDesc != -1);

    ssize_t ret = pread(self.fileDesc, buffer, length, offset);
    if (ret == -1) {
        int intError = errno;
        const char *strErr = strerror(intError);
        [self debugOutput:@"PersistentDataStream: Error while read, key:%@, (%d) %s", self.key, intError, strErr];

        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:intError userInfo:@{NSLocalizedDescriptionKey : @(strErr)}];
        }
    }
    return ret;
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
