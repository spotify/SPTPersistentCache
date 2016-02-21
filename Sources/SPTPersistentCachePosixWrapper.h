#import <Foundation/Foundation.h>

/**
 * An Obj-C wrapper for POSIX functions mainly made for mocking functions during unit tests.
 */
@interface SPTPersistentCachePosixWrapper : NSObject

/**
 * See POSIX "close"
 * @param descriptor The file descriptor to close.
 */
- (int)close:(int)descriptor;

@end
