// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCacheTypeUtilities.h"

uint64_t spt_uint64rint(double value)
{
    return (uint64_t)llrint(value);
}
