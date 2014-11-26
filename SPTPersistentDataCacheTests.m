
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <unistd.h>

#import "SPTPersistentDataHeader.h"
#import "SPTPersistentDataCache.h"

#import "SPTAsyncTestHelper.h"

static const char* kImages[] = {
    "b91998ae68b9639cee6243df0886d69bdeb75854",
    "c3b19963fc076930dd36ce3968757704bbc97357",
    "fc22d4f65c1ba875f6bb5ba7d35a7fd12851ed5c",
    "c5aec3eef2478bfe47aef16787a6b4df31eb45f2",
    "ee678d23b8dba2997c52741e88fa7a1fdeaf2863",
    "f7501f27f70162a9a7da196c5d2ece3151a2d80a",
    "e5a1921f8f75d42412e08aff4da33e1132f7ee8a",
    "e5b8abdc091921d49e86687e28b74abb3139df70",
    "ee6b44ab07fa3937a6d37f449355b64c09677295",
    "f50512901688b79a7852999d384d097a71fad788",
    "eee9747e967c4440eb90bb812d148aa3d0056700",
    "f1eeb834607dcc2b01909bd740d4356f2abb4cd1", //12
    "b02c1be08c00bac5f4f1a62c6f353a24487bb024",
    "b3e04bf446b486412a13659af71e3a333c6152f4",
    "b53aed36cdc67dd43b496db74843ac32fe1f64bb",
    "aad0e75ab0a6828d0a9b37a68198cc9d70d84850",
    "ab3d97d4d7b3df5417490aa726c5a49b9ee98038", //17
    NULL
};
typedef struct
{
    uint64_t ttl;
    BOOL locked;
    BOOL last;
    int corruptReason; // -1 not currupted
} StoreParamsType;

static const uint64_t kTTL1 = 7200;
static const uint64_t kTTL2 = 604800;
static const uint64_t kTTL3 = 1495;
static const uint64_t kTTL4 = 86400;
static const NSInteger kCorruptedFileSize = 15;
static const uint64_t kTestEpochTime = 1488;
static const NSTimeInterval kDefaultWaitTime = 6.0; //sec

static const StoreParamsType kParams[] = {
    {0,     YES, NO, -1},
    {0,     YES, NO, -1},
    {0,     NO, NO, -1},
    {0,     NO, NO, -1},
    {kTTL1, YES, NO, -1},
    {kTTL2, YES, NO, -1},
    {kTTL3, NO, NO, -1},
    {kTTL4, NO, NO, -1},
    {0,     NO, NO, -1},
    {0,     NO, NO, -1},
    {0,     NO, NO, -1},
    {0,     NO, NO, -1}, // 12
    {0,     NO, NO, PDC_ERROR_MAGIC_MISSMATCH},
    {0,     NO, NO, PDC_ERROR_WRONG_HEADER_SIZE},
    {0,     NO, NO, PDC_ERROR_WRONG_PAYLOAD_SIZE},
    {0,     NO, NO, PDC_ERROR_INVALID_HEADER_CRC},
    {0,     NO, NO, PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER}, // 17

    {kTTL4, NO, YES, -1}
};

static int params_GetFilesNumber(BOOL locked);
static int params_GetCorruptedFilesNumber(void);
static int params_GetDefaultExpireFilesNumber(void);
static int params_GetFilesWithTTLNumber(BOOL locked);

static BOOL spt_test_ReadHeaderForFile(const char* path, BOOL validate, SPTPersistentRecordHeaderType *header);

@interface SPTPersistentDataCache (Testing)
- (NSString *)pathForKey:(NSString *)key;
- (void)runRegularGC;
- (void)pruneBySize;
@end

@interface SPTPersistentDataCacheTests : XCTestCase
@property (nonatomic, strong) SPTPersistentDataCache *cache;
@property (nonatomic, strong) NSMutableArray *imageNames;
@property (nonatomic, strong) NSString *cachePath;
@property (nonatomic, strong) SPTAsyncTestHelper *asyncHelper;
@property (nonatomic, strong) NSBundle *thisBundle;
@end

/** DO NOT DELETE:
 * Failed seeds: 1417002282, 1417004699, 1417005389, 1417006103
 * Prune size failed: 1417004677, 1417004725, 1417003704
 */
@implementation SPTPersistentDataCacheTests

/*
 1. Write/Read test
 - Locked file
 - Unlocked file
 - Locked file with TTL
 - Unlocked file with TTL
 - Randomly generate data set
 - Use concurrent write
 */
- (void)setUp {
    [super setUp];

    time_t seed = time(NULL);
    NSLog(@"Seed:%ld", seed);
    srand(seed);

    // Form array of images for shuffling
    self.imageNames = [NSMutableArray array];

    {
        int i = 0;
        while (kImages[i] != NULL) {
            [self.imageNames addObject:@(kImages[i++])];
        }
    }

    @autoreleasepool {

        NSInteger count = self.imageNames.count-1;
        while (count >= 0) {
            uint32_t idx = rand() % ((uint32_t)(count+1));
            NSString * tmp = self.imageNames[count];
            self.imageNames[count] = self.imageNames[idx];
            self.imageNames[idx] = tmp;
            count--;
        }
    }

    self.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"pdc-%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]]];

    NSLog(@"%@", self.cachePath);

    self.cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return kTestEpochTime; }
                                    expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    self.thisBundle = [NSBundle bundleForClass:[self class]];

    self.asyncHelper = [SPTAsyncTestHelper new];

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        XCTAssert(kParams[i].last != YES, @"Last param element reached");
        NSString *fileName = [self.thisBundle pathForResource:self.imageNames[i] ofType:nil];
        [self putFile:fileName inCache:self.cache withKey:self.imageNames[i] ttl:kParams[i].ttl locked:kParams[i].locked];
        NSData *data = [NSData dataWithContentsOfFile:fileName];
        UIImage *image = [UIImage imageWithData:data];
        XCTAssertNotNil(image, @"Image is invalid");
    }

    [self.asyncHelper waitForTestGroupSync];

    for (unsigned i = 0; !kParams[i].last; ++i) {
        if (kParams[i].corruptReason > -1) {
            NSString *filePath = [self.cache pathForKey:self.imageNames[i]];
            [self corruptFile:filePath pdcError:kParams[i].corruptReason];
        }
    }

    self.cache = nil;
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:nil];
    self.cache = nil;
    self.imageNames = nil;
    self.asyncHelper = nil;
    self.thisBundle = nil;

    [super tearDown];
}

/*
 * Use read
 * Check data is ok.
 */
- (void)testCorrectWriteAndRead
{
    // No expiration
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return [NSDate timeIntervalSinceReferenceDate];
    }
                                                       expirationTime:[NSDate timeIntervalSinceReferenceDate]];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    int __block calls = 0;
    int __block errorCalls = 0;

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {

        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {

            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                BOOL locked = response.record.refCount > 0;
                XCTAssertEqual(kParams[i].locked, locked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];

        XCTAssert(kParams[i].last != YES, @"Last param element reached");
    }

    [self.asyncHelper waitForTestGroupSync];

    // Check that updat time was modified when access cache (both case ttl==0, ttl>0)
    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];
        [self checkUpdateTimeForFileAtPath:path validate:kParams[i].corruptReason == -1 referenceTimeCheck:^(uint64_t updateTime) {
            if (kParams[i].ttl > 0) {
                XCTAssertEqual(updateTime, kTestEpochTime, @"Time must not be altered for records with TTL > 0 on cache access");
            } else {
                if (i == streamIndex) {
                    XCTAssertEqual(updateTime, kTestEpochTime, @"Time must not be altered for records with TTL > 0 on cache access");
                } else {
                    XCTAssertNotEqual(updateTime, kTestEpochTime, @"Time must be altered since cache was accessed");
                }
            }
        }];
    }

    XCTAssertEqual(calls, self.imageNames.count, @"Number of checked files must match");
    // -1 for opened stream
    XCTAssertEqual(errorCalls -1, params_GetCorruptedFilesNumber(), @"Number of checked files must match");
}

