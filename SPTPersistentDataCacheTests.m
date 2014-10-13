
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "SPTPersistentDataHeader.h"
#import "SPTPersistentDataCache.h"

#import "SPTAsyncTestHelper.h"

//{b91998ae68b9639cee6243df0886d69bdeb75854 : https://i.scdn.co/image/387965e9e126b40e5b2e6158d4c15d78939b7b8c}
//{c3b19963fc076930dd36ce3968757704bbc97357 : https://i.scdn.co/image/0945a08f2bd84bec6f8b20d38436aa8b209ffda1}
//{fc22d4f65c1ba875f6bb5ba7d35a7fd12851ed5c : https://i.scdn.co/image/672173dbd2491301ae8ee83b948a0632b2c41ddc}
//{c5aec3eef2478bfe47aef16787a6b4df31eb45f2 : https://i.scdn.co/image/696c3753a6fb43a9ffec4e3907321b60348491f5}
//{ee678d23b8dba2997c52741e88fa7a1fdeaf2863 : https://i.scdn.co/image/5a3eb42b3ffc9d87b806f081f207bfb0f31b07e6}
//{f7501f27f70162a9a7da196c5d2ece3151a2d80a : https://i.scdn.co/image/db02388b27e91421929546ba260c6aa5233e1669}
//{e5a1921f8f75d42412e08aff4da33e1132f7ee8a : https://i.scdn.co/image/65d0bea9ffb748f5639850016a1eb62ab3bf98ca}
//{e5b8abdc091921d49e86687e28b74abb3139df70 : https://i.scdn.co/image/f16b52d2e5883a6b991fbf076162d3ed9ead0594}
//{ee6b44ab07fa3937a6d37f449355b64c09677295 : https://i.scdn.co/image/2ac519ea92d81ec88e079f70914d25c3ea1a973b}
//{f50512901688b79a7852999d384d097a71fad788 : https://i.scdn.co/image/c500b4ecda09b2b5ffb5141a98b414213bec90c5}
//{f1eeb834607dcc2b01909bd740d4356f2abb4cd1 : https://i.scdn.co/image/e5e1a8ae0c28892d86bb9e976583e091238d2deb} //big

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
    "f1eeb834607dcc2b01909bd740d4356f2abb4cd1",
    NULL
};
typedef struct
{
    uint64_t ttl;
    BOOL locked;
    BOOL last;
} StoreParamsType;

static const uint64_t kTTL1 = 7200;
static const uint64_t kTTL2 = 604800;
static const uint64_t kTTL3 = 600;
static const uint64_t kTTL4 = 86400;

static const StoreParamsType kParams[] = {
    {0,     YES, NO},
    {0,     YES, NO},
    {0,     NO, NO},
    {0,     NO, NO},
    {kTTL1, YES, NO},
    {kTTL2, YES, NO},
    {kTTL3, NO, NO},
    {kTTL4, NO, NO},
    {0,     NO, NO},
    {0,     NO, NO},
    {0,     NO, NO}, // 11
    {kTTL4, NO, YES}
};

@interface SPTPersistentDataCacheTests : XCTestCase
@property (nonatomic, strong) SPTPersistentDataCache *cache;
@property (nonatomic, strong) NSMutableArray *imageNames;
@property (nonatomic, strong) NSString *cachePath;
@property (nonatomic, strong) SPTAsyncTestHelper *asyncHelper;
@end

@implementation SPTPersistentDataCacheTests

- (void)setUp {
    [super setUp];

    // Form array of images for shuffling
    self.imageNames = [NSMutableArray array];

    {
        int i = 0;
        while (kImages[i] != NULL) {
            [self.imageNames addObject:@(kImages[i++])];
        }
    }

    @autoreleasepool {

        int count = self.imageNames.count-1;
        while (count >= 0) {
            uint32_t idx = arc4random_uniform(count+1);
            NSString * tmp = self.imageNames[count];
            self.imageNames[count] = self.imageNames[idx];
            self.imageNames[idx] = tmp;
            count--;
        }
    }

    self.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"pdc-%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]]];

    NSLog(@"%@", self.cachePath);

    self.cache = [self createCache];

    NSBundle *b = [NSBundle bundleForClass:[self class]];

    self.asyncHelper = [SPTAsyncTestHelper new];

    dispatch_apply(self.imageNames.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
        [self.asyncHelper startTest];

        XCTAssert(kParams[i].last != YES, @"Last param element reached");
        NSString *fileName = [b pathForResource:self.imageNames[i] ofType:nil];
        [self putFile:fileName withKey:self.imageNames[i] ttl:kParams[i].ttl locked:kParams[i].locked];
    });

    [self.asyncHelper waitForTestGroupSync];

    self.asyncHelper = nil;
    self.cache = nil;
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:nil];
    self.cache = nil;
    [super tearDown];
}

