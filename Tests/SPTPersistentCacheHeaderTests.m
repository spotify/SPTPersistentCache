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
#import <XCTest/XCTest.h>

#import "SPTPersistentCacheHeader.h"
#import <SPTPersistentCache/SPTPersistentCache.h>
#import "SPTPersistentCacheTypeUtilities.h"


@interface SPTPersistentCacheHeaderTests : XCTestCase

@end

@implementation SPTPersistentCacheHeaderTests

- (void)testGetHeaderFromDataWithSmallSizeData
{
    size_t smallerSize = SPTPersistentCacheRecordHeaderSize - 1;
    void *smallData = malloc(smallerSize);
    
    XCTAssertEqual(SPTPersistentCacheGetHeaderFromData(smallData, smallerSize), NULL);
    
    free(smallData);
}

- (void)testGetHeaderFromDataWithRightSize
{
    size_t rightHeaderSize = SPTPersistentCacheRecordHeaderSize;
    void *data = malloc(rightHeaderSize);
    
    XCTAssertEqual(SPTPersistentCacheGetHeaderFromData(data, rightHeaderSize), data);
    
    free(data);
}

- (void)testValidateMisalignedHeader
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wcast-align"
    int headerValidationResult = SPTPersistentCacheValidateHeader((SPTPersistentCacheRecordHeader *)3);
    #pragma mark diagnostic pop
    XCTAssertEqual(headerValidationResult, SPTPersistentCacheLoadingErrorHeaderAlignmentMismatch);
}

- (void)testValidateNULLHeader
{
    int headerValidationResult = SPTPersistentCacheValidateHeader(NULL);
    
    XCTAssertEqual(headerValidationResult, SPTPersistentCacheLoadingErrorInternalInconsistency);
}

- (void)testCalculateNULLHeaderCRC
{
    uint32_t headerCRC = SPTPersistentCacheCalculateHeaderCRC(NULL);
    
    XCTAssertEqual(headerCRC, (uint32_t)0);
}

- (void)testSPTPersistentCacheRecordHeaderMake
{
    uint64_t ttl = 64;
    uint64_t payloadSize = 400;
    uint64_t updateTime = spt_uint64rint([[NSDate date] timeIntervalSince1970]);
    BOOL isLocked = YES;
    
    
    SPTPersistentCacheRecordHeader header = SPTPersistentCacheRecordHeaderMake(ttl,
                                                                               payloadSize,
                                                                               updateTime,
                                                                               isLocked);
    
    XCTAssertEqual(header.reserved1, (uint64_t)0);
    XCTAssertEqual(header.reserved2, (uint64_t)0);
    XCTAssertEqual(header.reserved3, (uint64_t)0);
    XCTAssertEqual(header.reserved4, (uint64_t)0);
    XCTAssertEqual(header.flags, (uint32_t)0);
    XCTAssertEqual(header.magic, SPTPersistentCacheMagicValue);
    XCTAssertEqual(header.headerSize, (uint32_t)SPTPersistentCacheRecordHeaderSize);
    XCTAssertEqual(!!header.refCount, isLocked);
    XCTAssertEqual(header.ttl, ttl);
    XCTAssertEqual(header.payloadSizeBytes, payloadSize);
    XCTAssertEqual(header.updateTimeSec, updateTime);
    XCTAssertEqual(header.crc, SPTPersistentCacheCalculateHeaderCRC(&header));
}

@end
