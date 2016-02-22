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

@end
