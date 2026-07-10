#import <Foundation/Foundation.h>
#import "NSFileManagerMock.h"

NS_INLINE NSBundle *SPTTestBundle(void)
{
#ifdef SWIFTPM_MODULE_BUNDLE
    return SWIFTPM_MODULE_BUNDLE;
#else
    return [NSBundle bundleForClass:[NSFileManagerMock class]];
#endif
}
