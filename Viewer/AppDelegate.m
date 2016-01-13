//
//  AppDelegate.m
//  PersistentCacheViewver
//
//  Created by Dmitry Ponomarev on 10/11/14.
//  Copyright (c) 2014 Dmitry Ponomarev. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"

@interface AppDelegate ()

//@property (weak) IBOutlet NSWindow *window;
@property (strong) MainWindowController *mainWindowController;
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
