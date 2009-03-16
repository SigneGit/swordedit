/*
 *  defines.h
 *  swordedit
 *
 *  Created by sword on 5/11/08.
 *  Copyright 2008 sword Inc. All rights reserved.
 *
 */
 
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

typedef struct
{
	float x,y,z;
} CVector3;

/* BEGIN RENDER VIEW */

typedef enum
{
	redIndex,
	greenIndex,
	blueIndex,
	alphaIndex
} ClearColors;

typedef enum
{
	point,
	wireframe,
	flat_shading,
	textured,
	textured_tris
} RenderStyle;

typedef enum  
{
	rotate_camera,
	select,
	translate
} Mode;

typedef enum 
{
	s_all = 0,
	s_scenery = 1,
	s_vehicle = 2,
	s_playerspawn = 3,
	s_item = 4,
	s_netgame = 5,
	s_machine = 6
} SelectionType;

typedef enum
{
	up,
	down,
	left,
	right,
	forward,
	back
} Direction;

typedef struct
{
	int direction;
	BOOL isDown;
} Key_In_Use;

typedef struct
{
	float red;
	float blue;
	float green;
	long color_count;
} rgb;

/* END RENDER VIEW */

/* BEGIN MAP */
typedef struct
{
	long map_id;
	long version;
	long map_length;
	long zeros;
	long offsetToIndex;
	long metaSize;
	long zeros2[2];
	char name[32];
	char builddate[32];
	long maptype;
	long footer;
} Header;

typedef struct
{
	long indexMagic;
	long starting_id;
	long vertexsize;
	long tagcount;
	long vertex_object_count;
	long vertex_offset;
	long indices_object_count;
	long vertex_size;
	long modelsize;
	long tagstart;
} IndexHeader;

typedef struct
{
	long chunkcount;
	int offset;
	long zero;
	
	// Editing / saving related aspect
	long location_in_mapfile;
	int oldOffset;
	int newChunkCount;
	int chunkSize;
	
	// Scenario reconstruction aspect
	int refNumber;
} reflexive;

typedef struct
{
  char tag[4];
  long NamePtr;
  long unknown;
  long TagId;
} TAG_REFERENCE;

/* END MAP */
/* BEGIN SCENARIO */

// scenario header -> Taken from ScenarioDefs.h from Bob's sparkedit (Probably gren's code in the first place)
/*
*
*	Scenario header is ALWAYS 0x5B0 long and ends with the skybox tag ref.
*
*	Scenario reconstruction leaves everything up to Scenery untouched
*	After scenery, which we allow users to edit, the scenario may be reconstructed
*	thereby causing reflexives to change
*
*/
typedef struct
{
  char unk_str1[16];
  char unk_str2[16];
  char unk_str3[16];
  reflexive SkyBox; // 1
  int unk1;
  reflexive ChildScenarios; // 2

	unsigned long unneeded1[46];
  int EditorScenarioSize;
  int unk2;
  int unk3;
  unsigned long pointertoindex;
	unsigned long unneeded2[2];
  unsigned long pointertoendofindex;
	unsigned long zero1[57];

  reflexive ObjectNames; // 3
  reflexive Scenery; // 4
  reflexive SceneryRef; // 5
  reflexive Biped; // 6
  reflexive BipedRef; // 7
  reflexive Vehicle; // 8
  reflexive VehicleRef;  // 9
  reflexive Equip; // 10
  reflexive EquipRef; // 11
  reflexive Weap; // 12
  reflexive WeapRef; // 13
  reflexive DeviceGroups; // 14
  reflexive Machine; // 15
  reflexive MachineRef; // 16
  reflexive Control; // 17
  reflexive ControlRef; // 18
  reflexive LightFixture; // 19
  reflexive LightFixtureRef; // 20
  reflexive SoundScenery; // 21
  reflexive SoundSceneryRef; // 22
  reflexive Unknown1[7]; // 23-29
  reflexive PlayerStartingProfile; // 30
  reflexive PlayerSpawn; // 31
  reflexive TriggerVolumes; // 32
  reflexive Animations; // 33
  reflexive MultiplayerFlags; // 34
  reflexive MpEquip; // 35
  reflexive StartingEquip; // 36
  reflexive BspSwitchTrigger; // 37
  reflexive Decals; // 38
  reflexive DecalsRef; // 39
  reflexive DetailObjCollRef; // 40
  reflexive Unknown3[7]; // 41-47
  reflexive ActorVariantRef; // 48
  reflexive Encounters; // 49
  //below this, structs still not confirmed
  reflexive CommandLists; // 50
  reflexive Unknown2; // 51
  reflexive StartingLocations; // 52
  reflexive Platoons; // 53
  reflexive AiConversations; // 54
  unsigned long ScriptDataSize;
  unsigned long Unknown4;
  reflexive ScriptCrap; // 55
  reflexive Commands; // 56
  reflexive Points; // 57
  reflexive AiAnimationRefs; // 58
  reflexive GlobalsVerified; // 59
  reflexive AiRecordingRefs; // 60
  reflexive Unknown5; // 61
  reflexive Participants; // 62
  reflexive Lines; // 63
  reflexive ScriptTriggers; // 64
  reflexive VerifyCutscenes; // 65
  reflexive VerifyCutsceneTitle; // 66
  reflexive SourceFiles; // 67
  reflexive CutsceneFlags; // 68
  reflexive CutsceneCameraPoi; // 69
  reflexive CutsceneTitles; // 70
  reflexive Unknown6[8]; // 71-78
  unsigned long  Unknown7[2];
  reflexive StructBsp; // 79
}SCNR_HEADER;

