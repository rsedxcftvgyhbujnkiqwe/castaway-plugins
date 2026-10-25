//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// The flamethrower ammo management in DHookCallback_PrimaryAttack_Post is
// hacky and due for a re-write.

// For TF2 attributes, this uses nosoop's tf2attributes plugin, which is a fork of FlaminSarge's.

// The address read/write helpers at the bottom of this file are vendored
// leftovers from SM-Memory and SMTC; neither extension is used anymore
// (memory patches go through SourceScramble).

#pragma semicolon true
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <tf2attributes>
#include <dhooks>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2utils>

#define PLUGIN_NAME "old-flame-mechanics"

#define TF_FLAMETHROWER_MUZZLEPOS_FORWARD		70.00
#define TF_FLAMETHROWER_MUZZLEPOS_RIGHT			12.00
#define TF_FLAMETHROWER_MUZZLEPOS_UP			-12.00

#define OFM_CUTLVECTOR_SIZE 20
#define VECTOR_SIZE         12

// i'm not including the entire enum for this LOL
// ai_activity.h
#define ACT_VM_PRIMARYATTACK 180

#define WL_None 0
#define WL_Feet 1
#define WL_Waist 2
#define WL_Eyes 3

#define DMGTYPE DMG_IGNITE | DMG_PREVENT_PHYSICS_FORCE

#define TF_FLAMETHROWER_AMMO_PER_SECOND_PRIMARY_ATTACK		14.00

// settings for m_takedamage
#define	DAMAGE_NO				0
#define DAMAGE_EVENTS_ONLY		1		// Call damage functions, but don't modify health
#define	DAMAGE_YES				2
#define	DAMAGE_AIM				3

#define TF_BURNING_DMG_OLD 3.00
#define TF_BURNING_DMG_NEW 4.00
#define TF_BURNING_FLAME_LIFE_PYRO	0.25		// pyro only displays burning effect momentarily
#define TF_BURNING_FLAME_LIFE		10.0
#define TF_BURNING_FLAME_LIFE_PLASMA 6.0

#define TF_WEAPON_PRIMARY_MODE		0
#define TF_WEAPON_SECONDARY_MODE	1

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

// CTFFlameEntity offsets. Should be used with offset_CTFFlameEntity_m_vecInitialPos.
enum
{
	CTFFlameEntity_m_vecInitialPos = 0,														// Vector m_vecInitialPos;
	CTFFlameEntity_m_vecPrevPos = CTFFlameEntity_m_vecInitialPos + VECTOR_SIZE,				// Vector m_vecPrevPos;
	CTFFlameEntity_m_vecBaseVelocity = CTFFlameEntity_m_vecPrevPos + VECTOR_SIZE,			// Vector m_vecBaseVelocity;
	CTFFlameEntity_m_vecAttackerVelocity = CTFFlameEntity_m_vecBaseVelocity + VECTOR_SIZE,	// Vector m_vecAttackerVelocity;
	CTFFlameEntity_m_flTimeRemove = CTFFlameEntity_m_vecAttackerVelocity + VECTOR_SIZE,		// float m_flTimeRemove;
	CTFFlameEntity_m_iDmgType = CTFFlameEntity_m_flTimeRemove + 4,							// int m_iDmgType;
	CTFFlameEntity_m_flDmgAmount = CTFFlameEntity_m_iDmgType + 4,							// float m_flDmgAmount;
	CTFFlameEntity_m_EntitiesBurnt = CTFFlameEntity_m_flDmgAmount + 4,						// CUtlVector<EHANDLE> m_hEntitiesBurnt;
	CTFFlameEntity_m_hAttacker = CTFFlameEntity_m_EntitiesBurnt + OFM_CUTLVECTOR_SIZE,		// EHANDLE m_hAttacker;
	CTFFlameEntity_m_bCritFromBehind = CTFFlameEntity_m_hAttacker + 4,						// bool m_bCritFromBehind;
	CTFFlameEntity_m_bBurnedEnemy = CTFFlameEntity_m_bCritFromBehind + 1,					// bool m_bBurnedEnemy;
	CTFFlameEntity_m_hFlameThrower = CTFFlameEntity_m_bBurnedEnemy + 2						// CHandle<CTFFlameThrower> m_hFlameThrower;
};

enum FlameThrowerState_t
{
	// Firing states.
	FT_STATE_IDLE = 0,
	FT_STATE_STARTFIRING,
	FT_STATE_FIRING,
	FT_STATE_SECONDARY,
};

enum PlayerAnimEvent_t
{
	PLAYERANIMEVENT_ATTACK_PRIMARY,
	PLAYERANIMEVENT_ATTACK_SECONDARY,
	PLAYERANIMEVENT_ATTACK_GRENADE,
	PLAYERANIMEVENT_RELOAD,
	PLAYERANIMEVENT_RELOAD_LOOP,
	PLAYERANIMEVENT_RELOAD_END,
	PLAYERANIMEVENT_JUMP,
	PLAYERANIMEVENT_SWIM,
	PLAYERANIMEVENT_DIE,
	PLAYERANIMEVENT_FLINCH_CHEST,
	PLAYERANIMEVENT_FLINCH_HEAD,
	PLAYERANIMEVENT_FLINCH_LEFTARM,
	PLAYERANIMEVENT_FLINCH_RIGHTARM,
	PLAYERANIMEVENT_FLINCH_LEFTLEG,
	PLAYERANIMEVENT_FLINCH_RIGHTLEG,
	PLAYERANIMEVENT_DOUBLEJUMP,

	// Cancel.
	PLAYERANIMEVENT_CANCEL,
	PLAYERANIMEVENT_SPAWN,

	// Snap to current yaw exactly
	PLAYERANIMEVENT_SNAP_YAW,

	PLAYERANIMEVENT_CUSTOM,				// Used to play specific activities
	PLAYERANIMEVENT_CUSTOM_GESTURE,
	PLAYERANIMEVENT_CUSTOM_SEQUENCE,	// Used to play specific sequences
	PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE,

	// TF Specific. Here until there's a derived game solution to this.
	PLAYERANIMEVENT_ATTACK_PRE,
	PLAYERANIMEVENT_ATTACK_POST,
	PLAYERANIMEVENT_GRENADE1_DRAW,
	PLAYERANIMEVENT_GRENADE2_DRAW,
	PLAYERANIMEVENT_GRENADE1_THROW,
	PLAYERANIMEVENT_GRENADE2_THROW,
	PLAYERANIMEVENT_VOICE_COMMAND_GESTURE,
	PLAYERANIMEVENT_DOUBLEJUMP_CROUCH,
	PLAYERANIMEVENT_STUN_BEGIN,
	PLAYERANIMEVENT_STUN_MIDDLE,
	PLAYERANIMEVENT_STUN_END,
	PLAYERANIMEVENT_PASSTIME_THROW_BEGIN,
	PLAYERANIMEVENT_PASSTIME_THROW_MIDDLE,
	PLAYERANIMEVENT_PASSTIME_THROW_END,
	PLAYERANIMEVENT_PASSTIME_THROW_CANCEL,

