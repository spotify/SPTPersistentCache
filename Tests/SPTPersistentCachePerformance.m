#import <XCTest/XCTest.h>
#import <mach/mach_time.h>

#import <SPTPersistentCache/SPTPersistentCache.h>
double convertMachToMilliSeconds(uint64_t mach_time);

static const char* kFileNames[] = {
    "aad0e75ab0a6828d0a9b37a68198cc9d70d84850",
    "ab3d97d4d7b3df5417490aa726c5a49b9ee98038",
    "b02c1be08c00bac5f4f1a62c6f353a24487bb024",
    "b3e04bf446b486412a13659af71e3a333c6152f4",
    "b53aed36cdc67dd43b496db74843ac32fe1f64bb",
    "b91998ae68b9639cee6243df0886d69bdeb75854",
    "c3b19963fc076930dd36ce3968757704bbc97357",
    "c5aec3eef2478bfe47aef16787a6b4df31eb45f2",
    "e5a1921f8f75d42412e08aff4da33e1132f7ee8a",
    "e5b8abdc091921d49e86687e28b74abb3139df70",
    "ee6b44ab07fa3937a6d37f449355b64c09677295",
    "ee678d23b8dba2997c52741e88fa7a1fdeaf2863",
    "eee9747e967c4440eb90bb812d148aa3d0056700",
    "f1eeb834607dcc2b01909bd740d4356f2abb4cd1",
    "f7501f27f70162a9a7da196c5d2ece3151a2d80a",
    "f50512901688b79a7852999d384d097a71fad788",
    "fc22d4f65c1ba875f6bb5ba7d35a7fd12851ed5c",
    NULL
};

static const int SPTPersistentCachePerformanceIterationCount = 200;

@interface SPTPersistentCacheTiming : NSObject
@property (nonatomic) uint64_t queueTime;
@property (nonatomic) uint64_t startTime;
@property (nonatomic) uint64_t endTime;

- (double) calculateTimeInQueue;
- (double) calculateTimeExecuting;
- (double) calculateTotalTime;
@end

@implementation SPTPersistentCacheTiming

- (double) calculateTimeInQueue
{
    return convertMachToMilliSeconds(self.startTime) - convertMachToMilliSeconds(self.queueTime);
}
- (double) calculateTimeExecuting
{
    return convertMachToMilliSeconds(self.endTime) - convertMachToMilliSeconds(self.startTime);
}
- (double) calculateTotalTime
{
    return convertMachToMilliSeconds(self.endTime) - convertMachToMilliSeconds(self.queueTime);
}

@end

@interface SPTPersistentCachePerformance : XCTestCase


@property (nonatomic, strong) SPTPersistentCache *dataCache;
@property (nonatomic, strong) NSMutableArray<NSData *> *fileContents;
@property (nonatomic, strong) NSMutableArray<SPTPersistentCacheTiming *> *unLockTimings;
@property (nonatomic, strong) NSMutableArray<SPTPersistentCacheTiming *> *readTimings;
@property (nonatomic, strong) NSString *cachePath;

@end

@implementation SPTPersistentCachePerformance

