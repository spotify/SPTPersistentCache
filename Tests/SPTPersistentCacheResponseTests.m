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
#import "SPTDataCacheRecord+Private.h"
#import <SPTPersistentDataCache/SPTDataCacheRecord.h>
#import "SPTPersistentCacheResponse+Private.h"
#import <SPTPersistentDataCache/SPTPersistentCacheResponse.h>


static const SPTPersistentDataCacheResponseCode SPTPersistentCacheResponseTestsTestCode   = SPTPersistentDataCacheResponseCodeNotFound;

@interface SPTPersistentCacheResponseTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheResponse *persistentCacheResponse;
@property (nonatomic, strong) NSError *testError;
@property (nonatomic, strong) SPTDataCacheRecord *testCacheRecord;
@end

@implementation SPTPersistentCacheResponseTests

- (void)setUp
{
    [super setUp];
    
    self.testError = [NSError errorWithDomain:@""
                                         code:404
                                     userInfo:nil];
    
    self.testCacheRecord = [[SPTDataCacheRecord alloc] init];
    
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

@end
