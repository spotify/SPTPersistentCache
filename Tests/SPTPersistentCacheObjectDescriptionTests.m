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

#import "SPTPersistentCacheObjectDescription.h"
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"

@interface SPTPersistentCacheObjectDescriptionTests : XCTestCase

@property (nonatomic, strong) SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator;

@end

@implementation SPTPersistentCacheObjectDescriptionTests

#pragma mark Test Life Time

- (void)setUp
{
    [super setUp];
    self.styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];
}

#pragma mark Basic Properties

- (void)testNilObject
{
    XCTAssertNil(_SPTPersistentCacheObjectDescription(nil, @"value1", @"ke1", SPTPersistentCacheObjectDescriptionTerminationSentinel));
}

- (void)testWithoutValues
{
    NSString * const object = @"object1";
    NSString * const expected = [NSString stringWithFormat:@"<%@: %p>", object.class, (void *)object];

    NSString * const description = _SPTPersistentCacheObjectDescription(object, SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertEqualObjects(description, expected);
}

- (void)testSingleValueKeyPair
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the key-value pair. Description: \"%@\"", description1);
}

- (void)testMultipleValueKey
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", @"value2", @"key2", SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the first key-value pair. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"key2 = \"value2\""];
    XCTAssertNotEqual(keyValuePair2Range.location, NSNotFound, @"The description should contain the second key-value pair. Description: \"%@\"", description1);

    XCTAssertGreaterThan(keyValuePair2Range.location, keyValuePair1Range.location, @"The second key-value pair should come after the first. Description: \"%@\"", description1);
}

- (void)testNilValue
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];
    NSString * const expectedKeyValueString = [NSString stringWithFormat:@"key1 = \"%@\"", nil];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, nil, @"key1", SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:expectedKeyValueString];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the key-value pair. Description: \"%@\"", description1);
}

- (void)testNilKey
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];
    NSString * const expectedKeyValueString = [NSString stringWithFormat:@"%@ = \"value1\"", nil];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", nil, SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:expectedKeyValueString];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the key-value pair. Description: \"%@\"", description1);
}

- (void)testMultipleTerminationSentinels
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", SPTPersistentCacheObjectDescriptionTerminationSentinel, @"value2", @"key2", SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the first key-value pair. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"key2 = \"value2\""];
    XCTAssertEqual(keyValuePair2Range.location, NSNotFound, @"The description should NOT contain the second key-value pair as it comes after a termination sentinel. Description: \"%@\"", description1);
}

- (void)testMisalignedFirstValueKeyPairs
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", SPTPersistentCacheObjectDescriptionTerminationSentinel, @"key1", @"value2", @"key2");

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertEqual(keyValuePair1Range.location, NSNotFound, @"The description should NOT contain the first key-value pair since it’s misaligned. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"key2 = \"value2\""];
    XCTAssertEqual(keyValuePair2Range.location, NSNotFound, @"The description should NOT contain the second key-value pair as it comes after a termination sentinel. Description: \"%@\"", description1);
}

- (void)testMisalignedSecondValueKeyPairs
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", @"value2", SPTPersistentCacheObjectDescriptionTerminationSentinel, @"key2");

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the first key-value pair. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"key2 = \"value2\""];
    XCTAssertEqual(keyValuePair2Range.location, NSNotFound, @"The description should NOT contain the second key-value pair as it’s misaligned. Description: \"%@\"", description1);
}

- (void)testMissingKey
{
    NSString * const object1 = @"object1";

    NSString * const expectedPrefix = [NSString stringWithFormat:@"<%@: 0x", object1.class];

    NSString * const description1 = SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", @"value2", @"key2", @"value3");

    XCTAssertTrue([self.styleValidator isValidStyleDescription:description1], @"A description must be of the valid style `<ClassName: pointer-address; key1 = \"value1\"; key2 = \"value2\"; ...>`. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasPrefix:expectedPrefix], @"The description should have the expected prefix containing the class name. Description: \"%@\"", description1);
    XCTAssertTrue([description1 hasSuffix:@">"], @"The description should always end with `>`. Description: \"%@\"", description1);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \"value1\""];
    XCTAssertNotEqual(keyValuePair1Range.location, NSNotFound, @"The description should contain the first key-value pair. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"key2 = \"value2\""];
    XCTAssertNotEqual(keyValuePair2Range.location, NSNotFound, @"The description should contain the second key-value pair. Description: \"%@\"", description1);

    const NSRange value3Range = [description1 rangeOfString:@"value3"];
    XCTAssertEqual(value3Range.location, NSNotFound, @"The description should NOT contain the third value as the key is missing. Description: \"%@\"", description1);
}

- (void)testIsStable
{
    NSString * const object1 = @"object1";

    NSString * const description1 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", @32, @42, SPTPersistentCacheObjectDescriptionTerminationSentinel);
    NSString * const description2 = _SPTPersistentCacheObjectDescription(object1, @"value1", @"key1", @32, @42, SPTPersistentCacheObjectDescriptionTerminationSentinel);

    XCTAssertEqualObjects(description1, description2);
}

- (void)testDetecsRecursiveDescription
{
    NSString * const object1 = @"object1";

    NSString * const description1 = SPTPersistentCacheObjectDescription(object1, object1, @"key1", @32, @42);

    const NSRange keyValuePair1Range = [description1 rangeOfString:@"key1 = \""];
    XCTAssertEqual(keyValuePair1Range.location, NSNotFound, @"The description should NOT contain the first key-value pair as it would be recursive. Description: \"%@\"", description1);

    const NSRange keyValuePair2Range = [description1 rangeOfString:@"42 = \"32\""];
    XCTAssertNotEqual(keyValuePair2Range.location, NSNotFound, @"The description should contain the second key-value pair. Description: \"%@\"", description1);
}

#pragma mark Convenience Macro

- (void)testConvenienceMacroProcudeSameResultAsDirectFunctionAccess
{
    NSString * const object1 = @"object1";

    NSString * const directDescription = _SPTPersistentCacheObjectDescription(object1, @"foo", @"bar", @"hi", @"hello", SPTPersistentCacheObjectDescriptionTerminationSentinel);
    NSString * const macroDescription = SPTPersistentCacheObjectDescription(object1, @"foo", @"bar", @"hi", @"hello");

    XCTAssertEqualObjects(directDescription, macroDescription);
}

@end
