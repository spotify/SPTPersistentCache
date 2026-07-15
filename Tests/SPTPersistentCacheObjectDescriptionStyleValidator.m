// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
