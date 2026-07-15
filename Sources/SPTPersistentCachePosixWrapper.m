// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCachePosixWrapper.h"

@implementation SPTPersistentCachePosixWrapper

- (int)close:(int)descriptor
{
    return close(descriptor);
}

- (ssize_t)read:(int)descriptor buffer:(void *)buffer bufferSize:(size_t)bufferSize
{
    return read(descriptor, buffer, bufferSize);
}

- (off_t)lseek:(int)descriptor seekType:(off_t)seekType seekAmount:(int)seekAmount
{
    return lseek(descriptor, seekType, seekAmount);
}

- (ssize_t)write:(int)descriptor buffer:(const void *)buffer bufferSize:(size_t)bufferSize
{
    return write(descriptor, buffer, bufferSize);
}

- (int)fsync:(int)descriptor
{
    return fsync(descriptor);
}

- (int)stat:(const char *)path statStruct:(struct stat *)statStruct
{
    return stat(path, statStruct);
}

@end
