// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCachePosixWrapperMock.h"

@implementation SPTPersistentCachePosixWrapperMock

- (int)close:(int)descriptor
{
    return self.closeValue;
}

- (ssize_t)read:(int)descriptor buffer:(void *)buffer bufferSize:(size_t)bufferSize
{
    if (self.readOverridden) {
        return self.readValue;
    }
    return [super read:descriptor buffer:buffer bufferSize:bufferSize];
}

- (off_t)lseek:(int)descriptor seekType:(off_t)seekType seekAmount:(int)seekAmount
{
    return self.lseekValue;
}

- (ssize_t)write:(int)descriptor buffer:(const void *)buffer bufferSize:(size_t)bufferSize
{
    return self.writeValue;
}

- (int)fsync:(int)descriptor
{
    return self.fsyncValue;
}

- (int)stat:(const char *)path statStruct:(struct stat *)statStruct
{
    return self.statValue;
}

@end
