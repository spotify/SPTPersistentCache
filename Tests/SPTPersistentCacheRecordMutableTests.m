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

#import <XCTest/XCTest.h>
#import "SPTPersistentCacheRecord.h"
#import "SPTPersistentCacheRecord+Private.h"
#import <string.h>

static const NSUInteger SPTPersistentCacheRecordTestSamplesCount = 10;
static const NSUInteger SPTPersistentCacheRecordTestRefCount = 43244555;
static const NSUInteger SPTPersistentCacheRecordTestTTL = 43244555;

@interface SPTPersistentCacheRecordMutableTests : XCTestCase
@end

@implementation SPTPersistentCacheRecordMutableTests

- (void)testSPTPersistentCacheRecordWithMutableData {
    NSMutableArray<NSData *> *dataSamples = [NSMutableArray arrayWithCapacity: SPTPersistentCacheRecordTestSamplesCount];
    NSMutableArray<SPTPersistentCacheRecord *> *cacheRecords = [NSMutableArray arrayWithCapacity: SPTPersistentCacheRecordTestSamplesCount];

    NSMutableData *d = [NSMutableData dataWithLength:sizeof(NSUInteger)];
    for (NSUInteger i = 0; i < SPTPersistentCacheRecordTestSamplesCount; i++) {
        memcpy(d.mutableBytes, &i, sizeof(i));
        [dataSamples addObject: [d copy]];
        SPTPersistentCacheRecord *record = [[SPTPersistentCacheRecord alloc] initWithData: d key: [NSString stringWithFormat:@"key%lu", i] refCount: SPTPersistentCacheRecordTestRefCount ttl:SPTPersistentCacheRecordTestTTL];
        [cacheRecords addObject: record];
    }

    for (NSUInteger i = 0; i < SPTPersistentCacheRecordTestSamplesCount; i++) {
        XCTAssertEqualObjects(cacheRecords[i].data, dataSamples[i]);
    }
}

@end
