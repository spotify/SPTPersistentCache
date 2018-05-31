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
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"

@interface SPTPersistentCacheObjectDescriptionStyleValidator ()

@property (nonatomic, strong) NSRegularExpression *regex;

@end

@implementation SPTPersistentCacheObjectDescriptionStyleValidator

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Regex to match a description: ^<[\w]+: 0x[\da-fA-F]+((; [^=]+= "[^"]+")+)?>$

        // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
        _regex = [NSRegularExpression regularExpressionWithPattern:@"^<[\\w]+: 0x[\\da-fA-F]+((; [^=]+= \"[^\"]+\")+)?>$"
                                                           options:NSRegularExpressionAnchorsMatchLines
                                                             error:nil];
    }

    return self;
}

- (BOOL)isValidStyleDescription:(NSString *)description
{
    // Shorter than: <A: 0x0>
    if (description.length < 8) {
        return NO;
    }

    const NSRange descriptionRange = NSMakeRange(0, description.length);
    const NSMatchingOptions options = (NSMatchingOptions)0;
    const NSUInteger matches = [self.regex numberOfMatchesInString:description options:options range:descriptionRange];

    return matches == 1;
}

@end
