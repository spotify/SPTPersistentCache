// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <SPTPersistentCache/SPTPersistentCacheResponse.h>

extern NSString *NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCode code);

@interface SPTPersistentCacheResponse (Private)

- (instancetype)initWithResult:(SPTPersistentCacheResponseCode)result
                         error:(NSError *)error
                        record:(SPTPersistentCacheRecord *)record;

@end
