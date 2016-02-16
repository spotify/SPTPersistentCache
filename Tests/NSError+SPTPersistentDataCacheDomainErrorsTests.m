#import <XCTest/XCTest.h>
#import "NSError+SPTPersistentDataCacheDomainErrors.h"


@interface NSError_SPTPersistentDataCacheDomainErrorsTests : XCTestCase

@end

@implementation NSError_SPTPersistentDataCacheDomainErrorsTests


- (void)testPersistentDataCacheErrorFactoryMethod
{
    SPTPersistentDataCacheLoadingError errorCode = SPTPersistentDataCacheLoadingErrorHeaderAlignmentMismatch;
    
    NSError *error = [NSError spt_persistentDataCacheErrorWithCode:SPTPersistentDataCacheLoadingErrorHeaderAlignmentMismatch];
    
    XCTAssertEqual(error.domain, SPTPersistentDataCacheErrorDomain);
    XCTAssertEqual(error.code, errorCode);
}


@end
