// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "AppDelegate.h"
#import "MainWindowController.h"

@interface AppDelegate ()

//@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) MainWindowController *mainWindowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    // load the app's main window from an external nib for display
    _mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
    [self.mainWindowController showWindow:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
