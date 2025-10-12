// 2024.10.11:
// this code is.. a mess, to say the least.
// the syntax is horrible because this was my first ever sm plugin, there's a
// lot of ugly stuff going on and honestly i'm only just maintaining gamedata
// for this plugin.
//
// in the future, i *may* work on a successor plugin - it just depends on
// my motivation and my current project ideas

//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// This uses TF2Items by asherkin. I have also used their offset lookup tool (https://asherkin.github.io/vtable/) so thank you, asherkin! :)
// https://forums.alliedmods.net/showthread.php?t=115100

// This plugin also uses DHooks with Detours by Dr!fter. This should be included with SourceMod 1.11.

// This plugin also uses SM-Memory by Scags.

//////////////////////////////////////////////////////////////////////////////
// PRE-PROCESSING                                                           //
//////////////////////////////////////////////////////////////////////////////

#pragma semicolon true // semicolons gamer

#include <sourcemod>
#include <tf2items>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <smmem>

#define PYRO_OVERHEAL 260
#define KUNAI_OVERHEAL 180
#define TICK_RATE 66
#define TICK_RATE_PRECISION GetTickInterval()
#define MAX_ENTITY_COUNT 2048
#define MAX_WEAPON_COUNT 10
#define MAX_SHORTSTOP_CLIP 4
#define SCOUT_PISTOL_AMMO_TYPE 2
#define FLESH_IMPACT_BULLET_COUNT 5

#define FLIGHT_TIME_TO_MAX_STUN	1.0

#define TF_STUN_NONE						0
#define TF_STUN_MOVEMENT					(1<<0)
#define	TF_STUN_CONTROLS					(1<<1)
#define TF_STUN_MOVEMENT_FORWARD_ONLY		(1<<2)
#define TF_STUN_SPECIAL_SOUND				(1<<3)
#define TF_STUN_DODGE_COOLDOWN				(1<<4)
#define TF_STUN_NO_EFFECTS					(1<<5)
#define TF_STUN_LOSER_STATE					(1<<6)
#define TF_STUN_BY_TRIGGER					(1<<7)
#define TF_STUN_BOTH						TF_STUN_MOVEMENT | TF_STUN_CONTROLS

#define WL_None 0
#define WL_Feet 1
#define WL_Waist 2
#define WL_Eyes 3

#define COLLISION_GROUP_NONE 0

#define DMG_DONT_COUNT_DAMAGE_TOWARDS_CRIT_RATE DMG_DISSOLVE // DON'T USE THIS FOR EXPLOSION DAMAGE YOU WILL MAKE BRANDON SAD AND KYLE SADDER

#define TF_MINIGUN_PENALTY_PERIOD 1.0
#define TF_MINIGUN_MAX_SPREAD 1.5

#define AC_STATE_IDLE 0
#define AC_STATE_FIRING 2
#define AC_STATE_SPINNING 3
#define AC_STATE_DRYFIRE 4

#define SENTRYGUN_MINIGUN_RESIST_LVL_2_OLD 0.85
#define SENTRYGUN_MINIGUN_RESIST_LVL_3_OLD 0.8
#define SENTRYGUN_MINIGUN_RESIST_LVL_2_NEW 0.8
#define SENTRYGUN_MINIGUN_RESIST_LVL_3_NEW 0.67

#define SENTRYGUN_SAPPER_OWNER_DAMAGE_MODIFIER_OLD 0.67
#define SENTRYGUN_SAPPER_OWNER_DAMAGE_MODIFIER_NEW 0.34

#define LUNCHBOX_ADDS_MINICRITS_DURATION 15.00

#define TF_WEAPON_PRIMARY_MODE		0
#define TF_WEAPON_SECONDARY_MODE	1

#define OBJECT_CONSTRUCTION_STARTINGHEALTH 0.1

#define TF_COND_RESIST_OFFSET 58

#define MAX_DECAPITATIONS 4

#define TF_WEAPON_SNIPERRIFLE_CHARGE_PER_SEC 50

#define MAX_HEAD_BONUS 6

#define FSOLID_USE_TRIGGER_BOUNDS (1 << 7) // Uses a special trigger bounds separate from the normal OBB.

#define ACT_ITEM2_VM_PRIMARYATTACK 1652 // ai_activity.h

#define EF_NODRAW (1 << 5)

#define MODEL_PRECACHE_TABLENAME "modelprecache"

#define TF_BURNING_FLAME_LIFE_PYRO	0.25		// pyro only displays burning effect momentarily

#define PLUGIN_NAME "NotnHeavy - Pre-Gun Mettle Reverts"

DHookSetup DHooks_GetRadius;
DHookSetup DHooks_CTFWeaponBase_FinishReload;
DHookSetup DHooks_CTFWeaponBase_Reload;
DHookSetup DHooks_CTFWeaponBase_PrimaryAttack;
DHookSetup DHooks_CTFWeaponBase_SecondaryAttack;
DHookSetup DHooks_CTFMinigun_GetWeaponSpread;
DHookSetup DHooks_CTFMinigun_GetProjectileDamage;
DHookSetup DHooks_CTFSniperRifleDecap_SniperRifleChargeRateMod;
DHookSetup DHooks_CTFBall_Ornament_Explode;
DHookSetup DHooks_CAmmoPack_MyTouch;
DHookSetup DHooks_CTFWrench_Equip;
DHookSetup DHooks_CTFWrench_Detach;
DHookSetup DHooks_CWeaponMedigun_ItemPostFrame;
DHookSetup DHooks_CBaseObject_Command_Repair;
DHookSetup DHooks_CBaseObject_StartBuilding;
DHookSetup DHooks_CBaseObject_Construct;
DHookSetup DHooks_CObjectSapper_FinishedBuilding;
DHookSetup DHooks_CObjectSentrygun_OnWrenchHit;
DHookSetup DHooks_CTFProjectile_HealingBolt_ImpactTeamPlayer;

DHookSetup DHooks_InternalCalculateObjectCost;
DHookSetup DHooks_GetPlayerClassData;
DHookSetup DHooks_CTeamplayRoundBasedRules_GetActiveRoundTimer;
DHookSetup DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed;
DHookSetup DHooks_CTFPlayer_CanAirDash;
DHookSetup DHooks_CTFPlayer_Taunt;
DHookSetup DHooks_CTFPlayer_RegenThink;
DHookSetup DHooks_CTFPlayer_MedicGetHealTarget;
DHookSetup DHooks_CTFPlayer_ApplyPunchImpulseX;
DHookSetup DHooks_CTFPlayer_AddToSpyKnife;
DHookSetup DHooks_CTFPlayer_OnTakeDamage_Alive;
DHookSetup DHooks_CTFPlayerShared_AddCond;
DHookSetup DHooks_CTFPlayerShared_RemoveCond;
DHookSetup DHooks_CTFPlayerShared_SetRageMeter;
DHookSetup DHooks_CTFPlayerShared_CalcChargeCrit;
DHookSetup DHooks_CTFPlayerShared_AddToSpyCloakMeter;
//DHookSetup DHooks_CTFPlayerShared_Heal;
DHookSetup DHooks_CTFPlayerShared_CanRecieveMedigunChargeEffect;
DHookSetup DHooks_CTFWeaponBaseMelee_OnSwingHit;
DHookSetup DHooks_CTFMinigun_SharedAttack;
DHookSetup CTFWearable_CTFWearable_Break;
DHookSetup DHooks_CTFWearableDemoShield_ShieldBash;
DHookSetup DHooks_CTFAmmoPack_PackTouch;
DHookSetup DHooks_CTFLunchBox_ApplyBiteEffects;
DHookSetup DHooks_CTFLunchBox_DrainAmmo;
DHookSetup DHooks_CWeaponMedigun_FindAndHealTargets;
DHookSetup DHooks_CBaseObject_OnConstructionHit;
DHookSetup DHooks_CBaseObject_GetConstructionMultiplier;
DHookSetup DHooks_CBaseObject_CreateAmmoPack;
DHookSetup DHooks_CTFProjectile_Arrow_BuildingHealingArrow;
DHookSetup DHooks_CTFGameRules_ApplyOnDamageModifyRules;

Handle SDKCall_CAmmoPack_GetPowerupSize;
Handle SDKCall_CTFPlayer_EquipWearable;
Handle SDKCall_CTFItem_GetItemID;
Handle SDKCall_CWeaponMedigun_CanAttack;
Handle SDKCall_CBaseObject_DetonateObject;
Handle SDKCall_CBaseObject_GetType;

Handle SDKCall_CTFPlayer_TryToPickupBuilding;
Handle SDKCall_CTFWeaponBaseGun_GetWeaponSpread;
Handle SDKCall_CTFWeaponBaseGun_GetProjectileDamage;
Handle SDKCall_CTFWrench_GetConstructionValue;
Handle SDKCall_CBaseObject_GetReversesBuildingConstructionSpeed;

ConVar tf_scout_hype_mod;
ConVar tf_scout_stunball_base_duration;
ConVar tf_parachute_maxspeed_onfire_z;
ConVar tf_weapon_minicrits_distance_falloff;
ConVar tf_weapon_criticals_distance_falloff;
bool tf_weapon_minicrits_distance_falloff_original;
bool tf_weapon_criticals_distance_falloff_original;

ConVar notnheavy_gunmettle_reverts_reject_newitems;

Address MemoryPatch_ShieldTurnCap;
Address MemoryPatch_ShieldTurnCap_OldValue;
float MemoryPatch_ShieldTurnCap_NewValue = 1000.00;

Address MemoryPatch_NormalScorchShotKnockback;
Address MemoryPatch_NormalScorchShotKnockback_oldValue;
float MemoryPatch_NormalScorchShotKnockback_NewValue = 100.00;

Address MemoryPatch_DisableDebuffShortenWhilstCloaked;
Address MemoryPatch_DisableDebuffShortenWhilstCloaked_oldValue;
float MemoryPatch_DisableDebuffShortenWhilstCloaked_NewValue = 0.00;

Address MemoryPatch_FixYourEternalReward;
char MemoryPatch_FixYourEternalReward_OldValue[6];
char MemoryPatch_FixYourEternalReward_NewValue[] = "\x90\x90\x90\x90\x90\x90";
int MemoryPatch_FixYourEternalReward_NOPCount;

Address MemoryPatch_DisguiseIsAlways2Seconds;
Address MemoryPatch_DisguiseIsAlways2Seconds_OldValue;
float MemoryPatch_DisguiseIsAlways2Seconds_NewValue = 2.00;

Address CTFPlayerShared_m_pOuter;
Address CGameTrace_m_pEnt;
Address CTakeDamageInfo_m_hAttacker;
Address CTakeDamageInfo_m_flDamage;
Address CTakeDamageInfo_m_bitsDamageType;
//Address CTakeDamageInfo_m_flDamageBonus;
Address CTakeDamageInfo_m_eCritType;
Address CWeaponMedigun_m_bReloadDown; // *((_BYTE *)this + 2059)
Address CObjectSentrygun_m_flShieldFadeTime; // *((float *)this + 712)
Address CObjectBase_m_flHealth; // *((float *)a1 + 652)
Address CTFPlayer_m_aObjects;
const Address TFPlayerClassData_t_m_flMaxSpeed = view_as<Address>(640); // *((float *)this + 160)

Address SpyClassData;

const int ShortCircuit_MaxCollectedEntities = 64;
int ShortCircuit_CurrentCollectedEntities = 0;

bool BypassRoundTimerChecks = false;

int OriginalTF2ItemsIndex = -1;

//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "NotnHeavy",
    description = "An attempt to revert weapon functionality to how they were pre-Gun Mettle, as accurately as possible.",
    version = "1.4.8",
    url = "https://github.com/NotnHeavy/TF2-Pre-Gun-Mettle-Reverts"
};

//////////////////////////////////////////////////////////////////////////////
// UTILITY                                                                  //
//////////////////////////////////////////////////////////////////////////////

// Get the smaller integral value.
int intMin(int x, int y)
{
    return x > y ? y : x;
}

// Get the larger integral value.
int intMax(int x, int y)
{
    return x > y ? x : y;
}

// Get the smaller floating point value.
float min(float x, float y)
{
    return x > y ? y : x;
}

// Get the larger floating point value.
float max(float x, float y)
{
    return x > y ? x : y;
}

//////////////////////////////////////////////////////////////////////////////
// TF2 code                                                                 //
//////////////////////////////////////////////////////////////////////////////

enum taunts_t
{
	TAUNT_BASE_WEAPON,		// The standard taunt we shipped with. Taunts based on your currently held weapon
	TAUNT_MISC_ITEM,		// Taunts based on the item you have equipped in your Misc slot.
	TAUNT_SHOW_ITEM,		// Show off an item to everyone nearby
	TAUNT_LONG,				// Press-and-hold taunt
	TAUNT_SPECIAL,			// Special-case taunts called explicitly from code
	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//
};

enum powerupsize_t
{
	POWERUP_SMALL,
	POWERUP_MEDIUM,
	POWERUP_FULL,

	POWERUP_SIZES,
};

enum ObjectType_t
{
	OBJ_DISPENSER=0,
	OBJ_TELEPORTER,
	OBJ_SENTRYGUN,

	// Attachment Objects
	OBJ_ATTACHMENT_SAPPER,

	// If you add a new object, you need to add it to the g_ObjectInfos array 
	// in tf_shareddefs.cpp, and add it's data to the scripts/object.txt

	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//

	OBJ_LAST,
};

enum ETFAmmoType
{
	TF_AMMO_DUMMY = 0,	// Dummy index to make the CAmmoDef indices correct for the other ammo types.
	TF_AMMO_PRIMARY,
	TF_AMMO_SECONDARY,
	TF_AMMO_METAL,
	TF_AMMO_GRENADES1,
	TF_AMMO_GRENADES2,
	TF_AMMO_GRENADES3,	// Utility Slot Grenades
	TF_AMMO_COUNT,

	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//
};

enum ETFFlagType
{
	TF_FLAGTYPE_CTF = 0,
	TF_FLAGTYPE_ATTACK_DEFEND,
	TF_FLAGTYPE_TERRITORY_CONTROL,
	TF_FLAGTYPE_INVADE,
	TF_FLAGTYPE_RESOURCE_CONTROL,
	TF_FLAGTYPE_ROBOT_DESTRUCTION,
	TF_FLAGTYPE_PLAYER_DESTRUCTION

	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//
};

enum ETFGameType
{
	TF_GAMETYPE_UNDEFINED = 0,
	TF_GAMETYPE_CTF,
	TF_GAMETYPE_CP,
	TF_GAMETYPE_ESCORT,
	TF_GAMETYPE_ARENA,
	TF_GAMETYPE_MVM,
	TF_GAMETYPE_RD,
	TF_GAMETYPE_PASSTIME,
	TF_GAMETYPE_PD,

	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//
	TF_GAMETYPE_COUNT
};

enum ECritType
{
    CRIT_NONE = 0,
    CRIT_MINI,
    CRIT_FULL,
};

enum
{
	MEDIGUN_CHARGE_INVALID = -1,
	MEDIGUN_CHARGE_INVULN = 0,
	MEDIGUN_CHARGE_CRITICALBOOST,
	MEDIGUN_CHARGE_MEGAHEAL,
	MEDIGUN_CHARGE_BULLET_RESIST,
	MEDIGUN_CHARGE_BLAST_RESIST,
	MEDIGUN_CHARGE_FIRE_RESIST,

	MEDIGUN_NUM_CHARGE_TYPES,
};

enum
{
	MEDIGUN_BULLET_RESIST = 0,
	MEDIGUN_BLAST_RESIST,
	MEDIGUN_FIRE_RESIST,
	MEDIGUN_NUM_RESISTS
};

enum
{
	SHIELD_NONE = 0,
	SHIELD_NORMAL,	// 33% damage taken, no tracking
	SHIELD_MAX,		// 10% damage taken, tracking
};

enum
{
	TF_ITEM_UNDEFINED		= 0,
	TF_ITEM_CAPTURE_FLAG	= (1<<0),
	TF_ITEM_HEALTH_KIT		= (1<<1),
	TF_ITEM_ARMOR			= (1<<2),
	TF_ITEM_AMMO_PACK		= (1<<3),
	TF_ITEM_GRENADE_PACK	= (1<<4),

	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//
};

TFCond g_aDebuffConditions[] =
{
	TFCond_OnFire,
	TFCond_Jarated,
	TFCond_Bleeding,
	TFCond_Milked
};

float PackRatios[] =
{
	0.2,	// SMALL
	0.5,	// MEDIUM
	1.0,	// FULL
};

bool IsInvulnerable(int entity)
{
	return TF2_IsPlayerInCondition(entity, TFCond_Ubercharged) || 
           TF2_IsPlayerInCondition(entity, TFCond_UberchargedCanteen) || 
           TF2_IsPlayerInCondition(entity, TFCond_UberchargedHidden) ||
           TF2_IsPlayerInCondition(entity, TFCond_UberchargedOnTakeDamage);
}

bool IsMannVsMachineMode()
{
    return GameRules_GetProp("m_bPlayingMannVsMachine") == 1;
}

bool IsInTraining()
{
    return GameRules_GetPropEnt("m_bIsInTraining") == 1;
}

bool IsBountyMode()
{
    return GameRules_GetProp("m_bBountyModeEnabled") == 1 && !IsMannVsMachineMode() && !IsInTraining();
}

bool GameModeUsesMiniBosses()
{
    return IsMannVsMachineMode() || IsBountyMode();
}

bool IsPasstimeMode()
{
    return view_as<ETFGameType>(GameRules_GetProp("m_nGameType")) == TF_GAMETYPE_PASSTIME;
}

bool IsSetup()
{
    return GameRules_GetProp("m_bInSetup") == 1;
}

int GetChargeType(int entity)
{
    int iTmp = MEDIGUN_CHARGE_INVULN;
    if (GetWeaponIndex(entity) == 998)
        iTmp += GetEntProp(entity, Prop_Send, "m_nChargeResistType");
    return iTmp;
}

int GetResistType(int entity)
{
    // the original code is weird and this does what i want but it's here for the sake of it.
    return GetChargeType(entity);
}

ETFFlagType GetType(int entity)
{
    return view_as<ETFFlagType>(GetEntProp(entity, Prop_Send, "m_nType"));
}

bool CanReceiveMedigunChargeEffect(int client, int eType)
{
    bool bCanRecieve = true;

    int pItem = GetEntPropEnt(client, Prop_Send, "m_hItem");
    if (pItem != -1 && SDKCall(SDKCall_CTFItem_GetItemID, pItem) == TF_ITEM_CAPTURE_FLAG)
    {
        bCanRecieve = false;

        if 
        (
            GetType(pItem) == TF_FLAGTYPE_PLAYER_DESTRUCTION || // The "flag" in Player Destruction doesn't block uber
            IsMannVsMachineMode() || // allow bot flag carriers to be ubered
            eType == MEDIGUN_CHARGE_MEGAHEAL ||
            eType == MEDIGUN_CHARGE_BULLET_RESIST ||
            eType == MEDIGUN_CHARGE_BLAST_RESIST ||
            eType == MEDIGUN_CHARGE_FIRE_RESIST
        )
            bCanRecieve = true;
    }

    if (IsPasstimeMode())
            bCanRecieve &= !GetEntProp(client, Prop_Send, "m_bHasPasstimeBall");

    return bCanRecieve;
}

float RemapValClamped(float val, float A, float B, float C, float D)
{
	if ( A == B )
		return val >= B ? D : C;
	float cVal = (val - A) / (B - A);
	cVal = clamp( cVal, 0.0, 1.0 );

	return C + (D - C) * cVal;
}

float clamp(float val, float minVal, float maxVal)
{
	if ( maxVal < minVal )
		return maxVal;
	else if( val < minVal )
		return minVal;
	else if( val > maxVal )
		return maxVal;
	else
		return val;
}

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

enum TF2ConVarType
{
    TF2ConVarType_Int,
    TF2ConVarType_Float
}
enum BazaarBargainShotManager
{
    BazaarBargain_Lose = -1,
    BazaarBargain_Idle = 0,
    BazaarBargain_Gain
}

enum struct Player
{
    float TimeSinceEncounterWithFire;
    int FramesSinceLastSwitch;
    int TicksSinceHeadshot;
    int TickSinceBonk;
    int MaxHealth;
    int SpreadRecovery; // For Ambassador headshots.
    int HealthBeforeKill; // For Conniver's Kunai backstabs.
    int TicksSinceProjectileEncounter;
    int MostRecentProjectileEncounter;
    int OldHealth;
    
    int Weapons[MAX_WEAPON_COUNT];

    // Shortstop.
    int PrimaryAmmo;
    int SecondaryAmmo;

    // Pretty Boy's Pocket Pistol.
    int TicksSinceFallDamage;

    // BONK! Atomic Punch.
    int TicksSinceBonkEnd;

    // Crit-a-Cola.
    int TicksSinceAttack;

    // Flying Guillotine.
    float CleaverChargeMeter;

    // B.A.S.E. Jumper.
    float TimeSinceDeployment;

    // Phlog.
    int TicksSinceMmmphUsage;

    // Disciplinary Action.
    int TicksSinceSpeedBoost;

    // Shields.
    float TimeSinceShieldBash;
    bool ChargeBashHitPlayer;
    bool GiveChargeOnKill;
    int TicksSinceCharge;

    // Panic Attack.
    int TicksSinceFiring;

    // Buffalo Steak Sandvich.
    int TicksSinceConsumingSandvich;

    // Rescue Ranger.
    int OldMetalCount;

    // Medic.
    int RegenThink;
    float CurrentUber;

    // Vaccinator.
    bool VaccinatorHealers[MAXPLAYERS + 1];
    bool UsingVaccinatorUber;
    float VaccinatorCharge;
    float EndVaccinatorChargeFalloff;
    int TicksSinceApplyingDamageRules;
    Address DamageInfo;
    int ActualDamageType;
    ECritType ActualCritType;

    // Vita-Saw.
    bool HadVitaSawEquipped;

    // Huntsman.
    int WasInAttack;

    // Sydney Sleeper.
    float TimeSinceScoping;

    // Bazaar Bargain.
    BazaarBargainShotManager BazaarBargainShot;

    // Dead Ringer.
    bool FeigningDeath;
    int TicksSinceFeignReady;
    float DamageTakenDuringFeign;

    // Weapon models.
    int CurrentViewmodel;
    int CurrentArmsViewmodel;
    int CurrentWorldmodel;
    bool UsingCustomModels;
    bool InactiveDuringTaunt;

    // Rocket Jumper.
    int WeaponBlastJumpedWith;
}
enum struct Entity
{
    int OriginalTF2ItemsIndex;

    // Construction boosts. Would make this a separate enum struct but enum structs are one-dimensional.
    float ConstructionBoostExpiryTimes[MAXPLAYERS + 1];
    float ConstructionBoosts[MAXPLAYERS + 1];
    
    char Class[MAX_NAME_LENGTH];
    float SpawnTimestamp;
    int Owner;
    
    // Miniguns.
    float TimeSinceMinigunFiring;

    // Wrangler.
    int OldShield;
    float ShieldFadeTime;

    // Gunslinger.
    float BuildingHealth;

    // Vaccinator.
    int CurrentHealer;

