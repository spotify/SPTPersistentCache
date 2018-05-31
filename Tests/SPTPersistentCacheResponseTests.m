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
#import "SPTPersistentCacheRecord+Private.h"
#import <SPTPersistentCache/SPTPersistentCacheRecord.h>
#import "SPTPersistentCacheResponse+Private.h"
#import <SPTPersistentCache/SPTPersistentCacheResponse.h>
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"


static const SPTPersistentCacheResponseCode SPTPersistentCacheResponseTestsTestCode   = SPTPersistentCacheResponseCodeNotFound;

@interface SPTPersistentCacheResponseTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheResponse *persistentCacheResponse;
@property (nonatomic, strong) NSError *testError;
@property (nonatomic, strong) SPTPersistentCacheRecord *testCacheRecord;
@end

@implementation SPTPersistentCacheResponseTests

- (void)setUp
{
    [super setUp];
    
    self.testError = [NSError errorWithDomain:@""
                                         code:404
                                     userInfo:nil];
    
    self.testCacheRecord = [[SPTPersistentCacheRecord alloc] init];
    
    self.persistentCacheResponse = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseTestsTestCode
                                                                                error:self.testError
                                                                               record:self.testCacheRecord];
}

- (void)testDesignatedInitializer
{
    XCTAssertEqual(self.persistentCacheResponse.result, SPTPersistentCacheResponseTestsTestCode);
    XCTAssertEqualObjects(self.persistentCacheResponse.error, self.testError);
    XCTAssertEqualObjects(self.persistentCacheResponse.record, self.testCacheRecord);
}

#pragma mark Test describing objects

- (void)testDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const description = self.persistentCacheResponse.description;

    XCTAssertTrue([styleValidator isValidStyleDescription:description], @"The description string should follow our style.");
}

- (void)testDescriptionContainsClassName
{
    NSString * const description = self.persistentCacheResponse.description;

    const NSRange classNameRange = [description rangeOfString:@"SPTPersistentCacheResponse"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the description");
}

- (void)testDebugDescriptionContainsClassName
{
    NSString * const debugDescription = self.persistentCacheResponse.debugDescription;

    const NSRange classNameRange = [debugDescription rangeOfString:@"SPTPersistentCacheResponse"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the debugDescription");
}

- (void)testStringFromResponseCodeUniqueness
{
    SPTPersistentCacheResponseCode code = SPTPersistentCacheResponseCodeOperationSucceeded;
    
    NSArray *allResponses;
    
    switch (code) { // Ensure this method includes all states of enum.
        case SPTPersistentCacheResponseCodeOperationSucceeded:
        case SPTPersistentCacheResponseCodeNotFound:
        case SPTPersistentCacheResponseCodeOperationError: {
            allResponses = @[NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeOperationSucceeded),
                             NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeNotFound),
                             NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeOperationError)];
        }
    }
    
    NSSet *uniqueResponses = [NSSet setWithArray:allResponses];
    
    XCTAssertEqual(allResponses.count,
                   uniqueResponses.count,
                   @"Each string for the response codes should be unique.");

}


@end
