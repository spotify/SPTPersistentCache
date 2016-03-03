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

@class SPTPersistentCacheRecord;

NS_ASSUME_NONNULL_BEGIN

/**
 * The SPTPersistentCacheResponseCode enum defines constants that is used to identify what kind of response would be
 * given in callback to loadDataForKey:withCallback: method.
 */
typedef NS_ENUM(NSInteger, SPTPersistentCacheResponseCode) {
    /**
     * Indicates success of requested operation with data. The record field of SPTPersistentCacheResponse mustn't be nil
     * if it was load operation otherwise it could be. The error would be nil.
     */
    SPTPersistentCacheResponseCodeOperationSucceeded,
    /**
     * Indicates that no file found for given key in cache or is expired. The record and error field of
     * SPTPersistentCacheResponse is nil in this case.
     */
    SPTPersistentCacheResponseCodeNotFound,
    /**
     * Indicates error occured during requested operation. The record field of SPTPersistentCacheResponse would be nil.
     * The error mustn't be nil and specify exact error.
     */
    SPTPersistentCacheResponseCodeOperationError
};

/**
 * @brief SPTPersistentCacheResponse
 * @discussion Class defines one response passed in callback to call loadDataForKey:
 */
@interface SPTPersistentCacheResponse : NSObject

/**
 * @see SPTPersistentCacheResponseCode
 */
@property (nonatomic, assign, readonly) SPTPersistentCacheResponseCode result;
/**
 * Defines error of response if appliable
 */
@property (nonatomic, strong, readonly) NSError *error;
/**
 * @see SPTPersistentCacheRecord
 */
@property (nonatomic, strong, readonly) SPTPersistentCacheRecord *record;

@end

NS_ASSUME_NONNULL_END
