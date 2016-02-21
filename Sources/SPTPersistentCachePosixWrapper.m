#import "SPTPersistentCachePosixWrapper.h"

@implementation SPTPersistentCachePosixWrapper

- (int)close:(int)descriptor
{
    return close(descriptor);
}

@end
