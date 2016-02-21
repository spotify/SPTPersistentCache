#import <Foundation/Foundation.h>

@interface NSFileManagerMock : NSFileManager

@property (nonatomic, copy, readwrite) dispatch_block_t blockCalledOnFileExistsAtPath;
@property (nonatomic, strong, readwrite) NSString *lastPathCalledOnExists;

@end
