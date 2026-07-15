// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>
#import <SPTPersistentCache/SPTPersistentCacheOptions.h>

/**
 Executes the debug callback safely avoiding a crash if it is set to nil.

 @param debugMessage The debug message.
 @param debugCallback The callback block to execute safely.
 */
void SPTPersistentCacheSafeDebugCallback(NSString *debugMessage,
                                         SPTPersistentCacheDebugCallback debugCallback);
