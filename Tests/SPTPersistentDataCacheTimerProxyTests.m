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
#import "SPTPersistentDataCacheTimerProxy.h"
#import <SPTPersistentDataCache/SPTPersistentDataCache.h>

@interface SPTPersistentDataCacheForUnitTests : SPTPersistentDataCache
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) XCTestExpectation *testExpectation;
@property (nonatomic) BOOL wasCalledFromIncorrectQueue;
@property (nonatomic) BOOL wasRunRegularGCCalled;
@property (nonatomic) BOOL wasPruneBySizeCalled;
@end

@implementation SPTPersistentDataCacheForUnitTests

- (void)runRegularGC
{
    self.wasCalledFromIncorrectQueue = (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) != dispatch_queue_get_label(self.queue));
    self.wasRunRegularGCCalled = (YES && !self.wasPruneBySizeCalled);
}

- (void)pruneBySize
{
    self.wasCalledFromIncorrectQueue = (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) != dispatch_queue_get_label(self.queue));
    self.wasPruneBySizeCalled = (YES && self.wasRunRegularGCCalled);
    [self.testExpectation fulfill];
}

@end

@interface SPTPersistentDataCacheTimerProxyTests : XCTestCase
@property (nonatomic, strong) SPTPersistentDataCacheTimerProxy *timerProxy;
@property (nonatomic, strong) SPTPersistentDataCache *dataCache;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@end

@implementation SPTPersistentDataCacheTimerProxyTests

- (void)setUp
{
    [super setUp];
    
    self.dataCache = [[SPTPersistentDataCacheForUnitTests alloc] init];
    
    self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    self.timerProxy = [[SPTPersistentDataCacheTimerProxy alloc] initWithDataCache:self.dataCache
                                                                            queue:self.dispatchQueue];
}

- (void)testDesignatedInitializer
{
    __strong SPTPersistentDataCache *strongDataCache = self.timerProxy.dataCache;
    
    XCTAssertEqual(self.timerProxy.queue, self.dispatchQueue);
    XCTAssertEqualObjects(strongDataCache, self.dataCache);
}

- (void)testGarbageCollectorEnqueue
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"testGarbageCollectorEnqueue"];
    
    SPTPersistentDataCacheForUnitTests *dataCacheForUnitTests = (SPTPersistentDataCacheForUnitTests *)self.timerProxy.dataCache;
    dataCacheForUnitTests.queue = self.timerProxy.queue;
    dataCacheForUnitTests.testExpectation = expectation;
    [self.timerProxy enqueueGC:nil];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(dataCacheForUnitTests.wasRunRegularGCCalled);
        XCTAssertTrue(dataCacheForUnitTests.wasPruneBySizeCalled);
        XCTAssertFalse(dataCacheForUnitTests.wasCalledFromIncorrectQueue);
    }];
}

@end
