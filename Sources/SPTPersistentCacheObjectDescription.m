// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "SPTPersistentCacheObjectDescription.h"

id const SPTPersistentCacheObjectDescriptionTerminationSentinel = @"0xDEADC0DE";

NS_INLINE BOOL SPTIsObjectDescriptionTerminationSentinel(id const object)
{
    return object == SPTPersistentCacheObjectDescriptionTerminationSentinel;
}

static void SPTPersistentCacheObjectDescriptionAppendToString(NSMutableString *description, id<NSObject> object, id<NSObject> firstValue, va_list valueKeyPairs)
{
    NSCParameterAssert(description);
    NSCParameterAssert(object);

    id<NSObject> value = firstValue;
    id<NSObject> key = va_arg(valueKeyPairs, id);

    while (!SPTIsObjectDescriptionTerminationSentinel(value) && !SPTIsObjectDescriptionTerminationSentinel(key)) {
        if (value != object && key != object) {
            [description appendFormat:@"; %@ = \"%@\"", key, value];
        }

        value = va_arg(valueKeyPairs, id);
        if (SPTIsObjectDescriptionTerminationSentinel(value)) {
            break;
        }

        key = va_arg(valueKeyPairs, id);
    }

}

NSString *_SPTPersistentCacheObjectDescription(id<NSObject> object, id<NSObject> firstValue, ...)
{
    if (object == nil) {
        return nil;
    }

    NSString * const objectClassName = NSStringFromClass(object.class);
    NSMutableString * const description = [NSMutableString stringWithFormat:@"<%@: %p", objectClassName, (void *)object];

    NSString * (^ const closeAndReturnDescriptionBlock)(void) = ^{
        [description appendString:@">"];
        return [description copy];
    };

    if (SPTIsObjectDescriptionTerminationSentinel(firstValue)) {
        return closeAndReturnDescriptionBlock();
    }

    va_list valueKeyPairs;
    va_start(valueKeyPairs, firstValue);
    SPTPersistentCacheObjectDescriptionAppendToString(description, object, firstValue, valueKeyPairs);
    va_end(valueKeyPairs);

    return closeAndReturnDescriptionBlock();
}
