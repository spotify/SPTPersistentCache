#import "SPTPersistentCachePosixWrapperMock.h"

@implementation SPTPersistentCachePosixWrapperMock

- (int)close:(int)descriptor
{
    return self.closeValue;
}

@end
