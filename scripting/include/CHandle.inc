//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// basehandle.h
// ehandle.h

// Requires "CBaseEntity.inc".
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CHANDLE
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CHANDLE

#pragma semicolon true 
#pragma newdecls required

// must be defined before CBaseEntity!!!!
#define EHANDLE CHandle

// How many bits to use to encode an edict.
#define	MAX_EDICT_BITS				11			// # of bits needed to represent max edicts
// Max # of edicts in a level
#define	MAX_EDICTS					(1<<MAX_EDICT_BITS)

// Used for networking ehandles.
#define NUM_ENT_ENTRY_BITS		(MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES			(1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK			(NUM_ENT_ENTRIES - 1)
#define INVALID_EHANDLE_INDEX	0xFFFFFFFF

#define NUM_SERIAL_NUM_BITS		(32 - NUM_ENT_ENTRY_BITS)

#include "CBaseEntity.inc"

//////////////////////////////////////////////////////////////////////////////
// CHANDLE DATA                                                             //
//////////////////////////////////////////////////////////////////////////////

enum
{
    CHANDLE_OFFSET_M_INDEX = 0,                           // unsigned long m_Index

    SIZEOF_CHandle = CHANDLE_OFFSET_M_INDEX + SIZEOF_int // sizeof(CHandle);
};

//////////////////////////////////////////////////////////////////////////////
// CHANDLE METHODMAP                                                        //
//////////////////////////////////////////////////////////////////////////////

// A class that represents a 32-bit ID (entindex + serial number) unique to every entity in the game.
// It is used to refer to entities where pointers and entity indexes are unsafe.
methodmap CHandle < Pointer
{
    // Constructor - wrap around an existing address to make way for a CHandle object.
    public CHandle(Address address)
    {
        return view_as<CHandle>(address);
    }
    
    // The low NUM_SERIAL_BITS hold the index. If this value is less than MAX_EDICTS, then the entity is networkable.
	// The high NUM_SERIAL_NUM_BITS bits are the serial number.
    property int m_Index
    {
        public get() { return this.Dereference(CHANDLE_OFFSET_M_INDEX); }
        public set(int value) { this.Write(value, CHANDLE_OFFSET_M_INDEX); }
    }

    // Call constructor on existing type.
    public void ctor()
    {
        this.m_Index = INVALID_EHANDLE_INDEX;
    }

    // Constructor - allocate a new CHandle onto the heap. Deallocation will be required when you are finished using free().
    public static CHandle Malloc()
    {
        CHandle pointer = malloc(SIZEOF_CHandle);
        pointer.ctor();
        return pointer;
    }

    // Constructor - allocate a new CHandle onto the stack. When using the return value, you must use STACK_GETRETURN().
    public static STACK StackAlloc()
    {
        char buffer[SIZEOF_CHandle];
        view_as<CHandle>(AddressOfString(buffer)).ctor();
        return buffer;
    }

    // Assign a CHandle value to this CHandle.
    public void Assign(any value)
    {
        this.m_Index = value;
    }

    // Initialize with an entry and serial number. If the values specified are incorrect, the value of the handle will be INVALID_EHANDLE_INDEX.
    public void Init(int iEntry, int iSerialNumber)
    {
        if (iEntry < 0 || iEntry >= NUM_ENT_ENTRIES)
            this.m_Index = INVALID_EHANDLE_INDEX;
        if (iSerialNumber < 0 || iSerialNumber >= (1 << NUM_SERIAL_NUM_BITS))
            this.m_Index = INVALID_EHANDLE_INDEX;
        
        this.m_Index = iEntry | (iSerialNumber << NUM_ENT_ENTRY_BITS);
    }

    // Terminate this handle.
    public void Term()
    {
        this.m_Index = INVALID_EHANDLE_INDEX;
    }

    // Get index as int.
    public int ToInt()
    {
        return this.m_Index;
    }

    // Get the entry index.
    public int GetEntryIndex()
    {
        return this.m_Index & ENT_ENTRY_MASK;
    }

    // Get the serial number.
    public int GetSerialNumber()
    {
        return this.m_Index >> NUM_ENT_ENTRY_BITS;
    }

    // Set this handle to an entity's handle.
    public void Set(const CBaseEntity pEntity)
    {
        if (pEntity != NULL)
            memcpy(this, pEntity.m_RefEHandle, SIZEOF_CHandle);
        else
            this.m_Index = INVALID_EHANDLE_INDEX;
    }

    // Maybe use g_pEntityList->LookupEntity() in the future?
    public int GetAsEntIndex()
    {
        // internally EntRefToEntIndex() goes through m_EntPtrArray to retrieve CEntInfo for entity with this handle's entry index,
        // and checks if that serial number equates to this handle's serial number. if so, it will return the handle's entry index.
        //
        // i want to try and re-create this one day because.... well this is SMTC lol
        // bit 30 needs to be set to 1 as well because EntRefToEntIndex() validates this bit, to decide whether the entref is valid
        return EntRefToEntIndex(this.m_Index | (1 << 31)); 
    }

    // Use this to dereference the handle.
    public CBaseEntity Get()
    {
        return CBaseEntity.FromIndex(this.GetAsEntIndex());
    }
}