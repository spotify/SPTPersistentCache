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
#import <Foundation/Foundation.h>

/**
 * Class which validates object descriptions for conformance to the expected style.
 *
 * A valid description adheres to the following pattern:
 * - <ClassName: 0x0123456789abcdefABCDEF>`
 * - <ClassName: 0x0123456789abcdefABCDEF; key = "foo">
 * - <ClassName: 0x0123456789abcdefABCDEF; key = "foo"; bar-bar = "hello">
 */
@interface SPTPersistentCacheObjectDescriptionStyleValidator : NSObject

/**
 * Valides the given _description_ for style conformance.
 *
 * @param description A string description of an object which should be validated.
 *
 * @return A boolean indicating if the _description_ is valid stylewise.
 */
- (BOOL)isValidStyleDescription:(NSString *)description;

@end
