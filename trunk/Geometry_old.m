//
//  Geometry.m
//  swordedit
//
//  Copyright 2007 sword Inc. All rights reserved.
//
//	sword@clanhalo.net
//
// Why reinvent the wheel?

#include <string.h>

#import "Geometry_old.h"
#import "ModelTag.h"

@implementation Geometry_old
- (id)initWithMap:(HaloMap *)map modelTagPointer:(ModelTag *)m_pointer
{
	if ((self = [super init]) != nil)
	{
		_mapfile = [map retain];
		
		parent = [m_pointer retain]; // pointer to the parent model tag
				
		vertex_size = [_mapfile indexHead].vertex_size;
		vertex_offset = [_mapfile indexHead].vertex_offset;
		[_mapfile readBlockOfData:&me.junk size_of_buffer:36];
		partsref = [_mapfile readReflexive];
		
		numParts = partsref.chunkcount;
		textures = malloc(numParts * sizeof(GLuint));
		[_mapfile seekToAddress:partsref.offset];
		// In bob's words, "go to the parts"
		int x;
		parts = malloc(sizeof(part) * partsref.chunkcount);
		for (x = 0; x < numParts; x++)
		{
			part *currentPart = &parts[x];
			[_mapfile readBlockOfData:currentPart->junk4 size_of_buffer:4];
			[_mapfile readShort:&currentPart->shaderIndex];
			[_mapfile readBlockOfData:currentPart->junk size_of_buffer:66];
			
			// In bob's words, "read indices pointer"
			[_mapfile readLong:&currentPart->indexPointer.count];
			[_mapfile readLong:&currentPart->indexPointer.rawPointer[0]];
			[_mapfile readLong:&currentPart->indexPointer.rawPointer[1]];
			
			if (currentPart->indexPointer.rawPointer[1] != currentPart->indexPointer.rawPointer[0])
				NSLog(@"BadPartInt!"); // Whatever the hell that is
				
			// In bob's words, "junk"
			[_mapfile readBlockOfData:currentPart->junk2 size_of_buffer:4];
			
			// In bob's words, "read vertex pointer"
			[_mapfile readLong:&currentPart->vertPointer.count];
			[_mapfile readBlockOfData:currentPart->vertPointer.junk size_of_buffer:8];
			[_mapfile readLong:&currentPart->vertPointer.rawPointer];
			
			// In bob's words, "junk"
			[_mapfile readBlockOfData:currentPart->junk3 size_of_buffer:28];
			
			long endOfPart = [_mapfile currentOffset];
			[_mapfile seekToAddress:currentPart->vertPointer.rawPointer+vertex_offset];
			
			currentPart->vertices = malloc(sizeof(Vector) * currentPart->vertPointer.count);
			int i;
			for (i = 0; i < currentPart->vertPointer.count; i++)
			{
				Vector *currentVertex = &currentPart->vertices[i];
				[_mapfile readFloat:&currentVertex->x];
				[_mapfile readFloat:&currentVertex->y];
				[_mapfile readFloat:&currentVertex->z];
				
				[_mapfile readFloat:&currentVertex->normalx];
				[_mapfile readFloat:&currentVertex->normaly];
				[_mapfile readFloat:&currentVertex->normalz];
				[_mapfile skipBytes:24];
				[_mapfile readFloat:&currentVertex->u];
				[_mapfile readFloat:&currentVertex->v];
				[_mapfile skipBytes:12];
			}
			
			[_mapfile seekToAddress:(currentPart->indexPointer.rawPointer[0] + vertex_offset + vertex_size)];
			currentPart->indices = malloc(sizeof(unsigned short) * (currentPart->indexPointer.count + 2));
				// No clue why its +2, lol
			for (i = 0; i < currentPart->indexPointer.count + 2; i++)
				[_mapfile readShort:&currentPart->indices[i]];
			
			[_mapfile seekToAddress:endOfPart];
		}
	}
	return self;
}
- (void)dealloc 
{
	[parent release];
	if (parts->vertices) free(parts->vertices);
	if (parts->indices) free(parts->indices);
	if (parts) free(parts);
	if (textures) free(textures);
	[pathToFile release];
	[_mapfile release];
	[super dealloc];
}
- (BOUNDING_BOX)determineBoundingBox
{
	BOUNDING_BOX bb;
	bb.min[0] = 50000;
	bb.min[1] = 50000;
	bb.min[2] = 50000;
	bb.max[0] = -50000;
	bb.max[1] = -50000;
	bb.max[2] = -50000;
	int x;
	for (x=0;x<numParts;x++)
	{
		part currentPart = parts[x];
		int y;
		for (y=0;y<currentPart.vertPointer.count;y++)
		{
			if (currentPart.vertices[y].x>bb.max[0])
				bb.max[0]=currentPart.vertices[y].x;
			if (currentPart.vertices[y].y>bb.max[1])
				bb.max[1]=currentPart.vertices[y].y;
			if (currentPart.vertices[y].z>bb.max[2])
				bb.max[2]=currentPart.vertices[y].z;
			if (currentPart.vertices[y].x<bb.min[0])
				bb.min[0]=currentPart.vertices[y].x;
			if (currentPart.vertices[y].y<bb.min[1])
				bb.min[1]=currentPart.vertices[y].y;
			if (currentPart.vertices[y].z<bb.min[2])
				bb.min[2]=currentPart.vertices[y].z;
		}
	}
	return bb;
}
- (void)loadBitmaps
{
	// Need to finish bitmap tags first
	long index;
	NSLog(@"Loading bitmaps!");
	for (index = 0; index < numParts; index++)
	{
		
	}
}
- (void)releaseBitmaps
{
	glDeleteTextures(numParts,&textures[0]);
}
- (void)drawIntoView
{
	int i, x;
	part currentPart;
	float	u_scale,
			v_scale;
			
	u_scale = [parent u_scale];
	v_scale = [parent v_scale];
	
	for (i = 0; i < numParts; i++)
	{
		currentPart = parts[i];
		/*glBindTexture(GL_TEXTURE_2D, textures[i]);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		glEnable(GL_TEXTURE_2D);*/
		
		if (currentPart.indexPointer.rawPointer[0] == currentPart.indexPointer.rawPointer[1])
		{
			glBegin(GL_TRIANGLE_STRIP);
			unsigned short index;
			for (x = 0; x < currentPart.indexPointer.count + 2; x++)
			{
				index = currentPart.indices[x];
				Vector *tempVector = &currentPart.vertices[index];
				glNormal3f(tempVector->normalx, tempVector->normaly, tempVector->normalz);
				//glTexCoord2f(tempVector->u * u_scale, tempVector->v * v_scale);
				glVertex3f(tempVector->x, tempVector->y, tempVector->z);
			}
			glEnd();
			glDisable(GL_TEXTURE_2D);
		}
		else
		{
			NSLog(@"Bad part!");
		}
	}
	glFlush();
}
@end
