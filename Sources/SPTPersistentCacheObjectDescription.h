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

/// The termination sentinel that must be used toghether with `SPTPersistentCacheObjectDescription()`.
extern id const SPTPersistentCacheObjectDescriptionTerminationSentinel;

/**
 * Creates a standardized description string for the given _object_ and a variable list of _value_ to _key_ pairs.
 * Each value and key must be an object conforming to the `NSObject` protocol.
 *
 * The function takes a variable list of value and key pairs. Just like the variadic `NSDictionary` initializer. You
 * must terminate the list using `SPTPersistentCacheObjectDescriptionTerminationSentinel`.
 *
 * @note It’s recommended that you use the convenience macro `SPTPersistentCacheObjectDescription` over this function
 * directly. As it adds the termination sentinel for you.
 *
 * @warning The list of variadic arguments **MUST** end with the custom termination sentinel:
 * `SPTPersistentCacheObjectDescriptionTerminationSentinel`. We need a custom sentinel as the function supports
 * arguments being `nil`.
 *
 * @return A standardized description string on the format `<ClassName: 0x1234abcd; key1 = "value1"; key2 = "value2">`.
 */
extern NSString *_SPTPersistentCacheObjectDescription(id<NSObject> object, id<NSObject> firstValue, ...);

/**
 * Creates a standardized description string for the given _object_ and a variable list of _value_ to _key_ pairs.
 *
 * The function takes a variable list of value and key pairs. Just like the variadic `NSDictionary` initializer. It
 * will automatically insert the termination sentinel for you.
 *
 * @return A standardized description string on the format `<ClassName: 0x1234abcd; key1 = "value1"; key2 = "value2">`.
 */
#define SPTPersistentCacheObjectDescription(object, firstValue, ...) _SPTPersistentCacheObjectDescription((object), (firstValue), __VA_ARGS__, SPTPersistentCacheObjectDescriptionTerminationSentinel)
