
#import <Foundation/Foundation.h>

typedef void(^DataWriteCallback)(NSError *error);
typedef void(^DataReadCallback)(NSData *continousData, NSError *error);

@protocol SPTPersistentDataStream <NSObject>

- (void)appendData:(NSData *)data
          callback:(DataWriteCallback)callback
             queue:(dispatch_queue_t)queue;

- (void)appendBytes:(const void *)bytes
             length:(NSUInteger)length
           callback:(DataWriteCallback)callback
              queue:(dispatch_queue_t)queue;

/**
 * // SIZE_MAX
 *
 */
- (void)readDataWithOffset:(off_t)offset
                    length:(NSUInteger)length
                  callback:(DataReadCallback)callback
                     queue:(dispatch_queue_t)queue;

- (void)readAllDataWithCallback:(DataReadCallback)callback
                          queue:(dispatch_queue_t)queue;

/**
 * 
 */
- (BOOL)isComplete;

/**
 *
 */
- (void)finalize;

@end