    // Sapper.
    int AttachedSapper;
}
enum struct ModelInformation
{
    char Model[PLATFORM_MAX_PATH];
    char Texture[PLATFORM_MAX_PATH];
    
    bool ShowWhileTaunting;
    int ItemDefinitionIndex;
    int Cache;
    
    char FullModel[PLATFORM_MAX_PATH];
}
enum struct BlockedItem
{
    char Name[MAX_NAME_LENGTH];
    int Index;
}
enum struct TF2ConVar
{
    char Name[MAX_NAME_LENGTH];
    Handle Variable;
    any DefaultValue;
    any NewValue;
    TF2ConVarType Type;
}
Player allPlayers[MAXPLAYERS + 1];
Entity allEntities[MAX_ENTITY_COUNT];
int weaponHealthModifiers[][] = // A bit finnicky, but this is the closest I can get to a dictionary - with two-dimensional arrays.
{
    { 327, -15 }, // Claidheamh Mòr.
    { 773, 15 }, // Pretty Boy's Pocket Pistol.
    { 310, -20 }, // Warrior's Spirit.
    { 231, 25 }, // Darwin's Danger Shield,
};
int chargeOnChargeKillWeapons[][] =
{
    { 608, 25 }, // Bootlegger.
    { 405, 25 }, // Ali Baba's Wee Booties.
    { 1099, 75 }, // Tide Turner.
    { 327, 25 } // Claidheamh Mòr.
};
ModelInformation customWeapons[] =
{
    { "models\\weapons\\c_models\\c_rocketjumper\\c_oldrocketjumper", "materials\\models\\weapons\\c_items\\c_rocketjumper", false, 237 }, // Rocket Jumper.
    { "models\\weapons\\c_models\\c_old_sticky_jumper", "materials\\models\\weapons\\c_items\\c_sticky_jumper", true, 265 } // Sticky Jumper.
};
BlockedItem blockedWeapons[] =
{
    { "Dragon's Fury", 1178 },
    { "Thermal Thruster", 1179 },
    { "Gas Passer", 1180 },
    { "Hot Hand", 1181 },
    { "Second Banana", 1190 },
    { "Prinny Machete", 30758 }
};
TF2ConVar defaultConVars[] =
{ 
    { "tf_airblast_cray", INVALID_HANDLE, 0, 0, TF2ConVarType_Int },  // Revert to previous airblast. Still need to change the hitboxes, not sure how though.
    { "tf_dropped_weapon_lifetime", INVALID_HANDLE, 0, 0, TF2ConVarType_Int }, // Do not drop weapons.
    { "tf_parachute_aircontrol", INVALID_HANDLE, 0, 5.00, TF2ConVarType_Float }, // Give back full air control to the B.A.S.E. Jumper.
    { "tf_damageforcescale_pyro_jump", INVALID_HANDLE, 0, 6.50, TF2ConVarType_Float }, // Tune the Detonator/Scorch Shot jumps slightly.
    { "tf_construction_build_rate_multiplier", INVALID_HANDLE, 0, 2.00, TF2ConVarType_Float }, // Change the default build rate multiplier to 2.
    { "tf_feign_death_activate_damage_scale", INVALID_HANDLE, 0, 0.10, TF2ConVarType_Float }, // Apply 90% damage resistance when activating feign death. This is to get around damage numbers appearing 10 times smaller.
    { "tf_feign_death_damage_scale", INVALID_HANDLE, 0, 1.00, TF2ConVarType_Float }, // Don't apply any damage resistance while feigning. It'll ramp down anyway.
    { "tf_feign_death_duration", INVALID_HANDLE, 0, 0.00, TF2ConVarType_Float }, // Don't provide any damage buffs, I'll just handle everything myself.
    { "tf_stealth_damage_reduction", INVALID_HANDLE, 0, 1.0, TF2ConVarType_Float }, // Cloaking does not provide any damage resistance.

    // NotnHeavy's Old Flamethrower Mechanics
    { "notnheavy_flamethrower_damage", INVALID_HANDLE, 0, 6.80, TF2ConVarType_Float }, // 6.80 flame damage
    { "notnheavy_flamethrower_falloff", INVALID_HANDLE, 0, 0.60, TF2ConVarType_Float }, // 60% falloff
    { "notnheavy_flamethrower_oldafterburn_damage", INVALID_HANDLE, 0, 1, TF2ConVarType_Int }, // Use old afterburn damage.
    { "notnheavy_flamethrower_oldafterburn_duration", INVALID_HANDLE, 0, 1, TF2ConVarType_Int }, // Use old afterburn duration.
};
int resistanceMapping[] =
{
    DMG_BULLET | DMG_BUCKSHOT,
    DMG_BLAST,
    DMG_IGNITE | DMG_BURN
};
char modelExtensions[][] =
{
    ".dx80.vtx",
    ".dx90.vtx",
    ".phy",
    ".sw.vtx",
    ".vvd"
};
char textureExtensions[][] =
{
    ".vmt",
    ".vtf"
};
char armsViewmodels[][] = 
{
    // Gunslinger arms viewmodels.
    "models\\weapons\\c_models\\c_engineer_gunslinger.mdl",

    // Main arms viewmodels.
    "models\\weapons\\c_models\\c_scout_arms.mdl",
    "models\\weapons\\c_models\\c_sniper_arms.mdl",
    "models\\weapons\\c_models\\c_soldier_arms.mdl",
    "models\\weapons\\c_models\\c_demo_arms.mdl",
    "models\\weapons\\c_models\\c_medic_arms.mdl",
    "models\\weapons\\c_models\\c_heavy_arms.mdl",
    "models\\weapons\\c_models\\c_pyro_arms.mdl",
    "models\\weapons\\c_models\\c_spy_arms.mdl",
    "models\\weapons\\c_models\\c_engineer_arms.mdl"
};

//////////////////////////////////////////////////////////////////////////////
// SPECIFIC UTILITY                                                         //
//////////////////////////////////////////////////////////////////////////////

void SetTF2ConVarValue(char[] name, any value)
{
    for (int i = 0; i < sizeof(defaultConVars); ++i)
    {
        if (StrEqual(defaultConVars[i].Name, name))
        {
            if (defaultConVars[i].Variable == INVALID_HANDLE)
            {
                defaultConVars[i].Variable = FindConVar(defaultConVars[i].Name);
                if (defaultConVars[i].Variable != INVALID_HANDLE)
                {
                    if (defaultConVars[i].Type == TF2ConVarType_Int)
                        defaultConVars[i].DefaultValue = GetConVarInt(defaultConVars[i].Variable);
                    else if (defaultConVars[i].Type == TF2ConVarType_Float)
                        defaultConVars[i].DefaultValue = GetConVarFloat(defaultConVars[i].Variable);
                }
                else
                    break;
            }

            if (defaultConVars[i].Type == TF2ConVarType_Int)
                SetConVarInt(defaultConVars[i].Variable, value);
            else if (defaultConVars[i].Type == TF2ConVarType_Float)
                SetConVarFloat(defaultConVars[i].Variable, value);
            break;
        }
    }
}

//////////////////////////////////////////////////////////////////////////////
// INITIALISATION                                                           //
//////////////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    HookEvent("player_spawn", ClientSpawn);
    HookEvent("player_death", ClientDeath, EventHookMode_Pre);
    HookEvent("rocket_jump", ClientBlastJumped, EventHookMode_Pre);
    HookEvent("sticky_jump", ClientBlastJumped, EventHookMode_Pre);
    HookEvent("post_inventory_application", PostClientInventoryReset);

    AddNormalSoundHook(SoundPlayed);

    // Configs!
    GameData config = LoadGameConfigFile(PLUGIN_NAME);
    if (config == null)
    {
        SetFailState("The configuration file for plugin \"%s\" has failed to load. Please make sure that it is actually present in your gamedata directory.", PLUGIN_NAME);
    }

    // DHooks.
    DHooks_GetRadius = DHookCreateFromConf(config, "GetRadius");
    DHooks_CTFWeaponBase_FinishReload = DHookCreateFromConf(config, "CTFWeaponBase::FinishReload");
    DHooks_CTFWeaponBase_Reload = DHookCreateFromConf(config, "CTFWeaponBase::Reload");
    DHooks_CTFWeaponBase_PrimaryAttack = DHookCreateFromConf(config, "CTFWeaponBase::PrimaryAttack");
    DHooks_CTFWeaponBase_SecondaryAttack = DHookCreateFromConf(config, "CTFWeaponBase::SecondaryAttack");
    DHooks_CTFMinigun_GetWeaponSpread = DHookCreateFromConf(config, "CTFMinigun::GetWeaponSpread");
    DHooks_CTFMinigun_GetProjectileDamage = DHookCreateFromConf(config, "CTFMinigun::GetProjectileDamage");
    DHooks_CTFSniperRifleDecap_SniperRifleChargeRateMod = DHookCreateFromConf(config, "CTFSniperRifleDecap::SniperRifleChargeRateMod");
    DHooks_CTFBall_Ornament_Explode = DHookCreateFromConf(config, "CTFBall_Ornament::Explode");
    DHooks_CAmmoPack_MyTouch = DHookCreateFromConf(config, "CAmmoPack::MyTouch");
    DHooks_CTFWrench_Equip = DHookCreateFromConf(config, "CTFWrench::Equip");
    DHooks_CTFWrench_Detach = DHookCreateFromConf(config, "CTFWrench::Detach");
    DHooks_CWeaponMedigun_ItemPostFrame = DHookCreateFromConf(config, "CWeaponMedigun::ItemPostFrame");
    DHooks_CBaseObject_Command_Repair = DHookCreateFromConf(config, "CBaseObject::Command_Repair");
    DHooks_CBaseObject_StartBuilding = DHookCreateFromConf(config, "CBaseObject::StartBuilding");
    DHooks_CBaseObject_Construct = DHookCreateFromConf(config, "CBaseObject::Construct");
    DHooks_CObjectSapper_FinishedBuilding = DHookCreateFromConf(config, "CObjectSapper::FinishedBuilding");
    DHooks_CObjectSentrygun_OnWrenchHit = DHookCreateFromConf(config, "CObjectSentrygun::OnWrenchHit");
    DHooks_CTFProjectile_HealingBolt_ImpactTeamPlayer = DHookCreateFromConf(config, "CTFProjectile_HealingBolt::ImpactTeamPlayer");

    DHooks_InternalCalculateObjectCost = DHookCreateFromConf(config, "InternalCalculateObjectCost");
    DHooks_GetPlayerClassData = DHookCreateFromConf(config, "GetPlayerClassData");
    DHooks_CTeamplayRoundBasedRules_GetActiveRoundTimer = DHookCreateFromConf(config, "CTeamplayRoundBasedRules::GetActiveRoundTimer");
    DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed = DHookCreateFromConf(config, "CTFPlayer::TeamFortress_CalculateMaxSpeed");
    DHooks_CTFPlayer_CanAirDash = DHookCreateFromConf(config, "CTFPlayer::CanAirDash");
    DHooks_CTFPlayer_Taunt = DHookCreateFromConf(config, "CTFPlayer::Taunt");
    DHooks_CTFPlayer_RegenThink = DHookCreateFromConf(config, "CTFPlayer::RegenThink");
    DHooks_CTFPlayer_MedicGetHealTarget = DHookCreateFromConf(config, "CTFPlayer::MedicGetHealTarget");
    DHooks_CTFPlayer_ApplyPunchImpulseX = DHookCreateFromConf(config, "CTFPlayer::ApplyPunchImpulseX");
    DHooks_CTFPlayer_AddToSpyKnife = DHookCreateFromConf(config, "CTFPlayer::AddToSpyKnife");
    DHooks_CTFPlayer_OnTakeDamage_Alive = DHookCreateFromConf(config, "CTFPlayer::OnTakeDamage_Alive");
    DHooks_CTFPlayerShared_AddCond = DHookCreateFromConf(config, "CTFPlayerShared::AddCond");
    DHooks_CTFPlayerShared_RemoveCond = DHookCreateFromConf(config, "CTFPlayerShared::RemoveCond");
    DHooks_CTFPlayerShared_SetRageMeter = DHookCreateFromConf(config, "CTFPlayerShared::SetRageMeter");
    DHooks_CTFPlayerShared_CalcChargeCrit = DHookCreateFromConf(config, "CTFPlayerShared::CalcChargeCrit");
    DHooks_CTFPlayerShared_AddToSpyCloakMeter = DHookCreateFromConf(config, "CTFPlayerShared::AddToSpyCloakMeter");
    //DHooks_CTFPlayerShared_Heal = DHookCreateFromConf(config, "CTFPlayerShared::Heal");
    DHooks_CTFPlayerShared_CanRecieveMedigunChargeEffect = DHookCreateFromConf(config, "CTFPlayerShared::CanRecieveMedigunChargeEffect");
    DHooks_CTFWeaponBaseMelee_OnSwingHit = DHookCreateFromConf(config, "CTFWeaponBaseMelee::OnSwingHit");
    DHooks_CTFMinigun_SharedAttack = DHookCreateFromConf(config, "CTFMinigun::SharedAttack");
    CTFWearable_CTFWearable_Break = DHookCreateFromConf(config, "CTFWearable::Break");
    DHooks_CTFWearableDemoShield_ShieldBash = DHookCreateFromConf(config, "CTFWearableDemoShield::ShieldBash");
    DHooks_CTFAmmoPack_PackTouch = DHookCreateFromConf(config, "CTFAmmoPack::PackTouch");
    DHooks_CTFLunchBox_ApplyBiteEffects = DHookCreateFromConf(config, "CTFLunchBox::ApplyBiteEffects");
    DHooks_CTFLunchBox_DrainAmmo = DHookCreateFromConf(config, "CTFLunchBox::DrainAmmo");
    DHooks_CWeaponMedigun_FindAndHealTargets = DHookCreateFromConf(config, "CWeaponMedigun::FindAndHealTargets");
    DHooks_CBaseObject_OnConstructionHit = DHookCreateFromConf(config, "CBaseObject::OnConstructionHit");
    DHooks_CBaseObject_GetConstructionMultiplier = DHookCreateFromConf(config, "CBaseObject::GetConstructionMultiplier");
    DHooks_CBaseObject_CreateAmmoPack = DHookCreateFromConf(config, "CBaseObject::CreateAmmoPack");
    DHooks_CTFProjectile_Arrow_BuildingHealingArrow = DHookCreateFromConf(config, "CTFProjectile_Arrow::BuildingHealingArrow");
    DHooks_CTFGameRules_ApplyOnDamageModifyRules = DHookCreateFromConf(config, "CTFGameRules::ApplyOnDamageModifyRules");
    
    DHookEnableDetour(DHooks_InternalCalculateObjectCost, false, GetBuildingCost);
    DHookEnableDetour(DHooks_GetPlayerClassData, true, GetTFClassData);
    DHookEnableDetour(DHooks_CTeamplayRoundBasedRules_GetActiveRoundTimer, false, IsRoundTimerActive);
    DHookEnableDetour(DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed, true, CalculateMaxSpeed);
    DHookEnableDetour(DHooks_CTFPlayer_CanAirDash, false, CanAirDash);
    DHookEnableDetour(DHooks_CTFPlayer_Taunt, false, UseTaunt);
    DHookEnableDetour(DHooks_CTFPlayer_RegenThink, false, PlayerHealthRegen);
    DHookEnableDetour(DHooks_CTFPlayer_MedicGetHealTarget, false, GetPlayerHealTarget);
    DHookEnableDetour(DHooks_CTFPlayer_ApplyPunchImpulseX, false, ConfigureSniperFlinching);
    DHookEnableDetour(DHooks_CTFPlayer_AddToSpyKnife, false, AddToSpycicleMeter);
    DHookEnableDetour(DHooks_CTFPlayer_OnTakeDamage_Alive, false, OnTakeDamageAlive);
    DHookEnableDetour(DHooks_CTFPlayerShared_AddCond, false, AddCondition);
    DHookEnableDetour(DHooks_CTFPlayerShared_RemoveCond, false, RemoveCondition);
    DHookEnableDetour(DHooks_CTFPlayerShared_SetRageMeter, false, ModifyRageMeter);
    DHookEnableDetour(DHooks_CTFPlayerShared_CalcChargeCrit, false, CalculateChargeCrit);
    DHookEnableDetour(DHooks_CTFPlayerShared_AddToSpyCloakMeter, false, AddToCloak);
    //DHookEnableDetour(DHooks_CTFPlayerShared_Heal, false, HealPlayer);
    DHookEnableDetour(DHooks_CTFPlayerShared_CanRecieveMedigunChargeEffect, false, CheckIfPlayerCanBeUbered);
    DHookEnableDetour(DHooks_CTFWeaponBaseMelee_OnSwingHit, false, OnMeleeSwingHit);
    DHookEnableDetour(DHooks_CTFMinigun_SharedAttack, false, OnMinigunSharedAttack);
    DHookEnableDetour(CTFWearable_CTFWearable_Break, true, BreakRazorback);
    DHookEnableDetour(DHooks_CTFWearableDemoShield_ShieldBash, false, OnShieldBash);
    DHookEnableDetour(DHooks_CTFAmmoPack_PackTouch, false, CTFAmmoPack_OnAmmoTouch);
    DHookEnableDetour(DHooks_CTFLunchBox_ApplyBiteEffects, false, ApplyBiteEffects);
    DHookEnableDetour(DHooks_CTFLunchBox_DrainAmmo, false, RemoveSandvichAmmo);
    DHookEnableDetour(DHooks_CWeaponMedigun_FindAndHealTargets, false, PreFindAndHealTarget);
    DHookEnableDetour(DHooks_CWeaponMedigun_FindAndHealTargets, true, PostFindAndHealTarget);
    DHookEnableDetour(DHooks_CBaseObject_OnConstructionHit, false, BuildingConstructionHit);
    DHookEnableDetour(DHooks_CBaseObject_GetConstructionMultiplier, true, GetBuildingConstructionMultiplier);
    DHookEnableDetour(DHooks_CBaseObject_CreateAmmoPack, false, CreateBuildingGibs);
    DHookEnableDetour(DHooks_CTFProjectile_Arrow_BuildingHealingArrow, false, PreHealingBoltImpact);
    DHookEnableDetour(DHooks_CTFProjectile_Arrow_BuildingHealingArrow, true, PostHealingBoltImpact);
    DHookEnableDetour(DHooks_CTFGameRules_ApplyOnDamageModifyRules, false, ApplyDamageRules);
    DHookEnableDetour(DHooks_CTFGameRules_ApplyOnDamageModifyRules, true, ApplyDamageRules_Post);

    // SDKCall.
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CAmmoPack::GetPowerupSize");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SDKCall_CAmmoPack_GetPowerupSize = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFPlayer::EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    SDKCall_CTFPlayer_EquipWearable = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFItem::GetItemID");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SDKCall_CTFItem_GetItemID = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CWeaponMedigun::CanAttack");
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    SDKCall_CWeaponMedigun_CanAttack = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBaseObject::DetonateObject");
    SDKCall_CBaseObject_DetonateObject = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBaseObject::GetType");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SDKCall_CBaseObject_GetType = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::TryToPickupBuilding");
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
    SDKCall_CTFPlayer_TryToPickupBuilding = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Raw);
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWeaponBaseGun::GetWeaponSpread");
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    SDKCall_CTFWeaponBaseGun_GetWeaponSpread = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWeaponBaseGun::GetProjectileDamage");
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    SDKCall_CTFWeaponBaseGun_GetProjectileDamage = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWrench::GetConstructionValue");
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    SDKCall_CTFWrench_GetConstructionValue = EndPrepSDKCall();
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CBaseObject::GetReversesBuildingConstructionSpeed");
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    SDKCall_CBaseObject_GetReversesBuildingConstructionSpeed = EndPrepSDKCall();

    // Memory patches.
    /*
    // This code is not accurate in retrospect to Smissmas 2014. You can uncomment this if you wish, but
    // I cannot guarantee that the gamedata is accurate.

    MemoryPatch_ShieldTurnCap = GameConfGetAddress(config, "MemoryPatch_ShieldTurnCap") + view_as<Address>(GameConfGetOffset(config, "MemoryPatch_ShieldTurnCap"));
    MemoryPatch_ShieldTurnCap_OldValue = LoadFromAddress(MemoryPatch_ShieldTurnCap, NumberType_Int32);
    StoreToAddress(MemoryPatch_ShieldTurnCap, AddressOf(MemoryPatch_ShieldTurnCap_NewValue), NumberType_Int32);
    */

    MemoryPatch_NormalScorchShotKnockback = GameConfGetAddress(config, "MemoryPatch_NormalScorchShotKnockback") + view_as<Address>(GameConfGetOffset(config, "MemoryPatch_NormalScorchShotKnockback"));
    MemoryPatch_NormalScorchShotKnockback_oldValue = LoadFromAddress(MemoryPatch_NormalScorchShotKnockback, NumberType_Int32);
    StoreToAddress(MemoryPatch_NormalScorchShotKnockback, AddressOf(MemoryPatch_NormalScorchShotKnockback_NewValue), NumberType_Int32);

    MemoryPatch_DisableDebuffShortenWhilstCloaked = GameConfGetAddress(config, "MemoryPatch_DisableDebuffShortenWhilstCloaked") + view_as<Address>(GameConfGetOffset(config, "MemoryPatch_DisableDebuffShortenWhilstCloaked"));
    MemoryPatch_DisableDebuffShortenWhilstCloaked_oldValue = LoadFromAddress(MemoryPatch_DisableDebuffShortenWhilstCloaked, NumberType_Int32);
    StoreToAddress(MemoryPatch_DisableDebuffShortenWhilstCloaked, AddressOf(MemoryPatch_DisableDebuffShortenWhilstCloaked_NewValue), NumberType_Int32);

    MemoryPatch_FixYourEternalReward = GameConfGetAddress(config, "MemoryPatch_FixYourEternalReward") + view_as<Address>(GameConfGetOffset(config, "MemoryPatch_FixYourEternalReward"));
    MemoryPatch_FixYourEternalReward_NOPCount = GameConfGetOffset(config, "MemoryPatch_FixYourEternalReward_NOPCount");
    for (int i = 0; i < MemoryPatch_FixYourEternalReward_NOPCount; ++i)
    {
        Address index = view_as<Address>(i);
        MemoryPatch_FixYourEternalReward_OldValue[i] = LoadFromAddress(MemoryPatch_FixYourEternalReward + view_as<Address>(index), NumberType_Int8);
        StoreToAddress(MemoryPatch_FixYourEternalReward + index, MemoryPatch_FixYourEternalReward_NewValue[i], NumberType_Int8);
    }

    MemoryPatch_DisguiseIsAlways2Seconds = GameConfGetAddress(config, "MemoryPatch_DisguiseIsAlways2Seconds") + view_as<Address>(GameConfGetOffset(config, "MemoryPatch_DisguiseIsAlways2Seconds"));
    MemoryPatch_DisguiseIsAlways2Seconds_OldValue = LoadFromAddress(MemoryPatch_DisguiseIsAlways2Seconds, NumberType_Int32);
    StoreToAddress(MemoryPatch_DisguiseIsAlways2Seconds, AddressOf(MemoryPatch_DisguiseIsAlways2Seconds_NewValue), NumberType_Int32);

    // Offsets.
    CTFPlayerShared_m_pOuter = view_as<Address>(GameConfGetOffset(config, "CTFPlayerShared::m_pOuter"));
    CGameTrace_m_pEnt = view_as<Address>(GameConfGetOffset(config, "CGameTrace::m_pEnt"));
    CTakeDamageInfo_m_hAttacker = view_as<Address>(40);
    CTakeDamageInfo_m_flDamage = view_as<Address>(48);
    CTakeDamageInfo_m_bitsDamageType = view_as<Address>(60); //view_as<Address>(GameConfGetOffset(config, "CTakeDamageInfo::m_bitsDamageType"));
    //CTakeDamageInfo_m_flDamageBonus = view_as<Address>(84);
    CTakeDamageInfo_m_eCritType = view_as<Address>(100); //view_as<Address>(GameConfGetOffset(config, "CTakeDamageInfo::m_eCritType"));
    CWeaponMedigun_m_bReloadDown = view_as<Address>(FindSendPropInfo("CWeaponMedigun", "m_nChargeResistType") + 11);
    CObjectSentrygun_m_flShieldFadeTime = view_as<Address>(FindSendPropInfo("CObjectSentrygun", "m_nShieldLevel") + 4);
    CObjectBase_m_flHealth = view_as<Address>(FindSendPropInfo("CBaseObject", "m_bHasSapper") - 4);
    CTFPlayer_m_aObjects = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_iClassModelParity") + 72);

    delete config;

    // ConVars.
    tf_scout_hype_mod = FindConVar("tf_scout_hype_mod");
    tf_scout_stunball_base_duration = FindConVar("tf_scout_stunball_base_duration");
    tf_parachute_maxspeed_onfire_z = FindConVar("tf_parachute_maxspeed_onfire_z");
    tf_weapon_minicrits_distance_falloff = FindConVar("tf_weapon_minicrits_distance_falloff");
    tf_weapon_criticals_distance_falloff = FindConVar("tf_weapon_criticals_distance_falloff");
    tf_weapon_minicrits_distance_falloff_original = tf_weapon_minicrits_distance_falloff.BoolValue;
    tf_weapon_criticals_distance_falloff_original = tf_weapon_criticals_distance_falloff.BoolValue;

    notnheavy_gunmettle_reverts_reject_newitems = CreateConVar("notnheavy_gunmettle_reverts_reject_newitems", "1", "Disable the usage of post-Gun Mettle weapons. On by default.", FCVAR_PROTECTED);

    for (int i = 0; i < sizeof(defaultConVars); ++i)
    {
        defaultConVars[i].Variable = FindConVar(defaultConVars[i].Name);
        if (defaultConVars[i].Variable != INVALID_HANDLE)
        {
            if (defaultConVars[i].Type == TF2ConVarType_Int)
                defaultConVars[i].DefaultValue = GetConVarInt(defaultConVars[i].Variable);
            else if (defaultConVars[i].Type == TF2ConVarType_Float)
                defaultConVars[i].DefaultValue = GetConVarFloat(defaultConVars[i].Variable);
        }
    }

    // Hook onto entities.
    for (int i = 0; i < MAX_ENTITY_COUNT; ++i)
    {
        if (IsValidEntity(i))
        {
            char class[MAX_NAME_LENGTH];
            GetEntityClassname(i, class, MAX_NAME_LENGTH);
            OnEntityCreated(i, class);
        }
    }
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
            if (IsPlayerAlive(i))
            {
                StructuriseWeaponList(i);
                RequestFrame(NextFrameApplyViewmodelsToPlayer, i);
            }
        }
    }

    PrintToServer("--------------------------------------------------------\n\"%s\" has loaded.\n--------------------------------------------------------", PLUGIN_NAME);
}