/**
 * This test also checks Req.#1.1a of cache API
 WARNING: This test depend on hardcoded data
- Do 1
- find keys with same prefix
- load and check
*/
- (void)testLoadWithPrefixesSuccess
{
    // No expiration
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return [NSDate timeIntervalSinceReferenceDate];
    }
                                                       expirationTime:[NSDate timeIntervalSinceReferenceDate]];

    [self.asyncHelper startTest];

    // Thas hardcode logic: 10th element should be safe to get
    const int index = 10;
    NSString *prefix = self.imageNames[index];
    prefix = [prefix substringToIndex:2];
    NSString * __block key = nil;

    [cache loadDataForKeysWithPrefix:prefix chooseKeyCallback:^NSString *(NSArray *keys) {
        XCTAssert([keys count] >= 1, @"We expect at least 1 key here");
        key = keys.firstObject;
        XCTAssertTrue([key hasPrefix:prefix]);
        return key;

    } withCallback:^(SPTPersistentCacheResponse *response) {

        if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
            XCTAssertNotNil(response.record, @"Expected valid not nil record");
            UIImage *image = [UIImage imageWithData:response.record.data];
            XCTAssertNotNil(image, @"Expected valid not nil image");
            XCTAssertNil(response.error, @"error is not expected to be here");

            NSInteger idx = [self.imageNames indexOfObject:key];
            XCTAssertNotEqual(idx, NSNotFound);

            BOOL locked = response.record.refCount > 0;
            XCTAssertEqual(kParams[idx].locked, locked, @"Same files must be locked");
            XCTAssertEqual(kParams[idx].ttl, response.record.ttl, @"Same files must have same TTL");
            XCTAssertEqualObjects(key, response.record.key, @"Same files must have same key");

        } else if (response.result == PDC_DATA_NOT_FOUND) {
            XCTAssert(NO, @"This shouldnt happen");

        } else if (response.result == PDC_DATA_OPERATION_ERROR ){
            XCTAssertNotNil(response.error, @"error is not expected to be here");
        }

        [self.asyncHelper endTest];
    } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

}

/**
 * This test also checks Req.#1.1b of cache API
 */
- (void)testLoadWithPrefixesFail
{
    // No expiration
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return [NSDate timeIntervalSinceReferenceDate];
    }
                                                       expirationTime:[NSDate timeIntervalSinceReferenceDate]];

    [self.asyncHelper startTest];

    // Thas hardcode logic: 10th element should be safe to get
    const int index = 9;
    NSString *prefix = self.imageNames[index];
    prefix = [prefix substringToIndex:2];
    NSString * __block key = nil;

    [cache loadDataForKeysWithPrefix:prefix chooseKeyCallback:^NSString *(NSArray *keys) {
        XCTAssert([keys count] >= 1, @"We expect at least 1 key here");
        key = keys.firstObject;
        XCTAssertTrue([key hasPrefix:prefix]);

        // Refuse to open
        return nil;

    } withCallback:^(SPTPersistentCacheResponse *response) {

        if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
            XCTAssert(NO, @"This shouldnt happen");
        } else if (response.result == PDC_DATA_NOT_FOUND) {
            XCTAssertNil(response.record, @"Expected valid nil record");
            XCTAssertNil(response.error, @"Valid nil error is expected to be here");
        } else {
            XCTAssert(NO, @"This shouldnt happen");
        }

        [self.asyncHelper endTest];
    } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

}

/*
 - Do 1
 - Lock unlocked files
 - Unlock locked files
 - Concurrent read
 - Check data is ok.
 */
