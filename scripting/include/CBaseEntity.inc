//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// This does not re-create the CBaseEntity class - it's just a methodmap representing parts of its structure.
// Requires "CHandle.inc"

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CBASEENTITY
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CBASEENTITY

#include "CHandle.inc"

// For projects where you'd like to provide custom entity data, you can also make an enum struct
// and make a bunch of properties that index the enum struct members using the entity's entindex().

//////////////////////////////////////////////////////////////////////////////
// CBASEENTITY METHODMAP                                                    //
//////////////////////////////////////////////////////////////////////////////

methodmap CBaseEntity < Pointer
{
    // Constructor - wrap around an existing address to make way for a CBaseEntity object.
    public CBaseEntity(Address address)
    {
        return view_as<CBaseEntity>(address);
    }

    // Constructor - get a CBaseEntity from entity index. Returns NULL if the entity is not valid.
    public static CBaseEntity FromIndex(any index)
    {
        if (!IsValidEntity(index))
            return NULL;
        return view_as<CBaseEntity>(GetEntityAddress(index));
    }

    // This entity's EHANDLE.
    property CHandle m_RefEHandle
    {
        public get() { return view_as<CHandle>(this.Address + SMTC_CBaseEntity_m_RefEHandle); }
        public set(CHandle value) { memcpy(this.Address + SMTC_CBaseEntity_m_RefEHandle, value, SIZEOF_CHandle); } 
    }
     
    // Get the entity index.
    // TODO: maybe rely on m_Network in the future?
    public int entindex()
    {
        return this.m_RefEHandle.GetAsEntIndex();
    }

    // Does this entity have a netprop?
    public bool HasEntProp(PropType type, const char[] prop)
    {
        return HasEntProp(this.entindex(), type, prop);
    }

    // Get an integral netprop.
    public any GetEntProp(PropType type, const char[] prop, int size = 4, int element = 0)
    {
        return GetEntProp(this.entindex(), type, prop, size, element);
    }

    // Get the array size of a netprop.
    public int GetEntPropArraySize(PropType type, const char[] prop)
    {
        return GetEntPropArraySize(this.entindex(), type, prop);
    }

    // Get the entindex of a handle netprop.
    public int GetEntPropEntIndex(PropType type, const char[] prop, int element = 0)
    {
        return GetEntPropEnt(this.entindex(), type, prop, element);
    }

    // Get a handle netprop.
    public EHANDLE GetEntPropHandle(PropType type, const char[] prop, int element = 0)
    {
        return CBaseEntity.FromIndex(GetEntPropEnt(this.entindex(), type, prop, element)).m_RefEHandle;
    }

    // Get a float netprop.
    public float GetEntPropFloat(PropType type, const char[] prop, int element = 0)
    {
        return GetEntPropFloat(this.entindex(), type, prop, element);
    }

    // Get a string netprop. Returns the number of non-NUL bytes written.
    public int GetEntPropString(PropType type, const char[] prop, char[] buffer, int maxlen, int element = 0)
    {
        return GetEntPropString(this.entindex(), type, prop, buffer, maxlen, element);
    }

    // Set an integral netprop.
    public void SetEntProp(PropType type, const char[] prop, any value, int size = 4, int element = 0)
    {
        SetEntProp(this.entindex(), type, prop, value, size, element);
    }

    // Set an entindex for a handle netprop.
    public void SetEntPropEntIndex(PropType type, const char[] prop, int other, int element = 0)
    {
        SetEntPropEnt(this.entindex(), type, prop, other, element);
    }
    
    // Set a handle netprop.
    public void SetEntPropHandle(PropType type, const char[] prop, EHANDLE other, int element = 0)
    {
        SetEntPropEnt(this.entindex(), type, prop, other.GetAsEntIndex(), element);
    }

    // Set a float netprop.
    public void SetEntPropFloat(PropType type, const char[] prop, float value, int element = 0)
    {
        SetEntPropFloat(this.entindex(), type, prop, value, element);
    }

    // Set a string netprop. Returns the number of non-NUL bytes written.
    public int SetEntPropString(PropType type, const char[] prop, const char[] buffer, int element = 0)
    {
        SetEntPropString(this.entindex(), type, prop, buffer, element);
    }

    // Get a pointer netprop. Returns NULL if there is no prop present.
    public Pointer GetEntPropPointer(PropType type, const char[] prop)
    {
        if (!this.HasEntProp(type, prop))
            return NULL;

        int index = this.entindex();
        if (type == Prop_Data)
            return this.Address + FindDataMapInfo(index, prop);
        else // Prop_Send
        {
            char buffer[64];
            GetEntityNetClass(index, buffer, sizeof(buffer));
            return this.Address + FindSendPropInfo(buffer, prop);
        }
    }

    // Scale damage done and call OnTakeDamage.
    public int TakeDamage(const Pointer& inputInfo)
    {
        SDKCall(SMTC_SDKCall_CBaseEntity_TakeDamage, this, inputInfo);
    }
}

//////////////////////////////////////////////////////////////////////////////
// MISCELLANEOUS                                                            //
//////////////////////////////////////////////////////////////////////////////

// As determined by CWorld::RequiredEdictIndex(), the world entity always has entity index 0.
stock CBaseEntity GetWorldEntity()
{
    return CBaseEntity.FromIndex(0);
}

stock CBaseEntity operator=(CHandle value)
{
    return value.Get();
}
stock CBaseEntity operator=(int value)
{
    return CBaseEntity.FromIndex(value);
}