	PLAYERANIMEVENT_ATTACK_PRIMARY_SUPER,

	PLAYERANIMEVENT_COUNT
};

enum RuneTypes_t
{
	RUNE_NONE = -1,
	RUNE_STRENGTH,
	RUNE_HASTE,
	RUNE_REGEN,
	RUNE_RESIST,
	RUNE_VAMPIRE,
	RUNE_REFLECT,
	RUNE_PRECISION,
	RUNE_AGILITY,
	RUNE_KNOCKOUT,
	RUNE_KING,
	RUNE_PLAGUE,
	RUNE_SUPERNOVA,

	RUNE_TYPES_MAX
};

TFCond GetConditionFromRuneType( RuneTypes_t rt ) {
	switch (rt) {
		case RUNE_NONE:			return view_as<TFCond>(-1);
		case RUNE_STRENGTH:		return TFCond_RuneStrength;
		case RUNE_HASTE:		return TFCond_RuneHaste;
		case RUNE_REGEN:		return TFCond_RuneRegen;
		case RUNE_RESIST:		return TFCond_RuneResist;
		case RUNE_VAMPIRE:		return TFCond_RuneVampire;
		case RUNE_REFLECT:		return TFCond_RuneWarlock;
		case RUNE_PRECISION:	return TFCond_RunePrecision;
		case RUNE_AGILITY:		return TFCond_RuneAgility;
		case RUNE_KNOCKOUT:		return TFCond_RuneKnockout;
		case RUNE_KING:			return TFCond_KingRune;
		case RUNE_PLAGUE:		return TFCond_PlagueRune;
		case RUNE_SUPERNOVA:	return TFCond_SupernovaRune;
		default: LogError("Unexpected rune_type rt (%d) in GetConditionFromRuneType", rt);
	}
	return view_as<TFCond>(-1);
}

enum ETFAmmoType
{
	TF_AMMO_DUMMY = 0,	// Dummy index to make the CAmmoDef indices correct for the other ammo types.
	TF_AMMO_PRIMARY,
	TF_AMMO_SECONDARY,
	TF_AMMO_METAL,
	TF_AMMO_GRENADES1,
	TF_AMMO_GRENADES2,
	TF_AMMO_GRENADES3,	// Utility Slot Grenades

	TF_AMMO_COUNT
};

enum struct player_t
{
	int index;

	float m_flNextPrimaryAttack;
	float m_flStartFiringTime;
	float m_flNextPrimaryAttackAnim;
	float m_flAmmoUseRemainder;
	int m_iFlamethrowerAmmo;
	float m_flBurnDurationBefore;

	int GetAmmoCount(int iAmmoIndex)
	{
		return GetEntProp(this.index, Prop_Send, "m_iAmmo", .element = iAmmoIndex);
	}
	void SetAmmoCount(int iCount, int iAmmoIndex)
	{
		SetEntProp(this.index, Prop_Send, "m_iAmmo", iCount, .element = iAmmoIndex);
	}
}
static player_t PlayerData[MAXPLAYERS + 1];

static DynamicDetour DHooks_CTFFlameThrower_PrimaryAttack;
static DynamicDetour DHooks_CTFFlameThrower_FireAirBlast;
static DynamicDetour DHooks_CTFFlameManager_OnCollide;
static DynamicDetour DHooks_CTFPlayerShared_Burn;

static Handle SDKCall_CBaseCombatCharacter_Weapon_ShootPosition;
static Handle SDKCall_CTFWeaponBase_CanAttack;
static Handle SDKCall_CTFWeaponBase_CalcIsAttackCritical;
static Handle SDKCall_CTFWeaponBase_SendWeaponAnim;
static Handle SDKCall_CTFPlayer_DoAnimationEvent;

static any offset_CTFFlameEntity_m_vecInitialPos;
static any offset_CTFWeaponBase_m_iWeaponMode;

static ConVar tf_fireball_burn_duration;
static ConVar tf_flamethrower_velocity;
static ConVar tf_flamethrower_vecrand;

static ConVar sm_oldflames_enable;
static ConVar sm_oldflames_flames;
static ConVar sm_oldflames_damage;
static ConVar sm_oldflames_oldafterburn_duration;
static ConVar sm_oldflames_oldafterburn_damage;
static ConVar sm_oldflames_falloff;
static ConVar sm_oldflames_healing_debuff;

static MemoryPatch MemoryPatch_CTFFlameEntity_OnCollide_Falloff;
static float MemoryPatch_CTFFlameEntity_OnCollide_Falloff_New;

static MemoryPatch MemoryPatch_CTFFlameEntity_OnCollide_Falloff2;
static float MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_New;
static float MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_Multiplier;

static MemoryPatch MemoryPatch_ConditionGameRulesThink_HealDebuff;
static MemoryPatch MemoryPatch_CalcDamageResisted_HealDebuffShield;
static MemoryPatch MemoryPatch_CalcDamageResisted_HealDebuffCrit;
static float MemoryPatch_HealDebuff_Float75;
static float MemoryPatch_HealDebuff_Float25;


//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "NotnHeavy, huutti",
	description = "An attempt to revert flamethrower mechanics to how they were, pre-Jungle Inferno.",
	version = "2.0.0",
	url = "none"
};

