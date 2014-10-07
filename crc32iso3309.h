
#ifndef CRC32ISO3309_H
#define CRC32ISO3309_H

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Return the CRC of the bytes buf[0..len-1]. ISO-3309 */
uint32_t spt_crc32(uint8_t *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif
