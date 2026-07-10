// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

/**
 Class which validates object descriptions for conformance to the expected style.

 A valid description adheres to the following pattern:
 - <ClassName: 0x0123456789abcdefABCDEF>`
 - <ClassName: 0x0123456789abcdefABCDEF; key = "foo">
 - <ClassName: 0x0123456789abcdefABCDEF; key = "foo"; bar-bar = "hello">
 */
@interface SPTPersistentCacheObjectDescriptionStyleValidator : NSObject

/**
 Valides the given _description_ for style conformance.

 @param description A string description of an object which should be validated.

 @return A boolean indicating if the _description_ is valid stylewise.
 */
- (BOOL)isValidStyleDescription:(NSString *)description;

@end
