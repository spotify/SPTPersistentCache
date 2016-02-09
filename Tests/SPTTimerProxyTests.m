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
#import "SPTTimerProxy.h"
#import <SPTPersistentDataCache/SPTPersistentDataCache.h>


@interface SPTTimerProxyTests : XCTestCase
@property (nonatomic, strong) SPTTimerProxy *timerProxy;
@property (nonatomic, strong) SPTPersistentDataCache *dataCache;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@end

@implementation SPTTimerProxyTests

- (void)setUp
{
    [super setUp];
    
    self.dataCache = [[SPTPersistentDataCache alloc] init];
    
    self.dispatchQueue = dispatch_get_main_queue();
    
    self.timerProxy = [[SPTTimerProxy alloc] initWithDataCache:self.dataCache
                                                         queue:self.dispatchQueue];
}

- (void)testDesignatedInitializer
{
    __strong SPTPersistentDataCache *strongDataCache = self.timerProxy.dataCache;
    
    XCTAssertEqual(self.timerProxy.queue, self.dispatchQueue);
    XCTAssertEqualObjects(strongDataCache, self.dataCache);
}

@end
