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
#import <Foundation/Foundation.h>

/**
 * A custom mock of the NSFileManager object.
 */
@interface NSFileManagerMock : NSFileManager

/**
 * Called when the mock receives a "fileExistsAtPath:" call.
 */
@property (nonatomic, copy, readwrite) dispatch_block_t blockCalledOnFileExistsAtPath;
/**
 * Records the last "path" argument given to "fileExistsAtPath:".
 */
@property (nonatomic, strong, readwrite) NSString *lastPathCalledOnExists;
/**
 * Disables the "removeFile:" method.
 */
@property (nonatomic, assign, readwrite) BOOL disableRemoveFile;

/// Path -> Dictionary of attributes
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, id> *> *mock_attributesOfItemsAtPaths;

/// Path -> Dictionary of attributes
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, id> *> * mock_attributesOfFileSystemForPaths;

/// Path -> Contents
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *mock_contentsOfDirectoryAtPaths;

@end
