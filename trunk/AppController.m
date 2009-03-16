//
//  AppController.m
//  swordedit
//
//  Created by sword on 10/21/07.
//  Copyright 2007 sword Inc. All rights reserved.
//
//	sword@clanhalo.net
//

#import "AppController.h"
#import "AboutBox.h"

#import "RenderView.h"
#import "BitmapView.h"
#import "SpawnEditorController.h"

@implementation AppController
+ (void)aMethod:(id)param
{
	//int x;
	//for (x = 0; x < 50; x++)
	//{
	//	printf("Object thread says x is %i\n", x);
	//	usleep(1);
	//}
}
- (void)awakeFromNib
{
	[NSApp setDelegate:self];
	
	/* Beta experation code */
	NSString *nowString = [NSString stringWithUTF8String:__DATE__];
	NSCalendarDate *nowDate = [NSCalendarDate dateWithNaturalLanguageString:nowString];
	NSCalendarDate *expireDate = [nowDate addTimeInterval:(60 * 60 * 24 * 10)];
	
	/*if ([expireDate earlierDate:[NSDate date]] == expireDate)
	{
		NSRunAlertPanel(@"Beta Expired!",@"Your swordedit beta has expired!",@"Oh woes me!", nil, nil);
		[[NSApplication sharedApplication] terminate:self];
	}
	else
	{
		NSRunAlertPanel(@"Welcome to the beta.", [[NSString stringWithString:@"swordedit beta expires on "] stringByAppendingString:[expireDate description]], @"I feel blessed!", nil, nil);
	}*/
	/* End beta experation code */
	
	userDefaults = [NSUserDefaults standardUserDefaults];
	
	[self loadPrefs];
	
	if (!bitmapFilePath)
	{
		[self selectBitmapLocation];
	}
	
	[mainWindow makeKeyAndOrderFront:self];
	[mainWindow center];
}
- (IBAction)loadMap:(id)sender
{
	NSOpenPanel *open = [NSOpenPanel openPanel];
	if ([open runModalForTypes:[NSArray arrayWithObjects:@"map", nil]] == NSOKButton)
	{
		#ifdef __DEBUG__
		printf("\n");
		NSLog(@"==============================================================================");
		NSDate *startTime = [NSDate date];
		NSLog([open filename]);
		NSLog(bitmapFilePath);
		#endif
		
		switch ([self loadMapFile:[open filename]])
		{
			case 0:
				#ifdef __DEBUG__
				NSLog(@"Loaded!");
				NSLog(@"Setting renderview map objects...");
				#endif
				
				[mainWindow makeKeyAndOrderFront:self];
				
				[rendView setMapObject:mapfile];
				[bitmapView setMapfile:mapfile];
				[spawnEditor setMapFile:mapfile];
				
				#ifdef __DEBUG__
				NSDate *endDate = [NSDate date];
				NSLog(@"Load duration: %f seconds", [endDate timeIntervalSinceDate:startTime]);
				#endif
				break;
			case 1:
				break;
			case 2:
				NSLog(@"The map name is invalid!");
				break;
			case 3:
				NSLog(@"Could not open the map!");
				break;
			default:
				break;
		}
		[mainWindow setTitle:[[NSString stringWithString:@"swordedit : "] stringByAppendingString:[mapfile mapName]]];
	}
	
}
- (IBAction)saveFile:(id)sender
{
	if (!mapfile)
	{
		NSRunAlertPanel(@"Error!",@"No mapfile currently open!", @"Ok", nil,nil);
		return;
	}
	if ((NSRunAlertPanel(@"Saving...", @"Are you sure you want to save?",@"Yes",@"No",nil)) == 1)
	{
		// do whatever the fuck you want
		[mapfile saveMap];
	}
}
- (IBAction)close:(id)sender
{
	#ifdef __DEBUG__
	NSLog(@"Closing!");
	#endif
	if (sender == mainWindow)
	{
		[self closeMapFile];
	}
	else if (sender == prefsWindow)
	{
		#ifdef __DEBUG__
		NSLog(@"Closing prefs!");
		#endif
		[prefsWindow performClose:sender];
	}
}
- (IBAction)showAboutBox:(id)sender
{
	[[AboutBox sharedInstance] showPanel:sender];
}
- (int)loadMapFile:(NSString *)location
{
	[self closeMapFile];
	mapfile = [[HaloMap alloc] initWithMapfiles:location bitmaps:bitmapFilePath];
	return [mapfile loadMap];
}
- (void)closeMapFile
{
	[rendView stopDrawing];
	if (mapfile)
	{
		[rendView releaseMapObjects];
		[bitmapView releaseAllObjects];
		[spawnEditor destroyAllMapObjects];
		[mapfile destroy];
		[mapfile release];
	}
}
- (void)loadPrefs
{
	firstTime = [userDefaults boolForKey:@"_firstTimeUse"];
	
	bitmapFilePath = [[userDefaults stringForKey:@"bitmapFileLocation"] retain];
	
	if (bitmapFilePath)
		[bitmapLocationText setStringValue:bitmapFilePath];
		
	// Heh, here's a logical fucker. When firstTime = FALSE, its the first time the program has been run.
	if (!firstTime)
	{
		[self runIntroShit];
	}
}
- (void)runIntroShit
{
	/*NSSound *genesis = [[NSSound alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Genesis.mp3"] byReference:NO];
	[genesis setDelegate:self];
	[genesis play];*/
	NSRunAlertPanel(@"Genesis",@"Welcome to swordedit! Since this is the first time you've run me, we'll have to set a few things first.",@"I'd be honored!",nil,nil);
	NSRunAlertPanel(@"Its bitmap time!",@"We'll begin by setting the location of your bitmap file. You'll be asked to specify the location of the bitmaps file you wish to use in just a moment.",@"Ok!",nil,nil);
	[self selectBitmapLocation];
	[bitmapLocationText setStringValue:bitmapFilePath];
	switch (NSRunAlertPanel(@"Phantoms, everywhere!",@"When rendering scenario objects, would you like their transparencies to be rendered?",@"I'd love it!",@"Boo, no!",nil))
	{
		case NSAlertDefaultReturn:
			[userDefaults setBool:YES forKey:@"_useAlphas"];
			break;
		case NSAlertAlternateReturn:
			[userDefaults setBool:NO forKey:@"_useAlphas"];
			break;
	}
	switch (NSRunAlertPanel(@"How meticulous are you?",@"What level of detail would you like map objects to be rendered with?",@"DETAILS! DETAILS! DETAILS!",@"Not too high but not too low.",@"As low as it goes, baby!"))
	{
		case NSAlertDefaultReturn:
			[userDefaults setInteger:2 forKey:@"_LOD"];
			break;
		case NSAlertAlternateReturn:
			[userDefaults setInteger:1 forKey:@"_LOD"];
			break;
		case NSAlertOtherReturn:
			[userDefaults setInteger:0 forKey:@"_LOD"];
			break;
	}
	NSRunAlertPanel(@"We're done here.",@"Thank you for your cooperation! You may change all of these settings while under the Rendering tab of the Scenario Editor on the main swordedit window.",@"Thank you too!",nil,nil);
	[userDefaults setBool:TRUE forKey:@"_firstTimeUse"];
	[userDefaults synchronize];
	[rendView loadPrefs];
}
- (BOOL)selectBitmapLocation
{
	NSOpenPanel *open = [NSOpenPanel openPanel];
	[open setTitle:@"Please select the bitmap file you wish to use."];
	if ([open runModalForTypes:[NSArray arrayWithObjects:@"map", nil]] == NSOKButton)
	{
		bitmapFilePath = [open filename];
		//NSLog(@"Bitmap file path: %@", bitmapFilePath);
		[userDefaults setObject:bitmapFilePath forKey:@"bitmapFileLocation"];
		[userDefaults synchronize];
		return TRUE;
	}
	else
	{
		bitmapFilePath = @"";
	}
	return FALSE;
}
- (IBAction)setNewBitmaps:(id)sender
{
	if ([self selectBitmapLocation])
	{
		[bitmapLocationText setStringValue:bitmapFilePath];
		if (mapfile)
		{
			[NSThread detachNewThreadSelector:@selector(aMethod:) toTarget:[AppController class] withObject:nil];
			switch ([self loadMapFile:[mapfile mapLocation]])
			{
				case 0:
					#ifdef __DEBUG__
					NSLog(@"Loaded!");
					NSLog(@"Setting renderview map objects...");
					#endif
					[rendView setMapObject:mapfile];
					[bitmapView setMapfile:mapfile];
					[spawnEditor setMapFile:mapfile];
					break;
				case 1:
					break;
				case 2:
					NSRunAlertPanel(@"OH SHIT",@"The map name is invalid!",@"OK SIR",nil,nil);
					#ifdef __DEBUG__
					NSLog(@"The map name is invalid!");
					#endif
					break;
				case 3:
					NSRunAlertPanel(@"OH SHIT",@"Could not open the map! What did you fuck up?!?!?!?",@"OH GOD, I'M SORRY!",nil,nil);
					#ifdef __DEBUG__
					NSLog(@"Could not open the map!");
					#endif
					break;
				default:
					break;
			}
		}
	}
}

-(void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([tabView indexOfTabViewItem:tabViewItem] > 0)
	{
		[rendView stopDrawing];
	}
	else if ([tabView indexOfTabViewItem:tabViewItem] == 0)
	{
		[rendView resetTimerWithClassVariable];
	}
}
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying
{
	NSLog(@"Sound released!");
	[sound release];
}
@end
