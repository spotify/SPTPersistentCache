#ifndef SPTPERSISTENTDATAHEADER_H
#define SPTPERSISTENTDATAHEADER_H

typedef uint32_t MagicType;
static const MagicType kMagic = 0x46545053; // SPTF

typedef struct SPTPersistentRecordHeaderType
{
    // Version 1:
    MagicType magic;
    uint32_t headerSize;
    uint32_t refCount;
    uint32_t reserved;
    uint64_t ttl;
    // Time of last update i.e. creation or access
    uint64_t updateTimeSec; // unix time scale
    uint64_t payloadSizeBytes;
    uint32_t reserved1;
    uint32_t crc;
    // Version N: Add fields here if required
} SPTPersistentRecordHeaderType;

static const int kSPTPersistentRecordHeaderSize = sizeof(SPTPersistentRecordHeaderType);
_Static_assert(sizeof(SPTPersistentRecordHeaderType) == 48, "Struct SPTPersistentRecordHeaderType has to be packed without padding");
_Static_assert(sizeof(SPTPersistentRecordHeaderType)%4 == 0, "Struct size has to be multiple of 4");

#endif // SPTPERSISTENTDATAHEADER_H
