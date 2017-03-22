//
//  CLDApplication.m
//  Comedy Lab Dataset Viewer
//
//  Created by TBZ.PhD on 22/03/2017.
//  Copyright © 2017 Cognitive Science Group, Queen Mary University of London. All rights reserved.
//

#import "CLDApplicationDelegate.h"

@implementation CLDApplicationDelegate

- (void)applicationWillFinishLaunching:(nonnull NSNotification *)notification
{
    // Opt-out of full-sceen menuitem, mostly because it spoils the View menu.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSFullScreenMenuItemEverywhere"];
    
    // Opt-out of tabs, mostly because the auto-generated menu item spoils the View menu.
    [NSWindow setAllowsAutomaticWindowTabbing:NO];
}

@end
