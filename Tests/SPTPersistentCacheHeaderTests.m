#import <XCTest/XCTest.h>
#import "SPTPersistentCacheHeader.h"


@interface SPTPersistentCacheHeaderTests : XCTestCase

@end

@implementation SPTPersistentCacheHeaderTests

- (void)testGetHeaderFromDataWithSmallSizeData
{
    size_t smallerSize = SPTPersistentCacheRecordHeaderSize - 1;
    void *smallData = malloc(smallerSize);
    
    XCTAssertEqual(SPTPersistentCacheGetHeaderFromData(smallData, smallerSize), NULL);
    
    free(smallData);
}

- (void)testGetHeaderFromDataWithRightSize
{
    size_t rightHeaderSize = SPTPersistentCacheRecordHeaderSize;
    void *data = malloc(rightHeaderSize);
    
    XCTAssertEqual(SPTPersistentCacheGetHeaderFromData(data, rightHeaderSize), data);
    
    free(data);
}

@end
