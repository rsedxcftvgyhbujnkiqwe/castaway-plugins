//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_WEAPONDATA_T
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_WEAPONDATA_T

// Requires "tf_shareddefs.inc".
#include "tf_shareddefs.inc"

//////////////////////////////////////////////////////////////////////////////
// WEAPONDATA_T DATA                                                        //
//////////////////////////////////////////////////////////////////////////////

enum
{
    WEAPONDATA_T_OFFSET_M_NDAMAGE = 0,                                                              // int m_nDamage;
    WEAPONDATA_T_OFFSET_M_NBULLETSPERSHOT = WEAPONDATA_T_OFFSET_M_NDAMAGE + SIZEOF_int,             // int m_nBulletsPerShot;
    WEAPONDATA_T_OFFSET_M_FLRANGE = WEAPONDATA_T_OFFSET_M_NBULLETSPERSHOT + SIZEOF_int,             // float m_flRange;
    WEAPONDATA_T_OFFSET_M_FLSPREAD = WEAPONDATA_T_OFFSET_M_FLRANGE + SIZEOF_float,                  // float m_flSpread;
    WEAPONDATA_T_OFFSET_M_FLPUNCHANGLE = WEAPONDATA_T_OFFSET_M_FLSPREAD + SIZEOF_float,             // float m_flPunchAngle;
    WEAPONDATA_T_OFFSET_M_FLTIMEFIREDELAY = WEAPONDATA_T_OFFSET_M_FLPUNCHANGLE + SIZEOF_float,      // float m_flTimeFireDelay;
    WEAPONDATA_T_OFFSET_M_FLTIMEIDLE = WEAPONDATA_T_OFFSET_M_FLTIMEFIREDELAY + SIZEOF_float,        // float m_flTimeIdle;
    WEAPONDATA_T_OFFSET_M_FLTIMEIDLEEMPTY = WEAPONDATA_T_OFFSET_M_FLTIMEIDLE + SIZEOF_float,        // float m_flTimeIdleEmpty;
    WEAPONDATA_T_OFFSET_M_FLTIMERELOADSTART = WEAPONDATA_T_OFFSET_M_FLTIMEIDLEEMPTY + SIZEOF_float, // float m_flTimeReloadStart;
    WEAPONDATA_T_OFFSET_M_FLTIMERELOAD = WEAPONDATA_T_OFFSET_M_FLTIMERELOADSTART + SIZEOF_float,    // float m_flTimeReload;
    WEAPONDATA_T_OFFSET_M_BDRAWCROSSHAIR = WEAPONDATA_T_OFFSET_M_FLTIMERELOAD + SIZEOF_float,       // bool m_bDrawCrosshair;
    WEAPONDATA_T_OFFSET_M_IPROJECTILE = WEAPONDATA_T_OFFSET_M_BDRAWCROSSHAIR + 4,                   // int m_iProjectile;
    WEAPONDATA_T_OFFSET_M_IAMMOPERSHOT = WEAPONDATA_T_OFFSET_M_IPROJECTILE + SIZEOF_int,            // int m_iAmmoPerShot;
    WEAPONDATA_T_OFFSET_M_FLPROJECTILESPEED = WEAPONDATA_T_OFFSET_M_IAMMOPERSHOT + SIZEOF_int,      // float m_flProjectileSpeed;
    WEAPONDATA_T_OFFSET_M_FLSMACKDELAY = WEAPONDATA_T_OFFSET_M_FLPROJECTILESPEED + SIZEOF_float,    // float m_flSmackDelay;
    WEAPONDATA_T_OFFSET_M_BUSERAPIDFIRECRITS = WEAPONDATA_T_OFFSET_M_FLSMACKDELAY + SIZEOF_float,   // bool m_bUseRapidFireCrits;

    SIZEOF_WeaponData_t = WEAPONDATA_T_OFFSET_M_BUSERAPIDFIRECRITS + 4                              // sizeof(WeaponData_t);
};

//////////////////////////////////////////////////////////////////////////////
// WEAPONDATA_T METHODMAP                                                   //
//////////////////////////////////////////////////////////////////////////////

