/*
 Copyright (c) 2019 Spotify AB.

 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */
#import "SPTPersistentCacheRecord.h"
#import "SPTPersistentCacheObjectDescription.h"

@implementation SPTPersistentCacheRecord

#pragma mark SPTPersistentCacheRecord

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    refCount:(NSUInteger)refCount
                         ttl:(NSUInteger)ttl
{
    self = [super init];
    if (self) {
        _refCount = refCount;
        _ttl = ttl;
        _key = [key copy];
        _data = [data copy];
    }
    return self;
}

#pragma mark Describing Object

- (NSString *)description
{
    return SPTPersistentCacheObjectDescription(self, self.key, @"key");
}

- (NSString *)debugDescription
{
    return SPTPersistentCacheObjectDescription(self, self.key, @"key", @(self.ttl), @"ttl", @(self.refCount), @"ref-count");
}

@end