- (void)testLockUnlock
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    NSMutableArray *toLock = [NSMutableArray array];
    NSMutableArray *toUnlock = [NSMutableArray array];

    const NSUInteger count = self.imageNames.count;
    for (unsigned i = 0; i < count; ++i) {
        if (kParams[i].locked) {
            [toUnlock addObject:self.imageNames[i]];
        } else {
            [toLock addObject:self.imageNames[i]];
        }
    }

    // Wait untill all lock/unlock is done
    [self.asyncHelper startTest];
    NSInteger __block toLockCount = [toLock count];
    [cache lockDataForKeys:toLock callback:^(SPTPersistentCacheResponse *response) {
        if (--toLockCount == 0) {
            [self.asyncHelper endTest];
        }
    }
                   onQueue:dispatch_get_main_queue()];

    [self.asyncHelper startTest];
    NSInteger __block toUnlockCount = [toUnlock count];
    [cache unlockDataForKeys:toUnlock callback:^(SPTPersistentCacheResponse *response) {
        if (--toUnlockCount == 0){
            [self.asyncHelper endTest];
        }
    }
                     onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    // Now check that updateTime is not altered by lock unlock calls for all not corrupted files
    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];
        [self checkUpdateTimeForFileAtPath:path validate:kParams[i].corruptReason == -1 referenceTimeCheck:^(uint64_t updateTime) {
            XCTAssertEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. not altering");
        }];
    }

    int __block calls = 0;
    int __block errorCalls = 0;

    for (unsigned i = 0; i < count; ++i) {

        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                BOOL locked = response.record.refCount > 0;
                XCTAssertNotEqual(kParams[i].locked, locked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssertEqual(calls, self.imageNames.count, @"Number of checked files must match");
    // -1 stands for stream
    XCTAssertEqual(errorCalls -1, params_GetCorruptedFilesNumber(), @"Number of checked files must match");
}

/*
 3. Remove test
 - Do 1 w/o *
 - Remove data set with keys
 - Check file system is empty
 */
- (void)testRemoveItems
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    [cache removeDataForKeys:self.imageNames];

    int __block calls = 0;

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {

        [self.asyncHelper startTest];

        // This just give us guarantee that files should be deleted
        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (i == streamIndex) {
                XCTAssert(response.result == PDC_DATA_OPERATION_ERROR, @"We expect file wouldn't be found after removing");
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertEqual(response.error.code, PDC_ERROR_RECORD_IS_STREAM_AND_BUSY, @"error code is not as expected to be here");
            } else {
                XCTAssertEqual(response.result, PDC_DATA_NOT_FOUND, @"We expect file wouldn't be found after removing");
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssert(calls == self.imageNames.count, @"Number of checked files must match");

    // Check file syste, that there are no files left
    NSUInteger files = [self getFilesNumberAtPath:self.cachePath];
    // 1 for opened stream
    XCTAssertEqual(files, 1, @"There shouldn't be files left");
}

/*
 4. Test prune
 - Do 1 w/o *
 - prune
 - test file system is clean
 */
- (void)testPureCache
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    [cache prune];

    int __block calls = 0;

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {

        [self.asyncHelper startTest];

        // This just give us guarantee that files should be deleted
        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {

            calls += 1;

            if (i == streamIndex) {
                XCTAssert(response.result == PDC_DATA_OPERATION_ERROR, @"We expect file wouldn't be found after removing");
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertEqual(response.error.code, PDC_ERROR_RECORD_IS_STREAM_AND_BUSY, @"error code is not as expected to be here");
            } else {
                XCTAssertEqual(response.result, PDC_DATA_NOT_FOUND, @"We expect file wouldn't be found after removing");
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssert(calls == self.imageNames.count, @"Number of checked files must match");

    // Check file syste, that there are no files left
    NSUInteger files = [self getFilesNumberAtPath:self.cachePath];
    // 1 for opened streams
    XCTAssertEqual(files, 1, @"There shouldn't be files left");
}


/**
 5. Test wipe locked
 - Do 1 w/o *
 - wipe locked
 - check no locked files on fs
 - check unlocked is remains untouched
 */
- (void)testWipeLocked
{
    // We consider that no expiration occure in this test
    // If pass nil in time callback then files with TTL would be expired
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];
    const int streamIndex = 1;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    [cache wipeLockedFiles];

    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;

    BOOL __block locked = NO;
    const int reallyLocked = params_GetFilesNumber(YES);

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                locked = response.record.refCount > 0;
                XCTAssertEqual(kParams[i].locked, locked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {

                if (i == streamIndex) {
                    XCTAssertNil(response.record, @"Expected valid nil record");
                    XCTAssertEqual(response.error.code, PDC_ERROR_RECORD_IS_STREAM_AND_BUSY, @"Valid error is expected to be here");
                } else {
                    XCTAssertNil(response.record, @"Expected valid nil record");
                    XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                }
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssert(calls == self.imageNames.count, @"Number of checked files must match");
    // -1 stand for locked file opened as stream
    XCTAssertEqual(notFoundCalls, reallyLocked-1, @"Number of really locked files files is not the same we deleted");

    // Check file syste, that there are no files left
    NSUInteger files = [self getFilesNumberAtPath:self.cachePath];
    // -1 stand for locked file opened as stream
    XCTAssertEqual(files -1, self.imageNames.count-reallyLocked, @"There shouldn't be files left");
    // -1 stand for locked file opened as stream
    XCTAssertEqual(errorCalls -1, params_GetCorruptedFilesNumber(), @"Number of checked files must match");
}

/*
 6. Test wipe unlocked
 - Do 1 w/o *
 - wipe unlocked
 - check no unlocked files on fs
 - check locked is remains untouched
*/
- (void)testWipeUnlocked
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    [cache wipeNonLockedFiles];

    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    BOOL __block unlocked = YES;
    // +1 stands for PDC_ERROR_WRONG_PAYLOAD_SIZE since technically it has corrent header.
    const int reallyUnlocked = params_GetFilesNumber(NO) + 1;

    const NSUInteger count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                unlocked = response.record.refCount == 0;
                XCTAssertEqual(kParams[i].locked, !unlocked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {

                if (i == streamIndex) {
                    XCTAssertNil(response.record, @"Expected valid nil record");
                    XCTAssertEqual(response.error.code, PDC_ERROR_RECORD_IS_STREAM_AND_BUSY, @"Valid error is expected to be here");
                } else {
                    XCTAssertNil(response.record, @"Expected valid nil record");
                    XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                }

                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssert(calls == self.imageNames.count, @"Number of checked files must match");
    // -1 stands for opened stream
    XCTAssertEqual(notFoundCalls, reallyUnlocked -1, @"Number of really locked files files is not the same we deleted");

    // Check file system, that there are no files left
    NSUInteger files = [self getFilesNumberAtPath:self.cachePath];
    // -1 stands for opened stream
    XCTAssertEqual(files -1, self.imageNames.count-reallyUnlocked, @"There shouldn't be files left");
    // -1 stands for opened stream
    XCTAssertEqual(errorCalls -1, params_GetCorruptedFilesNumber()-1, @"Number of checked files must match");
}

/*
 7. Test used size
 - Do 1 w/o *
 - test
 */
- (void)testUsedSize
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    NSUInteger expectedSize = [self calculateExpectedSize];
    NSUInteger realUsedSize = [cache totalUsedSizeInBytes];
    XCTAssertEqual(realUsedSize, expectedSize);
}

/*
 8. Test locked size
 - Do 1 w/o *
 - test
 */
- (void)testLockedSize
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 1;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    NSUInteger expectedSize = 0;

    for (unsigned i = 0; !kParams[i].last; ++i) {

        if (i == streamIndex) {
            continue;
        }

        if (kParams[i].locked) {

            NSString *fileName = [self.thisBundle pathForResource:self.imageNames[i] ofType:nil];
            NSData *data = [NSData dataWithContentsOfFile:fileName];
            XCTAssertNotNil(data, @"Data must be valid");
            expectedSize += ([data length] + kSPTPersistentRecordHeaderSize);
        }
    }

    NSUInteger realUsedSize = [cache lockedItemsSizeInBytes];
    XCTAssertEqual(realUsedSize, expectedSize);
}

/**
 * This test also checks Req.#1.2 of cache API.
 */
- (void)testExpirationWithDefaultTimeout
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        // Exceed expiration interval by 1 sec
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec + 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const NSUInteger count = self.imageNames.count;
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;
    BOOL __block unlocked = YES;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                ++successCalls;
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                unlocked = response.record.refCount == 0;
                XCTAssertEqual(kParams[i].locked, !unlocked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int normalFilesCount = params_GetDefaultExpireFilesNumber();
    const int corrupted = params_GetCorruptedFilesNumber();

    XCTAssert(calls == count, @"Number of checked files must match");
    XCTAssertEqual(successCalls, count-normalFilesCount-corrupted, @"There should be exact number of locked files");
    // -1 stands for payload error since technically header is correct and returned as Not found
    XCTAssertEqual(notFoundCalls-1, normalFilesCount, @"Number of not found files must match");
    // -1 stands for payload error since technically header is correct
    XCTAssertEqual(errorCalls, corrupted-1, @"Number of not found files must match");
}

- (void)testExpirationWithTTL
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        // Take largest TTL of non locked + 1 sec
        return kTestEpochTime + kTTL4 + 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const NSUInteger count = self.imageNames.count;
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;
    BOOL __block unlocked = YES;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                ++successCalls;
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                unlocked = response.record.refCount == 0;
                XCTAssertEqual(kParams[i].locked, !unlocked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int normalFilesCount = params_GetFilesNumber(NO);

    XCTAssert(calls == count, @"Number of checked files must match");
    XCTAssertEqual(successCalls, params_GetFilesNumber(YES), @"There should be exact number of locked files");
    // -1 stands for payload error since technically header is correct and returned as Not found
    XCTAssertEqual(notFoundCalls-1, normalFilesCount, @"Number of not found files must match");
    // -1 stands for payload error since technically header is correct
    XCTAssertEqual(errorCalls, params_GetCorruptedFilesNumber()-1, @"Number of not found files must match");
}

/**
 * This test also checks Req.#1.2 for cache API
 */
- (void)testTouchOnlyRecordsWithDefaultExpirtion
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        return kTestEpochTime + SPTPersistentDataCacheDefaultExpirationTimeSec - 1;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];
    const NSUInteger streamIndex = 2;
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    const int count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache touchDataForKey:self.imageNames[i] callback:^(SPTPersistentCacheResponse *response) {
            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    // Now check that updateTime is not altered for files with TTL
    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];
        [self checkUpdateTimeForFileAtPath:path validate:kParams[i].corruptReason == -1 referenceTimeCheck:^(uint64_t updateTime) {
            if (kParams[i].ttl == 0) {
                if (i == streamIndex) {
                    XCTAssertEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. touched");
                } else {
                    XCTAssertNotEqual(updateTime, kTestEpochTime, @"Time must not match for initial value i.e. touched");
                }
            } else {
                XCTAssertEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. not touched");
            }
        }];
    }

    // Now do regular check of data integrity after touch
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;
    BOOL __block unlocked = YES;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                ++successCalls;
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                unlocked = response.record.refCount == 0;
                XCTAssertEqual(kParams[i].locked, !unlocked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int corrupted = params_GetCorruptedFilesNumber();

    XCTAssert(calls == count, @"Number of checked files must match");
    // -1 stands for opened stream
    XCTAssertEqual(successCalls, count-corrupted -1, @"There should be exact number of locked files");
    XCTAssertEqual(notFoundCalls, 0, @"Number of not found files must match");
    // -1 stands for opened stream
    XCTAssertEqual(errorCalls -1, corrupted, @"Number of not found files must match");
}


/**
 * This test also checks Req.#1.2 for cache API
 */
- (void)testCantTouchRecordsWithDefaultExpirtionThatAreExpiredAlready
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:nil
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    // Try to get stream for expired object
    [self.asyncHelper startTest];
    [cache openDataStreamForKey:self.imageNames[2] createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {
                       XCTAssertEqual(result, PDC_DATA_NOT_FOUND);
                       XCTAssertNil(s);
                       XCTAssertNil(error);
                       [self.asyncHelper endTest];
                   } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    // Try to touch the data that is expired
    const int count = self.imageNames.count;

    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache touchDataForKey:self.imageNames[i] callback:^(SPTPersistentCacheResponse *response) {
            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                successCalls += 1;

            } else if (response.result == PDC_DATA_NOT_FOUND) {
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                errorCalls += 1;
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int lockedFilesCount = params_GetFilesNumber(YES);
    const int corrupted = params_GetCorruptedFilesNumber();

    XCTAssertEqual(successCalls, lockedFilesCount);
    // -1 for payload error
    XCTAssertEqual(notFoundCalls -1, count-lockedFilesCount-corrupted);
    // -1 for payload error
    XCTAssertEqual(errorCalls, corrupted -1);


    // Now check that updateTime is not altered for files with TTL
    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];

        [self checkUpdateTimeForFileAtPath:path validate:kParams[i].corruptReason == -1 referenceTimeCheck:^(uint64_t updateTime) {

            if (kParams[i].ttl > 0 && kParams[i].locked == YES) {
                XCTAssertEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. touched");
            } else if (kParams[i].ttl == 0 && kParams[i].locked == YES) {
                XCTAssertNotEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. not touched");
            } else if (kParams[i].locked == NO) {
                XCTAssertEqual(updateTime, kTestEpochTime, @"Time must match for initial value i.e. touched");
            } else {
                XCTAssert(NO);
            }
        }];
    }

    // Now do regular check of data integrity after touch
    calls = 0;
    successCalls = 0;
    notFoundCalls = 0;
    errorCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {
            calls += 1;

            if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
                ++successCalls;
                XCTAssertNotNil(response.record, @"Expected valid not nil record");
                UIImage *image = [UIImage imageWithData:response.record.data];
                XCTAssertNotNil(image, @"Expected valid not nil image");
                XCTAssertNil(response.error, @"error is not expected to be here");

                BOOL unlocked = response.record.refCount == 0;
                XCTAssertEqual(kParams[i].locked, !unlocked, @"Same files must be locked");
                XCTAssertEqual(kParams[i].ttl, response.record.ttl, @"Same files must have same TTL");
                XCTAssertEqualObjects(self.imageNames[i], response.record.key, @"Same files must have same key");
            } else if (response.result == PDC_DATA_NOT_FOUND) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNil(response.error, @"error is not expected to be here");
                notFoundCalls += 1;

            } else if (response.result == PDC_DATA_OPERATION_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");
                errorCalls += 1;

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [self.asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssert(calls == count, @"Number of checked files must match");

    XCTAssertEqual(successCalls, lockedFilesCount, @"There should be exact number of locked files");
    // -1 for payload error
    XCTAssertEqual(notFoundCalls -1, count-lockedFilesCount-corrupted, @"Number of not found files must match");
    // -1 for payload error
    XCTAssertEqual(errorCalls, corrupted -1, @"Number of not found files must match");
}


- (void)testRegularGC
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:nil
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    NSString *path2 = [cache pathForKey:self.imageNames[streamIndex]];
    [self alterUpdateTime:[[NSDate date] timeIntervalSince1970] forFileAtPath:path2];
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    const NSUInteger count = self.imageNames.count;

    [cache runRegularGC];

    // After GC we have to have only locked files and corrupted
    int lockedCount = 0;
    int removedCount = 0;

    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];

        if (i == streamIndex) {
            continue;
        }

        SPTPersistentRecordHeaderType header;
        BOOL opened = spt_test_ReadHeaderForFile(path.UTF8String, YES, &header);
        if (kParams[i].locked) {
            ++lockedCount;
            XCTAssertTrue(opened, @"Locked files expected to be at place");
        } else {
            ++removedCount;
            XCTAssertFalse(opened, @"Not locked files expected to removed thus unable to be opened");
        }
    }

    XCTAssertEqual(lockedCount, params_GetFilesNumber(YES), @"Locked files count must match");
    // We add number of corrupted since we couldn't open them anyway
    // -1 stand for opened stream, its not deleted
    XCTAssertEqual(removedCount, params_GetFilesNumber(NO)+params_GetCorruptedFilesNumber() -1, @"Removed files count must match");
}