public void OnMapStart()
{
    char tempPath[PLATFORM_MAX_PATH];
    PrecacheSound("weapons\\icicle_melt_01.wav");
    PrecacheSound("items\\gunpickup2.wav");
    PrecacheSound("weapons\\shotgun_worldreload.wav");
    PrecacheSound("weapons\\tf2_backshot_shotty.wav");
    PrecacheSound("sounds\\barret_arm_zap.wav");
    PrecacheSound("player\\pl_fleshbreak.wav");
    for (int i = 1; i <= FLESH_IMPACT_BULLET_COUNT; ++i)
    {
        Format(tempPath, PLATFORM_MAX_PATH, "physics\\flesh\\flesh_impact_bullet%i.wav", i);
        PrecacheSound(tempPath);
    }
    for (int i = 0; i < sizeof(customWeapons); ++i)
    {
        Format(tempPath, PLATFORM_MAX_PATH, "%s.mdl", customWeapons[i].Model);
        customWeapons[i].Cache = PrecacheModel(tempPath);
        customWeapons[i].FullModel = tempPath;
        AddFileToDownloadsTable(tempPath);
        for (int extension = 0; extension < sizeof(modelExtensions); ++extension)
        {
            Format(tempPath, PLATFORM_MAX_PATH, "%s%s", customWeapons[i].Model, modelExtensions[extension]);
            AddFileToDownloadsTable(tempPath);
        }
        for (int extension = 0; extension < sizeof(textureExtensions); ++extension)
        {
            Format(tempPath, PLATFORM_MAX_PATH, "%s%s", customWeapons[i].Texture, textureExtensions[extension]);
            AddFileToDownloadsTable(tempPath);
        }
    }
    for (int i = 0; i < sizeof(armsViewmodels); ++i)
        PrecacheModel(armsViewmodels[i]);
}

public void OnPluginEnd()
{
    if (SpyClassData != Address_Null)
        WriteToValue(SpyClassData + TFPlayerClassData_t_m_flMaxSpeed, 320.00);
    for (int i = 0; i < sizeof(defaultConVars); ++i)
        SetTF2ConVarValue(defaultConVars[i].Name, defaultConVars[i].DefaultValue);
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
            RemoveViewmodelsFromPlayer(i);
    }

    // Memory patches.
    /*
    StoreToAddress(MemoryPatch_ShieldTurnCap, MemoryPatch_ShieldTurnCap_OldValue, NumberType_Int32);
    */
    StoreToAddress(MemoryPatch_NormalScorchShotKnockback, MemoryPatch_NormalScorchShotKnockback_oldValue, NumberType_Int32);
    StoreToAddress(MemoryPatch_DisableDebuffShortenWhilstCloaked, MemoryPatch_DisableDebuffShortenWhilstCloaked_oldValue, NumberType_Int32);
    for (int i = 0; i < MemoryPatch_FixYourEternalReward_NOPCount; ++i)
    {
        Address index = view_as<Address>(i);
        StoreToAddress(MemoryPatch_FixYourEternalReward + index, MemoryPatch_FixYourEternalReward_OldValue[i], NumberType_Int8);
    }
    StoreToAddress(MemoryPatch_DisguiseIsAlways2Seconds, MemoryPatch_DisguiseIsAlways2Seconds_OldValue, NumberType_Int32);
}

//////////////////////////////////////////////////////////////////////////////
// TF2 WEAPON HANDLING                                                      //
//////////////////////////////////////////////////////////////////////////////

public Action TF2Items_OnGiveNamedItem(int client, char[] class, int index, Handle& item)
{
    // TODO for throwables - revert this update:
    // October 6, 2015 Patch (Invasion Update) - Throwables (Jarate, Mad Milk, Flying Guillotine) will now pass through friendly targets at close range. This is the same behavior as rockets and grenades.

    // Prevent handle leaks.
    static Handle newItem = null;
    if (newItem != null)
        delete newItem;
 
    // Create a new item and change global attributes.
    newItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
    TF2Items_SetAttribute(newItem, 0, 773, 1.34); // This weapon deploys 1.34% slower. 0.5s * 1.34 = 0.67s, the same as pre-Tough Break switch speed.
    TF2Items_SetNumAttributes(newItem, 1);
    OriginalTF2ItemsIndex = -1;

    // Scout.
    {
        // Primary. 
        {
            if (index == 220) // Shortstop. TODO: Find a proper way to prevent shove from happening. MRES_Supercede on DHook isn't really the best method it seems.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 76, 1.125); // 12.5% max primary ammo on wearer
                TF2Items_SetAttribute(newItem, 2, 526, 1.2); // 20% bonus healing from all sources
                TF2Items_SetAttribute(newItem, 3, 534, 1.4); // 40% reduction in airblast vulnerability
                TF2Items_SetAttribute(newItem, 4, 535, 1.4); // 40% increase in push force taken from damage

                // Using secondary ammo is handled separately.
                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 448) // Soda Popper.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 793, 0.00); // On Hit: Builds Hype

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 772) // Baby Face's Blaster.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 733, 0.00); // Boost reduced when hit

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 419, 25.00); // Boost reduced on air jumps

                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Secondary.
        {
            // TODO for Crit-a-Cola: don't make it show marked for death symbol for a frame after firing. Play one of the few confusion sounds at end of effect instead of breathing effect too.

            if (index == 773) // Pretty Boy's Pocket Pistol.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 3, 1.00); // -0% clip size
                TF2Items_SetAttribute(newItem, 2, 6, 1.00); // 0% faster firing speed
                TF2Items_SetAttribute(newItem, 3, 16, 0.00); // On Hit: Gain up to +0 health

                // Set new attributes.
                TF2Items_SetAttribute(newItem, 4, 5, 1.25); // -25% slower firing speed

                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 812 || index == 833) // Flying Guillotine. TODO: change animations and sounds.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 437, 65536.00); // 100% critical hit vs stunned players

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
        // Melee.
        {
            // TODO: for stunning with Sandman, fix weapons being invisible after stunning (maybe).
            if (index == 349) // Shit-on-a-Stick.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 794, 1.00); // 0% fire damage resistance while deployed

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 355) // Fan O'War.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 179, 0.00); // Crits whenever it would normally mini-crit

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 1, 0.1); // 90% damage penalty 

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 450) // Atomizer.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 250, 0.00); // Grants Triple Jump while deployed. Melee attacks mini-crit while airborne.
                // Weapon deploy speed is already modified.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 1, 0.8); // -20% damage penalty 
                TF2Items_SetAttribute(newItem, 3, 5, 1.3); // -30% slower firing speed

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 648) // Wrap Assassin.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 0.3); // -70% damage penalty 

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
    }

    // Soldier.
    {
        // Primary.
        {
            if (index == 127) // Direct Hit.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 114, 0.00); // Mini-crits targets launched airborne by explosions, grapple hooks or rocket packs.

                TF2Items_SetNumAttributes(newItem, 2);
                
                // Maybe this is just too specific, but I decided to add a custom script for Direct Hit airborne attacks so that it only works with explosions.
            }
            else if (index == 228 || index == 1085) // Black Box.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 741, 0.00); // On Hit: Gain up to +20 health per attack

                TF2Items_SetNumAttributes(newItem, 2);

                // Healing is dealt with separately; the heal on hit attribute ramp up on damage.
            }
            else if (index == 237) // Rocket Jumper.
            {
                // Apply new attributes.
                TF2Items_SetFlags(newItem, OVERRIDE_ATTRIBUTES | OVERRIDE_ITEM_DEF);
                TF2Items_SetItemIndex(newItem, 18);
                TF2Items_SetAttribute(newItem, 2, 1, 0.00); // -100% damage penalty
                TF2Items_SetAttribute(newItem, 3, 15, 0.00); // No random critical hits
                TF2Items_SetAttribute(newItem, 4, 76, 3.00); // +200% max primary ammo on wearer
                TF2Items_SetAttribute(newItem, 5, 400, 1.00); // Wearer cannot carry the intelligence briefcase or PASS Time JACK

                TF2Items_SetNumAttributes(newItem, 6);

                OriginalTF2ItemsIndex = 237; // i will have not taken this path if it weren't for the bloody client prediction issues with weapon sounds. my best workaround is making the rocket jumper the stock rocket launcher in disguise.
            }
            else if (index == 414) // Liberty Launcher.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 4, 1.00); // +0% clip size

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 441) // Cow Mangler.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 869, 0.00); // Minicrits whenever it would normally crit

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 288, 1.00); // Cannot be crit boosted.

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 730) // Beggar's Bazooka.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 100, 1.00); // -0% explosion radius

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 1104) // Air Strike.
            {
                // Apply old attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 0.75); // -25% damage penalty
                TF2Items_SetAttribute(newItem, 2, 3, 0.75); // -25% clip size
                TF2Items_SetAttribute(newItem, 3, 100, 0.85); // -15% explosion radius
                TF2Items_SetAttribute(newItem, 4, 135, 0.75); // -25% blast damage from rocket jumps

                TF2Items_SetNumAttributes(newItem, 5);
            }
        }
        // Secondary.
        {
            if (index == 354) // Concheror.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 57, 0.00); // +0 health regenerated per second on wearer

                TF2Items_SetNumAttributes(newItem, 2);

                 // Healing is dealt with separately; the heal per second attribute is based upon when user was last damaged, not as a constant.
            }
            else if (index == 444) // Mantreads. TODO: remove the unique particle effect whenever a player performs a "Stomp" attack on another player with the Mantreads.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 329, 1.00); // -0% reduction in airblast vulnerability
                TF2Items_SetAttribute(newItem, 2, 610, 0.00); // 0% increased air control when blast jumping.

                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Melee.
        {
            if (index == 128 || index == 775) // Equalizer and Escape Plan.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 740, 1.00); // -0% less healing from Medic sources

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 236, 1.00); // Blocks healing while in use

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 416) // Market Gardener.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 5, 1.00); // 0% slower firing speed

                TF2Items_SetNumAttributes(newItem, 2);
            }       
        }
    }

    // Pyro. (:D)
    {
        // Primary.
        {
            if (StrEqual(class, "tf_weapon_flamethrower")) // Stats for all flamethrowers. TODO: Figure out what the hell I'm going to do with flame mechanics, adjust flame damage, remove flame density, replace flame visuals.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 783, 0.00); // Extinguishing teammates restores 0 health

                TF2Items_SetNumAttributes(newItem, 2);
            }

            if (index == 215) // Degreaser.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 2, 547, 1.00); // This weapon deloys 0% faster
                TF2Items_SetAttribute(newItem, 3, 199, 1.00); // This weapon holsters 0% faster
                TF2Items_SetAttribute(newItem, 4, 170, 1.00); // +0% airblast cost

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 5, 178, 0.35); // 65% faster weapon switch
                TF2Items_SetAttribute(newItem, 6, 1, 0.9); // 10% damage penalty 
                TF2Items_SetAttribute(newItem, 7, 72, 0.5); // 25% afterburn damage penalty.

                TF2Items_SetNumAttributes(newItem, 8);
            }
            else if (index == 594) // Phlogistinator. TODO:
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 1, 0.9); // 10% damage penalty
                
                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Secondary.
        {
            // TODO: change self-damage and velocity with knockback from Detonator/Scorch Shot.
            if (index == 351) // Detonator.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 1.00); // 0% damage penalty
                TF2Items_SetAttribute(newItem, 2, 209, 0.00); // 0% minicrits vs burning players

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 207, 1.25); // +0% damage to self
                
                // Mini-crits on direct hits are handled separately.
                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 595) // Manmelter.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 783, 0.00); // Extinguishing teammates restores 0 health.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 5, 1.20); // 20% slower firing speed
               
                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 740) // Scorch Shot.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 59, 1.00); // 0% self damage force
                TF2Items_SetAttribute(newItem, 2, 209, 0.00); // 0% minicrits vs burning players

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 1, 0.50); // 50% damage penalty

                TF2Items_SetNumAttributes(newItem, 4);
            }
        }
        // Melee.
        {
            if (index == 38 || index == 1000 || index == 457) // Axtinguisher and Postal Pummeler.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 1.00); // 0% damage penalty
                TF2Items_SetAttribute(newItem, 2, 772, 1.00); // This weapon holsters 0% slower
                TF2Items_SetAttribute(newItem, 3, 2067, 0.00); // Mini-crits burning targets and extinguishes them. Damage increases based on remaining duration of afterburn. Killing blows on burning players grant a speed boost.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 4, 21, 0.5); // 50% damage vs damage vs non-burning players
                TF2Items_SetAttribute(newItem, 5, 638, 1.00); // 100% critical hits burning players from behind. Mini-crits burning players from the front.

                TF2Items_SetNumAttributes(newItem, 6);
            }
            else if (index == 214) // Powerjack.
            {
                // Apply new attributes.
                //TF2Items_SetAttribute(newItem, 1, 180, 75.00); // +75 health restored on kill (doesn't overheal :c)
                TF2Items_SetAttribute(newItem, 1, 180, 0.00); // +0 health restored on kill

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
    }

    // Demoman.
    {
        // Primary.
        {
            if (index == 308) // Loch-n-Load.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 137, 1.00); // +0% damage vs buildings

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 2, 1.20); // +20% damage bonus

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 405 || index == 608) // Ali Baba's Wee Booties or Bootlegger.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 788, 1.00); // +0% faster move speed on wearer (shield required)
                TF2Items_SetAttribute(newItem, 2, 2034, 0.00); // Melee kills refill 0% of your charge meter.

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 996) // Loose Cannon. TODO: increase knockback strength.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 103, 1.50); // +50% projectile speed

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 1151) // Iron Bomber.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 787, 1.00); // -0% fuse time on grenades

                // Apply new atttributes.
                TF2Items_SetAttribute(newItem, 2, 100, 0.80); // -20% explosion radius
                TF2Items_SetAttribute(newItem, 3, 684, 0.90); // -10% damage on grenades that explode on timer

                TF2Items_SetNumAttributes(newItem, 4);
            }
        }
        // Secondary.
        {
            // TODO for all shields: Also remove resistance sounds.

            if (index == 131) // Chargin' Targe.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 64, 0.60); // +40% explosive damage resistance on wearer
                TF2Items_SetAttribute(newItem, 2, 527, 1.00); // Immune to the effects of afterburn.
                
                // Afterburn immunity is dealt with in my old flamethrower mechanics plugin.
                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 265) // Sticky Jumper.
            {
                // Apply new attributes.
                TF2Items_SetFlags(newItem, OVERRIDE_ATTRIBUTES | OVERRIDE_ITEM_DEF);
                TF2Items_SetItemIndex(newItem, 20);
                TF2Items_SetAttribute(newItem, 2, 1, 0.00); // -100% damage penalty
                TF2Items_SetAttribute(newItem, 3, 15, 0.00); // No random critical hits
                TF2Items_SetAttribute(newItem, 4, 78, 3.00); // +200% max primary ammo on wearer
                TF2Items_SetAttribute(newItem, 5, 89, -6.00); // -6 max pipebombs out
                TF2Items_SetAttribute(newItem, 6, 280, 14.00); // override_projectile_type
                TF2Items_SetAttribute(newItem, 7, 400, 1.00); // Wearer cannot carry the intelligence briefcase or PASS Time JACK

                TF2Items_SetNumAttributes(newItem, 8);

                OriginalTF2ItemsIndex = 265; // h
            }
            else if (index == 406) // Splendid Screen.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 249, 1.00); // +0% increase in charge recharge rate

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 64, 0.85); // +15% explosive damage resistance on wearer

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 1099) // Tide Turner.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 676, 0.00); // Taking damage while shield charging reduces remaining charging time. (This also allows for crits upon 60% depletion again.)
                TF2Items_SetAttribute(newItem, 2, 2034, 0.00); // Melee kills refill 0% of your charge meter.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 60, 0.75); // +25% fire damage resistance on wearer
                TF2Items_SetAttribute(newItem, 4, 64, 0.75); // +25% explosive damage resistance on wearer

                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 1150) // Quickiebomb Launcher.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 727, 1.00); // Up to +0% damage based on charge

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 3, 0.75); // -25% clip size
                TF2Items_SetAttribute(newItem, 3, 669, 4.00); // Stickybombs fizzle 4 seconds after landing
                TF2Items_SetAttribute(newItem, 4, 670, 0.50); // Max charge time decreased by 50%

                TF2Items_SetNumAttributes(newItem, 5);
            }
        }
        // Melee.
        {
            if (index == 132 || index == 1082 || index == 266 || index == 482) // Eyelander, Horseless Headless Horsemann's Headtaker and Nessie's Nine Iron.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 781, 0.00); // This Weapon has a large melee range and deploys and holsters slower

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 264, 1.50); // 50% increased melee attack range. 48 HU -> 72 HU

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 172) // Scotsman's Skullcutter.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 781, 0.00); // This Weapon has a large melee range and deploys and holsters slower

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 327) // Claidheamh Mòr.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 412, 1.00); // 0% damage vulnerability on wearer
                TF2Items_SetAttribute(newItem, 2, 781, 0.00); // This Weapon has a large melee range and deploys and holsters slower
                TF2Items_SetAttribute(newItem, 3, 2034, 0.00); // Melee kills refill 0% of your charge meter.

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 307) // Ullapool Caber.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 5, 1.00); // 0% slower firing speed
                TF2Items_SetAttribute(newItem, 2, 773, 1.00); // This weapon deploys 0% slower

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 404) // Persian Persuader.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 77, 1.00); // -0% max primary ammo on wearer
                TF2Items_SetAttribute(newItem, 2, 79, 1.00); // -0% max secondary ammo on wearer
                TF2Items_SetAttribute(newItem, 3, 778, 0.00); // Melee hits refill 0% of your charge meter
                TF2Items_SetAttribute(newItem, 4, 781, 0.00); // This Weapon has a large melee range and deploys and holsters slower
                TF2Items_SetAttribute(newItem, 5, 782, 0.00); // Ammo boxes collected also give Charge

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 6, 249, 2.00); // +100% increase in charge recharge rate
                TF2Items_SetAttribute(newItem, 7, 258, 1.00); // Ammo collected from ammo boxes becomes health. (Doesn't work :c)

                TF2Items_SetNumAttributes(newItem, 8);
            }
        }
    }

    // Heavy.
    {
        // Primary. TODO: make it so damage/accuracy penalties are removed 1s after firing and are present again when you stop firing, not when you wind up/wind down.
        {
            if (index == 41) // Natascha. TODO: remove stunt falloff.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 32, 0.00); // On Hit: 0% chance to slow target
                TF2Items_SetAttribute(newItem, 2, 738, 1.00); // 0% damage resistance when below 50% health and spun up

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 76, 1.50); // 50% max primary ammo on wearer

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 312) // Brass Beast.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 738, 1.00); // 0% damage resistance when below 50% health and spun up

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 424) // Tomislav.
            {
                // Remove old attributes. (RIP weapon).
                TF2Items_SetAttribute(newItem, 1, 106, 1.00); // 0% more accurate

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 87, 0.90); // 10% faster spin up time

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 811 || index == 832) // Huo-Long Heater. TODO: change pulse damage from ring of fire to 15 instead of 12 and set ammo drain to 6 per second.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 1.00); // -0% damage penalty
                TF2Items_SetAttribute(newItem, 2, 795, 1.00); // 0% damage bonus vs burning players

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 431, 6.00); // Consumes an additional 6 ammo per second while spun up

                TF2Items_SetNumAttributes(newItem, 4);
            }
        }
        // Secondary.
        {
            // TODO for Dalokohs bar: remove the UI and see if there's anything you can do about client prediction ding.
            if (index == 425) // Family Business.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 6, 1.00); // 0% faster firing speed

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
        // Melee.
        {
            if (index == 239 || index == 1084 || index == 1184 || index == 1100) // Gloves of Running Urgently and Bread Bite.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 772, 1.00); // This weapon holsters 0% slower
                TF2Items_SetAttribute(newItem, 2, 855, 0.00); // Maximum health is drained while item is active

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 1, 0.75); // -25% damage penalty
                TF2Items_SetAttribute(newItem, 4, 414, 3.00); // You are Marked-For-Death while active, and for short period after switching weapons

                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 310) // Warrior's Spirit.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 180, 0.00); // +0 health restored on kill
                TF2Items_SetAttribute(newItem, 2, 412, 1.00); // +0% damage vulnerability on wearer

                // Health is dealt with separately.

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 331) // Fists of Steel.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 772, 1.00); // This weapon holsters 0% faster
                TF2Items_SetAttribute(newItem, 2, 853, 1.00); // -0% maximum overheal on wearer
                TF2Items_SetAttribute(newItem, 3, 854, 1.00); // -40% health from healers on wearer

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 4, 177, 1.20); // 20% longer weapon switch

                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 426) // Eviction Notice.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 737, 0.00); // On Hit: Gain a speed boost
                TF2Items_SetAttribute(newItem, 2, 851, 1.00); // +0% faster move speed on wearer
                TF2Items_SetAttribute(newItem, 3, 855, 0.00); // Maximum health is drained while item is active

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 4, 6, 0.50); // +50% faster firing speed

                TF2Items_SetNumAttributes(newItem, 5);
            }
        }
    }

    // Engineer.
    {
        // Primary.
        {
            if (index == 527) // Widowmaker.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 789, 1.00); // 0% increased damage to your sentry's target

                TF2Items_SetNumAttributes(newItem, 2);
            }
            // TODO for Pomson:
            // - make projectile invisible if going through buildings
            else if (index == 997)
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 469, 130.00); // Alt-Fire: Use 130 metal to pick up your targeted building from long range
                TF2Items_SetAttribute(newItem, 2, 474, 74.00); // Fires a special bolt that can repair friendly buildings

                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Secondary.
        {
            // TODO for Short Circuit: add custom sounds.
        }
        // Melee.
        {
            if (index == 329) // Jag.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 6, 1.00); // +0% faster firing speed
                TF2Items_SetAttribute(newItem, 2, 95, 1.00); // -0% slower repair rate
                TF2Items_SetAttribute(newItem, 3, 775, 1.00); // -0% damage penalty vs buildings

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 589) // Eureka Effect.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 93, 1.00); // Construction hit speed boost decreased by 0%
                TF2Items_SetAttribute(newItem, 2, 732, 1.00); // 0% less metal from pickups and dispensers
                TF2Items_SetAttribute(newItem, 3, 790, 1.00); // -0% metal cost when constructing or upgrading teleporters

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 4, 95, 0.50); // 50% slower repair rate
                TF2Items_SetAttribute(newItem, 5, 2043, 0.50); // 50% slower upgrade rate

                TF2Items_SetNumAttributes(newItem, 6);
            }
        }
    }

    // Medic.
    {
        // Primary.
        {
            // TODO: make crossbow use huntsman shoot sound for shooting.
            if (index == 412) // Overdose.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 1, 1.00); // 0% damage penalty
                TF2Items_SetAttribute(newItem, 2, 792, 1.10); // mult_player_movespeed_resource_level

                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Secondary.
        {
            if (index == 411) // Quick-Fix.
            {
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 1, 10, 1.25); // +25% ÜberCharge rate

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 998) // Vaccinator. 
            {
                
                // TODO - revert these updates:
                /*
                Gun Mettle:
                - Resistances make a metal clashing sound.
                */

                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 739, 1.00); // -0% ÜberCharge rate on Overhealed patients
                
                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 10, 1.50); // +50% ÜberCharge rate

                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Melee.
        {
            if (index == 173) // Vita-Saw. TODO: Remove UI for organs.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 811, 0.00); // Collect the organs of people you hit

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 188, 20.00); // On death up to 20% of your stored ÜberCharge is retained (doesn't work?)

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 413) // Solemn Vow.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 5, 1.00); // 0% slower firing speed

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
    }

    // Sniper.
    {
        // Primary.
        {
            if (index == 230) // Sydney Sleeper. TODO: apply Jarate effect when applying Jarate on target.
            {
                 // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 175, 0.00); // On Scoped Hit: Apply Jarate for 2 to %s1 seconds based on charge level. Nature's Call: Scoped headshots always mini-crits and reduce the remaining cooldown of Jarate by 1 second.

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
        // Secondary.
        {
            if (index == 58 || index == 1083 || index == 554 || index == 1105) // Jarate and Self-Aware Beauty Mark.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 784, 0.00); // Extinguishing teammates reduces cooldown by 0%

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 57) // Razorback.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 800, 1.00); // -0% maximum overheal on wearer

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 231) // if you use this you are declaring to the server that you are a dickhead
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 60, 1.00); // +0% fire damage resistance on wearer
                TF2Items_SetAttribute(newItem, 2, 527, 0.00); // Immune to the effects of afterburn.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 65, 1.20); // 20% explosive damage vulnerability on wearer
                TF2Items_SetAttribute(newItem, 4, 66, 0.85); // 15% bullet damage resistance on wearer

                // Health is dealt with separately.
                TF2Items_SetNumAttributes(newItem, 5);
            }
            else if (index == 642) // Cozy Camper.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 57, 0.00); // +0 health regenerated per second on wearer

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 2, 412, 1.20); // 20% damage vulnerability on wearer

                // Health is dealt with separately; because of this attribute being based around last time you took damage, it doesn't even give 1 HP per second on initially taking damage.
                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 751) // Cleaner's Carbine. TODO: remove UI for crikey meter.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 779, 0.00); // Secondary fire when charged grants mini-crits for 0 seconds.
                TF2Items_SetAttribute(newItem, 2, 780, 0.00); // Dealing damage fills charge meter.

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 5, 1.35); // -35% slower firing speed
                TF2Items_SetAttribute(newItem, 4, 613, 8.00); // On Kill: Gain Mini-crits for 8 seconds.

                TF2Items_SetNumAttributes(newItem, 5);
            }
        }
        // Melee.
        {
            if (index == 232) // Bushwacka.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 412, 1.00); // 0% damage vulnerability on wearer

                TF2Items_SetNumAttributes(newItem, 2);
            }
        }
    }

    // Spy.
    {
        // Primary.
        {
            if (index == 61 || index == 1006) // Ambassador.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 868, 0.00); // Critical damage is affected by range

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 460) // Enforcer.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 410, 1.00); // 0% damage bonus whle disguised
                TF2Items_SetAttribute(newItem, 2, 797, 0.00); // Attacks pierce damage resistance effects and bonuses

                // Damage while undisguised is handled separately.
                TF2Items_SetNumAttributes(newItem, 3);
            }
        }
        // Melee.
        {
            if (index == 225 || index == 574) // Your Eternal Reward and Wanga Prick.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 34, 1.00); // +0% cloak drain rate
                TF2Items_SetAttribute(newItem, 2, 816, 0.00); // Normal disguises require (and consume) a full cloak meter

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 155, 1.00); // Wearer cannot disguise

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 356) // Conniver's Kunai.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 125, -65.00); // -0 max health on wearer (so this works on the Kunai but not other weapons? need this in order to get health drain to properly work anyway)
                TF2Items_SetAttribute(newItem, 2, 217, 0.00);

                TF2Items_SetNumAttributes(newItem, 3);
            }
            else if (index == 461) // Big Earner. (lol rip in pepperoni)
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 736, 0.00); // Gain a speed boost on kill

                TF2Items_SetNumAttributes(newItem, 2);
            }
            else if (index == 649) // Spy-cicle.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 361, 0.00); // On Hit by Fire: Fireproof for 1 second and Afterburn immunity for 0 seconds (might be worth just using this but checking if fire immunity is present, then overwriting fire immunity condiiton.)
                TF2Items_SetAttribute(newItem, 2, 359, 0.00); // Melts in fire, regenerates in 0 seconds and by picking up ammo

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 156, 1.00); // Silent Killer: No attack noise from backstabs

                // Weapon melting and fire immmunity is handled separately.
                TF2Items_SetNumAttributes(newItem, 4);
            }
        }
        // Secondary PDA.
        {
            if (index == 60) // Cloak and Dagger.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 728, 0.00); // No cloak meter from ammo boxes when invisible
                TF2Items_SetAttribute(newItem, 2, 729, 1.00); // -0% cloak meter from ammo boxes

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 3, 810, 1.00); // mod_cloak_no_regen_from_items (Attrib_NoCloakFromAmmo)

                TF2Items_SetNumAttributes(newItem, 4);
            }
            else if (index == 59) // Dead Ringer.
            {
                // Remove old attributes.
                TF2Items_SetAttribute(newItem, 1, 83, 1.00); // +0% cloak duration
                TF2Items_SetAttribute(newItem, 2, 726, 0.00); // -0% cloak meter when Feign Death is activated
                TF2Items_SetAttribute(newItem, 3, 810, 0.00); // mod_cloak_no_regen_from_items (Attrib_NoCloakFromAmmo)

                // Apply new attributes.
                TF2Items_SetAttribute(newItem, 4, 35, 1.80); // +80% cloak regen rate
                TF2Items_SetAttribute(newItem, 5, 82, 1.60); // -40% cloak duration

                TF2Items_SetNumAttributes(newItem, 6);
            }
        }
    }

    // Multi-class.
    {
        if (index == 357) // Half-Zatoichi.
        {
            // Remove old attributes.
            TF2Items_SetAttribute(newItem, 1, 15, 1.00); // No random critical hits
            TF2Items_SetAttribute(newItem, 2, 220, 0.00); // Gain 0% of base health on kill
            TF2Items_SetAttribute(newItem, 3, 226, 0.00); // Honorbound: Once drawn sheathing deals 50 damage to yourself unless it kills.
            TF2Items_SetAttribute(newItem, 4, 781, 0.00); // This Weapon has a large melee range and deploys and holsters slower

            TF2Items_SetNumAttributes(newItem, 5);

            // Healing is handled by a custom script: the gain percentage of base health attribute overheals. Honorbound is also handled separately.
        }
        else if (index == 415) // Reserve Shooter.
        {
            // Remove old attributes.
            TF2Items_SetAttribute(newItem, 1, 547, 1.00); // This weapon deloys 0% faster
            TF2Items_SetAttribute(newItem, 2, 199, 1.00); // This weapon holsters 0% faster
            TF2Items_SetAttribute(newItem, 3, 114, 0.00); // Mini-crits targets launched airborne by explosions, grapple hooks or rocket packs

            // Set new attributes.
            TF2Items_SetAttribute(newItem, 4, 178, 0.85); // 15% faster weapon switch
            
            TF2Items_SetNumAttributes(newItem, 5);

            // Mini-crit attribute is handled by ClientDamaged: all airborne targets should be mini-critted.
        }
        else if (index == 1153) // Panic Attack.
        {
            // Remove old attributes.
            TF2Items_SetAttribute(newItem, 1, 1, 1.00); // 0% damage penalty
            TF2Items_SetAttribute(newItem, 2, 45, 1.00); // +0% bullets per shot
            TF2Items_SetAttribute(newItem, 3, 547, 1.00); // This weapon deploys 0% faster
            TF2Items_SetAttribute(newItem, 4, 808, 0.00); // Successive shots become less accurate
            TF2Items_SetAttribute(newItem, 5, 809, 0.00); // Fires a wide, fixed shot pattern

            // Apply new attributes.
            TF2Items_SetAttribute(newItem, 6, 97, 0.67); // 33% faster reload time
            TF2Items_SetAttribute(newItem, 7, 394, 0.85); // 15% faster firing speed
            TF2Items_SetAttribute(newItem, 8, 424, 0.66); // -34% clip size
            TF2Items_SetAttribute(newItem, 9, 651, 0.50); // Fire rate increases as health decreases.
            TF2Items_SetAttribute(newItem, 10, 708, 1.00); // Hold fire to load up to 4 shells
            TF2Items_SetAttribute(newItem, 11, 709, 2.5); // Weapon spread increases as health decreases.
            TF2Items_SetAttribute(newItem, 12, 710, 1.00); // Attrib_AutoFiresFullClipNegative

            TF2Items_SetNumAttributes(newItem, 13);
        }
    }

    // Disallowed weapons - anything that was not available before Gun Mettle.
    if (GetConVarInt(notnheavy_gunmettle_reverts_reject_newitems))
    {
        for (int i = 0; i < sizeof(blockedWeapons); ++i)
        {
            if (index == blockedWeapons[i].Index)
            {
                PrintToChat(client, "You cannot use the %s.", blockedWeapons[i].Name);
                return Plugin_Handled;
            }
        }
    }

    item = newItem;
    return Plugin_Changed;
}

