#import <XCTest/XCTest.h>
#import "SPTPersistentCacheDebugUtilities.h"


@interface SPTPersistentCacheDebugUtilitiesTests : XCTestCase
@end

@implementation SPTPersistentCacheDebugUtilitiesTests

- (void)testNilDebugCallback
{
    XCTAssertNoThrow(SPTPersistentCacheSafeDebugCallback(@"",
                                                         nil),
                     @"A nil callback shouldn't cause an exception.");
}

- (void)testDebugCallback
{
    __block NSString *stringSetInsideBlock = nil;
    
    NSString *testString = @"Test";
    SPTPersistentCacheSafeDebugCallback(testString, ^(NSString *message){
        stringSetInsideBlock = message;
    });
    
    XCTAssertEqualObjects(stringSetInsideBlock,
                          testString,
                          @"The debug callback was not executed. :{");
}

@end
