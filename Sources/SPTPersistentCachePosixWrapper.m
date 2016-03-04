/*
 * Copyright (c) 2016 Spotify AB.
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
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
