#import <XCTest/XCTest.h>
#import "NSError+SPTPersistentCacheDomainErrors.h"


@interface NSError_SPTPersistentCacheDomainErrorsTests : XCTestCase

@end

@implementation NSError_SPTPersistentCacheDomainErrorsTests


- (void)testPersistentDataCacheErrorFactoryMethod
{
    SPTPersistentCacheLoadingError errorCode = SPTPersistentCacheLoadingErrorHeaderAlignmentMismatch;
    
    NSError *error = [NSError spt_persistentDataCacheErrorWithCode:SPTPersistentCacheLoadingErrorHeaderAlignmentMismatch];
    
    XCTAssertEqual(error.domain, SPTPersistentCacheErrorDomain);
    XCTAssertEqual(error.code, errorCode);
}


@end
