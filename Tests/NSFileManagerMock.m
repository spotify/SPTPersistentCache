// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error
{
    if (self.disableRemoveFile) {
        return NO;
    }
    return [super removeItemAtPath:path error:error];
}

- (NSDictionary<NSString *,id> *)attributesOfItemAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error
{
    if (self.mock_attributesOfItemsAtPaths) {
        return self.mock_attributesOfItemsAtPaths[path];
    }
    return [super attributesOfItemAtPath:path error:error];
}

- (NSDictionary<NSString *,id> *)attributesOfFileSystemForPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error
{
    if (self.mock_attributesOfFileSystemForPaths) {
        return self.mock_attributesOfFileSystemForPaths[path];
    }
    return [super attributesOfFileSystemForPath:path error:error];
}

- (NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error
{
    if (self.mock_contentsOfDirectoryAtPaths) {
        return self.mock_contentsOfDirectoryAtPaths[path];
    }
    return [super contentsOfDirectoryAtPath:path error:error];
}

@end
