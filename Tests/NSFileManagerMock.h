// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

/**
 A custom mock of the NSFileManager object.
 */
@interface NSFileManagerMock : NSFileManager

/**
 Called when the mock receives a "fileExistsAtPath:" call.
 */
@property (nonatomic, copy, readwrite) dispatch_block_t blockCalledOnFileExistsAtPath;
/**
 Records the last "path" argument given to "fileExistsAtPath:".
 */
@property (nonatomic, strong, readwrite) NSString *lastPathCalledOnExists;
/**
 Disables the "removeFile:" method.
 */
@property (nonatomic, assign, readwrite) BOOL disableRemoveFile;

/// Path -> Dictionary of attributes
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, id> *> *mock_attributesOfItemsAtPaths;

/// Path -> Dictionary of attributes
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, id> *> * mock_attributesOfFileSystemForPaths;

/// Path -> Contents
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *mock_contentsOfDirectoryAtPaths;

@end
