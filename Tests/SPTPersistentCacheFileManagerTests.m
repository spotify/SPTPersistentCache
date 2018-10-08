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

#import "SPTPersistentCacheFileManager+Private.h"
#import "NSFileManagerMock.h"

#import <objc/runtime.h>


static NSString * const SPTPersistentCacheFileManagerTestsCachePath = @"test_directory";


#pragma mark -

@interface SPTPersistentCacheFileManagerForTests : SPTPersistentCacheFileManager

@property (nonatomic, strong, readwrite) NSFileManagerMock *test_fileManager;
@property (nonatomic, copy, readwrite) SPTPersistentCacheDebugCallback test_debugOutput;

@end

@implementation SPTPersistentCacheFileManagerForTests

- (NSFileManager *)fileManager
{
    return self.test_fileManager ?: super.fileManager;
}

- (SPTPersistentCacheDebugCallback)debugOutput
{
    return self.test_debugOutput ?: super.debugOutput;
}

@end


#pragma mark -

@interface SPTPersistentCacheFileManagerTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheOptions *options;
@property (nonatomic, strong) SPTPersistentCacheFileManagerForTests *cacheFileManager;
@end

@implementation SPTPersistentCacheFileManagerTests

- (void)setUp
{
    [super setUp];

    SPTPersistentCacheOptions *options = [SPTPersistentCacheOptions new];
    options.cachePath = SPTPersistentCacheFileManagerTestsCachePath;
    options.cacheIdentifier = @"test";
    options.sizeConstraintBytes = (SPTPersistentCacheDiskSize)1024 * 1024 * 1024 * 3; // 3 GiB
    self.options = options;
    
    self.cacheFileManager = [[SPTPersistentCacheFileManagerForTests alloc] initWithOptions:self.options];
}

- (void)testCreateCacheDirectory
{
    BOOL didCreateCacheDirectory = [self.cacheFileManager createCacheDirectory];
    BOOL isDirectory = NO;
    
    BOOL wasFileCreated = [[NSFileManager defaultManager] fileExistsAtPath:self.options.cachePath
                                                               isDirectory:&isDirectory];

    XCTAssertTrue(didCreateCacheDirectory);
    XCTAssertTrue(wasFileCreated);
    XCTAssertTrue(isDirectory);
}

- (void)testExistingCacheDirectory
{
    BOOL didCreateDirectoryUsingNSFileManager = [[NSFileManager defaultManager] createDirectoryAtPath:self.options.cachePath
                                                                         withIntermediateDirectories:YES
                                                                                          attributes:nil
                                                                                               error:nil];
    BOOL directoryDidExist = [self.cacheFileManager createCacheDirectory];
    
    XCTAssertTrue(didCreateDirectoryUsingNSFileManager);
    XCTAssertTrue(directoryDidExist);
}

- (void)testSubdirectoryPathForKeyWithShortKey
{
    NSString *shortKey = @"AA";
    
    NSString *subDirectoryPath = [self.cacheFileManager subDirectoryPathForKey:shortKey];
    
    NSString *expectedSubDirectoryPath = [self.options.cachePath stringByAppendingPathComponent:shortKey];
    
    XCTAssertEqualObjects(subDirectoryPath,
                          expectedSubDirectoryPath);
}

- (void)testSubdirectoryPathForKeyWithLongKey
{
    NSString *key = @"AABBCC";
    
    NSString *subDirectoryPath = [self.cacheFileManager subDirectoryPathForKey:key];

    NSString *expectedSubDirectoryPath = [self.options.cachePath stringByAppendingPathComponent:[key substringToIndex:SPTPersistentCacheFileManagerSubDirNameLength]];
    
    XCTAssertEqualObjects(subDirectoryPath,
                          expectedSubDirectoryPath);
}

- (void)testPathForKey
{
    NSString *key = @"AABBCC";
    
    NSString *pathForKey = [self.cacheFileManager pathForKey:key];
    
    NSString *expectedSubDirectoryPath = [self.options.cachePath stringByAppendingPathComponent:[key substringToIndex:SPTPersistentCacheFileManagerSubDirNameLength]];
    
    expectedSubDirectoryPath = [expectedSubDirectoryPath stringByAppendingPathComponent:key];
    
    XCTAssertEqualObjects(pathForKey,
                          expectedSubDirectoryPath);
}

- (void)testRemoveFileForKey
{
    NSString *shortKey = @"AA";
    
    NSString *pathForKey = [self.cacheFileManager pathForKey:shortKey];
    
    [self createFileForKey:shortKey];
    
    [self.cacheFileManager removeDataForKey:shortKey];
    
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:pathForKey]);
}

- (void)testOptimizedDiskSizeForCacheSizeInsanelyBig
{
    SPTPersistentCacheDiskSize insanelyBigCacheSize = LONG_LONG_MAX;
    
    SPTPersistentCacheDiskSize optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:insanelyBigCacheSize];
    
    XCTAssertEqual(optimizedSize, (SPTPersistentCacheDiskSize)self.options.sizeConstraintBytes);
}

- (void)testOptimizedDiskSizeForCacheSizeSmall
{
    SPTPersistentCacheDiskSize smallCacheSize = 1024 * 1024 * 1;
    
    SPTPersistentCacheDiskSize optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:smallCacheSize];
    
    XCTAssertEqual(optimizedSize, (SPTPersistentCacheDiskSize)0);
}

