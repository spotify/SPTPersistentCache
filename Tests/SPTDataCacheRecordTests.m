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

#import <XCTest/XCTest.h>
#import "SPTDataCacheRecord.h"
#import "SPTDataCacheRecord+Private.h"


static const NSUInteger SPTDataCacheRecordTestRefCount = 43244555;
static const NSUInteger SPTDataCacheRecordTestTTL = 43244555;
static NSString * const SPTDataCacheRecordTestKey = @"key1";
static NSString * const SPTDataCacheRecordTestDataString = @"https://spotify.com";

@interface SPTDataCacheRecordTests : XCTestCase
@property (nonatomic, strong) SPTDataCacheRecord *dataCacheRecord;
@end

@implementation SPTDataCacheRecordTests

- (void)setUp
{
    [super setUp];
    
    NSData * const testData =[SPTDataCacheRecordTestDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    self.dataCacheRecord = [[SPTDataCacheRecord alloc] initWithData:testData
                                                                key:SPTDataCacheRecordTestKey
                                                           refCount:SPTDataCacheRecordTestRefCount
                                                                ttl:SPTDataCacheRecordTestTTL];
}

- (void)testDesignatedInitializer
{
    XCTAssertEqualObjects(self.dataCacheRecord.data, [SPTDataCacheRecordTestDataString dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(self.dataCacheRecord.key, SPTDataCacheRecordTestKey);
    XCTAssertEqual(self.dataCacheRecord.refCount, SPTDataCacheRecordTestRefCount);
    XCTAssertEqual(self.dataCacheRecord.ttl, SPTDataCacheRecordTestTTL);
}

@end