//////////////////////////////////////////////////////////////////////////////
// INITIALISATION                                                           //
//////////////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	HookEvent("post_inventory_application", PostInventoryApplication);

	// Load config data!
	GameData config = LoadGameConfigFile(PLUGIN_NAME);

	DHooks_CTFFlameThrower_PrimaryAttack = DynamicDetour.FromConf(config, "CTFFlameThrower::PrimaryAttack()");
	DHooks_CTFFlameThrower_FireAirBlast = DynamicDetour.FromConf(config, "CTFFlameThrower::FireAirBlast()");
	DHooks_CTFFlameManager_OnCollide = DynamicDetour.FromConf(config, "Signature::CTFFlameManager::OnCollide()");
	DHooks_CTFPlayerShared_Burn = DynamicDetour.FromConf(config, "CTFPlayerShared::Burn()");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBaseCombatCharacter::Weapon_ShootPosition()");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue); // Vector
	SDKCall_CBaseCombatCharacter_Weapon_ShootPosition = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFWeaponBase::CanAttack()");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain); // bool
	SDKCall_CTFWeaponBase_CanAttack = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWeaponBase::CalcIsAttackCritical()");
	SDKCall_CTFWeaponBase_CalcIsAttackCritical = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFWeaponBase::SendWeaponAnim()");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int iActivity;
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);        // bool
	SDKCall_CTFWeaponBase_SendWeaponAnim = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::DoAnimationEvent()");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // PlayerAnimEvent_t event;
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int mData = 0;
	SDKCall_CTFPlayer_DoAnimationEvent = EndPrepSDKCall();

	MemoryPatch_CTFFlameEntity_OnCollide_Falloff = MemoryPatch.CreateFromConf(config, "CTFFlameEntity::OnCollide_Falloff");
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff2 = MemoryPatch.CreateFromConf(config, "CTFFlameEntity::OnCollide_Falloff2");
	MemoryPatch_ConditionGameRulesThink_HealDebuff = MemoryPatch.CreateFromConf(config, "ConditionGameRulesThink_HealDebuff");
	MemoryPatch_CalcDamageResisted_HealDebuffShield = MemoryPatch.CreateFromConf(config, "CalcDamageResisted_HealDebuffShield");
	MemoryPatch_CalcDamageResisted_HealDebuffCrit = MemoryPatch.CreateFromConf(config, "CalcDamageResisted_HealDebuffCrit");

	if (DHooks_CTFFlameThrower_PrimaryAttack == null) SetFailState("Failed to create DHooks_CTFFlameThrower_PrimaryAttack");
	if (DHooks_CTFFlameThrower_FireAirBlast == null) SetFailState("Failed to create DHooks_CTFFlameThrower_FireAirBlast");
	if (DHooks_CTFFlameManager_OnCollide == null) SetFailState("Failed to create DHooks_CTFFlameManager_OnCollide");
	if (DHooks_CTFPlayerShared_Burn == null) SetFailState("Failed to create DHooks_CTFPlayerShared_Burn");
	if (SDKCall_CBaseCombatCharacter_Weapon_ShootPosition == null) SetFailState("Failed to create SDKCall_CBaseCombatCharacter_Weapon_ShootPosition");
	if (SDKCall_CTFWeaponBase_CanAttack == null) SetFailState("Failed to create SDKCall_CTFWeaponBase_CanAttack");
	if (SDKCall_CTFWeaponBase_CalcIsAttackCritical == null) SetFailState("Failed to create SDKCall_CTFWeaponBase_CalcIsAttackCritical");
	if (SDKCall_CTFWeaponBase_SendWeaponAnim == null) SetFailState("Failed to create SDKCall_CTFWeaponBase_SendWeaponAnim");
	if (SDKCall_CTFPlayer_DoAnimationEvent == null) SetFailState("Failed to create SDKCall_CTFPlayer_DoAnimationEvent");
	if (MemoryPatch_CTFFlameEntity_OnCollide_Falloff == null) SetFailState("Failed to create MemoryPatch_CTFFlameEntity_OnCollide_Falloff");
	if (MemoryPatch_CTFFlameEntity_OnCollide_Falloff2 == null) SetFailState("Failed to create MemoryPatch_CTFFlameEntity_OnCollide_Falloff2");
	if (MemoryPatch_ConditionGameRulesThink_HealDebuff == null)
		LogError("Failed to create MemoryPatch_ConditionGameRulesThink_HealDebuff — pre-JI mode will use modern values");
	if (MemoryPatch_CalcDamageResisted_HealDebuffShield == null)
		LogError("Failed to create MemoryPatch_CalcDamageResisted_HealDebuffShield — pre-JI mode will use modern values");
	if (MemoryPatch_CalcDamageResisted_HealDebuffCrit == null)
		LogError("Failed to create MemoryPatch_CalcDamageResisted_HealDebuffCrit — pre-JI mode will use modern values");

	DHooks_CTFFlameThrower_PrimaryAttack.Enable(Hook_Pre, DHookCallback_PrimaryAttack_Pre); // just because i don't want to re-write ammo management entirely.
	DHooks_CTFFlameThrower_PrimaryAttack.Enable(Hook_Post, DHookCallback_PrimaryAttack_Post);
	DHooks_CTFFlameThrower_FireAirBlast.Enable(Hook_Post, DHookCallback_FireAirBlast);
	DHooks_CTFFlameManager_OnCollide.Enable(Hook_Pre, DHookCallback_OnCollide);
	DHooks_CTFPlayerShared_Burn.Enable(Hook_Pre, DHookCallback_Burn_Pre);
	DHooks_CTFPlayerShared_Burn.Enable(Hook_Post, DHookCallback_Burn);

	offset_CTFFlameEntity_m_vecInitialPos = config.GetOffset("CTFFlameEntity::m_vecInitialPos");
	offset_CTFWeaponBase_m_iWeaponMode = FindSendPropInfo("CTFWeaponBase", "m_iReloadMode") - 4;

	MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_Multiplier = float(config.GetOffset("CTFFlameEntity::OnCollide_Falloff2_Multiplier"));

	delete config;

	// Load ConVars.
	tf_fireball_burn_duration = FindConVar("tf_fireball_burn_duration");
	tf_flamethrower_velocity = FindConVar("tf_flamethrower_velocity");
	tf_flamethrower_vecrand = FindConVar("tf_flamethrower_vecrand");

	// Setup convars. (These values are adjusted for before Jungle Inferno flame mechanics dropped.)
	sm_oldflames_enable = CreateConVar("sm_oldflames_enable", "1", "enable old flame mechanics? (master toggle)", _, true, 0.0, true, 1.0);
	sm_oldflames_flames = CreateConVar("sm_oldflames_flames", "1", "use old flamethrower mechanics flames?", _, true, 0.0, true, 1.0);
	sm_oldflames_oldafterburn_damage = CreateConVar("sm_oldflames_oldafterburn_damage", "1", "use old afterburn damage (3 per tick)", _, true, 0.0, true, 1.0);
	sm_oldflames_oldafterburn_duration = CreateConVar("sm_oldflames_oldafterburn_duration", "1", "use old afterburn duration (constant 10s, 6s with cow mangler)", _, true, 0.0, true, 1.0);
	sm_oldflames_damage = CreateConVar("sm_oldflames_damage", "6.80", "tf_flame damage number");
	sm_oldflames_falloff = CreateConVar("sm_oldflames_falloff", "0.70", "tf_flame falloff percentage when dealing damage");
	sm_oldflames_healing_debuff = CreateConVar("sm_oldflames_healing_debuff", "1", "Healing debuff mode: 0 = none, 1 = pre-JI (2s on direct flames, 25%), 2 = vanilla post-JI (afterburn, 20%)", _, true, 0.0, true, 2.0);

	sm_oldflames_enable.AddChangeHook(OnEnableChanged);
	sm_oldflames_falloff.AddChangeHook(AdjustFalloff);
	sm_oldflames_healing_debuff.AddChangeHook(OnHealingDebuffChanged);
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff_Patch();
	MemoryPatch_HealingDebuff_Patch();

	// Setup hooks for each client.
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
			SetupPlayerHooks(i);
	}

	PrintToServer("----------------------------------------------------------\n\"%s\" has loaded.\n----------------------------------------------------------", PLUGIN_NAME);
}