// WARNING: This test is dependent on hardcoded data TTL4
- (void)testRegularGCWithTTL
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval{
        // Take largest TTL4 of non locked
        return kTestEpochTime + kTTL4;
    }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int streamIndex = 2;
    NSString *path2 = [cache pathForKey:self.imageNames[streamIndex]];
    [self alterUpdateTime:[[NSDate date] timeIntervalSince1970] forFileAtPath:path2];
    id<SPTPersistentDataStream> stream = [self openStreamWithIndex:streamIndex onCache:cache];
    (void)(stream);

    const NSUInteger count = self.imageNames.count;

    [cache runRegularGC];

    // After GC we have to have only locked files and corrupted
    int lockedCount = 0;
    int removedCount = 0;

    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];

        if (i == streamIndex) {
            continue;
        }

        SPTPersistentRecordHeaderType header;
        BOOL opened = spt_test_ReadHeaderForFile(path.UTF8String, YES, &header);
        if (kParams[i].locked) {
            ++lockedCount;
            XCTAssertTrue(opened, @"Locked files expected to be at place");
        } else if (kParams[i].ttl == kTTL4) {
            XCTAssertTrue(opened, @"TTL4 file expected to be at place");
        } else {
            ++removedCount;
            XCTAssertFalse(opened, @"Not locked files expected to removed thus unable to be opened");
        }
    }

    XCTAssertEqual(lockedCount, params_GetFilesNumber(YES), @"Locked files count must match");
    // We add number of corrupted since we couldn't open them anyway
    // -1 stands for wrong payload
    // -1 stands for opened stream
    XCTAssertEqual(removedCount, params_GetFilesNumber(NO)+params_GetCorruptedFilesNumber() -1 -1, @"Removed files count must match");
}

- (void)testPruneWithSizeRestriction
{
    const NSUInteger count = self.imageNames.count;

    // Just dummy cache to get path to items
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:nil expirationTime:0];

    // Alter update time for our data set so it monotonically increase from the past starting at index 0 to count-1
    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];

        struct timeval t[2];
        t[0].tv_sec = kTestEpochTime - 5*(i+1);
        t[0].tv_usec = 0;
        t[1] = t[0];
        int ret = utimes(path.UTF8String, t);
        XCTAssertNotEqual(ret, -1, @"Failed to set file access time");
    }

    NSMutableArray *savedItems = [NSMutableArray array];

    // Take 6 first elements which are least oldest
    const NSUInteger dropCount = 6;
    NSUInteger expectedSize = 0;

    for (unsigned i = 0; i < count && i < dropCount; ++i) {
        NSUInteger size = [self dataSizeForItem:self.imageNames[i]];
        expectedSize -= (size + kSPTPersistentRecordHeaderSize);
        [savedItems addObject:self.imageNames[i]];
    }

    SPTPersistentDataCacheOptions *options = [SPTPersistentDataCacheOptions new];
    options.cachePath = self.cachePath;
    options.debugOutput = ^(NSString *str) {
        NSLog(@"%@", str);
    };
    options.sizeConstraintBytes = expectedSize;

    cache = [[SPTPersistentDataCache alloc] initWithOptions:options];

    [cache pruneBySize];

    // Check that size reached its required level
    NSUInteger realSize = [cache totalUsedSizeInBytes];
    XCTAssert(realSize <= expectedSize, @"real cache size has to be less or equal to what we expect");

    // Check that files supposed to be deleted was actually removed
    for (unsigned i = 0; i < savedItems.count; ++i) {

        // Skip not locked files since they could be deleted
        NSUInteger idx = [self.imageNames indexOfObject:savedItems[i]];
        if (!kParams[idx].locked) {
            continue;
        }

        NSString *path = [cache pathForKey:savedItems[i]];
        SPTPersistentRecordHeaderType header;
        BOOL opened = spt_test_ReadHeaderForFile(path.UTF8String, YES, &header);
        XCTAssertTrue(opened, @"Saved files expected to in place");
    }

    // Call once more to make sure nothing will be droped
    [cache pruneBySize];

    NSUInteger realSize2 = [cache totalUsedSizeInBytes];
    XCTAssertEqual(realSize, realSize2);
}

/**
 * At least 2 serial stores with lock for same key doesn't increment refCount.
 * Detect change in TTL and in refCount when parameters changed.
 * This is for Req.#1.0 of cache API
 */
