// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

/**
 Converts the given `double` _value_ to an `uint64_t` value.

 @param value The value as a `double`.
 @return The value as an `uint64_t`.
 */
uint64_t spt_uint64rint(double value);