// TF Weapon Info
methodmap WeaponData_t < Pointer
{
    // Constructor - wrap around an existing address to make way for a WeaponData_t object.
    public WeaponData_t(Address address)
    {
        return view_as<WeaponData_t>(address);
    }

    property int m_nDamage
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_NDAMAGE); }
        public set(int value) { this.Write(value, WEAPONDATA_T_OFFSET_M_NDAMAGE); }
    }

    property int m_nBulletsPerShot
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_NBULLETSPERSHOT); }
        public set(int value) { this.Write(value, WEAPONDATA_T_OFFSET_M_NBULLETSPERSHOT); }
    }

    property float m_flRange
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLRANGE); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLRANGE); }
    }

    property float m_flSpread
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLSPREAD); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLSPREAD); }
    }

    property float m_flPunchAngle
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLPUNCHANGLE); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLPUNCHANGLE); }
    }

    // Time to delay between firing
    property float m_flTimeFireDelay
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLTIMEFIREDELAY); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLTIMEFIREDELAY); }
    }

    // Time to idle after firing
    property float m_flTimeIdle
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLTIMEIDLE); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLRANGE); }
    }

    // Time to idle after firing last bullet in clip
    property float m_flTimeIdleEmpty
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLTIMEIDLEEMPTY); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLTIMEIDLEEMPTY); }
    }

    // Time to start into a reload (ie. shotgun)
    property float m_flTimeReloadStart
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLTIMERELOADSTART); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLTIMERELOADSTART); }
    }

    // Time to reload
    property float m_flTimeReload
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLTIMERELOAD); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLTIMERELOAD); }
    }

    // Should the weapon draw a crosshair
    property bool m_bDrawCrosshair
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_BDRAWCROSSHAIR, NumberType_Int8); }
        public set(bool value) { this.Write(value, WEAPONDATA_T_OFFSET_M_BDRAWCROSSHAIR, NumberType_Int8); }
    }

    // The type of projectile this mode fires
    property int m_iProjectile
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_IPROJECTILE); }
        public set(int value) { this.Write(value, WEAPONDATA_T_OFFSET_M_IPROJECTILE); }
    }

    // How much ammo each shot consumes
    property int m_iAmmoPerShot
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_IAMMOPERSHOT); }
        public set(int value) { this.Write(value, WEAPONDATA_T_OFFSET_M_IAMMOPERSHOT); }
    }

    // Start speed for projectiles (nail, etc.); NOTE: union with something non-projectile
    property float m_flProjectileSpeed
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLPROJECTILESPEED); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLPROJECTILESPEED); }
    }

    // how long after swing should damage happen for melee weapons
    property float m_flSmackDelay
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_FLSMACKDELAY); }
        public set(float value) { this.Write(value, WEAPONDATA_T_OFFSET_M_FLSMACKDELAY); }
    }

    property bool m_bUseRapidFireCrits
    {
        public get() { return this.Dereference(WEAPONDATA_T_OFFSET_M_BUSERAPIDFIRECRITS, NumberType_Int8); }
        public set(bool value) { this.Write(value, WEAPONDATA_T_OFFSET_M_BUSERAPIDFIRECRITS, NumberType_Int8); }
    }

    // Set all the values of a definition to its defaults.
    public void Init()
    {
        this.m_nDamage = 0;
        this.m_nBulletsPerShot = 0;
        this.m_flRange = 0.00;
        this.m_flSpread = 0.00;
        this.m_flPunchAngle = 0.00;
        this.m_flTimeFireDelay = 0.00;
        this.m_flTimeIdle = 0.00;
        this.m_flTimeIdleEmpty = 0.00;
        this.m_flTimeReloadStart = 0.00;
        this.m_flTimeReload = 0.00;
        this.m_iProjectile = TF_PROJECTILE_NONE;
        this.m_iAmmoPerShot = 0;
        this.m_flProjectileSpeed = 0.00;
        this.m_flSmackDelay = 0.00;
        this.m_bUseRapidFireCrits = false;
    }

    // Constructor - allocate a new WeaponData_t onto the heap. Deallocation will be required when you are finished using this using free().
    public static WeaponData_t Malloc()
    {
        return malloc(SIZEOF_WeaponData_t);
    }

    // Constructor - allocate a new WeaponData_t onto the stack. When using the return value, you must use STACK_GETRETURN().
    public static STACK StackAlloc()
    {
        char buffer[SIZEOF_WeaponData_t] = { 0, ... };
        return buffer;
    }
}