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

#import <SPTPersistentCache/SPTPersistentCacheOptions.h>
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"

@interface SPTPersistentCacheOptionsTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheOptions *dataCacheOptions;
@end

@implementation SPTPersistentCacheOptionsTests

- (void)setUp
{
    [super setUp];

    self.dataCacheOptions = [SPTPersistentCacheOptions new];
}

- (void)testDefaultInitializer
{
    XCTAssertEqual(self.dataCacheOptions.folderSeparationEnabled, YES);
    XCTAssertEqual(self.dataCacheOptions.gcIntervalSec, SPTPersistentCacheDefaultGCIntervalSec);
    XCTAssertEqual(self.dataCacheOptions.defaultExpirationPeriodSec,
                   SPTPersistentCacheDefaultExpirationTimeSec);
    XCTAssertNotNil(self.dataCacheOptions.cachePath, @"The cache path cannot be nil");
    XCTAssertNotNil(self.dataCacheOptions.cacheIdentifier, @"The cache identifier cannot be nil");
    XCTAssertNotNil(self.dataCacheOptions.identifierForQueue, @"The identifier for queue shouldn't be nil");
}

- (void)testMinimumGarbageColectorInterval
{
    SPTPersistentCacheOptions *dataCacheOptions = [[SPTPersistentCacheOptions alloc] initWithCachePath:nil
                                                                                            identifier:@"test"
                                                                             defaultExpirationInterval:1
                                                                              garbageCollectorInterval:1
                                                                                                 debug:nil];
    XCTAssertEqual(dataCacheOptions.gcIntervalSec,
                   SPTPersistentCacheMinimumGCIntervalLimit);
}

- (void)testMinimumDefaultExpirationInterval
{
    SPTPersistentCacheOptions *dataCacheOptions = [[SPTPersistentCacheOptions alloc] initWithCachePath:nil
                                                                                            identifier:nil
                                                                             defaultExpirationInterval:1
                                                                              garbageCollectorInterval:1
                                                                                                 debug:nil];
    XCTAssertEqual(dataCacheOptions.defaultExpirationPeriodSec,
                   SPTPersistentCacheMinimumExpirationLimit);
}

#pragma mark Test describing objects

- (void)testDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const description = self.dataCacheOptions.description;

    XCTAssertTrue([styleValidator isValidStyleDescription:description], @"The description string should follow our style.");
}

- (void)testDescriptionContainsClassName
{
    NSString * const description = self.dataCacheOptions.description;

    const NSRange classNameRange = [description rangeOfString:@"SPTPersistentCacheOptions"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the description");
}

- (void)testDebugDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const debugDescription = self.dataCacheOptions.debugDescription;

    XCTAssertTrue([styleValidator isValidStyleDescription:debugDescription], @"The debugDescription string should follow our style.");
}

- (void)testDebugDescriptionContainsClassName
{
    NSString * const debugDescription = self.dataCacheOptions.debugDescription;

    const NSRange classNameRange = [debugDescription rangeOfString:@"SPTPersistentCacheOptions"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the debugDescription");
}

@end
