// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCacheDebugUtilities.h"

void SPTPersistentCacheSafeDebugCallback(NSString *debugMessage,
                                         SPTPersistentCacheDebugCallback debugCallback)
{
    if (debugCallback) {
        debugCallback(debugMessage);
    }
}
