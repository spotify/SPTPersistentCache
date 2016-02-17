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
#import "SPTPersistentDataCacheFileManager.h"
#import <SPTPersistentDataCache/SPTPersistentDataCacheOptions.h>

static NSString * const SPTPersistentCacheFileManagerTestsCachePath = @"test_directory";

@interface SPTPersistentDataCacheFileManagerTests : XCTestCase
@property (nonatomic, strong) SPTPersistentDataCacheOptions *options;
@property (nonatomic, strong) SPTPersistentDataCacheFileManager *cacheFileManager;
@end

@implementation SPTPersistentDataCacheFileManagerTests

- (void)setUp
{
    [super setUp];
    
    self.options = [[SPTPersistentDataCacheOptions alloc] initWithCachePath:SPTPersistentCacheFileManagerTestsCachePath
                                                                 identifier:nil
                                                        currentTimeCallback:nil
                                                                      debug:nil];
    
    self.cacheFileManager = [[SPTPersistentDataCacheFileManager alloc] initWithOptions:self.options];
    
    
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

    NSString *expectedSubDirectoryPath = [self.options.cachePath stringByAppendingPathComponent:[key substringToIndex:SPTPersistentDataCacheFileManagerSubDirNameLength]];
    
    XCTAssertEqualObjects(subDirectoryPath,
                          expectedSubDirectoryPath);
}

- (void)testPathForKey
{
    NSString *key = @"AABBCC";
    
    NSString *pathForKey = [self.cacheFileManager pathForKey:key];
    
    NSString *expectedSubDirectoryPath = [self.options.cachePath stringByAppendingPathComponent:[key substringToIndex:SPTPersistentDataCacheFileManagerSubDirNameLength]];
    
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

@end