typedef struct SkyBox
{
	TAG_REFERENCE skybox;
	long modelIdent;
} SkyBox;
// scenery
typedef struct scenery_spawn
{
	short numid;
	short flag;
	short not_placed;
	short desired_permutation;
	float coord[3];
	float rotation[3];
	float unknown[10];
	
	// Not part of the in-map data
	long modelIdent;
	bool isSelected;
	bool isMoving;
} scenery_spawn;
#define SCENERY_SPAWN_CHUNK 0x48

typedef struct scenery_reference
{
	TAG_REFERENCE scen_ref;
	unsigned long zero[8];
} scenery_reference;
#define SCENERY_REF_CHUNK 0x30 

// vehicles
typedef struct 
{
	short numid;
	short flag;
	short not_placed;
	short desired_permutation;
	float coord[3];
	float rotation[3];
	/*
	long unknown1[0xA];
	float body_vitality;
	short unknown2;
	short flags;
	long unknown3[2];
	char mpTeamIndex;
	char secondPosMPTeamIndex;
	short mpSpawnFlags;
	*/
	unsigned long unknown2[22];
	
	// Not part of the in-map data
	long modelIdent;
	bool isSelected;
	bool isMoving;
} vehicle_spawn;
// Need to check this out
#define VEHICLE_SPAWN_CHUNK 0x78

typedef struct vehicle_reference
{
	TAG_REFERENCE vehi_ref;
	unsigned long zero[8];
} vehicle_reference;
#define VEHICLE_REF_CHUNK 0x30

// MP Equipment
typedef struct mp_equipment
{
	unsigned long unknown[16];
	float coord[3];
	float yaw;
	TAG_REFERENCE itmc;
	unsigned long unknown2[12];
	
	// Not part of the in-map data
	long modelIdent;
	bool isSelected;
	bool isMoving;
} mp_equipment;
#define MP_EQUIP_CHUNK 0x90

// players
typedef struct player_spawn
{
	float coord[3];
	float rotation;
	short team_index;
	short bsp_index;
	short type1; // Enum16
	short type2; // Enum16
	short type3; // Enum16
	short type4; // Enum16
	float unknown[6];
	
	// Not part of in-map data
	bool isSelected;
	bool isMoving;
} player_spawn;
#define PLAYER_SPAWN_CHUNK 0x34

