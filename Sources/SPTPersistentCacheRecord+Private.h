// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <SPTPersistentCache/SPTPersistentCacheRecord.h>

@interface SPTPersistentCacheRecord (Private)

- (instancetype)initWithData:(NSData *)data
                         key:(NSString *)key
                    refCount:(NSUInteger)refCount
                         ttl:(NSUInteger)ttl;

@end