int DoesPlayerHaveItem(int player, int index)
{
    if (!IsClientInGame(player))
        return 0;
    for (int i = 0; i < MAX_WEAPON_COUNT; ++i)
    {
        int entity = allPlayers[player].Weapons[i];
        if (GetWeaponIndex(entity) == index)
            return entity;
    }
    return 0;
}

int DoesPlayerHaveItems(int player, int[] indexes, int length)
{
    for (int i = 0; i < length; ++i)
    {
        int value = DoesPlayerHaveItem(player, indexes[i]);
        if (value)
            return value;
    }
    return 0;
}

int DoesPlayerHaveItemByClass(int player, char[] class)
{
    if (!IsClientInGame(player))
        return 0;
    for (int i = 0; i < MAX_WEAPON_COUNT; ++i)
    {
        int entity = allPlayers[player].Weapons[i];
        if (IsValidEntity(entity) && StrEqual(allEntities[entity].Class, class))
            return entity;
    }
    return 0;
}

void SetWeaponAmmoReserve(int entity, int ammo) 
{
	SetEntProp(allEntities[entity].Owner, Prop_Send, "m_iAmmo", ammo, 4, GetEntProp(entity, Prop_Send, "m_iPrimaryAmmoType"));
}

int GetWeaponAmmoReserve(int entity, int ammoType = -1)
{
    if (ammoType == -1)
        ammoType = GetEntProp(entity, Prop_Send, "m_iPrimaryAmmoType");
    return GetEntProp(allEntities[entity].Owner, Prop_Send, "m_iAmmo", 4, ammoType);
}

void RegisterToWeaponList(int client, int entity)
{
    allEntities[entity].Owner = client;
    for (int i = 0; i < MAX_WEAPON_COUNT; ++i)
    {
        if (allPlayers[client].Weapons[i] == 0 && allPlayers[client].Weapons[i] != entity)
        {
            allPlayers[client].Weapons[i] = entity;
            break;
        }
    }
}

void StructuriseWeaponList(int client)
{
    // Reset weapon structure.
    for (int i = 0; i < MAX_WEAPON_COUNT; ++i)
        allPlayers[client].Weapons[i] = 0;

    // Iterate through weapons.
    for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Item2; ++i)
    {
        int weapon = GetPlayerWeaponSlot(client, i);
        if (weapon != -1)
            RegisterToWeaponList(client, weapon);
    }

    // Iterate through wearables.
    Address m_hMyWearables = GetEntityAddress(client) + view_as<Address>(FindSendPropInfo("CTFPlayer", "m_hMyWearables"));
    for (int i = 0, size = Dereference(m_hMyWearables + view_as<Address>(12)); i < size; ++i)
    {
        int entity = LoadEntityHandleFromAddress(view_as<Address>(Dereference(m_hMyWearables) + i * 4));
        RegisterToWeaponList(client, entity);
    }
}

//////////////////////////////////////////////////////////////////////////////
// OBJECTS                                                                  //
//////////////////////////////////////////////////////////////////////////////

bool IsDisposableBuilding(int obj)
{
    return view_as<bool>(GetEntProp(obj, Prop_Send, "m_bDisposableBuilding"));
}

int GetObjectMode(int obj)
{
    return GetEntProp(obj, Prop_Send, "m_iObjectMode");
}

int GetObjectCount(int client)
{
    return Dereference(GetEntityAddress(client) + CTFPlayer_m_aObjects + view_as<Address>(12));
}

int GetObject(int client, int index)
{
    return LoadEntityHandleFromAddress(Dereference(GetEntityAddress(client) + CTFPlayer_m_aObjects) + index * 4);
}

int GetObjectOfType(int client, int iObjectType, int iObjectMode)
{
    int iNumObjects = GetObjectCount(client);
    for (int i = 0; i < iNumObjects; ++i)
    {
        int pObj = GetObject(client, i);
        if (pObj == -1)
            continue;

        if (SDKCall(SDKCall_CBaseObject_GetType, pObj) != iObjectType)
            continue;

        if (GetObjectMode(pObj) != iObjectMode)
            continue;
        
        if (IsDisposableBuilding(pObj))
            continue;

        return pObj;
    }
    return -1;
}

//////////////////////////////////////////////////////////////////////////////
// WEAPON FUNCTIONALITY                                                     //
//////////////////////////////////////////////////////////////////////////////

int GetWeaponIndex(int weapon)
{
    if (!IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
        return -1;
    for (int i = 0; i < sizeof(customWeapons); ++i)
    {
        if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex") && GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") == customWeapons[i].Cache) // In case the plugin has been reloaded.
            return customWeapons[i].ItemDefinitionIndex;
    }
    return allEntities[weapon].OriginalTF2ItemsIndex != -1 ? allEntities[weapon].OriginalTF2ItemsIndex : GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
}

void GetAbsOrigin(int entity, float absOrigin[3], bool center = true)
{
    // Create vectors.
    float mins[3];
    float maxs[3];

    // Get the absolute origin of the victim.
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", absOrigin);
    if (center)
    {
        GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
        GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
        absOrigin[0] += (mins[0] + maxs[0]) * 0.5;
        absOrigin[1] += (mins[1] + maxs[1]) * 0.5;
        absOrigin[2] += (mins[2] + maxs[2]) * 0.5;
    }
}

float ApplyRadiusDamage(int victim, float damageposition[3], float radius, float damage, float rampup, float falloff, bool center = true)
{
    // Create vectors.
    float absOrigin[3];
    float vectorDistance[3];
    GetAbsOrigin(victim, absOrigin, center);

    // Calculate the damage.
    SubtractVectors(damageposition, absOrigin, vectorDistance);
    return RemapValClamped(GetVectorLength(vectorDistance), 0.00, radius, damage * rampup, damage * falloff);
}

void DestroyAllBuildings(int client)
{
    // TODO: REVISIT
    /*
    for (any i = OBJ_DISPENSER; i < OBJ_LAST; ++i)
    {
        int building = GetObjectOfType(client, i, 0); // SDKCall(SDKCall_CTFPlayer_GetObjectOfType, client, i, 0);
        if (i == OBJ_TELEPORTER) // Destroy the exit as well.
        {
            int exitTeleporter = GetObjectOfType(client, i, 1); // SDKCall(SDKCall_CTFPlayer_GetObjectOfType, client, i, 1);
            if (IsValidEntity(exitTeleporter))
                SDKCall(SDKCall_CBaseObject_DetonateObject, exitTeleporter);
        }
        if (IsValidEntity(building))
            SDKCall(SDKCall_CBaseObject_DetonateObject, building);
    }
    */
}

float GetBuildingConstructionMultiplier_NoHook(int entity)
{
    // Construction hit boosts are now mulitplicative again, rather than additive.
    if (SDKCall(SDKCall_CBaseObject_GetReversesBuildingConstructionSpeed, entity)) // Is the building being sapped by the Red Tape Recorder?
        return -1.0;
    float multiplier = 1.0;

    // All construction boosts.
    for (int i = 1; i <= MAXPLAYERS; ++i)
    {
        if (allEntities[entity].ConstructionBoostExpiryTimes[i] < GetGameTime())
            allEntities[entity].ConstructionBoostExpiryTimes[i] = -1.0;
        else if (allEntities[entity].ConstructionBoostExpiryTimes[i] > 0)
            multiplier *= allEntities[entity].ConstructionBoosts[i];
    }

    // Increase the speed if the building is being redeployed or if it is a mini sentry.
    multiplier += GetEntProp(entity, Prop_Send, "m_bCarryDeploy") ? 2.0 : 0.0;
    multiplier += GetEntProp(entity, Prop_Send, "m_bMiniBuilding") ? 3.0 : 0.0;
    return multiplier;
}

int GetFeignBuffsEnd(int client)
{
    return allPlayers[client].TicksSinceFeignReady + RoundFloat(TICK_RATE * 6.5) - RoundFloat(allPlayers[client].DamageTakenDuringFeign * 1.1);
}

//////////////////////////////////////////////////////////////////////////////
// VIEWMODELS                                                               //
//////////////////////////////////////////////////////////////////////////////

int CreateWearable(bool createViewmodel = false)
{
    int wearable = CreateEntityByName(createViewmodel ? "tf_wearable_vm" : "tf_wearable");
    SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", 0xFFFF);
    DispatchSpawn(wearable);
    return wearable;
}
void ApplyViewmodelsToPlayer(int client)
{
    RemoveViewmodelsFromPlayer(client);
    allPlayers[client].InactiveDuringTaunt = false;

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(weapon))
        return;
    
    int index = GetWeaponIndex(weapon);
    for (int i = 0; i < sizeof(customWeapons); ++i)
    {
        if (index == customWeapons[i].ItemDefinitionIndex)
        {
            // Create the new worldmodel.
            int worldmodel = CreateWearable();
            SetEntProp(worldmodel, Prop_Send, "m_bValidatedAttachedEntity", true); // JIOFSDIOJSPFKFDIPOOFIKPASLJAFMIOFSAJOFASJOFSJPISFAJKPFASD
            SetEntityModel(worldmodel, customWeapons[i].FullModel);
            SDKCall(SDKCall_CTFPlayer_EquipWearable, client, worldmodel);
            allPlayers[client].CurrentWorldmodel = worldmodel;

            // Create the new viewmodel.
            int viewmodel = CreateWearable(true);
            SetEntityModel(viewmodel, customWeapons[i].FullModel);
            SDKCall(SDKCall_CTFPlayer_EquipWearable, client, viewmodel);
            allPlayers[client].CurrentViewmodel = viewmodel;

            // Create the new arms viewmodel.
            char armsViewmodelPath[PLATFORM_MAX_PATH];
            GetArmsViewmodel(client, armsViewmodelPath, sizeof(armsViewmodelPath));

            int armsViewmodel = CreateWearable(true);
            SetEntityModel(armsViewmodel, armsViewmodelPath);
            SDKCall(SDKCall_CTFPlayer_EquipWearable, client, armsViewmodel);
            allPlayers[client].CurrentArmsViewmodel = armsViewmodel;

            // Make the actual viewmodel and actual worldmodel invisible.
            int oldViewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
            SetEntProp(oldViewmodel, Prop_Send, "m_fEffects", EF_NODRAW);
            SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
            SetEntityRenderColor(weapon, 0, 0, 0, 0);
            break;
        }
    }

    allPlayers[client].UsingCustomModels = true;
}
void RemoveViewmodelsFromPlayer(int client)
{
    RemoveWearableIfExists(client, allPlayers[client].CurrentViewmodel);
    RemoveWearableIfExists(client, allPlayers[client].CurrentArmsViewmodel);
    RemoveWearableIfExists(client, allPlayers[client].CurrentWorldmodel);

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (activeWeapon != -1)
    {
        SetEntityRenderMode(activeWeapon, RENDER_NORMAL);
        SetEntityRenderColor(activeWeapon, 255, 255, 255, 255);
    }
    int viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if (viewmodel != -1)
        SetEntProp(viewmodel, Prop_Send, "m_fEffects", 0);

    allPlayers[client].UsingCustomModels = false;
}
void RemoveWearableIfExists(int client, int entity)
{
    if (IsValidEntity(entity))
        TF2_RemoveWearable(client, entity);
}
void GetArmsViewmodel(int client, char[] buffer, int length)
{
    if (DoesPlayerHaveItem(client, 142)) // Gunslinger.
        strcopy(buffer, length, armsViewmodels[0]);
    strcopy(buffer, length, armsViewmodels[TF2_GetPlayerClass(client)]);
}