typedef struct multiplayer_flags
{
	float coord[3];
	float rotation;
	short type;
	short team_index;
	TAG_REFERENCE item_used; // Not always there
	long zeros[0x70]; // Never needs to be read, just needs to be here
	
	// Not part of in-map data
	BOOL isSelected;
	BOOL isMoving;
} multiplayer_flags;
#define MP_FLAGS_CHUNK 0x94

/* I don't really think this will work... */
typedef struct netgame_equipment
{
	long bitmask32;
	short type0;
	short type1;
	short type2;
	short type3;
	short teamIndex;
	short spawnTime;
	float coord[3];
	float rotation[1];
	TAG_REFERENCE item_used;
} netgame_equipment;
#define NETGAME_EQUIP_CHUNK 0x90

// 0xCC in length
typedef struct starting_weapons
{
	long unk1;
	long unk2;
	long unk3[13];
	TAG_REFERENCE weapon[6]; // 6 * 0x10
	long zeros2[12];
} starting_weapons;
#define STARTING_WEAPONS_CHUNK 0xCC

// 0x40 in length
typedef struct machine_spawn
{
	short numid;
	short someflag;
	short not_placed;
	short desired_permutation;
	float coord[3];
	float rotation[3];
	short flags;
	short flags2;
	long zeros[7];
	
	// non-spawn data
	BOOL isSelected;
} machine_spawn;

// 0x30 in length
typedef struct machine_ref
{
	TAG_REFERENCE machTag;
	long zeros[8];
	
	// non-map data
	long modelIdent;
} machine_ref;

/* END SCENARIO */
/* BEGIN MODELS */

typedef struct MODEL_REGION_PERMUTATION
{
  char Name[32];
  unsigned long Flags[8];
  short LOD_MeshIndex[5];
  short Reserved[7];
} MODEL_REGION_PERMUTATION;

typedef struct MODEL_REGION
{
  char Name[64];
  reflexive Permutations;
  MODEL_REGION_PERMUTATION *modPermutations;
} MODEL_REGION;

typedef struct
{
  float min[3];
  float max[3];
}BOUNDING_BOX;

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
	long shaderBitmapIndex;
	char junk[66];
	indicesPointer indexPointer;
	char junk2[4];
	verticesPointer vertPointer;
	char junk3[28];
	Vector *vertices;
	unsigned short *indices;
} part;

/* END MODELS */
/* BEGIN BSP */

typedef struct
{
  unsigned long BspStart;
  unsigned long BspSize;
  unsigned long Magic;
  unsigned long Zero1;
  char bsptag[4];
  unsigned long NamePtr;
  unsigned long unknown2;
  unsigned long TagId;
}SCENARIO_BSP_INFO;
typedef struct STRUCT_BSP_HEADER
{
  TAG_REFERENCE LightmapsTag;
  unsigned long unk4[0x25];
  reflexive Shaders;
  reflexive CollBspHeader;
  reflexive Nodes;
  unsigned long unk6[6];
  reflexive Leaves;
  reflexive LeafSurfaces;
  reflexive SubmeshTriIndices;
  reflexive SubmeshHeader;
  reflexive Chunk10;
  reflexive Chunk11;
  reflexive Chunk12;
  reflexive Clusters;
  int ClusterDataSize;
  unsigned long unk11;
  reflexive Chunk14;
  reflexive ClusterPortals;
  reflexive Chunk16a;
  reflexive BreakableSurfaces;
  reflexive FogPlanes;
  reflexive FogRegions;
  reflexive FogOrWeatherPallette;
  reflexive Chunk16f;
  reflexive Chunk16g;
  reflexive Weather;
  reflexive WeatherPolyhedra;
  reflexive Chunk19;
  reflexive Chunk20;
  reflexive PathfindingSurface;
  reflexive Chunk24;
  reflexive BackgroundSound;
  reflexive SoundEnvironment;
  int SoundPASDataSize;
  unsigned long unk12;
  reflexive Chunk25;
  reflexive Chunk26;
  reflexive Chunk27;
  reflexive Markers;
  reflexive DetailObjects;
  reflexive RuntimeDecals;
  unsigned long unk10[9];
}BSP_HEADER;

