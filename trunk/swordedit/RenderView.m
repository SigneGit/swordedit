//
//  RenderView.m
//  swordedit
//
//  Created by Fred Havemeyer on 5/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "RenderView.h"
#import "defines.h"

#import "Camera.h"

#import "GeneralMath.h"

#import "BSP.h"
#import "ModelTag.h"

#import "TextureManager.h"

#import "SpawnEditorController.h"
/*
	TODO:
		Fucking lookup selection lookup table is being fed very large values for some reason. Something to do with the names, have to check it out.
*/

@implementation RenderView
/* 
*
*		Begin RenderView Functions 
*
*/
- (id)initWithFrame: (NSRect) frame
{
	// First, we must create an NSOpenGLPixelFormatAttribute
	NSOpenGLPixelFormat *nsglFormat;
	NSOpenGLPixelFormatAttribute attr[] = 
	{
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 
		BITS_PER_PIXEL,
		NSOpenGLPFADepthSize, 
		DEPTH_SIZE,
		0 
	};

    [self setPostsFrameChangedNotifications: YES];
	
	// Next, we initialize the NSOpenGLPixelFormat itself
    nsglFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
	
	// Check for errors in the creation of the NSOpenGLPixelFormat
    // If we could not create one, return nil (the OpenGL is not initialized, and
    // we should send an error message to the user at this point)
    if(!nsglFormat) { NSLog(@"Invalid format... terminating."); return nil; }
	
	// Now we create the the CocoaGL instance, using our initial frame and the NSOpenGLPixelFormat
    self = [super initWithFrame:frame pixelFormat:nsglFormat];
    [nsglFormat release];
	
	// If there was an error, we again should probably send an error message to the user
    if(!self) { NSLog(@"Self not created... terminating."); return nil; }
	
	// Now we set this context to the current context (means that its now drawable)
    [[self openGLContext] makeCurrentContext];
	
	// Finally, we call the initGL method (no need to make this method too long or complex)
    [self initGL];
    return self;
}
- (void)initGL
{
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClearDepth(1.0f);
	glDepthFunc(GL_LESS);
	glEnable(GL_DEPTH_TEST);
	
	glHint(GL_POLYGON_SMOOTH_HINT,GL_NICEST);
	
	first = YES;
}
- (void)prepareOpenGL
{
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClearDepth(1.0f);
	glDepthFunc(GL_LESS);
	glEnable(GL_DEPTH_TEST);
	
	glHint(GL_POLYGON_SMOOTH_HINT,GL_NICEST);
	
	first = YES;
	//NSLog(@"end initGL");
}
- (void)awakeFromNib
{
	
	_fps = 15;
	drawTimer = [[NSTimer timerWithTimeInterval:(1.0/_fps)
										target:self
										selector:@selector(timerTick:)
										userInfo:nil
										repeats:YES]
										retain
										];
	[[NSRunLoop currentRunLoop] addTimer:drawTimer forMode:(NSString *)kCFRunLoopCommonModes];
	
	prefs = [NSUserDefaults standardUserDefaults];
	[self loadPrefs];
	
	shouldDraw = NO;
	
	_camera = [[Camera alloc] init];
	acceleration = 0;
	cameraMoveSpeed = 0.5;
	maxRenderDistance = 100.0f;
	
	selectDistance = 100.0f;
	rendDistance = 50.0f;
	
	meshColor.blue = 1.0;
	meshColor.green = 0.1;
	meshColor.red = 0.1;
	meshColor.color_count = 0;
	
	color_index = alphaIndex;
	
	currentRenderStyle = textured_tris;
	
	_LOD = 4;
	
	_selectType = 0;
	s_acceleration = 1.0f;
	
	[fpsText setFloatValue:15.0];
	[bspNumbersButton removeAllItems];
	
	_mode = rotate_camera;
	[moveCameraMode setState:NSOnState];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
	
	[_spawnEditor setUpdateDelegate:self];
	
	selections = [[NSMutableArray alloc] initWithCapacity:300]; // Default it at 300, but possible to expand if needed lol.
	
	//selections = [[NSMutableArray alloc] initWithCapacity:1000];
	
	_lineWidth = 1.5f;
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	//switch (NSRunAlertPanel(@"Are you sure you want to quit?",@"I thought you loved me!",@"I do!",nil,nil))
	//{
		
	//}
}
- (void)reshape
{
	NSSize sceneBounds = [self frame].size;
	glViewport(0,0,sceneBounds.width,sceneBounds.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(45.0f,
					(sceneBounds.width / sceneBounds.height),
					0.1f,
					400.0f);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}
- (BOOL)acceptsFirstResponder
{ 
	return YES; 
}
- (BOOL)becomeFirstResponder
{ 
	return YES; 
}
- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters = [theEvent characters];
	unichar character = [characters characterAtIndex:0];
	//NSLog(@"%x", character);
	switch (character)
	{
		case 'w':
			move_keys_down[0].direction = forward;
			move_keys_down[0].isDown = YES;
			break;
		case 's':
			move_keys_down[1].direction = back;
			move_keys_down[1].isDown = YES;
			break;
		case 'a':
			move_keys_down[2].direction = left;
			move_keys_down[2].isDown = YES;
			break;
		case 'd':
			move_keys_down[3].direction = right;
			move_keys_down[3].isDown = YES;
			break;
		case ' ':
			move_keys_down[4].direction = up;
			move_keys_down[4].isDown = YES;
			break;
		case 'c':
			move_keys_down[5].direction = down;
			move_keys_down[5].isDown = YES;
			break;
		case 0xF700: // Forward Key
			if (_mode == rotate_camera)
				[_camera MoveCamera:0.1];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.y += 1;
				[self performTranslation:fakeDownPoint zEdit:FALSE];
			}
			break;
		case 0xF701: // Back Key
			if (_mode == rotate_camera)
				[_camera MoveCamera:-0.1];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.y -= 1;
				[self performTranslation:fakeDownPoint zEdit:FALSE];
			}
			break;
		case 0xF702: // Left Key
			if (_mode == rotate_camera)
				[_camera StrafeCamera:-0.1];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.x -= 1;
				[self performTranslation:fakeDownPoint zEdit:FALSE];
			}
			break;
		case 0xF703: // Right Key
			if (_mode == rotate_camera)
				[_camera StrafeCamera:0.1f];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.x += 1;
				[self performTranslation:fakeDownPoint zEdit:FALSE];
			}
			break;
		case 0x2E: // ? key
			if (_mode == rotate_camera)
				[_camera LevitateCamera:0.1f];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.y += 1;
				[self performTranslation:fakeDownPoint zEdit:TRUE];
			}
			break;
		case 0x2C: // > key
			if (_mode == rotate_camera)
				[_camera LevitateCamera:-0.1f];
			if (_mode == translate)
			{
				NSPoint fakeDownPoint = prevDown;
				fakeDownPoint.y -= 1;
				[self performTranslation:fakeDownPoint zEdit:TRUE];
			}
			break;
		case 'l':
			NSLog(@"Camera z coord: %f", [_camera position][2]);
			break;
	}
}
- (void)keyUp:(NSEvent *)event
{
	unichar character = [[event characters] characterAtIndex:0];
	switch (character)
	{
		case 'w':
			move_keys_down[0].isDown = NO;
			break;
		case 's':
			move_keys_down[1].isDown = NO;
			break;
		case 'a':
			move_keys_down[2].isDown = NO;
			break;
		case 'd':
			move_keys_down[3].isDown = NO;
			break;
		case ' ':
			move_keys_down[4].isDown = NO;
			break;
		case 'c':
			move_keys_down[5].isDown = NO;
			break;
	}
}
- (void)mouseUp:(NSEvent *)theEvent
{
}
- (void)mouseDown:(NSEvent *)event
{
	NSPoint downPoint = [event locationInWindow];
	prevDown = [NSEvent mouseLocation];
	
	if (_mode == select && _mapfile)
		[self trySelection:downPoint shiftDown:(([event modifierFlags] & NSShiftKeyMask) != 0)];
}
- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint dragPoint = [NSEvent mouseLocation];
	if (_mode == rotate_camera)
		[_camera HandleMouseMove:(dragPoint.x - prevDown.x) dy:(dragPoint.y - prevDown.y)];
	if (_mode == translate)
	{
		[self performTranslation:dragPoint zEdit:(([theEvent modifierFlags] & NSControlKeyMask) != 0)];
	}
	if ((([theEvent modifierFlags] & NSControlKeyMask) != 0) && _mode != translate)
		[_camera HandleMouseMove:(dragPoint.x - prevDown.x) dy:(dragPoint.y - prevDown.y)];
	prevDown = dragPoint;
}
- (void)mouseMoved:(NSEvent *)theEvent
{
	//NSPoint pt = [theEvent locationInWindow];
}
- (void)rightMouseDown:(NSEvent *)event
{
	prevRightDown = [NSEvent mouseLocation];
}
- (void)rightMouseUp:(NSEvent *)theEvent
{

}
- (void)rightMouseDragged:(NSEvent *)event
{
	NSPoint rightDragPoint = [NSEvent mouseLocation];
	[_camera HandleMouseMove:(rightDragPoint.x - prevRightDown.x) dy:(rightDragPoint.y - prevRightDown.y)];
	prevRightDown = rightDragPoint;
}
- (void)timerTick:(NSTimer *)timer
{
	// In here we handle a few things, mmk?
	int x;
	BOOL key_is_down = NO;
	
	for (x = 0; x < 6; x++)
	{
		if (move_keys_down[x].isDown)
		{
			key_is_down = YES;
			switch (move_keys_down[x].direction)
			{
				case forward:
					[_camera MoveCamera:(cameraMoveSpeed + acceleration)];
					break;
				case back:
					[_camera MoveCamera:(-1 * (cameraMoveSpeed + acceleration))];
					break;
				case left:
					[_camera StrafeCamera:(-1 * (cameraMoveSpeed + acceleration))];
					break;
				case right:
					[_camera StrafeCamera:(cameraMoveSpeed + acceleration)];
					break;
				case down:
					[_camera LevitateCamera:(-1 * (cameraMoveSpeed + acceleration))]; 
					break;
				case up:
					[_camera LevitateCamera:(cameraMoveSpeed + acceleration)];
					break;
			}
		}
	}
	if (key_is_down)
	{
		if (accelerationCounter > 10 && accelerationCounter < 15)
			acceleration += 0.1;
		if (accelerationCounter > 15 && accelerationCounter < 20)
			acceleration += 0.2;
		if (accelerationCounter > 20 && accelerationCounter < 25 && _fps < 40)
			acceleration += 0.2;
		if (accelerationCounter > 25 && acceleration < 30 && _fps < 30)
			acceleration += 0.2;
		
		accelerationCounter += 1;
	}
	else
	{
		acceleration = 0;
		accelerationCounter = 0;
	}
	
	if (shouldDraw)
	{
		[self reshape];
		[self setNeedsDisplay:YES];
	}
}
/* 
	Override the view's drawRect: to draw our GL content.
*/	 
- (void)drawRect:(NSRect)rect
{	
	glLoadIdentity();
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	[_camera Look];
	[_camera Update];
	
	[self drawAxes];
	
	if (shouldDraw)
	{
		if (mapBSP)
		{
			[self renderVisibleBSP:FALSE];
		}
		
		if (_scenario)
		{
			[self renderAllMapObjects];
		}
	}
	
	[[self openGLContext] flushBuffer];
}
- (void)loadPrefs
{
	//NSLog(@"Loading preferences!");
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	_useAlphas = [userDefaults boolForKey:@"_useAlphas"];
	[useAlphaCheckbox setState:_useAlphas];
	
	[lodDropdownButton selectItemAtIndex:[userDefaults integerForKey:@"_LOD"]];
	switch ([lodDropdownButton indexOfSelectedItem])
	{
		case 0:
			_LOD = 0;
			break;
		case 1:
			_LOD = 2;
			break;
		case 2:
			_LOD = 4;
			break;
	}
}
- (void)releaseMapObjects
{
	shouldDraw = NO;
	[[self openGLContext] flushBuffer];
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	[self initGL];
	[_texManager release];
	[_mapfile release];
	[_scenario release];
	[mapBSP release];
	
	[self deselectAllObjects];
}
- (void)setMapObject:(HaloMap *)mapfile
{
	int i;
	float x,y,z;
	
	_mapfile = [mapfile retain];
	_scenario = [[mapfile scenario] retain];
	mapBSP = [[mapfile bsp] retain];
	_texManager = [[mapfile _texManager] retain];
	if (_mapfile && _scenario && mapBSP)
		shouldDraw = YES;
	[bspNumbersButton removeAllItems];
	for (i = 0; i < [mapBSP NumberOfBsps]; i++)
		[bspNumbersButton addItemWithTitle:[[NSNumber numberWithInt:i+1] stringValue]];
	[mapBSP GetActiveBspCentroid:&x center_y:&y center_z:&z];
	[_camera PositionCamera:(x + 5.0f) positionY:(y + 5.0f) positionZ:(z + 5.0f)
						viewX:x viewY:y viewZ:z
						upVectorX:0.0f upVectorY:0.0f upVectorZ:1.0f];
		
	activeBSPNumber = 0;
}
- (void)lookAt:(float)x y:(float)y z:(float)z
{
	[_camera PositionCamera:[_camera position][0] positionY:[_camera position][1] positionZ:[_camera position][2] 
				viewX:x viewY:y viewZ:z 
				upVectorX:0.0f upVectorY:0.0f upVectorZ:1.0f];
}
- (void)stopDrawing
{
	//int i;
	shouldDraw = NO;
	[[self openGLContext] flushBuffer];
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
}
- (void)resetTimerWithClassVariable
{
	[drawTimer invalidate];
	[drawTimer release];
	drawTimer = [[NSTimer timerWithTimeInterval:(1.0/_fps)
						target:self
						selector:@selector(timerTick:)
						userInfo:nil
						repeats:YES]
						retain];
	[[NSRunLoop currentRunLoop] addTimer:drawTimer forMode:(NSString *)kCFRunLoopCommonModes];
	shouldDraw = YES;
}
/* 
*
*		End RenderView Functions 
*
*/

