//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// weapon_parse.h

// For the time being, none of the methods will be re-created.
// CHudTexture will also not be re-created; it is only relevant to the client.

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_FILEWEAPONINFO_T
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_FILEWEAPONINFO_T

#define MAX_SHOOT_SOUNDS	16			// Maximum number of shoot sounds per shoot type

#define MAX_WEAPON_STRING	80
#define MAX_WEAPON_PREFIX	16
#define MAX_WEAPON_AMMO_NAME		32

#define WEAPON_PRINTNAME_MISSING "!!! Missing printname on weapon"

#include "SMTCHeader"

//////////////////////////////////////////////////////////////////////////////
// FILEWEAPONINFO_T DATA                                                    //
//////////////////////////////////////////////////////////////////////////////

enum 
{
	EMPTY,
	SINGLE,
	SINGLE_NPC,
	WPN_DOUBLE, // Can't be "DOUBLE" because windows.h uses it.
                // my comment: L
	DOUBLE_NPC,
	BURST,
	RELOAD,
	RELOAD_NPC,
	MELEE_MISS,
	MELEE_HIT,
	MELEE_HIT_WORLD,
	SPECIAL1,
	SPECIAL2,
	SPECIAL3,
	TAUNT,
	DEPLOY,

	// Add new shoot sound types here

	NUM_SHOOT_SOUND_TYPES,
};

enum
{
    FILEWEAPONINFO_T_OFFSET_VTABLE = 0,                                                                                   // void* vtable;

    FILEWEAPONINFO_T_OFFSET_BPARSEDSCRIPT = FILEWEAPONINFO_T_OFFSET_VTABLE + SIZEOF_Pointer,                              // bool bParsedScript;
    FILEWEAPONINFO_T_OFFSET_BLOADEDHUDELEMENTS = FILEWEAPONINFO_T_OFFSET_BPARSEDSCRIPT + SIZEOF_bool,                     // bool bLoadedHudElements;

    FILEWEAPONINFO_T_OFFSET_SZCLASSNAME = FILEWEAPONINFO_T_OFFSET_BLOADEDHUDELEMENTS + SIZEOF_bool,                       // char szClassName[MAX_WEAPON_STRING];
    FILEWEAPONINFO_T_OFFSET_SZPRINTNAME = FILEWEAPONINFO_T_OFFSET_SZCLASSNAME + MAX_WEAPON_STRING,                        // char szPrintName[MAX_WEAPON_STRING];