- (void)testCorrectWriteAndReadConcurrent
{
    SPTPersistentDataCache *cache = [self createCache];
    SPTAsyncTestHelper *asyncHelper = [SPTAsyncTestHelper new];

    int __block calls = 0;
    dispatch_apply(self.imageNames.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
        [asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {

            calls += 1;

            if (response.result == PDC_DATA_LOADED) {
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

            } else if (response.result == PDC_DATA_LOADING_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            [asyncHelper endTest];
        } onQueue:dispatch_get_main_queue()];

        XCTAssert(kParams[i].last != YES, @"Last param element reached");
    });

    [asyncHelper waitForTestGroupSync];
    XCTAssertEqual(calls, self.imageNames.count, @"Number of checked files must match");
}

- (void)testLockUnlock
{
    SPTPersistentDataCache *cache = [self createCache];
    SPTAsyncTestHelper *asyncHelper = [SPTAsyncTestHelper new];

    NSMutableArray *toLock = [NSMutableArray array];
    NSMutableArray *toUnlock = [NSMutableArray array];

    unsigned count = self.imageNames.count;
    for (unsigned i = 0; i < count; ++i) {
        if (kParams[i].locked) {
            [toUnlock addObject:self.imageNames[i]];
        } else {
            [toLock addObject:self.imageNames[i]];
        }
    }

    [cache lockDataForKeys:toLock];
    [cache unlockDataForKeys:toUnlock];

    int __block calls = 0;
    dispatch_apply(self.imageNames.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
        [asyncHelper startTest];

        [cache loadDataForKey:self.imageNames[i] withCallback:^(SPTPersistentCacheResponse *response) {

            if (response.result == PDC_DATA_LOADED) {
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

            } else if (response.result == PDC_DATA_LOADING_ERROR) {
                XCTAssertNil(response.record, @"Expected valid nil record");
                XCTAssertNotNil(response.error, @"Valid error is expected to be here");

            } else {
                XCTAssert(NO, @"Unexpected result code on LOAD");
            }

            calls += 1;
        } onQueue:dispatch_get_main_queue()];
    });

    [asyncHelper waitForTestGroupSync];
    XCTAssertEqual(calls, self.imageNames.count, @"Number of checked files must match");
}

- (void)testPureCache
{
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
}

- (void)putFile:(NSString *)file
        withKey:(NSString *)key
            ttl:(NSUInteger)ttl
         locked:(BOOL)locked
{
    NSData *data = [NSData dataWithContentsOfFile:file];
    XCTAssertNotNil(data, @"Unable to get data from file:%@", file);
    XCTAssertNotNil(key, @"Key must be specified");

    [self.cache storeData:data forKey:key ttl:ttl locked:locked withCallback:^(SPTPersistentCacheResponse *response) {
        [self.asyncHelper endTest];
        if (response.result == PDC_DATA_STORED) {
            XCTAssertNil(response.record, @"record expected to be nil");
            XCTAssertNil(response.error, @"error xpected to be nil");
        } else if (response.result == PDC_DATA_STORE_ERROR) {
            XCTAssertNil(response.record, @"record expected to be nil");
            XCTAssertNotNil(response.error, @"error must exist for when STORE failed");
        } else {
            XCTAssert(NO, @"This is not expected result code for STORE operation");
        }
    } onQueue:dispatch_get_main_queue()];
}

- (void)putFile:(NSString *)file
        withKey:(NSString *)key
     expiration:(NSUInteger)expiratoin
            ttl:(NSUInteger)ttl
       refCount:(NSUInteger)refCount
corruptPayloadSize:(BOOL)corruptPayloadSize
corruptHeaderSize:(BOOL)corruptHeaderSize
{
    NSData *data = [NSData dataWithContentsOfFile:file];
    XCTAssertNotNil(data, @"Unable to get data from file:%@", file);
    XCTAssertNotNil(key, @"Key must be specified");

    SPTPersistentRecordHeaderType header;
    memset(&header, 0, kSPTPersistentRecordHeaderSize);

}

- (SPTPersistentDataCache *)createCache
{
    SPTPersistentDataCacheOptions *options = [SPTPersistentDataCacheOptions new];
    options.cachePath = self.cachePath;
    options.debugOutput = ^(NSString *str) {
        NSLog(@"%@", str);
    };

    return [[SPTPersistentDataCache alloc] initWithOptions:options];
}

@end
