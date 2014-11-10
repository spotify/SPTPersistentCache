
#import <Foundation/Foundation.h>

typedef void(^DataWriteCallback)(NSError *error);
typedef void(^DataReadCallback)(NSData *continousData, NSError *error);

/**
 * @discussion Implemetetion of this protocol is not thread safe in a sense that no two or more consecutive writes
 *             from different threads could guarantee the order of data that will be written. Serveral reads at once is fine.
 *             Intermixing of reads and writes is also should be fine.
 */
@protocol SPTPersistentDataStream <NSObject>

/**
 * @discussion Appends data to the end of the record. 
 * @param data Data to append
 * @param callback May be nil.
 * @param queue. May be nil if callback is nil.
 */
- (void)appendData:(NSData *)data
          callback:(DataWriteCallback)callback
             queue:(dispatch_queue_t)queue;

/**
 * @discussion Appends bytes to the end of the record.
 * @param bytes Pointer to buffer where to get the data.
 * @param length Length of data in buffer.
 * @param callback May be nil.
 * @param queue. May be nil if callback is nil.
 */
- (void)appendBytes:(const void *)bytes
             length:(NSUInteger)length
           callback:(DataWriteCallback)callback
              queue:(dispatch_queue_t)queue;

/**
 * @discussion Read data from record.
 * @param offset Offset from beginning of the payload data to read data from. 0 - beginning of payload.
 * @param length Length in bytes of how much to read. Specify SIZE_MAX to read to EOF.
 * @param callback Callback to which to pass the data. Can't be nil.
 * @param queue Queue to execute callback on.
 *
 */
- (void)readDataWithOffset:(off_t)offset
                    length:(NSUInteger)length
                  callback:(DataReadCallback)callback
                     queue:(dispatch_queue_t)queue;

/**
 * @discussion Read whole data from record.
 * @param callback Callback to which to pass the data. Can't be nil.
 * @param queue Queue to execute callback on.
 *
 */
- (void)readAllDataWithCallback:(DataReadCallback)callback
                          queue:(dispatch_queue_t)queue;

/**
 *  Return YES if data was finilized in previos session. NO otherwise.
 */
- (BOOL)isComplete;

/**
 * Call to mark record as complete. Further append calls make record incomplete again untill next finalize call.
 */
- (void)finalize;

@end
