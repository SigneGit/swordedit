//
//  Scripter.h
//  swordedit
//
//  Created by Fred Havemeyer on 5/28/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "HaloMap.h"
#import "Scenario.h"

@interface Scripter : NSObject {
	HaloMap *_mapfile;
	Scenario *_scenario;
}

@end
