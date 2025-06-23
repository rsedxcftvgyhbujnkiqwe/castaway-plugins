//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// tf_weapon_parse.h

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTFWEAPONINFO
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTFWEAPONINFO

// Requires "FileWeaponInfo_t.inc", "WeaponData_t.inc" and "tf_item_constants.inc".
#include "FileWeaponInfo_t.inc"
#include "WeaponData_t.inc"
#include "tf_item_constants.inc"

// Use CBaseEntity.Dereference(SMTC_CTFWeaponBase_m_pWeaponInfo) to access this object on a
// CTFWeaponBase or derived entity.
// To get the weapon mode, use CBaseEntity.Dereference(SMTC_CTFWeaponBase_m_iWeaponMode).

//////////////////////////////////////////////////////////////////////////////
// CTFWEAPONINFO DATA                                                       //
//////////////////////////////////////////////////////////////////////////////

enum
{
    CTFWEAPONINFO_OFFSET_M_WEAPONDATA = SIZEOF_FileWeaponInfo_t,                                                           // WeaponData_t m_WeaponData[2];

    CTFWEAPONINFO_OFFSET_M_IWEAPONTYPE = CTFWEAPONINFO_OFFSET_M_WEAPONDATA + SIZEOF_WeaponData_t * 2,                      // int m_iWeaponType;

    CTFWEAPONINFO_OFFSET_M_BGRENADE = CTFWEAPONINFO_OFFSET_M_IWEAPONTYPE + SIZEOF_int,                                     // bool m_bGrenade;
    CTFWEAPONINFO_OFFSET_M_FLDAMAGERADIUS = CTFWEAPONINFO_OFFSET_M_BGRENADE + 4,                                           // float m_flDamageRadius;
    CTFWEAPONINFO_OFFSET_M_FLPRIMERTIME = CTFWEAPONINFO_OFFSET_M_FLDAMAGERADIUS + SIZEOF_float,                            // float m_flPrimerTime;
    CTFWEAPONINFO_OFFSET_M_BLOWERWEAPON = CTFWEAPONINFO_OFFSET_M_FLPRIMERTIME + SIZEOF_float,                              // bool m_bLowerWeapon;
    CTFWEAPONINFO_OFFSET_M_BSUPPRESSGRENTIMER = CTFWEAPONINFO_OFFSET_M_BLOWERWEAPON + SIZEOF_bool,                         // bool m_bSuppressGrenTimer;

    CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_VIEWMODEL = CTFWEAPONINFO_OFFSET_M_BSUPPRESSGRENTIMER + SIZEOF_bool,              // m_bHasTeamSkins_Viewmodel;
    CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_WORLDMODEL = CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_VIEWMODEL + SIZEOF_bool,        // m_bHasTeamSkins_Worldmodel;

    CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHMODEL = CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_WORLDMODEL + SIZEOF_bool,             // char m_szMuzzleFlashModel[128];
    CTFWEAPONINFO_OFFSET_M_FLMUZZLEFLASHMODELDURATION = CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHMODEL + 128,                   // float m_flMuzzleFlashModelDuration;
    CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHPARTICLEEFFECT = CTFWEAPONINFO_OFFSET_M_FLMUZZLEFLASHMODELDURATION + SIZEOF_float, // char m_szMuzzleFlashParticleEffect[128];

    CTFWEAPONINFO_OFFSET_M_SZTRACEREFFECT = CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHPARTICLEEFFECT + 128,                      // char m_szTracerEffect[128];

    CTFWEAPONINFO_OFFSET_M_BDOINSTANTEJECTBRASS = CTFWEAPONINFO_OFFSET_M_SZTRACEREFFECT + 128,                             // bool m_bDoInstantEjectBrass;
    CTFWEAPONINFO_OFFSET_M_SZBRASSMODEL = CTFWEAPONINFO_OFFSET_M_BDOINSTANTEJECTBRASS + SIZEOF_bool,                       // char m_szBrassModel[128];

    CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONSOUND = CTFWEAPONINFO_OFFSET_M_SZBRASSMODEL + 128,                                   // char m_szExplosionSound[128];
    CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONEFFECT = CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONSOUND + 128,                              // char m_szExplosionEffect[128];
    CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONPLAYEREFFECT = CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONEFFECT + 128,                       // char m_szExplosionPlayerEffect[128];
    CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONWATEREFFECT = CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONPLAYEREFFECT + 128,                  // char m_szExplosionWaterEffect[128];

    CTFWEAPONINFO_OFFSET_M_BDONTDROP = CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONWATEREFFECT + 128,                                // bool m_bDontDrop;

    SIZEOF_CTFWeaponInfo = CTFWEAPONINFO_OFFSET_M_BDONTDROP + 3,                                                           // sizeof(CTFWeaponInfo);
};

//////////////////////////////////////////////////////////////////////////////
// CTFWEAPONINFO METHODMAP                                                  //
//////////////////////////////////////////////////////////////////////////////