/* 
*
*		Begin BSP Rendering 
*
*/
- (void)renderVisibleBSP:(BOOL)selectMode
{
	unsigned int mesh_count;
	int i;
	
	if (shouldDraw)
	{
		mesh_count = [mapBSP GetActiveBspSubmeshCount];
		
		[self resetMeshColors];
		
		for (i = 0; i < mesh_count; i++)
		{
			if ((currentRenderStyle == point) || (currentRenderStyle == wireframe) || (currentRenderStyle == flat_shading))
				[self setNextMeshColor];
			
			switch (currentRenderStyle)
			{
				case point:
					[self renderBSPAsPoints:i];
					break;
				case wireframe:
					glLineWidth(1.0f);
					[self renderBSPAsWireframe:i];
					break;
				case flat_shading:
					[self renderBSPAsFlatShadedPolygon:i];
					break;
				case textured_tris:
					[self renderBSPAsTexturedAndLightmaps:i];
					glLineWidth(2.0f);
					glColor3f(0.5f, 0.5f, 0.5f);
					break;
			}
		}
	}
}
- (void)renderBSPAsPoints:(int)mesh_index
{
	SUBMESH_INFO *pMesh;
	int i;
	
	pMesh = [mapBSP GetActiveBspPCSubmesh:mesh_index];
	
	glBegin(GL_POINTS);
	for (i = 0; i < pMesh->IndexCount; i++)
	{
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[0]].vertex_k));
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[1]].vertex_k));
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[2]].vertex_k));
	}
	glEnd();
}
- (void)renderBSPAsWireframe:(int)mesh_index
{
	SUBMESH_INFO *pMesh;
	int i;
	
	pMesh = [mapBSP GetActiveBspPCSubmesh:mesh_index];
	
	glLineWidth(_lineWidth);
	
	glBegin(GL_LINES);
	for (i = 0; i < pMesh->IndexCount; i++)
	{
		// First line:(0 -> 1)
		{
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[0]].vertex_k);
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[1]].vertex_k);
		}
		// Second line :(1 -> 2)
		{
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[1]].vertex_k);
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[2]].vertex_k);
		}
		// Third line :(2 -> 0)
		{
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[2]].vertex_k);
			glVertex3fv(pMesh->pVert[pMesh->pIndex[i].tri_ind[0]].vertex_k);
		}
	}
	glEnd();
}
- (void)renderBSPAsFlatShadedPolygon:(int)mesh_index
{
	SUBMESH_INFO *pMesh;
	int i;
	
	pMesh = [mapBSP GetActiveBspPCSubmesh:mesh_index];
	
	glBegin(GL_TRIANGLES);
	[self setNextMeshColor];
	for (i = 0; i < pMesh->IndexCount; i++)
	{
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[0]].vertex_k));
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[1]].vertex_k));
		glVertex3fv((float *)(pMesh->pVert[pMesh->pIndex[i].tri_ind[2]].vertex_k));
	}
	glEnd();
}
- (void)renderBSPAsTexturedAndLightmaps:(int)mesh_index
{
	SUBMESH_INFO *pMesh;
	
	pMesh = [mapBSP GetActiveBspPCSubmesh:mesh_index];
	
	if (pMesh->ShaderIndex == -1)
	{
		glColor3f(0.1f, 0.1f, 0.1f);
	}
	else
	{
		if (pMesh->LightmapIndex != -1)
			glEnable(GL_TEXTURE_2D);
		
		[_texManager activateTextureOfIdent:pMesh->DefaultBitmapIndex subImage:0 useAlphas:NO];
		
		glColor4f(1,1,1,1);
			
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
		glVertexPointer(3, GL_FLOAT, 56, pMesh->pVert[0].vertex_k);
	
		glTexCoordPointer(2, GL_FLOAT, 56, pMesh->pVert[0].uv);
			
		glDrawElements(GL_TRIANGLES, (pMesh->IndexCount * 3), GL_UNSIGNED_SHORT, pMesh->pIndex);
		
		glDisableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
			
		glDisable(GL_TEXTURE_2D);
		glDisable(GL_BLEND);
		
	}
}
- (void)drawAxes
{
	// Red is X
	// White is Y
	// Blue is Z
	/*glBegin(GL_LINES);
		glColor3f(1.0f,0.0f,0.0f);
		glVertex3f(15.0f,0.0f,0.0f);
		glVertex3f(-15.0f,0.0f,0.0f);
		
		glColor3f(1.0f, 1.0f, 1.0f);
		glVertex3f(0.0f,15.0f,0.0f);
		glVertex3f(0.0f,-15.0f,0.0f);
		
		glColor3f(0.0f,0.0f, 1.0f);
		glVertex3f(0.0f, 0.0f, 15.0f);
		glVertex3f(0.0f, 0.0f, -15.0f);
	glEnd();*/
	glBegin(GL_LINES);
		// Z
		glColor3f(0,0,1);
		glVertex3f(0,0,0);
		glVertex3f(0,0,100);

		// Y
		glColor3f(0,1,0);
		glVertex3f(0,0,0);
		glVertex3f(0,100,0);
  
		// X
		glColor3f(1,0,0);
		glVertex3f(0,0,0);
		glVertex3f(100,0,0);
  glEnd();
}
- (void)resetMeshColors
{
	meshColor.red = meshColor.green = meshColor.blue = 1.0f;
	meshColor.color_count = 0;
}
- (void)setNextMeshColor
{
	if (meshColor.red < 0.2)
		meshColor.red = 1;
	if (meshColor.blue < 0.2)
		meshColor.blue = 1;
	if (meshColor.green < 0.2)
		meshColor.green = 1;
	
	if ((meshColor.color_count%3) == 0);
		meshColor.red -= 0.1f;
	if ((meshColor.color_count%3) == 1)
		meshColor.blue -= 0.1f;
	if ((meshColor.color_count%3) == 2)
		meshColor.green -= 0.1f;
	
	meshColor.color_count++;
	
	glColor3f(meshColor.red, meshColor.green, meshColor.blue);
}
/* 
*
*		End BSP Rendering 
*
*/

