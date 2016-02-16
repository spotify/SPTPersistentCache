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
#import <SPTPersistentDataCache/SPTPersistentDataCacheHeader.h>

#import <SPTPersistentDataCache/SPTPersistentDataCacheTypes.h>
#import "NSError+SPTPersistentDataCacheDomainErrors.h"

#include "crc32iso3309.h"

const SPTPersistentDataCacheMagicType SPTPersistentDataCacheMagicValue = 0x46545053; // SPTF
const size_t SPTPersistentDataCacheRecordHeaderSize = sizeof(SPTPersistentDataCacheRecordHeaderType);

_Static_assert(sizeof(SPTPersistentDataCacheRecordHeaderType) == 64,
               "Struct SPTPersistentDataCacheRecordHeaderType has to be packed without padding");
_Static_assert(sizeof(SPTPersistentDataCacheRecordHeaderType) % 4 == 0,
               "Struct size has to be multiple of 4");

NS_INLINE BOOL SPTPersistentDataCachePointerMagicAlignCheck(const void *ptr)
{
    const unsigned align = _Alignof(SPTPersistentDataCacheMagicType);
    uint64_t v = (uint64_t)(ptr);
    return (v % align == 0);
}

SPTPersistentDataCacheRecordHeaderType *SPTPersistentDataCacheGetHeaderFromData(void *data, size_t size)
{
    if (size < SPTPersistentDataCacheRecordHeaderSize) {
        return NULL;
    }

    return (SPTPersistentDataCacheRecordHeaderType *)data;
}

int /*SPTPersistentDataCacheLoadingError*/ SPTPersistentDataCacheValidateHeader(const SPTPersistentDataCacheRecordHeaderType *header)
{
    if (header == NULL) {
        return SPTPersistentDataCacheLoadingErrorInternalInconsistency;
    }

    // Check that header could be read according to alignment
    if (!SPTPersistentDataCachePointerMagicAlignCheck(header)) {
        return SPTPersistentDataCacheLoadingErrorHeaderAlignmentMismatch;
    }

    // 1. Check magic
    if (header->magic != SPTPersistentDataCacheMagicValue) {
        return SPTPersistentDataCacheLoadingErrorMagicMismatch;
    }

    // 2. Check CRC
    uint32_t crc = SPTPersistentDataCacheCalculateHeaderCRC(header);
    if (crc != header->crc) {
        return SPTPersistentDataCacheLoadingErrorInvalidHeaderCRC;
    }

    // 3. Check header size
    if (header->headerSize != SPTPersistentDataCacheRecordHeaderSize) {
        return SPTPersistentDataCacheLoadingErrorWrongHeaderSize;
    }

    return -1;
}

NSError * SPTPersistentDataCacheCheckValidHeader(SPTPersistentDataCacheRecordHeaderType *header)
{
    int code = SPTPersistentDataCacheValidateHeader(header);
    if (code == -1) { // No error
        return nil;
    }
    
    return [NSError spt_persistentDataCacheErrorWithCode:code];
}

uint32_t SPTPersistentDataCacheCalculateHeaderCRC(const SPTPersistentDataCacheRecordHeaderType *header)
{
    if (header == NULL) {
        return 0;
    }

    return spt_crc32((const uint8_t *)header, SPTPersistentDataCacheRecordHeaderSize - sizeof(header->crc));
}