public void TF2_OnConditionAdded(int client, TFCond condition) // No condition management is done in here, this is only to get around some bugs with the world mode.
{
    // Check if the custom models should be removed.
    if (condition != TFCond_Taunting)
        return;
    
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int index = GetWeaponIndex(weapon);
    int taunt = GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex");
    bool ShowWhileTaunting;
    for (int i = 0; i < sizeof(customWeapons); ++i)
    {
        if (index == customWeapons[i].ItemDefinitionIndex)
            ShowWhileTaunting = customWeapons[i].ShowWhileTaunting;
    }
    if ((taunt < 0 && ShowWhileTaunting) || !allPlayers[client].UsingCustomModels)
        return;

    allPlayers[client].InactiveDuringTaunt = true;
    RemoveViewmodelsFromPlayer(client);
}
public void TF2_OnConditionRemoved(int client, TFCond condition)
{
    if (condition != TFCond_Taunting)
        return;
    if (!allPlayers[client].UsingCustomModels)
        ApplyViewmodelsToPlayer(client);
}

//////////////////////////////////////////////////////////////////////////////
// EVENTS                                                                   //
//////////////////////////////////////////////////////////////////////////////

public void ClientSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    allPlayers[client].FramesSinceLastSwitch = 0;
    if (DoesPlayerHaveItem(client, 173) && allPlayers[client].HadVitaSawEquipped) // Give up to 20% Uber back with the Vita-Saw.
        SetEntPropFloat(DoesPlayerHaveItemByClass(client, "tf_weapon_medigun"), Prop_Send, "m_flChargeLevel", min(0.2, allPlayers[client].CurrentUber));
    else
        allPlayers[client].CurrentUber = 0.00;
}

public Action ClientDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Set up variables.
    int client = GetClientOfUserId(event.GetInt("userid"));
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    // Make the player's sentry shield disappear in only one second.
    if (IsValidEntity(weapon))
    {
        int index = GetWeaponIndex(weapon);
        if (index == 140 || index == 1086 || index == 30668) // Make the player's sentry shield disappear in only one second.
        {
            int sentry = GetObjectOfType(client, view_as<int>(OBJ_SENTRYGUN), 0); // SDKCall(SDKCall_CTFPlayer_GetObjectOfType, client, OBJ_SENTRYGUN, 0);
            if (IsValidEntity(sentry))
            {
                Address m_flShieldFadeTime = GetEntityAddress(sentry) + CObjectSentrygun_m_flShieldFadeTime;
                if (Dereference(m_flShieldFadeTime) > GetGameTime())
                    allEntities[sentry].ShieldFadeTime = GetGameTime() + 1.0;
            }
        }
    }

    // Show that the player was killed by an Ambassador headshot.
    if (allPlayers[client].TicksSinceHeadshot == GetGameTickCount())
        event.SetInt("customkill", TF_CUSTOM_HEADSHOT);

    // Set a bool to show whether the player had the Vita-Saw equipped when dying.
    allPlayers[client].HadVitaSawEquipped = DoesPlayerHaveItem(client, 173) != 0;
    return Plugin_Continue;
}

public Action ClientBlastJumped(Event event, const char[] name, bool dontBroadcast)
{
    // Set up variables.
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (allPlayers[client].WeaponBlastJumpedWith == 237 || allPlayers[client].WeaponBlastJumpedWith == 265) // Play the wind sound with the Rocket Jumper/Sticky Jumper
        event.SetInt("playsound", true);
    allPlayers[client].WeaponBlastJumpedWith = 0;
    return Plugin_Continue;
}

// When a player spawns in or touches a resupply locker.
public void PostClientInventoryReset(Event event, const char[] name, bool dontBroadcast)
{
    // Reset some player data.
    int client = GetClientOfUserId(event.GetInt("userid"));
    allPlayers[client].SpreadRecovery = 0;

    // Structurise the player's weapon list.
    StructuriseWeaponList(client);

    // Viewmodels.
    ApplyViewmodelsToPlayer(client);
}


//////////////////////////////////////////////////////////////////////////////
// NEXT-FRAME EVENTS                                                        //
//////////////////////////////////////////////////////////////////////////////

void SetSpreadInaccuracy(int client)
{
    allPlayers[client].SpreadRecovery = 66;
}

void RewardChargeOnChargeKill(int client) // This is called next frame to compensate for charge bash kills.
{
    float newCharge = GetEntPropFloat(client, Prop_Send, "m_flChargeMeter");
    for (int i = 0; i < sizeof(chargeOnChargeKillWeapons); ++i) // Award charge on charge kill.
    {
        if (DoesPlayerHaveItem(client, chargeOnChargeKillWeapons[i][0]))
            newCharge += chargeOnChargeKillWeapons[i][1];
    }
    SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", newCharge > 100.00 ? 100.00 : newCharge);
}

void NextFrameApplyViewmodelsToPlayer(int client)
{
    ApplyViewmodelsToPlayer(client);
}

//////////////////////////////////////////////////////////////////////////////
// FORWARDS                                                                 //
//////////////////////////////////////////////////////////////////////////////

public void OnClientPutInServer(int client) 
{
    SDKHook(client, SDKHook_TraceAttack, ClientIsAttacked);
    SDKHook(client, SDKHook_OnTakeDamage, ClientDamaged);
    SDKHook(client, SDKHook_OnTakeDamageAlive, ClientDamagedAlive);
    SDKHook(client, SDKHook_OnTakeDamagePost, AfterClientDamaged);
    SDKHook(client, SDKHook_WeaponSwitchPost, AfterClientSwitchedWeapons);
    SDKHook(client, SDKHook_GetMaxHealth, ClientGetMaxHealth);
}

public void OnEntityCreated(int entity, const char[] class)
{
    if (entity <= MaxClients)
        return;
    allEntities[entity].OriginalTF2ItemsIndex = -1;
    allEntities[entity].SpawnTimestamp = GetGameTime();
    strcopy(allEntities[entity].Class, MAX_NAME_LENGTH, class);

    if (HasEntProp(entity, Prop_Send, "m_iItemDefinitionIndex")) // Any econ entity.
    {
        // Hooks.
        if (StrContains(class, "tf_weapon") == 0) // Hooks restricted to weapons only.
        {
            SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", true);

            // DHooks.
            DHookEntity(DHooks_CTFWeaponBase_FinishReload, false, entity, _, WeaponReloaded);
            DHookEntity(DHooks_CTFWeaponBase_Reload, false, entity, _, WeaponReload);
            DHookEntity(DHooks_CTFWeaponBase_PrimaryAttack, false, entity, _, WeaponPrimaryFire);
            DHookEntity(DHooks_CTFWeaponBase_SecondaryAttack, false, entity, _, WeaponSecondaryFire);

            // Restricted to wrenches but it's best to do the checks in the hooked functions instead.
            DHookEntity(DHooks_CTFWrench_Equip, false, entity, _, WeaponEquipped);
            DHookEntity(DHooks_CTFWrench_Detach, false, entity, _, WeaponDetached);

            if (StrEqual(class, "tf_weapon_minigun"))
            {
                DHookEntity(DHooks_CTFMinigun_GetWeaponSpread, false, entity, _, GetMinigunWeaponSpread);
                DHookEntity(DHooks_CTFMinigun_GetProjectileDamage, false, entity, _, GetMinigunDamage);
            }
            else if (StrEqual(class, "tf_weapon_medigun"))
                DHookEntity(DHooks_CWeaponMedigun_ItemPostFrame, false, entity, _, MedigunItemPostFrame);
            else if (StrEqual(class, "tf_weapon_sniperrifle_decap"))
                DHookEntity(DHooks_CTFSniperRifleDecap_SniperRifleChargeRateMod, false, entity, _, GetBazaarBargainChargeRate);
        }
        allEntities[entity].OriginalTF2ItemsIndex = OriginalTF2ItemsIndex;
    }
    else if (StrEqual(class, "tf_projectile_ball_ornament"))
        DHookEntity(DHooks_CTFBall_Ornament_Explode, false, entity, _, OrnamentExplode);
    else if (StrEqual(class, "tf_projectile_rocket") || StrEqual(class, "tf_projectile_flare"))
        DHookEntity(DHooks_GetRadius, true, entity, _, GetProjectileExplosionRadius);
    else if (StrEqual(class, "obj_sentrygun") || StrEqual(class, "obj_dispenser") || StrEqual(class, "obj_teleporter")) // Engineer's buildings.
    {
        for (int i = 0; i <= MAXPLAYERS; ++i)
            allEntities[entity].ConstructionBoostExpiryTimes[i] = -1.0;
        SDKHook(entity, SDKHook_OnTakeDamage, BuildingDamaged);

        // TODO: REVISIT
        //DHookEntity(DHooks_CBaseObject_Command_Repair, false, entity, _, CommandRepair);
        
        if (StrEqual(class, "obj_sentrygun"))
        {
            DHookEntity(DHooks_CObjectSentrygun_OnWrenchHit, false, entity, _, PreSentryWrenchHit);
            DHookEntity(DHooks_CObjectSentrygun_OnWrenchHit, true, entity, _, PostSentryWrenchHit);
            DHookEntity(DHooks_CBaseObject_StartBuilding, true, entity, _, StartBuilding);
            DHookEntity(DHooks_CBaseObject_Construct, false, entity, _, PreConstructBuilding);
            DHookEntity(DHooks_CBaseObject_Construct, true, entity, _, PostConstructBuilding);
        }
    }
    else if (StrContains(class, "item_ammopack") == 0) // Map ammopacks, rather than dropped ammopacks.
        DHookEntity(DHooks_CAmmoPack_MyTouch, false, entity, _, CAmmoPack_OnAmmoTouch);
    else if (StrEqual(class, "tf_projectile_healing_bolt"))
        DHookEntity(DHooks_CTFProjectile_HealingBolt_ImpactTeamPlayer, true, entity, _, HealPlayerWithCrossbow);
    else if (StrEqual(class, "obj_attachment_sapper"))
        DHookEntity(DHooks_CObjectSapper_FinishedBuilding, false, entity, _, PlantSapperOnBuilding);

    SDKHook(entity, SDKHook_SpawnPost, EntitySpawn);
    SDKHook(entity, SDKHook_Touch, EntityTouch);
}

public void OnGameFrame()
{
    static int frame = 0; // Looks nicer than a global variable.
    ++frame;

    // ConVars. (I don't know why but these just get reset...)
    for (int i = 0; i < sizeof(defaultConVars); ++i)
        SetTF2ConVarValue(defaultConVars[i].Name, defaultConVars[i].NewValue);

    // Go through entities.
    for (int i = 0; i < MAX_ENTITY_COUNT; ++i)
    {
        if (IsValidEntity(i))
        {
            // Set Wrangler sentry shield fade time.
            if (allEntities[i].ShieldFadeTime != 0)
            {
                if (allEntities[i].ShieldFadeTime < GetGameTime())
                    allEntities[i].ShieldFadeTime = 0.0;
                Address m_flShieldFadeTime = GetEntityAddress(i) + CObjectSentrygun_m_flShieldFadeTime;
                WriteToValue(m_flShieldFadeTime, allEntities[i].ShieldFadeTime);
            }
        }
    }

    // Go through players.
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
        {
            int activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
            int doesHaveWeapon;
            int secondaryWeapon = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
            ++allPlayers[i].FramesSinceLastSwitch;
            if (allPlayers[i].SpreadRecovery > 0)
                --allPlayers[i].SpreadRecovery;

            // BONK! consumption.
            if (TF2_IsPlayerInCondition(i, TFCond_Bonked))
                allPlayers[i].TickSinceBonk = GetGameTickCount();

            // Shortstop push prevention and ammo management. The push prevention doesn't really account for after finishing reload. The DHook I have doesn't account for client prediction either. I'll figure something out eventually.
            doesHaveWeapon = DoesPlayerHaveItem(i, 220);
            if (doesHaveWeapon && secondaryWeapon != -1 && GetEntProp(secondaryWeapon, Prop_Send, "m_iPrimaryAmmoType") == SCOUT_PISTOL_AMMO_TYPE)
            {
                SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.00);
                SetWeaponAmmoReserve(doesHaveWeapon, GetWeaponAmmoReserve(secondaryWeapon));  
            }

            // Soda Popper hype meter buildup.
            doesHaveWeapon = DoesPlayerHaveItem(i, 448);
            if (doesHaveWeapon && doesHaveWeapon == activeWeapon && GetEntProp(i, Prop_Data, "m_nWaterLevel") < WL_Waist && GetEntityMoveType(i) == MOVETYPE_WALK && !TF2_IsPlayerInCondition(i, TFCond_CritHype))
            {
                float speed[3];
                GetEntPropVector(i, Prop_Data, "m_vecVelocity", speed);
                float newHype = GetVectorLength(speed) * TICK_RATE_PRECISION / GetConVarFloat(tf_scout_hype_mod) + GetEntPropFloat(i, Prop_Send, "m_flHypeMeter");
                SetEntPropFloat(i, Prop_Send, "m_flHypeMeter", min(100.00, newHype));
            }

            // Prevent long-range shots from reducing recharge time with the Flying Guillotine. I'll see if I can find a more convenient method than this.
            doesHaveWeapon = DoesPlayerHaveItems(i, { 812, 833 }, 2);
            if (doesHaveWeapon)
            {
                float timer = GetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime");
                if (timer != 0 && allPlayers[i].CleaverChargeMeter - timer == 1.50)
                {
                    timer = allPlayers[i].CleaverChargeMeter;
                    SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime", timer);
                }
                allPlayers[i].CleaverChargeMeter = timer;
            }

            // Sandman ball recharge. (This is REALLY hacky, but I can't use DHooks with CTFBat_Wood::InternalGetEffectBarRechargeTime because returning the right value won't do anything. :/)
            doesHaveWeapon = DoesPlayerHaveItem(i, 44);
            if (doesHaveWeapon)
                SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime", GetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime") + TICK_RATE_PRECISION / 3);

            // Wrap Assassin ball recharge. (Also REALLY hacky.)
            doesHaveWeapon = DoesPlayerHaveItem(i, 648);
            if (doesHaveWeapon)
                SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime", GetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime") + TICK_RATE_PRECISION / 2);

            // B.A.S.E. Jumper redeployment and updraft.
            doesHaveWeapon = DoesPlayerHaveItem(i, 1101);
            if (doesHaveWeapon)
            {
                if (TF2_IsPlayerInCondition(i, TFCond_Parachute) && TF2_IsPlayerInCondition(i, TFCond_OnFire)) // Updraft.
                {
                    float velocity[3];
                    float maxVerticalMomentum = GetConVarFloat(tf_parachute_maxspeed_onfire_z);
                    GetEntPropVector(i, Prop_Data, "m_vecVelocity", velocity);
                    if (velocity[2] < maxVerticalMomentum)
                    {
                        velocity[2] = maxVerticalMomentum;
                        TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
                    }
                }
                else if (TF2_IsPlayerInCondition(i, TFCond_ParachuteDeployed) && GetGameTime() - allPlayers[i].TimeSinceDeployment > 0.2) // Allow parachute redeployment.
                    TF2_RemoveCondition(i, TFCond_ParachuteDeployed);
            }

            // Half-Zatoichi honorbound. This is hacky but hooks to Weapon_Switch/Weapon_CanSwitchTo don't fully work because of client prediction.
            if (activeWeapon != -1 && GetWeaponIndex(activeWeapon) == 357 && GetEntProp(i, Prop_Send, "m_iKillCountSinceLastDeploy") == 0 && GetGameTime() >= GetEntPropFloat(i, Prop_Send, "m_flFirstPrimaryAttack"))
                TF2_AddCondition(i, TFCond_RestrictToMelee, TICK_RATE_PRECISION * 2);

            // Short Circuit alt-fire prevention.
            doesHaveWeapon = DoesPlayerHaveItem(i, 528);
            if (doesHaveWeapon)
                SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.00);
            
            // Set the healer for the Vaccinator and if being Ubered, remove their resistance. Also drain charge while Ubering.
            doesHaveWeapon = DoesPlayerHaveItem(i, 998);
            if (doesHaveWeapon)
            {
                int patient = GetEntPropEnt(doesHaveWeapon, Prop_Send, "m_hHealingTarget");
                int currentHealer = allEntities[doesHaveWeapon].CurrentHealer;
                TFCond resistance = view_as<TFCond>(GetResistType(doesHaveWeapon) + TF_COND_RESIST_OFFSET);
                if (allPlayers[i].UsingVaccinatorUber)
                {
                    allPlayers[i].VaccinatorCharge -= 0.25 * (TICK_RATE_PRECISION / 2);
                    if (allPlayers[i].VaccinatorCharge <= allPlayers[i].EndVaccinatorChargeFalloff)
                    {
                        allPlayers[i].UsingVaccinatorUber = false;
                        allPlayers[i].VaccinatorHealers[i] = false;
                        if (patient != -1)
                            TF2_RemoveCondition(patient, resistance);
                        TF2_RemoveCondition(i, resistance);
                    }
                    else
                        SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flChargeLevel", allPlayers[i].VaccinatorCharge);
                }
                if (currentHealer != patient || doesHaveWeapon != activeWeapon)
                {
                    if (patient > 0)
                    {
                        if (allPlayers[i].UsingVaccinatorUber)
                            TF2_AddCondition(patient, resistance);
                        allPlayers[patient].VaccinatorHealers[i] = true;
                    }
                    if (doesHaveWeapon != activeWeapon)
                        allPlayers[i].VaccinatorHealers[i] = false;
                    if (currentHealer > 0)
                    {
                        TF2_RemoveCondition(currentHealer, resistance);
                        allPlayers[currentHealer].VaccinatorHealers[i] = false;
                    }
                    allEntities[doesHaveWeapon].CurrentHealer = patient;
                }
            }

            // Medigun Uber.
            doesHaveWeapon = DoesPlayerHaveItemByClass(i, "tf_weapon_medigun");
            if (doesHaveWeapon && IsPlayerAlive(i))
            {
                // Do not give Uber with the Amputator while using the taunt.
                int amputator = DoesPlayerHaveItem(i, 304);
                if (amputator == GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon") && TF2_IsPlayerInCondition(i, TFCond_Taunting))
                    SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flChargeLevel", allPlayers[i].CurrentUber);
                allPlayers[i].CurrentUber = GetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flChargeLevel");
            }

            // Bazaar Bargain head counter.
            int decapitations = GetEntProp(i, Prop_Send, "m_iDecapitations");
            if ((allPlayers[i].BazaarBargainShot == BazaarBargain_Lose && decapitations != 0) || allPlayers[i].BazaarBargainShot != BazaarBargain_Idle)
            {
                int newHead = decapitations + view_as<int>(allPlayers[i].BazaarBargainShot);
                SetEntProp(i, Prop_Send, "m_iDecapitations", intMax(0, newHead));
                allPlayers[i].BazaarBargainShot = BazaarBargain_Idle;
            }
        }
    }

    if (frame % TICK_RATE == 0) // Every second.
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i))
            {
                // Might use a "dictionary" for this to automate things.
                int health = GetClientHealth(i);
                int maxHealth = allPlayers[i].MaxHealth;
                if (DoesPlayerHaveItem(i, 354) && health < maxHealth) // Concheror passive heal.
                {
                    // Show that attacker got healed.
                    Handle event = CreateEvent("player_healonhit", true);
                    SetEventInt(event, "amount", 2);
                    SetEventInt(event, "entindex", i);
                    FireEvent(event);

                    // Set health.
                    SetEntityHealth(i, intMin(health + 2, maxHealth));
                }
                else if (DoesPlayerHaveItem(i, 642) && health < maxHealth) // Cozy Camper passive heal.
                {
                    // Show that attacker got healed.
                    Handle event = CreateEvent("player_healonhit", true);
                    SetEventInt(event, "amount", 1);
                    SetEventInt(event, "entindex", i);
                    FireEvent(event);

                    // Set health.
                    SetEntityHealth(i, intMin(health + 1, maxHealth));
                }
            }
        }
    }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    // Panic Attack fire when reaching full clip.
    int doesHaveWeapon = DoesPlayerHaveItem(client, 1153);
    if (doesHaveWeapon && GetEntProp(doesHaveWeapon, Prop_Send, "m_iClip1") == 4)
    {
        allPlayers[client].TicksSinceFiring = GetGameTickCount();
        buttons ^= IN_ATTACK;
        EmitSoundToAll("weapons\\tf2_backshot_shotty.wav", doesHaveWeapon, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL);
        return Plugin_Changed;
    }

    // Allow the user to pick up buildings with the Short Circuit equipped.
    doesHaveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (IsValidEntity(doesHaveWeapon) && GetWeaponIndex(doesHaveWeapon) == 528 && !GetEntProp(client, Prop_Send, "m_bHasPasstimeBall") && buttons & IN_ATTACK2)
        SDKCall(SDKCall_CTFPlayer_TryToPickupBuilding, client);

    // Prevent using alt-fire to activate the Amputator taunt.
    if (IsValidEntity(doesHaveWeapon) && GetWeaponIndex(doesHaveWeapon) == 304 && buttons & IN_ATTACK2)
    {
        buttons ^= IN_ATTACK2;
        return Plugin_Changed;
    }

    // Do not launch the Huntsman arrow until the player is on the ground. This kind of screws up client prediction though.
    if (IsValidEntity(doesHaveWeapon))
    {
        int index = GetWeaponIndex(doesHaveWeapon);
        if ((index == 56 || index == 1005 || index == 1092) && GetEntityFlags(client) & FL_ONGROUND == 0 && allPlayers[client].WasInAttack)
        {
            buttons |= IN_ATTACK;
            return Plugin_Changed;
        }
    }

    //return Plugin_Changed;
    allPlayers[client].WasInAttack = buttons & IN_ATTACK;
    return Plugin_Continue;
}

//////////////////////////////////////////////////////////////////////////////
// SDK HOOKS                                                                //
//////////////////////////////////////////////////////////////////////////////