/*
* 
*		Begin scenario rendering
* 
*/
- (float)distanceToObject:(float *)d
{
	return (float)sqrt(powf(d[0] - [_camera position][0],2) + powf(d[1] - [_camera position][1], 2) + powf(d[2] - [_camera position][2], 2));
}
- (void)renderAllMapObjects
{
	int x, i, name = 1;
	float pos[6], distanceTo;
	
	vehicle_spawn *vehi_spawns;
	scenery_spawn *scen_spawns;
	mp_equipment *equipSpawns;
	machine_spawn *mach_spawns;
	player_spawn *spawns;
	
	glInitNames();
	glPushName(0);
	
	// This one does its own namings
	[self renderNetgameFlags:&name];
	
	/*SkyBox *tmpBox = [_scenario sky];
	
	[[_mapfile tagForId:tmpBox[0].modelIdent] drawAtPoint:pos lod:4 isSelected:NO];*/
	
	vehi_spawns = [_scenario vehi_spawns];
		
	scen_spawns = [_scenario scen_spawns];
		
	equipSpawns = [_scenario item_spawns];
		
	spawns = [_scenario spawns];
	
	mach_spawns = [_scenario mach_spawns];
	
	glColor4f(0.0f,0.0f,0.0f,1.0f);
	
	for (x = 0; x < [_scenario player_spawn_count]; x++)
	{
		// Lookup goes hur
		if (_lookup)
			_lookup[name] = (long)(s_playerspawn * 10000 + x);
		glLoadName(name);
		name++;
		if (spawns[x].bsp_index == activeBSPNumber)
			[self renderPlayerSpawn:spawns[x].coord team:spawns[x].team_index isSelected:spawns[x].isSelected];
	}
	for (x = 0; x < [_scenario item_spawn_count]; x++)
	{
		// Lookup goes hur
		if (_lookup)
			_lookup[name] = (long)(s_item * 10000 + x); 
		glLoadName(name);
		name++;
		if ([_mapfile isTag:equipSpawns[x].modelIdent])
		{
			for (i = 0; i < 3; i++)
				pos[i] = equipSpawns[x].coord[i];
			pos[3] = equipSpawns[x].yaw;
			pos[4] = pos[5] = 0.0f;
			distanceTo = [self distanceToObject:pos];
			if (distanceTo < rendDistance || equipSpawns[x].isSelected)
				[[_mapfile tagForId:equipSpawns[x].modelIdent] drawAtPoint:pos lod:_LOD isSelected:equipSpawns[x].isSelected useAlphas:_useAlphas];
		}
	}
	for (x = 0; x < [_scenario mach_spawn_count]; x++)
	{
		if (_lookup)
			_lookup[name] = (long)(s_machine * 10000 + x);
		glLoadName(name);
		name++;
		if ([_mapfile isTag:[_scenario mach_references][mach_spawns[x].numid].machTag.TagId])
		{
			/*for (i = 0; i < 3; i++)
				pos[i] = mach_spawns[x].coord[i];
			for (i = 3; i < 6; i++)
				pos[i] = mach_spawns[x].rotation[i - 3];*/
			distanceTo = [self distanceToObject:pos];
			
			if ((distanceTo < rendDistance || mach_spawns[x].isSelected) && mach_spawns[x].desired_permutation == activeBSPNumber)
				[[_mapfile tagForId:[_scenario mach_references][mach_spawns[x].numid].modelIdent] drawAtPoint:mach_spawns[x].coord lod:_LOD isSelected:mach_spawns[x].isSelected useAlphas:_useAlphas];
		}
	}
	for (x = 0; x < [_scenario vehicle_spawn_count]; x++)
	{
		// Lookup goes hur
		if (_lookup)
			_lookup[name] = (long)(s_vehicle * 10000 + x);
		glLoadName(name);
		name++;
		if ([_mapfile isTag:vehi_spawns[x].modelIdent])
		{	
			//NSLog(@"Vehi Model Ident: 0x%x", vehi_spawns[x].modelIdent);
			for (i = 0; i < 3; i++)
				pos[i] = vehi_spawns[x].coord[i];
			for (i = 3; i < 6; i++)
				pos[i] = vehi_spawns[x].rotation[i - 3];
			distanceTo = [self distanceToObject:pos];
			/*if (distanceTo > 40)
				lod = 0;
			else if (distanceTo > 25 && distanceTo < 40)
				lod = 1;
			else
				lod = 4;*/
			if ((distanceTo < rendDistance || vehi_spawns[x].isSelected) && vehi_spawns[x].desired_permutation == activeBSPNumber)
				[[_mapfile tagForId:vehi_spawns[x].modelIdent] drawAtPoint:pos lod:_LOD isSelected:vehi_spawns[x].isSelected useAlphas:_useAlphas];
		}
	}
	for (x = 0; x < [_scenario scenery_spawn_count]; x++)
	{	
		// Lookup goes hur
		if (_lookup)
			_lookup[name] = (long)(s_scenery * 10000 + x);
		glLoadName(name);
		name++;
		if ([_mapfile isTag:scen_spawns[x].modelIdent])
		{
			for (i = 0; i < 3; i++)
				pos[i] = scen_spawns[x].coord[i];
			for (i = 3; i < 6; i++)
				pos[i] = scen_spawns[x].rotation[i - 3];
			distanceTo = [self distanceToObject:pos];
			/*if (distanceTo > 40)
				lod = 0;
			else if (distanceTo > 25 && distanceTo < 40)
				lod = 1;
			else
				lod = 4;*/
			if ((distanceTo < rendDistance || scen_spawns[x].isSelected) && scen_spawns[x].desired_permutation == activeBSPNumber)
				[[_mapfile tagForId:scen_spawns[x].modelIdent] drawAtPoint:pos lod:_LOD isSelected:scen_spawns[x].isSelected useAlphas:_useAlphas];
		}
	}		
	//NSLog(@"Name count: %d", name);
}
- (void)renderPlayerSpawn:(float *)coord team:(int)team isSelected:(BOOL)isSelected
{
	if (team == 0)
		glColor3f(1.0,0.0,0.0);
	else if (team == 1)
		glColor3f(0.0,0.0,1.0);
	if (isSelected)
		glColor3f(0.0f, 1.0f, 0.0f);
	
	
	glPushMatrix();
	glTranslatef(coord[0], coord[1], coord[2]);
	glRotatef(coord[3] * 57.29577, 0, 0,1);

	glBegin(GL_QUADS);
	{
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(0.2f,0.2f,-0.1f);
		
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);
		glVertex3f(0.2f,0.2f,-0.1f);
		
		glVertex3f(0.2f,0.2f,-0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);	
	}
	glEnd();
	if (isSelected)
	{
		glBegin(GL_LINES);
		{
			// Now to try some other stuffs! Bwahaha!
			// set these lines to white
			glLineWidth(2.0f);
			// x
			glColor3f(1.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(50.0f,0.0f,0.0f);
			// y
			glColor3f(0.0f,1.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,50.0f,0.0f);
			// z
			glColor3f(0.0f,0.0f,1.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,50.0f);
		}
		glEnd();
	}
	glPopMatrix();
	glEndList();
}
- (void)renderBox:(float *)coord rotation:(float *)rotation color:(float *)color selected:(BOOL)selected
{
	glPushMatrix();
	glTranslatef(coord[0], coord[1], coord[2]);
	glRotatef(piradToDeg( rotation[0]),0,0,1);
	glColor3f(color[0],color[1],color[2]);
	
	// lol, override
	if (selected)
		glColor3f(0.0f, 1.0f, 0.0f);
		
	glBegin(GL_QUADS);
	{
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(0.2f,0.2f,-0.1f);
		
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		
		glVertex3f(-0.2f,-0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		
		glVertex3f(0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);
		glVertex3f(0.2f,0.2f,-0.1f);
		
		glVertex3f(0.2f,0.2f,-0.1f);
		glVertex3f(0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,-0.2f,-0.1f);
		glVertex3f(-0.2f,0.2f,-0.1f);	
	}
	glEnd();
	if (selected)
	{
		glBegin(GL_LINES);
		{
			// Now to try some other stuffs! Bwahaha!
			// set these lines to white
			glLineWidth(4.0f);
			// x
			glColor3f(1.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(50.0f,0.0f,0.0f);
			// y
			glColor3f(0.0f,1.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,50.0f,0.0f);
			// z
			glColor3f(0.0f,0.0f,1.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,50.0f);
			// pointer arrow
			glColor3f(1.0f,1.0f,1.0f);
			glVertex3f(0.5f,0.0f,0.0f);
			glVertex3f(0.3f,0.2f,0.0f);
			glVertex3f(0.5f,0.0f,0.0f);
			glVertex3f(0.3f,-0.2f,0.0f);
		}
		glEnd();
	}
	glPopMatrix();
}
- (void)renderFlag:(float *)coord team:(int)team isSelected:(BOOL)isSelected
{	
	glPushMatrix();
	glTranslatef(coord[0], coord[1], coord[2]);
	
	if (team == 0)
		glColor3f(1.0,0.0,0.0);
	else if (team == 1)
		glColor3f(0.0,0.0,1.0);
	if (isSelected)
		glColor3f(0.0f, 1.0f, 0.0f);
		
	glBegin(GL_QUADS);
	{
		glVertex3f(0.1f,0.05f,0.6f);
		glVertex3f(0.1f,-0.05f,0.6f);
		glVertex3f(-0.1f,-0.05f,0.6f);
		glVertex3f(-0.1f,0.05f,0.6f);
		
		glVertex3f(0.1f,0.05f,0.6f);
		glVertex3f(0.1f,-0.05f,0.6f);
		glVertex3f(0.1f,-0.05f,-0.2f);
		glVertex3f(0.1f,0.05f,-0.2f);
		
		glVertex3f(-0.1f,-0.05f,0.6f);
		glVertex3f(0.1f,-0.05f,0.6f);
		glVertex3f(0.1f,-0.05f,-0.2f);
		glVertex3f(-0.1f,-0.05f,-0.2f);
		
		glVertex3f(-0.1f,-0.05f,0.6f);
		glVertex3f(-0.1f,0.05f,0.6f);
		glVertex3f(-0.1f,0.05f,-0.2f);
		glVertex3f(-0.1f,-0.05f,-0.2f);
		
		glVertex3f(0.1f,0.05f,0.6f);
		glVertex3f(-0.1f,0.05f,0.6f);
		glVertex3f(-0.1f,0.05f,-0.2f);
		glVertex3f(0.1f,0.05f,-0.2f);
		
		glVertex3f(0.1f,0.05f,-0.2f);
		glVertex3f(0.1f,-0.05f,-0.2f);
		glVertex3f(-0.1f,-0.05f,-0.2f);
		glVertex3f(-0.1f,0.05f,-0.2f);
	}
	glEnd();
	if (isSelected)
	{
		glBegin(GL_LINES);
		{
			// Now to try some other stuffs! Bwahaha!
			// set these lines to white
			glLineWidth(2.0f);
			// x
			glColor3f(1.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(50.0f,0.0f,0.0f);
			// y
			glColor3f(0.0f,1.0f,0.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,50.0f,0.0f);
			// z
			glColor3f(0.0f,0.0f,1.0f);
			glVertex3f(0.0f,0.0f,0.0f);
			glVertex3f(0.0f,0.0f,50.0f);
		}
		glEnd();
	}
	glPopMatrix();
}
- (void)renderNetgameFlags:(int *)name
{
	int i;
	float color[3];
	float rotation[3];
	multiplayer_flags *mp_flags;
	
	mp_flags = [_scenario netgame_flags];
	
	for (i = 0; i < [_scenario multiplayer_flags_count]; i++)
	{	
		// Name convention is going to be the following:
		/*
			10000 * the type + the index
			This way, I can go like so:
		*/
		
		rotation[0] = mp_flags[i].rotation; rotation[1] = rotation[2] = 0.0f;
		
		glLoadName(*name);
		// Lookup goes hur
		if (_lookup)
			_lookup[*name] = (long)((s_netgame * 10000) + i);
		*name += 1; // For some reason it won't increment when I go *name++;
		switch (mp_flags[i].type)
		{
			case ctf_flag:
				[self renderFlag:mp_flags[i].coord team:mp_flags[i].team_index isSelected:mp_flags[i].isSelected];
				break;
			case ctf_vehicle:
				break;
			case oddball:
				//NSLog(@"Oddball attempt ID: 0x%x", mp_flags[i].item_used.TagId);
				break;
			case race_track:
				break;
			case race_vehicle:
				break;
			case vegas_bank:
				break;
			case teleporter_entrance:
				color[0] = 1.0f; color[1] = 1.0f; color[2] = 0.2f;
				[self renderBox:mp_flags[i].coord rotation:rotation color:color selected:mp_flags[i].isSelected];
				break;
			case teleporter_exit:
				color[0] = 0.2f; color[1] = 1.0f; color[2] = 1.0f;
				[self renderBox:mp_flags[i].coord rotation:rotation color:color selected:mp_flags[i].isSelected];
				break;
			case hill_flag:
				color[0] = 0.4f; color [1] = color[2] = 0.0f;
				[self renderBox:mp_flags[i].coord rotation:rotation color:color selected:mp_flags[i].isSelected];
				break;
		}
	}
}
/*
* 
*		End scenario rendering
* 
*/

/*
* 
*		Begin GUI interfacing functions
* 
*/
- (IBAction)renderBSPNumber:(id)sender
{
	activeBSPNumber = [sender indexOfSelectedItem];
	[mapBSP setActiveBsp:[sender indexOfSelectedItem]];
	[self recenterCamera:self];
}
- (IBAction)sliderChanged:(id)sender
{
	if (sender == framesSlider)
	{
		_fps = roundf([framesSlider floatValue]);
		[fpsText setFloatValue:_fps];
		[self resetTimerWithClassVariable];
	}
	else if (sender == s_accelerationSlider)
	{
		// Time to abuse floor()
		s_acceleration = floorf([s_accelerationSlider floatValue] * 10 + 0.5)/10;
		[s_accelerationText setStringValue:[[[NSNumber numberWithFloat:s_acceleration] stringValue] stringByAppendingString:@"x"]];
	}
	else if ((sender == s_xRotation) || (sender == s_yRotation) || (sender == s_zRotation))
	{
		[self rotateFocusedItem:[s_xRotation floatValue] y:[s_yRotation floatValue] z:[s_zRotation floatValue]];
	}
}
- (IBAction)buttonPressed:(id)sender
{
	if (sender == selectMode || sender == m_SelectMode)
	{
		_mode = select;
		[self unpressButtons];
		[selectMode setState:NSOnState];
	}
	else if (sender == translateMode || sender == m_TranslateMode)
	{
		_mode = translate;
		[self unpressButtons];
		[translateMode setState:NSOnState];
	}
	else if (sender == moveCameraMode || sender == m_MoveCamera)
	{
		_mode = rotate_camera;
		[self unpressButtons];
		[moveCameraMode setState:NSOnState];
	}
	else if (sender == duplicateSelected || sender == m_duplicateSelected)
	{
		unsigned int type, index, nameLookup;

		if (!selections || [selections count] == 0)
			return;
		
		nameLookup = [[selections objectAtIndex:0] unsignedIntValue];
	
		type = (unsigned int)(nameLookup / 10000);
		index = (unsigned int)(nameLookup % 10000);
		[selections replaceObjectAtIndex:0 withObject:[NSNumber numberWithUnsignedInt:[_scenario duplicateScenarioObject:type index:index]]];
		_selectFocus = [[selections objectAtIndex:0] longValue];
	}
	else if (sender == s_spawnCreateButton)
	{
		// Since I only have the option to create a teleporter pair now, lets just do that.
		if (_mapfile)
		{
			[self deselectAllObjects];
			[self processSelection:(unsigned int)[_scenario createTeleporterPair:[_camera vView]]];
		}
	}
	else if (sender == b_deleteSelected || sender == m_deleteFocused)
	{
		unsigned int type, index, nameLookup;

		if (!selections || [selections count] == 0)
			return;
		
		nameLookup = [[selections objectAtIndex:0] unsignedIntValue];
	
		type = (unsigned int)(nameLookup / 10000);
		index = (unsigned int)(nameLookup % 10000);
		[_scenario deleteScenarioObject:type index:index];
		
		[self deselectAllObjects];
		
		[_spawnEditor reloadAllData];
	}
	else if (sender == selectedSwapButton)
	{
		unsigned int type, index;
		short *numid;
		
		type = (unsigned int)(_selectFocus / 10000);
		index = (unsigned int)(_selectFocus % 10000);
		
		switch (type)
		{
			case s_scenery:
				numid = &[_scenario scen_spawns][index].numid;
				*numid = [sender indexOfSelectedItem];
				[_scenario scen_spawns][index].modelIdent = [_scenario baseModelIdent:[_scenario scen_references][*numid].scen_ref.TagId];
				#ifdef __DEBUG__
				NSLog([[_mapfile tagForId:[_scenario scen_spawns][index].modelIdent] tagName]);
				#endif
				break;
			case s_item:
				[_scenario item_spawns][index].itmc.TagId = [_mapfile itmcIdForKey:[sender indexOfSelectedItem]];
				[_scenario item_spawns][index].modelIdent = [_scenario itmcModelForId:[_scenario item_spawns][index].itmc.TagId];
				break;
		}
		[self fillSelectionInfo];
	}
	else if (sender == useAlphaCheckbox)
	{
		_useAlphas = ([useAlphaCheckbox state] ? TRUE : FALSE);
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults setBool:_useAlphas forKey:@"_useAlphas"];
		[userDefaults synchronize];
	}
	else if (sender == lodDropdownButton)
	{
		switch ([lodDropdownButton indexOfSelectedItem])
		{
			case 0:
				_LOD = 0;
				break;
			case 1:
				_LOD = 2;
				break;
			case 2:
				_LOD = 4;
				break;
		}
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults setInteger:[lodDropdownButton indexOfSelectedItem] forKey:@"_LOD"];
		[userDefaults synchronize];
	}
}
- (void)lookAtFocusedItem
{
	float *coord;
	unsigned int type, index;
	type = (unsigned int)(_selectFocus / 10000);
	index = (unsigned int)(_selectFocus % 10000);
	
	switch (type)
	{
		case s_scenery:
			coord = [_scenario scen_spawns][index].coord;
			break;
		case s_item:
			coord = [_scenario item_spawns][index].coord;
			break;
		case s_playerspawn:
			coord = [_scenario spawns][index].coord;
			break;
	}
	
	[_camera PositionCamera:[_camera position][0] positionY:[_camera position][1] positionZ:[_camera position][2] 
							viewX:coord[0] viewY:coord[1] viewZ:coord[2] 
							upVectorX:0.0f upVectorY:0.0f upVectorZ:1.0f];
}
- (IBAction)recenterCamera:(id)sender
{
	float x,y,z;
		[mapBSP GetActiveBspCentroid:&x center_y:&y center_z:&z];
		[_camera PositionCamera:(x + 5.0f) positionY:(y + 5.0f) positionZ:(z + 5.0f)
						viewX:x viewY:y viewZ:z
						upVectorX:0.0f upVectorY:0.0f upVectorZ:1.0f];
}
- (IBAction)orientCamera:(id)sender
{

}
- (IBAction)changeRenderStyle:(id)sender
{
	[pointsItem setState:NSOffState];
	[wireframeItem setState:NSOffState];
	[shadedTrisItem setState:NSOffState];
	[texturedItem setState:NSOffState];
	if (sender == pointsItem || sender == buttonPoints)
		currentRenderStyle = point;
	else if (sender == wireframeItem || sender == buttonWireframe)
		currentRenderStyle = wireframe;
	else if (sender == shadedTrisItem || sender == buttonShadedFaces)
		currentRenderStyle = flat_shading;
	else if (sender == texturedItem || sender == buttonTextured)
		currentRenderStyle = textured_tris;
	[sender setState:NSOnState];
}
- (IBAction)setCameraSpawn:(id)sender
{
	
	NSData *camDat = [NSData dataWithBytes:&camCenter[0] length:12];
	[prefs setObject:camDat forKey:[[_mapfile mapName] stringByAppendingFormat:@"camDat_0%d", activeBSPNumber]];
	//[prefs setObject:camDat forKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_0"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	camDat = [NSData dataWithBytes:&camCenter[1] length:12];
	[prefs setObject:camDat forKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_1"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	camDat = [NSData dataWithBytes:&camCenter[2] length:12];
	[prefs setObject:camDat forKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_@"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	[prefs synchronize];
	
}
- (IBAction)setSelectionMode:(id)sender
{
	_selectType = [sender indexOfSelectedItem];
}
- (IBAction)killKeys:(id)sender
{
	int i;
	for (i = 0; i < 6; i++)
		move_keys_down[i].isDown = NO;
}
- (void)setRotationSliders:(float)x y:(float)y z:(float)z
{
	x = fabs(piradToDeg(x));
	y = fabs(piradToDeg(y));
	z = fabs(piradToDeg(z));
	
	[s_xRotation setFloatValue:x];
	[s_yRotation setFloatValue:y];
	[s_zRotation setFloatValue:z];
	
	[s_xRotText setFloatValue:x];
	[s_yRotText setFloatValue:y];
	[s_zRotText setFloatValue:z];
}
- (void)unpressButtons
{
	[selectMode setState:NSOffState];
	[translateMode setState:NSOffState];
	[moveCameraMode setState:NSOffState];
}
- (void)updateSpawnEditorInterface
{
	unsigned int type, index;
	type = (unsigned int)(_selectFocus / 10000);
	index = (unsigned int)(_selectFocus % 10000);
	
	// Here we now send these values to the spawn editor.
}
// This little baby will go ahead and find the location of a spawn where the ray from the mouse intersects the BSP, thus you can select stuff.
- (void)findSelectedSpawnCoord
{
}
/*
* 
*		End GUI interfacing functions
* 
*/


/*
*
*	Begin Scenario Editing Functions
*
*/
- (void)trySelection:(NSPoint)downPoint shiftDown:(BOOL)shiftDown
{
	// Thank you, http://glprogramming.com/red/chapter13.html
	
	
	// Adjustment that, for some reason, is necessary.
	downPoint.x -= 25.0f;
	downPoint.y -= 71.0f;
	
	GLsizei bufferSize = (GLsizei) ([_scenario vehicle_spawn_count] + 
									[_scenario scenery_spawn_count] + 
									[_scenario item_spawn_count] + 
									[_scenario multiplayer_flags_count] +
									[_scenario player_spawn_count] +
									[_scenario mach_spawn_count]);
	GLuint nameBuf[bufferSize];
	GLuint tmpLookup[bufferSize];
	GLint viewport[4];
	GLuint hits;
	unsigned int i, j, z1, z2;
	
	if (!selections)
		selections = [[NSMutableArray alloc] initWithCapacity:(bufferSize * 3)]; // Three times too big for meh.
	
	// Lookup is our name lookup table for the hits we get.
	_lookup = (GLuint *)tmpLookup;
	
	
	glGetIntegerv(GL_VIEWPORT,viewport);
	
	//glMatrixMode(GL_PROJECTION);
	
	glSelectBuffer(bufferSize,nameBuf);
	glRenderMode(GL_SELECT);
	
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	gluPickMatrix((GLdouble)downPoint.x,(GLdouble)downPoint.y,1.0f,1.0f,viewport);
	
	gluPerspective(45.0f,(GLfloat)(viewport[2] - viewport[0])/(GLfloat)(viewport[3] - viewport[1]),0.1f,100.0f);
	
	glMatrixMode(GL_MODELVIEW);
	
	// This kick starts names
	[self renderAllMapObjects];
	
	
	
	[self reshape];
	hits = glRenderMode(GL_RENDER);
	
	GLuint names, *ptr = (GLuint *)nameBuf;
	unsigned int type;
	BOOL hasFound = FALSE;
	
	if (hits == 0 || !shiftDown)
		[self deselectAllObjects];
		
	/*
	type = (long)(tableVal / 10000);
	index = (tableVal % 10000);
	*/
	
	for (i = 0; i < hits; i++)
	{
		names = *ptr;
		ptr++;
		z1 = (float)*ptr/0x7fffffff;
		ptr++;
		z2 = (float)*ptr/0x7fffffff;
		ptr++;
		for ( j = 0; j < names; j++)
		{
			if (z2 < selectDistance)
			{
				type = (unsigned int)(_lookup[*ptr] / 10000);
				if (type == _selectType || _selectType == s_all)
				{
					[self processSelection:(unsigned int)_lookup[*ptr]];
					hasFound = TRUE;
				}
				ptr++;
				if (hasFound)
					break;
			}
		}
		if (hasFound)
			break;
	}
	_lookup = NULL;
}
- (void)deselectAllObjects
{
	int x;
	for (x = 0; x < [_scenario vehicle_spawn_count]; x++)
		[_scenario vehi_spawns][x].isSelected = NO;
	for (x = 0; x < [_scenario scenery_spawn_count]; x++)
		[_scenario scen_spawns][x].isSelected = NO;
	for (x = 0; x < [_scenario item_spawn_count]; x++)
		[_scenario item_spawns][x].isSelected = NO;
	for (x = 0; x < [_scenario player_spawn_count]; x++)
		[_scenario spawns][x].isSelected = NO;
	for (x = 0; x < [_scenario multiplayer_flags_count]; x++)
		[_scenario netgame_flags][x].isSelected = NO;
	for (x = 0; x < [_scenario mach_spawn_count]; x++)
		[_scenario mach_spawns][x].isSelected = NO;
	[selectText setStringValue:[[NSNumber numberWithInt:0] stringValue]];
	[selectedName setStringValue:@""];
	[selectedType setStringValue:@""];
	[selections removeAllObjects];
	[selectedSwapButton removeAllItems];
}
- (void)processSelection:(unsigned int)tableVal
{
	unsigned int type, index;
	long mapIndex;
	BOOL overrideString;
	
	type = (long)(tableVal / 10000);
	index = (tableVal % 10000);
	
	_selectFocus = tableVal;
	
	[selections addObject:[NSNumber numberWithLong:tableVal]];
	[selectText setStringValue:[[NSNumber numberWithInt:[selections count]] stringValue]];
	
	[selectedSwapButton removeAllItems];
	
	[_spawnEditor loadFocusedItemData:_selectFocus];
	
	switch (type)
	{
		case s_scenery:
			if (_selectType == s_all || _selectType == s_scenery)
			{
				[_scenario scen_spawns][index].isSelected = YES;
				mapIndex = [_scenario scen_references][[_scenario scen_spawns][index].numid].scen_ref.TagId;
				[self setRotationSliders:[_scenario scen_spawns][index].rotation[0] y:[_scenario scen_spawns][index].rotation[1] z:[_scenario scen_spawns][index].rotation[2]];
				
				[selectedSwapButton addItemsWithTitles:(NSArray *)[_scenario scenTagArray]];
			}
			break;
		case s_playerspawn:
			if (_selectType == s_all || _selectType == s_playerspawn)
			{
				[_scenario spawns][index].isSelected = YES;
				switch ([_scenario spawns][index].team_index)
				{
					case 0:
						[selectedType setStringValue:@"Red Team"];
						break;
					case 1:
						[selectedType setStringValue:@"Blue Team"];
						break;
				}
				[self setRotationSliders:[_scenario spawns][index].rotation y:0 z:0];
				overrideString = TRUE;
			}
			break;
		case s_vehicle:
			if (_selectType == s_all || _selectType == s_vehicle)
			{
				[_scenario vehi_spawns][index].isSelected = YES;
				mapIndex = [_scenario vehi_references][[_scenario vehi_spawns][index].numid].vehi_ref.TagId;
				[self setRotationSliders:[_scenario vehi_spawns][index].rotation[0] y:[_scenario vehi_spawns][index].rotation[1] z:[_scenario vehi_spawns][index].rotation[2]];
			}
			break;
		case s_machine:
			if (_selectType == s_all || _selectType == s_machine)
			{
				[_scenario mach_spawns][index].isSelected = YES;
				mapIndex = [_scenario mach_references][[_scenario mach_spawns][index].numid].machTag.TagId;
				[self setRotationSliders:[_scenario mach_spawns][index].rotation[0] y:[_scenario mach_spawns][index].rotation[1] z:[_scenario mach_spawns][index].rotation[2]];
			}
			break;
		case s_netgame:
			if (_selectType == s_all || _selectType == s_netgame)
			{
				[_scenario netgame_flags][index].isSelected = YES;
				switch ([_scenario netgame_flags][index].type)
				{
					case teleporter_entrance:
						[selectedType setStringValue:@"Teleporter Entrance"];
						#ifdef __DEBUG__
						NSLog(@"Teleporter entrance type: %d, index: %d", [_scenario netgame_flags][index].type, [_scenario netgame_flags][index].team_index);
						#endif
						break;
					case teleporter_exit:
						[selectedType setStringValue:@"Teleporter Exit"];
						break;
					case ctf_flag:
						[selectedType setStringValue:@"CTF Flag"];
						break;
					case ctf_vehicle:
						[selectedType setStringValue:@"CTF Vehicle"];
						break;
					case oddball:
						[selectedType setStringValue:@"Oddball"];
						break;
					case race_track:
						[selectedType setStringValue:@"Race Track Marker"];
						break;
					case race_vehicle:
						[selectedType setStringValue:@"Race Vehicle"];
						break;
					case vegas_bank:
						[selectedType setStringValue:@"Vegas Bank?"];
						break;
					case hill_flag:
						[selectedType setStringValue:@"KotH Hill Marker"];
						break;
				}
				[self setRotationSliders:[_scenario netgame_flags][index].rotation y:0 z:0];
				overrideString = YES;
			}
			break;
		case s_item:
			if (_selectType == s_all || _selectType == s_item)
			{
				[_scenario item_spawns][index].isSelected = YES;
				mapIndex = [_scenario item_spawns][index].itmc.TagId;
				[self setRotationSliders:[_scenario item_spawns][index].yaw y:0 z:0];
				
				[selectedSwapButton addItemsWithTitles:(NSArray *)[_mapfile itmcList]];
			}
			break;
	}
	if (type == s_playerspawn)
		[selectedName setStringValue:@"Player Spawn"];
	else if (type == s_netgame)
		[selectedName setStringValue:@"Netgame Flag"];
	else
		[selectedName setStringValue:[[_mapfile tagForId:mapIndex] tagName]];
	if (type != s_netgame && type != s_playerspawn)
		[selectedType setStringValue:[[NSString stringWithCString:[[_mapfile tagForId:mapIndex] tagClassHigh]] substringToIndex:4]];
	else if (overrideString)
		return; // lol, quick fix hur
	else
		[selectedType setStringValue:@"Non-Tag Object"];
}
- (void)fillSelectionInfo
{
	int type = (long)(_selectFocus / 10000);
	int index = (_selectFocus % 10000);
	long mapIndex;
	
	switch (type)
	{
		case s_scenery:
			if (_selectType == s_all || _selectType == s_scenery)
			{
				[_scenario scen_spawns][index].isSelected = YES;
				mapIndex = [_scenario scen_references][[_scenario scen_spawns][index].numid].scen_ref.TagId;
				[selectedName setStringValue:[[_mapfile tagForId:mapIndex] tagName]];
				[self setRotationSliders:[_scenario scen_spawns][index].rotation[0] y:[_scenario scen_spawns][index].rotation[1] z:[_scenario scen_spawns][index].rotation[2]];
			}
			break;
		case s_item:
			if (_selectType == s_all || _selectType == s_item)
			{
				[_scenario item_spawns][index].isSelected = YES;
				mapIndex = [_scenario item_spawns][index].itmc.TagId;
				[self setRotationSliders:[_scenario item_spawns][index].yaw y:0 z:0];
			}
			break;
	}
}
/*

*	Object Translation

*/
- (void)performTranslation:(NSPoint)downPoint zEdit:(BOOL)zEdit
{
	// Ok, lets see exactly where it is that the mouse is down and see what the delta value is.
	float move[3];
	unsigned int	i,
					nameLookup,
					type,
					index;
	
	move[2] = 0;
	
	if (!zEdit)
	{
		move[0] = (downPoint.x - prevDown.x);
		move[1] = (downPoint.y - prevDown.y);
		move[2] = 0;
	}
	else
	{
		move[0] = 0;
		move[1] = 0;
		move[2] = (downPoint.y - prevDown.y)/10;
	}
	
	// Lets proportion the changes.
	move[0] /= 200;
	move[1] /= 200;
	move[2] /= 10;
	
	// correct something now
	move[1] *= -1;
	
	if ([selections count] > 1)
	{
		//[self calculateTranslation:multi_move move:move];
		float *rMove;
		nameLookup = [[selections objectAtIndex:0] unsignedIntValue];
		type = (unsigned int)(nameLookup / 10000);
		index = (unsigned int)(nameLookup % 10000);
		
		/*
			Bad code standards from the start means that I have to explicetly choose the array of spawns to edit
			This looks so shitty
		*/
		switch (type)
		{
			case s_vehicle:
				rMove = [self getTranslation:[_scenario vehi_spawns][index].coord move:move];
				break;
			case s_scenery:
				rMove = [self getTranslation:[_scenario scen_spawns][index].coord move:move];
				break;
			case s_playerspawn:
				rMove = [self getTranslation:[_scenario spawns][index].coord move:move];
				break;
			case s_netgame:
				rMove = [self getTranslation:[_scenario netgame_flags][index].coord move:move];
				break;
			case s_item:
				rMove = [self getTranslation:[_scenario item_spawns][index].coord move:move];
				break;
			case s_machine:
				rMove = [self getTranslation:[_scenario mach_spawns][index].coord move:move];
				break;
		}
		
		/*
			Now we apply these moves.
			
			Oh my god this code looks like shit. 
			
			Sorry about this, when I began writing this program I didn't think it was necessary to
			have a way to ambiguously access scenario attributes.
		*/
		for (i = 0; i < [selections count]; i++)
		{
			nameLookup = [[selections objectAtIndex:i] unsignedIntValue];
			type = (unsigned int)(nameLookup / 10000);
			index = (unsigned int)(nameLookup % 10000);
			
			switch (type)
			{
				case s_vehicle:
					[self applyMove:[_scenario vehi_spawns][index].coord move:rMove];
					break;
				case s_scenery:
					[self applyMove:[_scenario scen_spawns][index].coord move:rMove];
					break;
				case s_playerspawn:
					[self applyMove:[_scenario spawns][index].coord move:rMove];
					break;
				case s_netgame:
					[self applyMove:[_scenario netgame_flags][index].coord move:rMove];
					break;
				case s_item:
					[self applyMove:[_scenario item_spawns][index].coord move:rMove];
					break;
				case s_machine:
					[self applyMove:[_scenario mach_spawns][index].coord move:rMove];
					break;
			}
		}
		
		free(rMove);
	}
	else if ([selections count] == 1)
	{
		nameLookup = [[selections objectAtIndex:0] unsignedIntValue];
		type = (unsigned int)(nameLookup / 10000);
		index = (unsigned int)(nameLookup % 10000);
		
		switch (type)
		{
			case s_vehicle:
				[self calculateTranslation:[_scenario vehi_spawns][index].coord move:move];
				break;
			case s_scenery:
				[self calculateTranslation:[_scenario scen_spawns][index].coord move:move];
				break;
			case s_playerspawn:
				[self calculateTranslation:[_scenario spawns][index].coord move:move];
				break;
			case s_netgame:
				[self calculateTranslation:[_scenario netgame_flags][index].coord move:move];
				break;
			case s_item:
				[self calculateTranslation:[_scenario item_spawns][index].coord move:move];
				break;
			case s_machine:
				[self calculateTranslation:[_scenario mach_spawns][index].coord move:move];
				break;
		}
	}
	
	// Now lets apply the transformations.
	/*for (i = 0; i < [selections count]; i++)
	{
		nameLookup = [[selections objectAtIndex:i] unsignedIntValue];
		type = (unsigned int)(nameLookup / 10000);
		index = (unsigned int)(nameLookup % 10000);
		
		switch (type)
		{
			case s_vehicle:
				[self calculateTranslation:[_scenario vehi_spawns][index].coord move:move];
				break;
			case s_scenery:
				[self calculateTranslation:[_scenario scen_spawns][index].coord move:move];
				break;
			case s_playerspawn:
				[self calculateTranslation:[_scenario spawns][index].coord move:move];
				break;
			case s_netgame:
				[self calculateTranslation:[_scenario netgame_flags][index].coord move:move];
				break;
			case s_item:
				[self calculateTranslation:[_scenario item_spawns][index].coord move:move];
				break;
			case s_machine:
				[self calculateTranslation:[_scenario mach_spawns][index].coord move:move];
				break;
		}
	}*/
	[_spawnEditor loadFocusedItemData:_selectFocus];
}
- (void)calculateTranslation:(float *)coord move:(float *)move
{
	/* God damn this is being a bitch with the vector functions */
	CVector3 viewDirection, cross;
	
	// Z-axis movement, return after done since we don't want this to conflict with xy plane movement.
	if (move[2])
	{
		coord[2] += (move[2] * s_acceleration);
		return;
	}
	
	//viewDirection = (CVector3)SubtractTwoVectors(NewCVector3([_camera position][0],[_camera position][1],[_camera position][2]),NewCVector3(coord[0], coord[1], coord[2]));
	viewDirection.x = [_camera position][0] - coord[0];
	viewDirection.y = [_camera position][1] - coord[1];
	viewDirection.z = [_camera position][2] - coord[2];
	
	
	coord[0] += (s_acceleration * move[1] * viewDirection.x);
	coord[1] += (s_acceleration * move[1] * viewDirection.y);
	
	//cross = (CVector3)Cross(NewCVector3(0,0,1),viewDirection);
	cross.x = ((0 * viewDirection.z) - (1 * viewDirection.y));
	cross.y = ((1 * viewDirection.x) - (0 * viewDirection.z));
	
	
	coord[0] += (s_acceleration * move[0] * cross.x);
	coord[1] += (s_acceleration * move[0] * cross.y);
}
- (float *)getTranslation:(float *)coord move:(float *)move
{
	CVector3 viewDirection, cross;
	float *rMove;
	
	rMove = malloc(sizeof(float) * 3);
	
	rMove[0] = rMove[1] = rMove[2] = 0.0f;
	
	if (move[2])
	{
		rMove[2] = (move[2] * s_acceleration);
		return rMove;
	}
	
	viewDirection.x = [_camera position][0] - coord[0];
	viewDirection.y = [_camera position][1] - coord[1];
	viewDirection.z = [_camera position][2] - coord[2];
	
	rMove[0] = (s_acceleration * move[1] * viewDirection.x);
	rMove[1] = (s_acceleration * move[1] * viewDirection.y);
	
	cross.x = ((0 * viewDirection.z) - (1 * viewDirection.y));
	cross.y = ((1 * viewDirection.x) - (0 * viewDirection.z));
	
	rMove[0] += (s_acceleration * move[0] * cross.x);
	rMove[1] += (s_acceleration * move[0] * cross.y);
	
	return rMove;
}
- (void)applyMove:(float *)coord move:(float *)move
{
	coord[0] += move[0];
	coord[1] += move[1];
	coord[2] += move[2];
}
- (void)rotateFocusedItem:(float)x y:(float)y z:(float)z
{
	int type, index;
	type = (_selectFocus / 10000);
	index = (_selectFocus % 10000);
	
	switch (type)
	{
		case s_vehicle:
			[_scenario vehi_spawns][index].rotation[0] = degToPiRad(x);
			[_scenario vehi_spawns][index].rotation[1] = degToPiRad(y);
			[_scenario vehi_spawns][index].rotation[2] = degToPiRad(z);
			[s_xRotText setFloatValue:x];
			[s_yRotText setFloatValue:y];
			[s_zRotText setFloatValue:z];
			break;
		case s_scenery:
			[_scenario scen_spawns][index].rotation[0] = degToPiRad(x);
			[_scenario scen_spawns][index].rotation[1] = degToPiRad(y);
			[_scenario scen_spawns][index].rotation[2] = degToPiRad(z);
			[s_xRotText setFloatValue:x];
			[s_yRotText setFloatValue:y];
			[s_zRotText setFloatValue:z];
			break;
		case s_playerspawn:
			[_scenario spawns][index].rotation = degToPiRad(x);
			[s_xRotText setFloatValue:x];
			[s_yRotText setFloatValue:0];
			[s_zRotText setFloatValue:0];
			break;
		case s_netgame:
			[_scenario netgame_flags][index].rotation = degToPiRad(x);
			[s_xRotText setFloatValue:x];
			[s_yRotText setFloatValue:0];
			[s_zRotText setFloatValue:0];
			break;
		case s_item:
			[_scenario item_spawns][index].yaw = degToPiRad(x);
			[s_xRotText setFloatValue:x];
			[s_yRotText setFloatValue:0];
			[s_zRotText setFloatValue:0];
			break;
	}
	[_spawnEditor loadFocusedItemData:_selectFocus];
}
/*
*
*	End Scenario Editing Functions
*
*/

/*
*
*	Begin miscellaneous functions
*
*/
- (void)loadCameraPrefs
{
	if (!_mapfile)
		return;
		
	NSData *camDat;
	
	camDat = [prefs objectForKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_0"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	[camDat getBytes:&camCenter[0] length:12];
	camDat = [prefs objectForKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_1"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	[camDat getBytes:&camCenter[1] length:12];
	camDat = [prefs objectForKey:[[[_mapfile mapName] stringByAppendingString:@"camDat_2"] stringByAppendingString:[[NSNumber numberWithInt:activeBSPNumber] stringValue]]];
	[camDat getBytes:&camCenter[2] length:12];
	
	[self recenterCamera:self];
}

- (void)renderPartyTriangle
{
	
	glTranslatef(2.0f,2.0f,0.0f);
	
	glBegin( GL_TRIANGLES );              // Draw a triangle
		glColor3f( 1.0f, 0.0f, 0.0f );        // Set color to red
		glVertex3f(  0.0f,  1.0f, 0.0f );     // Top of front
		glColor3f( 0.0f, 1.0f, 0.0f );        // Set color to green
		glVertex3f( -1.0f, -1.0f, 1.0f );     // Bottom left of front
		glColor3f( 0.0f, 0.0f, 1.0f );        // Set color to blue
		glVertex3f(  1.0f, -1.0f, 1.0f );     // Bottom right of front
			
		glColor3f( 1.0f, 0.0f, 0.0f );        // Red
		glVertex3f( 0.0f, 1.0f, 0.0f );       // Top of right side
		glColor3f( 0.0f, 0.0f, 1.0f );        // Blue
		glVertex3f( 1.0f, -1.0f, 1.0f );      // Left of right side
		glColor3f( 0.0f, 1.0f, 0.0f );        // Green
		glVertex3f( 1.0f, -1.0f, -1.0f );     // Right of right side

		glColor3f( 1.0f, 0.0f, 0.0f );        // Red
		glVertex3f( 0.0f, 1.0f, 0.0f );       // Top of back side
		glColor3f( 0.0f, 1.0f, 0.0f );        // Green
		glVertex3f( 1.0f, -1.0f, -1.0f );     // Left of back side
		glColor3f( 0.0f, 0.0f, 1.0f );        // Blue
		glVertex3f( -1.0f, -1.0f, -1.0f );    // Right of back side

		glColor3f( 1.0f, 0.0f, 0.0f );        // Red
		glVertex3f( 0.0f, 1.0f, 0.0f );       // Top of left side
		glColor3f( 0.0f, 0.0f, 1.0f );        // Blue
		glVertex3f( -1.0f, -1.0f, -1.0f );    // Left of left side
		glColor3f( 0.0f, 1.0f, 0.0f );        // Green
		glVertex3f( -1.0f, -1.0f, 1.0f );     // Right of left side
	glEnd();  // Done with triangle
}
/*
*
*	End miscellaneous functions
*
*/
@end
