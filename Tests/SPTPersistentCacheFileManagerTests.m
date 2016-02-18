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
                                                        currentTimeCallback:nil
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
    
    NSError *error;
    
    [[NSFileManager defaultManager] createDirectoryAtPath:[pathForKey stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    BOOL didCreateFile = [@"TestString" writeToFile:pathForKey
                                         atomically:YES
                                           encoding:NSUTF8StringEncoding
                                              error:&error];
    
    XCTAssertTrue(didCreateFile, @"%@", [error localizedDescription]);
    
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

@end
