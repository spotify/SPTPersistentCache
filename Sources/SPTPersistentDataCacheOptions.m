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
#import "SPTPersistentDataCacheOptions.h"

const NSUInteger SPTPersistentDataCacheDefaultExpirationTimeSec = 10 * 60;
const NSUInteger SPTPersistentDataCacheDefaultGCIntervalSec = 6 * 60 + 3;

#pragma mark SPTPersistentDataCacheOptions

@implementation SPTPersistentDataCacheOptions

- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _defaultExpirationPeriodSec = SPTPersistentDataCacheDefaultExpirationTimeSec;
    _gcIntervalSec = SPTPersistentDataCacheDefaultGCIntervalSec;
    _folderSeparationEnabled = YES;
    
    return self;
}

@end