    FILEWEAPONINFO_T_OFFSET_SZVIEWMODEL = FILEWEAPONINFO_T_OFFSET_SZPRINTNAME + MAX_WEAPON_STRING,                        // char szViewModel[MAX_WEAPON_STRING];
    FILEWEAPONINFO_T_OFFSET_SZWORLDMODEL = FILEWEAPONINFO_T_OFFSET_SZVIEWMODEL + MAX_WEAPON_STRING,                       // char szWorldModel[MAX_WEAPON_STRING];
    FILEWEAPONINFO_T_OFFSET_SZANIMATIONPREFIX = FILEWEAPONINFO_T_OFFSET_SZWORLDMODEL + MAX_WEAPON_STRING,                 // char szAnimationPrefix[MAX_WEAPON_PREFIX];
    FILEWEAPONINFO_T_OFFSET_ISLOT = FILEWEAPONINFO_T_OFFSET_SZANIMATIONPREFIX + MAX_WEAPON_PREFIX + 2,                    // int iSlot; // The +2 is for the previous bools.
    FILEWEAPONINFO_T_OFFSET_IPOSITION = FILEWEAPONINFO_T_OFFSET_ISLOT + SIZEOF_int,                                       // int iPosition;
    FILEWEAPONINFO_T_OFFSET_IMAXCLIP1 = FILEWEAPONINFO_T_OFFSET_IPOSITION + SIZEOF_int,                                   // int iMaxClip1;
    FILEWEAPONINFO_T_OFFSET_IMAXCLIP2 = FILEWEAPONINFO_T_OFFSET_IMAXCLIP1 + SIZEOF_int,                                   // int iMaxClip2;
    FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP1 = FILEWEAPONINFO_T_OFFSET_IMAXCLIP2 + SIZEOF_int,                               // int iDefaultClip1;
    FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP2 = FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP1 + SIZEOF_int,                           // int iDefaultClip2;
    FILEWEAPONINFO_T_OFFSET_IWEIGHT = FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP2 + SIZEOF_int,                                 // int iWeight;
    FILEWEAPONINFO_T_OFFSET_IRUMBLEEFFECT = FILEWEAPONINFO_T_OFFSET_IWEIGHT + SIZEOF_int,                                 // int iRumbleEffect;
    FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHTO = FILEWEAPONINFO_T_OFFSET_IRUMBLEEFFECT + SIZEOF_int,                           // bool bAutoSwitchTo;
    FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHFROM = FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHTO + SIZEOF_bool,                        // bool bAutoSwitchFrom;
    FILEWEAPONINFO_T_OFFSET_IFLAGS = FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHFROM + 3,                                         // int iFlags;
    FILEWEAPONINFO_T_OFFSET_SZAMMO1 = FILEWEAPONINFO_T_OFFSET_IFLAGS + SIZEOF_int,                                        // char szAmmo1[MAX_WEAPON_AMMO_NAME];
    FILEWEAPONINFO_T_OFFSET_SZAMMO2 = FILEWEAPONINFO_T_OFFSET_SZAMMO1 + MAX_WEAPON_AMMO_NAME,                             // char szAmmo2[MAX_WEAPON_AMMO_NAME];

    FILEWEAPONINFO_T_OFFSET_ASHOOTSOUNDS = FILEWEAPONINFO_T_OFFSET_SZAMMO2 + MAX_WEAPON_AMMO_NAME,                        // char aShootSounds[NUM_SHOOT_SOUND_TYPES][MAX_WEAPON_STRING];
    
    FILEWEAPONINFO_T_OFFSET_IAMMOTYPE = FILEWEAPONINFO_T_OFFSET_ASHOOTSOUNDS + NUM_SHOOT_SOUND_TYPES * MAX_WEAPON_STRING, // int iAmmoType;
    FILEWEAPONINFO_T_OFFSET_IAMMO2TYPE = FILEWEAPONINFO_T_OFFSET_IAMMOTYPE + SIZEOF_int,                                  // int iAmmo2Type;
    FILEWEAPONINFO_T_OFFSET_M_BMELEEWEAPON = FILEWEAPONINFO_T_OFFSET_IAMMO2TYPE + SIZEOF_int,                             // bool m_bMeleeWeapon;
    
    FILEWEAPONINFO_T_OFFSET_M_BBUILTRIGHTHANDED = FILEWEAPONINFO_T_OFFSET_M_BMELEEWEAPON + SIZEOF_bool,                   // bool m_bBuiltRightHanded;
    FILEWEAPONINFO_T_OFFSET_M_BALLOWFLIPPING = FILEWEAPONINFO_T_OFFSET_M_BBUILTRIGHTHANDED + SIZEOF_bool,                 // bool m_bAllowFlipping;

