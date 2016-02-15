#import <XCTest/XCTest.h>
#import "SPTPersistentDataCacheHeader.h"


@interface SPTPersistentDataCacheHeaderTests : XCTestCase

@end

@implementation SPTPersistentDataCacheHeaderTests

- (void)testGetHeaderFromDataWithSmallSizeData
{
    size_t smallerSize = SPTPersistentDataCacheRecordHeaderSize - 1;
    void *smallData = malloc(smallerSize);
    
    XCTAssertEqual(SPTPersistentDataCacheGetHeaderFromData(smallData, smallerSize), NULL);
    
    free(smallData);
}

- (void)testGetHeaderFromDataWithRightSize
{
    size_t rightHeaderSize = SPTPersistentDataCacheRecordHeaderSize;
    void *data = malloc(rightHeaderSize);
    
    XCTAssertEqual(SPTPersistentDataCacheGetHeaderFromData(data, rightHeaderSize), data);
    
    free(data);
}

@end
