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
#import "SPTPersistentCacheGarbageCollectorScheduler.h"
#import <SPTPersistentCache/SPTPersistentCache.h>

@interface SPTPersistentCacheGarbageCollectorScheduler ()
@property (nonatomic, strong) NSTimer *timer;
- (void)enqueueGarbageCollection:(NSTimer *)timer;
@end
    


@interface SPTPersistentCacheForUnitTests : SPTPersistentCache
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) XCTestExpectation *testExpectation;
@property (nonatomic) BOOL wasCalledFromIncorrectQueue;
@property (nonatomic) BOOL wasRunRegularGCCalled;
@property (nonatomic) BOOL wasPruneBySizeCalled;
@end

@implementation SPTPersistentCacheForUnitTests

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

@interface SPTPersistentCacheTimerProxyTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheOptions *options;
@property (nonatomic, strong) SPTPersistentCacheGarbageCollectorScheduler *timerProxy;
@property (nonatomic, strong) SPTPersistentCache *dataCache;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@end

@implementation SPTPersistentCacheTimerProxyTests

- (void)setUp
{
    [super setUp];
    
    self.dataCache = [[SPTPersistentCacheForUnitTests alloc] init];
    
    self.options = [SPTPersistentCacheOptions new];
    
    self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    self.timerProxy = [[SPTPersistentCacheGarbageCollectorScheduler alloc] initWithDataCache:self.dataCache
                                                                                     options:self.options
                                                                                       queue:self.dispatchQueue];
}

- (void)testDesignatedInitializer
{
    __strong SPTPersistentCache *strongDataCache = self.timerProxy.dataCache;
    
    XCTAssertEqual(self.timerProxy.queue, self.dispatchQueue);
    XCTAssertEqualObjects(strongDataCache, self.dataCache);
    XCTAssertNil(self.timerProxy.timer);
}

- (void)testGarbageCollectorEnqueue
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"testGarbageCollectorEnqueue"];
    
    SPTPersistentCacheForUnitTests *dataCacheForUnitTests = (SPTPersistentCacheForUnitTests *)self.timerProxy.dataCache;
    dataCacheForUnitTests.queue = self.timerProxy.queue;
    dataCacheForUnitTests.testExpectation = expectation;
    [self.timerProxy enqueueGarbageCollection:nil];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(dataCacheForUnitTests.wasRunRegularGCCalled);
        XCTAssertTrue(dataCacheForUnitTests.wasPruneBySizeCalled);
        XCTAssertFalse(dataCacheForUnitTests.wasCalledFromIncorrectQueue);
    }];
}

- (void)testIsGarbageCollectionScheduled
{
    XCTAssertFalse(self.timerProxy.isGarbageCollectionScheduled);
    [self.timerProxy scheduleGarbageCollection];
    XCTAssertTrue(self.timerProxy.isGarbageCollectionScheduled);
    [self.timerProxy unscheduleGarbageCollection];
    XCTAssertFalse(self.timerProxy.isGarbageCollectionScheduled);
}

- (void)testScheduleGarbageCollection
{
    [self.timerProxy scheduleGarbageCollection];
    XCTAssertNotNil(self.timerProxy.timer);
    XCTAssertTrue(self.timerProxy.timer.isValid);
    XCTAssertEqualWithAccuracy(self.timerProxy.timer.timeInterval, self.options.gcIntervalSec, 0.0);
}

- (void)testRepeatedScheduleGarbageCollection
{
    [self.timerProxy scheduleGarbageCollection];
    
    NSTimer *timerFirstCall = self.timerProxy.timer;
    
    [self.timerProxy scheduleGarbageCollection];
    
    NSTimer *timerSecondCall = self.timerProxy.timer;
    
    XCTAssertEqualObjects(timerFirstCall, timerSecondCall);
}


- (void)testUnscheduleGarbageCollection
{
    [self.timerProxy scheduleGarbageCollection];
    [self.timerProxy unscheduleGarbageCollection];
    XCTAssertNil(self.timerProxy.timer);
}


@end