    FILEWEAPONINFO_T_OFFSET_ISPRITECOUNT = FILEWEAPONINFO_T_OFFSET_M_BALLOWFLIPPING + 2,                                  // int iSpriteCount;
    FILEWEAPONINFO_T_OFFSET_ICONACTIVE = FILEWEAPONINFO_T_OFFSET_ISPRITECOUNT + SIZEOF_int,                               // CHudTexture* iconActive;
    FILEWEAPONINFO_T_OFFSET_ICONINACTIVE = FILEWEAPONINFO_T_OFFSET_ICONACTIVE + SIZEOF_Pointer,                           // CHudTexture* iconInactive;
    FILEWEAPONINFO_T_OFFSET_ICONAMMO = FILEWEAPONINFO_T_OFFSET_ICONINACTIVE + SIZEOF_Pointer,                             // CHudTexture* iconAmmo;
    FILEWEAPONINFO_T_OFFSET_ICONAMMO2 = FILEWEAPONINFO_T_OFFSET_ICONAMMO + SIZEOF_Pointer,                                // CHudTexture* iconAmmo2;
    FILEWEAPONINFO_T_OFFSET_ICONCROSSHAIR = FILEWEAPONINFO_T_OFFSET_ICONAMMO2 + SIZEOF_Pointer,                           // CHudTexture* iconCrosshair;
    FILEWEAPONINFO_T_OFFSET_ICONAUTOAIM = FILEWEAPONINFO_T_OFFSET_ICONCROSSHAIR + SIZEOF_Pointer,                         // CHudTexture* iconAutoaim;
    FILEWEAPONINFO_T_OFFSET_ICONZOOMEDCROSSHAIR = FILEWEAPONINFO_T_OFFSET_ICONAUTOAIM + SIZEOF_Pointer,                   // CHudTexture* iconZoomedCrosshair;
    FILEWEAPONINFO_T_OFFSET_ICONZOOMEDAUTOAIM = FILEWEAPONINFO_T_OFFSET_ICONZOOMEDCROSSHAIR + SIZEOF_Pointer,             // CHudTexture* iconZoomedAutoaim;
    FILEWEAPONINFO_T_OFFSET_ICONSMALL = FILEWEAPONINFO_T_OFFSET_ICONZOOMEDAUTOAIM + SIZEOF_Pointer,                       // CHudTexture* iconSmall;

    FILEWEAPONINFO_T_OFFSET_M_BSHOWUSAGEHINT = FILEWEAPONINFO_T_OFFSET_ICONSMALL + SIZEOF_Pointer,                        // bool bShowUsageHint;

    SIZEOF_FileWeaponInfo_t = FILEWEAPONINFO_T_OFFSET_M_BSHOWUSAGEHINT + 4,                                               // sizeof(FileWeaponInfo_t);
};

//////////////////////////////////////////////////////////////////////////////
// FILEWEAPONINFO_T METHODMAP                                               //
//////////////////////////////////////////////////////////////////////////////

