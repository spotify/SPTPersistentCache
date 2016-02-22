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
#import <Foundation/Foundation.h>

#import <SPTPersistentCache/SPTPersistentCache.h>

/**
 * Category to instantiate NSError objects with a specific domain for SPTPersistentCache.
 */
@interface NSError (SPTPersistentCacheDomainErrors)

/**
 * Returns a new instance of NSError with a SPTPersistentCache domain and an error code.
 * @param persistentDataCacheLoadingError The error code for the NSError object.
 */
+ (instancetype)spt_persistentDataCacheErrorWithCode:(SPTPersistentCacheLoadingError)persistentDataCacheLoadingError;

@end
