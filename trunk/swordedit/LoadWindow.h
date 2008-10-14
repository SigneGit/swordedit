//
//  LoadWindow.h
//  swordedit
//
//  Created by Fred Havemeyer on 8/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LoadWindow : NSObject {

}

+ (LoadWindow *)sharedInstance;
- (id)init;
- (IBAction)showPanel:(id)sender;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
@end