// Contains the data read from the weapon's script file. 
// It's cached so we only read each weapon's script file once.
// Each game provides a CreateWeaponInfo function so it can have game-specific
// data (like CS move speeds) in the weapon script.
methodmap FileWeaponInfo_t < Pointer
{
    // Constructor - wrap around an existing address to make way for a FileWeaponInfo_t object.
    public FileWeaponInfo_t(Address address)
    {
        return view_as<FileWeaponInfo_t>(address);
    }

    property bool bParsedScript
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_BPARSEDSCRIPT, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_BPARSEDSCRIPT, NumberType_Int8); }
    }

    property bool bLoadedHudElements
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_BLOADEDHUDELEMENTS, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_BLOADEDHUDELEMENTS, NumberType_Int8); }
    }

    // The buffer size is 80 (MAX_WEAPON_STRING).
    property Pointer szClassName
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZCLASSNAME; }
    }

    // Name for showing in HUD, etc.
    // The buffer size is 80 (MAX_WEAPON_STRING).
    property Pointer szPrintName
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZPRINTNAME; }
    }

    // View model of this weapon
    // The buffer size is 80 (MAX_WEAPON_STRING).
    property Pointer szViewModel
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZVIEWMODEL; }
    }

    // Model of this weapon seen carried by the player
    // The buffer size is 80 (MAX_WEAPON_STRING).
    property Pointer szWorldModel
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZWORLDMODEL; }
    }

    // Prefix of the animations that should be used by the player carrying this weapon
    // The buffer size is 80 (MAX_WEAPON_STRING).
    property Pointer szAnimationPrefix
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZANIMATIONPREFIX; }
    }

    // inventory slot.
    property int iSlot
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ISLOT); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ISLOT); }
    }

    // position in the inventory slot.
    property int iPosition
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IPOSITION); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IPOSITION); }
    }

    // max primary clip size (-1 if no clip)
    property int iMaxClip1
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IMAXCLIP1); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IMAXCLIP1); }
    }

    // max secondary clip size (-1 if no clip)
    property int iMaxClip2
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IMAXCLIP2); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IMAXCLIP2); }
    }

    // amount of primary ammo in the gun when it's created
    property int iDefaultClip1
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP1); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP1); }
    }

    // amount of secondary ammo in the gun when it's created
    property int iDefaultClip2
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP2); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IDEFAULTCLIP2); }
    }

    // this value used to determine this weapon's importance in autoselection.
    property int iWeight
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IWEIGHT); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IWEIGHT); }
    }

    // Which rumble effect to use when fired? (xbox)
    property int iRumbleEffect
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IRUMBLEEFFECT); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IRUMBLEEFFECT); }
    }

    // whether this weapon should be considered for autoswitching to
    property bool bAutoSwitchTo
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHTO, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHTO, NumberType_Int8); }
    }

    // whether this weapon can be autoswitched away from when picking up another weapon or ammo
    property bool bAutoSwitchFrom
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHFROM, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_BAUTOSWITCHFROM, NumberType_Int8); }
    }

    // miscellaneous weapon flags
    property int iFlags
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IFLAGS); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IFLAGS); }
    }

    // "primary" ammo type
    // The buffer size is 32 (MAX_WEAPON_AMMO_NAME).
    property Pointer szAmmo1
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZAMMO1; }
    }

    // "secondary" ammo type
    // The buffer size is 32 (MAX_WEAPON_AMMO_NAME).
    property Pointer szAmmo2
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_SZAMMO2; }
    }

    // Sound blocks
    // Each buffer has a buffer size of 80 (MAX_WEAPON_STRING).
    // There are 16 (NUM_SHOOT_SOUND_TYPES) strings.
    property Pointer aShootSounds
    {
        public get() { return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_ASHOOTSOUNDS; }
    }

    // Sound blocks
    // Each string has a buffer size of 80 (MAX_WEAPON_STRING).
    // There are 16 (NUM_SHOOT_SOUND_TYPES) strings.
    public Pointer aShootSounds_Get(any index)
    {
        if (index < 0 || index >= NUM_SHOOT_SOUND_TYPES)
            return NULL;
        return view_as<any>(this) + FILEWEAPONINFO_T_OFFSET_ASHOOTSOUNDS + index * MAX_WEAPON_STRING;
    }

    property int iAmmoType
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IAMMOTYPE); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IAMMOTYPE); }
    }

    property int iAmmo2Type
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_IAMMO2TYPE); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_IAMMO2TYPE); }
    }

    // Melee weapons can always "fire" regardless of ammo.
    property bool m_bMeleeWeapon
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_M_BMELEEWEAPON, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_M_BMELEEWEAPON, NumberType_Int8); }
    }

    // This tells if the weapon was built right-handed (defaults to true).
	// This helps cl_righthand make the decision about whether to flip the model or not.
    property bool m_bBuiltRightHanded
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_M_BBUILTRIGHTHANDED, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_M_BBUILTRIGHTHANDED, NumberType_Int8); }
    }

    // False to disallow flipping the model, regardless of whether
    // it is built left or right handed.
    property bool m_bAllowFlipping
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_M_BALLOWFLIPPING, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_M_BALLOWFLIPPING, NumberType_Int8); }
    }

    // Sprite data, read from the data file
    property int iSpriteCount
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ISPRITECOUNT); }
        public set(int value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ISPRITECOUNT); }
    }

    property Pointer iconActive
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONACTIVE); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONACTIVE); }
    }
    
    property Pointer iconInactive
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONINACTIVE); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONINACTIVE); }
    }

    property Pointer iconAmmo
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONAMMO); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONAMMO); }
    }

    property Pointer iconAmmo2
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONAMMO2); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONAMMO2); }
    }

    property Pointer iconCrosshair
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONCROSSHAIR); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONCROSSHAIR); }
    }

    property Pointer iconAutoaim
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONAUTOAIM); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONAUTOAIM); }
    }

    property Pointer iconZoomedCrosshair
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONZOOMEDCROSSHAIR); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONZOOMEDCROSSHAIR); }
    }

    property Pointer iconZoomedAutoaim
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONZOOMEDAUTOAIM); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONZOOMEDAUTOAIM); }
    }

    property Pointer iconSmall
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_ICONSMALL); }
        public set(Pointer value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_ICONSMALL); }
    }

    // if true, then when you receive the weapon, show a hint about it
    property bool bShowUsageHint
    {
        public get() { return this.Dereference(FILEWEAPONINFO_T_OFFSET_M_BSHOWUSAGEHINT, NumberType_Int8); }
        public set(bool value) { this.Write(value, FILEWEAPONINFO_T_OFFSET_M_BSHOWUSAGEHINT, NumberType_Int8); }
    }

    // Each game can override this to get whatever values it wants from the script.
    public void Parse(Pointer pKeyValuesData, Pointer szWeaponName)
    {
        SDKCall(SMTC_SDKCall_FileWeaponInfo_t_Parse, this, pKeyValuesData, szWeaponName);
    }
    
    // Call constructor on existing type.
    public void ctor()
    {
        this.bParsedScript = false;
        this.bLoadedHudElements = false;
        this.szClassName.Write(0, .bits = NumberType_Int8);
        this.szPrintName.Write(0, .bits = NumberType_Int8);

        this.szViewModel.Write(0, .bits = NumberType_Int8);
        this.szWorldModel.Write(0, .bits = NumberType_Int8);
        this.szAnimationPrefix.Write(0, .bits = NumberType_Int8);
        this.iSlot = 0;
        this.iPosition = 0;
        this.iMaxClip1 = 0;
        this.iMaxClip2 = 0;
        this.iDefaultClip1 = 0;
        this.iDefaultClip2 = 0;
        this.iWeight = 0;
        this.iRumbleEffect = -1;
        this.bAutoSwitchTo = false;
        this.bAutoSwitchFrom = false;
        this.iFlags = 0;
        this.szAmmo1.Write(0, .bits = NumberType_Int8);
        this.szAmmo2.Write(0, .bits = NumberType_Int8);
        memset(this.aShootSounds, 0, NUM_SHOOT_SOUND_TYPES * MAX_WEAPON_STRING);
        this.iAmmoType = 0;
        this.iAmmo2Type = 0;
        this.m_bMeleeWeapon = false;
        this.iSpriteCount = 0;
        this.iconActive = NULL;
        this.iconInactive = NULL;
        this.iconAmmo = NULL;
        this.iconAmmo2 = NULL;
        this.iconCrosshair = NULL;
        this.iconAutoaim = NULL;
        this.iconZoomedCrosshair = NULL;
        this.iconZoomedAutoaim = NULL;
        this.bShowUsageHint = false;
        this.m_bAllowFlipping = true;
        this.m_bBuiltRightHanded = true;
    }

    // Constructor - allocate a new FileWeaponInfo_t onto the heap. Deallocation will be required when you are finished using this using free().
    public static FileWeaponInfo_t Malloc()
    {
        FileWeaponInfo_t pointer = malloc(SIZEOF_FileWeaponInfo_t);
        pointer.ctor();
        return pointer;
    }

    // Constructor - allocate a new FileWeaponInfo_t onto the stack. When using the return value, you must use STACK_GETRETURN().
    public static STACK StackAlloc()
    {
        char buffer[SIZEOF_FileWeaponInfo_t];
        view_as<FileWeaponInfo_t>(AddressOfString(buffer)).ctor();
        return buffer;
    }
}
