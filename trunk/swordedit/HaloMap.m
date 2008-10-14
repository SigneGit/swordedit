//
//  HaloMap.m
//  swordedit
//
//  Created by Fred Havemeyer on 5/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HaloMap.h"
#import "Scenario.h"
#import "BSP.h"
#import "ModelTag.h"
#import "BitmapTag.h"

#import "TextureManager.h"

#define IndexTagSize	-32

#define EndianSwap64(x) (((x & 0xFF00000000000000) >> 56) | ((x & 0x00FF000000000000) >> 40) | ((x & 0x0000FF0000000000) >> 24) | ((x & 0x000000FF00000000) >> 8) | ((x & 0x00000000FF000000) << 8) | ((x & 0x0000000000FF0000) << 24) | ((x & 0x000000000000FF00) << 40) |    ((x & 0x00000000000000FF) << 56))
#define EndianSwap32(x) (((x & 0xFF000000) >> 24) | ((x & 0x00FF0000) >> 8) | ((x & 0x0000FF00) << 8) | ((x & 0x000000FF) << 24))
#define EndianSwap16(x) (((x & 0x00FF) << 8) | ((x & 0xFF00) >> 8))

@implementation HaloMap
- (id)init
{
	if ((self = [super init]) != nil)
	{
	}
	return self;
}
- (id)initWithMapfiles:(NSString *)mapfile bitmaps:(NSString *)bitmaps
{
	if ((self = [super init]) != nil)
	{
		mapName = [mapfile retain];
		bitmapFilePath = [bitmaps retain];
	}
	return self;
}
- (void)destroy
{	
	[self closeMap];

	[tagArray removeAllObjects];
	[tagLookupDict removeAllObjects];
	[itmcList removeAllObjects];
	[itmcLookupDict removeAllObjects];
	[scenList removeAllObjects];
	[scenLookupDict removeAllObjects];
	[scenNameLookupDict removeAllObjects];
	[modTagList removeAllObjects];
	[modTagLookupDict removeAllObjects];
	[bitmTagList removeAllObjects];
	[bitmTagLookupDict removeAllObjects];
	
	[mapName release];
	[bitmapFilePath release];
	[tagArray release];
	[tagLookupDict release];
	[itmcList release];
	[itmcLookupDict release];
	[scenList release];
	[scenLookupDict release];
	[scenNameLookupDict release];
	[modTagList release];
	[modTagLookupDict release];
	[bitmTagList release];
	[bitmTagLookupDict release];
	
	[_texManager deleteAllTextures];
	[bspHandler destroyObjects];
	
	[_texManager release];
	[mapScenario release];
	[bspHandler release];
}
- (void)dealloc
{
	#ifdef __DEBUG__
	NSLog(@"Mapfile deallocating!");
	#endif
	
	[super dealloc];
}
- (BOOL)checkIsPPC
{
	unsigned int val;
	FILE *executable;
	executable = fopen(__FILE__,"r+");
	fread(&val,4,1,executable);
	fclose(executable);
	return (val == 0xFEEDFACE ? TRUE : FALSE);
}
/*
	@function loadMap, the actual map-loading function for the HaloMap class.
	
	Returns in the following manner:
		0 = successful load
		1 = lol dongs?
		2 = The map name is invalid
		3 = Could not open map
*/
- (int)loadMap
{
	// Quick hack
	isPPC = NO;
	
	// Use this for computing the tag location, mmk?
	if (mapName == nil)
		return 2;
	
	mapFile = fopen([mapName cString],"r+");
	
	if (!mapFile)
		return 3;
	
	bitmapsFile = fopen([bitmapFilePath cString], "r+");
	
	// Lets load the map header, ok?
	[self readLongAtAddress:&mapHeader.map_id address:0x0];
	
	#ifdef __DEBUG__
	printf("\n");
	NSLog(@"Header: 0x%x, swapped: 0x%x", mapHeader.map_id, EndianSwap32(mapHeader.map_id));
	#endif
	
	/* LETS SEE WHAT DIS IS */
	isPPC = [self checkIsPPC];
	/* SO IS IT PPC OR NOT?! */
	
	// Reload the map header
	[self readLongAtAddress:&mapHeader.map_id address:0x0];
	
	BOOL tmpPPC = isPPC;
	
	if (mapHeader.map_id == 0x18309 || mapHeader.map_id == 0x0)
	{
		mapHeader.version = 0x06000000;
		isPPC = NO;
		[self readBlockOfDataAtAddress:&mapHeader.builddate size_of_buffer:0x20 address:0x2C8]; // Map seeked to 0x2C4 now.
		[self readBlockOfDataAtAddress:&mapHeader.name size_of_buffer:0x20 address:0x58C];
		isPPC = tmpPPC;
		[self readLongAtAddress:&mapHeader.map_length address:0x5E8];
		[self readLong:&mapHeader.offsetToIndex];
		mapHeader.maptype = 0x01000000;
	}
	else
	{
		#ifdef __DEBUG__
		NSLog(@"Were Halo Full");
		#endif
		[self readLong:&mapHeader.version];
		[self readLong:&mapHeader.map_length];
		[self readLong:&mapHeader.zeros];
		[self readLong:&mapHeader.offsetToIndex];
		[self readLong:&mapHeader.metaSize];
		[self skipBytes:8];
		isPPC = NO;
		[self readBlockOfData:&mapHeader.name size_of_buffer:0x20];
		[self readBlockOfData:&mapHeader.builddate size_of_buffer:0x20];
		isPPC = tmpPPC;
		[self readLong:&mapHeader.maptype];
	}
	
	#ifdef __DEBUG__
	NSLog(@"File Header Version: 0x%x", mapHeader.version);
	NSLog(@"File Length: 0x%x", mapHeader.map_length);
	NSLog(@"Offset To Index: 0x%x", mapHeader.offsetToIndex);
	NSLog(@"Total Metadata Size: 0x%x", mapHeader.metaSize);
	NSLog(@"File Name: %s \n", (char *)mapHeader.name);
	NSLog(@"Build Date: %s \n", (char *)mapHeader.builddate);
	#endif
			
	// Index time!
	[self readLongAtAddress:&indexHead.indexMagic address:mapHeader.offsetToIndex];
	[self readLong:&indexHead.starting_id];
	[self readLong:&indexHead.vertexsize];
	[self readLong:&indexHead.tagcount];
	[self readLong:&indexHead.vertex_object_count];
	[self readLong:&indexHead.vertex_offset];
	[self readLong:&indexHead.indices_object_count];
	[self readLong:&indexHead.vertex_size];
	[self readLong:&indexHead.modelsize];
	[self readLong:&indexHead.tagstart];
	
	#ifdef __DEBUG__
	NSLog(@"Tag count: %d", indexHead.tagcount);
	NSLog(@"Tag starting id: 0x%x", indexHead.starting_id);
	#endif
	
	_magic = (indexHead.indexMagic - (mapHeader.offsetToIndex + 40));
	
	#ifdef __DEBUG__
	NSLog(@"Magic: [0x%x]", _magic);
	printf("\n");
	#endif
	
	// Now lets create and load our tag arrays
	tagArray = [[NSMutableArray alloc] initWithCapacity:indexHead.tagcount];
	tagLookupDict = [[NSMutableDictionary alloc] initWithCapacity:indexHead.tagcount];
	
	// Create our texture manager
	_texManager = [[TextureManager alloc] init];
	
	// Now I'm going to create a temporary tag pointer
	// We'll use this when loading... stuff
	MapTag *tempTag;
	
	int i,
		vehi_count = 0,
		scen_count = 0,
		itmc_count = 0,
		mod2_count = 0,
		bitm_count = 0,
		nextOffset,
		scenario_offset,
		itmc_counter = 0,
		scen_counter = 0,
		mod2_counter = 0,
		bitm_counter = 0;
		
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tempTag = [[MapTag alloc] initWithDataFromFile:self];
		nextOffset = [self currentOffset];
		
		//NSLog(@"Tag name: %@, id: 0x%x, offset in map: 0x%x", [tempTag tagName], [tempTag idOfTag], [tempTag offsetInMap]);
		
		if (i != 0)
			[[tagArray objectAtIndex:(i -1)] setTagLength:([tempTag offsetInMap] - [[tagArray objectAtIndex:(i - 1)] offsetInMap])];
		
		if (memcmp([tempTag tagClassHigh], (isPPC ? "scnr" : "rncs"), 4) == 0)
		{
			[self skipBytes:IndexTagSize];
			scenario_offset = [self currentOffset];
			// I'll load the scenario later
			[tagArray addObject:tempTag];
			[self seekToAddress:nextOffset];
		}
		else if (memcmp([tempTag tagClassHigh], (isPPC ? "mod2" : "2dom"), 4) == 0)
		{
			[self skipBytes:IndexTagSize];
			ModelTag *tempModel = [[ModelTag alloc] initWithMapFile:self texManager:_texManager];
			[tagArray addObject:tempModel];
			[tempModel releaseGeometryObjects];
			[tempModel release];
			
			// Increment our counter
			mod2_count++;
			
			[self seekToAddress:nextOffset];
		}
		else if (memcmp([tempTag tagClassHigh], (isPPC ? "bitm" : "mtib"), 4) == 0)
		{
			[self skipBytes:IndexTagSize];
			BitmapTag *tempBitmap = [[BitmapTag alloc] initWithMapFiles:self
														bitmap:bitmapsFile
														ppc:isPPC];
			[tagArray addObject:tempBitmap];
			[tempBitmap release];
			
			// Increment our counter
			bitm_count++;
			
			[self seekToAddress:nextOffset];
		}
		else
		{
			if (memcmp([tempTag tagClassHigh], (isPPC ? "vehi" : "ihev"), 4) == 0)
			{
				vehi_count++;
			}
			else if (memcmp([tempTag tagClassHigh], (isPPC ? "scen" : "necs"), 4) == 0)
			{
				scen_count++;
			}
			else if (memcmp([tempTag tagClassHigh], (isPPC ? "itmc" : "cmti"), 4) == 0)
			{
				itmc_count++;
			}
			[tagArray addObject:tempTag];
		}
		
		// Add the identity of the tag to the lookup dictionary
		[tagLookupDict setObject:[NSNumber numberWithInt:i] forKey:[NSNumber numberWithLong:[tempTag idOfTag]]];
		
		// Here is where we'd add text to a view, mmk?
		
		// Now we release our temporary tag
		[tempTag release];
	}
	
	// Its texture manager time!
	[_texManager setCapacity:bitm_count];
	
	// Now lets quickly make our scenario item list
	itmcList = [[NSMutableArray alloc] initWithCapacity:itmc_count];
	itmcLookupDict = [[NSMutableDictionary alloc] initWithCapacity:itmc_count];
	scenList = [[NSMutableArray alloc] initWithCapacity:scen_count];
	scenLookupDict = [[NSMutableDictionary alloc] initWithCapacity:scen_count];
	scenNameLookupDict = [[NSMutableDictionary alloc] initWithCapacity:scen_count];
	modTagList = [[NSMutableArray alloc] initWithCapacity:mod2_count];
	modTagLookupDict = [[NSMutableDictionary alloc] initWithCapacity:mod2_count];
	bitmTagList = [[NSMutableArray alloc] initWithCapacity:bitm_count];
	bitmTagLookupDict = [[NSMutableDictionary alloc] initWithCapacity:bitm_count];
	
	/*
		Second pass here to create some arrays
	*/
	[self seekToAddress:(mapHeader.offsetToIndex + 0x28)];
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tempTag = [[MapTag alloc] initWithDataFromFile:self];
		
		if (memcmp([tempTag tagClassHigh],(isPPC ? "itmc" : "cmti"),4) == 0)
		{
			[itmcLookupDict setObject:[NSNumber numberWithLong:[tempTag idOfTag]] forKey:[NSNumber numberWithInt:itmc_counter]];
			[itmcList addObject:[tempTag tagName]];
			itmc_counter++;
		}
		else if (memcmp([tempTag tagClassHigh], (isPPC ? "scen" : "necs"), 4) == 0)
		{
			[scenLookupDict setObject:[NSNumber numberWithLong:[tempTag idOfTag]] forKey:[NSNumber numberWithInt:scen_counter]];
			[scenNameLookupDict setObject:[NSNumber numberWithLong:[tempTag idOfTag]] forKey:[tempTag tagName]];
			[scenList addObject:[tempTag tagName]];
			scen_counter++;
		}
		else if (memcmp([tempTag tagClassHigh], (isPPC ? "mod2" : "2dom"), 4) == 0)
		{
			[modTagLookupDict setObject:[NSNumber numberWithLong:[tempTag idOfTag]] forKey:[NSNumber numberWithInt:mod2_counter]];
			[modTagList addObject:[tempTag tagName]];
			mod2_counter++;
		}
		else if (memcmp([tempTag tagClassHigh], (isPPC ? "bitm" : "mtib"), 4) == 0)
		{
			[bitmTagLookupDict setObject:[NSNumber numberWithLong:[tempTag idOfTag]] forKey:[NSNumber numberWithInt:bitm_counter]];
			[bitmTagList addObject:[tempTag tagName]];
			
			[_texManager addTexture:[tagArray objectAtIndex:i]];
			
			bitm_counter++;
		}
		
		[tempTag release];
	}
	// Next we load the scenario
	
	
	[self seekToAddress:scenario_offset];
	mapScenario = [[Scenario alloc] initWithMapFile:self];
	[mapScenario setTagLength:[[tagArray objectAtIndex:0] tagLength]];
	#ifdef __DEBUG__
	if ([mapScenario loadScenario])
		NSLog(@"Scenario Loaded!");
	#else
	[mapScenario loadScenario];
	#endif
	//[mapScenario pairModelsWithSpawn];
	[tagArray replaceObjectAtIndex:0 withObject:mapScenario];
	
	// Then we load the BSP
	bspHandler = [[BSP alloc] initWithMapFile:self texManager:_texManager];
	[bspHandler loadVisibleBspInfo:[mapScenario header].StructBsp version:mapHeader.version];
	[bspHandler setActiveBsp:0];
	
	#ifdef __DEBUG__
	NSLog(@"BSPs are loaded!");
	printf("\n");
	
	NSLog(@"Scenery spawn count: %d", [mapScenario scenery_spawn_count]);
	NSLog(@"Vehicle spawn count: %d", [mapScenario vehicle_spawn_count]);
	NSLog(@"Item spawn count: %d", [mapScenario item_spawn_count]);
	NSLog(@"Player spawn count: %d", [mapScenario player_spawn_count]);
	#endif
	
	// Now lets load all of the bitmaps for shit
	[self loadAllBitmaps];

	return 0;
}
- (void)closeMap
{
	fclose(mapFile);
	fclose(bitmapsFile);
}
- (FILE *)currentFile
{
	return mapFile;
}
- (BOOL)isPPC
{
	return isPPC;
}
- (void)seekToAddress:(unsigned long)address
{
	fseek(mapFile, address, SEEK_SET);
}
- (void)skipBytes:(long)bytesToSkip
{
	fseek(mapFile, (ftell(mapFile) + bytesToSkip), SEEK_SET);
}
- (void)swapBufferEndian32:(void *)buffer size:(int)size
{
	if (size == 1)
	{
		return;
	}
	else if (size == 2)
	{
		short *tmpShort = (short *)buffer;
	
		*tmpShort = EndianSwap16(*tmpShort);
	}
	else if (size >= 4)
	{
		
	}
}
/* This is directly accessing the buffer, dammit */
- (BOOL)write:(void *)buffer size:(int)size
{
	int i;
	if (isPPC)
	{
		/*
			lol, this takes some work, doesn't it?
			
			What I'm doing is going through the buffer and swapping the bytes
			This way we can build once and run on all macs
		*/

		if (size == 1)
		{
			if (fwrite(buffer, size, 1, mapFile) == 1)
				return YES;
		}
		else if (size == 2)
		{
			short tmpShort;
			tmpShort = EndianSwap16(tmpShort);
			if (fwrite(&tmpShort, size, 1, mapFile) == 1);
				return YES;
		}
		else if (size >= 4)
		{
			long *pointLong = buffer;
			long tmpLong;
			for (i = 0; i < (size / 4); i++)
			{	
				tmpLong = EndianSwap32(pointLong[i]);
				fwrite(&tmpLong, 4, 1, mapFile);
			}
			if ((size % 4) > 0)
			{
				char *bytes = buffer;
				int x;
				
				for (x = size; x >  (size % 4); x--)
				{
					fwrite(&bytes[x],1,1,mapFile);
				}
			}
			FILE *tmpFile = fopen("test.scnr","w+");
	
			fwrite(buffer,size,1,tmpFile);
		
			fclose(tmpFile);

			return YES;
		}
	}
	else
	{
		// Howwwwww embarrassing, I had it as fread rather than fwrite
		if (fwrite(buffer, size, 1, mapFile) == 1)
			return YES;
		else
			return NO;
	}
	return NO;
}
- (BOOL)writeByte:(void *)byte
{
	if (fwrite(byte,1,1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeShort:(void *)byte
{
	if (fwrite(byte,2,1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeFloat:(float *)toWrite
{	
	if (fwrite(toWrite, sizeof(float),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeInt:(int *)myInt
{
	if (fwrite(myInt, sizeof(int),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeLong:(long *)myLong
{
	if (fwrite(myLong, sizeof(long),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeAnyData:(void *)data size:(unsigned int)size
{
	if (fwrite(data, size,1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeAnyArrayData:(void *)data size:(unsigned int)size array_size:(unsigned int)array_size
{
	if (fwrite(data, size,array_size,mapFile) == array_size)
		return YES;
	else
		return NO;
}
- (BOOL)writeByteAtAddress:(void *)byte address:(unsigned long)address
{
	fseek(mapFile, address, SEEK_SET);
	if (fwrite(byte,1,1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeFloatAtAddress:(float *)toWrite address:(unsigned long)address
{	
	fseek(mapFile, address, SEEK_SET);
	if (fwrite(toWrite, sizeof(float),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeIntAtAddress:(int *)myInt address:(unsigned long)address
{
	fseek(mapFile, address, SEEK_SET);
	if (fwrite(myInt, sizeof(int),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeLongAtAddress:(long *)myLong address:(unsigned long)address
{
	fseek(mapFile, address, SEEK_SET);
	if (fwrite(myLong, sizeof(long),1,mapFile) == 1)
		return YES;
	else
		return NO;
}
- (BOOL)writeAnyDataAtAddress:(void *)data size:(unsigned int)size address:(unsigned long)address
{
	fseek(mapFile, address, SEEK_SET);

	return [self write:data size:size];
}
- (BOOL)writeAnyArrayDataAtAddress:(void *)data size:(unsigned int)size array_size:(unsigned int)array_size address:(unsigned long)address
{
	fseek(mapFile,address, SEEK_SET);
	if (fwrite(data, size,array_size,mapFile) == array_size)
		return YES;
	else
		return NO;
}
- (BOOL)read:(void *)buffer size:(unsigned int)size
{
	int i;
	if (isPPC)
	{
		/*
			lol, this takes some work, doesn't it?
			
			What I'm doing is going through the buffer and swapping the bytes
			This way we can build once and run on all macs
		*/
		if (size == 1)
		{
			if (fread(buffer, size, 1, mapFile) == 1)
				return YES;
		}
		else if (size == 2)
		{
			short tmpShort;
			fread(&tmpShort, size, 1, mapFile);
			tmpShort = EndianSwap16(tmpShort);
			memcpy(buffer, &tmpShort, 2);
			return YES;
		}
		else if (size >= 4)
		{
			long *pointLong = buffer;
			for (i = 0; i < (size / 4); i++)
			{
				fread(&pointLong[i], 4, 1, mapFile);
				pointLong[i] = EndianSwap32(pointLong[i]);
			}
			if ((size % 4) > 0)
			{
				long tempLong;
				pointLong = &tempLong;
				char *bytes;
				int x, byteToTranscribe;
				
				fread(pointLong, 4, 1, mapFile);
				
				bytes = (char *)&pointLong;
				
				for (x = size; x >  (size % 4); x--)
				{
					bytes[x] = bytes[byteToTranscribe];
					byteToTranscribe++;
				}
			}
			return YES;
		}
	}
	else
	{
		if (fread(buffer, size, 1, mapFile) == 1)
			return YES;
		else
			return NO;
	}
	return NO;
}
- (BOOL)readByte:(void *)buffer
{
	return [self read:buffer size:1];
}
- (BOOL)readShort:(void *)buffer
{
	return [self read:buffer size:sizeof(short)];
}
- (char)readSimpleByte
{
	char buffer;
	fread(&buffer,1,1,mapFile);
	return buffer;
}
- (BOOL)readLong:(void *)buffer
{
	return [self read:buffer size:4];
}
- (BOOL)readFloat:(void *)floatBuffer
{
	return [self read:floatBuffer size:4];
}
- (BOOL)readInt:(void *)intBuffer
{
	return [self read:intBuffer size:4];
}
- (BOOL)readBlockOfData:(void *)buffer size_of_buffer:(unsigned int)size
{
	// Need to remove this at some point
	return [self read:buffer size:size];
}
- (BOOL)readByteAtAddress:(void *)buffer address:(unsigned long)address
{
	fseek(mapFile,address,SEEK_SET);
	return [self read:buffer size:1];
}
- (BOOL)readIntAtAddress:(void *)buffer address:(unsigned long)address
{
	fseek(mapFile,address,SEEK_SET);
	return [self read:buffer size:4];
}
- (BOOL)readFloatAtAddress:(void *)buffer address:(unsigned long)address
{
	fseek(mapFile,address,SEEK_SET);
	return [self read:buffer size:4];
}
- (BOOL)readLongAtAddress:(void *)buffer address:(unsigned long)address
{
	fseek(mapFile,address,SEEK_SET);
	return [self read:buffer size:4];
}
- (BOOL)readBlockOfDataAtAddress:(void *)buffer size_of_buffer:(unsigned int)size address:(unsigned long)address
{
	fseek(mapFile,address,SEEK_SET);
	return [self read:buffer size:size];
}
- (char *)readCString
{
	char *buffer, *tempBuffer, tempChar;
	int i  = 0;
	
	buffer = malloc(sizeof(char)*1024);
	
	tempBuffer = buffer;
	do
	{
		[self readByte:&tempChar];
		*buffer=tempChar;
		buffer++;
		i++;
	} while (tempChar != 0x00 && i <= 1024);
	return tempBuffer;
}
- (reflexive)readReflexive
{
	reflexive reflex;
	reflex.location_in_mapfile = [self currentOffset];
	[self readLong:&reflex.chunkcount];
	[self readLong:&reflex.offset];
	[self readLong:&reflex.zero];
	reflex.offset -= _magic;
	return reflex;
}
- (reflexive)readBspReflexive:(long)magic
{
	reflexive reflex;
	reflex.location_in_mapfile = [self currentOffset];
	[self readLong:&reflex.chunkcount];
	[self readLong:&reflex.offset];
	[self readLong:&reflex.zero];
	reflex.offset -= magic;
	return reflex;
}
- (TAG_REFERENCE)readReference
{
	TAG_REFERENCE ref;
	[self readLong:&ref.tag];
	[self readLong:&ref.NamePtr];
	ref.NamePtr -= _magic;
	[self readLong:&ref.unknown];
	[self readLong:&ref.TagId];
	return ref;
}
- (id)bitmTagForShaderId:(long)shaderId
{
	long currentOffset = [self currentOffset];
	
	// ok, so lets lookup the shader tag
	MapTag *tempShaderTag = [[self tagForId:shaderId] retain]; // Now we have the shader! Yay!
	
	[self seekToAddress:[tempShaderTag offsetInMap]];
	
	[tempShaderTag release];
	
	long bitm = 'bitm', tempInt;
	int x;
	x = 0;
	do 
	{
		[self readLong:&tempInt];
		x++;
	} while (tempInt != bitm && x < 1000);
	if (x != 1000)
	{
		[self skipBytes:8];
		long identOfBitm;
		[self readLong:&identOfBitm];
		[self seekToAddress:currentOffset];
		return (identOfBitm != 0xFFFFFFFF) ? [self tagForId:identOfBitm] : nil;
	}
	[self seekToAddress:currentOffset];
	return nil;
}
- (long)currentOffset
{
	return ftell(mapFile);
	//return [[NSNumber numberWithDouble:ftell(mapFile)] longValue];
}
// I have duplicates here since I'm going to be switcing over from get_magic to _magic
- (long)getMagic
{
	return _magic;
}
- (long)magic
{
	return _magic;
}
- (IndexHeader)indexHead
{
	return indexHead;
}
- (NSString *)mapName
{
	return [NSString stringWithCString:mapHeader.name];
}
- (NSString *)mapLocation
{
	return mapName;
}
- (id)tagForId:(long)identity
{
	return [tagArray objectAtIndex:[[tagLookupDict objectForKey:[NSNumber numberWithLong:identity]] intValue]];
}
- (Scenario *)scenario
{
	return mapScenario;
}
- (BSP *)bsp
{
	return bspHandler;
}
- (TextureManager *)_texManager
{
	return _texManager;
}
- (void)loadAllBitmaps
{
	int x;
	long tempIdent;
	
	vehicle_reference *vehi_ref = [mapScenario vehi_references];
	scenery_reference *scen_ref = [mapScenario scen_references];
	mp_equipment *mp_equip = [mapScenario item_spawns];
	//multiplayer_flags *mp_flags = [mapScenario netgame_flags];
	
	for (x = 0; x < [mapScenario vehi_ref_count]; x++)
	{
		if ([self isTag:vehi_ref[x].vehi_ref.TagId])
			[(ModelTag *)[self tagForId:[mapScenario baseModelIdent:vehi_ref[x].vehi_ref.TagId]] loadAllBitmaps];
	}
	for (x = 0; x < [mapScenario scen_ref_count]; x++)
	{
		if ([self isTag:scen_ref[x].scen_ref.TagId])
		{
			//NSLog(@"Tag id and index: [%d], index:[0x%x], next tag index:[0x%x]", x, scen_ref[x].scen_ref.TagId, scen_ref[x+1].scen_ref.TagId);
			if ([self tagForId:[mapScenario baseModelIdent:scen_ref[x].scen_ref.TagId]] != mapScenario)
				[(ModelTag *)[self tagForId:[mapScenario baseModelIdent:scen_ref[x].scen_ref.TagId]] loadAllBitmaps];
		}
	}
	//[(ModelTag *)[self tagForId:[mapScenario sky][0].modelIdent] loadAllBitmaps];
	for (x = 0; x < [mapScenario item_spawn_count]; x++)
	{
		[self seekToAddress:([[self tagForId:mp_equip[x].itmc.TagId] offsetInMap] + 0x8C)];
		[self readLong:&tempIdent];
		if ([self isTag:tempIdent])
			[(ModelTag *)[self tagForId:[mapScenario baseModelIdent:tempIdent]] loadAllBitmaps];
	}
	for (x = 0; x < [mapScenario mach_ref_count]; x++)
	{
		if ([self tagForId:[mapScenario mach_references][x].modelIdent] != mapScenario)
			[(ModelTag *)[self tagForId:[mapScenario mach_references][x].modelIdent] loadAllBitmaps];
	}
	// Then we put netgame flags in a bit
}
- (BOOL)isTag:(long)tagId
{
	if (tagId == 0xFFFFFFFF)
		return NO;
	if ([self tagForId:tagId] == mapScenario)
		return NO;
	if ((tagId < (indexHead.tagcount + indexHead.starting_id)) || (unsigned int)tagId < (unsigned int)indexHead.starting_id)
		return NO;
	//NSLog(@"Int val: 0x%x", [[tagLookupDict objectForKey:[NSNumber numberWithLong:tagId]] intValue]);
	
	return TRUE;
}
- (NSMutableArray *)itmcList
{
	return itmcList;
}
- (NSMutableDictionary *)itmcLookup
{
	return itmcLookupDict;
}
- (NSMutableArray *)scenList
{
	return scenList;
}
- (NSMutableDictionary *)scenLookup
{
	return scenLookupDict;
}
- (NSMutableDictionary *)scenLookupByName
{
	return scenNameLookupDict;
}
- (NSMutableArray *)modTagList
{
	return modTagList;
}
- (NSMutableDictionary *)modTagLookup
{
	return modTagLookupDict;
}
- (NSMutableArray *)bitmTagList
{
	return bitmTagList;
}
- (NSMutableDictionary *)bitmLookup
{
	return bitmTagLookupDict;
}
- (NSMutableArray *)constructArrayForTagType:(char *)tagType
{
	int i,
		tagCount = 0;
	MapTag *tmptag;
	
	NSMutableArray *tmpArray;
	
	[self seekToAddress:(mapHeader.offsetToIndex + 0x40)];
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tmptag = [[MapTag alloc] initWithDataFromFile:self];
		if (memcmp([tmptag tagClassHigh], tagType, 4) == 0)
			tagCount++;
		[tmptag release];
	}
	
	tmpArray = [[NSMutableArray alloc] initWithCapacity:tagCount];
	tagCount = 0;
	
	[self seekToAddress:(mapHeader.offsetToIndex + 0x40)];
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tmptag = [[MapTag alloc] initWithDataFromFile:self];
		if (memcmp([tmptag tagClassHigh], tagType, 4) == 0)
		{
			[tmpArray addObject:[tmptag tagName]];
		}
		[tmptag release];
	}
	
	return tmpArray;
}
- (void)constructArrayAndLookupForTagType:(char *)tagType array:(NSMutableArray *)array dictionary:(NSMutableDictionary *)dictionary
{
	int i, 
		tagCount = 0;
	MapTag *tmptag;
	
	NSMutableDictionary *tmpDict;
	NSMutableArray *tmpArray;
	
	[self seekToAddress:(mapHeader.offsetToIndex + 0x40)];
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tmptag = [[MapTag alloc] initWithDataFromFile:self];
		if (memcmp([tmptag tagClassHigh],tagType,4) == 0)
			tagCount++;
		[tmptag release];
	}

	tmpArray = [[NSMutableArray alloc] initWithCapacity:tagCount];
	tmpDict = [[NSMutableDictionary alloc] initWithCapacity:tagCount];
	tagCount = 0;
	
	[self seekToAddress:(mapHeader.offsetToIndex + 0x40)];
	for (i = 0; i < indexHead.tagcount; i++)
	{
		tmptag = [[MapTag alloc] initWithDataFromFile:self];
		if (memcmp([tmptag tagClassHigh], tagType, 4) == 0)
		{
			[tmpDict setObject:[NSNumber numberWithLong:[tmptag idOfTag]] forKey:[NSNumber numberWithInt:tagCount]];
			[tmpArray addObject:[tmptag tagName]];
		}
		[tmptag release];
	}
	
	dictionary = [tmpDict retain];
	array = [tmpArray retain];
	
	[tmpDict release];
	[tmpArray release];
}
- (long)itmcIdForKey:(int)key
{
	return [[itmcLookupDict objectForKey:[NSNumber numberWithInt:key]] longValue];
}
- (long)modIdForKey:(int)key
{
	return [[modTagLookupDict objectForKey:[NSNumber numberWithInt:key]] longValue];
}
- (long)bitmIdForKey:(int)key
{
	return [[bitmTagLookupDict objectForKey:[NSNumber numberWithInt:key]] longValue];
}
- (void)saveMap
{
	NSLog(@"hur?");
	[mapScenario rebuildScenario];
	NSLog(@"Or hur!?");
	[mapScenario saveScenario];
	NSLog(@"Asdf.");
}
@end