/*
 * Copyright (c) 2016 Spotify AB.
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

#import "SPTPersistentCacheFileManager.h"
#import <SPTPersistentCache/SPTPersistentCacheOptions.h>

static NSString * const SPTPersistentCacheFileManagerTestsCachePath = @"test_directory";

@interface SPTPersistentCacheFileManager ()

@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, copy) SPTPersistentCacheDebugCallback debugOutput;

@end

@interface SPTPersistentCacheFileManagerTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheOptions *options;
@property (nonatomic, strong) SPTPersistentCacheFileManager *cacheFileManager;
@end

@implementation SPTPersistentCacheFileManagerTests

- (void)setUp
{
    [super setUp];
    
    self.options = [[SPTPersistentCacheOptions alloc] initWithCachePath:SPTPersistentCacheFileManagerTestsCachePath
                                                                 identifier:nil
                                                                      debug:nil];
    
    self.cacheFileManager = [[SPTPersistentCacheFileManager alloc] initWithOptions:self.options];
    
    
}

- (void)testCreateCacheDirectory
{
    BOOL didCreateCacheDirectory = [self.cacheFileManager createCacheDirectory];
    BOOL isDirectory = NO;
    
    BOOL wasFileCreated = [[NSFileManager defaultManager] fileExistsAtPath:self.options.cachePath
                                                               isDirectory:&isDirectory];

    XCTAssertTrue(didCreateCacheDirectory &&
                  wasFileCreated &&
                  isDirectory);
}

- (void)testExistingCacheDirectory
{
    BOOL didCreateDirectoryUsingNSFileManager = [[NSFileManager defaultManager] createDirectoryAtPath:self.options.cachePath
                                                                         withIntermediateDirectories:YES
                                                                                          attributes:nil
                                                                                               error:nil];
    BOOL directoryDidExist = [self.cacheFileManager createCacheDirectory];
    
    XCTAssertTrue(didCreateDirectoryUsingNSFileManager &&
                  directoryDidExist);
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
    self.cacheFileManager.debugOutput = ^(NSString *string) {
        called = YES;
    };
    self.cacheFileManager.fileManager = nil;
    [self.cacheFileManager getFileSizeAtPath:@"TEST"];
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