public void OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (newValue[0] == '1')
	{
		PrintToServer("\"%s\" enabled.", PLUGIN_NAME);
		MemoryPatch_CTFFlameEntity_OnCollide_Falloff_Patch();
		MemoryPatch_HealingDebuff_Patch();
	}
	else
	{
		PrintToServer("\"%s\" disabled. Flames have been reverted to their default state.", PLUGIN_NAME);
		DisableAllPatches();
	}
}

//////////////////////////////////////////////////////////////////////////////
// MEMORY PATCHES                                                           //
//////////////////////////////////////////////////////////////////////////////

static void DisableAllPatches()
{
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff.Disable();
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff2.Disable();
	if (MemoryPatch_ConditionGameRulesThink_HealDebuff) MemoryPatch_ConditionGameRulesThink_HealDebuff.Disable();
	if (MemoryPatch_CalcDamageResisted_HealDebuffShield) MemoryPatch_CalcDamageResisted_HealDebuffShield.Disable();
	if (MemoryPatch_CalcDamageResisted_HealDebuffCrit) MemoryPatch_CalcDamageResisted_HealDebuffCrit.Disable();
}

public void OnPluginEnd()
{
	DisableAllPatches();
}

static void MemoryPatch_CTFFlameEntity_OnCollide_Falloff_Patch()
{
	if (!sm_oldflames_enable.BoolValue)
		return;

	MemoryPatch_CTFFlameEntity_OnCollide_Falloff_New = sm_oldflames_falloff.FloatValue;
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_New = (1.00 - sm_oldflames_falloff.FloatValue) * MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_Multiplier;
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff.Enable();
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff2.Enable();
	WriteToValue(MemoryPatch_CTFFlameEntity_OnCollide_Falloff.Address + view_as<Address>(4), GetAddressOfCell(MemoryPatch_CTFFlameEntity_OnCollide_Falloff_New));
	WriteToValue(MemoryPatch_CTFFlameEntity_OnCollide_Falloff2.Address + view_as<Address>(4), GetAddressOfCell(MemoryPatch_CTFFlameEntity_OnCollide_Falloff2_New));
}

static void MemoryPatch_HealingDebuff_Patch()
{
	if (!sm_oldflames_enable.BoolValue)
		return;

	if (sm_oldflames_healing_debuff.IntValue == 1) {
		MemoryPatch_HealDebuff_Float75 = 0.75;
		MemoryPatch_HealDebuff_Float25 = 0.25;

		if (MemoryPatch_ConditionGameRulesThink_HealDebuff && MemoryPatch_ConditionGameRulesThink_HealDebuff.Enable())
			WriteToValue(MemoryPatch_ConditionGameRulesThink_HealDebuff.Address + view_as<Address>(4), GetAddressOfCell(MemoryPatch_HealDebuff_Float75));
		else
			LogError("ConditionGameRulesThink_HealDebuff patch failed — using modern value");

		if (MemoryPatch_CalcDamageResisted_HealDebuffShield && MemoryPatch_CalcDamageResisted_HealDebuffShield.Enable())
			WriteToValue(MemoryPatch_CalcDamageResisted_HealDebuffShield.Address + view_as<Address>(4), GetAddressOfCell(MemoryPatch_HealDebuff_Float75));
		else
			LogError("CalcDamageResisted_HealDebuffShield patch failed — using modern value");

		if (MemoryPatch_CalcDamageResisted_HealDebuffCrit && MemoryPatch_CalcDamageResisted_HealDebuffCrit.Enable())
			WriteToValue(MemoryPatch_CalcDamageResisted_HealDebuffCrit.Address + view_as<Address>(4), GetAddressOfCell(MemoryPatch_HealDebuff_Float25));
		else
			LogError("CalcDamageResisted_HealDebuffCrit patch failed — using modern value");
	}
	else {
		if (MemoryPatch_ConditionGameRulesThink_HealDebuff) MemoryPatch_ConditionGameRulesThink_HealDebuff.Disable();
		if (MemoryPatch_CalcDamageResisted_HealDebuffShield) MemoryPatch_CalcDamageResisted_HealDebuffShield.Disable();
		if (MemoryPatch_CalcDamageResisted_HealDebuffCrit) MemoryPatch_CalcDamageResisted_HealDebuffCrit.Disable();
	}
}

public void OnHealingDebuffChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	MemoryPatch_HealingDebuff_Patch();
	PrintToServer("Healing debuff mode set to %d (0=none, 1=pre-JI 25%%, 2=vanilla 20%%).", sm_oldflames_healing_debuff.IntValue);
}

//////////////////////////////////////////////////////////////////////////////
// UTIL                                                                     //
//////////////////////////////////////////////////////////////////////////////

static bool CTraceFilterIgnoreObjects(int entity, int mask, int owner)
{
	char class[MAX_NAME_LENGTH];
	GetEntityClassname(entity, class, sizeof(class));
	if (StrContains(class, "obj_") != -1 || entity == owner)
		return false;
	return true;
}

// Weapons that count as flames for healing-debuff purposes.
static bool IsFlameWeapon(int weapon)
{
	if (!IsValidEntity(weapon))
		return false;

	char class[64];
	GetEntityClassname(weapon, class, sizeof(class));
	return StrEqual(class, "tf_weapon_flamethrower")
		|| StrEqual(class, "tf_weapon_rocketlauncher_fireball");
}

//////////////////////////////////////////////////////////////////////////////
// CTFPLAYERSHARED                                                          //
//////////////////////////////////////////////////////////////////////////////

static RuneTypes_t GetCarryingRuneType(int client)
{
	RuneTypes_t retVal = RUNE_NONE;
	for (RuneTypes_t i = view_as<RuneTypes_t>(0); i < RUNE_TYPES_MAX; ++i)
	{
		if (TF2_IsPlayerInCondition(client, view_as<TFCond>(GetConditionFromRuneType(i))))
		{
			retVal = i;
			break;
		}
	}
	return retVal;
}

//////////////////////////////////////////////////////////////////////////////
// CTFFLAMETHROWER                                                          //
//////////////////////////////////////////////////////////////////////////////

static void GetMuzzlePosHelper(int entity, bool bVisualPos, float buffer[3])
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		float vecForward[3];
		float vecRight[3];
		float vecUp[3];
		float vecAngles[3];
		GetClientAbsAngles(owner, vecAngles);
		GetAngleVectors(vecAngles, vecForward, vecRight, vecUp);

		SDKCall(SDKCall_CBaseCombatCharacter_Weapon_ShootPosition, owner, buffer);
		ScaleVector(vecRight, TF_FLAMETHROWER_MUZZLEPOS_RIGHT);
		AddVectors(buffer, vecRight, buffer);

		// if asking for visual position of muzzle, include the forward component
		if (bVisualPos)
		{
			ScaleVector(vecForward, TF_FLAMETHROWER_MUZZLEPOS_FORWARD);
			AddVectors(buffer, vecForward, buffer);
		}
	}
}