- (void)testMinimumFreeDiskSpaceFraction
{
    const SPTPersistentCacheDiskSize diskSize = (SPTPersistentCacheDiskSize)1024 * 1024 * 1024 * 16; // 16GiB
    const SPTPersistentCacheDiskSize freeSpace = (SPTPersistentCacheDiskSize)1024 * 1024 * 1024 * 8; // 8GiB
    NSFileManagerMock *fileManager = [NSFileManagerMock new];
    fileManager.mock_attributesOfFileSystemForPaths = @{SPTPersistentCacheFileManagerTestsCachePath: @{NSFileSystemSize: @(diskSize),
                                                                                                       NSFileSystemFreeSize: @(freeSpace)}};
    self.cacheFileManager.test_fileManager = fileManager;

    self.cacheFileManager.options.minimumFreeDiskSpaceFraction = 1.0;
    SPTPersistentCacheDiskSize optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:0];
    XCTAssertEqual(optimizedSize, (SPTPersistentCacheDiskSize)0);

    self.cacheFileManager.options.minimumFreeDiskSpaceFraction = 0.0;
    optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:0];
    XCTAssertEqual(optimizedSize, (SPTPersistentCacheDiskSize)self.options.sizeConstraintBytes);

    self.cacheFileManager.options.minimumFreeDiskSpaceFraction = 0.5;
    optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:0];
    XCTAssertEqual(optimizedSize, (SPTPersistentCacheDiskSize)0);

    const SPTPersistentCacheDiskSize twoGiB = (SPTPersistentCacheDiskSize)1024 * 1024 * 1024 * 2;
    self.cacheFileManager.options.minimumFreeDiskSpaceFraction = (freeSpace - twoGiB) / (double)diskSize;
    optimizedSize = [self.cacheFileManager optimizedDiskSizeForCacheSize:0];
    XCTAssertEqual(optimizedSize, twoGiB);
}

- (void)testRemoveAllDataButKeysWithoutKeys
{
    NSString *keyOne = @"AA";
    NSString *pathForDirectoryOne = [self createFileForKey:keyOne];
    
    NSString *keyTwo = @"AB";
    NSString *pathForDirectoryTwo = [self createFileForKey:keyTwo];
    
    [self.cacheFileManager removeAllData];
    
    BOOL isFileOneAtPath = [[NSFileManager defaultManager] fileExistsAtPath:pathForDirectoryOne
                                                                isDirectory:nil];
    
    BOOL isFileTwoAtPath = [[NSFileManager defaultManager] fileExistsAtPath:pathForDirectoryTwo
                                                                isDirectory:nil];
    
    XCTAssertTrue(!isFileOneAtPath && !isFileTwoAtPath,
                  @"Removing all keys with nil or empty argument should have removed all data");
}

- (void)testFileManagerFailsToGetAttributesOfFile
{
    __block BOOL called = NO;
    self.cacheFileManager.test_debugOutput = ^(NSString *string) {
        called = YES;
    };

    NSFileManagerMock *fileManager = [NSFileManagerMock new];
    fileManager.mock_attributesOfItemsAtPaths = @{};
    self.cacheFileManager.test_fileManager = fileManager;

    [self.cacheFileManager getFileSizeAtPath:@"TEST"];
    XCTAssertTrue(called);
}

- (void)testTotalUsedSizeInBytesFailWithNSURLGetResourceValue
{
    __block BOOL called = NO;
    self.cacheFileManager.test_debugOutput = ^(NSString *string) {
        called = YES;
    };
    Method originalMethod = class_getInstanceMethod(NSURL.class, @selector(getResourceValue:forKey:error:));
    IMP originalMethodImplementation = method_getImplementation(originalMethod);
    IMP fakeMethodImplementation = imp_implementationWithBlock(^ {
        return nil;
    });
    method_setImplementation(originalMethod, fakeMethodImplementation);
    [self.cacheFileManager totalUsedSizeInBytes];
    method_setImplementation(originalMethod, originalMethodImplementation);
    XCTAssertTrue(called);
}

- (void)testOptimizedDiskSizeForCacheSizeFileManagerFail
{
    __block BOOL called = NO;
    self.cacheFileManager.test_debugOutput = ^(NSString *string) {
        called = YES;
    };

    NSFileManagerMock *fileManager = [NSFileManagerMock new];
    fileManager.mock_attributesOfFileSystemForPaths = @{};
    self.cacheFileManager.test_fileManager = fileManager;

    [self.cacheFileManager optimizedDiskSizeForCacheSize:100];
    XCTAssertTrue(called);
}

#pragma mark - Helper Functions

- (NSString *)createFileForKey:(NSString *)key
{
    NSError *error;
    
    NSString *pathForKey = [self.cacheFileManager pathForKey:key];
    
    [self createDirectoryForKey:key];
    
    BOOL didCreateFile = [@"TestString" writeToFile:pathForKey
                                         atomically:YES
                                           encoding:NSUTF8StringEncoding
                                              error:&error];
    
    XCTAssertTrue(didCreateFile,
                  @"Error while creating test file for key. %@", error);
    
    return didCreateFile ? pathForKey: nil;
}

- (NSString *)createDirectoryForKey:(NSString *)key
{
    NSString *pathForKey = [self.cacheFileManager pathForKey:key];
    
    NSError *error;
    
    NSString *pathForDirectory = [pathForKey stringByDeletingLastPathComponent];
    
    BOOL didCreateDirectory = [[NSFileManager defaultManager] createDirectoryAtPath:pathForDirectory
                                                        withIntermediateDirectories:YES
                                                                         attributes:nil
                                                                              error:&error];
    
    XCTAssertTrue(didCreateDirectory,
                 @"Error while creating test directory for key. %@", error);
    
    return didCreateDirectory ? pathForDirectory : nil;
}

@end
