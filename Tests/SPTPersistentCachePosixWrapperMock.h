// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCachePosixWrapper.h"

/**
 A custom mock of the SPTPersistentCachePosixWrapper class.
 */
@interface SPTPersistentCachePosixWrapperMock : SPTPersistentCachePosixWrapper

/**
 The value to return when executing the "close:" method.
 */
@property (nonatomic, assign, readwrite) int closeValue;
/**
 The value to return when executing the "read:" method.
 @warning Will not work unless the "isReadOverridden" property is set to YES.
 */
@property (nonatomic, assign, readwrite) ssize_t readValue;
/**
 When this is set to YES the "read:" method will return the readValue above.
 */
@property (nonatomic, assign, readwrite, getter = isReadOverridden) BOOL readOverridden;
/**
 The value to return when executing the "lseek:" method.
 */
@property (nonatomic, assign, readwrite) off_t lseekValue;
/**
 The value to return when executing the "write:" method.
 */
@property (nonatomic, assign, readwrite) ssize_t writeValue;
/**
 The value to return when executing the "fsync:" method.
 */
@property (nonatomic, assign, readwrite) int fsyncValue;
/**
 The value to return when executing the "stat:" method.
 */
@property (nonatomic, assign, readwrite) int statValue;

@end
