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
#import "SPTPersistentCacheGarbageCollector.h"
#import <SPTPersistentCache/SPTPersistentCache.h>

@interface SPTPersistentCacheGarbageCollector ()
@property (nonatomic, strong) NSTimer *timer;
- (void)garbageCollectionTimerFired:(NSTimer *)timer;
@end
    


@interface SPTPersistentCacheForTimerProxyUnitTests : SPTPersistentCache
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, weak) XCTestExpectation *testExpectation;
@property (nonatomic, assign) BOOL wasCalledFromIncorrectQueue;
@property (nonatomic, assign) BOOL wasRunRegularGCCalled;
@property (nonatomic, assign) BOOL wasPruneBySizeCalled;
@end

@implementation SPTPersistentCacheForTimerProxyUnitTests

- (void)runRegularGC
{
    self.wasCalledFromIncorrectQueue = ![[NSOperationQueue currentQueue].name isEqual:self.queue.name];
    self.wasRunRegularGCCalled = (YES && !self.wasPruneBySizeCalled);
}

- (void)pruneBySize
{
    self.wasCalledFromIncorrectQueue = ![[NSOperationQueue currentQueue].name isEqual:self.queue.name];
    self.wasPruneBySizeCalled = (YES && self.wasRunRegularGCCalled);
    [self.testExpectation fulfill];
}

@end

@interface SPTPersistentCacheGarbageCollectorTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheOptions *options;
@property (nonatomic, strong) SPTPersistentCacheGarbageCollector *garbageCollector;
@property (nonatomic, strong) SPTPersistentCache *cache;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation SPTPersistentCacheGarbageCollectorTests

- (void)setUp
{
    [super setUp];
    
    self.cache = [[SPTPersistentCacheForTimerProxyUnitTests alloc] init];
    
    self.options = [SPTPersistentCacheOptions new];
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.name = @"cacheQueue";
    
    self.garbageCollector = [[SPTPersistentCacheGarbageCollector alloc] initWithCache:self.cache
                                                                              options:self.options
                                                                                queue:self.operationQueue];
}

- (void)testDesignatedInitializer
{
    __strong SPTPersistentCache *strongCache = self.garbageCollector.cache;
    
    XCTAssertEqual(self.garbageCollector.queue, self.operationQueue);
    XCTAssertEqualObjects(strongCache, self.cache);
    XCTAssertNil(self.garbageCollector.timer);
}

- (void)testGarbageCollectorEnqueue
{
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"testGarbageCollectorEnqueue"];
    
    SPTPersistentCacheForTimerProxyUnitTests *dataCacheForUnitTests = (SPTPersistentCacheForTimerProxyUnitTests *)self.garbageCollector.cache;
    dataCacheForUnitTests.queue = self.garbageCollector.queue;

    dataCacheForUnitTests.testExpectation = expectation;
    [self.garbageCollector enqueueGarbageCollection];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(dataCacheForUnitTests.wasRunRegularGCCalled);
        XCTAssertTrue(dataCacheForUnitTests.wasPruneBySizeCalled);
        XCTAssertFalse(dataCacheForUnitTests.wasCalledFromIncorrectQueue);
    }];
}

- (void)testGarbageCollectorTimerFired
{
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"testGarbageCollectorEnqueue"];

    SPTPersistentCacheForTimerProxyUnitTests *dataCacheForUnitTests = (SPTPersistentCacheForTimerProxyUnitTests *)self.garbageCollector.cache;
    dataCacheForUnitTests.queue = self.garbageCollector.queue;

    dataCacheForUnitTests.testExpectation = expectation;
    [self.garbageCollector garbageCollectionTimerFired:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(dataCacheForUnitTests.wasRunRegularGCCalled);
        XCTAssertTrue(dataCacheForUnitTests.wasPruneBySizeCalled);
        XCTAssertFalse(dataCacheForUnitTests.wasCalledFromIncorrectQueue);
    }];
}

- (void)testIsGarbageCollectionScheduled
{
    XCTAssertFalse(self.garbageCollector.isGarbageCollectionScheduled);
    [self.garbageCollector schedule];
    XCTAssertTrue(self.garbageCollector.isGarbageCollectionScheduled);
    [self.garbageCollector unschedule];
    XCTAssertFalse(self.garbageCollector.isGarbageCollectionScheduled);
}

- (void)testScheduleGarbageCollection
{
    [self.garbageCollector schedule];
    XCTAssertNotNil(self.garbageCollector.timer);
    XCTAssertTrue(self.garbageCollector.timer.isValid);
    XCTAssertEqualWithAccuracy(self.garbageCollector.timer.timeInterval, self.options.garbageCollectionInterval, 0.0);
}

- (void)testRepeatedScheduleGarbageCollection
{
    [self.garbageCollector schedule];
    NSTimer *timerFirstCall = self.garbageCollector.timer;
    
    [self.garbageCollector schedule];
    NSTimer *timerSecondCall = self.garbageCollector.timer;
    
    XCTAssertEqualObjects(timerFirstCall, timerSecondCall);
}

- (void)testUnscheduleGarbageCollection
{
    [self.garbageCollector schedule];
    [self.garbageCollector unschedule];
    XCTAssertNil(self.garbageCollector.timer);
}

- (void)testSchedulingGarbageCollectionOnAnotherThread
{
    __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Scheduled Expectation"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        [self.garbageCollector schedule];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [expectation fulfill];
        });
    });
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertTrue(self.garbageCollector.isGarbageCollectionScheduled);
}

@end
