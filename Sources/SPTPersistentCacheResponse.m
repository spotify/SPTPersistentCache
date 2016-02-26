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
