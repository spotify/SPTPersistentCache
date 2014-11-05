#ifndef SPTPERSISTENTDATAHEADER_H
#define SPTPERSISTENTDATAHEADER_H

typedef uint32_t MagicType;
FOUNDATION_EXPORT const MagicType kSPTPersistentDataCacheMagic;

typedef struct SPTPersistentRecordHeaderType
{
    // Version 1:
    MagicType magic;
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
    uint32_t flags;        // See SPTPersistentRecordHeaderFlags
    uint32_t crc;
    // Version 2: Add fields here if required
} SPTPersistentRecordHeaderType;

FOUNDATION_EXPORT const int kSPTPersistentRecordHeaderSize;

_Static_assert(sizeof(SPTPersistentRecordHeaderType) == 64, "Struct SPTPersistentRecordHeaderType has to be packed without padding");
_Static_assert(sizeof(SPTPersistentRecordHeaderType)%4 == 0, "Struct size has to be multiple of 4");

// Following functions used internally and could be used testing purposes also

// Function return pointer to header if there are enough data otherwise NULL
FOUNDATION_EXPORT SPTPersistentRecordHeaderType* pdc_GetHeaderFromData(const void* data, size_t size);

// Function validates header accoring to predefined rules used in production code
// @return -1 if everything is ok, otherwise one of codes from SPTDataCacheLoadingError
FOUNDATION_EXPORT int /*SPTDataCacheLoadingError*/ pdc_ValidateHeader(const SPTPersistentRecordHeaderType *header);

// Function return calculated CRC for current header.
FOUNDATION_EXPORT uint32_t pdc_CalculateHeaderCRC(const SPTPersistentRecordHeaderType *header);

#endif // SPTPERSISTENTDATAHEADER_H
