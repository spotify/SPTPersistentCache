// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

/// The termination sentinel that must be used toghether with `SPTPersistentCacheObjectDescription()`.
extern id const SPTPersistentCacheObjectDescriptionTerminationSentinel;

/**
 Creates a standardized description string for the given _object_ and a variable list of _value_ to _key_ pairs.
 Each value and key must be an object conforming to the `NSObject` protocol.

 The function takes a variable list of value and key pairs. Just like the variadic `NSDictionary` initializer. You
 must terminate the list using `SPTPersistentCacheObjectDescriptionTerminationSentinel`.

 @note It’s recommended that you use the convenience macro `SPTPersistentCacheObjectDescription` over this function
 directly. As it adds the termination sentinel for you.

 @warning The list of variadic arguments **MUST** end with the custom termination sentinel:
 `SPTPersistentCacheObjectDescriptionTerminationSentinel`. We need a custom sentinel as the function supports
 arguments being `nil`.

 @return A standardized description string on the format `<ClassName: 0x1234abcd; key1 = "value1"; key2 = "value2">`.
 */
extern NSString *_SPTPersistentCacheObjectDescription(id<NSObject> object, id<NSObject> firstValue, ...);

/**
 Creates a standardized description string for the given _object_ and a variable list of _value_ to _key_ pairs.

 The function takes a variable list of value and key pairs. Just like the variadic `NSDictionary` initializer. It
 will automatically insert the termination sentinel for you.

 @return A standardized description string on the format `<ClassName: 0x1234abcd; key1 = "value1"; key2 = "value2">`.
 */
#define SPTPersistentCacheObjectDescription(object, firstValue, ...) _SPTPersistentCacheObjectDescription((object), (firstValue), __VA_ARGS__, SPTPersistentCacheObjectDescriptionTerminationSentinel)
