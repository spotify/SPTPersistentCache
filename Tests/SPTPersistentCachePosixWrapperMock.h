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
#import "SPTPersistentCachePosixWrapper.h"

/**
 * A custom mock of the SPTPersistentCachePosixWrapper class.
 */
@interface SPTPersistentCachePosixWrapperMock : SPTPersistentCachePosixWrapper

/**
 * The value to return when executing the "close:" method.
 */
@property (nonatomic, assign, readwrite) int closeValue;
/**
 * The value to return when executing the "read:" method.
 * @warning Will not work unless the "isReadOverridden" property is set to YES.
 */
@property (nonatomic, assign, readwrite) ssize_t readValue;
/**
 * When this is set to YES the "read:" method will return the readValue above.
 */
@property (nonatomic, assign, readwrite, getter = isReadOverridden) BOOL readOverridden;
/**
 * The value to return when executing the "lseek:" method.
 */
@property (nonatomic, assign, readwrite) off_t lseekValue;
/**
 * The value to return when executing the "write:" method.
 */
@property (nonatomic, assign, readwrite) ssize_t writeValue;
/**
 * The value to return when executing the "fsync:" method.
 */
@property (nonatomic, assign, readwrite) int fsyncValue;
/**
 * The value to return when executing the "stat:" method.
 */
@property (nonatomic, assign, readwrite) int statValue;

@end
