// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <SPTPersistentCache/SPTPersistentCacheResponse.h>
#import <SPTPersistentCache/SPTPersistentCacheRecord.h>
#import "SPTPersistentCacheObjectDescription.h"
#import "SPTPersistentCacheResponse+Private.h"

@interface SPTPersistentCacheResponse ()

@property (nonatomic, assign, readwrite) SPTPersistentCacheResponseCode result;
@property (nonatomic, strong, readwrite) NSError *error;
@property (nonatomic, strong, readwrite) SPTPersistentCacheRecord *record;

@end

@implementation SPTPersistentCacheResponse

- (instancetype)initWithResult:(SPTPersistentCacheResponseCode)result
                         error:(NSError *)error
                        record:(SPTPersistentCacheRecord *)record
{
    self = [super init];
    if (self) {
        _result = result;
        _error = error;
        _record = record;
    }
    return self;
}

#pragma mark Describing Object

NSString *NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCode code)
{
    switch (code) {
        case SPTPersistentCacheResponseCodeNotFound:            return @"not-found";
        case SPTPersistentCacheResponseCodeOperationError:      return @"operation-error";
        case SPTPersistentCacheResponseCodeOperationSucceeded:  return @"operation-success";
    }
}

- (NSString *)description
{
    return SPTPersistentCacheObjectDescription(self, NSStringFromSPTPersistentCacheResponseCode(self.result), @"result");
}

- (NSString *)debugDescription
{
    return SPTPersistentCacheObjectDescription(self,
                                               NSStringFromSPTPersistentCacheResponseCode(self.result), @"result",
                                               self.record.debugDescription, @"record",
                                               self.error.debugDescription, @"error");
}

@end
