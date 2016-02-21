#import "NSFileManagerMock.h"

@implementation NSFileManagerMock

- (BOOL)fileExistsAtPath:(NSString *)path
{
    self.lastPathCalledOnExists = path;
    BOOL exists = [super fileExistsAtPath:path];
    if (self.blockCalledOnFileExistsAtPath) {
        self.blockCalledOnFileExistsAtPath();
    }
    return exists;
}

@end
