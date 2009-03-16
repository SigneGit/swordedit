//
//  
//  swordedit
//
//  Created by sword on 5/11/08.
//

#import <Cocoa/Cocoa.h>

#import "defines.h"

#import "HaloMap.h"
#import "MapTag.h"

@class TextureManager;

@interface ModelTag : MapTag {
	HaloMap *_mapfile;
	
	TextureManager *_texManager;
	
	NSMutableArray *subModels;
	NSMutableArray *shaders;
	
	float u_scale;
	float v_scale;
	
	MODEL_REGION *regions;
	
	reflexive regionRef;
	
	int numRegions;
	
	BOUNDING_BOX *bb;
	
	BOOL moving;
	BOOL selected;
}
- (id)initWithMapFile:(HaloMap *)map texManager:(TextureManager *)texManager;
- (void)dealloc;
- (void)releaseGeometryObjects;
- (void)determineBoundingBox;
- (BOUNDING_BOX *)bounding_box;
- (float)u_scale;
- (float)v_scale;
- (int)numRegions;
- (void)drawAtPoint:(float *)point lod:(int)lod isSelected:(BOOL)isSelected useAlphas:(BOOL)useAlphas;
- (void)loadAllBitmaps;
- (long)shaderIdentForIndex:(int)index;
- (void)drawBoundingBox;
- (void)drawAxes:(BOOL)withPointerArrow;
- (TextureManager *)_texManager;
- (void)renderPartyTriangle;
@end