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
#import "SPTPersistentCacheRecord.h"
#import "SPTPersistentCacheRecord+Private.h"


static const NSUInteger SPTPersistentCacheRecordTestRefCount = 43244555;
static const NSUInteger SPTPersistentCacheRecordTestTTL = 43244555;
static NSString * const SPTPersistentCacheRecordTestKey = @"key1";
static NSString * const SPTPersistentCacheRecordTestDataString = @"https://spotify.com";

@interface SPTPersistentCacheRecordTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheRecord *dataCacheRecord;
@end

@implementation SPTPersistentCacheRecordTests

- (void)setUp
{
    [super setUp];
    
    NSData * const testData =[SPTPersistentCacheRecordTestDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    self.dataCacheRecord = [[SPTPersistentCacheRecord alloc] initWithData:testData
                                                                key:SPTPersistentCacheRecordTestKey
                                                           refCount:SPTPersistentCacheRecordTestRefCount
                                                                ttl:SPTPersistentCacheRecordTestTTL];
}

- (void)testDesignatedInitializer
{
    XCTAssertEqualObjects(self.dataCacheRecord.data, [SPTPersistentCacheRecordTestDataString dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(self.dataCacheRecord.key, SPTPersistentCacheRecordTestKey);
    XCTAssertEqual(self.dataCacheRecord.refCount, SPTPersistentCacheRecordTestRefCount);
    XCTAssertEqual(self.dataCacheRecord.ttl, SPTPersistentCacheRecordTestTTL);
}

@end