Action EntitySpawn(int entity)
{
    if (StrEqual(allEntities[entity].Class, "tf_ammo_pack"))
    {
        int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if (client > 0 && client <= MaxClients) // Set ammo pack model to the player's active weapon.
        {
            //SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_iWorldModelIndex"), _, 0);
            SetEntProp(entity, Prop_Send, "m_nModelIndex", GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_iWorldModelIndex"), _, 0);
        }
    }
    else if (IsValidEntity(entity) && HasEntProp(entity, Prop_Send, "m_iWorldModelIndex") && HasEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
    {
        int index = GetWeaponIndex(entity);
        for (int i = 0; i < sizeof(customWeapons); ++i)
        {
            if (index == customWeapons[i].ItemDefinitionIndex)
            {
                SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", customWeapons[i].Cache); // this only exists just for the sake of ammo drops.
                //SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", customWeapons[i].Cache, _, 0); // this fucks up viewmodel animations, great. thanks source
                break;
            }
        }
    }
    else if (StrEqual(allEntities[entity].Class, "tf_projectile_energy_ring")) // Set the hitbox size of the Bison/Pomson projectiles.
    {
        float mins[3] = { -2.0, -2.0, -10.0 };
        float maxs[3] = { 2.0, 2.0, 10.0 };
        SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
        SetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
        SetEntProp(entity, Prop_Send, "m_usSolidFlags", GetEntProp(entity, Prop_Send, "m_usSolidFlags") | FSOLID_USE_TRIGGER_BOUNDS);
        SetEntProp(entity, Prop_Send, "m_triggerBloat", 24);
    }
    return Plugin_Continue;
}

Action EntityTouch(int entity, int other)
{
    if (StrContains(allEntities[entity].Class, "tf_projectile_") == 0)
    {
        if (StrEqual(allEntities[entity].Class, "tf_projectile_energy_ring"))
        {
            // If the teammate has a Huntsman, set it alight.
            bool isTeammate = false;
            if (other > 0 && other <= MaxClients && TF2_GetClientTeam(other) == TF2_GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
            {
                isTeammate = true;
                int weapon = DoesPlayerHaveItemByClass(other, "tf_weapon_compound_bow");
                if (weapon == GetEntPropEnt(other, Prop_Send, "m_hActiveWeapon"))
                    SetEntProp(weapon, Prop_Send, "m_bArrowAlight", true);
            }

            // Allow the Pomson projectile to go through teammates and teammate buildings.
            if (GetWeaponIndex(GetEntPropEnt(entity, Prop_Send, "m_hLauncher")) == 588 && (isTeammate || HasEntProp(other, Prop_Send, "m_hBuilder")))
                return Plugin_Handled;
        }

        if (other > 0 && other <= MaxClients)
        {
            allPlayers[other].TicksSinceProjectileEncounter = GetGameTickCount();
            allPlayers[other].MostRecentProjectileEncounter = entity;
            
            // Pick up the Wrap Assassin ornament for usage.
            int doesHaveWeapon = DoesPlayerHaveItems(other, { 44, 648 }, 2);
            if (StrEqual(allEntities[entity].Class, "tf_projectile_ball_ornament") && doesHaveWeapon && GetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime") > GetGameTime())
            {
                RemoveEntity(entity);
                SetEntPropFloat(doesHaveWeapon, Prop_Send, "m_flEffectBarRegenTime", 0.00);
            }
        }
    }
    return Plugin_Continue;
}

Action ClientIsAttacked(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
    if (hitgroup == 1 && damagetype & DMG_USE_HITLOCATIONS && allPlayers[attacker].SpreadRecovery == 0)
        allPlayers[victim].TicksSinceHeadshot = GetGameTickCount();
    return Plugin_Continue;
}

Action BuildingDamaged(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageforce[3], float damageposition[3], int damagecustom)
{
    Action returnValue = Plugin_Continue;
    if (IsValidEntity(weapon))
    {
        int index = GetWeaponIndex(weapon);
        if (damagecustom == TF_CUSTOM_CANNONBALL_PUSH) // Loose Cannon ball.
        {
            damage = 60.00;
            returnValue = Plugin_Changed;
        }
        if (index == 460 && !TF2_IsPlayerInCondition(attacker, TFCond_Disguised)) // Enforcer 20% damage bonus while undisguised.
        {
            damage *= 1.20;
            returnValue =  Plugin_Changed;
        }
        if (damagecustom == TF_CUSTOM_BASEBALL && index == 44) // Sandman ball impact.
        {
            damage = 15.00; // Force the damage to always be 15.
            returnValue =  Plugin_Changed;
        }
        if (index == 442) // Righteous Bison damage.
        {
            damage = 3.2; // 16 * 0.2
            returnValue =  Plugin_Changed;
        }
        if (index == 307) // Caber damage.
        {
            if (damagecustom == 0) // Melee damage.
                damage = 35.00;
            else if (damagecustom == TF_CUSTOM_STICKBOMB_EXPLOSION) // Explosion damage.
                damage = 100.00;
            returnValue =  Plugin_Changed;
        }
        if (StrEqual(allEntities[victim].Class, "m_nShieldLevel")) // Set sentry damage resistances from miniguns and the sapper's owner.
        {
            bool changed = false;
            if (StrEqual(allEntities[weapon].Class, "tf_weapon_minigun"))
            {
                switch (GetEntProp(victim, Prop_Send, "m_iUpgradeLevel"))
                {
                    case 2:
                    {
                        damage = damage / SENTRYGUN_MINIGUN_RESIST_LVL_2_OLD * SENTRYGUN_MINIGUN_RESIST_LVL_2_NEW;
                        changed = true;
                    }
                    case 3:
                    {
                        damage = damage / SENTRYGUN_MINIGUN_RESIST_LVL_3_OLD * SENTRYGUN_MINIGUN_RESIST_LVL_3_NEW;
                        changed = true;
                    }
                }
            }
            if (GetEntProp(victim, Prop_Send, "m_bHasSapper") && GetEntPropEnt(allEntities[victim].AttachedSapper, Prop_Send, "m_hBuilder") == attacker)
            {
                damage = damage / SENTRYGUN_SAPPER_OWNER_DAMAGE_MODIFIER_OLD * SENTRYGUN_SAPPER_OWNER_DAMAGE_MODIFIER_NEW;
                changed = true;
            }
            if (changed)
                returnValue =  Plugin_Changed;
        }
    }
    
    return returnValue;
}

Action ClientDamaged(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageforce[3], float damageposition[3], int damagecustom)
{
    Action returnValue = Plugin_Continue;
    int index = GetWeaponIndex(weapon);
    int inflictorIndex = IsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_hLauncher") ? GetWeaponIndex(GetEntPropEnt(inflictor, Prop_Send, "m_hLauncher")) : -1;
    int victimActiveWeapon = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");
    allPlayers[victim].HealthBeforeKill = GetClientHealth(victim);

    if ((damagetype & DMG_IGNITE || index == 348) && ((attacker != victim && GetClientTeam(attacker) != GetClientTeam(victim)) || attacker == victim) && !IsInvulnerable(victim) && !TF2_IsPlayerInCondition(victim, TFCond_FireImmune)) // Anything that causes fire.
    {
        allPlayers[victim].TimeSinceEncounterWithFire = GetGameTime();
        returnValue = Plugin_Changed;
    }

    // projectile-specific code
    if (damagecustom == TF_CUSTOM_BASEBALL && GetWeaponIndex(inflictor) == 44) // Sandman stun. The majority of this is sourced from the TF2 source code leak.
    {
        damage = 15.00; // Force the damage to always be 15.
        allPlayers[victim].TicksSinceProjectileEncounter = 0;
        TF2_RemoveCondition(victim, TFCond_Dazed); // TF2_StunPlayer just sets TFCond_Dazed again anyway.

        // We have a more intense stun based on our travel time.
        float flLifeTime = min(GetGameTime() - allEntities[allPlayers[victim].MostRecentProjectileEncounter].SpawnTimestamp, FLIGHT_TIME_TO_MAX_STUN);
        float flLifeTimeRatio = flLifeTime / FLIGHT_TIME_TO_MAX_STUN;
        if (flLifeTimeRatio > 0.1)
        {
            float flStun = 0.5;
            float flStunDuration = GetConVarFloat(tf_scout_stunball_base_duration) * flLifeTimeRatio;
            if (damagetype & DMG_CRIT)
                flStunDuration += 2.0; // Extra two seconds of effect time if we're a critical hit.
            int iStunFlags = TF_STUN_LOSER_STATE | TF_STUN_MOVEMENT;
            if (flLifeTimeRatio >= 1.0)
            {
                flStunDuration += 1.0;
                iStunFlags = TF_STUN_CONTROLS;
                iStunFlags |= TF_STUN_SPECIAL_SOUND;
            }

            // Adjust stun amount and flags if we're hitting a boss or scaled enemy
            if (GameModeUsesMiniBosses() && (GetEntProp(victim, Prop_Send, "m_bIsMiniBoss") || GetEntPropFloat(victim, Prop_Send, "m_flModelScale") > 1.0))
            {
                // If max range, freeze them in place - otherwise adjust it based on distance
                flStun = flLifeTimeRatio >= 1.0 ? 1.0 : RemapValClamped( flLifeTimeRatio, 0.1, 0.99, 0.5, 0.75 );
                iStunFlags = flLifeTimeRatio >= 1.0 ? ( TF_STUN_SPECIAL_SOUND | TF_STUN_MOVEMENT ) : TF_STUN_MOVEMENT; 
            }

            if (GetEntProp(victim, Prop_Send, "m_nWaterLevel") != WL_Eyes)
                TF2_StunPlayer(victim, flStunDuration, flStun, iStunFlags, attacker);
        }

        returnValue = Plugin_Changed;
    }
    else if (damagecustom == TF_CUSTOM_CANNONBALL_PUSH) // Loose Cannon ball.
    {
        damage = 60.00;
        returnValue = Plugin_Changed;
    }
    else if ((damagecustom == TF_CUSTOM_CLEAVER || damagecustom == TF_CUSTOM_CLEAVER_CRIT) && allPlayers[victim].TicksSinceProjectileEncounter == GetGameTickCount() && GetGameTime() - allEntities[allPlayers[victim].MostRecentProjectileEncounter].SpawnTimestamp >= 1) // Flying Guillotine mini-crit.
        TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, TICK_RATE_PRECISION);
    else if ((inflictorIndex == 228 || inflictorIndex == 1085) && attacker != victim && TF2_GetClientTeam(attacker) != TF2_GetClientTeam(victim)) // Black Box hit.
    {
        // Show that attacker got healed.
        Handle event = CreateEvent("player_healonhit", true);
        SetEventInt(event, "amount", 15);
        SetEventInt(event, "entindex", attacker);
        FireEvent(event);

        // Set health.
        SetEntityHealth(attacker, intMin(GetClientHealth(attacker) + 15, allPlayers[attacker].MaxHealth));
    }

    // weapon-specific code
    if (IsValidEntity(weapon)) 
    {
        if (index == 415 && GetEntityFlags(victim) & (FL_ONGROUND | FL_INWATER) == 0 && allPlayers[attacker].FramesSinceLastSwitch < TICK_RATE * 5) // Reserve Shooter mini-crit. This only works if it hasn't been 5 seconds since equipping the Reserve Shooter.
            TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, TICK_RATE_PRECISION, inflictor);
        if ((index == 228 || index == 1085) && attacker != victim && TF2_GetClientTeam(attacker) != TF2_GetClientTeam(victim)) // Black Box hit.
        
        if (index == 127 && TF2_IsPlayerInCondition(victim, TFCond_BlastJumping)) // Direct Hit mini-crit on players thrown into air via explosion.
            TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, TICK_RATE_PRECISION);
        if (allPlayers[victim].TicksSinceHeadshot == GetGameTickCount() && (index == 61 || index == 1006)) // Ambassador headshot. TODO:
        {
            // You'd think that "damagetype |= DMG_USE_HITLOCATIONS" should work fine, but ever since Jungle Inferno, this was changed to only actually crit within a specific range (0-1200 HU).
            damagetype |= DMG_CRIT;
            returnValue = Plugin_Changed;
        }
        if (index == 460 && !TF2_IsPlayerInCondition(attacker, TFCond_Disguised)) // Enforcer 20% damage bonus while undisguised.
        {
            damage *= 1.20;
            returnValue = Plugin_Changed;
        }
        if (index == 442) // Righteous Bison damage. I doubt this is exact but it's still pretty accurate as far as I'm aware.
        {
            // Damage numbers.
            damagetype ^= DMG_USEDISTANCEMOD; // Do not use internal rampup/falloff.
            damage = 16.00 * RemapValClamped(min(0.35, GetGameTime() - allEntities[allPlayers[victim].MostRecentProjectileEncounter].SpawnTimestamp), 0.35 / 2, 0.35, 1.25, 0.75); // Deal 16 base damage with 125% rampup, 75% falloff.

            returnValue = Plugin_Changed;
        }
        if (index == 588) // Pomson damage (uses same rampup/falloff system as the Bison) and Medic/Spy Uber/Cloak drain. Welcome back, fun police.
        {
            // Damage.
            damagetype ^= DMG_USEDISTANCEMOD; // Do not use internal rampup/falloff.
            damage = 48.00 * RemapValClamped(min(0.35, GetGameTime() - allEntities[allPlayers[victim].MostRecentProjectileEncounter].SpawnTimestamp), 0.35 / 2, 0.35, 1.25, 0.75); // Deal 48 base damage with 125% rampup, 75% falloff.

            // Uber/cloak drain: vectors.
            float attackerPosition[3];
            float victimPosition[3];
            GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerPosition);
            GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPosition);

            // Uber/cloak drain: mechanics.
            float drain = RemapValClamped(GetVectorDistance(attackerPosition, victimPosition), 512.0, 1536.0, 1.0, 0.0);
            if (TF2_GetPlayerClass(victim) == TFClass_Medic)
            {
                int medigun = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);
                if (!GetEntProp(medigun, Prop_Send, "m_bChargeRelease"))
                {
                    float newUber = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel") - 0.10 * (1.00 - drain);
                    SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", newUber > 0.00 ? newUber : 0.00);
                }
            }
            else if (TF2_GetPlayerClass(victim) == TFClass_Spy)
            {
                float newCloak = GetEntPropFloat(victim, Prop_Send, "m_flCloakMeter") - 20 * (1.00 - drain);
                SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", newCloak > 0.00 ? newCloak : 0.00);
            }
            returnValue = Plugin_Changed;
        }
        if (index == 357 && IsValidEntity(victimActiveWeapon) && GetWeaponIndex(victimActiveWeapon) == 357) // Half-Zatoichi duels. Instead of checking for the active weapon index or class name or whatever, Valve decided to go with checking for the honorbound attribute instead...
        {
            damage = float(GetClientHealth(victim) * 3);
            damagetype |= DMG_DONT_COUNT_DAMAGE_TOWARDS_CRIT_RATE;
            returnValue = Plugin_Changed;
        }
        if (damagetype & DMG_IGNITE && index == 351)
        {
            if (victim != attacker && allPlayers[victim].TicksSinceProjectileEncounter == GetGameTickCount() && GetEntPropEnt(allPlayers[victim].MostRecentProjectileEncounter, Prop_Send, "m_hLauncher") == weapon && TF2_IsPlayerInCondition(victim, TFCond_OnFire)) // Make Detonator mini-crit on burning targets if hit directly.
                TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, TICK_RATE_PRECISION);
            else if (victim == attacker) // Detonator self-damage. The damage also influences the damage force.
            {
                if (damagetype & DMG_BLAST) // Direct hit: set the damage to just be 30.
                {
                    damage = 30.00;
                    returnValue = Plugin_Changed;
                }
                else // Self-detonation jump from Detonator.
                {
                    damage = ApplyRadiusDamage(victim, damageposition, 96.00, 30.00, 1.00, 0.5, false) / 1.25;
                    returnValue = Plugin_Changed;
                }
            }
        }
        if (damagecustom == TF_CUSTOM_CHARGE_IMPACT) // Charge impact damage.
        {
             // Do not deal charge damage if the user's charge meter is still higher than 40.00 and they aren't using the Splendid Screen.
            if (index != 406 && GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter") > 40.00)
                return Plugin_Handled;

            // Set the charge impact damage. Previously it did not have rampup.
            damage = 50 * (1.0 + intMin(GetEntProp(attacker, Prop_Send, "m_iDecapitations"), 5) * 0.2);
            if (index == 406) // Increase charge damage by 70%. I should probably find a way to hook onto attributes without hardcoding numbers.
                damage *= 1.7;
            
            returnValue = Plugin_Changed;
        }
        if (index == 307) // Caber damage.
        {
            if (damagecustom == 0) // Melee damage.
            {
                damage = 35.00;
                returnValue = Plugin_Changed;
            }
            else if (damagecustom == TF_CUSTOM_STICKBOMB_EXPLOSION) // Explosion damage.
            {
                // Set base damage.
                damage = 100.00;

                if (victim != attacker && damagetype & DMG_CRIT == 0)
                {
                    // Set up vectors.
                    float start[3];
                    float end[3];
                    GetAbsOrigin(attacker, start);
                    GetAbsOrigin(victim, end);

                    // Modify damage.
                    damagetype ^= DMG_USEDISTANCEMOD; // Do not use internal rampup/falloff.
                    damage *= 1.0 + 0.50 * (1.0 - GetVectorDistance(start, end) / 2048.00); // 100 base damage, 50% rampup.
                }
                returnValue = Plugin_Changed;
            }
        }
        if (index == 41) // Natascha stun. Stun amount/duration taken from TF2 source code.
        {
            // Slow enemy on hit, unless they're being healed by a medic
            if (!TF2_IsPlayerInCondition(victim, TFCond_Healing))
                TF2_StunPlayer(victim, 0.20, 0.60, TF_STUN_MOVEMENT, attacker);
        }
        if (damagetype & DMG_IGNITE && index == 811 || index == 832) // Huo-Long Heater Ring of Fire attack.
        {
            damage = 15.00;
            returnValue = Plugin_Changed;
        }
        if (index == 740 && attacker == victim) // Scorch Shot jump.
        {
            damage = ApplyRadiusDamage(victim, damageposition, 96.00, 30.00, 1.00, 0.166, false);
            returnValue = Plugin_Changed;
        }
        if (index == 402 && allPlayers[victim].TicksSinceHeadshot == GetGameTickCount() && TF2_IsPlayerInCondition(attacker, TFCond_Slowed)) // Bazaar bargain headshot: gain a head.
            allPlayers[attacker].BazaarBargainShot = BazaarBargain_Gain;
        if (index == 356 && damagecustom == TF_CUSTOM_BACKSTAB) // Save the player's HP for the Kunai backstab.
            allPlayers[attacker].OldHealth = GetClientHealth(attacker);
        if (index == 237 || index == 265) // Stop the Rocket Jumper/Sticky Jumper from damaging yourself.
        {
            allPlayers[attacker].OldHealth = GetClientHealth(attacker);
            allPlayers[attacker].WeaponBlastJumpedWith = index;
            SetEntityHealth(attacker, allPlayers[attacker].MaxHealth);
        }
    }

    if (damagetype & DMG_FALL) // Fall damage.
        allPlayers[victim].TicksSinceFallDamage = GetGameTickCount();

    // Dead Ringer damage modification and feign checks.
    if (GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") && !allPlayers[victim].FeigningDeath)
        allPlayers[victim].TicksSinceFeignReady = GetGameTickCount();
    if (allPlayers[victim].FeigningDeath)
        allPlayers[victim].DamageTakenDuringFeign += damage;
    if (allPlayers[victim].FeigningDeath && GetFeignBuffsEnd(victim) >= GetGameTickCount())
    {
        damage *= 0.10;
        returnValue = Plugin_Changed;
    }

    return returnValue;
}

MRESReturn OnTakeDamageAlive(int entity, DHookReturn returnValue, DHookParam parameters)
{
    Address info = view_as<Address>(parameters.Get(1));
    int victim = entity;
    int attacker = LoadEntityHandleFromAddress(info + CTakeDamageInfo_m_hAttacker);
    int damagetype = Dereference(info + CTakeDamageInfo_m_bitsDamageType);
    float damage = Dereference(info + CTakeDamageInfo_m_flDamage);
    //float damagebonus = Dereference(info + CTakeDamageInfo_m_flDamageBonus);
    ECritType crit = Dereference(info + CTakeDamageInfo_m_eCritType);

    // Vaccinator resistances.
    int count = 0;
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (allPlayers[victim].VaccinatorHealers[i])
        {
            ++count;
            int vaccinator = DoesPlayerHaveItem(i, 998);
            if (attacker != victim && damagetype & resistanceMapping[GetResistType(vaccinator)]) // Check that the damage type matches the Medic's current resistance.
            {
                if (damagetype != DMG_BURN)
                {
                    if (victim != i)
                    {
                        // Show that the healer got healed.
                        Handle event = CreateEvent("player_healonhit", true);
                        SetEventInt(event, "amount", RoundFloat(damage * 0.25));
                        SetEventInt(event, "entindex", i);
                        FireEvent(event);

                        // Set health.
                        SetEntityHealth(i, intMin(GetClientHealth(i) + RoundFloat(damage * 0.25), allPlayers[i].MaxHealth));

                    }
                    if (allPlayers[victim].ActualCritType != CRIT_NONE)
                    {
                        if (allPlayers[i].UsingVaccinatorUber)
                        {
                            if (damagetype & DMG_BULLET)
                                allPlayers[i].VaccinatorCharge -= 0.03;
                            else if (damagetype & DMG_BLAST)
                                allPlayers[i].VaccinatorCharge -= 0.75;
                            else if (damagetype & DMG_IGNITE)
                                allPlayers[i].VaccinatorCharge -= 0.01;
                            SetEntPropFloat(vaccinator, Prop_Send, "m_flChargeLevel", max(0.00, allPlayers[i].VaccinatorCharge));
                            WriteToValue(info + CTakeDamageInfo_m_eCritType, CRIT_NONE);
                            WriteToValue(info + CTakeDamageInfo_m_bitsDamageType, damagetype & ~DMG_CRIT);
                            if (crit == CRIT_MINI)
                                WriteToValue(info + CTakeDamageInfo_m_flDamage, damage / 1.35);
                            else if (crit == CRIT_FULL)
                                WriteToValue(info + CTakeDamageInfo_m_flDamage, damage / 3.00);
                            //WriteToValue(info + CTakeDamageInfo_m_flDamage, damage - damagebonus);
                        }
                    }
                }

                // Stack up resistances.
                if (count > 1)
                {
                    if (allPlayers[i].UsingVaccinatorUber)
                        WriteToValue(info + CTakeDamageInfo_m_flDamage, damage * 0.25);
                    else
                        WriteToValue(info + CTakeDamageInfo_m_flDamage, damage * 0.90);
                }
            }
        }
    }


    return MRES_Ignored;
}