- (void)testSerialStoreWithLockDoesntIncrementRefCount
{
    const NSTimeInterval refTime = kTestEpochTime + 1.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    // Index of file to put. It should be file without any problems.
    const int putIndex = 2;
    NSString *key = self.imageNames[putIndex];
    NSString *fileName = [self.thisBundle pathForResource:key ofType:nil];
    NSString *path = [cache pathForKey:key];

    // Check that image is valid just in case
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    UIImage *image = [UIImage imageWithData:data];
    XCTAssertNotNil(image, @"Image is invalid");

    // Put file for existing name and expect new ttl and lock status
    [self.asyncHelper startTest];
    [self putFile:fileName inCache:cache withKey:key ttl:kTTL1 locked:YES];
    [self.asyncHelper waitForTestGroupSync];

    // Check data
    SPTPersistentRecordHeaderType header;
    XCTAssertTrue(spt_test_ReadHeaderForFile(path.UTF8String, YES, &header), @"Expect valid record");
    XCTAssertEqual(header.ttl, kTTL1, @"TTL must match");
    XCTAssertEqual(header.refCount, 1, @"refCount must match");

    // Now same call with new ttl and same lock status. Expect no change in refCount according to API Req.#1.0
    [self.asyncHelper startTest];
    [self putFile:fileName inCache:cache withKey:key ttl:kTTL2 locked:YES];
    [self.asyncHelper waitForTestGroupSync];

    // Check data
    XCTAssertTrue(spt_test_ReadHeaderForFile(path.UTF8String, YES, &header), @"Expect valid record");
    XCTAssertEqual(header.ttl, kTTL2, @"TTL must match");
    XCTAssertEqual(header.refCount, 1, @"refCount must match");

    // Now same call with new ttl and new lock status. Expect no change in refCount according to API Req.#1.0
    [self.asyncHelper startTest];
    [self putFile:fileName inCache:cache withKey:key ttl:kTTL1 locked:NO];
    [self.asyncHelper waitForTestGroupSync];

    // Check data
    XCTAssertTrue(spt_test_ReadHeaderForFile(path.UTF8String, YES, &header), @"Expect valid record");
    XCTAssertEqual(header.ttl, kTTL1, @"TTL must match");
    XCTAssertEqual(header.refCount, 0, @"refCount must match");
}

- (void)testStreamOpenSuccessNoCreate
{
    const NSTimeInterval refTime = kTestEpochTime + 1.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];


    const int count = self.imageNames.count;

    // Now do regular check of data integrity after touch
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache openDataStreamForKey:self.imageNames[i] createIfNotExist:NO ttl:0 locked:NO
                       withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {

                           calls += 1;

                           if (result == PDC_DATA_OPERATION_SUCCEEDED) {
                               ++successCalls;

                               XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                               XCTAssertNil(error, @"error is not expected to be here");

                           } else if (result == PDC_DATA_NOT_FOUND) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNil(error, @"error is not expected to be here");
                               notFoundCalls += 1;

                           } else if (result == PDC_DATA_OPERATION_ERROR) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNotNil(error, @"Valid error is expected to be here");
                               errorCalls += 1;

                           } else {
                               XCTAssert(NO, @"Unexpected result code on LOAD");
                           }

                           [self.asyncHelper endTest];

                       } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int corrupted = params_GetCorruptedFilesNumber();
    XCTAssertEqual(calls, count, @"Number of files and callbacks must match");
    // -1 for wrong payload
    XCTAssertEqual(successCalls , count - (corrupted -1), @"Success calls must match");
    XCTAssertEqual(notFoundCalls, 0);
    // -1 for wrong payload
    XCTAssertEqual(errorCalls, (corrupted -1), @"Error calls must match");
}

- (void)testCantGetSameStreamMoreThanOneTime
{
    const NSTimeInterval refTime = kTestEpochTime + 1.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    [self.asyncHelper startTest];
    id<SPTPersistentDataStream> __block s1 = nil;
    [cache openDataStreamForKey:self.imageNames[2] createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {
                       XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED);
                       XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNil(error, @"error is not expected to be here");
                       s1 = stream;
                       [self.asyncHelper endTest];
                   }
                        onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    [self.asyncHelper startTest];
    [cache openDataStreamForKey:self.imageNames[2] createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {
                       XCTAssertEqual(result, PDC_DATA_OPERATION_ERROR);
                       XCTAssertNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNotNil(error, @"error is not expected to be here");
                       XCTAssertEqual(error.code, PDC_ERROR_RECORD_IS_STREAM_AND_BUSY, @"Error code must match");
                       [self.asyncHelper endTest];
                   }
                        onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];
}

- (void)testStreamOpenFailNoCreate
{
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:nil
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];


    const int count = self.imageNames.count;

    // Now do regular check of data integrity after touch
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        [cache openDataStreamForKey:self.imageNames[i] createIfNotExist:NO ttl:0 locked:NO
                       withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {

                           calls += 1;

                           if (result == PDC_DATA_OPERATION_SUCCEEDED) {
                               ++successCalls;

                               XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                               XCTAssertNil(error, @"error is not expected to be here");

                           } else if (result == PDC_DATA_NOT_FOUND) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNil(error, @"error is not expected to be here");
                               notFoundCalls += 1;

                           } else if (result == PDC_DATA_OPERATION_ERROR) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNotNil(error, @"Valid error is expected to be here");
                               errorCalls += 1;

                           } else {
                               XCTAssert(NO, @"Unexpected result code on LOAD");
                           }

                           [self.asyncHelper endTest];

                       } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    const int corrupted = params_GetCorruptedFilesNumber();
    XCTAssertEqual(calls, count, @"Number of files and callbacks must match");
    // -1 for wrong payload
    XCTAssertEqual(successCalls , 0, @"Success calls must match");
    XCTAssertEqual(notFoundCalls, count - (corrupted -1));
    // -1 for wrong payload
    XCTAssertEqual(errorCalls, (corrupted -1), @"Error calls must match");
}

- (void)testStreamOpenSuccessWithCreate
{
    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    const uint64_t refTTL = kTTL1 + kTTL3;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];


    const int count = self.imageNames.count;

    // Now do regular check of data integrity after touch
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        const uint64_t ttl = (kParams[i].ttl > 0 ? refTTL : 0);
        const BOOL locked = !kParams[i].locked;

        [cache openDataStreamForKey:self.imageNames[i] createIfNotExist:YES ttl:ttl locked:locked
                       withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {

                           calls += 1;

                           if (result == PDC_DATA_OPERATION_SUCCEEDED) {
                               ++successCalls;

                               XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                               XCTAssertNil(error, @"error is not expected to be here");

                           } else if (result == PDC_DATA_NOT_FOUND) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNil(error, @"error is not expected to be here");
                               notFoundCalls += 1;

                           } else if (result == PDC_DATA_OPERATION_ERROR) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNotNil(error, @"Valid error is expected to be here");
                               errorCalls += 1;

                           } else {
                               XCTAssert(NO, @"Unexpected result code on LOAD");
                           }

                           [self.asyncHelper endTest];

                       } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssertEqual(calls, count, @"Number of files and callbacks must match");
    XCTAssertEqual(successCalls , count, @"Success calls must match");
    XCTAssertEqual(notFoundCalls, 0);
    XCTAssertEqual(errorCalls, 0, @"Error calls must match");

    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];

        SPTPersistentRecordHeaderType header;
        BOOL opened = spt_test_ReadHeaderForFile(path.UTF8String, YES, &header);
        XCTAssertTrue(opened, @"Files must be at place");

        const uint32_t refCount = (kParams[i].locked ? 0 : 1);
        XCTAssertEqual(header.refCount, refCount, @"RefCoutn must match");
        const uint64_t ttl = (kParams[i].ttl > 0 ? refTTL : 0);
        XCTAssertEqual(header.ttl, ttl, @"TTL must match");
        XCTAssertEqual(header.payloadSizeBytes, 0, @"Payload must be 0 initially");
        XCTAssertEqual(header.flags, 0, @"Flags must be 0 initially");
        XCTAssertEqual(header.updateTimeSec, refTime, @"Update time must match");
    }
}

- (void)testStreamOpenFailWithCreate
{
    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    const uint64_t refTTL = kTTL1 + kTTL3;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];


    const int count = self.imageNames.count;

    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];
        int ret = chflags(path.UTF8String, UF_IMMUTABLE);
        XCTAssertEqual(ret, 0, @"Couldnt change file flags");
    }


    // Now do regular check of data integrity after touch
    int __block calls = 0;
    int __block notFoundCalls = 0;
    int __block errorCalls = 0;
    int __block successCalls = 0;

    for (unsigned i = 0; i < count; ++i) {
        [self.asyncHelper startTest];

        const uint64_t ttl = (kParams[i].ttl > 0 ? refTTL : 0);
        const BOOL locked = !kParams[i].locked;

        [cache openDataStreamForKey:self.imageNames[i] createIfNotExist:YES ttl:ttl locked:locked
                       withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> stream, NSError *error) {

                           calls += 1;

                           if (result == PDC_DATA_OPERATION_SUCCEEDED) {
                               ++successCalls;

                               XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                               XCTAssertNil(error, @"error is not expected to be here");

                           } else if (result == PDC_DATA_NOT_FOUND) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNil(error, @"error is not expected to be here");
                               notFoundCalls += 1;

                           } else if (result == PDC_DATA_OPERATION_ERROR) {
                               XCTAssertNil(stream, @"Must be nil stream on not found");
                               XCTAssertNotNil(error, @"Valid error is expected to be here");
                               errorCalls += 1;

                           } else {
                               XCTAssert(NO, @"Unexpected result code on LOAD");
                           }

                           [self.asyncHelper endTest];

                       } onQueue:dispatch_get_main_queue()];
    }

    [self.asyncHelper waitForTestGroupSync];

    XCTAssertEqual(calls, count, @"Number of files and callbacks must match");
    XCTAssertEqual(successCalls , 0, @"Success calls must match");
    XCTAssertEqual(notFoundCalls, 0);
    XCTAssertEqual(errorCalls, count, @"Error calls must match");

    for (unsigned i = 0; i < count; ++i) {
        NSString *path = [cache pathForKey:self.imageNames[i]];
        int ret = chflags(path.UTF8String, 0);
        XCTAssertEqual(ret, 0, @"Couldnt change file flags back to normal");
    }
}

