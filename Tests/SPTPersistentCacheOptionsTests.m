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

#import <SPTPersistentCache/SPTPersistentCacheOptions.h>
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"

static NSString * const SPTPersistentCacheOptionsPathComponent = @"com.spotify.tmp.cache";

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
    XCTAssertTrue(self.dataCacheOptions.useDirectorySeparation, @"Directory separation should be enabled");
    XCTAssertEqual(self.dataCacheOptions.garbageCollectionInterval, SPTPersistentCacheDefaultGCIntervalSec);
    XCTAssertEqual(self.dataCacheOptions.defaultExpirationPeriod, SPTPersistentCacheDefaultExpirationTimeSec);
    XCTAssertNotNil(self.dataCacheOptions.cachePath, @"The cache path cannot be nil");
    XCTAssertNotNil(self.dataCacheOptions.cacheIdentifier, @"The cache identifier cannot be nil");
    XCTAssertNotNil(self.dataCacheOptions.identifierForQueue, @"The identifier for queue shouldn't be nil");
}

- (void)testMinimumGarbageCollectorIntervalForDeprecatedInit
{
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wdeprecated\"");
    SPTPersistentCacheOptions *dataCacheOptions = [[SPTPersistentCacheOptions alloc] initWithCachePath:[NSTemporaryDirectory() stringByAppendingPathComponent:SPTPersistentCacheOptionsPathComponent]
                                                                                            identifier:@"test"
                                                                             defaultExpirationInterval:1
                                                                              garbageCollectorInterval:1
                                                                                                 debug:nil];
    _Pragma("clang diagnostic pop");

    XCTAssertEqual(dataCacheOptions.garbageCollectionInterval,
                   SPTPersistentCacheMinimumGCIntervalLimit);
}

- (void)testMinimumGarbageCollectorInterval
{
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"debugOuput is executed"];

    SPTPersistentCacheOptions *options = [SPTPersistentCacheOptions new];
    options.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:SPTPersistentCacheOptionsPathComponent];
    options.cacheIdentifier = @"test";
    options.debugOutput = ^(NSString *message) {
        XCTAssertNotEqual([message rangeOfString:@"garbageCollectionInterval"].location, NSNotFound, @"The \"garbageCollectionInterval\" property name should be in the message (\"%@\")", message);
        [expectation fulfill];
    };

    options.garbageCollectionInterval = 1;
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(options.garbageCollectionInterval,
                   SPTPersistentCacheMinimumGCIntervalLimit);
}

- (void)testMinimumDefaultExpirationIntervalForDeprecatedInit
{
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wdeprecated\"");
    SPTPersistentCacheOptions *dataCacheOptions = [[SPTPersistentCacheOptions alloc] initWithCachePath:[NSTemporaryDirectory() stringByAppendingPathComponent:SPTPersistentCacheOptionsPathComponent]
                                                                                            identifier:@"test"
                                                                             defaultExpirationInterval:1
                                                                              garbageCollectorInterval:1
                                                                                                 debug:nil];
    _Pragma("clang diagnostic pop");

    XCTAssertEqual(dataCacheOptions.defaultExpirationPeriod,
                   SPTPersistentCacheMinimumExpirationLimit);
}

- (void)testMinimumDefaultExpiration
{
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"debugOuput is executed"];

    SPTPersistentCacheOptions *options = [SPTPersistentCacheOptions new];
    options.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:SPTPersistentCacheOptionsPathComponent];
    options.cacheIdentifier = @"test";
    options.debugOutput = ^(NSString *message) {
        XCTAssertNotEqual([message rangeOfString:@"defaultExpirationPeriod"].location, NSNotFound, @"The \"defaultExpirationPeriod\" property name should be in the message (\"%@\")", message);
        [expectation fulfill];
    };

    options.defaultExpirationPeriod = 1;
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(options.defaultExpirationPeriod,
                   SPTPersistentCacheMinimumExpirationLimit);
}