Action ClientDamagedAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    Action returnValue = Plugin_Continue;

    if (TF2_IsPlayerInCondition(victim, TFCond_RestrictToMelee) && TF2_IsPlayerInCondition(victim, TFCond_CritCola) && GetGameTickCount() - allPlayers[victim].TicksSinceConsumingSandvich < TICK_RATE * LUNCHBOX_ADDS_MINICRITS_DURATION) // 25% damage vulnerability when under the effects of the Buffalo Steak Sandvich.
    {
        damage = damage / 1.20 * 1.25;
        returnValue = Plugin_Changed;
    }
    
    if (TF2_IsPlayerInCondition(victim, TFCond_CritCola) && TF2_GetPlayerClass(victim) == TFClass_Scout) // 10% damage vulnerability while using Crit-a-Cola.
    {
        damage *= 1.10;
        returnValue = Plugin_Changed;
    }

    if (DoesPlayerHaveItem(victim, 232) && damagetype & (DMG_IGNITE | DMG_BURN)) // 20% fire damage vulnerability with the Bushwacka.
    {
        damage *= 1.20;
        returnValue = Plugin_Changed;
    }

    if (DoesPlayerHaveItem(victim, 773)) // The player has the Pretty Boy's Pocket Pistol equipped.
    {
        if (damagetype & DMG_FALL && !attacker) // Fall damage negation.
            return Plugin_Handled;
        if (damagetype & (DMG_BURN | DMG_IGNITE)) // 50% fire damage vulnerability.
        {
            damage *= 1.50;
            returnValue = Plugin_Changed;
        }
    }

    if (IsValidEntity(weapon))
    {
        int index = GetWeaponIndex(weapon);
        if (index == 230 && GetGameTime() - allPlayers[attacker].TimeSinceScoping >= 1.0 && TF2_IsPlayerInCondition(attacker, TFCond_Slowed)) // Sydney Sleeper Jarateing.
            TF2_AddCondition(victim, TFCond_Jarated, 8.0);
    }
    
    return returnValue;
}

void AfterClientDamaged(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
    int victimActiveWeapon = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");
    if (IsValidEntity(victimActiveWeapon) && GetWeaponIndex(victimActiveWeapon) == 649 && damagetype & (DMG_IGNITE | DMG_BURN)) // Spy-cicle fire immunity.
    {
        // Add immunity.
        TF2_RemoveCondition(victim, TFCond_OnFire);
        TF2_AddCondition(victim, TFCond_FireImmune, 2.00);
        EmitSoundToAll("weapons\\icicle_melt_01.wav", victim, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL | SND_CHANGEPITCH);

        // Manually modify network properties. (I wrote this code before I had my addcond DHook so...)
        SetEntPropFloat(victimActiveWeapon, Prop_Send, "m_flKnifeMeltTimestamp", GetGameTime());
        SetEntPropFloat(victimActiveWeapon, Prop_Send, "m_flKnifeRegenerateDuration", 15.00);
        SetEntProp(victimActiveWeapon, Prop_Send, "m_bKnifeExists", false);
        
        // Finally, holster the Spy-cicle!
        ClientCommand(victim, "slot2"); // Equip the sapper. Probably should SDKCall Weapon_Switch instead and use the sapper entity.
    }
    if (IsValidEntity(weapon))
    {
        int index = GetWeaponIndex(weapon);
        if (!IsPlayerAlive(victim))
        {
            if (index == 214) // Powerjack kill.
            {
                // Show that attacker got healed.
                Handle event = CreateEvent("player_healonhit", true);
                SetEventInt(event, "amount", intMin(PYRO_OVERHEAL - GetClientHealth(attacker), 75));
                SetEventInt(event, "entindex", attacker);
                FireEvent(event);

                // Set health.
                SetEntityHealth(attacker, intMin(GetClientHealth(attacker) + 75, PYRO_OVERHEAL));
            }
            if (index == 356 && damagecustom == TF_CUSTOM_BACKSTAB) // Conniver's Kunai backstab.
            {
                // Show that attacker got healed.
                Handle event = CreateEvent("player_healonhit", true);
                SetEventInt(event, "amount", intMin(KUNAI_OVERHEAL - allPlayers[attacker].OldHealth, allPlayers[victim].HealthBeforeKill));
                SetEventInt(event, "entindex", attacker);
                FireEvent(event);

                // Set health.
                SetEntityHealth(attacker, intMin(allPlayers[attacker].OldHealth + allPlayers[victim].HealthBeforeKill, KUNAI_OVERHEAL));
            }
            if (((weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee) && allPlayers[attacker].GiveChargeOnKill) || damagecustom == TF_CUSTOM_CHARGE_IMPACT) && DoesPlayerHaveItemByClass(attacker, "tf_wearable_demoshield")) // Award charge on charge kill.
                RequestFrame(RewardChargeOnChargeKill, attacker);
            if (index == 357) // Half-Zatoichi kill.
                SetEntityHealth(attacker, allPlayers[attacker].MaxHealth);
            if (index == 402 && TF2_IsPlayerInCondition(attacker, TFCond_Slowed) && allPlayers[attacker].BazaarBargainShot == BazaarBargain_Gain) // Bazaar Bargain: do not gain two heads in one time. I don't wanna make yet another DHook so I'll just make this instead.
                SetEntProp(attacker, Prop_Send, "m_iDecapitations", GetEntProp(attacker, Prop_Send, "m_iDecapitations") - 1);
        }
        if (index == 237 || index == 265) // Stop the Rocket Jumper/Sticky Jumper from damaging yourself.
        {
            SetEntityHealth(attacker, allPlayers[attacker].OldHealth);
        }
    }
    if (DoesPlayerHaveItem(victim, 1099) && TF2_IsPlayerInCondition(victim, TFCond_Charging)) // Charge loss when taking damage with the Tide Turner.
    {
        float newCharge = GetEntPropFloat(victim, Prop_Send, "m_flChargeMeter") - damage * 3;
        SetEntPropFloat(victim, Prop_Send, "m_flChargeMeter", newCharge < 0.00 ? 0.00 : newCharge);
    }
    if (allPlayers[victim].TicksSinceFeignReady == GetGameTickCount()) // Set the cloak meter to 100 when feigning.
        SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", 100.00);

}

void AfterClientSwitchedWeapons(int client, int weapon)
{
    // Weapon functionality.
    if (IsValidEntity(weapon))
    {
        int index = GetWeaponIndex(weapon);
        if (index == 998 && allPlayers[client].UsingVaccinatorUber) // Give back resistances to the Medic if using the Vaccinator Uber.
        {
            allPlayers[client].VaccinatorHealers[client] = true;
            TF2_AddCondition(client, view_as<TFCond>(GetResistType(weapon) + TF_COND_RESIST_OFFSET));
        }
    }
    allPlayers[client].FramesSinceLastSwitch = 0;

    // Viewmodels.
    ApplyViewmodelsToPlayer(client);
}

Action ClientGetMaxHealth(int client, int& maxhealth)
{
    if (allPlayers[client].Weapons[0] == 0) // Final weapon structure check.
        StructuriseWeaponList(client);
    for (int weapon = 0; weapon < sizeof(weaponHealthModifiers); ++weapon)
    {
        if (DoesPlayerHaveItem(client, weaponHealthModifiers[weapon][0]))
            maxhealth += weaponHealthModifiers[weapon][1];
    }
    allPlayers[client].MaxHealth = maxhealth;
    return Plugin_Handled;
}

//////////////////////////////////////////////////////////////////////////////
// DHOOKS                                                                   //
//////////////////////////////////////////////////////////////////////////////