typedef struct
{
  TAG_REFERENCE ShaderTag;
  unsigned long UnkZero2;
  unsigned long VertIndexOffset;
  unsigned long VertIndexCount;
  float Centroid[3];
  float AmbientColor[3];
  unsigned long DistLightCount;
  float DistLight1[6];
  float DistLight2[6];
  float unkFloat2[3];
  float ReflectTint[4];
  float ShadowVector[3];
  float ShadowColor[3];
  float Plane[4];
  unsigned long UnkFlag2;
  unsigned long UnkCount1;
  unsigned long VertexCount1;
  unsigned long UnkZero4;
  unsigned long VertexOffset;
  unsigned long Vert_Reflexive;
  unsigned long UnkAlways3;
  unsigned long VertexCount2;
  unsigned long UnkZero9;
  unsigned long UnkLightmapOffset;
  unsigned long CompVert_Reflexive;
  unsigned long UnkZero5[2];
  unsigned long SomeOffset1;
  unsigned long PcVertexDataOffset;
  unsigned long UnkZero6;
  unsigned long CompVertBufferSize;
  unsigned long UnkZero7;
  unsigned long SomeOffset2;
  unsigned long VertexDataOffset;
  unsigned long UnkZero8;
}MATERIAL_SUBMESH_HEADER;
typedef struct
{
  unsigned long comp_normal;
  short comp_uv[2];
}COMPRESSED_LIGHTMAP_VERT;
typedef struct
{
  float normal[3];
  float uv[2];
}UNCOMPRESSED_LIGHTMAP_VERT;


typedef struct
{
  float vertex_k[3];
  float normal[3];
  float binormal[3];
  float tangent[3];
  float uv[2];
}UNCOMPRESSED_BSP_VERT;
typedef struct
{
  float vertex_k[3];
  unsigned long  comp_normal;
  unsigned long  comp_binormal;
  unsigned long  comp_tangent;
  float uv[2];
}COMPRESSED_BSP_VERT;
typedef struct
{
  unsigned short tri_ind[3];
}TRI_INDICES;
typedef struct
{
  MATERIAL_SUBMESH_HEADER		header;
  GLuint						*textures;
  char							shader_name[128];
  UNCOMPRESSED_BSP_VERT			*pVert;
  COMPRESSED_BSP_VERT			*pCompVert;
  unsigned long					VertCount;
  TRI_INDICES					*pIndex;
  unsigned long					IndexCount;
  char							*pTextureData;
  unsigned long					ShaderType;
  unsigned long					ShaderIndex;
  unsigned long					DefaultBitmapIndex;
  unsigned long					DefaultLightmapIndex;
  BOUNDING_BOX					Box;
  int							RenderTextureIndex;
  int							LightmapIndex;
  UNCOMPRESSED_LIGHTMAP_VERT	*pLightmapVert;
  COMPRESSED_LIGHTMAP_VERT		*pCompLightmapVert;
}SUBMESH_INFO;
typedef struct
{
  char name[128];
  unsigned long offset;
  unsigned long count;
}BSP_XREF;
typedef struct
{
  char Name[32];
  char tag[4];
  unsigned long NamePtr;
  unsigned long zero1;
  unsigned long TagId;
  unsigned long reserved[20];
  char tag2[4];
  unsigned long NamePtr2;
  unsigned long zero2;
  unsigned long signature2;
  unsigned long unk[24];
}BSP_WEATHER;
typedef struct
{
  short LightmapIndex;
  short unk1;
  unsigned long unknown[4];
  reflexive Material;
}BSP_LIGHTMAP;
typedef struct
{
  short SkyIndex;
  short FogIndex;
  short BackgroundSoundIndex;
  short SoundEnvIndex;
  short WeatherIndex;
  short TransitionBsp;
  unsigned long  unk1[10];
  reflexive SubCluster;
	unsigned long unk2[7];
  reflexive Portals;
}BSP_CLUSTER;
/* END BSP */