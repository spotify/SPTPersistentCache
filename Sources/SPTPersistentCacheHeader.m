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
#import <SPTPersistentCache/SPTPersistentCacheHeader.h>

#import "NSError+SPTPersistentCacheDomainErrors.h"

#include "crc32iso3309.h"
#include <sys/xattr.h>

const SPTPersistentCacheMagicType SPTPersistentCacheMagicValue = 0x46545053; // SPTF
const size_t SPTPersistentCacheRecordHeaderSize = sizeof(SPTPersistentCacheRecordHeader);
static NSString* const SPTPersistentCacheRecordHeaderAttributeName = @"com.spotify.cache";
static int const SPTPersistentCacheHeaderInvalidResult = -1;

_Static_assert(sizeof(SPTPersistentCacheRecordHeader) == 64,
               "Struct SPTPersistentCacheRecordHeader has to be packed without padding");
_Static_assert(sizeof(SPTPersistentCacheRecordHeader) % 4 == 0,
               "Struct size has to be multiple of 4");

NS_INLINE BOOL SPTPersistentCachePointerMagicAlignCheck(const void *ptr)
{
    const unsigned align = _Alignof(SPTPersistentCacheMagicType);
    uint64_t v = (uint64_t)(ptr);
    return (v % align == 0);
}

SPTPersistentCacheRecordHeader SPTPersistentCacheRecordHeaderMake(uint64_t ttl,
                                                                  uint64_t payloadSize,
                                                                  uint64_t updateTime,
                                                                  BOOL isLocked)

{
    SPTPersistentCacheRecordHeader dummy;
    memset(&dummy, 0, SPTPersistentCacheRecordHeaderSize);
    SPTPersistentCacheRecordHeader *header = &dummy;
    
    header->magic = SPTPersistentCacheMagicValue;
    header->headerSize = (uint32_t)SPTPersistentCacheRecordHeaderSize;
    header->refCount = (isLocked ? 1 : 0);
    header->ttl = ttl;
    header->payloadSizeBytes = payloadSize;
    header->updateTimeSec = updateTime;
    header->crc = SPTPersistentCacheCalculateHeaderCRC(header);
    
    return dummy;
}

SPTPersistentCacheRecordHeader *SPTPersistentCacheGetHeaderFromData(void *data, size_t size)
{
    if (size < SPTPersistentCacheRecordHeaderSize) {
        return NULL;
    }

    return (SPTPersistentCacheRecordHeader *)data;
}

NSError* SPTPersistentCacheGetHeaderFromFileWithPath(NSString *filePath, SPTPersistentCacheRecordHeader *header)
{
    memset(header, 0, SPTPersistentCacheRecordHeaderSize);
    ssize_t size = getxattr([filePath UTF8String], [SPTPersistentCacheRecordHeaderAttributeName UTF8String], header, SPTPersistentCacheRecordHeaderSize, 0, 0);
    if (size == SPTPersistentCacheHeaderInvalidResult) {
        // try to load the legacy header. the fileHandle object uses file descriptor under the hood and responsible for closing it on deallocation.
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        NSMutableData* rawData = [[fileHandle readDataOfLength:SPTPersistentCacheRecordHeaderSize] mutableCopy];
        SPTPersistentCacheRecordHeader *legacyHeader = SPTPersistentCacheGetHeaderFromData(rawData.mutableBytes, rawData.length);
        // If not enough data to cast to header, its not the file we can process
        if (legacyHeader == NULL) {
            return [NSError spt_persistentDataCacheErrorWithCode:SPTPersistentCacheLoadingErrorNotEnoughDataToGetHeader];
        }
        memcpy(header, legacyHeader, SPTPersistentCacheRecordHeaderSize);
    }
    return SPTPersistentCacheCheckValidHeader(header);
}

NSError* SPTPersistentCacheSetHeaderForFileWithPath(NSString *filepath, const SPTPersistentCacheRecordHeader *header) {
    int res = setxattr([filepath UTF8String], [SPTPersistentCacheRecordHeaderAttributeName UTF8String], header, SPTPersistentCacheRecordHeaderSize, 0, 0);
    if (res == SPTPersistentCacheHeaderInvalidResult) {
        return [NSError spt_persistentDataCacheErrorWithCode:SPTPersistentCacheLoadingErrorFileAttributeOperationFail];
    }
    return nil;
}

int /*SPTPersistentCacheLoadingError*/ SPTPersistentCacheValidateHeader(const SPTPersistentCacheRecordHeader *header)
{
    if (header == NULL) {
        return SPTPersistentCacheLoadingErrorInternalInconsistency;
    }

    // Check that header could be read according to alignment
    if (!SPTPersistentCachePointerMagicAlignCheck(header)) {
        return SPTPersistentCacheLoadingErrorHeaderAlignmentMismatch;
    }

    // 1. Check magic
    if (header->magic != SPTPersistentCacheMagicValue) {
        return SPTPersistentCacheLoadingErrorMagicMismatch;
    }

    // 2. Check CRC
    uint32_t crc = SPTPersistentCacheCalculateHeaderCRC(header);
    if (crc != header->crc) {
        return SPTPersistentCacheLoadingErrorInvalidHeaderCRC;
    }

    // 3. Check header size
    if (header->headerSize != SPTPersistentCacheRecordHeaderSize) {
        return SPTPersistentCacheLoadingErrorWrongHeaderSize;
    }

    return -1;
}

NSError * SPTPersistentCacheCheckValidHeader(SPTPersistentCacheRecordHeader *header)
{
    int code = SPTPersistentCacheValidateHeader(header);
    if (code == -1) { // No error
        return nil;
    }
    
    return [NSError spt_persistentDataCacheErrorWithCode:code];
}

uint32_t SPTPersistentCacheCalculateHeaderCRC(const SPTPersistentCacheRecordHeader *header)
{
    if (header == NULL) {
        return 0;
    }

    return spt_crc32((const uint8_t *)header, SPTPersistentCacheRecordHeaderSize - sizeof(header->crc));
}