methodmap CTFWeaponInfo < FileWeaponInfo_t
{
    // Constructor - wrap around an existing address to make way for a CTFWeaponInfo object.
    public CTFWeaponInfo(Address address)
    {
        return view_as<CTFWeaponInfo>(address);
    }

    // There are two instances of WeaponData_t (SIZEOF_WeaponData_t).
    property Pointer m_WeaponData
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_WEAPONDATA; }
    }

    // Retrieve a WeaponData_t. There are two indexes of this.
    public WeaponData_t m_WeaponData_Get(int index)
    {
        if (index < 0 || index > 1)
            return NULL;
        return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_WEAPONDATA + index * SIZEOF_WeaponData_t;
    }

    // Sets a WeaponData_t. There are two indexes of this.
    public void m_WeaponData_Set(int index, WeaponData_t obj)
    {
        if (index < 0 || index > 1)
            return;
        memcpy(view_as<any>(this) + index * SIZEOF_WeaponData_t, obj, SIZEOF_WeaponData_t);
    }
    
    property int m_iWeaponType
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_IWEAPONTYPE); }
        public set(int value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_IWEAPONTYPE); }
    }

    // Grenade.
    property bool m_bGrenade
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BGRENADE, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BGRENADE, NumberType_Int8); }
    }

    property float m_flDamageRadius
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_FLDAMAGERADIUS); }
        public set(float value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_FLDAMAGERADIUS); }
    }

    property float m_flPrimerTime
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_FLPRIMERTIME); }
        public set(float value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_FLPRIMERTIME); }
    }

    property bool m_bLowerWeapon
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BLOWERWEAPON, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BLOWERWEAPON, NumberType_Int8); }
    }
    
    property bool m_bSuppressGrenTimer
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BSUPPRESSGRENTIMER, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BSUPPRESSGRENTIMER, NumberType_Int8); }
    }

    // Skins
    property bool m_bHasTeamSkins_Viewmodel
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_VIEWMODEL, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_VIEWMODEL, NumberType_Int8); }
    }
    
    property bool m_bHasTeamSkins_Worldmodel
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_WORLDMODEL, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BHASTEAMSKINS_WORLDMODEL, NumberType_Int8); }
    }

    // Muzzle flash
    // The buffer size is 128.
    property Pointer m_szMuzzleFlashModel
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHMODEL; }
    }

    property float m_flMuzzleFlashModelDuration
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_FLMUZZLEFLASHMODELDURATION); }
        public set(float value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_FLMUZZLEFLASHMODELDURATION); }
    }

    // The buffer size is 128.
    property Pointer m_szMuzzleFlashParticleEffect
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZMUZZLEFLASHPARTICLEEFFECT; }
    }

    // Tracer
    // The buffer size is 128.
    property Pointer m_szTracerEffect
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZTRACEREFFECT; }
    }

    // Eject Brass
    property bool m_bDoInstantEjectBrass
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BDOINSTANTEJECTBRASS, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BDOINSTANTEJECTBRASS, NumberType_Int8); }
    }

    // The buffer size is 128.
    property Pointer m_szBrassModel
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZBRASSMODEL; }
    }

    // Explosion Effect
    // The buffer size is 128.
    property Pointer m_szExplosionSound
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONSOUND; }
    }

    // The buffer size is 128.
    property Pointer m_szExplosionEffect
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONEFFECT; }
    }

    // The buffer size is 128.
    property Pointer m_szExplosionPlayerEffect
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONPLAYEREFFECT; }
    }

    // The buffer size is 128.
    property Pointer m_szExplosionWaterEffect
    {
        public get() { return view_as<any>(this) + CTFWEAPONINFO_OFFSET_M_SZEXPLOSIONWATEREFFECT; }
    }

    property bool m_bDontDrop
    {
        public get() { return this.Dereference(CTFWEAPONINFO_OFFSET_M_BDONTDROP, NumberType_Int8); }
        public set(bool value) { this.Write(value, CTFWEAPONINFO_OFFSET_M_BDONTDROP, NumberType_Int8); }
    }

    public WeaponData_t GetWeaponData(int iWeapon)
    {
        return this.m_WeaponData_Get(iWeapon);
    }

    // Call constructor on existing type.
    public void ctor()
    {
        this.m_WeaponData_Get(0).Init();
        this.m_WeaponData_Get(1).Init();

        this.m_bGrenade = false;
        this.m_flDamageRadius = 0.0;
        this.m_flPrimerTime = 0.0;
        this.m_bSuppressGrenTimer = false;
        this.m_bLowerWeapon = false;

        this.m_bHasTeamSkins_Viewmodel = false;
        this.m_bHasTeamSkins_Worldmodel = false;
        
        this.m_szMuzzleFlashModel.Write(0, .bits = NumberType_Int8);
        this.m_flMuzzleFlashModelDuration = 0.0;
        this.m_szMuzzleFlashParticleEffect.Write(0, .bits = NumberType_Int8);

        this.m_szTracerEffect.Write(0, .bits = NumberType_Int8);

        this.m_szBrassModel.Write(0, .bits = NumberType_Int8);
        this.m_bDoInstantEjectBrass = true;

        this.m_szExplosionSound.Write(0, .bits = NumberType_Int8);
        this.m_szExplosionEffect.Write(0, .bits = NumberType_Int8);
        this.m_szExplosionPlayerEffect.Write(0, .bits = NumberType_Int8);
        this.m_szExplosionWaterEffect.Write(0, .bits = NumberType_Int8);

        this.m_iWeaponType = TF_WPN_TYPE_PRIMARY;
    }

    // Constructor - allocate a new CTFWeaponInfo onto the heap. Deallocation will be required when you are finished using this using free().
    public static CTFWeaponInfo Malloc()
    {
        CTFWeaponInfo pointer = malloc(SIZEOF_CTFWeaponInfo);
        pointer.ctor();
        return pointer;
    }

    // Constructor - allocate a new CTFWeaponInfo onto the stack. When using the return value, you must use STACK_GETRETURN().
    public static STACK StackAlloc()
    {
        char buffer[SIZEOF_CTFWeaponInfo];
        view_as<CTFWeaponInfo>(AddressOfString(buffer)).ctor();
        return buffer;
    }
}