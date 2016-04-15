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
#import "SPTPersistentCacheFileManager+Private.h"
#import "SPTPersistentCacheDebugUtilities.h"
#import "SPTPersistentCacheOptions.h"

static const double SPTPersistentCacheFileManagerMinFreeDiskSpace = 0.1;

const NSUInteger SPTPersistentCacheFileManagerSubDirNameLength = 2;

@implementation SPTPersistentCacheFileManager

#pragma mark - Initializer

- (instancetype)initWithOptions:(SPTPersistentCacheOptions *)options
{
    self = [super init];
    if (self) {
        _options = [options copy];
        _fileManager = [NSFileManager defaultManager];
        _debugOutput = options.debugOutput;
    }
    return self;
}

#pragma mark -

- (BOOL)createCacheDirectory
{
    BOOL isDirectory = NO;
    
    BOOL didFileExist = [self.fileManager fileExistsAtPath:self.options.cachePath isDirectory:&isDirectory];
    if (didFileExist == NO) {
        NSError *error = nil;
        BOOL didCreateDirectory = [self.fileManager createDirectoryAtPath:self.options.cachePath
                                              withIntermediateDirectories:YES
                                                               attributes:nil
                                                                    error:&error];
        if (didCreateDirectory == NO) {
            SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Unable to create dir: %@ with error:%@", self.options.cachePath, error], self.debugOutput);
            
            return NO;
        }
    }
    
    return YES;
}

/**
 * 2 letter separation is handled only by this method. All other code is agnostic to this fact.
 */
- (NSString *)subDirectoryPathForKey:(NSString *)key
{
    // make folder tree: xx/  zx/  xy/  yz/ etc.
    NSString *subDir = self.options.cachePath;
    
    if (self.options.useDirectorySeparation && key.length >= SPTPersistentCacheFileManagerSubDirNameLength) {
        NSString *subDirectoryName = [key substringToIndex:SPTPersistentCacheFileManagerSubDirNameLength];
        subDir = [self.options.cachePath stringByAppendingPathComponent:subDirectoryName];
    }
    
    return subDir;
}

- (NSString *)pathForKey:(NSString *)key
{
    NSString *subDirectoryPathForKey = [self subDirectoryPathForKey:key];
    
    return [subDirectoryPathForKey stringByAppendingPathComponent:key];
}

- (void)removeAllData
{
    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];
    
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];
    
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {
        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {
                NSString *key = theURL.lastPathComponent;
                
                // That satisfies Req.#1.3
                [self removeDataForKey:key];
            }
        }
    }
}

- (void)removeDataForKey:(NSString *)key
{
    NSError *error = nil;
    
    NSString *filePath = [self pathForKey:key];
    
    if (![self.fileManager removeItemAtPath:filePath error:&error]) {
        SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Error removing data for Key:%@ , error:%@", key, error], self.debugOutput);
    }
}

- (NSUInteger)getFileSizeAtPath:(NSString *)filePath
{
    NSError *error = nil;
    NSDictionary *attrs = [self.fileManager attributesOfItemAtPath:filePath error:&error];
    if (attrs == nil) {
        SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: Error getting attributes for file: %@, error: %@", filePath, error], self.debugOutput);
    }
    return (NSUInteger)[attrs fileSize];
}

- (NSUInteger)totalUsedSizeInBytes
{
    NSUInteger size = 0;
    NSURL *urlPath = [NSURL URLWithString:self.options.cachePath];
    NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtURL:urlPath
                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                errorHandler:nil];
    
    // Enumerate the dirEnumerator results, each value is stored in allURLs
    NSURL *theURL = nil;
    while ((theURL = [dirEnumerator nextObject])) {
        
        // Retrieve the file name. From cached during the enumeration.
        NSNumber *isDirectory;
        if ([theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL]) {
            if ([isDirectory boolValue] == NO) {
                NSString *key = theURL.lastPathComponent;
                
                NSString *filePath = [self pathForKey:key];
                size += [self getFileSizeAtPath:filePath];
            }
        } else {
            SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"Unable to fetch isDir#2 attribute:%@", theURL], self.debugOutput);
        }
    }
    
    return size;
}

- (SPTPersistentCacheDiskSize)optimizedDiskSizeForCacheSize:(SPTPersistentCacheDiskSize)currentCacheSize
{
    SPTPersistentCacheDiskSize tempCacheSize = (SPTPersistentCacheDiskSize)self.options.sizeConstraintBytes;
    
    NSError *error = nil;
    
    NSDictionary *fileSystemAttributes = [self.fileManager attributesOfFileSystemForPath:self.options.cachePath
                                                                                   error:&error];
    if (fileSystemAttributes) {
        // Never use the last SPTImageLoaderMinimumFreeDiskSpace of the disk for caching
        NSNumber *fileSystemSize = fileSystemAttributes[NSFileSystemSize];
        NSNumber *fileSystemFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];
        
        SPTPersistentCacheDiskSize totalSpace = fileSystemSize.longLongValue;
        SPTPersistentCacheDiskSize freeSpace = fileSystemFreeSpace.longLongValue + currentCacheSize;
        SPTPersistentCacheDiskSize proposedCacheSize = freeSpace - llrint(totalSpace *
                                                                              SPTPersistentCacheFileManagerMinFreeDiskSpace);
        
        tempCacheSize = MAX(0, proposedCacheSize);
        
    } else {
        SPTPersistentCacheSafeDebugCallback([NSString stringWithFormat:@"PersistentDataCache: %@ ERROR %@", @(__PRETTY_FUNCTION__), [error localizedDescription]], self.debugOutput);
    }
    
    return MIN(tempCacheSize, (SPTPersistentCacheDiskSize)self.options.sizeConstraintBytes);
}

@end
