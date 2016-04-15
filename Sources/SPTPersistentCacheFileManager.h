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
#import <Foundation/Foundation.h>

typedef long long SPTPersistentCacheDiskSize;

extern const NSUInteger SPTPersistentCacheFileManagerSubDirNameLength;

@class SPTPersistentCacheOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 *  An object that encapsulates file-related operations of SPTPersistentCache.
 */
@interface SPTPersistentCacheFileManager : NSObject

/// The total amount of bytes used by the cache given the reciever’s options.
@property (nonatomic, readonly) NSUInteger totalUsedSizeInBytes;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 *  Initializes a new file manager set with specific options. 
 *  
 *  @param options Options of the permanent cache.
 */
- (instancetype)initWithOptions:(SPTPersistentCacheOptions *)options NS_DESIGNATED_INITIALIZER;

/**
 *  Creates the directory that will be used to persist the cached data. Returns YES if the operation is successful, 
 *  Or NO otherwise.
 */
- (BOOL)createCacheDirectory;

/**
 *  Returns the path for the subdirectory containing the data associated to a specific key.
 *
 *  @param key Key of the data you are looking for.
 */
- (NSString *)subDirectoryPathForKey:(NSString *)key;

/**
 *  Returns the path for the data associated to a specific key.
 *
 *  @param key Key of the data you are looking for.
 */
- (NSString *)pathForKey:(NSString *)key;

/**
 *  Removes all data files in the cache.
 */
- (void)removeAllData;

/**
 *  Removes the associated cached file for a key.
 *  
 *  @param key Key of the data you are looking for.
 */
- (void)removeDataForKey:(NSString *)key;

/**
 *  Based on a specific cache size, return a size optimized for the disk space. 
 *
 *  @param currentCacheSize Cache size to be optimized
 */
- (SPTPersistentCacheDiskSize)optimizedDiskSizeForCacheSize:(SPTPersistentCacheDiskSize)currentCacheSize;

/**
 *  Returns the size of some data located at a specific path.
 *
 *  @param filePath Path of a specific file.
 */
- (NSUInteger)getFileSizeAtPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