static void GetVisualMuzzlePos(int entity, float buffer[3])
{
	GetMuzzlePosHelper(entity, true, buffer);
}

static void GetFlameOriginPos(int entity, float buffer[3])
{
	GetMuzzlePosHelper(entity, false, buffer);
}

static void SetWeaponState(int weapon, FlameThrowerState_t state)
{
	if (GetEntProp(weapon, Prop_Send, "m_iWeaponState") == view_as<int>(state))
		return;
	int owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwner");

	switch (state)
	{
		case FT_STATE_IDLE:
		{
			float flFiringForwardPull = 0.00;
			flFiringForwardPull = TF2Attrib_HookValueFloat(flFiringForwardPull, "firing_forward_pull", weapon);
			if (flFiringForwardPull)
				TF2_RemoveCondition(owner, TFCond_SpeedBuffAlly);
		}
		case FT_STATE_STARTFIRING:
		{
			float flFiringForwardPull = 0.00;
			flFiringForwardPull = TF2Attrib_HookValueFloat(flFiringForwardPull, "firing_forward_pull", weapon);
			if (flFiringForwardPull)
				TF2_AddCondition(owner, TFCond_SpeedBuffAlly);
		}
	}

	SetEntProp(weapon, Prop_Send, "m_iWeaponState", state);
}

//////////////////////////////////////////////////////////////////////////////
// CTFFLAMEENTITY                                                           //
//////////////////////////////////////////////////////////////////////////////

static int CreateFlameEntity(
	float origin[3], float angles[3], int owner, float speed, int damage_type,
	float damage, bool crit_from_behind, bool randomize = true
) {
	int entity = CreateEntityByName("tf_flame");
	if (entity == -1)
		return -1;

	TeleportEntity(entity, origin, angles, NULL_VECTOR);
	SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", owner);
	DispatchSpawn(entity);

	any offset_m_hAttacker = offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_hAttacker;
	if (
		HasEntProp(owner, Prop_Send, "m_hOwnerEntity") &&
		GetEntPropEnt(owner, Prop_Send, "m_hOwnerEntity") != -1
	) {
		// pFlame->m_hAttacker = pOwner->GetOwnerEntity();
		SetEntDataEnt2(entity, offset_m_hAttacker, GetEntPropEnt(owner, Prop_Send, "m_hOwnerEntity"));
	}
	else {
		// pFlame->m_hAttacker = pOwner;
		SetEntDataEnt2(entity, offset_m_hAttacker, owner);
	}

	// this is not apparent anymore?
	// 2024.04.28: pre-smtc removal code, this is old however so i'm leaving it as a relic :)
	// pFlame->m_iAttackerTeam = pAttacker->GetTeamNumber();
	//if (flamePointer.DereferenceEHandle(CTFFlameEntity_Base + CTFFLAMEENTITY_OFFSET_M_HATTACKER) != -1)
	//    flamePointer.Write(GetEntProp(flamePointer.DereferenceEHandle(CTFFlameEntity_Base + CTFFLAMEENTITY_OFFSET_M_HATTACKER), Prop_Send, "m_iTeamNum"), CTFFlameEntity_Base + CTFFLAMEENTITY_OFFSET_M_IATTACKERTEAM);

	// Set team.
	// pFlame->ChangeTeam( pOwner->GetTeamNumber() );
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetEntProp(owner, Prop_Send, "m_iTeamNum"));

	// pFlame->m_iDmgType = iDmgType;
	SetEntData(entity, offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_iDmgType, damage_type);
	// pFlame->m_flDmgAmount = flDmgAmount;
	SetEntDataFloat(entity, offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_flDmgAmount, damage);

	// Setup the initial velocity.
	float m_vecBaseVelocity[3];
	float vecRight[3];
	float vecUp[3];
	GetAngleVectors(angles, m_vecBaseVelocity, vecRight, vecUp);

	int attacker = GetEntDataEnt2(entity, offset_m_hAttacker);

	// CALL_ATTRIB_HOOK_FLOAT_ON_OTHER( pFlame->m_hAttacker, flFlameLifeMult, mult_flame_life );
	float flFlameLifeMult = 1.0;
	if (IsValidEntity(attacker)) {
		flFlameLifeMult = TF2Attrib_HookValueFloat(flFlameLifeMult, "mult_flame_life", attacker);
	}

	float velocity = flFlameLifeMult * speed;
	// pFlame->m_vecBaseVelocity = vecForward * velocity;
	ScaleVector(m_vecBaseVelocity, velocity);

	// CALL_ATTRIB_HOOK_FLOAT_ON_OTHER( pFlame->m_hAttacker, iFlameSizeMult, mult_flame_size );
	float flFlameSizeMult = 1.0;
	if (IsValidEntity(attacker)) {
		flFlameSizeMult = TF2Attrib_HookValueFloat(flFlameSizeMult, "mult_flame_size", attacker);
	}

	// pFlame->m_vecBaseVelocity += RandomVector( -velocity * iFlameSizeMult * tf_flamethrower_vecrand.GetFloat(), velocity * iFlameSizeMult * tf_flamethrower_vecrand.GetFloat() );
	if (randomize)
	{
		float minValue = -velocity * flFlameSizeMult * tf_flamethrower_vecrand.FloatValue;
		float maxValue = velocity * flFlameSizeMult * tf_flamethrower_vecrand.FloatValue;
		float rand[3];
		rand[0] = GetRandomFloat(minValue, maxValue);
		rand[1] = GetRandomFloat(minValue, maxValue);
		rand[2] = GetRandomFloat(minValue, maxValue);
		AddVectors(m_vecBaseVelocity, rand, m_vecBaseVelocity);
	}

	// pFlame->m_vecAttackerVelocity = pOwner->GetOwnerEntity()->GetAbsVelocity();
	if (
		HasEntProp(owner, Prop_Send, "m_hOwnerEntity") &&
		GetEntPropEnt(owner, Prop_Send, "m_hOwnerEntity") != -1
	) {
		float vel[3];
		GetEntPropVector(GetEntPropEnt(owner, Prop_Send, "m_hOwnerEntity"), Prop_Data, "m_vecAbsVelocity", vel);
		SetEntDataVector(entity, offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_vecAttackerVelocity, vel);
	}

	// pFlame->SetAbsVelocity( pFlame->m_vecBaseVelocity );
	// pFlame->SetAbsAngles( vecAngles );
	TeleportEntity(entity, NULL_VECTOR, angles, m_vecBaseVelocity);

	// pFlame->SetCritFromBehind( bAlwaysCritFromBehind );
	SetEntData(entity, offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_bCritFromBehind, crit_from_behind, 1);

	SetEntDataVector(entity, offset_CTFFlameEntity_m_vecInitialPos + CTFFlameEntity_m_vecBaseVelocity, m_vecBaseVelocity);
	return entity;
}