- (void)testStreamReadImageWithParts
{
    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int count = self.imageNames.count;


    NSUInteger maxDataSize = 0;
    int idx = 0;
    for (unsigned i = 0; i < count; ++i) {
        NSUInteger size = [self dataSizeForItem:self.imageNames[i]];
        if (size > maxDataSize && kParams[i].corruptReason == -1) {
            maxDataSize = size;
            idx = i;
        }
    }

    NSString *key = self.imageNames[idx];
    id<SPTPersistentDataStream> __block stream = nil;

    [self.asyncHelper startTest];
    [cache openDataStreamForKey:key createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {

                       stream = s;
                       XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED, @"Result must be success");
                       XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNil(error, @"error is not expected to be here");

                       [self.asyncHelper endTest];

                   } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    NSUInteger expectedLen = maxDataSize /3;

    // Get ranges we want to get from stream
    NSRange r1 = NSMakeRange(0, expectedLen);
    NSRange r2 = NSMakeRange(expectedLen, expectedLen);
    NSRange r3 = NSMakeRange(2*expectedLen, maxDataSize - 2*expectedLen);

    XCTAssertEqual(r1.length+r2.length+r3.length, maxDataSize);

    [self.asyncHelper startTest];
    [self.asyncHelper startTest];
    [self.asyncHelper startTest];

    NSData * __block data1 = nil;
    NSData * __block data2 = nil;
    NSData * __block data3 = nil;

    [stream readDataWithOffset:r1.location length:r1.length callback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        data1 = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    [stream readDataWithOffset:r2.location length:r2.length callback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        data2 = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    [stream readDataWithOffset:r3.location length:r3.length callback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        data3 = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    NSMutableData *imageData = [NSMutableData dataWithData:data1];
    [imageData appendData:data2];
    [imageData appendData:data3];

    UIImage *image = [UIImage imageWithData:imageData];
    XCTAssertNotNil(image, @"Image must be non nil");

    NSString *fileName = [self.thisBundle pathForResource:key ofType:nil];
    NSData *originalData = [NSData dataWithContentsOfFile:fileName];
    XCTAssertEqualObjects(imageData, originalData, @"Read and original data must match");
}

- (void)testStreamReadWhole
{
    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];

    const int count = self.imageNames.count;

    // Get index of most large data
    NSUInteger maxDataSize = 0;
    int idx = 0;
    for (unsigned i = 0; i < count; ++i) {
        NSUInteger size = [self dataSizeForItem:self.imageNames[i]];
        if (size > maxDataSize && kParams[i].corruptReason == -1) {
            maxDataSize = size;
            idx = i;
        }
    }

    NSString *key = self.imageNames[idx];
    id<SPTPersistentDataStream> __block stream = nil;

    [self.asyncHelper startTest];
    [cache openDataStreamForKey:key createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {

                       stream = s;
                       XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED, @"Result must be success");
                       XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNil(error, @"error is not expected to be here");

                       [self.asyncHelper endTest];

                   } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    NSUInteger expectedLen = maxDataSize /2;

    // Get ranges we want to get from stream
    NSRange r1 = NSMakeRange(0, expectedLen);
    NSRange r2 = NSMakeRange(expectedLen, maxDataSize - expectedLen);

    XCTAssertEqual(r1.length+r2.length, maxDataSize);

    [self.asyncHelper startTest];
    [self.asyncHelper startTest];
    [self.asyncHelper startTest];

    NSData * __block data1 = nil;
    NSData * __block data2 = nil;
    NSData * __block wholeData = nil;

    [stream readDataWithOffset:r1.location length:r1.length callback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        data1 = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    [stream readDataWithOffset:r2.location length:r2.length callback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        data2 = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    // Read whole data
    [stream readAllDataWithCallback:^(NSData *continousData, NSError *error) {
        XCTAssertNotNil(continousData);
        XCTAssertNil(error);
        wholeData = continousData;

        [self.asyncHelper endTest];
    } queue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    NSMutableData *imageData = [NSMutableData dataWithData:data1];
    [imageData appendData:data2];

    UIImage *image = [UIImage imageWithData:imageData];
    XCTAssertNotNil(image, @"Image must be non nil");

    UIImage *wholeImage = [UIImage imageWithData:wholeData];
    XCTAssertNotNil(wholeImage, @"Image must be non nil");

    NSString *fileName = [self.thisBundle pathForResource:key ofType:nil];
    NSData *originalData = [NSData dataWithContentsOfFile:fileName];
    XCTAssertEqualObjects(imageData, originalData, @"Read and original data must match");
    XCTAssertEqualObjects(wholeData, originalData, @"Read and wholeData data must match");
}

- (void)testStreamWriteChunks
{
    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];
    const int count = self.imageNames.count;

    NSUInteger maxDataSize = 0;
    int idx = 0;
    for (unsigned i = 0; i < count; ++i) {
        NSUInteger size = [self dataSizeForItem:self.imageNames[i]];
        // Exclude corrupted files
        if (size > maxDataSize && kParams[i].corruptReason == -1) {
            maxDataSize = size;
            idx = i;
        }
    }

    NSString *key = self.imageNames[idx];
    id<SPTPersistentDataStream> __block stream = nil;

    [self.asyncHelper startTest];
    [cache openDataStreamForKey:key createIfNotExist:YES ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {

                       stream = s;
                       XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED, @"Result must be success");
                       XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNil(error, @"error is not expected to be here");

                       [self.asyncHelper endTest];

                   } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];

    NSUInteger expectedLen = maxDataSize /5;

    // Get ranges we want to get from stream
    NSRange r1 = NSMakeRange(0, expectedLen);
    NSRange r2 = NSMakeRange(1*expectedLen, expectedLen);
    NSRange r3 = NSMakeRange(2*expectedLen, expectedLen);
    NSRange r4 = NSMakeRange(3*expectedLen, expectedLen);
    NSRange r5 = NSMakeRange(4*expectedLen, maxDataSize - 4*expectedLen);

    XCTAssertEqual(r1.length+r2.length+r3.length+r4.length+r5.length, maxDataSize);

    NSString *fileName = [self.thisBundle pathForResource:key ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:fileName];

    XCTAssertTrue([stream isComplete]);

    XCTestExpectation *exp1 = [self expectationWithDescription:@"d1 write"];
    NSData *d1 = [data subdataWithRange:r1];
    [stream appendData:d1 callback:^(NSError *error) {
        [exp1 fulfill];
    } queue:dispatch_get_main_queue()];

    XCTAssertFalse([stream isComplete]);

    XCTestExpectation *exp2 = [self expectationWithDescription:@"d2 write"];
    NSData *d2 = [data subdataWithRange:r2];
    [stream appendData:d2 callback:^(NSError *error) {
        [exp2 fulfill];
    } queue:dispatch_get_main_queue()];


    XCTestExpectation *exp3 = [self expectationWithDescription:@"d3 write"];
    NSData *d3 = [data subdataWithRange:r3];
    [stream appendBytes:d3.bytes length:d3.length callback:^(NSError *error) {
        [exp3 fulfill];
    } queue:dispatch_get_main_queue()];


    XCTestExpectation *exp4 = [self expectationWithDescription:@"d4 write"];
    NSData *d4 = [data subdataWithRange:r4];
    [stream appendBytes:d4.bytes length:d4.length callback:^(NSError *error) {
        [exp4 fulfill];
    } queue:dispatch_get_main_queue()];

    XCTestExpectation *exp5 = [self expectationWithDescription:@"d5 write"];
    NSData *d5 = [data subdataWithRange:r5];
    [stream appendData:d5 callback:^(NSError *error) {
        [exp5 fulfill];
    } queue:dispatch_get_main_queue()];

    [self waitForExpectationsWithTimeout:kDefaultWaitTime handler:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];


    // Now check read data
    XCTestExpectation *readExp = [self expectationWithDescription:@"Read whole data"];

    NSData * __block readAllData = nil;
    [stream readAllDataWithCallback:^(NSData *continousData, NSError *error) {
        readAllData = continousData;
        XCTAssertNil(error);
        [readExp fulfill];
    } queue:dispatch_get_main_queue()];

    [self waitForExpectationsWithTimeout:kDefaultWaitTime handler:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];

    XCTAssertEqualObjects(readAllData, data);
}

/**
 * Write 3 chunks. finalize.
 * check read whole data and check its same as written.
 * Kill the stream
 * write to more chinks. finalize
 * read whole and compare
 */
- (void)testStreamWriteMoreChunksWithFinalize
{

    const NSTimeInterval refTime = kTestEpochTime + 17.0;
    SPTPersistentDataCache *cache = [self createCacheWithTimeCallback:^NSTimeInterval(){ return refTime; }
                                                       expirationTime:SPTPersistentDataCacheDefaultExpirationTimeSec];
    const int count = self.imageNames.count;

    NSUInteger maxDataSize = 0;
    int idx = 0;
    for (unsigned i = 0; i < count; ++i) {
        NSUInteger size = [self dataSizeForItem:self.imageNames[i]];
        // Exclude corrupted files
        if (size > maxDataSize && kParams[i].corruptReason == -1) {
            maxDataSize = size;
            idx = i;
        }
    }

    NSString *key = self.imageNames[idx];
    id<SPTPersistentDataStream> __block stream = nil;
    NSString *fileName = [self.thisBundle pathForResource:key ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    NSUInteger expectedLen = maxDataSize /5;

    // Get ranges we want to get from stream
    NSRange r1 = NSMakeRange(0, expectedLen);
    NSRange r2 = NSMakeRange(1*expectedLen, expectedLen);
    NSRange r3 = NSMakeRange(2*expectedLen, expectedLen);
    NSRange r4 = NSMakeRange(3*expectedLen, expectedLen);
    NSRange r5 = NSMakeRange(4*expectedLen, maxDataSize - 4*expectedLen);

    XCTAssertEqual(r1.length+r2.length+r3.length+r4.length+r5.length, maxDataSize);

    // Autorelease pool is required as sync primitive to make stream dealloc invoked first before reopen it again.
    @autoreleasepool {
        [self.asyncHelper startTest];
        [cache openDataStreamForKey:key createIfNotExist:YES ttl:0 locked:NO
                       withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {

                           stream = s;
                           XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED, @"Result must be success");
                           XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                           XCTAssertNil(error, @"error is not expected to be here");

                           [self.asyncHelper endTest];

                       } onQueue:dispatch_get_main_queue()];

        [self.asyncHelper waitForTestGroupSync];

        XCTestExpectation *exp1 = [self expectationWithDescription:@"d1 write"];
        NSData *d1 = [data subdataWithRange:r1];
        [stream appendData:d1 callback:^(NSError *error) {
            [exp1 fulfill];
        } queue:dispatch_get_main_queue()];


        XCTestExpectation *exp2 = [self expectationWithDescription:@"d2 write"];
        NSData *d2 = [data subdataWithRange:r2];
        [stream appendData:d2 callback:^(NSError *error) {
            [exp2 fulfill];
        } queue:dispatch_get_main_queue()];


        XCTestExpectation *exp3 = [self expectationWithDescription:@"d3 write"];
        NSData *d3 = [data subdataWithRange:r3];
        [stream appendBytes:d3.bytes length:d3.length callback:^(NSError *error) {
            [exp3 fulfill];
        } queue:dispatch_get_main_queue()];

        XCTestExpectation *expFinalize = [self expectationWithDescription:@"finalize"];
        [stream finalize: ^{
            [expFinalize fulfill];
        }];

        [self waitForExpectationsWithTimeout:kDefaultWaitTime handler:^(NSError *error) {
            NSLog(@"Error: %@", error);
        }];


        // Now check read data
        XCTestExpectation *read123Exp = [self expectationWithDescription:@"Read d1 d2 d3 data"];

        NSData * __block readData = nil;
        [stream readAllDataWithCallback:^(NSData *continousData, NSError *error) {
            readData = continousData;
            XCTAssertNil(error);
            [read123Exp fulfill];
        } queue:dispatch_get_main_queue()];
        
        [self waitForExpectationsWithTimeout:kDefaultWaitTime handler:^(NSError *error) {
            NSLog(@"Error: %@", error);
        }];
        
        XCTAssertTrue([stream isComplete]);
        
        NSMutableData* d123 = [NSMutableData dataWithData:d1];
        [d123 appendData:d2];
        [d123 appendData:d3];
        XCTAssertEqualObjects(d123, readData);
        
        // Release stream
        stream = nil;
    }

    XCTestExpectation *openExp = [self expectationWithDescription:@"second open for append"];
    // and reopen it again to comlete it
    [cache openDataStreamForKey:key createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {

                       stream = s;

                       if (error) {
                           NSLog(@"Error for key:%@ error:%@", key, error);
                       }

                       XCTAssertEqual(result, PDC_DATA_OPERATION_SUCCEEDED, @"Result must be success");
                       XCTAssertNotNil(stream, @"Must be valid non nil stream on success");
                       XCTAssertNil(error, @"error is not expected to be here");

                       [openExp fulfill];

                   } onQueue:dispatch_get_main_queue()];
    
    [self waitForExpectationsWithTimeout:kDefaultWaitTime handler:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];

    XCTestExpectation *exp4 = [self expectationWithDescription:@"d4 write"];
    NSData *d4 = [data subdataWithRange:r4];
    [stream appendBytes:d4.bytes length:d4.length callback:^(NSError *error) {
        [exp4 fulfill];
    } queue:dispatch_get_main_queue()];

    XCTAssertFalse([stream isComplete]);

    XCTestExpectation *exp5 = [self expectationWithDescription:@"d5 write"];
    NSData *d5 = [data subdataWithRange:r5];
    [stream appendData:d5 callback:^(NSError *error) {
        [exp5 fulfill];
    } queue:dispatch_get_main_queue()];


    // Now check read data
    XCTestExpectation *readExp = [self expectationWithDescription:@"Read whole data"];

    NSData * __block readAllData = nil;
    [stream readAllDataWithCallback:^(NSData *continousData, NSError *error) {
        readAllData = continousData;
        XCTAssertNil(error);
        [readExp fulfill];
    } queue:dispatch_get_main_queue()];

    XCTestExpectation *expFinalize1 = [self expectationWithDescription:@"finalize"];
    [stream finalize: ^{
        [expFinalize1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:4.0 handler:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];

    XCTAssertTrue([stream isComplete]);

    XCTAssertEqualObjects(readAllData, data);
}

#pragma mark - Internal methods

- (void)putFile:(NSString *)file
        inCache:(SPTPersistentDataCache *)cache
        withKey:(NSString *)key
            ttl:(NSUInteger)ttl
         locked:(BOOL)locked
{
    NSData *data = [NSData dataWithContentsOfFile:file];
    XCTAssertNotNil(data, @"Unable to get data from file:%@", file);
    XCTAssertNotNil(key, @"Key must be specified");

    [cache storeData:data forKey:key ttl:ttl locked:locked withCallback:^(SPTPersistentCacheResponse *response) {
        if (response.result == PDC_DATA_OPERATION_SUCCEEDED) {
            XCTAssertNil(response.record, @"record expected to be nil");
            XCTAssertNil(response.error, @"error xpected to be nil");
        } else if (response.result == PDC_DATA_OPERATION_ERROR) {
            XCTAssertNil(response.record, @"record expected to be nil");
            XCTAssertNotNil(response.error, @"error must exist for when STORE failed");
        } else {
            XCTAssert(NO, @"This is not expected result code for STORE operation");
        }

        [self.asyncHelper endTest];
    } onQueue:dispatch_get_main_queue()];
}

/*
PDC_ERROR_MAGIC_MISSMATCH,
PDC_ERROR_WRONG_HEADER_SIZE,
PDC_ERROR_WRONG_PAYLOAD_SIZE,
PDC_ERROR_INVALID_HEADER_CRC,
PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER,
*/

- (void)corruptFile:(NSString *)filePath
           pdcError:(int)pdcError
{
    unsigned flags = O_RDWR;
    if (pdcError == PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER) {
        flags |= O_TRUNC;
    }

    int fd = open([filePath UTF8String], flags);
    if (fd == -1) {
        XCTAssert(fd != -1, @"Could open file for currupting");
        return;
    }

    SPTPersistentRecordHeaderType header;
    memset(&header, 0, kSPTPersistentRecordHeaderSize);

    if (pdcError != PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER) {

        ssize_t readSize = read(fd, &header, kSPTPersistentRecordHeaderSize);
        if (readSize != kSPTPersistentRecordHeaderSize) {
            XCTAssert(readSize == kSPTPersistentRecordHeaderSize, @"Header not read");
            close(fd);
            return;
        }
    }

    NSUInteger headerSize = kSPTPersistentRecordHeaderSize;

    switch (pdcError) {
        case PDC_ERROR_MAGIC_MISSMATCH:
            header.magic = 0xFFFF5454;

            break;

        case PDC_ERROR_WRONG_HEADER_SIZE:
            header.headerSize = kSPTPersistentRecordHeaderSize + 1 + arc4random_uniform(106);
            header.crc = pdc_CalculateHeaderCRC(&header);

            break;
        case PDC_ERROR_WRONG_PAYLOAD_SIZE:
            header.payloadSizeBytes += (1 + (arc4random_uniform((uint32_t)header.payloadSizeBytes) - (header.payloadSizeBytes-1)/2));
            header.crc = pdc_CalculateHeaderCRC(&header);

            break;
        case PDC_ERROR_INVALID_HEADER_CRC:
            header.crc = header.crc + 5;

            break;
        case PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER:
            headerSize = kCorruptedFileSize;
            break;

        default:
            assert(!"Gotcha!");
            break;
    }

    off_t ret = lseek(fd, SEEK_SET, 0);
    XCTAssert(ret != -1);

    ssize_t written = write(fd, &header, headerSize);
    XCTAssert(written == headerSize, @"header was not written");
    fsync(fd);
    close(fd);
}

- (void)alterUpdateTime:(uint64_t)updateTime forFileAtPath:(NSString *)filePath
{
    int fd = open([filePath UTF8String], O_RDWR);
    if (fd == -1) {
        XCTAssert(fd != -1, @"Could open file for altering");
        return;
    }

    SPTPersistentRecordHeaderType header;
    memset(&header, 0, kSPTPersistentRecordHeaderSize);

    ssize_t readSize = read(fd, &header, kSPTPersistentRecordHeaderSize);
    if (readSize != kSPTPersistentRecordHeaderSize) {
        close(fd);
        return;
    }

    header.updateTimeSec = updateTime;
    header.crc = pdc_CalculateHeaderCRC(&header);

    off_t ret = lseek(fd, SEEK_SET, 0);
    XCTAssert(ret != -1);

    ssize_t written = write(fd, &header, kSPTPersistentRecordHeaderSize);
    XCTAssert(written == kSPTPersistentRecordHeaderSize, @"header was not written");
    fsync(fd);
    close(fd);
}

- (SPTPersistentDataCache *)createCacheWithTimeCallback:(SPTDataCacheCurrentTimeSecCallback)currentTime
                                         expirationTime:(NSTimeInterval)expirationTimeSec
{
    SPTPersistentDataCacheOptions *options = [SPTPersistentDataCacheOptions new];
    options.cachePath = self.cachePath;
    options.debugOutput = ^(NSString *str) {
        NSLog(@"%@", str);
    };
    options.currentTimeSec = currentTime;
    options.defaultExpirationPeriodSec = expirationTimeSec;

    return [[SPTPersistentDataCache alloc] initWithOptions:options];
}

- (NSUInteger)getFilesNumberAtPath:(NSString *)path
{
    NSUInteger count = 0;
    NSURL *urlPath = [NSURL URLWithString:path];
    NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:urlPath
                                                                includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                              errorHandler:nil];

    // Enumerate the dirEnumerator results, each value is stored in allURLs
    for (NSURL *theURL in dirEnumerator) {

        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {
                ++count;
            }
        }
    }

    return count;
}

- (void)checkUpdateTimeForFileAtPath:(NSString *)path validate:(BOOL)validate referenceTimeCheck:(void(^)(uint64_t updateTime))timeCheck
{
    XCTAssertNotNil(path, @"Path is nil");
    SPTPersistentRecordHeaderType header;
    if (validate) {
        XCTAssertTrue(spt_test_ReadHeaderForFile(path.UTF8String, validate, &header), @"Unable to read and validate header");
        timeCheck(header.updateTimeSec);
    }
}

- (NSUInteger)dataSizeForItem:(NSString *)item
{
    NSString *fileName = [self.thisBundle pathForResource:item ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    XCTAssertNotNil(data, @"Data must be valid");
    return [data length];
}

- (NSUInteger)calculateExpectedSize
{
    NSUInteger expectedSize = 0;

    for (unsigned i = 0; i < self.imageNames.count; ++i) {
        if (kParams[i].corruptReason == PDC_ERROR_NOT_ENOUGH_DATA_TO_GET_HEADER) {
            expectedSize += kCorruptedFileSize;
        } else {
            expectedSize += ([self dataSizeForItem:self.imageNames[i]] + kSPTPersistentRecordHeaderSize);
        }
    }

    return expectedSize;
}

- (id<SPTPersistentDataStream>)openStreamWithIndex:(NSInteger)index onCache:(SPTPersistentDataCache *)cache
{
    [self.asyncHelper startTest];
    id<SPTPersistentDataStream> __block stream = nil;
    [cache openDataStreamForKey:self.imageNames[index] createIfNotExist:NO ttl:0 locked:NO
                   withCallback:^(SPTDataCacheResponseCode result, id<SPTPersistentDataStream> s, NSError *error) {
                       stream = s;
                       XCTAssertNotNil(s);
                       XCTAssertNil(error);
                       [self.asyncHelper endTest];
                   } onQueue:dispatch_get_main_queue()];

    [self.asyncHelper waitForTestGroupSync];
    return stream;
}

@end

static BOOL spt_test_ReadHeaderForFile(const char* path, BOOL validate, SPTPersistentRecordHeaderType *header)
{
    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        return NO;
    }

    assert(header != NULL);
    memset(header, 0, kSPTPersistentRecordHeaderSize);

    ssize_t readSize = read(fd, header, kSPTPersistentRecordHeaderSize);
    close(fd);

    if (readSize != kSPTPersistentRecordHeaderSize) {
        return NO;
    }

    if (validate && pdc_ValidateHeader(header) != -1) {
        return NO;
    }

    uint32_t crc = pdc_CalculateHeaderCRC(header);
    return crc == header->crc;
}

static int params_GetFilesNumber(BOOL locked)
{
    int c = 0;
    for (unsigned i = 0; kParams[i].last != YES; ++i) {
        if (kParams[i].corruptReason == -1) {
            c += (kParams[i].locked == locked) ? 1 : 0;
        }
    }
    return c;
}

static int params_GetCorruptedFilesNumber(void)
{
    int c = 0;
    for (unsigned i = 0; kParams[i].last != YES; ++i) {
        if (kParams[i].corruptReason != -1) {
            c += 1;
        }
    }
    return c;
}

static int params_GetDefaultExpireFilesNumber(void)
{
    int c = 0;
    for (unsigned i = 0; kParams[i].last != YES; ++i) {
        if (kParams[i].ttl == 0 &&
            kParams[i].corruptReason == -1 &&
            kParams[i].locked == NO) {
            c += 1;
        }
    }
    return c;
}

static int params_GetFilesWithTTLNumber(BOOL locked)
{
    int c = 0;
    for (unsigned i = 0; kParams[i].last != YES; ++i) {
        if (kParams[i].ttl > 0 &&
            kParams[i].corruptReason == -1 &&
            kParams[i].locked == locked) {
            c += 1;
        }
    }
    return c;
}
