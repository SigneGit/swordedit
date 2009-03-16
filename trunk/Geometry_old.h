//
//  Geometry.h
//  swordedit
//
//  Copyright 2007 sword Inc. All rights reserved.
//
//	sword@clanhalo.net
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#import "HaloMap.h"
#import "ModelTag.h"

@class ModelTag;
@class Geometry;
typedef struct
{
	char junk[36];
	reflexive parts;
} geometry;
typedef struct
{
	long count;
	long rawPointer[2];
} indicesPointer;
typedef struct
{
	long count;
	char junk[8];
	long rawPointer;
} verticesPointer;
typedef struct
{
	float x;
	float y;
	float z;
	float normalx;
	float normaly;
	float normalz;
	float u;
	float v;
} Vector;
typedef struct
{
	char junk4[4];
	short shaderIndex;
	char junk[66];
	indicesPointer indexPointer;
	char junk2[4];
	verticesPointer vertPointer;
	char junk3[28];
	Vector *vertices;
	unsigned short *indices;
} part;

@interface Geometry_old : NSObject {
	long numParts;
	long vertex_size;
	long vertex_offset;
	
	GLuint *textures;
	
	HaloMap *_mapfile;
	
	NSString *pathToFile;
	
	ModelTag *parent;
	
	reflexive partsref;
	part *parts;
	geometry me;
}
- (id)initWithMap:(HaloMap *)map modelTagPointer:(ModelTag *)m_pointer;
- (BOUNDING_BOX)determineBoundingBox;
- (void)dealloc;
- (void)loadBitmaps;
- (void)releaseBitmaps;
- (void)drawIntoView;
@end