- (void)setUp
{
    [super setUp];
    self.fileContents = [NSMutableArray array];

    self.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"pdc-%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]]];

    NSLog(@"%@", self.cachePath);

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    int i = 0;
    while (kFileNames[i] != NULL) {
        NSString *fileName = [bundle pathForResource:@(kFileNames[i++]) ofType:nil];
        [self.fileContents addObject:[NSData dataWithContentsOfFile:fileName]];
    }

    self.unLockTimings = [NSMutableArray arrayWithCapacity:SPTPersistentCachePerformanceIterationCount];
    self.readTimings = [NSMutableArray arrayWithCapacity:SPTPersistentCachePerformanceIterationCount];
    for (int i = 0; i < SPTPersistentCachePerformanceIterationCount; i++) {
        self.unLockTimings[i] = (SPTPersistentCacheTiming *)[NSNull null];
        self.readTimings[i] = (SPTPersistentCacheTiming *)[NSNull null];
    }

    //Setup a cache
    SPTPersistentCacheOptions *options = [[SPTPersistentCacheOptions alloc] init];
    options.cachePath = self.cachePath;
    options.timingCallback = ^(NSString *key, SPTPersistentCacheDebugMethodType method, SPTPersistentCacheDebugTimingType type, uint64_t machTime){
        NSMutableArray<SPTPersistentCacheTiming *> *timings = nil;
        switch (method) {
            case SPTPersistentCacheDebugMethodTypeUnlock:
                timings = self.unLockTimings;
                break;
            case SPTPersistentCacheDebugMethodTypeRead:
                timings = self.readTimings;
                break;
            default:
                break;
        }
        if (timings == nil) {
            return;
        }
        int index = [[key stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n(),"]] intValue];
        SPTPersistentCacheTiming *timing = timings[index];
        if ([[NSNull null] isEqual:timing]) {
            timing = [[SPTPersistentCacheTiming alloc] init];
            timings[index] = timing;
        }
        switch (type) {
            case SPTPersistentCacheDebugTimingTypeStarting:
                timing.startTime = machTime;
                break;

            case SPTPersistentCacheDebugTimingTypeQueued:
                timing.queueTime = machTime;
                break;
            case SPTPersistentCacheDebugTimingTypeFinished:
                timing.endTime = machTime;
                break;
        }
    };
    self.dataCache = [[SPTPersistentCache alloc] initWithOptions:options];
}

- (void)tearDown
{
    //NSLog(@"**** %s total execution time %f", __PRETTY_FUNCTION__, convertMachToMilliSeconds(executionTime));

    NSError *error = nil;
    if(![[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:&error]){
        NSLog(@"Error removing cache: %@", error);
    }

    [super tearDown];
}

- (void)testUnlockPlusReads
{

    //Load with data & lock
    for (int i = 0; i < SPTPersistentCachePerformanceIterationCount; i++) {
        int fileIndex = i % self.fileContents.count;
        NSData *data = self.fileContents[fileIndex];
        NSString *key = [NSString stringWithFormat:@"%d", i];
        __weak XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@ store", key]];
        [self.dataCache storeData:data forKey:key locked:YES withCallback:^(SPTPersistentCacheResponse * _Nonnull response) {
            [expectation fulfill];
        } onQueue:dispatch_get_main_queue()];
    }
    //Wait till all data is loaded
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    //Sleep to make sure everything is settled down
    [NSThread sleepForTimeInterval:5];

    //Queue unlock data
    for (int i = 0; i < SPTPersistentCachePerformanceIterationCount; i++) {
        NSString *key = [NSString stringWithFormat:@"%d", i];
        __weak XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@ unlock", key]];
        [self.dataCache unlockDataForKeys:@[key] callback:^(SPTPersistentCacheResponse * _Nonnull response) {
            [expectation fulfill];
        } onQueue:dispatch_get_main_queue()];
    }

    //Queue read data
    for (int i = 0; i < SPTPersistentCachePerformanceIterationCount; i++) {
        NSString *key = [NSString stringWithFormat:@"%d", i];
        __weak XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@ read", key]];
        [self.dataCache loadDataForKey:key withCallback:^(SPTPersistentCacheResponse * _Nonnull response) {
            [expectation fulfill];
        } onQueue:dispatch_get_main_queue()];
    }

    [self waitForExpectationsWithTimeout:60 handler:nil];

    //Report times
    for (SPTPersistentCacheTiming *timing in self.unLockTimings) {
        NSLog(@"****Unlock Queue time %f, execution time: %f total time:%f", [timing calculateTimeInQueue],
              [timing calculateTimeExecuting],
              [timing calculateTotalTime]);
    }
    for (SPTPersistentCacheTiming *timing in self.readTimings) {
        NSLog(@"****Read Queue time %f, execution time: %f total time:%f", [timing calculateTimeInQueue],
              [timing calculateTimeExecuting],
              [timing calculateTotalTime]);
    }
}

double convertMachToMilliSeconds(uint64_t mach_time)
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);

    const double timeNS = (double)mach_time * (double)info.numer / (double)info.denom;

    return timeNS/1000000;
}

@end
