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

#import <XCTest/XCTest.h>
#import "SPTPersistentCacheRecord.h"
#import "SPTPersistentCacheRecord+Private.h"
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"


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

#pragma mark Test describing objects

- (void)testDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const description = self.dataCacheRecord.description;

    XCTAssertTrue([styleValidator isValidStyleDescription:description], @"The description string should follow our style.");
}

- (void)testDescriptionContainsClassName
{
    NSString * const description = self.dataCacheRecord.description;

    const NSRange classNameRange = [description rangeOfString:@"SPTPersistentCacheRecord"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the description");
}

- (void)testDebugDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const debugDescription = self.dataCacheRecord.debugDescription;

    XCTAssertTrue([styleValidator isValidStyleDescription:debugDescription], @"The debugDescription string should follow our style.");
}

- (void)testDebugDescriptionContainsClassName
{
    NSString * const debugDescription = self.dataCacheRecord.debugDescription;

    const NSRange classNameRange = [debugDescription rangeOfString:@"SPTPersistentCacheRecord"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the debugDescription");
}

@end