MRESReturn GetProjectileExplosionRadius(int entity, DHookReturn returnValue)
{
    int index = GetWeaponIndex(GetEntPropEnt(entity, Prop_Send, "m_hLauncher"));
    if (index == 1104 && TF2_IsPlayerInCondition(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), TFCond_BlastJumping)) // Do not reduce rocket radius while rocket jumping with the Air Strike.
    {
        returnValue.Value = view_as<float>(returnValue.Value) / 0.80;
        return MRES_Override;
    }
    else if (index == 351 || index == 740) // Use old Detonator/Scorch Shot explosion radius.
    {
        returnValue.Value = view_as<float>(92.00);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn WeaponReloaded(int entity)
{
    int secondaryWeapon = GetPlayerWeaponSlot(allEntities[entity].Owner, TFWeaponSlot_Secondary);
    if (secondaryWeapon != -1 && GetWeaponIndex(entity) == 220 && GetEntProp(secondaryWeapon, Prop_Send, "m_iPrimaryAmmoType") == SCOUT_PISTOL_AMMO_TYPE) // Shortstop using secondary ammo reserve.
    {
        int newAmmo = GetWeaponAmmoReserve(entity) - (MAX_SHORTSTOP_CLIP - GetEntProp(entity, Prop_Send, "m_iClip1"));
        SetWeaponAmmoReserve(secondaryWeapon, intMax(newAmmo, 0));
    }
    return MRES_Ignored;
}

MRESReturn WeaponReload(int entity)
{
    return MRES_Ignored;
}

MRESReturn WeaponPrimaryFire(int entity)
{
    int index = GetWeaponIndex(entity);
    int owner = allEntities[entity].Owner;
    if (index == 61 || index == 1006) // Ambassador headshot cooldown.
        RequestFrame(SetSpreadInaccuracy, owner); // SDKHook_TraceAttack/SDKHook_OnTakeDamage are both called only after this function is invoked.
    else if (entity == GetPlayerWeaponSlot(owner, TFWeaponSlot_Melee)) // Charge on charge kill.
    {
        allPlayers[owner].GiveChargeOnKill = false;
        if (GetGameTime() - allPlayers[owner].TimeSinceShieldBash < 0.5 || TF2_IsPlayerInCondition(owner, TFCond_Charging))
            allPlayers[owner].GiveChargeOnKill = true;
    }
    else if (index == 528) // Short Circuit projectile removal. Most of the code is sampled from the post-Gun Mettle Short Circuit alt-fire.
    {
        // Set up variables.
        ShortCircuit_CurrentCollectedEntities = 0;

        // Vector vecEye = pOwner->EyePosition(); 
        float vecEye[3];
        GetClientEyePosition(owner, vecEye);

        // Vector vecForward, vecRight, vecUp;
        float vecForward[3];
        float vecRight[3];
        float vecUp[3];

        // AngleVectors( pOwner->EyeAngles(), &vecForward, &vecRight, &vecUp );
        float vecEyeAngles[3];
        GetClientEyeAngles(owner, vecEyeAngles);
        GetAngleVectors(vecEyeAngles, vecForward, vecRight, vecUp);

        /*
        Vector vecSize = Vector( 128, 128, 64 );
        float flMaxElement = 0.0f;
        for ( int i = 0; i < 3; ++i )
        {
            flMaxElement = MAX( flMaxElement, vecSize[i] );
        }
        Vector vecCenter = vecEye + vecForward * flMaxElement;
        */
        float vecCenter[3];
        ScaleVector(vecForward, 128.00);
        AddVectors(vecEye, vecForward, vecCenter);

        /*
        // Get a list of entities in the box defined by vecSize at VecCenter.
        // We will then try to deflect everything in the box.
        const int maxCollectedEntities = 64;
        CBaseEntity	*pObjects[ maxCollectedEntities ];
        int count = UTIL_EntitiesInBox( pObjects, maxCollectedEntities, vecCenter - vecSize, vecCenter + vecSize, FL_GRENADE | FL_CLIENT | FL_FAKECLIENT );
        */
        float mins[3] = { -128.00, -128.00, -64.00 };
        float maxs[3] = { 128.00, 128.00, 64.00 };
        TR_TraceHullFilter(vecEye, vecCenter, mins, maxs, MASK_SOLID, TR_ShortCircuitProjectileRemoval, owner);
    }
    else if (index == 402 && TF2_IsPlayerInCondition(owner, TFCond_Slowed)) // Bazaar Bargain head counter: lose a head.
        allPlayers[owner].BazaarBargainShot = BazaarBargain_Lose;
    allPlayers[owner].TicksSinceAttack = GetGameTickCount();
    return MRES_Ignored;
}

MRESReturn WeaponSecondaryFire(int entity)
{
    int index = GetWeaponIndex(entity);
    int owner = allEntities[entity].Owner;
    if 
    (
        index == 220 || // Shortstop shove prevention. Because of client prediction though, the animation still plays a frame or so, so this is paired with extending the next secondary attack, though that doesn't stop the shove when reloading.
        index == 159 || index == 433 || // Prevent the Dalokohs Bar from being dropped.
        index == 998 && allPlayers[owner].UsingVaccinatorUber // The player is using Vaccinator Uber at the moment.
    ) 
        return MRES_Supercede;
    else if (!allPlayers[owner].UsingVaccinatorUber && index == 998 && SDKCall(SDKCall_CWeaponMedigun_CanAttack, entity) && GetEntPropFloat(entity, Prop_Send, "m_flChargeLevel") >= 0.25 && CanReceiveMedigunChargeEffect(owner, GetChargeType(entity))) // Vaccinator Uber.
    {
        allPlayers[owner].UsingVaccinatorUber = true;
        allPlayers[owner].VaccinatorHealers[owner] = true;
        allPlayers[owner].VaccinatorCharge = float(RoundToFloor(GetEntPropFloat(entity, Prop_Send, "m_flChargeLevel") * 4)) / 4;
        allPlayers[owner].EndVaccinatorChargeFalloff = allPlayers[owner].VaccinatorCharge - 0.25;
    }
    allPlayers[owner].TicksSinceAttack = GetGameTickCount();
    return MRES_Ignored;
}

MRESReturn GetMinigunWeaponSpread(int entity, DHookReturn returnValue)
{
    float spread = SDKCall(SDKCall_CTFWeaponBaseGun_GetWeaponSpread, entity);
    float firingDuration = GetGameTime() - allEntities[entity].TimeSinceMinigunFiring;
    if (firingDuration < TF_MINIGUN_PENALTY_PERIOD)
        spread *= RemapValClamped(firingDuration, 0.0, TF_MINIGUN_PENALTY_PERIOD, TF_MINIGUN_MAX_SPREAD, 1.0);
    returnValue.Value = spread;
    return MRES_Supercede;
}

MRESReturn GetMinigunDamage(int entity, DHookReturn returnValue)
{
    float damage = SDKCall(SDKCall_CTFWeaponBaseGun_GetProjectileDamage, entity);
    float firingDuration = GetGameTime() - allEntities[entity].TimeSinceMinigunFiring;
    if (firingDuration < TF_MINIGUN_PENALTY_PERIOD)
        damage *= RemapValClamped(firingDuration, 0.2, TF_MINIGUN_PENALTY_PERIOD, 0.5, 1.0);
    returnValue.Value = damage;
    return MRES_Supercede;
}

MRESReturn GetBazaarBargainChargeRate(int entity, DHookReturn returnValue)
{
    // I am not entirely sure whether this is correct or not. Might consider installing SourceMod on one of my older builds of TF2.
    // Change the recharge rate for the Bazaar Bargain.
    returnValue.Value = 0.2 * (intMin(GetEntProp(allEntities[entity].Owner, Prop_Send, "m_iDecapitations"), MAX_HEAD_BONUS) - 1) * TF_WEAPON_SNIPERRIFLE_CHARGE_PER_SEC;
    return MRES_Supercede;
}

MRESReturn OrnamentExplode(int entity) // Guys I think I actually fixed the Wrap Assassin... Quite unbelievable. (Just prevent the ornament from exploding. It'll roll on the ground instead like a stun ball.)
{
    return MRES_Supercede;
}

MRESReturn CAmmoPack_OnAmmoTouch(int entity, DHookReturn returnValue, DHookParam parameters)
{
    int client = GetEntityFromAddress(parameters.Get(1));
    if (DoesPlayerHaveItem(client, 404)) // Health pickup with the Persian Persuader.
    {
        returnValue.Value = false;
        int health = GetClientHealth(client);
        if (health < allPlayers[client].MaxHealth)
        {
            // Get amount to heal.
            int heal = RoundFloat(40 * PackRatios[SDKCall(SDKCall_CAmmoPack_GetPowerupSize, entity)]);

            // Show that the player got healed.
            Handle event = CreateEvent("player_healonhit", true);
            SetEventInt(event, "amount", heal);
            SetEventInt(event, "entindex", client);
            FireEvent(event);

            // Set health.
            SetEntityHealth(client, intMin(health + heal, allPlayers[client].MaxHealth));
            EmitSoundToAll("items\\gunpickup2.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL);
            returnValue.Value = true;

            // todo: play pickup sound.
        }
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn WeaponEquipped(int entity, DHookParam parameters)
{
    int client = parameters.Get(1);
    if (client > 0 && client <= MaxClients && TF2_GetPlayerClass(client) == TFClass_Engineer && entity == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
        DestroyAllBuildings(client);
    return MRES_Ignored;
}

MRESReturn WeaponDetached(int entity)
{
    int client = allEntities[entity].Owner;
    if (client > 0 && client <= MaxClients && TF2_GetPlayerClass(client) == TFClass_Engineer && entity == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
    {
        if (IsMannVsMachineMode() && TF2_GetClientTeam(client) != TFTeam_Red) // MvM Engineer bots should have their buildings left alone.
            return MRES_Ignored;
        DestroyAllBuildings(client);
    }
    return MRES_Ignored;
}

MRESReturn MedigunItemPostFrame(int entity)
{
    if (allPlayers[allEntities[entity].Owner].UsingVaccinatorUber) // Prevent resistance cycling while Ubering with the Vaccinator.
        WriteToValue(GetEntityAddress(entity) + CWeaponMedigun_m_bReloadDown, true, NumberType_Int8);
    return MRES_Ignored;
}

MRESReturn CommandRepair(int entity, DHookReturn returnValue, DHookParam parameters)
{
    parameters.Set(4, 5.00); // This is the parameter responsible for the HP per point of metal.
    return MRES_ChangedHandled;
}

MRESReturn StartBuilding(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (GetEntProp(entity, Prop_Send, "m_bMiniBuilding")) // Mini sentries always start off at max health.
        WriteToValue(GetEntityAddress(entity) + CObjectBase_m_flHealth, 100.00);
    return MRES_Ignored;
}

MRESReturn PreConstructBuilding(int entity, DHookReturn returnValue, DHookParam parameters)
{
    allEntities[entity].BuildingHealth = Dereference(GetEntityAddress(entity) + CObjectBase_m_flHealth);
    return MRES_Ignored;
}

MRESReturn PostConstructBuilding(int entity, DHookReturn returnValue, DHookParam parameters)
{
    Address m_flHealth = GetEntityAddress(entity) + CObjectBase_m_flHealth;
    if (GetEntProp(entity, Prop_Send, "m_bMiniBuilding")) // Prevent mini sentries from gaining health while being built. Usually only an issue if the building has been damaged during construction time.
    {
        if (SDKCall(SDKCall_CBaseObject_GetReversesBuildingConstructionSpeed, entity))
            WriteToValue(m_flHealth, view_as<float>(Dereference(m_flHealth)) + GetBuildingConstructionMultiplier_NoHook(entity) * 0.5);
        else
            WriteToValue(m_flHealth, allEntities[entity].BuildingHealth);
    }
    return MRES_Ignored;
}

MRESReturn PlantSapperOnBuilding(int entity)
{
    int building = GetEntPropEnt(entity, Prop_Send, "m_hBuiltOnEntity");
    if (IsValidEntity(building))
        allEntities[building].AttachedSapper = entity;
    return MRES_Ignored;
}

MRESReturn PreSentryWrenchHit(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (GetEntProp(entity, Prop_Send, "m_bMiniBuilding")) // Do not allow reparations on mini sentries.
    {
        returnValue.Value = false;
        return MRES_Supercede;
    }
    allEntities[entity].OldShield = GetEntProp(entity, Prop_Send, "m_nShieldLevel");
    SetEntProp(entity, Prop_Send, "m_nShieldLevel", SHIELD_NONE);
    return MRES_Ignored;
}

MRESReturn PostSentryWrenchHit(int entity, DHookReturn returnValue, DHookParam parameters)
{
    SetEntProp(entity, Prop_Send, "m_nShieldLevel", allEntities[entity].OldShield);
    return MRES_Ignored;
}

MRESReturn HealPlayerWithCrossbow(int entity, DHookParam parameters)
{
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if (client > 0) // Do not grant Uber with the crossbow.
        SetEntPropFloat(DoesPlayerHaveItemByClass(client, "tf_weapon_medigun"), Prop_Send, "m_flChargeLevel", allPlayers[client].CurrentUber);
    return MRES_Ignored;
}

MRESReturn GetBuildingCost(DHookReturn returnValue, DHookParam parameters)
{
    if (parameters.Get(1) == OBJ_TELEPORTER) // Revert the teleporter cost to 125. This won't affect the client however...
    {
        returnValue.Value = 125;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn GetTFClassData(DHookReturn returnValue, DHookParam parameters)
{
    // This is called whenever TF2 wants to grab the data of a specific class.
    // Modify the Spy's default speed to be 300HU/s instead of 320HU/s.
    if (SpyClassData == Address_Null && parameters.Get(1) == TFClass_Spy)
    {
        SpyClassData = view_as<Address>(returnValue.Value);
        WriteToValue(SpyClassData + TFPlayerClassData_t_m_flMaxSpeed, 300.00);
    }
    return MRES_Ignored;
}

MRESReturn IsRoundTimerActive(DHookReturn returnValue)
{
    if (IsSetup() && BypassRoundTimerChecks) // Only also called with this function for the Medigun faster Uber build. Very hacky but it stops the Medic from building faster Uber during setup time.
    {
        returnValue.Value = false;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn CalculateMaxSpeed(int entity, DHookReturn returnValue)
{
    int activeWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
    if (TF2_IsPlayerInCondition(entity, TFCond_CritCola) && TF2_GetPlayerClass(entity) == TFClass_Scout) // Crit-a-Cola speed boost.
    {
        returnValue.Value = view_as<float>(returnValue.Value) * 1.25;
        return MRES_Override;
    }
    else if (GetEntProp(entity, Prop_Send, "m_bCarryingObject") && !IsMannVsMachineMode() && !TF2_IsPlayerInCondition(entity, TFCond_HalloweenBombHead)) // If an Engineer is carrying a building, slow him down by 25% instead of 10%.
    {
        returnValue.Value = view_as<float>(returnValue.Value) / 0.90 * 0.75;
        return MRES_Override;
    }
    else if (IsValidEntity(activeWeapon) && GetWeaponIndex(activeWeapon) != 411 && StrEqual(allEntities[activeWeapon].Class, "tf_weapon_medigun") && GetEntPropEnt(activeWeapon, Prop_Send, "m_hHealingTarget") != -1) // The player is a Medic who is not using the Quick-Fix and is healing a target. In that case, do not mirror their target's speed.
    {
        returnValue.Value = 320.00;
        return MRES_Override;
    }
    return MRES_Ignored;
}

MRESReturn CanAirDash(int entity, DHookReturn returnValue)
{
    // Re-writing everything is probably the easiest way, this is a small function after all.
    if (TF2_IsPlayerInCondition(entity, TFCond_HalloweenKart)) // Halloween bumper karts.
        returnValue.Value = false;
    else if (TF2_IsPlayerInCondition(entity, TFCond_HalloweenSpeedBoost)) // Halloween speed boost.
        returnValue.Value = true;
    else if (TF2_GetPlayerClass(entity) == TFClass_Scout)
    {
        int airDashCount = GetEntProp(entity, Prop_Send, "m_iAirDash");
        if (TF2_IsPlayerInCondition(entity, TFCond_CritHype) && airDashCount < 5) // Soda Popper multi-jump.
            returnValue.Value = true;
        else if (DoesPlayerHaveItem(entity, 450) && airDashCount < 2) // Atomizer passive triple jump.
        {
            returnValue.Value = true;
            if (airDashCount == 1)
            {
                char path[PLATFORM_MAX_PATH];
                Format(path, PLATFORM_MAX_PATH, "physics\\flesh\\flesh_impact_bullet%i.wav", GetRandomInt(1, FLESH_IMPACT_BULLET_COUNT));
                SDKHooks_TakeDamage(entity, entity, entity, 10.00, (DMG_BLAST_SURFACE | DMG_PREVENT_PHYSICS_FORCE));
                EmitSoundToClient(entity, path);
            }
        }
        else if (GetEntProp(entity, Prop_Send, "m_iAirDash") < 1) // Normal double jump.
            returnValue.Value = true;
        else
            returnValue.Value = false;
    }
    else
        returnValue.Value = false;

    return MRES_Supercede;
}

MRESReturn UseTaunt(int entity, DHookParam parameters)
{
    int activeWeapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
    if (IsValidEntity(activeWeapon) && GetWeaponIndex(activeWeapon) == 594 && parameters.Get(1) == TAUNT_BASE_WEAPON && GetEntPropFloat(entity, Prop_Send, "m_flRageMeter") == 100) // Is player using mmmph with the Phlog?
    {
        allPlayers[entity].TicksSinceMmmphUsage = GetGameTickCount();
        TF2_AddCondition(entity, TFCond_DefenseBuffMmmph, 3.0); // Old mmmph defense.
        if (GetEntProp(entity, Prop_Send, "m_iHealth") < allPlayers[entity].MaxHealth)
            SetEntityHealth(entity, allPlayers[entity].MaxHealth);
    }
    return MRES_Ignored;
}

MRESReturn PlayerHealthRegen(int entity)
{
    allPlayers[entity].RegenThink = true;
    return MRES_Ignored;
}

MRESReturn GetPlayerHealTarget(int entity, DHookReturn returnValue)
{
    if (allPlayers[entity].RegenThink) // Do not gain more HP over time from healing injured patients.
    {
        allPlayers[entity].RegenThink = false;
        returnValue.Value = false;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn ConfigureSniperFlinching(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (DoesPlayerHaveItem(entity, 642) && TF2_IsPlayerInCondition(entity, TFCond_Zoomed))
    {
        returnValue.Value = false;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn AddToSpycicleMeter(int entity, DHookReturn returnValue, DHookParam parameters)
{
    // Prevent ammo pick-up with the Spy-cicle.
    returnValue.Value = false;
    return MRES_Supercede;
}

MRESReturn AddCondition(Address thisPointer, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    TFCond condition = parameters.Get(1);
    if (condition == TFCond_MarkedForDeathSilent && TF2_IsPlayerInCondition(client, TFCond_CritCola) && allPlayers[client].TicksSinceAttack == GetGameTickCount()) // Do not mark the player for death when using Crit-a-Cola.
        return MRES_Supercede;
    else if ((condition == TFCond_UberchargedCanteen || condition == TFCond_MegaHeal) && allPlayers[client].TicksSinceMmmphUsage == GetGameTickCount()) // Phlog invulnerability/knockback prevention.
        return MRES_Supercede;
    else if (condition == TFCond_SpeedBuffAlly)
    {
        if (allPlayers[client].TicksSinceSpeedBoost == GetGameTickCount()) // Set the speed boost on targets to 3s from the Disciplinary Action.
        {
            parameters.Set(2, 3.0);
            return MRES_ChangedHandled;
        }
        else if (allPlayers[client].TicksSinceFeignReady == GetGameTickCount()) // Prevent the Spy from getting a speed boost just from feigning.
            return MRES_Supercede;
    }
    else if (condition == TFCond_Charging) // Set the player's TicksSinceCharge value. This is necessary for preventing debuffs from being removed via charging.
        allPlayers[client].TicksSinceCharge = GetGameTickCount();
    else if ((condition == TFCond_RestrictToMelee || condition == TFCond_CritCola) && allPlayers[client].TicksSinceConsumingSandvich == GetGameTickCount()) // Shorten the Buffalo Steak Sandvich effects duration to 15s.
    {
        parameters.Set(2, LUNCHBOX_ADDS_MINICRITS_DURATION);
        return MRES_ChangedHandled;
    }
    else if (condition == TFCond_UberBulletResist || condition == TFCond_UberBlastResist || condition == TFCond_UberFireResist) // Vaccinator Uber should only last 2s.
    {
        parameters.Set(2, 2.0);
        return MRES_ChangedHandled;
    }
    else if (condition == TFCond_Cloaked && DoesPlayerHaveItem(client, 59)) // Simplify feign checks with the Dead Ringer.
    {
        allPlayers[client].FeigningDeath = true;
        allPlayers[client].DamageTakenDuringFeign = 0.00;
        TF2_RemoveCondition(client, TFCond_OnFire); // Extinguish the player.
    }
    else if (condition == TFCond_CloakFlicker && allPlayers[client].FeigningDeath && GetFeignBuffsEnd(client) >= GetGameTickCount()) // Prevent bump shimmers while feigning with the Dead Ringer.
        return MRES_Supercede;
    else if (condition == TFCond_AfterburnImmune && allPlayers[client].TicksSinceFeignReady == GetGameTickCount()) // Do not provide afterburn immunuity.
        return MRES_Supercede;
    else if (condition == TFCond_Slowed && GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) // Modify checks for the Sydney Sleeper.
        allPlayers[client].TimeSinceScoping = GetGameTime();
    else if (condition == TFCond_Dazed && allPlayers[client].TicksSinceBonkEnd == GetGameTickCount()) // Do not suffer from BONK! slowdown.
        return MRES_Supercede;
    return MRES_Ignored;
}

MRESReturn RemoveCondition(Address thisPointer, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    TFCond condition = parameters.Get(1);
    if (allPlayers[client].TicksSinceCharge == GetGameTickCount()) // Prevent player debuffs from being removed via charging.
    {
        for (int i = 0; i < sizeof(g_aDebuffConditions); ++i)
        {
            if (condition == g_aDebuffConditions[i])
                return MRES_Supercede;
        }
    }
    else if (condition == TFCond_Cloaked && allPlayers[client].FeigningDeath) // End feign death with the Dead Ringer.
    {
        allPlayers[client].FeigningDeath = false;
        if (GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") > 40.00) // Set the cloak meter to 40% when ending feign death.
            SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 40.00);
    }
    else if (condition == TFCond_Parachute) // Used to check for parachute redeployment.
        allPlayers[client].TimeSinceDeployment = GetGameTime();
    else if (condition == TFCond_Bonked) // Checks for BONK! slowdown.
        allPlayers[client].TicksSinceBonkEnd = GetGameTickCount();
    return MRES_Ignored;
}

MRESReturn CalculateChargeCrit(Address thisPointer, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    if (GetGameTime() - allPlayers[client].TimeSinceShieldBash < 0.5 && allPlayers[client].ChargeBashHitPlayer)
    {
        parameters.Set(1, true); // Set bForceCrit to true, so that the player's melee weapon will always crit on shield bash.
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

MRESReturn AddToCloak(Address thisPointer, DHookReturn returnValue, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    if (DoesPlayerHaveItem(client, 59)) // Only gain up to 35% cloak with the Dead Ringer.
    {
        parameters.Set(1, min(view_as<float>(parameters.Get(1)), 35.00)); // Force "val" to be no larger than 35.
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

// TODO - REVISIT PLEASE!
/*
MRESReturn HealPlayer(Address thisPointer, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    int healer = parameters.Get(1);
    if (TF2_GetPlayerClass(client) == TFClass_Heavy && allPlayers[client].MaxHealth == 350.00 && healer > 0 && DoesPlayerHaveItem(healer, 411) == GetEntPropEnt(healer, Prop_Send, "m_hActiveWeapon")) // Only overheal up to 375 HP with the Quick-Fix if the target is using the Dalokohs Bar.
    {
        parameters.Set(3, 1.082); // Really hacky and I need to find a better method for this.
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}
*/

MRESReturn CheckIfPlayerCanBeUbered(Address thisPointer, DHookReturn returnValue, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    returnValue.Value = CanReceiveMedigunChargeEffect(client, parameters.Get(1));
    return MRES_Supercede;
}

MRESReturn ModifyRageMeter(Address thisPointer, DHookParam parameters)
{
    int client = GetEntityFromAddress(Dereference(thisPointer + CTFPlayerShared_m_pOuter));
    if (TF2_GetPlayerClass(client) == TFClass_Pyro && DoesPlayerHaveItem(client, 594))
    {
        float delta = view_as<float>(parameters.Get(1));
        delta *= (300.00 / 225.00); // Take only 225 damage to build up the Phlog rage meter. This is hacky but it's simple, at least.
        parameters.Set(1, delta);
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

MRESReturn OnMeleeSwingHit(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (GetWeaponIndex(entity) == 447) // Disciplinary Action speed boost. (This code only cares about the victim, the player using the Disciplinary Action already has their speed boost duration set to 3.6s.)
    {
        int victim = GetEntityFromAddress(Dereference(view_as<Address>(parameters.Get(1)) + CGameTrace_m_pEnt));
        int client = allEntities[entity].Owner;
        if (victim > 0 && victim <= MaxClients && (TF2_GetClientTeam(victim) == TF2_GetClientTeam(client) || (TF2_IsPlayerInCondition(victim, TFCond_Disguised) && TF2_GetClientTeam(victim) != TF2_GetClientTeam(client)))) // The speed boost applies to both disguised enemy Spies or teammates.
            allPlayers[victim].TicksSinceSpeedBoost = GetGameTickCount();
    }
    return MRES_Ignored;
}

MRESReturn OnMinigunSharedAttack(int entity)
{
    switch (GetEntProp(entity, Prop_Send, "m_iWeaponState"))
    {
        case AC_STATE_FIRING:
        {
            if (allEntities[entity].TimeSinceMinigunFiring <= 0)
                allEntities[entity].TimeSinceMinigunFiring = GetGameTime();
        }
        case AC_STATE_DRYFIRE, AC_STATE_SPINNING, AC_STATE_IDLE:
        {
            allEntities[entity].TimeSinceMinigunFiring = 0.0;
        }
    }
    return MRES_Ignored;
}

MRESReturn BreakRazorback(int entity)
{
    if (GetWeaponIndex(entity) == 57) // Delete the Razorback entirely. This is basically how the old Razorback functioned.
        RemoveEntity(entity);
    return MRES_Ignored;
}

MRESReturn OnShieldBash(int entity)
{
    /*
    Vector vecForward; 
	AngleVectors( pOwner->EyeAngles(), &vecForward );
	Vector vecStart = pOwner->Weapon_ShootPosition();
	Vector vecEnd = vecStart + vecForward * 48;

	// See if we hit anything.
	trace_t trace;
	UTIL_TraceHull( vecStart, vecEnd, -Vector(24,24,24), Vector(24,24,24),
		MASK_SOLID, pOwner, COLLISION_GROUP_NONE, &trace );
    */

    // Set charge bash.
    int client = allEntities[entity].Owner;
    allPlayers[client].TimeSinceShieldBash = GetGameTime();
    allPlayers[client].ChargeBashHitPlayer = false;

    // Set up vectors and set up a trace.
    float vecEyeAngles[3];
    float vecForward[3];
    float vecStart[3];
    float vecEnd[3];
    float vecMin[3] = {-24.00, -24.00, -24.00};
    float vecMax[3] = {24.00, 24.00, 24.00};

    GetClientEyeAngles(client, vecEyeAngles);
    GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
    GetClientEyePosition(client, vecStart);
    ScaleVector(vecForward, 48.00);
    AddVectors(vecStart, vecForward, vecEnd);
    Handle trace = TR_TraceHullFilterEx(vecStart, vecEnd, vecMin, vecMax, MASK_SOLID, TR_CheckForTargetPlayer, client);

    // Check if we hit a player.
    int player = TR_GetEntityIndex(trace);
    if (TR_DidHit(trace) && player > 0 && player <= MaxClients)
        allPlayers[client].ChargeBashHitPlayer = true;
    
    delete trace;
    return MRES_Ignored;
}

MRESReturn CTFAmmoPack_OnAmmoTouch(int entity, DHookParam parameters)
{
    int client = parameters.Get(1);
    if (client > 0 && client <= MaxClients && DoesPlayerHaveItem(client, 404)) // Health pickup with the Persian Persuader from dropped ammo packs.
    {
        int health = GetClientHealth(client);
        if (health < allPlayers[client].MaxHealth)
        {
            // Show that the player got healed.
            Handle event = CreateEvent("player_healonhit", true);
            SetEventInt(event, "amount", 20);
            SetEventInt(event, "entindex", client);
            FireEvent(event);

            // Set health.
            SetEntityHealth(client, intMin(health + 20, allPlayers[client].MaxHealth));
            RemoveEntity(entity);
        }
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn ApplyBiteEffects(int entity)
{
    int index = GetWeaponIndex(entity);
    if (index == 311) // Buffalo Steak Sandvich.
        allPlayers[allEntities[entity].Owner].TicksSinceConsumingSandvich = GetGameTickCount();
    return MRES_Ignored;
}

MRESReturn RemoveSandvichAmmo(int entity)
{
    int index = GetWeaponIndex(entity);
    if (index == 159 || index == 433) // Prevent ammo usage from the Dalokohs Bar; allow the player to eat forever.
        return MRES_Supercede;
    return MRES_Ignored;
}

MRESReturn PreFindAndHealTarget(int entity)
{
    BypassRoundTimerChecks = true;
    return MRES_Ignored;
}

MRESReturn PostFindAndHealTarget(int entity)
{
    BypassRoundTimerChecks = false;
    return MRES_Ignored;
}

MRESReturn BuildingConstructionHit(int entity, DHookParam parameters)
{
    // The actual function is still called just for the sparking effects.
    if (!GetEntProp(entity, Prop_Send, "m_bMiniBuilding")) // Do not allow mini sentries to be construction boosted.
    {
        int client = parameters.Get(1);
        allEntities[entity].ConstructionBoostExpiryTimes[client] = GetGameTime() + 1;
        allEntities[entity].ConstructionBoosts[client] = SDKCall(SDKCall_CTFWrench_GetConstructionValue, parameters.Get(2));
    }
    return MRES_Ignored;
}

MRESReturn GetBuildingConstructionMultiplier(int entity, DHookReturn returnValue)
{
    // The actual function is still called so the CUtlMap is still properly managed.
    returnValue.Value = GetBuildingConstructionMultiplier_NoHook(entity);
    return MRES_Override;
}

MRESReturn CreateBuildingGibs(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (GetEntProp(entity, Prop_Send, "m_bMiniBuilding")) // Allow metal to be picked up from mini sentry gibs.
    {
        parameters.Set(2, 7);
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

MRESReturn PreHealingBoltImpact(int entity, DHookParam parameters)
{
    // Fake the metal count to allow free healing.
    int client = allEntities[GetEntPropEnt(entity, Prop_Send, "m_hLauncher")].Owner;
    allPlayers[client].OldMetalCount = GetEntProp(client, Prop_Send, "m_iAmmo", _, view_as<int>(TF_AMMO_METAL));
    SetEntProp(client, Prop_Send, "m_iAmmo", 200, _, view_as<int>(TF_AMMO_METAL));

    // Fake the sentry's shield to allow for maximum healing potential.
    int sentry = parameters.Get(1);
    if (IsValidEntity(sentry) && HasEntProp(sentry, Prop_Send, "m_nShieldLevel"))
    {
        allEntities[sentry].OldShield = GetEntProp(sentry, Prop_Send, "m_nShieldLevel");
        SetEntProp(sentry, Prop_Send, "m_nShieldLevel", SHIELD_NONE);
    }
    return MRES_Ignored;
}

MRESReturn PostHealingBoltImpact(int entity, DHookParam parameters)
{
    // Revert the metal count.
    int client = allEntities[GetEntPropEnt(entity, Prop_Send, "m_hLauncher")].Owner;
    SetEntProp(client, Prop_Send, "m_iAmmo", allPlayers[client].OldMetalCount, _, view_as<int>(TF_AMMO_METAL));

    // Revert the sentry's shield.
    int sentry = parameters.Get(1);
    if (IsValidEntity(sentry) && HasEntProp(sentry, Prop_Send, "m_nShieldLevel"))
        SetEntProp(sentry, Prop_Send, "m_nShieldLevel", allEntities[sentry].OldShield);
    return MRES_Ignored;
}

MRESReturn ApplyDamageRules(Address thisPointer, DHookReturn returnValue, DHookParam parameters)
{
    int victim = parameters.Get(2);
    if (victim > 0 && victim <= MaxClients)
    {
        Address info = parameters.Get(1);
        int bitsDamageType = Dereference(info + CTakeDamageInfo_m_bitsDamageType);
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (allPlayers[victim].VaccinatorHealers[i] && bitsDamageType & resistanceMapping[GetResistType(DoesPlayerHaveItem(i, 998))])
            {
                allPlayers[victim].TicksSinceApplyingDamageRules = GetGameTickCount();
                tf_weapon_minicrits_distance_falloff.BoolValue = true;
                tf_weapon_criticals_distance_falloff.BoolValue = true;
                break;
            }
        }
    }

    return MRES_Ignored;
}

MRESReturn ApplyDamageRules_Post(Address thisPointer, DHookReturn returnValue, DHookParam parameters)
{
    int victim = parameters.Get(2);
    if (victim > 0 && victim <= MaxClients && allPlayers[victim].TicksSinceApplyingDamageRules == GetGameTickCount())
    {
        Address info = parameters.Get(1);
        allPlayers[victim].ActualDamageType = Dereference(info + CTakeDamageInfo_m_bitsDamageType);
        allPlayers[victim].ActualCritType = Dereference(info + CTakeDamageInfo_m_eCritType);
        tf_weapon_minicrits_distance_falloff.BoolValue = tf_weapon_minicrits_distance_falloff_original;
        tf_weapon_criticals_distance_falloff.BoolValue = tf_weapon_criticals_distance_falloff_original;
    }
    return MRES_Ignored;
}

//////////////////////////////////////////////////////////////////////////////
// TRACE FILTERS                                                            //
//////////////////////////////////////////////////////////////////////////////

bool TR_CheckForTargetPlayer(int entity, int mask, int client)
{
    return entity != client && entity > 0 && entity <= MaxClients;
}

bool TR_ShortCircuitProjectileRemoval(int entity, int mask, int client)
{
    // Entity checks.
    int ammo = GetEntProp(client, Prop_Send, "m_iAmmo", 4, view_as<int>(TF_AMMO_METAL));
    if 
    (
        ShortCircuit_CurrentCollectedEntities == ShortCircuit_MaxCollectedEntities || // Reached the maximum number of collected entities.
        !( // Is the entity not one of the following:
            StrEqual(allEntities[entity].Class, "tf_projectile_rocket") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_sentryrocket") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_pipe") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_pipe_remote") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_arrow") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_flare") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_stun_ball") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_ball_ornament") ||
            StrEqual(allEntities[entity].Class, "tf_projectile_cleaver")
        ) ||
        GetEntProp(client, Prop_Send, "m_iAmmo", 4, view_as<int>(TF_AMMO_METAL)) < 15 || // Does the user not have enough metal?
        GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetEntProp(client, Prop_Send, "m_iTeamNum") // Is the entity from the same team as the the player using the Short Circuit?
    )
        return false;


    // Delete the entity.
    RemoveEntity(entity);
    SetEntProp(client, Prop_Send, "m_iAmmo", ammo - 15, 4, view_as<int>(TF_AMMO_METAL));

    // Always return false to act as an enumerator.
    return false;
}

//////////////////////////////////////////////////////////////////////////////
// OTHER HOOKS                                                              //
//////////////////////////////////////////////////////////////////////////////

public Action SoundPlayed(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
    if (StrContains(sample, "pl_impact_stun") != -1)
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (allPlayers[i].TickSinceBonk == GetGameTickCount()) // Stop BONK! stun sound effect. Can't remove TFCond_Dazed here though - the condition is not applied yet.
                return Plugin_Stop;
            else if (StrEqual(allEntities[allPlayers[i].MostRecentProjectileEncounter].Class, "tf_projectile_stun_ball") && allPlayers[i].TicksSinceProjectileEncounter == GetGameTickCount()) // Remove duplicate stun sound fron Sandman.
                return Plugin_Stop;
        }
    }
    else if (StrContains(sample, "pl_fallpain") != -1)
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (allPlayers[i].TicksSinceFallDamage == GetGameTickCount()) // Stop playing the original fall damage sound.
            {
                if (!DoesPlayerHaveItem(i, 773)) // Play the old fall damage sound if the user is not using the Pretty Boy's Pocket Pistol.
                {
                    strcopy(sample, PLATFORM_MAX_PATH, "player\\pl_fleshbreak.wav");
                    pitch = 92;
                    return Plugin_Changed;
                }
                return Plugin_Stop;
            }
        }
    }
    else if (StrContains(sample, "PainSevere") != -1)
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (allPlayers[i].TicksSinceFallDamage == GetGameTickCount()) // Just a small minor change because I am a perfectionist. Don't play the pain severe sounds when taking fall damage.
                return Plugin_Stop;
        }
    }
    else if (StrContains(sample, "weapons\\shotgun_worldreload.wav") != -1)
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (allPlayers[i].TicksSinceFiring == GetGameTickCount() + 1 && DoesPlayerHaveItem(i, 1153)) // Stop Panic Attack reload sound when reaching full clip.
                return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

//////////////////////////////////////////////////////////////////////////////
// MEMORY                                                                   //
//////////////////////////////////////////////////////////////////////////////

int LoadEntityHandleFromAddress(Address addr) // From nosoop's stocksoup framework.
{
    return EntRefToEntIndex(LoadFromAddress(addr, NumberType_Int32) | (1 << 31));
}

int GetEntityFromAddress(Address pEntity) // From nosoop's stocksoup framework.
{
    static int offs_RefEHandle;
    if (offs_RefEHandle) 
    {
        return LoadEntityHandleFromAddress(pEntity + view_as<Address>(offs_RefEHandle));
    }

    // if we don't have it already, attempt to lookup offset based on SDK information
    // CWorld is derived from CBaseEntity so it should have both offsets
    int offs_angRotation = FindDataMapInfo(0, "m_angRotation"), offs_vecViewOffset = FindDataMapInfo(0, "m_vecViewOffset");
    if (offs_angRotation == -1) 
    {
        ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_angRotation");
    }
    else if (offs_vecViewOffset == -1) 
    {
        ThrowError("Could not find offset for ((CBaseEntity) CWorld)::m_vecViewOffset");
    } 
    else if ((offs_angRotation + 0x0C) != (offs_vecViewOffset - 0x04)) 
    {
        char game[32];
        GetGameFolderName(game, sizeof(game));
        ThrowError("Could not confirm offset of CBaseEntity::m_RefEHandle "
                ... "(incorrect assumption for game '%s'?)", game);
    }

    // offset seems right, cache it for the next call
    offs_RefEHandle = offs_angRotation + 0x0C;
    return GetEntityFromAddress(pEntity);
}

any Dereference(Address address, NumberType bitdepth = NumberType_Int32)
{
	return LoadFromAddress(address, bitdepth);
}

void WriteToValue(Address address, any value, NumberType bitdepth = NumberType_Int32)
{
    StoreToAddress(address, value, bitdepth);
}
