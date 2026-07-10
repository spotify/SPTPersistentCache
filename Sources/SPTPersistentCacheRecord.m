// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <SPTPersistentCache/SPTPersistentCacheRecord.h>
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
        _data = data;
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
