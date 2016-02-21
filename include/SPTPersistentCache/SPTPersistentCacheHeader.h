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

NS_ASSUME_NONNULL_BEGIN

typedef uint32_t SPTPersistentCacheMagicType;

/**
 * Describes different flags for record
 */
typedef NS_ENUM(NSInteger, SPTPersistentCacheRecordHeaderFlags) {
    // 0x0 means regular file
    /*
     * Indicates that record might not be completed last time it was written.
     * This is not an error state but more Application logic.
     */
    SPTPersistentCacheRecordHeaderFlagsStreamIncomplete = 0x1,
};

typedef struct SPTPersistentCacheRecordHeader {
    // Version 1:
    SPTPersistentCacheMagicType magic;
    uint32_t headerSize;
    uint32_t refCount;
    uint32_t reserved1;
    uint64_t ttl;
    // Time of last update i.e. creation or access
    uint64_t updateTimeSec; // unix time scale
    uint64_t payloadSizeBytes;
    uint64_t reserved2;
    uint32_t reserved3;
    uint32_t reserved4;
    uint32_t flags;         // See SPTPersistentRecordHeaderFlags
    uint32_t crc;
    // Version 2: Add fields here if required
} SPTPersistentCacheRecordHeader;

FOUNDATION_EXPORT const SPTPersistentCacheMagicType SPTPersistentCacheMagicValue;
FOUNDATION_EXPORT const size_t SPTPersistentCacheRecordHeaderSize;

FOUNDATION_EXPORT SPTPersistentCacheRecordHeader SPTPersistentCacheRecordHeaderMake(uint64_t ttl,
                                                                                    uint64_t payloadSize,
                                                                                    uint64_t updateTime,
                                                                                    BOOL isLocked);

// Following functions used internally and could be used for testing purposes also
// Function return pointer to header if there are enough data otherwise NULL
FOUNDATION_EXPORT SPTPersistentCacheRecordHeader * _Nullable SPTPersistentCacheGetHeaderFromData(void * _Nullable data,
                                                                                                 size_t size);
// Function validates header accoring to predefined rules used in production code
// @return -1 if everything is ok, otherwise one of codes from SPTPersistentCacheLoadingError
FOUNDATION_EXPORT int /*SPTPersistentCacheLoadingError*/ SPTPersistentCacheValidateHeader(const SPTPersistentCacheRecordHeader * _Nullable header);
// Function return calculated CRC for current header.
FOUNDATION_EXPORT uint32_t SPTPersistentCacheCalculateHeaderCRC(const  SPTPersistentCacheRecordHeader * _Nullable header);

/// Checks that a given header is valid.
/// @return nil if everything is ok, otherwise will return an instance of NSError.
FOUNDATION_EXPORT NSError * _Nullable SPTPersistentCacheCheckValidHeader(SPTPersistentCacheRecordHeader * _Nullable header);

NS_ASSUME_NONNULL_END
