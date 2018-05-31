/*
 * Copyright (c) 2018 Spotify AB.
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
