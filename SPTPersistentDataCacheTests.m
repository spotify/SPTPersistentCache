
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "SPTPersistentDataHeader.h"
#import "SPTPersistentDataCache.h"

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

@interface SPTPersistentDataCacheTests : XCTestCase
@property (nonatomic, strong) SPTPersistentDataCache *cache;
@end

@implementation SPTPersistentDataCacheTests

- (void)setUp {
    [super setUp];

    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"pdc-%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]]];


    SPTPersistentDataCacheOptions *options = [SPTPersistentDataCacheOptions new];
    options.cachePath = cachePath;
    options.debugOutput = ^(NSString *str) {
        NSLog(@"%@", str);
    };

    self.cache = [[SPTPersistentDataCache alloc] initWithOptions:options];
    NSString *s = [[NSBundle bundleForClass:[self class]] pathForResource:@"b91998ae68b9639cee6243df0886d69bdeb75854" ofType:nil];
    NSLog(@"%@",s);
}

- (void)tearDown
{
    self.cache = nil;
    [super tearDown];
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

- (void)testPureCache
{
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
}

@end