//////////////////////////////////////////////////////////////////////////////
// FORWARDS                                                                 //
//////////////////////////////////////////////////////////////////////////////

public void OnClientPutInServer(int client)
{
	SetupPlayerHooks(client);
}

public Action OnPlayerRunCmd(
	int client, int &buttons, int &impulse, float vel[3], float angles[3],
	int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]
) {
	if (
		sm_oldflames_enable.BoolValue &&
		sm_oldflames_flames.BoolValue
	) {
		int flamethrower = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if (
			IsValidEntity(flamethrower) &&
			flamethrower == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
		) {
			char class[MAX_NAME_LENGTH];
			GetEntityClassname(flamethrower, class, sizeof(class));
			if (StrEqual(class, "tf_weapon_flamethrower")) {
				float vecEye[3];
				float vecMuzzlePos[3];
				GetClientEyePosition(client, vecEye);
				GetVisualMuzzlePos(flamethrower, vecMuzzlePos);
				TR_TraceRayFilter(vecEye, vecMuzzlePos, MASK_SOLID, RayType_EndPoint, CTraceFilterIgnoreObjects, client);

				if (TR_GetFraction() < 1.00 && (TR_GetEntityIndex() == -1 || GetEntProp(TR_GetEntityIndex(), Prop_Data, "m_takedamage") == DAMAGE_NO))
				{
					if (GetEntProp(flamethrower, Prop_Send, "m_iWeaponState") > view_as<int>(FT_STATE_IDLE))
						SetWeaponState(flamethrower, FT_STATE_IDLE);
					buttons &= ~IN_ATTACK;
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

//////////////////////////////////////////////////////////////////////////////
// HOOKS                                                                    //
//////////////////////////////////////////////////////////////////////////////

public void AdjustFalloff(ConVar convar, const char[] oldValue, const char[] newValue)
{
	MemoryPatch_CTFFlameEntity_OnCollide_Falloff_Patch();
	PrintToServer("Flamethrower falloff with tf_flame has been changed to %f.", Dereference(Dereference(MemoryPatch_CTFFlameEntity_OnCollide_Falloff.Address + view_as<Address>(4))));
}

static void SetupPlayerHooks(int client)
{
	PlayerData[client].index = client; // dumb shortcut but whatever
	PlayerData[client].m_flNextPrimaryAttack = 0.00;
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage);
}

// pre-call CTFPlayer::OnTakeDamage(), using SDKHooks.
// Handle the healing debuff on flame ignite, and re-write afterburn damage
// if sm_oldflames_flamethrower_oldafterburn_damage is on.
Action SDKHookCB_OnTakeDamage(
	int victim, int& attacker, int& inflictor, float& damage, int& damage_type,
	int& weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	if (!sm_oldflames_enable.BoolValue)
		return Plugin_Continue;

	if ((damage_type & DMG_IGNITE) && IsFlameWeapon(weapon))
	{
		switch (sm_oldflames_healing_debuff.IntValue)
		{
			case 0: TF2_RemoveCondition(victim, TFCond_HealingDebuff);
			case 1: TF2_AddCondition(victim, TFCond_HealingDebuff, 2.0);
		}
	}

	if (sm_oldflames_oldafterburn_damage.BoolValue && damage_type == (DMG_BURN | DMG_PREVENT_PHYSICS_FORCE))
	{
		damage *= TF_BURNING_DMG_OLD / TF_BURNING_DMG_NEW;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	PlayerData[client].m_flStartFiringTime = 0.00;
	PlayerData[client].m_flNextPrimaryAttackAnim = 0.00;
	PlayerData[client].m_flAmmoUseRemainder = 0.00;
	return Plugin_Continue;
}

// pre-call CTFFlameThrower::PrimaryAttack();
// This is only just so I don't have to re-write ammo management with the flamethrowers.
MRESReturn DHookCallback_PrimaryAttack_Pre(int entity)
{
	// Get the owner of this weapon.
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (owner == -1)
		return MRES_Ignored;

	PlayerData[owner].m_iFlamethrowerAmmo = PlayerData[owner].GetAmmoCount(view_as<int>(TF_AMMO_PRIMARY));
	return MRES_Ignored;
}

// post-call CTFFlameThrower::PrimaryAttack();
// The route I'm taking is hacky; I'm not sure what would be the best way to get around with flame visuals otherwise.
// Essentially, the original function will still be called. However, there'll be another layer to this function that
// spawns the stream of tf_flame entities.
//
// This hook emits certain things, either things that I find unnecessary at this moment, or are already handled in the internal function.
MRESReturn DHookCallback_PrimaryAttack_Post(int entity)
{
	if (!sm_oldflames_enable.BoolValue)
		return MRES_Ignored;

	if (sm_oldflames_flames.BoolValue)
	{
		// Get the owner of this weapon.
		int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
		if (owner == -1)
			return MRES_Ignored;

		// Revert ammo to pre-call.
		PlayerData[owner].SetAmmoCount(PlayerData[owner].m_iFlamethrowerAmmo, view_as<int>(TF_AMMO_PRIMARY));

		// Check for if we're capable of firing.
		if (PlayerData[owner].m_flNextPrimaryAttack > GetGameTime())
			return MRES_Ignored;

		if (!SDKCall(SDKCall_CTFWeaponBase_CanAttack, entity))
		{
			SetWeaponState(entity, FT_STATE_IDLE);
			return MRES_Ignored;
		}
		SetEntData(entity, offset_CTFWeaponBase_m_iWeaponMode, TF_WEAPON_PRIMARY_MODE);

		SDKCall(SDKCall_CTFWeaponBase_CalcIsAttackCritical, entity);

		// Because the muzzle is so long, it can stick through a wall if the player is right up against it.
		// Make sure the weapon can't fire in this condition by tracing a line between the eye point and the end of the muzzle.
		/*
		trace_t trace;
		Vector vecEye = pOwner->EyePosition();
		Vector vecMuzzlePos = GetVisualMuzzlePos();
		CTraceFilterIgnoreObjects traceFilter( this, COLLISION_GROUP_NONE );
		UTIL_TraceLine( vecEye, vecMuzzlePos, MASK_SOLID, &traceFilter, &trace );
		if ( trace.fraction < 1.0 && ( !trace.m_pEnt || trace.m_pEnt->m_takedamage == DAMAGE_NO ) )
		{
			// there is something between the eye and the end of the muzzle, most likely a wall, don't fire, and stop firing if we already are
			if ( m_iWeaponState > FT_STATE_IDLE )
			{
				SetWeaponState( FT_STATE_IDLE );
			}
			return;
		}
		*/
		// See OnPlayerRunCmd().

		// Deal with weapon animations.
		switch (view_as<FlameThrowerState_t>(GetEntProp(entity, Prop_Send, "m_iWeaponState")))
		{
			case FT_STATE_IDLE:
			{
				SDKCall(SDKCall_CTFPlayer_DoAnimationEvent, owner, PLAYERANIMEVENT_ATTACK_PRE, 0);
				SDKCall(SDKCall_CTFWeaponBase_SendWeaponAnim, entity, ACT_VM_PRIMARYATTACK);
				PlayerData[owner].m_flStartFiringTime = GetGameTime() + 0.16;
				SetWeaponState(entity, FT_STATE_STARTFIRING);
			}
			case FT_STATE_STARTFIRING:
			{
				if (GetGameTime() > PlayerData[owner].m_flStartFiringTime)
				{
					SetWeaponState(entity, FT_STATE_FIRING);
					PlayerData[owner].m_flNextPrimaryAttackAnim = GetGameTime();
				}
			}
			case FT_STATE_FIRING:
			{
				if (GetGameTime() >= PlayerData[owner].m_flNextPrimaryAttackAnim)
				{
					SDKCall(SDKCall_CTFPlayer_DoAnimationEvent, owner, PLAYERANIMEVENT_ATTACK_PRIMARY, 0);
					PlayerData[owner].m_flNextPrimaryAttackAnim = GetGameTime() + 1.40;
				}
			}
		}

		// Check if we're not underwater, in that case, fire!
		float flFiringInterval = 0.044;
		if (GetEntProp(owner, Prop_Send, "m_nWaterLevel") != WL_Eyes)
		{
			int iDmgType = DMGTYPE;
			if (GetEntProp(entity, Prop_Send, "m_bCritFire"))
				iDmgType |= DMG_CRIT;

			// Create the flame entity.
			float flDamage = sm_oldflames_damage.FloatValue; // 6.80 by default
			flDamage = TF2Attrib_HookValueFloat(flDamage, "mult_dmg", entity);

			int iCritFromBehind = 0;
			iCritFromBehind = TF2Attrib_HookValueInt(iCritFromBehind, "set_flamethrower_back_crit", entity);

			float eyeangles[3];
			float origin[3];
			GetFlameOriginPos(entity, origin);
			GetClientEyeAngles(owner, eyeangles);

			CreateFlameEntity(origin, eyeangles, entity, tf_flamethrower_velocity.FloatValue, iDmgType, flDamage, iCritFromBehind == 1);
		}

		// Figure how much ammo we're using.
		float flAmmoPerSecond = TF_FLAMETHROWER_AMMO_PER_SECOND_PRIMARY_ATTACK;
		flAmmoPerSecond = TF2Attrib_HookValueFloat(flAmmoPerSecond, "mult_flame_ammopersec", entity);
		PlayerData[owner].m_flAmmoUseRemainder += flAmmoPerSecond * flFiringInterval;

		int iAmmoToSubtract = RoundToFloor(PlayerData[owner].m_flAmmoUseRemainder); // basically (int)m_flAmmoUseRemainder.
		if (iAmmoToSubtract > 0)
		{
			PlayerData[owner].m_iFlamethrowerAmmo -= iAmmoToSubtract;
			PlayerData[owner].m_flAmmoUseRemainder -= iAmmoToSubtract;

			// round to 2 digits of precision
			PlayerData[owner].m_flAmmoUseRemainder = RoundToFloor(PlayerData[owner].m_flAmmoUseRemainder * 100) / 100.00;
		}

		// Finish this detour.
		PlayerData[owner].m_flNextPrimaryAttack = GetGameTime() + flFiringInterval;
		PlayerData[owner].SetAmmoCount(PlayerData[owner].m_iFlamethrowerAmmo, view_as<int>(TF_AMMO_PRIMARY));
	}
	return MRES_Ignored;
}

// CTFFlameThrower::FireAirblast();
// Fix the next primary attack timer in this detour.
MRESReturn DHookCallback_FireAirBlast(int entity, DHookParam parameters)
{
	if (!sm_oldflames_enable.BoolValue)
		return MRES_Ignored;

	// Get the owner of this weapon.
	int pOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (pOwner == -1)
		return MRES_Ignored;

	float fAirblastRefireTimeScale = 1.00;
	fAirblastRefireTimeScale = TF2Attrib_HookValueFloat(fAirblastRefireTimeScale, "mult_airblast_refire_time", entity);
	if (fAirblastRefireTimeScale <= 0.00)
		fAirblastRefireTimeScale = 1.00;

	float fAirblastPrimaryRefireTimeScale = 1.00;
	fAirblastPrimaryRefireTimeScale = TF2Attrib_HookValueFloat(fAirblastPrimaryRefireTimeScale, "mult_airblast_primary_refire_time", entity);
	if (fAirblastPrimaryRefireTimeScale <= 0.00)
		fAirblastPrimaryRefireTimeScale = 1.00;

	// Haste Powerup Rune adds multiplier to fire delay time
	if (GetCarryingRuneType(pOwner) == RUNE_HASTE)
		fAirblastRefireTimeScale *= 0.50;

	PlayerData[pOwner].m_flNextPrimaryAttack = GetGameTime() + (1.00 * fAirblastRefireTimeScale * fAirblastPrimaryRefireTimeScale);
	return MRES_Ignored;
}

// CTFFlameManager::OnCollide();
// Supercede this just to prevent damage-dealing.
MRESReturn DHookCallback_OnCollide(int entity, DHookParam parameters)
{
	if (!sm_oldflames_enable.BoolValue)
		return MRES_Ignored;

	if (sm_oldflames_flames.BoolValue)
		return MRES_Supercede;
	return MRES_Ignored;
}

// pre-call CTFPlayerShared::Burn();
// Track the pre-call burning state: whether the player was already burning
// (healing debuff mode handling) and their remaining burn time (immune
// victims must never get a longer burn shortened -- Burn() overwrites
// m_flAfterburnDuration with the fixed 0.25s before the post-hook runs).
MRESReturn DHookCallback_Burn_Pre(Address pThis)
{
	int client = TF2Util_GetPlayerFromSharedAddress(pThis);
	PlayerData[client].m_flBurnDurationBefore = TF2Util_GetPlayerBurnDuration(client);
	return MRES_Ignored;
}

// post-call CTFPlayerShared::Burn();
// Adjust afterburn duration, if sm_oldflames_flamethrower_oldafterburn_duration is on.
MRESReturn DHookCallback_Burn(Address pThis, DHookParam parameters)
{
	if (!sm_oldflames_enable.BoolValue)
		return MRES_Ignored;

	int client = TF2Util_GetPlayerFromSharedAddress(pThis);
	int pWeapon = parameters.Get(2);
	float flBurningTime = parameters.Get(3);
	if (
		!IsPlayerAlive(client) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_PasstimeInterception)
	)
		return MRES_Ignored;

	// Healing debuff mode handling
	int healDebuffMode = sm_oldflames_healing_debuff.IntValue;
	if (healDebuffMode != 2 && PlayerData[client].m_flBurnDurationBefore == 0.0)
	{
		TF2_RemoveCondition(client, TFCond_HealingDebuff);

		if (healDebuffMode == 1 && IsFlameWeapon(pWeapon))
			TF2_AddCondition(client, TFCond_HealingDebuff, 2.0);
	}

	if (!sm_oldflames_oldafterburn_duration.BoolValue)
		return MRES_Ignored;

	int nAfterburnImmunity = TF2_GetPlayerClass(client) == TFClass_Pyro;

	if (
		nAfterburnImmunity &&
		TF2_IsPlayerInCondition(client, TFCond_BurningPyro)
	) {
		nAfterburnImmunity = 0;
	}

	int pMyWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(pMyWeapon))
	{
		nAfterburnImmunity = TF2Attrib_HookValueInt(nAfterburnImmunity, "afterburn_immunity", pMyWeapon);
	}

	if (TF2_IsPlayerInCondition(client, TFCond_AfterburnImmune))
	{
		nAfterburnImmunity = 1;
	}

	int shield = -1;
	for (int i = 0; i < TF2Util_GetPlayerWearableCount(client); ++i)
	{
		int wearable = TF2Util_GetPlayerWearable(client, i);
		char class[MAX_NAME_LENGTH];
		GetEntityClassname(wearable, class, sizeof(class));
		if (StrEqual(class, "tf_wearable_demoshield"))
		{
			shield = wearable;
			break;
		}
	}
	if (!nAfterburnImmunity && IsValidEntity(shield) && !GetEntProp(shield, Prop_Send, "m_bDisguiseWearable"))
	{
		nAfterburnImmunity = TF2Attrib_HookValueInt(nAfterburnImmunity, "afterburn_immunity", shield);
	}

	if (!nAfterburnImmunity && TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		for (int i = 0; i < TF2Util_GetPlayerWearableCount(client); ++i)
		{
			shield = TF2Util_GetPlayerWearable(client, i);
			if (IsValidEntity(shield) && !GetEntProp(shield, Prop_Send, "m_bDisguiseWearable"))
				nAfterburnImmunity = TF2Attrib_HookValueInt(nAfterburnImmunity, "afterburn_immunity", shield);
		}
	}

	if (!nAfterburnImmunity)
	{
		float flFlameLife;
		if (flBurningTime > 0.00)
			flFlameLife = flBurningTime;
		else
		{
			float length = TF_BURNING_FLAME_LIFE;
			if (IsValidEntity(pWeapon))
			{
				char class[MAX_NAME_LENGTH];
				GetEntityClassname(pWeapon, class, sizeof(class));
				if (StrEqual(class, "tf_weapon_rocketlauncher_fireball")) {
					length = tf_fireball_burn_duration.FloatValue;
				}
				else if (StrEqual(class, "tf_weapon_particle_cannon")) {
					length = TF_BURNING_FLAME_LIFE_PLASMA;
				}
			}
			flFlameLife = length;
		}
		flFlameLife = TF2Attrib_HookValueFloat(flFlameLife, "mult_wpn_burntime", pWeapon);

		if (flFlameLife > TF2Util_GetPlayerBurnDuration(client))
			TF2Util_SetPlayerBurnDuration(client, flFlameLife);
	}

	// Afterburn-immune victims (pyro, shields, afterburn_immunity, ...):
	// Burn() gives them a fixed TF_BURNING_FLAME_LIFE_PYRO (0.25s) burn, but
	// modern TF2 tracks burn expiry in m_flAfterburnDuration, which is only
	// decremented on 0.5s damage ticks -- so a "0.25s" burn actually lingers
	// until the first tick (~0.5s after ignition). Old flames extinguished
	// immune victims precisely 0.25s after ignition (m_flFlameRemoveTime,
	// checked every frame). The game still has that machinery: every condition
	// carries its own per-frame countdown (m_ConditionData[].m_flExpireTime,
	// decremented by frametime and removed at 0 in
	// CTFPlayerShared::ConditionGameRulesThink; TF_COND_BURNING is explicitly
	// listed in ConditionExpiresFast, so being healed still shortens the burn),
	// but Burn() adds TF_COND_BURNING as a permanent condition (-1.0). Give the
	// condition itself a duration and let the game expire it on the exact
	// frame through the normal extinguish path -- no plugin-side bookkeeping.
	//
	// Like the old m_flFlameRemoveTime (set to the later of the old and new
	// removal times) this only ever extends: the condition is given the max
	// of the fixed 0.25s, the burn time remaining before this hit (tracked in
	// the pre-hook -- Burn() overwrites m_flAfterburnDuration with 0.25s for
	// immune victims, so the pre-hit value is gone by the time we run here)
	// and the game's post-call value. E.g. a Dragon's Fury pyro whose
	// TF_COND_BURNING_PYRO just expired keeps its remaining multi-second
	// burn, but precisely timed now.
	else if (TF2_IsPlayerInCondition(client, TFCond_OnFire))
	{
		float flNewDuration = TF_BURNING_FLAME_LIFE_PYRO;

		float flPrevBurn = PlayerData[client].m_flBurnDurationBefore;
		if (flPrevBurn > flNewDuration)
			flNewDuration = flPrevBurn;

		float flCurBurn = TF2Util_GetPlayerBurnDuration(client);
		if (flCurBurn > flNewDuration)
			flNewDuration = flCurBurn;

		TF2Util_SetPlayerConditionDuration(client, TFCond_OnFire, flNewDuration);
	}

	return MRES_Ignored;
}

//////////////////////////////////////////////////////////////////////////////
// MEMORY                                                                   //
//////////////////////////////////////////////////////////////////////////////

stock int LoadEntityHandleFromAddress(Address addr) // From nosoop's stocksoup framework.
{
	return EntRefToEntIndex(LoadFromAddress(addr, NumberType_Int32) | (1 << 31));
}

stock void StoreEntityHandleToAddress(Address addr, int handle)
{
	StoreToAddress(addr, IsValidEntity(handle) ? EntIndexToEntRef(handle) & ~(1 << 31) : 0, NumberType_Int32);
}

stock int GetEntityFromAddress(Address pEntity) // From nosoop's stocksoup framework.
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

stock any Dereference(any address, NumberType bitdepth = NumberType_Int32)
{
	return LoadFromAddress(address, bitdepth);
}

stock void WriteToValue(any address, any value, bool updateMemAccess = true, NumberType bitdepth = NumberType_Int32)
{
	StoreToAddress(address, value, bitdepth, updateMemAccess);
}

stock void GetVector(any address, float buffer[3])
{
	for (int i = 0; i < VECTOR_SIZE; i += 4)
		buffer[i / 4] = LoadFromAddress(address + i, NumberType_Int32);
}

stock void WriteVector(any address, float buffer[3], bool updateMemAccess = true)
{
	for (int i = 0; i < VECTOR_SIZE; i += 4)
		StoreToAddress(address + i, buffer[i / 4], NumberType_Int32, updateMemAccess);
}