#pragma mark Copying

- (void)testCopying
{
    SPTPersistentCacheOptions * const original = [SPTPersistentCacheOptions new];
    original.cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:SPTPersistentCacheOptionsPathComponent];
    original.cacheIdentifier = @"test";
    original.useDirectorySeparation = NO;
    original.garbageCollectionInterval = SPTPersistentCacheDefaultGCIntervalSec + 10;
    original.defaultExpirationPeriod = SPTPersistentCacheDefaultExpirationTimeSec + 10;
    original.sizeConstraintBytes = 1024 * 1024;
    original.debugOutput = ^(NSString *message) {
        NSLog(@"Foo: %@", message);
    };

    const NSRange lastDotRange = [original.identifierForQueue rangeOfString:@"." options:NSBackwardsSearch];
    NSString * const queueIdentifierPrefix = [original.identifierForQueue substringToIndex:lastDotRange.location];

    SPTPersistentCacheOptions * const copy = [original copy];

    XCTAssertNotEqual(original, copy, @"The original and copy shouldn’t be the same object");

    XCTAssertNotNil(copy.debugOutput, @"The debug output callback block should exist after copy");

    XCTAssertTrue([copy.identifierForQueue hasPrefix:queueIdentifierPrefix] , @"The values of the property \"identifierForQueue\" should have the same prefix");
    XCTAssertEqualObjects(original.cachePath, copy.cachePath, @"The values of the property \"cachePath\" should be equal");
    XCTAssertEqualObjects(original.cacheIdentifier, copy.cacheIdentifier, @"The values of the property \"cacheIdentifier\" should be equal");

    XCTAssertEqual(original.useDirectorySeparation, copy.useDirectorySeparation, @"The values of the property \"useDirectorySeparation\" should be equal");
    XCTAssertEqual(original.garbageCollectionInterval, copy.garbageCollectionInterval, @"The values of the property \"garbageCollectionInterval\" should be equal");
    XCTAssertEqual(original.defaultExpirationPeriod, copy.defaultExpirationPeriod, @"The values of the property \"defaultExpirationPeriod\" should be equal");
    XCTAssertEqual(original.sizeConstraintBytes, copy.sizeConstraintBytes, @"The values of the property \"sizeConstraintBytes\" should be equal");
}

#pragma mark Compatibility Properties for Deprecated Properties

- (void)testFolderSeparationEnabled
{
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wdeprecated\"");

    SPTPersistentCacheOptions * const options = [SPTPersistentCacheOptions new];

    XCTAssertEqual(options.folderSeparationEnabled, options.useDirectorySeparation);

    options.folderSeparationEnabled = NO;
    XCTAssertFalse(options.useDirectorySeparation, @"Setting the compatibility property should update the real property");
    XCTAssertEqual(options.folderSeparationEnabled, options.useDirectorySeparation);

    _Pragma("clang diagnostic pop");
}

- (void)testGcIntervalSec
{
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wdeprecated\"");

    SPTPersistentCacheOptions * const options = [SPTPersistentCacheOptions new];
    options.garbageCollectionInterval = SPTPersistentCacheDefaultGCIntervalSec + 37;

    XCTAssertEqual(options.gcIntervalSec, options.garbageCollectionInterval);

    _Pragma("clang diagnostic pop");
}

- (void)testDefaultExpirationPeriodSec
{
    _Pragma("clang diagnostic push");
    _Pragma("clang diagnostic ignored \"-Wdeprecated\"");

    SPTPersistentCacheOptions * const options = [SPTPersistentCacheOptions new];
    options.defaultExpirationPeriod = SPTPersistentCacheDefaultExpirationTimeSec + 37;

    XCTAssertEqual(options.defaultExpirationPeriodSec, options.defaultExpirationPeriod);

    _Pragma("clang diagnostic pop");
}

#pragma mark Describing objects

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
