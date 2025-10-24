/*
	╔════════════════════════════════════════════════════╗
	║                    !!README!!!                     ║
	╚════════════════════════════════════════════════════╝

	This section controls the compiling of memory patch reverts.
	These are reverts which require SourceScramble to be installed.
	Memory patch reverts may break when game updates happen.
	If there is a major code update to the game resulting in
	patches breaking, you can disable them here.

	To disable all memory patches, comment out/remove the following line:
 v v v v v v v v v v v
*/
#define MEMORY_PATCHES
/*
	Alternatively, you can pass NO_MEMPATCHES= as a parameter to spcomp.
*/
#if defined NO_MEMPATCHES && defined MEMORY_PATCHES
#undef MEMORY_PATCHES
#endif

//#define WIN32
/*
 ^ ^ ^ ^ ^ ^ ^ ^ ^
	Additionally, you will need to select your compile OS.
	Memory patches are different for Windows and Linux servers.
	For Windows, either uncomment the above line
	or pass in WIN32= as a parameter to spcomp.exe.
	For Linux, leave this line commented.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2utils>
#include <tf2attributes>
#include <tf2condhooks>
#include <dhooks>
#include <morecolors> // Should be compiled on version 1.9.1 of morecolors.inc
#undef REQUIRE_PLUGIN
#include <sourcescramble>
#define REQUIRE_PLUGIN
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "TF2 Weapon Reverts Extended"
#define PLUGIN_DESC "Reverts nerfed weapons back to their glory days"
#define PLUGIN_AUTHOR "Bakugo, NotnHeavy, random, huutti, VerdiusArcana, MindfulProtons, EricZhang456"

#define PLUGIN_VERSION_NUM "2.0.0"
// Add a OS suffix if Memorypatch reverts are used
// to make it easier to see which OS the plugin is compiled for. 
// To server owners, before you raise hell, do: sm plugins list 
// and check that you compiled for the correct OS.
#if defined MEMORY_PATCHES
#if defined WIN32
#define PLUGIN_VERSION PLUGIN_VERSION_NUM ... "-win32"
#else
#define PLUGIN_VERSION PLUGIN_VERSION_NUM ... "-linux32"
#endif
#else
#define PLUGIN_VERSION PLUGIN_VERSION_NUM
#endif

//#define GIT_COMMIT

#if defined GIT_COMMIT
#define PLUGIN_VERSION_GIT PLUGIN_VERSION ... "%GIT_COMMIT%"
#endif

#define PLUGIN_URL "https://castaway.tf"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	description = PLUGIN_DESC,
	author = PLUGIN_AUTHOR,
#if defined GIT_COMMIT
	version = PLUGIN_VERSION_GIT,
#else
	version = PLUGIN_VERSION,
#endif
	url = PLUGIN_URL
};

#define MAX_VARIANTS 4 // not including base version
#define BALANCE_CIRCUIT_METAL 15
#define BALANCE_CIRCUIT_DAMAGE 20.0
#define BALANCE_CIRCUIT_RECOVERY 0.67
#define PLAYER_CENTER_HEIGHT (82.0 / 2.0) // constant for tf2 players

// flags for item definitions
#define CLASSFLAG_SCOUT		(1 << 0)
#define CLASSFLAG_SNIPER	(1 << 1)
#define CLASSFLAG_SOLDIER	(1 << 2)
#define CLASSFLAG_DEMOMAN	(1 << 3)
#define CLASSFLAG_MEDIC		(1 << 4)
#define CLASSFLAG_HEAVY		(1 << 5)
#define CLASSFLAG_PYRO		(1 << 6)
#define CLASSFLAG_SPY		(1 << 7)
#define CLASSFLAG_ENGINEER	(1 << 8)

#define ITEMFLAG_DISABLED	(1 << 9) // Disabled by default

// game code defs
#define EF_NODRAW 0x20
#define FSOLID_USE_TRIGGER_BOUNDS 0x80
#define DMG_MELEE DMG_BLAST_SURFACE
#define DMG_DONT_COUNT_DAMAGE_TOWARDS_CRIT_RATE DMG_DISSOLVE
#define TF_DMG_CUSTOM_NONE 0
#define TF_DMG_CUSTOM_BACKSTAB 2
#define TF_DMG_CUSTOM_TAUNTATK_GRENADE 21
#define TF_DMG_CUSTOM_BASEBALL 22
#define TF_DMG_CUSTOM_CHARGE_IMPACT 23
#define TF_DMG_CUSTOM_PICKAXE 27
#define TF_DMG_CUSTOM_PLAYER_SENTRY 30
#define TF_DMG_CUSTOM_STICKBOMB_EXPLOSION 42
#define TF_DMG_CUSTOM_CANNONBALL_PUSH 61
#define TF_DEATH_FEIGN_DEATH 0x20
#define TF_FLAGTYPE_PLAYER_DESTRUCTION 6
#define SHIELD_NORMAL_VALUE 0.33
#define LOADOUT_POSITION_SECONDARY 1
#define TF_MINIGUN_SPINUP_TIME 0.75
#define TF_MINIGUN_PENALTY_PERIOD 1.0
#define SENTRYGUN_ADD_SHELLS 40
#define SENTRYGUN_MAX_SHELLS_1 150

enum
{
	SHIELD_NONE = 0,
	SHIELD_NORMAL,	// 33% damage taken, no tracking
	SHIELD_MAX,		// 10% damage taken, tracking
};

TFCond debuffs[] =
{
	TFCond_OnFire,
	TFCond_Jarated,
	TFCond_Bleeding,
	TFCond_Milked,
	TFCond_Gas
};

enum
{
	EUREKA_FIRST_TARGET = 0,
	EUREKA_TELEPORT_HOME = 0,
	EUREKA_TELEPORT_TELEPORTER_EXIT,
	EUREKA_LAST_TARGET = EUREKA_TELEPORT_TELEPORTER_EXIT,	
	EUREKA_NUM_TARGETS
};

char class_names[][] = {
	"SCOUT",
	"SNIPER",
	"SOLDIER",
	"DEMOMAN",
	"MEDIC",
	"HEAVY",
	"PYRO",
	"SPY",
	"ENGINEER"
};

enum struct Item {
	char key[64];
	int flags;
	int num_variants;
	ConVar cvar;
	bool mem_patch;
}

enum struct Player {
	//int respawn; // frame to force a respawn after
	bool received_help_notice;

	// gameplay vars
	float resupply_time;
	int headshot_frame;
	int projectile_touch_frame;
	int projectile_touch_entity;
	float stunball_fix_time_bonk;
	float stunball_fix_time_wear;
	float spy_cloak_meter;
	bool spy_is_feigning;
	int ammo_grab_frame;
	int bonk_cond_frame;
	int bison_hit_frame;
	int beggars_ammo;
	int sleeper_piss_frame;
	float sleeper_piss_duration;
	bool sleeper_piss_explode;
	int medic_medigun_defidx;
	float medic_medigun_charge;
	float cleaver_regen_time;
	float icicle_regen_time;
	int scout_airdash_value;
	int scout_airdash_count;
	float backstab_time;
	int old_health;
	int feign_ready_tick;
	float damage_taken_during_feign;
	bool is_under_hype;
	int charge_tick;
	int fall_dmg_tick;
	int ticks_since_switch;
	bool holding_jump;
	int drain_victim;
	float drain_time;
	bool spy_under_feign_buffs;
	bool is_eureka_teleporting;
	int eureka_teleport_target;
	int powerjack_kill_tick;
	float pyro_rage_meter;
	bool cloak_gain_capped;
	float damage_received_time;
	float aiming_cond_time;
}

enum struct Entity {
	bool exists;
	float spawn_time;
	bool is_demo_shield;
	int old_shield;
	float minisentry_health;
}

ConVar cvar_enable;
ConVar cvar_show_moonshot;
ConVar cvar_old_falldmg_sfx;
ConVar cvar_no_reverts_info_by_default;
#if defined MEMORY_PATCHES
ConVar cvar_dropped_weapon_enable;
#endif
ConVar cvar_pre_toughbreak_switch;
ConVar cvar_enable_shortstop_shove;
ConVar cvar_ref_tf_airblast_cray;
ConVar cvar_ref_tf_bison_tick_time;
ConVar cvar_ref_tf_dropped_weapon_lifetime;
ConVar cvar_ref_tf_feign_death_activate_damage_scale;
ConVar cvar_ref_tf_feign_death_damage_scale;
ConVar cvar_ref_tf_feign_death_duration;
ConVar cvar_ref_tf_feign_death_speed_duration;
ConVar cvar_ref_tf_fireball_radius;
ConVar cvar_ref_tf_parachute_aircontrol;
ConVar cvar_ref_tf_parachute_maxspeed_onfire_z;
ConVar cvar_ref_tf_parachute_deploy_toggle_allowed;
ConVar cvar_ref_tf_scout_hype_mod;
ConVar cvar_ref_tf_gamemode_mvm;
ConVar cvar_ref_tf_weapon_criticals;
ConVar cvar_ref_tf_sticky_airdet_radius;
ConVar cvar_ref_tf_sticky_radius_ramp_time;
ConVar cvar_ref_tf_damage_disablespread;

#if defined MEMORY_PATCHES
MemoryPatch patch_RevertDisciplinaryAction;
// If Windows, prepare additional vars for Disciplinary Action.
#if defined WIN32
float g_flNewDiscilplinaryAllySpeedBuffTimer = 3.0;
// Address of our float:
Address AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer;
#endif

MemoryPatch patch_RevertDragonsFury_CenterHitForBonusDmg;
MemoryPatch patch_RevertFlamethrowers_Density_DmgScale;
MemoryPatch patch_RevertFlamethrowers_Density_OnCollide;
MemoryPatch patch_RevertMiniguns_RampupNerf_Dmg;
MemoryPatch patch_RevertMiniguns_RampupNerf_Spread;
MemoryPatch patch_RevertCozyCamper_FlinchNerf;
MemoryPatch patch_RevertQuickFix_Uber_CannotCapturePoint;
MemoryPatch patch_RevertIronBomber_PipeHitbox;
MemoryPatch patch_DroppedWeapon;

MemoryPatch patch_RevertMadMilk_ChgFloatAddr;
float g_flMadMilkHealTarget = 0.75;
Address AddressOf_g_flMadMilkHealTarget;

// Changes float addr to point to our plugin declared "AddressOf_g_flDalokohsBarCanOverHealTo"
MemoryPatch patch_RevertDalokohsBar_ChgFloatAddr; 
// Changes a MOV to 400. Basically it's for setup of the function that deals with
// Consuming Dalokohs bar.
MemoryPatch patch_RevertDalokohsBar_ChgTo400;
float g_flDalokohsBarCanOverHealTo = 400.0; // Float to use for Dalokohs Bar revert
// Address of our float to use for the MOVSS part of revert:
Address AddressOf_g_flDalokohsBarCanOverHealTo;

DynamicDetour dhook_CTFAmmoPack_MakeHolidayPack;

MemoryPatch patch_RevertSniperRifles_ScopeJump;
#if !defined WIN32
MemoryPatch patch_RevertSniperRifles_ScopeJump_linuxextra;
#endif

DynamicHook dhook_CObjectSentrygun_StartBuilding;
DynamicHook dhook_CObjectSentrygun_Construct;

DynamicDetour dhook_CBaseObject_OnConstructionHit;
DynamicDetour dhook_CBaseObject_CreateAmmoPack;

Address CBaseObject_m_flHealth; // *((float *)a1 + 652)

Handle sdkcall_CBaseObject_GetReversesBuildingConstructionSpeed;

#endif

Handle sdkcall_JarExplode;
Handle sdkcall_GetMaxHealth;
Handle sdkcall_CAmmoPack_GetPowerupSize;
Handle sdkcall_AwardAchievement;

DynamicHook dhook_CTFWeaponBase_PrimaryAttack;
DynamicHook dhook_CTFWeaponBase_SecondaryAttack;
DynamicHook dhook_CTFBaseRocket_GetRadius;
DynamicHook dhook_CAmmoPack_MyTouch;
DynamicHook dhook_CObjectDispenser_DispenseAmmo;
DynamicHook dhook_CObjectSentrygun_OnWrenchHit;

DynamicDetour dhook_CTFPlayer_CanDisguise;
DynamicDetour dhook_CTFPlayer_CalculateMaxSpeed;
DynamicDetour dhook_CTFAmmoPack_PackTouch;
DynamicDetour dhook_CTFPlayer_AddToSpyKnife;
DynamicDetour dhook_CTFProjectile_Arrow_BuildingHealingArrow;
DynamicDetour dhook_CTFPlayer_RegenThink;

Player players[MAXPLAYERS+1];
Entity entities[2048];
int frame;
Handle hudsync;
// Menu menu_pick;
int rocket_create_entity;
int rocket_create_frame;

//cookies
Cookie g_hClientMessageCookie;
Cookie g_hClientShowMoonshot;

//weapon caching
//this would break if you ever enabled picking up weapons from the ground!
//add weapons to the FRONT of this enum to maintain the player_weapons array size
enum
{
	//Generic class features
	Feat_Airblast,
#if defined MEMORY_PATCHES
	Feat_Flamethrower, // All Flamethrowers
#endif
	Feat_Grenade, // All Grenade Launchers
	Feat_Minigun, // All Miniguns
#if defined MEMORY_PATCHES
	Feat_SniperRifle, // All Sniper Rifles
#endif
	Feat_Stickybomb, // All Stickybomb Launchers
	Feat_Sword, // All Swords

	//Item sets
	Set_SpDelivery,
	Set_GasJockey,
	Set_Expert,
	Set_Hibernate,
	Set_CrocoStyle,
	Set_Saharan,
	
	//Specific weapons
	Wep_Airstrike,
	Wep_Ambassador,
	Wep_Amputator,
	Wep_Atomizer,
	Wep_Axtinguisher,
	Wep_BabyFace,
	Wep_Backburner,
	Wep_BaseJumper,
	Wep_Beggars,
	Wep_BlackBox,
	Wep_Bonk,
	Wep_Booties,
	Wep_BrassBeast,
	Wep_BuffaloSteak,
	Wep_Bushwacka,
	Wep_CharginTarge,
	Wep_Concheror,
	Wep_CowMangler,
#if defined MEMORY_PATCHES
	Wep_CozyCamper,
#endif
	Wep_Claidheamh,
	Wep_CleanerCarbine,
	Wep_CritCola,
#if defined MEMORY_PATCHES
	Wep_Dalokohs,
#endif
	Wep_Darwin,
	Wep_DeadRinger,	
	Wep_Degreaser,
#if defined MEMORY_PATCHES
	Wep_Disciplinary,
#endif
	Wep_DragonFury,
	Wep_Enforcer,
	Wep_Pickaxe, // Equalizer
	Wep_EurekaEffect,
	Wep_Eviction,
	Wep_FistsSteel,
	Wep_Cleaver, // Flying Guillotine
#if defined MEMORY_PATCHES
	Wep_MadMilk,
#endif
	Wep_MarketGardener,
	Wep_GRU,
	Wep_Gunboats,
#if defined MEMORY_PATCHES
	Wep_Gunslinger,
#endif
	Wep_Zatoichi, // Half-Zatoichi
#if defined MEMORY_PATCHES	
	Wep_IronBomber,
#endif
	Wep_Jag,
	Wep_LibertyLauncher,
	Wep_LochLoad,
	Wep_LooseCannon,
	Wep_Natascha,
	Wep_PanicAttack,
	Wep_Persian,
	Wep_Phlogistinator,
	Wep_PocketPistol,
	Wep_Pomson,
	Wep_Powerjack,
	Wep_QuickFix,
	Wep_Quickiebomb,
	Wep_Razorback,
	Wep_RedTapeRecorder,
	Wep_RescueRanger,
	Wep_ReserveShooter,
	Wep_Bison, // Righteous Bison
	Wep_RocketJumper,
	Wep_Sandman,
	Wep_Scottish,
	Wep_ShortCircuit,
	Wep_Shortstop,
	Wep_SydneySleeper,
	Wep_SodaPopper,
	Wep_Solemn,
	Wep_SplendidScreen,
	Wep_Spycicle,
	Wep_StickyJumper,
	Wep_Tomislav,
	Wep_TideTurner,
	Wep_TribalmansShiv,
	Wep_Caber, // Ullapool Caber
	Wep_VitaSaw,
	Wep_WarriorSpirit,
	Wep_Wrangler,
	Wep_EternalReward, // Your Eternal Reward
	//must always be at the end of the enum!
	NUM_ITEMS,
}
bool player_weapons[MAXPLAYERS+1][NUM_ITEMS];
//is there a more elegant way to do this?
bool prev_player_weapons[MAXPLAYERS+1][NUM_ITEMS];
Item items[NUM_ITEMS];
char items_desc[NUM_ITEMS][MAX_VARIANTS+1][256];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	char game[128];
	GetGameFolderName(game, sizeof(game));
	if (!(StrEqual(game, "tf") && GetEngineVersion() == Engine_TF2)) {
		strcopy(error, err_max, "This plugin only works on Team Fortress 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart() {
	int idx;
	GameData conf;
	// char tmp[64];

	CCheckTrie();

	LoadTranslations("reverts.phrases.txt");

#if defined GIT_COMMIT
	CreateConVar("sm_reverts__version", PLUGIN_VERSION_GIT, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));
#else
	CreateConVar("sm_reverts__version", PLUGIN_VERSION, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));
#endif

	cvar_enable = CreateConVar("sm_reverts__enable", "1", (PLUGIN_NAME ... " - Enable plugin"), _, true, 0.0, true, 1.0);
	cvar_show_moonshot = CreateConVar("sm_reverts__show_moonshot", "0", (PLUGIN_NAME ... " - Show a HUD message when someone lands a moonshot"), _, true, 0.0, true, 1.0);
	cvar_old_falldmg_sfx = CreateConVar("sm_reverts__old_falldmg_sfx", "0", (PLUGIN_NAME ... " - Enable old (pre-inferno) fall damage sound (old bone crunch, no hurt voicelines)"), _, true, 0.0, true, 1.0);
#if defined MEMORY_PATCHES
	cvar_dropped_weapon_enable = CreateConVar("sm_reverts__enable_dropped_weapon", "0", (PLUGIN_NAME ... " - Revert dropped weapon behaviour"), _, true, 0.0, true, 1.0);
#endif
	cvar_no_reverts_info_by_default = CreateConVar("sm_reverts__no_reverts_info_on_spawn", "0", (PLUGIN_NAME ... " - Disable loadout change reverts info by default"), _, true, 0.0, true, 1.0);
	cvar_pre_toughbreak_switch = CreateConVar("sm_reverts__pre_toughbreak_switch", "0", (PLUGIN_NAME ... " - Use pre-toughbreak weapon switch time (0.67 sec instead of 0.5 sec)"), _, true, 0.0, true, 1.0);
	cvar_enable_shortstop_shove = CreateConVar("sm_reverts__enable_shortstop_shove", "0", (PLUGIN_NAME ... " - Enable alt-fire shove for reverted Shortstop"), _, true, 0.0, true, 1.0);

#if defined MEMORY_PATCHES
	cvar_dropped_weapon_enable.AddChangeHook(OnDroppedWeaponCvarChange);
#endif
	cvar_enable_shortstop_shove.AddChangeHook(OnShortstopShoveCvarChange);

	ItemDefine("airblast", "Airblast_PreJI", CLASSFLAG_PYRO, Feat_Airblast);
#if defined MEMORY_PATCHES
	ItemDefine("flamethrower", "Flamethrower_PreBM", CLASSFLAG_PYRO, Feat_Flamethrower, true);
#endif
	ItemDefine("grenade", "Grenade_Pre2014", CLASSFLAG_DEMOMAN | ITEMFLAG_DISABLED, Feat_Grenade);
#if defined MEMORY_PATCHES
	ItemDefine("miniramp", "Minigun_ramp_PreLW", CLASSFLAG_HEAVY, Feat_Minigun, true);
	ItemDefine("sniperrifles", "SniperRifle_PreLW", CLASSFLAG_SNIPER, Feat_SniperRifle, true);
#else
	ItemDefine("miniramp", "Minigun_ramp_PreLW", CLASSFLAG_HEAVY, Feat_Minigun);
#endif
	ItemDefine("stickybomb", "Stickybomb_PreLW", CLASSFLAG_DEMOMAN, Feat_Stickybomb);
	ItemDefine("swords", "Swords_PreTB", CLASSFLAG_DEMOMAN, Feat_Sword);
	ItemDefine("airstrike", "Airstrike_PreTB", CLASSFLAG_SOLDIER, Wep_Airstrike);
	ItemDefine("ambassador", "Ambassador_PreJI", CLASSFLAG_SPY, Wep_Ambassador);
	ItemDefine("amputator", "Amputator_PreTB", CLASSFLAG_MEDIC, Wep_Amputator);
	ItemDefine("atomizer", "Atomizer_PreJI", CLASSFLAG_SCOUT, Wep_Atomizer);
	ItemVariant(Wep_Atomizer, "Atomizer_PreBM");
	ItemDefine("axtinguish", "Axtinguisher_PreLW", CLASSFLAG_PYRO, Wep_Axtinguisher);
	ItemVariant(Wep_Axtinguisher, "Axtinguisher_PreTB");
	ItemVariant(Wep_Axtinguisher, "Axtinguisher_PreBM");
	ItemDefine("backburner", "Backburner_PreHat", CLASSFLAG_PYRO, Wep_Backburner);
	ItemVariant(Wep_Backburner, "Backburner_119");
	ItemVariant(Wep_Backburner, "Backburner_Release");
	ItemDefine("basejump", "BaseJumper_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN, Wep_BaseJumper);
	ItemDefine("babyface", "BabyFace_PreGM", CLASSFLAG_SCOUT, Wep_BabyFace);
	ItemVariant(Wep_BabyFace, "BabyFace_Release");
	ItemDefine("beggars", "Beggars_Pre2013", CLASSFLAG_SOLDIER, Wep_Beggars);
	ItemVariant(Wep_Beggars, "Beggars_PreTB");
	ItemDefine("blackbox", "BlackBox_PreGM", CLASSFLAG_SOLDIER, Wep_BlackBox);
	ItemDefine("bonk", "Bonk_PreJI", CLASSFLAG_SCOUT, Wep_Bonk);
	ItemDefine("booties", "Booties_PreMYM", CLASSFLAG_DEMOMAN, Wep_Booties);
	ItemDefine("brassbeast", "BrassBeast_PreMYM", CLASSFLAG_HEAVY, Wep_BrassBeast);
	ItemDefine("bushwacka", "Bushwacka_PreLW", CLASSFLAG_SNIPER, Wep_Bushwacka);
	ItemVariant(Wep_Bushwacka, "Bushwacka_PreGM");
	ItemDefine("buffalosteak", "BuffaloSteak_PreMYM", CLASSFLAG_HEAVY, Wep_BuffaloSteak);
	ItemVariant(Wep_BuffaloSteak, "BuffaloSteak_Release");
	ItemVariant(Wep_BuffaloSteak, "BuffaloSteak_Pre2013");
	ItemDefine("targe", "Targe_PreTB", CLASSFLAG_DEMOMAN, Wep_CharginTarge);
	ItemDefine("claidheamh", "Claidheamh_PreTB", CLASSFLAG_DEMOMAN, Wep_Claidheamh);
	ItemDefine("carbine", "Carbine_Release", CLASSFLAG_SNIPER, Wep_CleanerCarbine);
	ItemVariant(Wep_CleanerCarbine, "Carbine_PreTB");
	ItemDefine("concheror", "Concheror_PreTB", CLASSFLAG_SOLDIER, Wep_Concheror);
	ItemDefine("cowmangler", "CowMangler_Release", CLASSFLAG_SOLDIER, Wep_CowMangler);
	ItemVariant(Wep_CowMangler, "CowMangler_Pre2013");
#if defined MEMORY_PATCHES
	ItemDefine("cozycamper", "CozyCamper_PreMYM", CLASSFLAG_SNIPER, Wep_CozyCamper, true);
#endif
	ItemDefine("critcola", "CritCola_PreMYM", CLASSFLAG_SCOUT, Wep_CritCola);
	ItemVariant(Wep_CritCola, "CritCola_PreJI");
	ItemVariant(Wep_CritCola, "CritCola_PreDec2013");
	ItemVariant(Wep_CritCola, "CritCola_PreJuly2013");
	ItemVariant(Wep_CritCola, "CritCola_Release");
	ItemDefine("crocostyle", "CrocoStyle_Release", CLASSFLAG_SNIPER | ITEMFLAG_DISABLED, Set_CrocoStyle);
#if defined MEMORY_PATCHES
	ItemDefine("dalokohsbar", "DalokohsBar_PreMYM", CLASSFLAG_HEAVY, Wep_Dalokohs, true);
#endif
	ItemDefine("darwin", "Darwin_Pre2013", CLASSFLAG_SNIPER, Wep_Darwin);
	ItemVariant(Wep_Darwin, "Darwin_PreJI");
	ItemDefine("ringer", "Ringer_PreGM", CLASSFLAG_SPY, Wep_DeadRinger);
	ItemVariant(Wep_DeadRinger, "Ringer_PreJI");
	ItemVariant(Wep_DeadRinger, "Ringer_PreTB");
	ItemVariant(Wep_DeadRinger, "Ringer_PostRelease");
	ItemDefine("degreaser", "Degreaser_PreTB", CLASSFLAG_PYRO, Wep_Degreaser);
#if defined MEMORY_PATCHES
	ItemDefine("disciplinary", "Disciplinary_PreMYM", CLASSFLAG_SOLDIER, Wep_Disciplinary, true);
#endif
#if defined MEMORY_PATCHES
	ItemDefine("dragonfury", "DragonFury_Release", CLASSFLAG_PYRO, Wep_DragonFury, true);
#else
	ItemDefine("dragonfury", "DragonFury_Release_Patchless", CLASSFLAG_PYRO, Wep_DragonFury);
#endif
	ItemDefine("enforcer", "Enforcer_PreGM", CLASSFLAG_SPY, Wep_Enforcer);
	ItemVariant(Wep_Enforcer, "Enforcer_Release");
	ItemDefine("equalizer", "Equalizer_PrePyro", CLASSFLAG_SOLDIER, Wep_Pickaxe);
	ItemVariant(Wep_Pickaxe, "Equalizer_PreHat");
	ItemVariant(Wep_Pickaxe, "Equalizer_Release");
	ItemDefine("eureka", "Eureka_SpawnRefill", CLASSFLAG_ENGINEER, Wep_EurekaEffect);
	ItemDefine("eviction", "Eviction_PreJI", CLASSFLAG_HEAVY, Wep_Eviction);
	ItemVariant(Wep_Eviction, "Eviction_PreMYM");
	ItemDefine("expert", "Expert_Release", CLASSFLAG_DEMOMAN | ITEMFLAG_DISABLED, Set_Expert);
	ItemDefine("fiststeel", "FistSteel_PreJI", CLASSFLAG_HEAVY, Wep_FistsSteel);
	ItemVariant(Wep_FistsSteel, "FistSteel_PreTB");
	ItemVariant(Wep_FistsSteel, "FistSteel_Release");
	ItemDefine("guillotine", "Guillotine_PreJI", CLASSFLAG_SCOUT, Wep_Cleaver);
	ItemDefine("gasjockey", "GasJockey_Release", CLASSFLAG_PYRO | ITEMFLAG_DISABLED, Set_GasJockey);
	ItemDefine("glovesru", "GlovesRU_PreTB", CLASSFLAG_HEAVY, Wep_GRU);
	ItemVariant(Wep_GRU, "GlovesRU_PreJI");
	ItemVariant(Wep_GRU, "GlovesRU_PrePyro");
	ItemDefine("gunboats", "Gunboats_Release", CLASSFLAG_SOLDIER, Wep_Gunboats);
#if defined MEMORY_PATCHES
	ItemDefine("gunslinger", "Gunslinger_PreGM", CLASSFLAG_ENGINEER, Wep_Gunslinger);
	ItemVariant(Wep_Gunslinger, "Gunslinger_Release");
#endif
	ItemDefine("zatoichi", "Zatoichi_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN, Wep_Zatoichi);
	ItemDefine("hibernate", "Hibernate_Release", CLASSFLAG_HEAVY | ITEMFLAG_DISABLED, Set_Hibernate);
#if defined MEMORY_PATCHES	
	ItemDefine("ironbomber", "IronBomber_Pre2022", CLASSFLAG_DEMOMAN | ITEMFLAG_DISABLED, Wep_IronBomber, true);
#endif
	ItemDefine("jag", "Jag_PreTB", CLASSFLAG_ENGINEER, Wep_Jag);
	ItemVariant(Wep_Jag, "Jag_PreGM");  
	ItemDefine("liberty", "Liberty_Release", CLASSFLAG_SOLDIER, Wep_LibertyLauncher);
	ItemDefine("lochload", "LochLoad_PreGM", CLASSFLAG_DEMOMAN, Wep_LochLoad);
	ItemVariant(Wep_LochLoad, "LochLoad_2013");
	ItemDefine("cannon", "Cannon_PreTB", CLASSFLAG_DEMOMAN, Wep_LooseCannon);
#if defined MEMORY_PATCHES
	ItemDefine("madmilk", "MadMilk_Release", CLASSFLAG_SCOUT, Wep_MadMilk, true);
#endif
	ItemDefine("gardener", "Gardener_PreTB", CLASSFLAG_SOLDIER, Wep_MarketGardener);
	ItemDefine("natascha", "Natascha_PreMYM", CLASSFLAG_HEAVY, Wep_Natascha);
	ItemVariant(Wep_Natascha, "Natascha_PreGM");
	ItemDefine("panic", "Panic_PreJI", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO | CLASSFLAG_HEAVY | CLASSFLAG_ENGINEER, Wep_PanicAttack);
	ItemDefine("persuader", "Persuader_PreTB", CLASSFLAG_DEMOMAN, Wep_Persian);
	ItemDefine("phlog", "Phlog_Pyro", CLASSFLAG_PYRO, Wep_Phlogistinator);
	ItemVariant(Wep_Phlogistinator, "Phlog_TB");
	ItemVariant(Wep_Phlogistinator, "Phlog_Release");
	ItemVariant(Wep_Phlogistinator, "Phlog_March2012");
	ItemDefine("pomson", "Pomson_PreGM", CLASSFLAG_ENGINEER, Wep_Pomson);
	ItemVariant(Wep_Pomson, "Pomson_Release");
	ItemVariant(Wep_Pomson, "Pomson_PreGM_Historical");
	ItemDefine("powerjack", "Powerjack_PreGM", CLASSFLAG_PYRO, Wep_Powerjack);
	ItemVariant(Wep_Powerjack, "Powerjack_Release");
	ItemVariant(Wep_Powerjack, "Powerjack_Pre2013");	
	ItemDefine("pocket", "Pocket_Release", CLASSFLAG_SCOUT, Wep_PocketPistol);
	ItemVariant(Wep_PocketPistol, "Pocket_PreBM");
#if defined MEMORY_PATCHES
	ItemDefine("quickfix", "Quickfix_PreTB", CLASSFLAG_MEDIC, Wep_QuickFix, true);
#else
	ItemDefine("quickfix", "Quickfix_PreMYM", CLASSFLAG_MEDIC, Wep_QuickFix);
#endif
	ItemDefine("quickiebomb", "Quickiebomb_PreMYM", CLASSFLAG_DEMOMAN | ITEMFLAG_DISABLED, Wep_Quickiebomb);
	ItemDefine("razorback", "Razorback_PreJI", CLASSFLAG_SNIPER, Wep_Razorback);
	ItemDefine("redtape", "RedTapeRecorder_Release", CLASSFLAG_SPY | ITEMFLAG_DISABLED, Wep_RedTapeRecorder);
	ItemDefine("rescueranger", "RescueRanger_PreGM", CLASSFLAG_ENGINEER, Wep_RescueRanger);
	ItemVariant(Wep_RescueRanger, "RescueRanger_PreJI");
	ItemVariant(Wep_RescueRanger, "RescueRanger_Release");
	ItemDefine("reserve", "Reserve_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO, Wep_ReserveShooter);
	ItemVariant(Wep_ReserveShooter, "Reserve_PreJI");
	ItemVariant(Wep_ReserveShooter, "Reserve_Release");
	ItemDefine("bison", "Bison_PreMYM", CLASSFLAG_SOLDIER, Wep_Bison);
	ItemVariant(Wep_Bison, "Bison_PreTB");
	ItemDefine("rocketjmp", "RocketJmp_Pre2013", CLASSFLAG_SOLDIER, Wep_RocketJumper);
	ItemVariant(Wep_RocketJumper, "RocketJmp_Release");
	ItemVariant(Wep_RocketJumper, "RocketJmp_Pre2011");
	ItemVariant(Wep_RocketJumper, "RocketJmp_Oct2010");
	ItemDefine("saharan", "Saharan_Release", CLASSFLAG_SPY | ITEMFLAG_DISABLED, Set_Saharan);
	ItemVariant(Set_Saharan, "Saharan_ExtraCloak");
	ItemDefine("sandman", "Sandman_PreJI", CLASSFLAG_SCOUT, Wep_Sandman);
	ItemVariant(Wep_Sandman, "Sandman_PreWAR");
	ItemDefine("scottish", "Scottish_Release", CLASSFLAG_DEMOMAN | ITEMFLAG_DISABLED, Wep_Scottish);
	ItemDefine("circuit", "Circuit_PreMYM", CLASSFLAG_ENGINEER, Wep_ShortCircuit);
	ItemVariant(Wep_ShortCircuit, "Circuit_PreGM");
	ItemVariant(Wep_ShortCircuit, "Circuit_Dec2013");
	ItemDefine("shortstop", "Shortstop_PreMnvy", CLASSFLAG_SCOUT, Wep_Shortstop);
	ItemVariant(Wep_Shortstop, "Shortstop_PreGM");
	ItemVariant(Wep_Shortstop, "Shortstop_Release");
	ItemDefine("sodapop", "Sodapop_Pre2013", CLASSFLAG_SCOUT, Wep_SodaPopper);
	ItemVariant(Wep_SodaPopper, "Sodapop_PreMYM");
	ItemDefine("solemn", "Solemn_PreGM", CLASSFLAG_MEDIC, Wep_Solemn);
	ItemDefine("spdelivery", "SpDelivery_Release", CLASSFLAG_SCOUT | ITEMFLAG_DISABLED, Set_SpDelivery);
	ItemDefine("splendid", "Splendid_PreTB", CLASSFLAG_DEMOMAN, Wep_SplendidScreen);
	ItemVariant(Wep_SplendidScreen, "Splendid_Release");
	ItemDefine("spycicle", "SpyCicle_PreGM", CLASSFLAG_SPY, Wep_Spycicle);
	ItemDefine("stkjumper", "StkJumper_Pre2013", CLASSFLAG_DEMOMAN, Wep_StickyJumper);
	ItemVariant(Wep_StickyJumper, "StkJumper_Pre2013_Intel");
	ItemVariant(Wep_StickyJumper, "StkJumper_Pre2011");
	ItemVariant(Wep_StickyJumper, "StkJumper_ReleaseDay2");
	ItemDefine("sleeper", "Sleeper_PreBM", CLASSFLAG_SNIPER, Wep_SydneySleeper);
	ItemVariant(Wep_SydneySleeper, "Sleeper_PreGM");
	ItemVariant(Wep_SydneySleeper, "Sleeper_Release");	
	ItemDefine("turner", "Turner_PreTB", CLASSFLAG_DEMOMAN, Wep_TideTurner);
	ItemDefine("tomislav", "Tomislav_PrePyro", CLASSFLAG_HEAVY, Wep_Tomislav);
	ItemVariant(Wep_Tomislav, "Tomislav_Release");
	ItemDefine("tribalshiv", "TribalShiv_Release", CLASSFLAG_SNIPER, Wep_TribalmansShiv);
	ItemDefine("caber", "Caber_PreGM", CLASSFLAG_DEMOMAN, Wep_Caber);
	ItemDefine("vitasaw", "VitaSaw_PreJI", CLASSFLAG_MEDIC, Wep_VitaSaw);
	ItemDefine("warrior", "Warrior_PreTB", CLASSFLAG_HEAVY, Wep_WarriorSpirit);
	ItemDefine("wrangler", "Wrangler_PreGM", CLASSFLAG_ENGINEER, Wep_Wrangler);
	ItemVariant(Wep_Wrangler, "Wrangler_PreLW");
	ItemDefine("eternal", "Eternal_PreJI", CLASSFLAG_SPY, Wep_EternalReward);

	ItemFinalize();

	AutoExecConfig(true, "reverts", "sourcemod");

	g_hClientMessageCookie = new Cookie("reverts_messageinfo_cookie","Weapon Reverts Message Info Cookie",CookieAccess_Protected);
	g_hClientShowMoonshot = new Cookie("reverts_show_moonshot", "Weapon Reverts Show Moonshot Message", CookieAccess_Protected);

	hudsync = CreateHudSynchronizer();

	cvar_ref_tf_airblast_cray = FindConVar("tf_airblast_cray");
	cvar_ref_tf_bison_tick_time = FindConVar("tf_bison_tick_time");
	cvar_ref_tf_dropped_weapon_lifetime = FindConVar("tf_dropped_weapon_lifetime");
	cvar_ref_tf_feign_death_activate_damage_scale = FindConVar("tf_feign_death_activate_damage_scale");
	cvar_ref_tf_feign_death_damage_scale = FindConVar("tf_feign_death_damage_scale");
	cvar_ref_tf_feign_death_duration = FindConVar("tf_feign_death_duration");
	cvar_ref_tf_feign_death_speed_duration = FindConVar("tf_feign_death_speed_duration");
	cvar_ref_tf_fireball_radius = FindConVar("tf_fireball_radius");
	cvar_ref_tf_parachute_aircontrol = FindConVar("tf_parachute_aircontrol");
	cvar_ref_tf_parachute_maxspeed_onfire_z = FindConVar("tf_parachute_maxspeed_onfire_z");
	cvar_ref_tf_parachute_deploy_toggle_allowed = FindConVar("tf_parachute_deploy_toggle_allowed");
	cvar_ref_tf_scout_hype_mod = FindConVar("tf_scout_hype_mod");
	cvar_ref_tf_gamemode_mvm = FindConVar("tf_gamemode_mvm");
	cvar_ref_tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	cvar_ref_tf_sticky_airdet_radius = FindConVar("tf_sticky_airdet_radius");
	cvar_ref_tf_sticky_radius_ramp_time = FindConVar("tf_sticky_radius_ramp_time");
	cvar_ref_tf_damage_disablespread = FindConVar("tf_damage_disablespread");

#if !defined MEMORY_PATCHES
	cvar_ref_tf_dropped_weapon_lifetime.AddChangeHook(OnDroppedWeaponLifetimeCvarChange);
#endif

	RegConsoleCmd("sm_revert", Command_Menu, (PLUGIN_NAME ... " - Open reverts menu"), 0);
	RegConsoleCmd("sm_reverts", Command_Menu, (PLUGIN_NAME ... " - Open reverts menu"), 0);
	RegConsoleCmd("sm_revertinfo", Command_Info, (PLUGIN_NAME ... " - Show reverts info in console"), 0);
	RegConsoleCmd("sm_revertsinfo", Command_Info, (PLUGIN_NAME ... " - Show reverts info in console"), 0);
	RegConsoleCmd("sm_classrevert", Command_ClassInfo, (PLUGIN_NAME ... " - Show reverts for the current class"), 0);
	RegConsoleCmd("sm_classreverts", Command_ClassInfo, (PLUGIN_NAME ... " - Show reverts for the current class"), 0);
	RegConsoleCmd("sm_toggleinfo", Command_ToggleInfo, (PLUGIN_NAME ... " - Toggle the revert info dump in chat when changing loadouts"), 0);

	HookEvent("player_spawn", OnGameEvent, EventHookMode_Post);
	HookEvent("player_death", OnGameEvent, EventHookMode_Pre);
	HookEvent("post_inventory_application", OnGameEvent, EventHookMode_Post);
	HookEvent("item_pickup", OnGameEvent, EventHookMode_Post);

	AddCommandListener(CommandListener_EurekaTeleport, "eureka_teleport");

	AddNormalSoundHook(OnSoundNormal);

	{
		conf = new GameData("reverts");

		if (conf == null) SetFailState("Failed to load reverts conf");

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "JarExplode");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int iEntIndex
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer); // CTFPlayer* pAttacker
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* pOriginalWeapon
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* pWeapon
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef); // Vector& vContactPoint
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int iTeam
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); // float flRadius
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // ETFCond cond
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); // float flDuration
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // char* pszImpactEffect
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // char* pszSound
		sdkcall_JarExplode = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "CAmmoPack::GetPowerupSize");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		sdkcall_CAmmoPack_GetPowerupSize = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CBaseMultiplayerPlayer::AwardAchievement");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		sdkcall_AwardAchievement = EndPrepSDKCall();

		dhook_CTFWeaponBase_PrimaryAttack = DynamicHook.FromConf(conf, "CTFWeaponBase::PrimaryAttack");
		dhook_CTFWeaponBase_SecondaryAttack = DynamicHook.FromConf(conf, "CTFWeaponBase::SecondaryAttack");
		dhook_CTFBaseRocket_GetRadius = DynamicHook.FromConf(conf, "CTFBaseRocket::GetRadius");
		dhook_CAmmoPack_MyTouch = DynamicHook.FromConf(conf, "CAmmoPack::MyTouch");
		dhook_CObjectDispenser_DispenseAmmo = DynamicHook.FromConf(conf, "CObjectDispenser::DispenseAmmo");
		dhook_CObjectSentrygun_OnWrenchHit = DynamicHook.FromConf(conf, "CObjectSentrygun::OnWrenchHit");

		dhook_CTFPlayer_CanDisguise = DynamicDetour.FromConf(conf, "CTFPlayer::CanDisguise");
		dhook_CTFPlayer_CalculateMaxSpeed = DynamicDetour.FromConf(conf, "CTFPlayer::TeamFortress_CalculateMaxSpeed");
		dhook_CTFPlayer_AddToSpyKnife = DynamicDetour.FromConf(conf, "CTFPlayer::AddToSpyKnife");
		dhook_CTFAmmoPack_PackTouch =  DynamicDetour.FromConf(conf, "CTFAmmoPack::PackTouch");
		dhook_CTFProjectile_Arrow_BuildingHealingArrow = DynamicDetour.FromConf(conf, "CTFProjectile_Arrow::BuildingHealingArrow");
		dhook_CTFPlayer_RegenThink = DynamicDetour.FromConf(conf, "CTFPlayer::RegenThink");

		delete conf;
	}

#if defined MEMORY_PATCHES
	{
		conf = new GameData("memorypatch_reverts");

		if (conf == null) SetFailState("Failed to load memorypatch_reverts.txt conf!");

		patch_RevertDisciplinaryAction =
			MemoryPatch.CreateFromConf(conf,
			"CTFWeaponBaseMelee::OnSwingHit_2fTO3fOnAllySpeedBuff");
#if defined WIN32
		// If on Windows, perform the Address of Natives so we can patch in the address for the Discilpinary Action Ally Speedbuff.
		AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer = GetAddressOfCell(g_flNewDiscilplinaryAllySpeedBuffTimer);
#endif

		patch_RevertDragonsFury_CenterHitForBonusDmg =
			MemoryPatch.CreateFromConf(conf,
			"CTFProjectile_BallOfFire::Burn_SkipCenterHitRequirement");

		patch_RevertFlamethrowers_Density_DmgScale =
			MemoryPatch.CreateFromConf(conf,
			"CTFFlameManager::GetFlameDamageScale_SkipDensityClampingFlameDamage");
		patch_RevertFlamethrowers_Density_OnCollide =
			MemoryPatch.CreateFromConf(conf,
			"CTFFlameManager::OnCollide_SkipDensityClampingFlameDamage");
		patch_RevertMiniguns_RampupNerf_Dmg =
			MemoryPatch.CreateFromConf(conf,
			"CTFMinigun::GetProjectileDamage_JumpOver1SecondCheck");
		patch_RevertMiniguns_RampupNerf_Spread =
			MemoryPatch.CreateFromConf(conf,
			"CTFMinigun::GetWeaponSpread_JumpOver1SecondCheck");
		patch_RevertCozyCamper_FlinchNerf =
			MemoryPatch.CreateFromConf(conf,
			"CTFPlayer::ApplyPunchImpulseX_FakeFullyChargedCondition");
		patch_RevertQuickFix_Uber_CannotCapturePoint =
			MemoryPatch.CreateFromConf(conf,
			"CTFGameRules::PlayerMayCapturePoint_QuickFixUberCanCapturePoint");
		patch_RevertDalokohsBar_ChgFloatAddr =
			MemoryPatch.CreateFromConf(conf,
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOVSS_AddrTo_400");
		patch_RevertMadMilk_ChgFloatAddr =
			MemoryPatch.CreateFromConf(conf,
			"CTFWeaponBase::ApplyOnHitAttributes_Milk_HealAmount");
		patch_RevertDalokohsBar_ChgTo400 =
			MemoryPatch.CreateFromConf(conf,
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOV_400");
		patch_DroppedWeapon =
			MemoryPatch.CreateFromConf(conf,
			"CTFPlayer::DropAmmoPack");
		patch_RevertSniperRifles_ScopeJump =
			MemoryPatch.CreateFromConf(conf,
			"CTFSniperRifle::SetInternalUnzoomTime_SniperScopeJump");
		patch_RevertIronBomber_PipeHitbox =
			MemoryPatch.CreateFromConf(conf,
			"CTFWeaponBaseGun::FirePipeBomb_IronBomberHitboxRevert");			
#if !defined WIN32
		patch_RevertSniperRifles_ScopeJump_linuxextra =
			MemoryPatch.CreateFromConf(conf,
			"CTFSniperRifle::Fire_SniperScopeJump");
		PrintToServer("Made the sniperscope linuxextra patch!");
#endif

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CBaseObject::GetReversesBuildingConstructionSpeed");
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
		sdkcall_CBaseObject_GetReversesBuildingConstructionSpeed = EndPrepSDKCall();
		
		dhook_CObjectSentrygun_StartBuilding = DynamicHook.FromConf(conf, "CObjectSentrygun::StartBuilding");
		dhook_CObjectSentrygun_Construct = DynamicHook.FromConf(conf, "CObjectSentrygun::Construct");

		dhook_CTFAmmoPack_MakeHolidayPack = DynamicDetour.FromConf(conf, "CTFAmmoPack::MakeHolidayPack");
		dhook_CBaseObject_OnConstructionHit = DynamicDetour.FromConf(conf, "CBaseObject::OnConstructionHit");
		dhook_CBaseObject_CreateAmmoPack = DynamicDetour.FromConf(conf, "CBaseObject::CreateAmmoPack");

		if (sdkcall_CBaseObject_GetReversesBuildingConstructionSpeed == null) SetFailState("Failed to create sdkcall_CBaseObject_GetReversesBuildingConstructionSpeed");
		if (dhook_CObjectSentrygun_StartBuilding == null) SetFailState("Failed to create dhook_CObjectSentrygun_StartBuilding");
		if (dhook_CObjectSentrygun_Construct == null) SetFailState("Failed to create dhook_CObjectSentrygun_Construct");
		if (dhook_CTFAmmoPack_MakeHolidayPack == null) SetFailState("Failed to create dhook_CTFAmmoPack_MakeHolidayPack");
		if (dhook_CBaseObject_OnConstructionHit == null) SetFailState("Failed to create dhook_CBaseObject_OnConstructionHit");
		if (dhook_CBaseObject_CreateAmmoPack == null) SetFailState("Failed to create dhook_CBaseObject_CreateAmmoPack");

		dhook_CTFAmmoPack_MakeHolidayPack.Enable(Hook_Pre, DHookCallback_CTFAmmoPack_MakeHolidayPack);
		dhook_CBaseObject_OnConstructionHit.Enable(Hook_Pre, DHookCallback_CBaseObject_OnConstructionHit);
		dhook_CBaseObject_CreateAmmoPack.Enable(Hook_Pre, DHookCallback_CBaseObject_CreateAmmoPack);

		if (!ValidateAndNullCheck(patch_RevertDisciplinaryAction)) SetFailState("Failed to create patch_RevertDisciplinaryAction");
		if (!ValidateAndNullCheck(patch_RevertDragonsFury_CenterHitForBonusDmg)) SetFailState("Failed to create patch_RevertDragonsFury_CenterHitForBonusDmg");
		if (!ValidateAndNullCheck(patch_RevertFlamethrowers_Density_DmgScale)) SetFailState("Failed to create patch_RevertFlamethrowers_Density_DmgScale");
		if (!ValidateAndNullCheck(patch_RevertFlamethrowers_Density_OnCollide)) SetFailState("Failed to create patch_RevertFlamethrowers_Density_OnCollide");
		if (!ValidateAndNullCheck(patch_RevertMiniguns_RampupNerf_Dmg)) SetFailState("Failed to create patch_RevertMiniguns_RampupNerf_Dmg");
		if (!ValidateAndNullCheck(patch_RevertMiniguns_RampupNerf_Spread)) SetFailState("Failed to create patch_RevertMiniguns_RampupNerf_Spread");
		if (!ValidateAndNullCheck(patch_RevertCozyCamper_FlinchNerf)) SetFailState("Failed to create patch_RevertCozyCamper_FlinchNerf");
		if (!ValidateAndNullCheck(patch_RevertQuickFix_Uber_CannotCapturePoint)) SetFailState("Failed to create patch_RevertQuickFix_Uber_CannotCapturePoint");
		if (!ValidateAndNullCheck(patch_RevertMadMilk_ChgFloatAddr)) SetFailState("Failed to create patch_RevertMadMilk_ChgFloatAddr");
		if (!ValidateAndNullCheck(patch_RevertDalokohsBar_ChgFloatAddr)) SetFailState("Failed to create patch_RevertDalokohsBar_ChgFloatAddr");
		if (!ValidateAndNullCheck(patch_RevertDalokohsBar_ChgTo400)) SetFailState("Failed to create patch_RevertDalokohsBar_ChgTo400");
		if (!ValidateAndNullCheck(patch_DroppedWeapon)) SetFailState("Failed to create patch_DroppedWeapon");
		if (!ValidateAndNullCheck(patch_RevertSniperRifles_ScopeJump)) SetFailState("Failed to create patch_RevertSniperRifles_ScopeJump");
		if (!ValidateAndNullCheck(patch_RevertIronBomber_PipeHitbox)) SetFailState("Failed to create patch_RevertIronBomber_PipeHitbox");
#if !defined WIN32
		if (!ValidateAndNullCheck(patch_RevertSniperRifles_ScopeJump_linuxextra)) SetFailState("Failed to create patch_RevertSniperRifles_ScopeJump_linuxextra");
		PrintToServer("Nullchecked and validates sniperscope jump linux extra!");
#endif
		AddressOf_g_flDalokohsBarCanOverHealTo = GetAddressOfCell(g_flDalokohsBarCanOverHealTo);
		AddressOf_g_flMadMilkHealTarget = GetAddressOfCell(g_flMadMilkHealTarget);

		CBaseObject_m_flHealth = view_as<Address>(FindSendPropInfo("CBaseObject", "m_bHasSapper") - 4);

		delete conf;
	}
#endif

	{
		conf = LoadGameConfigFile("sdkhooks.games");

		if (conf == null) SetFailState("Failed to load sdkhooks conf");

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "GetMaxHealth");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		sdkcall_GetMaxHealth = EndPrepSDKCall();

		delete conf;
	}

	if (sdkcall_JarExplode == null) SetFailState("Failed to create sdkcall_JarExplode");
	if (sdkcall_GetMaxHealth == null) SetFailState("Failed to create sdkcall_GetMaxHealth");
	if (sdkcall_CAmmoPack_GetPowerupSize == null) SetFailState("Failed to create sdkcall_CAmmoPack_GetPowerupSize");
	if (sdkcall_AwardAchievement == null) SetFailState("Failed to create sdkcall_AwardAchievement");
	if (dhook_CTFWeaponBase_PrimaryAttack == null) SetFailState("Failed to create dhook_CTFWeaponBase_PrimaryAttack");
	if (dhook_CTFWeaponBase_SecondaryAttack == null) SetFailState("Failed to create dhook_CTFWeaponBase_SecondaryAttack");
	if (dhook_CTFBaseRocket_GetRadius == null) SetFailState("Failed to create dhook_CTFBaseRocket_GetRadius");
	if (dhook_CTFPlayer_CanDisguise == null) SetFailState("Failed to create dhook_CTFPlayer_CanDisguise");
	if (dhook_CTFPlayer_CalculateMaxSpeed == null) SetFailState("Failed to create dhook_CTFPlayer_CalculateMaxSpeed");
	if (dhook_CTFPlayer_AddToSpyKnife == null) SetFailState("Failed to create dhook_CTFPlayer_AddToSpyKnife");
	if (dhook_CAmmoPack_MyTouch == null) SetFailState("Failed to create dhook_CAmmoPack_MyTouch");
	if (dhook_CTFAmmoPack_PackTouch == null) SetFailState("Failed to create dhook_CTFAmmoPack_PackTouch");
	if (dhook_CTFProjectile_Arrow_BuildingHealingArrow == null) SetFailState("Failed to create dhook_CTFProjectile_Arrow_BuildingHealingArrow");
	if (dhook_CTFPlayer_RegenThink == null) SetFailState("Failed to create dhook_CTFPlayer_RegenThink");
	if (dhook_CObjectDispenser_DispenseAmmo == null) SetFailState("Failed to create dhook_CObjectDispenser_DispenseAmmo");
	if (dhook_CObjectSentrygun_OnWrenchHit == null) SetFailState("Failed to create dhook_CObjectSentrygun_OnWrenchHit");

	dhook_CTFPlayer_CanDisguise.Enable(Hook_Post, DHookCallback_CTFPlayer_CanDisguise);
	dhook_CTFPlayer_CalculateMaxSpeed.Enable(Hook_Post, DHookCallback_CTFPlayer_CalculateMaxSpeed);
	dhook_CTFPlayer_AddToSpyKnife.Enable(Hook_Pre, DHookCallback_CTFPlayer_AddToSpyKnife);
	dhook_CTFAmmoPack_PackTouch.Enable(Hook_Pre, DHookCallback_CTFAmmoPack_PackTouch);
	dhook_CTFProjectile_Arrow_BuildingHealingArrow.Enable(Hook_Pre, DHookCallback_CTFProjectile_Arrow_BuildingHealingArrow_Pre);
	dhook_CTFProjectile_Arrow_BuildingHealingArrow.Enable(Hook_Post, DHookCallback_CTFProjectile_Arrow_BuildingHealingArrow_Post);
	dhook_CTFPlayer_RegenThink.Enable(Hook_Pre, DHookCallback_CTFPlayer_RegenThink);

	for (idx = 1; idx <= MaxClients; idx++) {
		if (IsClientConnected(idx)) OnClientConnected(idx);
		if (IsClientInGame(idx)) OnClientPutInServer(idx);
	}
}


#if defined MEMORY_PATCHES
public void OnDroppedWeaponCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	// weapon pickups are disabled to ensure attribute consistency
	SetConVarMaybe(cvar_ref_tf_dropped_weapon_lifetime, "0", !convar.BoolValue);
	if (convar.BoolValue) {
		patch_DroppedWeapon.Enable();
	} else {
		patch_DroppedWeapon.Disable();
	}
}
#else
public void OnDroppedWeaponLifetimeCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	SetConVarMaybe(cvar_ref_tf_dropped_weapon_lifetime, "0", cvar_enable.BoolValue);
}
#endif

public void OnShortstopShoveCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	UpdateShortstopDescription();
}

void UpdateShortstopDescription() {
	int i = Wep_Shortstop;
	char shove_str[] = "_Shove";

	for (int j = 0; j <= items[i].num_variants; j++) {
		if (cvar_enable_shortstop_shove.BoolValue) {
			if (StrContains(items_desc[i][j], shove_str) == -1) {
				Format(items_desc[i][j], sizeof(items_desc[][]), "%s%s", items_desc[i][j], shove_str);
			}
		} else {
			ReplaceString(items_desc[i][j], sizeof(items_desc[][]), shove_str, "");
		}
	}
}

public void OnConfigsExecuted() {
#if defined MEMORY_PATCHES
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_Disciplinary),Wep_Disciplinary);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_DragonFury),Wep_DragonFury);
	ToggleMemoryPatchReverts(ItemIsEnabled(Feat_Flamethrower),Feat_Flamethrower);
	ToggleMemoryPatchReverts(ItemIsEnabled(Feat_Minigun),Feat_Minigun);
	ToggleMemoryPatchReverts(ItemIsEnabled(Feat_SniperRifle),Feat_SniperRifle);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_CozyCamper),Wep_CozyCamper);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_QuickFix),Wep_QuickFix);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_Dalokohs),Wep_Dalokohs);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_MadMilk),Wep_MadMilk);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_IronBomber),Wep_IronBomber);
	OnDroppedWeaponCvarChange(cvar_dropped_weapon_enable, "0", "0");
#else
	SetConVarMaybe(cvar_ref_tf_dropped_weapon_lifetime, "0", cvar_enable.BoolValue);
#endif
	UpdateShortstopDescription();
}

#if defined MEMORY_PATCHES
bool ValidateAndNullCheck(MemoryPatch patch) {
	return patch.Validate() && patch != null;
}

void OnServerCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char cvarName[128];
	convar.GetName(cvarName, sizeof(cvarName));	
	if (StrContains(cvarName, "sm_reverts__item_") != -1)
	{
		char item[64];
		strcopy(item,sizeof(item),cvarName[strlen("sm_reverts__item_")]);
		for (int i; i < NUM_ITEMS; i++) {
			if (StrEqual(items[i].key,item)) {
				ToggleMemoryPatchReverts(ItemIsEnabled(i),i);
				return;
			}
		}
	}
}

void ToggleMemoryPatchReverts(bool enable, int wep_enum) {
	switch(wep_enum) {
		case Wep_Disciplinary: {
			if (enable) {
#if defined WIN32
				patch_RevertDisciplinaryAction.Enable();
				// The Windows port of Disciplinary Action Revert requires a extra step.
				StoreToAddress(patch_RevertDisciplinaryAction.Address + view_as<Address>(0x02), view_as<int>(AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer), NumberType_Int32);
#else
				patch_RevertDisciplinaryAction.Enable();
#endif
			} else {
				patch_RevertDisciplinaryAction.Disable();
			}
		}
		case Wep_DragonFury: {
			if (enable) {
				patch_RevertDragonsFury_CenterHitForBonusDmg.Enable();
			} else {
				patch_RevertDragonsFury_CenterHitForBonusDmg.Disable();
			}
		}
		case Feat_Flamethrower: {
			if (enable) {
				patch_RevertFlamethrowers_Density_DmgScale.Enable();
				patch_RevertFlamethrowers_Density_OnCollide.Enable();
			} else {
				patch_RevertFlamethrowers_Density_DmgScale.Disable();
				patch_RevertFlamethrowers_Density_OnCollide.Disable();
			}
		}
		case Feat_Minigun: {
			if (enable) {
				patch_RevertMiniguns_RampupNerf_Dmg.Enable();
				patch_RevertMiniguns_RampupNerf_Spread.Enable();
			} else {
				patch_RevertMiniguns_RampupNerf_Dmg.Disable();
				patch_RevertMiniguns_RampupNerf_Spread.Disable();
			}
		}
		case Feat_SniperRifle: {
			if (enable) {
				patch_RevertSniperRifles_ScopeJump.Enable();
#if !defined WIN32
				patch_RevertSniperRifles_ScopeJump_linuxextra.Enable();
				PrintToServer("patch_RevertSniperRifles_ScopeJump_linuxextra enabled!");
#endif
			} else {
				patch_RevertSniperRifles_ScopeJump.Disable();
#if !defined WIN32
				patch_RevertSniperRifles_ScopeJump_linuxextra.Disable();
#endif
			}
		}
		case Wep_CozyCamper: {
			if (enable) {
				patch_RevertCozyCamper_FlinchNerf.Enable();
			} else {
				patch_RevertCozyCamper_FlinchNerf.Disable();
			}
		}
		case Wep_QuickFix: {
			if (enable) {
				patch_RevertQuickFix_Uber_CannotCapturePoint.Enable();
			} else {
				patch_RevertQuickFix_Uber_CannotCapturePoint.Disable();
			}
		}
		case Wep_Dalokohs: {
			if (enable) {
				patch_RevertDalokohsBar_ChgFloatAddr.Enable();
				patch_RevertDalokohsBar_ChgTo400.Enable();

				// Due to it being a MOVSS instruction that needs
				// a Address instead of values, there's some extra steps to be done in here:
				StoreToAddress(patch_RevertDalokohsBar_ChgFloatAddr.Address + view_as<Address>(0x04), view_as<int>(AddressOf_g_flDalokohsBarCanOverHealTo), NumberType_Int32);
			} else {
				patch_RevertDalokohsBar_ChgFloatAddr.Disable();
				patch_RevertDalokohsBar_ChgTo400.Disable();
			}
		}
		case Wep_MadMilk: {
			if (enable) {
				patch_RevertMadMilk_ChgFloatAddr.Enable();
				StoreToAddress(patch_RevertMadMilk_ChgFloatAddr.Address + view_as<Address>(0x04), view_as<int>(AddressOf_g_flMadMilkHealTarget), NumberType_Int32);
			} else {
				patch_RevertMadMilk_ChgFloatAddr.Disable();
			}
		}
		case Wep_IronBomber: {
			if (enable) {
				patch_RevertIronBomber_PipeHitbox.Enable();
			} else {
				patch_RevertIronBomber_PipeHitbox.Disable();
			}
		}		
	}
}
#endif

public void OnMapStart() {
	PrecacheSound("items/ammo_pickup.wav");
	PrecacheSound("items/gunpickup2.wav");
	PrecacheSound("misc/banana_slip.wav");
	PrecacheScriptSound("Jar.Explode");
	PrecacheScriptSound("Player.ResistanceLight");
}

public void OnGameFrame() {
	int idx;
	char class[64];
	float cloak;
	int weapon;
	int ammo;
	int clip;
	//int ent;
	float timer;
	float pos1[3];
	//float pos2[3];
	//float maxs[3];
	//float mins[3];
	float hype;
	int airdash_value;
	int airdash_limit_old;
	int airdash_limit_new;

	frame++;

	// run every frame
	if (frame % 1 == 0) {
		for (idx = 1; idx <= MaxClients; idx++) {
			if (
				IsClientInGame(idx) &&
				IsPlayerAlive(idx)
			) {
				{
					// respawn to apply attribs

					// if (players[idx].respawn > 0) {
					// 	if ((players[idx].respawn + 2) == GetGameTickCount()) {
					// 		TF2_RespawnPlayer(idx);
					// 		players[idx].respawn = 0;

					// 		PrintToChat(idx, "[SM] Revert changes have been applied");
					// 	}

					// 	continue;
					// }
				}

				{
					// used for reserve shooter
					++players[idx].ticks_since_switch;
				}

				{
					// reset medigun info
					// if player is medic, this will be set again this frame

					players[idx].medic_medigun_defidx = 0;
					players[idx].medic_medigun_charge = 0.0;
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Scout) {
					{
						// extra jump stuff (atomizer/sodapop)
						// truly a work of art

						airdash_limit_old = 1; // multijumps allowed by game
						airdash_limit_new = 1; // multijumps we want to allow

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Melee);

						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));

							if (
								StrEqual(class, "tf_weapon_bat") &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 450
							) {
								switch (GetItemVariant(Wep_Atomizer)) {
									case -1: {
										if (weapon == GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon")) {
											airdash_limit_old = 2;
											airdash_limit_new = 2;
										}
									}
									case 0: airdash_limit_new = 2;
									case 1: {
										if (weapon == GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon")) {
											airdash_limit_new = 2;
										}
									}	
								}
							}
						}

						if (TF2_IsPlayerInCondition(idx, TFCond_CritHype)) {
							airdash_limit_old = 5;

							if (GetItemVariant(Wep_SodaPopper) != 0) {
								airdash_limit_new = 5;
							}
						}

						if (TF2_IsPlayerInCondition(idx, TFCond_HalloweenSpeedBoost)) {
							airdash_limit_old = 999;
							airdash_limit_new = 999;
						}

						airdash_value = GetEntProp(idx, Prop_Send, "m_iAirDash");

						if (airdash_value > players[idx].scout_airdash_value) {
							// airdash happened this frame

							players[idx].scout_airdash_count++;

							if (
								airdash_limit_new == 2 &&
								ItemIsEnabled(Wep_Atomizer)
							) {
								if (
									GetItemVariant(Wep_Atomizer) == 0 ||
									(GetItemVariant(Wep_Atomizer) == 1 && players[idx].scout_airdash_count == 2)
								) {
									// emit purple smoke (still shows white smoke too but good enough for now)
									GetEntPropVector(idx, Prop_Send, "m_vecOrigin", pos1);
									ParticleShowSimple("doublejump_puff_alt", pos1);
								}

								if (players[idx].scout_airdash_count == 2) {
									// atomizer global jump
									if (GetItemVariant(Wep_Atomizer) == 0) {
										SDKHooks_TakeDamage(idx, idx, idx, 10.0, (DMG_BULLET|DMG_PREVENT_PHYSICS_FORCE), -1, NULL_VECTOR, NULL_VECTOR);
									}

									if (airdash_limit_new > airdash_limit_old) {
										// only play sound if the game doesn't play it
										EmitSoundToAll("misc/banana_slip.wav", idx, SNDCHAN_AUTO, 30, (SND_CHANGEVOL|SND_CHANGEPITCH), 1.0, 100);
									}	
								}
							}
						} else {
							if ((GetEntityFlags(idx) & FL_ONGROUND) != 0) {
								players[idx].scout_airdash_count = 0;
							}
						}

						if (airdash_value >= 1) {
							if (
								airdash_value >= airdash_limit_old &&
								players[idx].scout_airdash_count < airdash_limit_new
							) {
								airdash_value = (airdash_limit_old - 1);
							}

							if (
								airdash_value < airdash_limit_old &&
								players[idx].scout_airdash_count >= airdash_limit_new
							) {
								airdash_value = airdash_limit_old;
							}
						}

						players[idx].scout_airdash_value = airdash_value;

						if (airdash_value != GetEntProp(idx, Prop_Send, "m_iAirDash")) {
							SetEntProp(idx, Prop_Send, "m_iAirDash", airdash_value);
						}
					}

					{
						// bonk effect

						if (TF2_IsPlayerInCondition(idx, TFCond_Bonked)) {
							players[idx].bonk_cond_frame = GetGameTickCount();
						}
					}

					{
						// guillotine recharge

						if (ItemIsEnabled(Wep_Cleaver)) {
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Secondary);

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_cleaver")) {
									timer = GetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime");

									if (
										timer > 0.1 &&
										players[idx].cleaver_regen_time > 0.1 &&
										(players[idx].cleaver_regen_time - timer) > 1.49 &&
										(players[idx].cleaver_regen_time - timer) < 1.51
									) {
										timer = players[idx].cleaver_regen_time;
										SetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime", timer);
									}

									players[idx].cleaver_regen_time = timer;
								}
							}
						}
					}

					{
						// sodapopper stuff

						if (ItemIsEnabled(Wep_SodaPopper)) {
							if (
								GetItemVariant(Wep_SodaPopper) == 0 &&
								players[idx].is_under_hype
							) {
								// allow mini-crit buff to last indefinitely
								SetEntPropFloat(idx, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
							}

							weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (
									players[idx].is_under_hype == false &&
									StrEqual(class, "tf_weapon_soda_popper") &&
									TF2_IsPlayerInCondition(idx, TFCond_CritHype) == false
								) {
									if (
										GetItemVariant(Wep_SodaPopper) == 0 &&
										GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter") >= 100.0
									) {
										// Fall back to hype condition if the player has a drink item
										bool has_lunchbox = (player_weapons[idx][Wep_Bonk] || player_weapons[idx][Wep_CritCola]);
										TF2_AddCondition(idx, has_lunchbox ? TFCond_CritHype : TFCond_CritCola, 11.0, 0);
										players[idx].is_under_hype = has_lunchbox ? false : true;
									}

									if (
										weapon == GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon") &&
										GetEntProp(idx, Prop_Data, "m_nWaterLevel") <= 1 &&
										GetEntityMoveType(idx) == MOVETYPE_WALK
									) {
										// add hype according to speed

										GetEntPropVector(idx, Prop_Data, "m_vecVelocity", pos1);

										hype = GetVectorLength(pos1);
										hype = (hype * GetTickInterval());
										hype = (hype / cvar_ref_tf_scout_hype_mod.FloatValue);
										hype = (hype + GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter"));
										hype = (hype > 100.0 ? 100.0 : hype);

										SetEntPropFloat(idx, Prop_Send, "m_flHypeMeter", hype);
									}
								}

								// hype meter drain on minicrit condition
								if (
									GetItemVariant(Wep_SodaPopper) == 0 &&
									players[idx].is_under_hype
								) {
									hype = GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter");

									if (hype <= 0.0)
									{
										players[idx].is_under_hype = false;
										TF2_RemoveCondition(idx, TFCond_CritCola);
									}
									else
									{
										hype -= 9.375 * GetTickInterval(); // m_fEnergyDrinkConsumeRate*0.75f
										SetEntPropFloat(idx, Prop_Send, "m_flHypeMeter", floatMax(hype, 0.0));
									}
								}
							}
						}
					}
				} else {
					// reset if player isn't scout
					players[idx].is_under_hype = false;
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Soldier) {
					{
						// beggars overload

						// overload is detected via rocket entity spawn/despawn and ammo change
						// pretty hacky but it works I guess

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));

							if (
								StrEqual(class, "tf_weapon_rocketlauncher") &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 730
							) {
								clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
								ammo = GetEntProp(idx, Prop_Send, "m_iAmmo", 4, 1);

								if (
									GetItemVariant(Wep_Beggars) == 0 &&
									players[idx].beggars_ammo >= 3 &&
									clip == (players[idx].beggars_ammo - 1) &&
									rocket_create_entity == -1 &&
									(rocket_create_frame + 1) == GetGameTickCount() &&
									ammo > 0
								) {
									clip = (clip + 1);
									SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
									SetEntProp(idx, Prop_Send, "m_iAmmo", (ammo - 1), 4, 1);
								}

								players[idx].beggars_ammo = clip;
							}
						}
					}
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Pyro) {
					{
						// Powerjack overheal on kill

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Melee);

						if (weapon > 0) {

							if (
								ItemIsEnabled(Wep_Powerjack) &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 214 &&
								players[idx].powerjack_kill_tick + 1 == GetGameTickCount()
							) {
								int max_overheal = TF2Util_GetPlayerMaxHealthBoost(idx);
								int health_cur = GetClientHealth(idx);
								int health_max = SDKCall(sdkcall_GetMaxHealth, idx);

								int heal_amt = TF2Attrib_HookValueInt(0, "heal_on_kill", weapon);
								if (health_max - health_cur >= heal_amt)
									heal_amt = 0;
								else if (health_max > health_cur)
									heal_amt -= health_max - health_cur;
								
								heal_amt = intMin(max_overheal - health_cur, heal_amt);

								if (heal_amt > 0) {
									// Apply overheal
									TF2Util_TakeHealth(idx, float(heal_amt), TAKEHEALTH_IGNORE_MAXHEALTH);
								}
							}
						}
					}

					{
						// Phlog rage takes 225 damage to fully fill (from 300)

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

						if (weapon > 0) {

							if (
								ItemIsEnabled(Wep_Phlogistinator) &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 594
							) {
								hype = GetEntPropFloat(idx, Prop_Send, "m_flRageMeter");
								float delta = hype - players[idx].pyro_rage_meter;

								if (delta > 0.0) {
									delta *= 1.33333333; // 300.0 / 225.0
									hype = floatMin(players[idx].pyro_rage_meter + delta, 100.0);
									SetEntPropFloat(idx, Prop_Send, "m_flRageMeter", hype);
								}

								players[idx].pyro_rage_meter = hype;
							}
						}
					}
				}

#if !defined MEMORY_PATCHES
				if (TF2_GetPlayerClass(idx) == TFClass_Heavy) {
					{
						// Patchless minigun rampup revert

						if (
							ItemIsEnabled(Feat_Minigun) &&
							TF2_IsPlayerInCondition(idx, TFCond_Slowed)
						) {
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_minigun")) {
									float spinup_time = TF2Attrib_HookValueFloat(TF_MINIGUN_SPINUP_TIME, "mult_minigun_spinup_time", weapon);
									float spunup_duration = GetGameTime() - players[idx].aiming_cond_time - spinup_time;

									if (spunup_duration < TF_MINIGUN_PENALTY_PERIOD) {

										// weapon spread
										// inverse of flMod = RemapValClamped( flSpinTime, 0.f, TF_MINIGUN_PENALTY_PERIOD, 1.5f, 1.f );
										TF2Attrib_SetByDefIndex(weapon, 36, ValveRemapVal(spunup_duration, 0.0, TF_MINIGUN_PENALTY_PERIOD, 0.66666667, 1.0));

										// damage
										// inverse of flMod = RemapValClamped( flSpinTime, 0.2f, TF_MINIGUN_PENALTY_PERIOD, 0.5f, 1.f );
										TF2Attrib_SetByDefIndex(weapon, 476, ValveRemapVal(spunup_duration, 0.2, TF_MINIGUN_PENALTY_PERIOD, 2.0, 1.0));
									} else {
										// once we've stayed spun up for long enough remove the attribs
										TF2Attrib_RemoveByDefIndex(weapon, 36);
										TF2Attrib_RemoveByDefIndex(weapon, 476);
									}
								}
							}
						}
					}
				}
#endif

				if (TF2_GetPlayerClass(idx) == TFClass_Medic) {
					{
						// vitasaw charge store

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Secondary);

						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));

							if (StrEqual(class, "tf_weapon_medigun")) {
								players[idx].medic_medigun_defidx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
								players[idx].medic_medigun_charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
							}
						}
					}
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Sniper) {
					{
						// release cleaner's carbine use crikey meter to indicate remaining buff duration
						// this is purely a custom visual thing
						if (GetItemVariant(Wep_CleanerCarbine) == 0) {
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Secondary);

							if (weapon > 0) {

								if (HasEntProp(weapon, Prop_Send, "m_flMinicritCharge")) {
									hype = GetEntPropFloat(weapon, Prop_Send, "m_flMinicritCharge");
									timer = TF2Attrib_HookValueFloat(0.0, "add_onkill_critboost_time", weapon);

									if (timer != 0.0) timer += 1.0;

									if (hype > 0.0 && timer > 0.0) {
										hype -= 100.0 / timer * GetTickInterval();
										SetEntPropFloat(weapon, Prop_Send, "m_flMinicritCharge", floatMax(hype, 0.0));
									}
								}
							}
						}
					}

					{
						// razorback no recharge

						if (
							ItemIsEnabled(Wep_Razorback) &&
							player_weapons[idx][Wep_Razorback]
						) {
							for (int i = 0; i < TF2Util_GetPlayerWearableCount(idx); i++)
							{
								weapon = TF2Util_GetPlayerWearable(idx, i);

								if (weapon > 0) {

									if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 57) {
	
										timer = GetEntPropFloat(idx, Prop_Send, "m_flItemChargeMeter", LOADOUT_POSITION_SECONDARY);
										if (timer < 1.0) {
											RemoveEntity(weapon);
											player_weapons[idx][Wep_Razorback] = false;
										}
									}
								}
							}
						}
					}
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Spy) {
					{
						// "old-style" dead ringer cloak meter mechanics

						if (players[idx].spy_is_feigning == false) {
							if (
								TF2_IsPlayerInCondition(idx, TFCond_Cloaked) &&
								player_weapons[idx][Wep_DeadRinger]
							) {
								players[idx].spy_is_feigning = true;
								players[idx].damage_taken_during_feign = 0.0;
								switch (GetItemVariant(Wep_DeadRinger)) {
									case 0, 3: {
										players[idx].spy_under_feign_buffs = true;
									}
								}
							}
						} else {
							if (
								TF2_IsPlayerInCondition(idx, TFCond_Cloaked) == false &&
								player_weapons[idx][Wep_DeadRinger]
							) {
								players[idx].spy_is_feigning = false;
								players[idx].spy_under_feign_buffs = false;

								switch (GetItemVariant(Wep_DeadRinger)) {
									case 0: { // pre-GM
										// when uncloaking, cloak is drained to 40%

										if (GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter") > 40.0) {
											SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", 40.0);
										}
									}
									case 3: { // post-release
										// fully drain meter when uncloaking

										if (GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter") > 0.0) {
											SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", 0.0);
										}
									}
								}
							}
						}

						cloak = GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter");

						if (GetItemVariant(Wep_DeadRinger) == 0) {
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Building);

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (
									StrEqual(class, "tf_weapon_invis") &&
									GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 59
								) {
									if (
										(cloak - players[idx].spy_cloak_meter) > 35.0 &&
										(players[idx].ammo_grab_frame + 1) == GetGameTickCount()
									) {
										// ammo boxes only give 35% cloak max
										cloak = (players[idx].spy_cloak_meter + 35.0);
										SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", cloak);	
									}
									if (players[idx].cloak_gain_capped) {
										TF2Attrib_RemoveByDefIndex(weapon, 729);
										players[idx].cloak_gain_capped = false;
									}
								}
							}
						}

						players[idx].spy_cloak_meter = cloak;
					}

					{
						// "old-style" deadringer feign buff canceling
						if (
							players[idx].spy_is_feigning &&
							players[idx].spy_under_feign_buffs
						) {
							if (GetFeignBuffsEnd(idx) < GetGameTickCount()) {
								players[idx].spy_under_feign_buffs = false;
							}
						}
					}

					{
						// spycicle recharge

						if (ItemIsEnabled(Wep_Spycicle)) {
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Melee);

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (
									StrEqual(class, "tf_weapon_knife") &&
									GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 649
								) {
									timer = GetEntPropFloat(weapon, Prop_Send, "m_flKnifeMeltTimestamp");

									if (
										timer > 0.1 &&
										players[idx].icicle_regen_time > 0.1 &&
										players[idx].icicle_regen_time > timer &&
										(players[idx].ammo_grab_frame + 1) == GetGameTickCount()
									) {
										timer = players[idx].icicle_regen_time;
										SetEntPropFloat(weapon, Prop_Send, "m_flKnifeMeltTimestamp", timer);
									}

									players[idx].icicle_regen_time = timer;
								}
							}
						}
					}
				} else {
					// reset if player isn't spy
					players[idx].spy_is_feigning = false;
					players[idx].spy_under_feign_buffs = false;
					players[idx].cloak_gain_capped = false;
				}

				if (
					TF2_GetPlayerClass(idx) == TFClass_Soldier ||
					TF2_GetPlayerClass(idx) == TFClass_DemoMan
				) {
					{
						// zatoichi honorbound

						if (ItemIsEnabled(Wep_Zatoichi)) {
							weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_katana")) {
									if (
										GetEntProp(idx, Prop_Send, "m_iKillCountSinceLastDeploy") == 0 &&
										GetGameTime() >= GetEntPropFloat(idx, Prop_Send, "m_flFirstPrimaryAttack") &&
										(GetGameTime() - players[idx].resupply_time) > 1.5
									) {
										// this cond is very convenient
										TF2_AddCondition(idx, TFCond_RestrictToMelee, 0.100, 0);
									}
								}
							}
						}
					}
				}

				if (TF2_GetPlayerClass(idx) != TFClass_Engineer) {
					// reset if player isn't engineer
					players[idx].is_eureka_teleporting = false;
				}
			} else {
				// reset if player is dead
				players[idx].spy_is_feigning = false;
				players[idx].scout_airdash_value = 0;
				players[idx].scout_airdash_count = 0;
				players[idx].is_under_hype = false;
				players[idx].holding_jump = false;
				players[idx].spy_under_feign_buffs = false;
				players[idx].is_eureka_teleporting = false;
				players[idx].eureka_teleport_target = -1;
				players[idx].cloak_gain_capped = false;
			}
		}
	}

	// run every 3 frames
	if (frame % 3 == 0) {
		for (idx = 1; idx <= MaxClients; idx++) {
			if (
				IsClientInGame(idx) &&
				IsPlayerAlive(idx)
			) {
				{
					// fix weapons being invisible after sandman stun
					// this bug apparently existed before sandman nerf

					weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

					if (
						weapon > 0 &&
						(GetEntProp(weapon, Prop_Send, "m_fEffects") & EF_NODRAW) != 0 &&
						(GetGameTime() - players[idx].stunball_fix_time_bonk) < 10.0 &&
						TF2_IsPlayerInCondition(idx, TFCond_Dazed) == false
					) {
						if (players[idx].stunball_fix_time_wear == 0.0) {
							players[idx].stunball_fix_time_wear = GetGameTime();
						} else {
							if ((GetGameTime() - players[idx].stunball_fix_time_wear) > 0.100) {
								SetEntProp(weapon, Prop_Send, "m_fEffects", (GetEntProp(weapon, Prop_Send, "m_fEffects") & ~EF_NODRAW));

								players[idx].stunball_fix_time_bonk = 0.0;
								players[idx].stunball_fix_time_wear = 0.0;
							}
						}
					}
				}
			}
		}
	}

	// run every 66 frames (~1s)
	if (frame % 66 == 0) {
		{
			// set all the convars needed

			// these cvars are changed just-in-time, reset them
			cvar_ref_tf_airblast_cray.RestoreDefault();
			cvar_ref_tf_feign_death_duration.RestoreDefault();
			cvar_ref_tf_feign_death_speed_duration.RestoreDefault();
			cvar_ref_tf_feign_death_activate_damage_scale.RestoreDefault();
			cvar_ref_tf_feign_death_damage_scale.RestoreDefault();

			// these cvars are global, set them to the desired value
			SetConVarMaybe(cvar_ref_tf_bison_tick_time, "0.001", ItemIsEnabled(Wep_Bison));
			SetConVarMaybe(cvar_ref_tf_fireball_radius, "30.0", ItemIsEnabled(Wep_DragonFury));
			SetConVarMaybe(cvar_ref_tf_parachute_aircontrol, "5", ItemIsEnabled(Wep_BaseJumper));
			SetConVarMaybe(cvar_ref_tf_parachute_maxspeed_onfire_z, "10.0", ItemIsEnabled(Wep_BaseJumper));
			SetConVarMaybe(cvar_ref_tf_parachute_deploy_toggle_allowed, "1", ItemIsEnabled(Wep_BaseJumper));

			// Winbomb revert cvars for stickybomb launchers
			SetConVarMaybe(cvar_ref_tf_sticky_airdet_radius, "1.0", ItemIsEnabled(Feat_Stickybomb));
			SetConVarMaybe(cvar_ref_tf_sticky_radius_ramp_time, "0.0", ItemIsEnabled(Feat_Stickybomb));
		}
	}
}

public void OnClientConnected(int client) {
	// reset these per player
	//players[client].respawn = 0;
	players[client].resupply_time = 0.0;
	players[client].medic_medigun_defidx = 0;
	players[client].medic_medigun_charge = 0.0;
	players[client].received_help_notice = false;

	for (int i = 0; i < NUM_ITEMS; i++) {
		prev_player_weapons[client][i] = false;
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_TraceAttack, SDKHookCB_TraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDKHookCB_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_OnTakeDamagePost);
	SDKHook(client, SDKHook_WeaponSwitchPost, SDKHookCB_WeaponSwitchPost);
}

public void OnEntityCreated(int entity, const char[] class) {
	if (entity < 0 || entity >= 2048) {
		// sourcemod calls this with entrefs for non-networked ents ??
		return;
	}

	entities[entity].exists = true;
	entities[entity].spawn_time = 0.0;
	entities[entity].is_demo_shield = false;
	entities[entity].old_shield = 0;
	entities[entity].minisentry_health = 0.0;

	if (StrEqual(class, "tf_wearable_demoshield")) {
		entities[entity].is_demo_shield = true;
	}

	if (
		StrEqual(class, "tf_projectile_stun_ball") ||
		StrEqual(class, "tf_projectile_energy_ring") ||
		StrEqual(class, "tf_projectile_cleaver")
	) {
		SDKHook(entity, SDKHook_Spawn, SDKHookCB_Spawn);
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_SpawnPost);
		SDKHook(entity, SDKHook_Touch, SDKHookCB_Touch);
	}

	if (
		StrEqual(class, "obj_sentrygun") ||
		StrEqual(class, "obj_dispenser") ||
		StrEqual(class, "obj_teleporter")
	) {
		SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage_Building);
	}

	if (StrEqual(class, "instanced_scripted_scene")) {
		SDKHook(entity, SDKHook_Spawn, SDKHookCB_Spawn);
	}

	if (StrEqual(class, "tf_projectile_rocket")) {
		// keep track of when rockets are created

		rocket_create_entity = entity;
		rocket_create_frame = GetGameTickCount();

		dhook_CTFBaseRocket_GetRadius.HookEntity(Hook_Post, entity, DHookCallback_CTFBaseRocket_GetRadius);
	}

	if (
		StrEqual(class, "tf_weapon_flamethrower") ||
		StrEqual(class, "tf_weapon_rocketlauncher_fireball")
	) {
		dhook_CTFWeaponBase_SecondaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_CTFWeaponBase_SecondaryAttack);
	}

	if (StrEqual(class, "tf_weapon_mechanical_arm")) {
		dhook_CTFWeaponBase_PrimaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_CTFWeaponBase_PrimaryAttack);
		dhook_CTFWeaponBase_SecondaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_CTFWeaponBase_SecondaryAttack);
	}

	if (StrEqual(class, "tf_weapon_handgun_scout_primary")) {
		dhook_CTFWeaponBase_SecondaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_CTFWeaponBase_SecondaryAttack);
	}

	if (StrContains(class, "item_ammopack") == 0) {
		dhook_CAmmoPack_MyTouch.HookEntity(Hook_Pre, entity, DHookCallback_CAmmoPack_MyTouch);
	}

	if (StrEqual(class, "obj_dispenser")) {
		dhook_CObjectDispenser_DispenseAmmo.HookEntity(Hook_Pre, entity, DHookCallback_CObjectDispenser_DispenseAmmo);
	}

	if (StrEqual(class, "obj_sentrygun")) {
		dhook_CObjectSentrygun_OnWrenchHit.HookEntity(Hook_Pre, entity, DHookCallback_CObjectSentrygun_OnWrenchHit_Pre);
		dhook_CObjectSentrygun_OnWrenchHit.HookEntity(Hook_Post, entity, DHookCallback_CObjectSentrygun_OnWrenchHit_Post);
#if defined MEMORY_PATCHES
		dhook_CObjectSentrygun_StartBuilding.HookEntity(Hook_Post, entity, DHookCallback_CObjectSentrygun_StartBuilding);
		dhook_CObjectSentrygun_Construct.HookEntity(Hook_Pre, entity, DHookCallback_CObjectSentrygun_Construct_Pre);
		dhook_CObjectSentrygun_Construct.HookEntity(Hook_Post, entity, DHookCallback_CObjectSentrygun_Construct_Post);
#endif
	}
}

public void OnEntityDestroyed(int entity) {
	if (entity < 0 || entity >= 2048) {
		return;
	}

	entities[entity].exists = false;

	if (
		rocket_create_entity == entity &&
		rocket_create_frame == GetGameTickCount()
	) {
		// this rocket was created and destroyed on the same frame
		// this likely means a beggars overload happened

		rocket_create_entity = -1;
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	float cloak;
	int health_cur;
	int health_max;

	// this function is called on a per-frame basis
	// if two conds are added within the same game frame,
	// they will both be present when this is called for each

	{
		// bonk cancel stun

		if (
			ItemIsEnabled(Wep_Bonk) &&
			condition == TFCond_Dazed &&
			abs(GetGameTickCount() - players[client].bonk_cond_frame) <= 2 &&
			players[client].bonk_cond_frame > 0 //just in case
		) {
			TF2_RemoveCondition(client, TFCond_Dazed);
		}
	}
	{
		// if player somehow activated hype condition, remove it, unless they have a drink item

		if (
			GetItemVariant(Wep_SodaPopper) == 0 &&
			condition == TFCond_CritHype &&
			(player_weapons[client][Wep_Bonk] || player_weapons[client][Wep_CritCola]) == false
		) {
			TF2_RemoveCondition(client, TFCond_CritHype);
		}
	}
	{
		// "old-style" dead ringer stuff

		if (
			(GetItemVariant(Wep_DeadRinger) == 0 ||
			GetItemVariant(Wep_DeadRinger) == 3) &&
			TF2_GetPlayerClass(client) == TFClass_Spy
		) {
			if (
				condition == TFCond_Cloaked &&
				player_weapons[client][Wep_DeadRinger]
			) {
				cloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter");

				if (
					abs(GetGameTickCount() - players[client].feign_ready_tick) <= 2 &&
					players[client].feign_ready_tick > 0
				) {
					// undo 50% drain on activated
					SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", floatMin(cloak + 50.0, 100.0));
				}
			}

			if (
				TF2_IsPlayerInCondition(client, TFCond_Cloaked) &&
				player_weapons[client][Wep_DeadRinger]
			) {

				if (
					condition == TFCond_AfterburnImmune &&
					TF2_IsPlayerInCondition(client, TFCond_FireImmune) == false // didn't use spycicle
				) {
					// grant afterburn immunity for a bit

					// this may look like it overrides spycicle afterburn immune in some cases, but it doesn't
					// this function is not called when a condition is gained that we already had before

					TF2_RemoveCondition(client, TFCond_AfterburnImmune);
					TF2_AddCondition(client, TFCond_AfterburnImmune, 0.5, 0);
				}
			}
		}
	}
	{
		// spycicle fire immune

		if (
			ItemIsEnabled(Wep_Spycicle) &&
			TF2_GetPlayerClass(client) == TFClass_Spy &&
			condition == TFCond_FireImmune &&
			TF2_IsPlayerInCondition(client, TFCond_AfterburnImmune)
		) {
			TF2_RemoveCondition(client, TFCond_FireImmune);
			TF2_RemoveCondition(client, TFCond_AfterburnImmune);

			TF2_AddCondition(client, TFCond_FireImmune, 2.0, 0);
		}
	}
	{
		// buffalo steak sandvich minicrit on damage taken
		// steak sandvich buff effect is composed of TFCond_CritCola and TFCond_RestrictToMelee according to the released source code
		if (
			ItemIsEnabled(Wep_BuffaloSteak) &&
			(GetItemVariant(Wep_BuffaloSteak) == 1 || GetItemVariant(Wep_BuffaloSteak) == 2) &&
			TF2_GetPlayerClass(client) == TFClass_Heavy &&
			condition == TFCond_RestrictToMelee &&
			TF2_IsPlayerInCondition(client, TFCond_CritCola)
		) {
			TF2_AddCondition(client, TFCond_MarkedForDeathSilent);
		}
	}
	{
		// crit-a-cola damage taken minicrits
		if (
			(GetItemVariant(Wep_CritCola) == 3 || GetItemVariant(Wep_CritCola) == 4) &&
			TF2_GetPlayerClass(client) == TFClass_Scout &&
			condition == TFCond_CritCola &&
			player_weapons[client][Wep_CritCola] == true
		) {
			TF2_AddCondition(client, TFCond_MarkedForDeathSilent, 8.0, 0);
		}
	}
	{
		// Phlogistinator reverts (uber and knockback immunity removal handled in OnAddCond)
		if (
			ItemIsEnabled(Wep_Phlogistinator) &&
			TF2_GetPlayerClass(client) == TFClass_Pyro &&
			condition == TFCond_Taunting &&
			TF2_IsPlayerInCondition(client, TFCond_CritMmmph)
		) {
			// Instantly restore to max health on mmmph activation
			health_cur = GetClientHealth(client);
			health_max = SDKCall(sdkcall_GetMaxHealth, client);
			if (health_cur < health_max) {
				SetEntProp(client, Prop_Send, "m_iHealth", health_max);
			}

			switch (GetItemVariant(Wep_Phlogistinator)) {
				case 0, 2, 3: { // Pyromania, Release and March 15, 2012 Phlog
					TF2_AddCondition(client, TFCond_InHealRadius, 3.0, 0); // re-add healing circle visual effect
					TF2_AddCondition(client, TFCond_DefenseBuffMmmph, 3.0, 0);
					// 90% damage reduction for release and march variants handled in OnTakeDamageAlive
				}
				case 1: { // Tough Break Phlog
					// a bit of Uber left over when taunt ends for historical accuracy. i am not sure how exactly long it was, this is just a guess.
					TF2_AddCondition(client, TFCond_UberchargedCanteen, 3.5, 0);
				}
			}
		}
	}
	{
		// Track when player starts aiming (Minigun, Sniper Rifles) for use elsewhere
		if (condition == TFCond_Slowed) {
			players[client].aiming_cond_time = GetGameTime();
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	{
		// if player is under minicrits but the cond was removed (e.g. via resupply), re-add it
		if (
			GetItemVariant(Wep_SodaPopper) == 0 &&
			condition == TFCond_CritCola &&
			players[client].is_under_hype == true &&
			TF2_GetPlayerClass(client) == TFClass_Scout
		) {
			TF2_AddCondition(client, TFCond_CritCola, 11.0, 0);
		}
	}

	{
		// buffalo steak sandvich marked-for-death effect removal
		if (
			ItemIsEnabled(Wep_BuffaloSteak) &&
			(GetItemVariant(Wep_BuffaloSteak) == 1 || GetItemVariant(Wep_BuffaloSteak) == 2) &&
			TF2_GetPlayerClass(client) == TFClass_Heavy &&
			(condition == TFCond_CritCola || condition == TFCond_RestrictToMelee) &&
			TF2_IsPlayerInCondition(client, TFCond_MarkedForDeathSilent)
		) {
			TF2_RemoveCondition(client, TFCond_MarkedForDeathSilent);
		}			
	}
	{
		// crit-a-cola mark-for-death removal for pre-July2013 and release variants
		if (
			(GetItemVariant(Wep_CritCola) == 3 || GetItemVariant(Wep_CritCola) == 4) &&
			condition == TFCond_CritCola &&
			TF2_GetPlayerClass(client) == TFClass_Scout &&
			TF2_IsPlayerInCondition(client, TFCond_MarkedForDeathSilent)
		) {
			TF2_RemoveCondition(client, TFCond_MarkedForDeathSilent);
		}
	}
	{
		if (
			ItemIsEnabled(Wep_EurekaEffect) &&
			TF2_GetPlayerClass(client) == TFClass_Engineer &&
			condition == TFCond_Taunting &&
			players[client].is_eureka_teleporting == true
		) {
			players[client].is_eureka_teleporting = false;

			if (
				players[client].eureka_teleport_target == EUREKA_TELEPORT_HOME ||
				players[client].eureka_teleport_target == EUREKA_TELEPORT_TELEPORTER_EXIT &&
				FindBuiltTeleporterExitOwnedByClient(client) == -1
			) {
				// Refill player health and ammo
				TF2_RegeneratePlayer(client);
			}
		}
	}
#if !defined MEMORY_PATCHES
	{
		// Temporary attribute removal on minigun spin-down
		if (
			TF2_GetPlayerClass(client) == TFClass_Heavy &&
			condition == TFCond_Slowed
		) {
			int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

			if (weapon > 0) {
				char class[64];
				GetEntityClassname(weapon, class, sizeof(class));

				if (StrEqual(class, "tf_weapon_minigun")) {
					if (ItemIsEnabled(Feat_Minigun)) {
						// patchless minigun rampup revert
						TF2Attrib_RemoveByDefIndex(weapon, 36);
						TF2Attrib_RemoveByDefIndex(weapon, 476);
					}

				}
			}
		}
	}
#endif
}

public Action TF2_OnAddCond(int client, TFCond &condition, float &time, int &provider) {
	{
		// "old-style" dead ringer stuff
		if (
			(GetItemVariant(Wep_DeadRinger) == 0 ||
			GetItemVariant(Wep_DeadRinger) == 3) &&
			TF2_GetPlayerClass(client) == TFClass_Spy
		) {
			// prevent speed boost being applied on feign death
			if (
				condition == TFCond_SpeedBuffAlly &&
				players[client].feign_ready_tick == GetGameTickCount()
			) {
				return Plugin_Handled;
			}
			// prevent cloak flickering while under feign buffs
			if (
				condition == TFCond_CloakFlicker &&
				players[client].spy_is_feigning &&
				players[client].spy_under_feign_buffs
			) {
				return Plugin_Handled;
			}
		}
	}
	{
		// save charge tick (for preventing debuff removal)
		if (condition == TFCond_Charging) {
			players[client].charge_tick = GetGameTickCount();
			return Plugin_Continue;
		}
	}
	{
		// crit-a-cola release variant duration modification
		// crit-a-cola normally applies 9 seconds, then relies on the energy drink meter to have it be 8 seconds
		if (
			GetItemVariant(Wep_CritCola) == 4 &&
			condition == TFCond_CritCola &&
			time == 9.0 &&
			TF2_GetPlayerClass(client) == TFClass_Scout
		) {
			time = 6.0;
			return Plugin_Changed;
		}
	}
	{
		// prevent Phlog uber and knockback immunity for Release, Pyromania, and March 2012 variants
		// also prevents removal of debuffs when taunting (e.g. jarate gets removed because of the uber effect)
		if (
			ItemIsEnabled(Wep_Phlogistinator) && GetItemVariant(Wep_Phlogistinator) != 1 &&
			TF2_GetPlayerClass(client) == TFClass_Pyro
		) {
			// Prevent Uber effect (should also prevent debuff removal)
			if (condition == TFCond_UberchargedCanteen) {
				return Plugin_Handled;	
			}
			// Prevent knockback immunity (this removes the healing circle visual effect! visual effect must be readded via addcond 20)
			if (condition == TFCond_MegaHeal) {
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action TF2_OnRemoveCond(int client, TFCond &condition, float &timeleft, int &provider) {
	{
		// prevent debuff removal for shields
		if (
			((ItemIsEnabled(Wep_CharginTarge) && player_weapons[client][Wep_CharginTarge]) ||
			 (ItemIsEnabled(Wep_SplendidScreen) && player_weapons[client][Wep_SplendidScreen]) ||
			 (ItemIsEnabled(Wep_TideTurner) && player_weapons[client][Wep_TideTurner])) &&
			players[client].charge_tick == GetGameTickCount()
		) {
			for (int i = 0; i < sizeof(debuffs); ++i)
			{
				if (condition == debuffs[i])
					return Plugin_Handled;
			}
		}
	}
	{
		// pre-inferno crit-a-cola mark-for-death on expire
		if (
			GetItemVariant(Wep_CritCola) == 1 &&
			TF2_GetPlayerClass(client) == TFClass_Scout &&
			condition == TFCond_CritCola &&
			GetEntPropFloat(client, Prop_Send, "m_flEnergyDrinkMeter") <= 0.0
		) {
			TF2_AddCondition(client, TFCond_MarkedForDeathSilent, 2.0, 0);
		}
	}
	return Plugin_Continue;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] class, int index, Handle& itemTarget) {
	Handle itemNew = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
	bool sword_reverted = false;

	switch (index) {
		case 61, 1006: { if (ItemIsEnabled(Wep_Ambassador)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 868, 0.0); // crit dmg falloff
		}}
		case 450: { if (ItemIsEnabled(Wep_Atomizer)) {
			switch (GetItemVariant(Wep_Atomizer)) {
				case 1: { // Pre-Blue Moon
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 250, 0.0); // air dash count
				}
				default: { // Pre-Jungle Inferno
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 5, 1.30); // fire rate penalty
					TF2Items_SetAttribute(itemNew, 1, 138, 0.80); // dmg penalty vs players
					TF2Items_SetAttribute(itemNew, 2, 250, 0.0); // air dash count
					TF2Items_SetAttribute(itemNew, 3, 773, 1.0); // single wep deploy time increased
				}
			}
		}}
		case 38, 457, 1000: { if (ItemIsEnabled(Wep_Axtinguisher)) {
			switch (GetItemVariant(Wep_Axtinguisher)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 20, 1.0); // crit vs burning players
					TF2Items_SetAttribute(itemNew, 2, 21, 0.50); // dmg penalty vs nonburning
					TF2Items_SetAttribute(itemNew, 3, 772, 1.00); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 4, 2067, 0.0); // attack minicrits and consumes burning
				}
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 21, 0.50); // dmg penalty vs nonburning
					TF2Items_SetAttribute(itemNew, 2, 638, 1.0); // axtinguisher properties
					TF2Items_SetAttribute(itemNew, 3, 772, 1.00); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 4, 2067, 0.0); // attack minicrits and consumes burning
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 5, 1.2); // fire rate penalty
					TF2Items_SetAttribute(itemNew, 1, 20, 1.0); // crit vs burning players
					TF2Items_SetAttribute(itemNew, 2, 772, 1.00); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 3, 773, 1.75); // single wep deploy time increased
					TF2Items_SetAttribute(itemNew, 4, 2067, 0.0); // attack minicrits and consumes burning
				}
			}
			
		}}
		case 772: { if (ItemIsEnabled(Wep_BabyFace)) {
			switch (GetItemVariant(Wep_BabyFace)) {
				case 1: { //release
					TF2Items_SetNumAttributes(itemNew, 6);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.70); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 3, 1.00); // clip size penalty
					TF2Items_SetAttribute(itemNew, 2, 54, 0.65); // move speed penalty
					TF2Items_SetAttribute(itemNew, 3, 106, 0.60); // weapon spread bonus
					TF2Items_SetAttribute(itemNew, 4, 419, 100.0); // hype resets on jump
					TF2Items_SetAttribute(itemNew, 5, 733, 0.0); // lose hype on take damage
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 419, 25.0); // hype resets on jump
					TF2Items_SetAttribute(itemNew, 1, 733, 0.0); // lose hype on take damage
				}
			}
		}}
		case 40, 1146: { if (ItemIsEnabled(Wep_Backburner)) {
			switch (GetItemVariant(Wep_Backburner)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.1); // +10% damage bonus; mult_dmg
				}
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.2); // +20% damage bonus
					TF2Items_SetAttribute(itemNew, 1, 356, 1.0); // no airblast; airblast_disabled
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 26, 50.0); // +50 max health on wearer; add_maxhealth
					TF2Items_SetAttribute(itemNew, 1, 356, 1.0); // no airblast; airblast_disabled
				}
			}
		}}
		case 237: { if (ItemIsEnabled(Wep_RocketJumper)) {
			switch (GetItemVariant(Wep_RocketJumper)) {				
				case 1: { // RocketJmp_Release
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 400, 0.0); // cannot_pick_up_intelligence
				}
				case 2: { // RocketJmp_Pre2011 (December 22, 2010 version)
					TF2Items_SetNumAttributes(itemNew, 6);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 61, 2.00); // 100% fire damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 2, 65, 2.00); // 100% explosive damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 3, 67, 2.00); // 100% bullet damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 4, 207, 0.0); // remove self blast dmg; blast dmg to self increased
					TF2Items_SetAttribute(itemNew, 5, 400, 0.0); // cannot_pick_up_intelligence
				}
				case 3: { // RocketJmp_Oct2010 (October 27, 2010 version)
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 125, -100.0); // max health additive penalty
					TF2Items_SetAttribute(itemNew, 2, 207, 0.0); // remove self blast dmg; blast dmg to self increased
					TF2Items_SetAttribute(itemNew, 3, 400, 0.0); // cannot_pick_up_intelligence
				}	
			}
		}}
		case 730: { if (ItemIsEnabled(Wep_Beggars)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 100, 1.0); // blast radius decreased
		}}
		case 228, 1085: { if (ItemIsEnabled(Wep_BlackBox)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 741, 0.0); // falloff-based heal
			// heal per hit handled elsewhere
		}}
		case 405, 608: { if (ItemIsEnabled(Wep_Booties)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 107, 1.10); // move speed bonus
			TF2Items_SetAttribute(itemNew, 1, 788, 1.00); // move speed bonus shield required
		}}
		case 311: { if (ItemIsEnabled(Wep_BuffaloSteak)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			// 0% damage vulnerability while under the effect on release
			// +10% damage vulnerability while under the effect for current
			// energy_buff_dmg_taken_multiplier
			TF2Items_SetAttribute(itemNew, 0, 798, GetItemVariant(Wep_BuffaloSteak) > 0 ? 1.00 : 1.10);
			// mini-crits on damage taken handled elsewhere in TF2_OnConditionAdded and TF2_OnConditionRemoved
		}}
		case 232: { if (ItemIsEnabled(Wep_Bushwacka)) {
			switch (GetItemVariant(Wep_Bushwacka)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 61, 1.20); // 20% fire damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 1, 128, 0.0); // When weapon is active:
					TF2Items_SetAttribute(itemNew, 2, 412, 1.00); // 0% damage vulnerability on wearer
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // random crits enabled
					TF2Items_SetAttribute(itemNew, 1, 61, 1.20); // 20% fire damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 2, 128, 0.0); // When weapon is active:
					TF2Items_SetAttribute(itemNew, 3, 412, 1.00); // 0% damage vulnerability on wearer
				}
			}
		}}
		case 307: { if (ItemIsEnabled(Wep_Caber)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.00); // fire rate penalty
			TF2Items_SetAttribute(itemNew, 1, 773, 1.00); // single wep deploy time increased
		}}
		case 996: { if (ItemIsEnabled(Wep_LooseCannon)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 103, 1.50); // projectile speed increased
		}}
		case 751: { if (ItemIsEnabled(Wep_CleanerCarbine)) {
			switch (GetItemVariant(Wep_CleanerCarbine)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 5, 1.35); // 35% slower firing speed
					TF2Items_SetAttribute(itemNew, 1, 31, 3.0); // 3 sec crits on kill
					TF2Items_SetAttribute(itemNew, 2, 779, 0.0); // minicrit on charge
					TF2Items_SetAttribute(itemNew, 3, 780, 0.0); // gain charge on hit
				}
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 5, 1.35); // 35% slower firing speed
					TF2Items_SetAttribute(itemNew, 1, 613, 8.0); // 8 sec minicrits on kill
					TF2Items_SetAttribute(itemNew, 2, 779, 0.0); // minicrit on charge
					TF2Items_SetAttribute(itemNew, 3, 780, 0.0); // gain charge on hit
				}
			}
		}}
		case 327: { if (ItemIsEnabled(Wep_Claidheamh)) {
			bool swords = ItemIsEnabled(Feat_Sword);
			TF2Items_SetNumAttributes(itemNew, swords ? 4 : 3);
			TF2Items_SetAttribute(itemNew, 0, 125, -15.0); // -15 max health on wearer
			TF2Items_SetAttribute(itemNew, 1, 128, 0.0); // When weapon is active:
			TF2Items_SetAttribute(itemNew, 2, 412, 1.00); // 0% damage vulnerability on wearer
			// sword holster code handled here
			if (swords) {
				TF2Items_SetAttribute(itemNew, 3, 781, 0.0); // is a sword
			}
			sword_reverted = true;
		}}
		case 354: { if (ItemIsEnabled(Wep_Concheror)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 57, 2.0); // +2 health regenerated per second on wearer
		}}
		case 441: { if (ItemIsEnabled(Wep_CowMangler)) {
			switch (GetItemVariant(Wep_CowMangler)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 288, 1.0); // no_crit_boost; this attribute does not work properly! you still get crits but without the crit glow
					TF2Items_SetAttribute(itemNew, 1, 335, 1.25); // mult_clipsize_upgrade; increase clip to 5 shots, attrib 4 doesn't work
					TF2Items_SetAttribute(itemNew, 2, 869, 0.0); // crits_become_minicrits
				}
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.90); // mult_dmg; -10% damage penalty
					TF2Items_SetAttribute(itemNew, 1, 96, 1.05); // mult_reload_time; 5% slower reload time
					TF2Items_SetAttribute(itemNew, 2, 288, 1.0); // no_crit_boost
					TF2Items_SetAttribute(itemNew, 3, 335, 1.25); // mult_clipsize_upgrade
					TF2Items_SetAttribute(itemNew, 4, 869, 0.0); // crits_become_minicrits
				}
				// no crit boost attribute fix handled elsewhere in SDKHookCB_OnTakeDamage
			}
		}}
		case 163: { if (ItemIsEnabled(Wep_CritCola)) {
			switch (GetItemVariant(Wep_CritCola)) {
				case 0, 1, 2: {
					TF2Items_SetNumAttributes(itemNew, 2);
					// +25% or +10% damage vulnerability while under the effect, depending on variant
					float vuln = GetItemVariant(Wep_CritCola) == 2 ? 1.25 : 1.10;
					TF2Items_SetAttribute(itemNew, 0, 798, vuln);
					TF2Items_SetAttribute(itemNew, 1, 814, 0.0); // no mark-for-death on attack
				}
				case 3, 4: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 814, 0.0); // no mark-for-death on attack
					// Mini-crit vulnerability handled elsewhere
				}
			}
		}}
		case 231: { if (ItemIsEnabled(Wep_Darwin)) {
			switch (GetItemVariant(Wep_Darwin)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 26, 25.0); // +25 max health on wearer
					TF2Items_SetAttribute(itemNew, 1, 60, 1.0); // +0% fire damage resistance on wearer
					TF2Items_SetAttribute(itemNew, 2, 65, 1.20); // 20% explosive damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 3, 66, 0.85); // +15% bullet damage resistance on wearer
					TF2Items_SetAttribute(itemNew, 4, 527, 0.0); // remove afterburn immunity
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 26, 25.0); // +25 max health on wearer
					TF2Items_SetAttribute(itemNew, 1, 60, 1.0); // +0% fire damage resistance on wearer
					TF2Items_SetAttribute(itemNew, 2, 527, 0.0); // remove afterburn immunity
				}
			}
		}}
		case 215: { if (ItemIsEnabled(Wep_Degreaser)) {
			TF2Items_SetNumAttributes(itemNew, 6);
			TF2Items_SetAttribute(itemNew, 0, 1, 0.90); // damage penalty
			TF2Items_SetAttribute(itemNew, 1, 72, 0.75); // weapon burn dmg reduced
			TF2Items_SetAttribute(itemNew, 2, 170, 1.00); // airblast cost increased
			TF2Items_SetAttribute(itemNew, 3, 178, 0.35); // deploy time decreased
			TF2Items_SetAttribute(itemNew, 4, 199, 1.00); // switch from wep deploy time decreased
			TF2Items_SetAttribute(itemNew, 5, 547, 1.00); // single wep deploy time decreased
		}}
		case 460: { if (ItemIsEnabled(Wep_Enforcer)) {
			switch (GetItemVariant(Wep_Enforcer)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 6);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.20); // +20% damage bonus
					TF2Items_SetAttribute(itemNew, 1, 5, 1.00); // increase back the firing rate to same as stock revolver; fire rate penalty attribute
					TF2Items_SetAttribute(itemNew, 2, 15, 1.0); // add back random crits; crit mod enabled 
					TF2Items_SetAttribute(itemNew, 3, 253, 0.5); // 0.5 sec increase in time taken to cloak
					TF2Items_SetAttribute(itemNew, 4, 410, 1.0); // remove damage bonus while disguised
					TF2Items_SetAttribute(itemNew, 5, 797, 0.0); // dmg pierces resists absorbs
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.20); // +20% damage bonus
					TF2Items_SetAttribute(itemNew, 1, 410, 1.0 / 1.2); // -16.667% damage bonus while disguised; cancels out the 20% dmg bonus to make it 0% total
					TF2Items_SetAttribute(itemNew, 2, 797, 0.0); // dmg pierces resists absorbs
				}
			}
		}}
		case 128, 775: { if (ItemIsEnabled(Wep_Pickaxe)) {
			TF2Items_SetNumAttributes(itemNew, index == 775 ? 5 : 4);
			TF2Items_SetAttribute(itemNew, 0, 115, 0.0); // mod shovel damage boost
			TF2Items_SetAttribute(itemNew, 1, 235, 2.0); // mod shovel speed boost
			TF2Items_SetAttribute(itemNew, 2, 236, 1.0); // mod weapon blocks healing
			TF2Items_SetAttribute(itemNew, 3, 740, 1.0); // reduced healing from medics
			if (index == 775)
				TF2Items_SetAttribute(itemNew, 4, 414, 0.0); // self mark for death
		}}
		case 225, 574: { if (ItemIsEnabled(Wep_EternalReward)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 34, 1.00); // mult cloak meter consume rate
			TF2Items_SetAttribute(itemNew, 1, 155, 1.00); // cannot disguise
		}}
		case 426: { if (ItemIsEnabled(Wep_Eviction)) {
			switch (GetItemVariant(Wep_Eviction)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 6, 0.50); // +50% faster firing speed
					TF2Items_SetAttribute(itemNew, 1, 851, 1.00); // +0% faster move speed on wearer
					TF2Items_SetAttribute(itemNew, 2, 855, 0.0); // mod maxhealth drain rate
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 852, 1.20); // mult_dmgtaken_active
					TF2Items_SetAttribute(itemNew, 1, 855, 0.0); // mod maxhealth drain rate
				}
			}
			// Eviction Notice stacking speedboost on hit with reverted Buffalo Steak Sandvich handled elsewhere
		}}
		case 331: { if (ItemIsEnabled(Wep_FistsSteel)) {
			switch (GetItemVariant(Wep_FistsSteel)) {
				case 0: {
				// Pre-Inferno FoS
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 853, 1.0); // mult patient overheal penalty active
					TF2Items_SetAttribute(itemNew, 1, 854, 1.0); // mult health fromhealers penalty active
				}
				case 1: {
				// Pre-Tough Break FoS
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 177, 1.2); // 20% longer weapon switch; mult_deploy_time
					TF2Items_SetAttribute(itemNew, 1, 772, 1.0); // single wep holster time increased; mult_switch_from_wep_deploy_time
					TF2Items_SetAttribute(itemNew, 2, 853, 1.0); // mult patient overheal penalty active
					TF2Items_SetAttribute(itemNew, 3, 854, 1.0); // mult health fromhealers penalty active
				}
				case 2: {
				// Release FoS
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 205, 0.4); // -60% damage from ranged sources while active; dmg_from_ranged
					TF2Items_SetAttribute(itemNew, 1, 772, 1.0); // single wep holster time increased; mult_switch_from_wep_deploy_time
					TF2Items_SetAttribute(itemNew, 2, 853, 1.0); // mult patient overheal penalty active
					TF2Items_SetAttribute(itemNew, 3, 854, 1.0); // mult health fromhealers penalty active
				}
			}
		}}
		case 416: { if (ItemIsEnabled(Wep_MarketGardener)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.0); // fire rate penalty
		}}
		case 239, 1084, 1100: { if (ItemIsEnabled(Wep_GRU)) {
			switch (GetItemVariant(Wep_GRU)) {
				case 0: {
					// Pre-Tough Break
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.75); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 414, 3.0); // self mark for death
					TF2Items_SetAttribute(itemNew, 2, 772, 1.0); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 3, 855, 0.0); // mod maxhealth drain rate
				}
				case 1: {
					// Pre-Jungle Inferno
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.75); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 414, 3.0); // self mark for death
					TF2Items_SetAttribute(itemNew, 2, 855, 0.0); // mod maxhealth drain rate
				}
				case 2: {
					// Pre-Pyromania
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.50); // -50% damage penalty
					TF2Items_SetAttribute(itemNew, 1, 191, -6.0); // -6 health drained per second on wearer while active
					TF2Items_SetAttribute(itemNew, 2, 772, 1.0); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 3, 855, 0.0); // mod maxhealth drain rate
				}
			}
		}}
		case 133: { if (ItemIsEnabled(Wep_Gunboats)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 135, 0.25); // -75% blast damage from rocket jumps
		}}
#if defined MEMORY_PATCHES
		case 142: { if (ItemIsEnabled(Wep_Gunslinger)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 464, 4.0); // Sentry build speed increased by 300%
		}}
#endif
		case 812, 833: { if (ItemIsEnabled(Wep_Cleaver)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 437, 65536.0); // crit vs stunned players
		}}
		case 329: { if (ItemIsEnabled(Wep_Jag)) {
			switch (GetItemVariant(Wep_Jag))  {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 6, 1.00); // +0% faster firing speed
					TF2Items_SetAttribute(itemNew, 1, 95, 1.00); // -0% slower repair rate
					TF2Items_SetAttribute(itemNew, 2, 775, 1.00); // -0% damage penalty vs buildings
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 775, 1.00); // -0% damage penalty vs buildings
				}
			}
		}}
		case 414: { if (ItemIsEnabled(Wep_LibertyLauncher)) {
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // damage penalty
			TF2Items_SetAttribute(itemNew, 1, 3, 0.75); // clip size penalty
			TF2Items_SetAttribute(itemNew, 2, 4, 1.00); // clip size bonus
			TF2Items_SetAttribute(itemNew, 3, 135, 1.00); // rocket jump damage reduction
		}}
		case 308: { if (ItemIsEnabled(Wep_LochLoad)) {
			switch (GetItemVariant(Wep_LochLoad)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 6);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.20); // +20% damage bonus
					TF2Items_SetAttribute(itemNew, 1, 3, 0.50); // -50% clip size
					TF2Items_SetAttribute(itemNew, 2, 100, 1.00); // -0% explosion radius
					TF2Items_SetAttribute(itemNew, 3, 137, 1.00); // +0% damage vs buildings
					TF2Items_SetAttribute(itemNew, 4, 207, 1.25); // +25% damage to self
					TF2Items_SetAttribute(itemNew, 5, 681, 0.00); // grenade no spin
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.20); // damage bonus
					TF2Items_SetAttribute(itemNew, 1, 137, 1.00); // dmg bonus vs buildings
				}
			}
		}}
#if defined MEMORY_PATCHES
		case 222, 1121: { if (ItemIsEnabled(Wep_MadMilk)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 784, 1.0); // extinguish_reduces_cooldown
		}}
#endif
		case 41: { if (GetItemVariant(Wep_Natascha) == 1) {
			// imported from NotnHeavy's pre-GM plugin
			TF2Items_SetNumAttributes(itemNew, 3);
			TF2Items_SetAttribute(itemNew, 0, 32, 0.00); // On Hit: 0% chance to slow target
			TF2Items_SetAttribute(itemNew, 1, 76, 1.50); // 50% max primary ammo on wearer
			TF2Items_SetAttribute(itemNew, 2, 738, 1.00); // 0% damage resistance when below 50% health and spun up
			// no distance falloff for natascha slowdown handled elsewhere
		}}
		case 1153: { if (ItemIsEnabled(Wep_PanicAttack)) {
			TF2Items_SetNumAttributes(itemNew, 11);
			TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // -0% damage penalty
			TF2Items_SetAttribute(itemNew, 1, 45, 1.00); // +0% bullets per shot
			TF2Items_SetAttribute(itemNew, 2, 97, 0.50); // 50% faster reload time
			TF2Items_SetAttribute(itemNew, 3, 394, 0.70); // +30% faster firing speed (hidden)
			TF2Items_SetAttribute(itemNew, 4, 424, 0.66); // -34% clip size (hidden)
			TF2Items_SetAttribute(itemNew, 5, 651, 0.50); // Fire rate increases as health decreases.
			TF2Items_SetAttribute(itemNew, 6, 708, 1.00); // Hold fire to load up to 4 shells
			TF2Items_SetAttribute(itemNew, 7, 709, 2.5); // Weapon spread increases as health decreases.
			TF2Items_SetAttribute(itemNew, 8, 710, 1.00); // Attrib_AutoFiresFullClipNegative
			TF2Items_SetAttribute(itemNew, 9, 808, 0.00); // Successive shots become less accurate
			TF2Items_SetAttribute(itemNew, 10, 809, 0.00); // Fires a wide, fixed shot pattern
		}}
		case 594: { if (ItemIsEnabled(Wep_Phlogistinator)) {
			switch (GetItemVariant(Wep_Phlogistinator)) {
			// full health on taunt, MMMPH meter reduction, and defense buff handled elsewhere
				case 0, 3: { // Pyromania and March 2012 Phlogistinator
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 1, 0.90); // -10% damage penalty
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 357, 1.30); // +30% buff duration (hidden)
				}
			}
		}}
		case 773: { if (ItemIsEnabled(Wep_PocketPistol)) {
			switch (GetItemVariant(Wep_PocketPistol)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 8);
					TF2Items_SetAttribute(itemNew, 0, 3, 1.0); // -0% clip size
					TF2Items_SetAttribute(itemNew, 1, 5, 1.25); // 25% slower firing speed
					TF2Items_SetAttribute(itemNew, 2, 6, 1.0); // +0% faster firing speed
					TF2Items_SetAttribute(itemNew, 3, 16, 0.0); // On Hit: Gain up to +0 health
					TF2Items_SetAttribute(itemNew, 4, 26, 15.0); // +15 max health on wearer
					TF2Items_SetAttribute(itemNew, 5, 61, 1.50); // 50% fire damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 6, 128, 0.0); // When weapon is active:
					TF2Items_SetAttribute(itemNew, 7, 275, 1.0); // Wearer never takes falling damage
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 16, 7.0); // On Hit: Gain up to +7 health
				}
			}
		}}
		case 588: { if (GetItemVariant(Wep_Pomson) == 1) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 283, 1.0); // energy_weapon_penetration; NOTE: turns pomson projectile into bison projectile
		}}
		case 214: { if (ItemIsEnabled(Wep_Powerjack)) {
			switch (GetItemVariant(Wep_Powerjack)) {
				case 0: {
					// Pre-Gun Mettle Powerjack (pre-2015)
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 180, 75.0); // +75 health restored on kill
				}
				case 1: {
					// Release Powerjack (2010)
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 2, 1.25); // +25% damage bonus
					TF2Items_SetAttribute(itemNew, 1, 15, 0.0); // No random critical hits
					TF2Items_SetAttribute(itemNew, 2, 107, 1.0); // +0% faster move speed on wearer
					TF2Items_SetAttribute(itemNew, 3, 180, 75.0); // +75 health restored on kill
					TF2Items_SetAttribute(itemNew, 4, 412, 1.0); // 0% damage vulnerability on wearer
				}
				case 2: {
					// Hatless Update Powerjack (2011 to 2013)
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 107, 1.0); // +0% faster move speed on wearer
					TF2Items_SetAttribute(itemNew, 1, 180, 75.0); // +75 health restored on kill
					TF2Items_SetAttribute(itemNew, 2, 206, 1.2); // +20% damage from melee sources while active
					TF2Items_SetAttribute(itemNew, 3, 412, 1.0); // 0% damage vulnerability on wearer
				}
			}
			// Overheal on kill handled elsewhere
		}}
		case 404: { if (ItemIsEnabled(Wep_Persian)) {
			bool swords = ItemIsEnabled(Feat_Sword);
			TF2Items_SetNumAttributes(itemNew, swords ? 7 : 6);
			TF2Items_SetAttribute(itemNew, 0, 77, 1.00); // -0% max primary ammo on wearer
			TF2Items_SetAttribute(itemNew, 1, 79, 1.00); // -0% max secondary ammo on wearer
			TF2Items_SetAttribute(itemNew, 2, 249, 2.00); // +100% increase in charge recharge rate
			TF2Items_SetAttribute(itemNew, 3, 258, 1.0); // Ammo collected from ammo boxes becomes health (doesn't work, using three DHooks instead)
			TF2Items_SetAttribute(itemNew, 4, 778, 0.00); // Melee hits refill 0% of your charge meter
			TF2Items_SetAttribute(itemNew, 5, 782, 0.0); // Ammo boxes collected also (don't) give Charge
			if (swords) {
				TF2Items_SetAttribute(itemNew, 6, 781, 0.0); // is a sword
			}
			sword_reverted = true;
		}}
		case 57: { if (ItemIsEnabled(Wep_Razorback)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 800, 1.0); // -0% maximum overheal on wearer
		}}
		case 411: { if (ItemIsEnabled(Wep_QuickFix)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 10, 1.25); // +25% ÜberCharge rate
		}}
		case 1150: { if (ItemIsEnabled(Wep_Quickiebomb)) {
			TF2Items_SetNumAttributes(itemNew, 4); // attributes ported from NotnHeavy's pre-Gun Mettle plugin
			TF2Items_SetAttribute(itemNew, 0, 3, 0.75); // -25% clip size
			TF2Items_SetAttribute(itemNew, 1, 727, 1.25); // Up to +25% damage based on charge
			TF2Items_SetAttribute(itemNew, 2, 669, 4.00); // Stickybombs fizzle 4 seconds after landing
			TF2Items_SetAttribute(itemNew, 3, 670, 0.50); // Max charge time decreased by 50%
		}}
		case 810, 831: { if (ItemIsEnabled(Wep_RedTapeRecorder)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 433, 0.9); // Downgrade speed; sapper_degenerates_buildings; default is 0.5 (3 seconds). release was 1.6 seconds (0.9 according to https://wiki.teamfortress.com/wiki/August_2,_2012_Patch)
		}}
		case 997: { if (ItemIsEnabled(Wep_RescueRanger)) {
			switch (GetItemVariant(Wep_RescueRanger)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 469, 130.0); // ranged pickup metal cost
					TF2Items_SetAttribute(itemNew, 1, 474, 75.0); // repair bolt healing amount
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 469, 130.0); // ranged pickup metal cost
					TF2Items_SetAttribute(itemNew, 1, 474, 50.0); // repair bolt healing amount
					TF2Items_SetAttribute(itemNew, 2, 476, 0.875); // -12.5% damage penalty (hidden, for 35 base damage)
				}
			}
		}}
		case 415: { if (ItemIsEnabled(Wep_ReserveShooter)) {
			switch (GetItemVariant(Wep_ReserveShooter)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 114, 0.0); // mod mini-crit airborne
					TF2Items_SetAttribute(itemNew, 1, 178, 0.85); // 15% faster weapon switch
					TF2Items_SetAttribute(itemNew, 2, 547, 1.0); // This weapon deploys 0% faster
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 3, 0.50); // -50% clip size
					TF2Items_SetAttribute(itemNew, 1, 114, 0.0); // mod mini-crit airborne
					TF2Items_SetAttribute(itemNew, 2, 178, 0.85); // 15% faster weapon switch
					TF2Items_SetAttribute(itemNew, 3, 547, 1.0); // This weapon deploys 0% faster
				}
			}
		}}
		case 59: { if (ItemIsEnabled(Wep_DeadRinger)) {
			switch (GetItemVariant(Wep_DeadRinger)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 35, 1.8); // mult cloak meter regen rate
					TF2Items_SetAttribute(itemNew, 1, 82, 1.6); // cloak consume rate increased
					TF2Items_SetAttribute(itemNew, 2, 83, 1.0); // cloak consume rate decreased
					TF2Items_SetAttribute(itemNew, 3, 726, 1.0); // cloak consume on feign death activate
					TF2Items_SetAttribute(itemNew, 4, 810, 0.0); // mod cloak no regen from items
				}
				case 3: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 35, 1.8); // mult cloak meter regen rate
					TF2Items_SetAttribute(itemNew, 1, 82, 1.6); // cloak consume rate increased
					TF2Items_SetAttribute(itemNew, 2, 83, 1.0); // cloak consume rate decreased
					TF2Items_SetAttribute(itemNew, 3, 726, 1.0); // cloak consume on feign death activate
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 728, 1.0); // No cloak meter from ammo boxes when invisible
					TF2Items_SetAttribute(itemNew, 1, 729, 0.65); // -35% cloak meter from ammo boxes
					TF2Items_SetAttribute(itemNew, 2, 810, 0.0); // mod cloak no regen from items
				}
			}
		}}
		case 44: { if (ItemIsEnabled(Wep_Sandman)) {
			switch (GetItemVariant(Wep_Sandman)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 125, -30.0); // -30 max health on wearer
					TF2Items_SetAttribute(itemNew, 1, 278, 1.50); // increase ball recharge time to 15s
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 278, 1.50); // increase ball recharge time to 15s
				}
			}
		}}
		case 130: { if (ItemIsEnabled(Wep_Scottish)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 6, 1.0); // fire rate bonus
			TF2Items_SetAttribute(itemNew, 1, 120, 0.4); // sticky arm time penalty
		}}
		case 528: { if (GetItemVariant(Wep_ShortCircuit) == 1) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 614, 1.0); // no metal from dispensers while active
		}}
		case 220: { if (ItemIsEnabled(Wep_Shortstop)) {
			switch (GetItemVariant(Wep_Shortstop)) {
				case 0: {
					// Pre-Manniversary Shortstop
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 241, 1.0); // reload time increased hidden
					TF2Items_SetAttribute(itemNew, 1, 534, 1.00); // airblast vulnerability multiplier hidden
					TF2Items_SetAttribute(itemNew, 2, 535, 1.00); // damage force increase hidden
				}
				case 1: {
					// Pre-Gun Mettle Shortstop
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 128, 0.0); // When weapon is active:
					TF2Items_SetAttribute(itemNew, 1, 526, 1.20); // 20% bonus healing from all sources
					TF2Items_SetAttribute(itemNew, 2, 534, 1.40); // airblast vulnerability multiplier hidden
					TF2Items_SetAttribute(itemNew, 3, 535, 1.40); // damage force increase hidden
				}
				case 2: {
					// Release Shortstop
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 182, 0.5); // On Hit: Slow target movement by 40% for 0.5s
					TF2Items_SetAttribute(itemNew, 1, 241, 1.0); // reload time increased hidden
					TF2Items_SetAttribute(itemNew, 2, 534, 1.00); // airblast vulnerability multiplier hidden
					TF2Items_SetAttribute(itemNew, 3, 535, 1.00); // damage force increase hidden
				}
			}	
		}}
		case 230: { if (ItemIsEnabled(Wep_SydneySleeper)) {
			switch (GetItemVariant(Wep_SydneySleeper)) {
				// jarate application handled elsewhere for all variants
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 175, 8.0); // jarate duration
				}
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 175, 0.0); // jarate duration
				}
				case 2: {
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 28, 1.0); // crit mod disabled; doesn't work
					TF2Items_SetAttribute(itemNew, 1, 41, 1.0); // +0% charge rate
					TF2Items_SetAttribute(itemNew, 2, 175, 0.0); // jarate duration
					TF2Items_SetAttribute(itemNew, 3, 308, 1.0); // sniper_penetrate_players_when_charged
					// temporary penetration attribute used for penetration until a way to penetrate targets when above 75% charge is found
				}
			}
		}}
		case 448: { if (ItemIsEnabled(Wep_SodaPopper)) {
			switch (GetItemVariant(Wep_SodaPopper)) {
				case 0: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 15, 0.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 793, 0.0); // hype on damage
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 793, 0.0); // hype on damage
				}
			}
		}}
		case 413: { if (ItemIsEnabled(Wep_Solemn)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.0); // fire rate penalty
		}}
		case 406: { if (ItemIsEnabled(Wep_SplendidScreen)) {
			switch (GetItemVariant(Wep_SplendidScreen)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 60, 0.75); // +25% fire damage resistance on wearer
					TF2Items_SetAttribute(itemNew, 1, 247, 1.0); // Can deal charge impact damage at any range
					TF2Items_SetAttribute(itemNew, 2, 249, 1.0); // +0% increase in charge recharge rate
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 3);
					TF2Items_SetAttribute(itemNew, 0, 64, 0.85); // +15% explosive damage resistance on wearer
					TF2Items_SetAttribute(itemNew, 1, 247, 1.0); // Can deal charge impact damage at any range
					TF2Items_SetAttribute(itemNew, 2, 249, 1.0); // +0% increase in charge recharge rate
				}
			}
		}}
		case 649: { if (ItemIsEnabled(Wep_Spycicle)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 156, 1.0); // silent killer
		}}
		case 265: { if (ItemIsEnabled(Wep_StickyJumper)) {
			switch (GetItemVariant(Wep_StickyJumper)) {
				case 0: { // StkJumper_Pre2013 (Pyromania Update version)
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 89, 0.0); // max pipebombs decreased
				}
				case 1: { // StkJumper_Pre2013_Intel (Manniversary Update version)
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 89, 0.0); // max pipebombs decreased
					TF2Items_SetAttribute(itemNew, 1, 400, 0.0); // cannot_pick_up_intelligence
				}
				case 2: { // StkJumper_Pre2011 (December 22, 2010 version)
					TF2Items_SetNumAttributes(itemNew, 7);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 61, 2.00); // 100% fire damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 2, 65, 2.00); // 100% explosive damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 3, 67, 2.00); // 100% bullet damage vulnerability on wearer
					TF2Items_SetAttribute(itemNew, 4, 89, 0.0); // max pipebombs decreased
					TF2Items_SetAttribute(itemNew, 5, 207, 0.0); // remove self blast dmg; blast dmg to self increased (only works for the weapon itself)
					TF2Items_SetAttribute(itemNew, 6, 400, 0.0); // cannot_pick_up_intelligence
				}
				case 3: { // StkJumper_ReleaseDay2 (October 28, 2010 version)
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
					TF2Items_SetAttribute(itemNew, 1, 89, 0.0); // max pipebombs decreased
					TF2Items_SetAttribute(itemNew, 2, 125, -75.0); // max health additive penalty
					TF2Items_SetAttribute(itemNew, 3, 207, 0.0); // remove self blast dmg; blast dmg to self increased
					TF2Items_SetAttribute(itemNew, 4, 400, 0.0); // cannot_pick_up_intelligence
				}																
			}
		}}
		case 131, 1144: { if (ItemIsEnabled(Wep_CharginTarge)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 64, 0.6); // dmg taken from blast reduced
			TF2Items_SetAttribute(itemNew, 1, 527, 1.0); // afterburn immunity
		}}
		case 424: { if (ItemIsEnabled(Wep_Tomislav)) {
			switch (GetItemVariant(Wep_Tomislav)) {
				case 1: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 87, 0.25); // 75% faster spin up time
					TF2Items_SetAttribute(itemNew, 1, 106, 1.0); // 0% more accurate
				}
				default: {
					TF2Items_SetNumAttributes(itemNew, 2);
					TF2Items_SetAttribute(itemNew, 0, 87, 0.60); // 40% faster spin up time
					TF2Items_SetAttribute(itemNew, 1, 106, 1.0); // 0% more accurate
				}
			}
			// Note: It is recommended for the minigun ramp-up revert to be active so that the reverted pre-Pyromania Tomislav is historically and functionally accurate!
		}}
		case 1099: { if (ItemIsEnabled(Wep_TideTurner)) {
			TF2Items_SetNumAttributes(itemNew, 3);
			TF2Items_SetAttribute(itemNew, 0, 60, 0.75); // 25% fire damage resistance on wearer
			TF2Items_SetAttribute(itemNew, 1, 64, 0.75); // 25% explosive damage resistance on wearer
			TF2Items_SetAttribute(itemNew, 2, 676, 0.0); // Taking damage while shield charging reduces remaining charging time
		}}
		case 171: { if (ItemIsEnabled(Wep_TribalmansShiv)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 1, 0.65); // -35% damage penalty
			TF2Items_SetAttribute(itemNew, 1, 149, 8.0); // On Hit: Bleed for 8 seconds
		}}
		case 173: { if (ItemIsEnabled(Wep_VitaSaw)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 188, 20.0); // preserve ubercharge (doesn't work)
			TF2Items_SetAttribute(itemNew, 1, 811, 0.0); // ubercharge preserved on spawn max
		}}
		case 310: { if (ItemIsEnabled(Wep_WarriorSpirit)) {
			TF2Items_SetNumAttributes(itemNew, 5);
			TF2Items_SetAttribute(itemNew, 0, 110, 10.0); // On Hit: Gain up to +10 health
			TF2Items_SetAttribute(itemNew, 1, 125, -20.0); // -20 max health on wearer
			TF2Items_SetAttribute(itemNew, 2, 128, 0.0); // When weapon is active:
			TF2Items_SetAttribute(itemNew, 3, 180, 0.0); // +0 health restored on kill
			TF2Items_SetAttribute(itemNew, 4, 412, 1.0); // 0% damage vulnerability on wearer
		}}
		case 357: { if (ItemIsEnabled(Wep_Zatoichi)) {
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 15, 1.0); // crit mod disabled
			TF2Items_SetAttribute(itemNew, 1, 220, 0.0); // restore health on kill
			TF2Items_SetAttribute(itemNew, 2, 226, 0.0); // honorbound
			//this version of zatoichi was not considered a sword
			//therefore, do not apply sword logic here
			TF2Items_SetAttribute(itemNew, 3, 781, 0.0); // is a sword
		}}
	}

	if (
		ItemIsEnabled(Feat_Sword) &&
		!sword_reverted && //must be set to true on every weapon that implements Feat_Sword check! 
		(StrEqual(class, "tf_weapon_sword") ||
		(!ItemIsEnabled(Wep_Zatoichi) && (index == 357)) )
	) {
		TF2Items_SetNumAttributes(itemNew, 2);
		TF2Items_SetAttribute(itemNew, 0, 781, 0.0); // is a sword
		TF2Items_SetAttribute(itemNew, 1, 264, (index == 357) ? 1.50 : 1.0); // melee range multiplier
	}

	if (TF2Items_GetNumAttributes(itemNew)) {
		itemTarget = itemNew;
		return Plugin_Changed;
	}
	delete itemNew;
	return Plugin_Continue;
}

Action OnGameEvent(Event event, const char[] name, bool dontbroadcast) {
	int client;
	int attacker;
	int weapon;
	int health_cur;
	int health_max;
	char class[64];
	float charge;
	Event event1;
	int index;

	if (StrEqual(name, "player_spawn")) {
		client = GetClientOfUserId(GetEventInt(event, "userid"));
		players[client].ticks_since_switch = 0;

		{
			// vitasaw charge apply

			if (
				ItemIsEnabled(Wep_VitaSaw) &&
				IsPlayerAlive(client) &&
				TF2_GetPlayerClass(client) == TFClass_Medic &&
				GameRules_GetRoundState() == RoundState_RoundRunning
			) {
				weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);

				if (weapon > 0) {
					GetEntityClassname(weapon, class, sizeof(class));

					if (
						StrEqual(class, "tf_weapon_bonesaw") &&
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 173
					) {
						weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));

							if (
								StrEqual(class, "tf_weapon_medigun") &&
								GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel") < 0.01 &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == players[client].medic_medigun_defidx
							) {
								charge = players[client].medic_medigun_charge;
								charge = (charge > 0.20 ? 0.20 : charge);

								SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", charge);
							}
						}
					}
				}
			}
		}
	}

	if (StrEqual(name, "player_death")) {
		client = GetClientOfUserId(GetEventInt(event, "userid"));
		attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		// Just to ensure that if attacker is missing for some reason, that we still check the victim.
		// Also check that wrangler revert is enabled.
		if (
			client > 0 &&
			client <= MaxClients &&
			IsClientInGame(client) && 
			ItemIsEnabled(Wep_Wrangler)
		) {
			// 1 second sentry disable if wrangler shield active && engineer dies.
			// should not effect the normal 3 second disable on engineer weapon switch etc.
			if (TF2_GetPlayerClass(client) == TFClass_Engineer) {

				int sentry = FindSentryGunOwnedByClient(client);
				if (sentry != -1) {
					int isControlled = GetEntProp(sentry, Prop_Send, "m_bPlayerControlled");
					if (isControlled > 0) {
						Address sentryBaseAddr = GetEntityAddress(sentry); // Get base address of sentry.

						// Offset to m_flShieldFadeTime and input our own value.
#if !defined WIN32
						// Offset for Linux (0xB50)
						StoreToAddress(sentryBaseAddr + view_as<Address>(0xB50), GetGameTime() + 1.0, NumberType_Int32);
#else
						// Offset for Windows (0xB38 NOTE: Ghidra will show something else in decompile, check the bytes instead!)
						StoreToAddress(sentryBaseAddr + view_as<Address>(0xB38), GetGameTime() + 1.0, NumberType_Int32);
#endif
						isControlled = 0; // Make sure isControlled is set to 0 or org source code
										  // will consider it true on next tick and m_flShieldFadeTime will become 3.0
										  // thus undoing our revert.
						SetEntProp(sentry, Prop_Send, "m_bPlayerControlled", isControlled);
					} 
				} 
			} 
		}

		if (
			client > 0 &&
			client <= MaxClients &&
			attacker > 0 &&
			attacker <= MaxClients &&
			IsClientInGame(client) &&
			IsClientInGame(attacker)
		) {

			{
				if (
					client != attacker &&
					(GetEventInt(event, "death_flags") & TF_DEATH_FEIGN_DEATH) == 0 &&
					GetEventInt(event, "inflictor_entindex") == attacker && // make sure it wasn't a "finished off" kill
					IsPlayerAlive(attacker)
				) {
					weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

					if (weapon > 0) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							ItemIsEnabled(Wep_Zatoichi) &&
							StrEqual(class, "tf_weapon_katana")
						) {
							// zatoichi heal on kill
							health_cur = GetClientHealth(attacker);
							health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

							if (health_cur < health_max) {
								SetEntProp(attacker, Prop_Send, "m_iHealth", health_max);

								event1 = CreateEvent("player_healonhit", true);

								event1.SetInt("amount", health_max);
								event1.SetInt("entindex", attacker);
								event1.SetInt("weapon_def_index", -1);

								event1.Fire();
							}
						}

						if (
							ItemIsEnabled(Wep_Powerjack) &&
							GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 214 &&
							// fix to prevent powerjack gaining hp while active from players burning to death by flamethrowers, flareguns and reflected burning arrows
							GetEventInt(event,"customkill") == TF_DMG_CUSTOM_NONE // powerjack melee kill has a customkill value of 0, thanks huutti; -mindfulprotons
						) {
							// Save kill tick for applying overheal on next tick
							players[attacker].powerjack_kill_tick = GetGameTickCount();
						}

						if (
							GetItemVariant(Wep_CleanerCarbine) == 0 &&
							TF2_GetPlayerClass(attacker) == TFClass_Sniper &&
							HasEntProp(weapon, Prop_Send, "m_flMinicritCharge") &&
							GetEventInt(event,"customkill") == TF_DMG_CUSTOM_NONE
						) {
							// release cleaner's carbine use crikey meter to indicate remaining buff duration
							// this is purely a custom visual thing
							SetEntPropFloat(weapon, Prop_Send, "m_flMinicritCharge", 99.5);
						}
					}
				}
			}

			{
				// ambassador headshot kill icon

				if (
					GetEventInt(event, "customkill") != TF_CUSTOM_HEADSHOT &&
					players[attacker].headshot_frame == GetGameTickCount()
				) {
					weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

					if (weapon > 0) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							ItemIsEnabled(Wep_Ambassador) &&
							StrEqual(class, "tf_weapon_revolver")
						) {
							event.SetInt("customkill", TF_CUSTOM_HEADSHOT);

							return Plugin_Changed;
						}
					}
				}
			}
		}
	}

	if (StrEqual(name, "post_inventory_application")) {
		client = GetClientOfUserId(GetEventInt(event, "userid"));

		// keep track of resupply time
		players[client].resupply_time = GetGameTime();

		// apply pre-toughbreak weapon switch if cvar is enabled
		if (cvar_pre_toughbreak_switch.BoolValue)
			TF2Attrib_SetByDefIndex(client, 177, 1.34); // 34% longer weapon switch
		else
			TF2Attrib_RemoveByDefIndex(client, 177);

		bool should_display_info_msg = false;

		//cache players weapons for later funcs
		{

			for (int i = 0; i < NUM_ITEMS; i++) {
				prev_player_weapons[client][i] = player_weapons[client][i];
				player_weapons[client][i] = false;
			}

			int length = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
			for (int i;i < length; i++)
			{
				weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons",i);
				if (weapon != -1)
				{
					GetEntityClassname(weapon, class, sizeof(class));
					index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

					if (
						(index != 594) &&
						(StrEqual(class, "tf_weapon_flamethrower") ||
						StrEqual(class, "tf_weapon_rocketlauncher_fireball"))
					) {
						player_weapons[client][Feat_Airblast] = true;
					}

#if defined MEMORY_PATCHES
					if (StrEqual(class, "tf_weapon_flamethrower")) {
						player_weapons[client][Feat_Flamethrower] = true;
					}

					else if (StrContains(class, "tf_weapon_sniperrifle") == 0) {
						player_weapons[client][Feat_SniperRifle] = true;
					}
#endif

					if (StrEqual(class, "tf_weapon_minigun")) {
						player_weapons[client][Feat_Minigun] = true;
					}

					else if (StrEqual(class, "tf_weapon_grenadelauncher")) {
						player_weapons[client][Feat_Grenade] = true;

						if (ItemIsEnabled(Feat_Grenade)) {
							TF2Attrib_SetByDefIndex(weapon, 99, 1.089); // +8.9% explosion radius
							// Old radius: 159 Hu, Modern radius: 146 Hu. 159/146 = 1.089
						}
					}

					else if (StrEqual(class, "tf_weapon_pipebomblauncher")) {
						player_weapons[client][Feat_Stickybomb] = true;

						if (ItemIsEnabled(Feat_Stickybomb)) {
							TF2Attrib_SetByDefIndex(weapon, 99, 1.089); // +8.9% explosion radius
							// Old radius: 159 Hu, Modern radius: 146 Hu. 159/146 = 1.089
						}
					}

					else if (
						StrEqual(class, "tf_weapon_sword") ||
						(!ItemIsEnabled(Wep_Zatoichi) && StrEqual(class, "tf_weapon_katana"))
					) {
						player_weapons[client][Feat_Sword] = true;
					}

					switch (index) {
						case 1104: player_weapons[client][Wep_Airstrike] = true;
						case 61: player_weapons[client][Wep_Ambassador] = true;
						case 1006: player_weapons[client][Wep_Ambassador] = true;
						case 304: player_weapons[client][Wep_Amputator] = true;
						case 450: player_weapons[client][Wep_Atomizer] = true;
						case 38, 47, 1000: player_weapons[client][Wep_Axtinguisher] = true;
						case 772: player_weapons[client][Wep_BabyFace] = true;
						case 40, 1146: player_weapons[client][Wep_Backburner] = true;
						case 1101: player_weapons[client][Wep_BaseJumper] = true;
						case 237: player_weapons[client][Wep_RocketJumper] = true;
						case 730: player_weapons[client][Wep_Beggars] = true;
						case 442: player_weapons[client][Wep_Bison] = true;
						case 228, 1085: player_weapons[client][Wep_BlackBox] = true;
						case 46, 1145: player_weapons[client][Wep_Bonk] = true;
						case 312: player_weapons[client][Wep_BrassBeast] = true;
						case 311: player_weapons[client][Wep_BuffaloSteak] = true;
						case 232: player_weapons[client][Wep_Bushwacka] = true;
						case 307: player_weapons[client][Wep_Caber] = true;
#if defined MEMORY_PATCHES
						case 159, 433: player_weapons[client][Wep_Dalokohs] = true;
						case 447: player_weapons[client][Wep_Disciplinary] = true;
#endif
						case 1178: player_weapons[client][Wep_DragonFury] = true;
						case 996: player_weapons[client][Wep_LooseCannon] = true;
						case 751: player_weapons[client][Wep_CleanerCarbine] = true;
						case 327: player_weapons[client][Wep_Claidheamh] = true;
						case 354: player_weapons[client][Wep_Concheror] = true;
						case 441: player_weapons[client][Wep_CowMangler] = true;
						case 163: player_weapons[client][Wep_CritCola] = true;
						case 215: player_weapons[client][Wep_Degreaser] = true;
						case 460: player_weapons[client][Wep_Enforcer] = true;
						case 128, 775: player_weapons[client][Wep_Pickaxe] = true;
						case 225, 574: player_weapons[client][Wep_EternalReward] = true;
						case 589: player_weapons[client][Wep_EurekaEffect] = true;
						case 426: player_weapons[client][Wep_Eviction] = true;
						case 331: player_weapons[client][Wep_FistsSteel] = true;
						case 416: player_weapons[client][Wep_MarketGardener] = true;
						case 239, 1084, 1100: player_weapons[client][Wep_GRU] = true;
						case 812, 833: player_weapons[client][Wep_Cleaver] = true;
#if defined MEMORY_PATCHES
						case 142: player_weapons[client][Wep_Gunslinger] = true;
						case 1151: player_weapons[client][Wep_IronBomber] = true;
#endif
						case 329: player_weapons[client][Wep_Jag] = true;
						case 414: player_weapons[client][Wep_LibertyLauncher] = true;
						case 308: player_weapons[client][Wep_LochLoad] = true;
#if defined MEMORY_PATCHES
						case 222, 1121: player_weapons[client][Wep_MadMilk] = true;
#endif
						case 41: player_weapons[client][Wep_Natascha] = true;
						case 1153: player_weapons[client][Wep_PanicAttack] = true;
						case 594: player_weapons[client][Wep_Phlogistinator] = true;
						case 773: player_weapons[client][Wep_PocketPistol] = true;
						case 588: player_weapons[client][Wep_Pomson] = true;
						case 214: player_weapons[client][Wep_Powerjack] = true;
						case 404: player_weapons[client][Wep_Persian] = true;
						case 411: player_weapons[client][Wep_QuickFix] = true;
						case 1150: player_weapons[client][Wep_Quickiebomb] = true;
						case 810, 831: player_weapons[client][Wep_RedTapeRecorder] = true;
						case 997: player_weapons[client][Wep_RescueRanger] = true;
						case 415: player_weapons[client][Wep_ReserveShooter] = true;
						case 59: player_weapons[client][Wep_DeadRinger] = true;
						case 44: player_weapons[client][Wep_Sandman] = true;
						case 130: player_weapons[client][Wep_Scottish] = true;
						case 230: player_weapons[client][Wep_SydneySleeper] = true;
						case 448: player_weapons[client][Wep_SodaPopper] = true;
						case 413: player_weapons[client][Wep_Solemn] = true;
						case 528: player_weapons[client][Wep_ShortCircuit] = true;
						case 220: {
							player_weapons[client][Wep_Shortstop] = true;

							if (ItemIsEnabled(Wep_Shortstop)) {
								// Reverted Shortstop uses secondary ammo
								SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 2);
							}
						}
						case 649: player_weapons[client][Wep_Spycicle] = true;
						case 265: player_weapons[client][Wep_StickyJumper] = true;
						case 424: player_weapons[client][Wep_Tomislav] = true;
						case 171: player_weapons[client][Wep_TribalmansShiv] = true;
						case 173: player_weapons[client][Wep_VitaSaw] = true;
						case 310: player_weapons[client][Wep_WarriorSpirit] = true;
						case 140, 1086, 30668: player_weapons[client][Wep_Wrangler] = true;
						case 357: player_weapons[client][Wep_Zatoichi] = true;
					}
				}
			}
			for (int i = 0; i < TF2Util_GetPlayerWearableCount(client); i++)
			{
				weapon = TF2Util_GetPlayerWearable(client, i);
				index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

				switch (index) {
					case 405, 608: player_weapons[client][Wep_Booties] = true;
#if defined MEMORY_PATCHES
					case 642: player_weapons[client][Wep_CozyCamper] = true;
#endif
					case 231: player_weapons[client][Wep_Darwin] = true;
					case 57: player_weapons[client][Wep_Razorback] = true;
					case 133: player_weapons[client][Wep_Gunboats] = true;
					case 406: player_weapons[client][Wep_SplendidScreen] = true;
					case 131, 1144: player_weapons[client][Wep_CharginTarge] = true;
					case 1099: player_weapons[client][Wep_TideTurner] = true;
				}
			}
		}

		//item sets
		if (
			ItemIsEnabled(Set_SpDelivery) ||
			ItemIsEnabled(Set_GasJockey) ||
			ItemIsEnabled(Set_Expert) ||
			ItemIsEnabled(Set_Hibernate) ||
			ItemIsEnabled(Set_CrocoStyle) ||
			ItemIsEnabled(Set_Saharan)
		) {
			// reset set bonuses on loadout changes
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Scout:
				{
					TF2Attrib_RemoveByDefIndex(client, 517); // SET BONUS: max health additive bonus
				}
				case TFClass_Pyro:
				{
					TF2Attrib_RemoveByDefIndex(client, 489); // SET BONUS: move speed set bonus
					TF2Attrib_RemoveByDefIndex(client, 516); // SET BONUS: dmg taken from bullets increased 
				}
				case TFClass_DemoMan:
				{
					TF2Attrib_RemoveByDefIndex(client, 492); // SET BONUS: dmg taken from fire reduced set bonus
				}
				case TFClass_Heavy:
				{
					TF2Attrib_RemoveByDefIndex(client, 491); // SET BONUS: dmg taken from crit reduced set bonus
				}
				case TFClass_Sniper:
				{
					TF2Attrib_RemoveByDefIndex(client, 176); // SET BONUS: no death from headshots
				}
				case TFClass_Spy:
				{
					TF2Attrib_RemoveByDefIndex(client, 159); // SET BONUS: cloak blink time penalty
					TF2Attrib_RemoveByDefIndex(client, 160); // SET BONUS: quiet unstealth
				}
			}

			//handle item sets
			int wep_count = 0;
			int active_set = 0;
			int first_wep = -1;

			int length = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
			for (int i;i < length; i++)
			{
				weapon = GetEntPropEnt(client,Prop_Send,"m_hMyWeapons",i);
				if (weapon != -1)
				{
					index = GetEntProp(weapon,Prop_Send,"m_iItemDefinitionIndex");

					switch(index) {
						// Special Delivery
						case 220, 221, 222, 572, 999, 1121: {
							if(ItemIsEnabled(Set_SpDelivery)) {
								wep_count++;
								if(wep_count == 3) active_set = Set_SpDelivery;
							}
						}
						// Gas Jockey's Gear
						case 214, 215: {
							if(ItemIsEnabled(Set_GasJockey)) {
								wep_count++;
								if(wep_count == 2) active_set = Set_GasJockey;
							}
						}
						// Expert's Ordnance
						case 307, 308: {
							if(ItemIsEnabled(Set_Expert)) {
								wep_count++;
								if(wep_count == 2) active_set = Set_Expert;
							}
						}
						// Hibernating Bear
						case 310, 311, 312: {
							if(ItemIsEnabled(Set_Hibernate)) {
								wep_count++;
								if(wep_count == 3) active_set = Set_Hibernate;
							}
						}
						// Croc-o-Style Kit
						case 230, 232: {
							if(ItemIsEnabled(Set_CrocoStyle)) {
								wep_count++;
								if(wep_count == 2) active_set = Set_CrocoStyle;
							}
						}
						// Saharan Spy
						case 224, 225, 574: {
							if (
								GetItemVariant(Set_Saharan) == 0 &&
								index != 574 // exclude Wanga Prick
							) {
								if (index == 224 && first_wep == -1) {
									// reset L'Etranger cloak duration
									first_wep = weapon;
									TF2Attrib_RemoveByDefIndex(first_wep, 83);
								}
								wep_count++;
								if(wep_count == 2) active_set = Set_Saharan;
							}else if(GetItemVariant(Set_Saharan) == 1) {
								wep_count++;
								if(wep_count == 2) active_set = Set_Saharan;
							}
						}
					}
				}
			}

			if (active_set)
			{
				bool validSet = false;

				if (active_set == Set_CrocoStyle)
				{
					// This code only checks for Darwin's Danger Shield (231)
					// this code can also be used if you want cosmetics to be a part of item sets
					for (int i = 0; i < TF2Util_GetPlayerWearableCount(client); i++)
					{
						weapon = TF2Util_GetPlayerWearable(client, i);
						index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
						if (index == 231) {
							validSet = true;
							break;
						}
					}
				} else {
					validSet = true;
				}

				if (validSet)
				{
					switch (active_set)
					{
						case Set_SpDelivery:
						{
							player_weapons[client][Set_SpDelivery] = true;
							TF2Attrib_SetByDefIndex(client, 517, 25.0); // SET BONUS: max health additive bonus
						}
						case Set_GasJockey:
						{
							player_weapons[client][Set_GasJockey] = true;
							TF2Attrib_SetByDefIndex(client, 489, 1.10); // SET BONUS: move speed set bonus
							TF2Attrib_SetByDefIndex(client, 516, 1.10); // SET BONUS: dmg taken from bullets increased
						}
						case Set_Expert:
						{
							player_weapons[client][Set_Expert] = true;
							TF2Attrib_SetByDefIndex(client, 492, 0.90); // SET BONUS: dmg taken from fire reduced set bonus
						}
						case Set_Hibernate:
						{
							player_weapons[client][Set_Hibernate] = true;
							TF2Attrib_SetByDefIndex(client, 491, 0.95); // SET BONUS: dmg taken from crit reduced set bonus
						}
						case Set_CrocoStyle:
						{
							player_weapons[client][Set_CrocoStyle] = true;
							TF2Attrib_SetByDefIndex(client, 176, 1.0); // SET BONUS: no death from headshots
						}
						case Set_Saharan:
						{
							player_weapons[client][Set_Saharan] = true;
							TF2Attrib_SetByDefIndex(client, 159, 0.5); // SET BONUS: cloak blink time penalty
							TF2Attrib_SetByDefIndex(client, 160, 1.0); // SET BONUS: quiet unstealth
							if (GetItemVariant(Set_Saharan) == 0 && first_wep != -1)
							{
								TF2Attrib_SetByDefIndex(first_wep, 83, 1.0); // +0% cloak duration
							}
						}
					}
				}
			}
		}

		{
			// if player has a drink item, end minicrits and apply hype

			if (
				GetItemVariant(Wep_SodaPopper) == 0 &&
				players[client].is_under_hype
			) {
				if (player_weapons[client][Wep_SodaPopper]) {
					if (
						player_weapons[client][Wep_Bonk] ||
						player_weapons[client][Wep_CritCola]
					){
						players[client].is_under_hype = false;
						TF2_AddCondition(client, TFCond_CritHype, 11.0, 0);
					}
				} else {
					players[client].is_under_hype = false;
				}
			}
		}

		{
			//honestly this is kind of a silly way of doing it
			//but it works!
			for (int i = 0; i < NUM_ITEMS; i++) {
				if(prev_player_weapons[client][i] != player_weapons[client][i]) {
					should_display_info_msg = true;
					break;
				}
			}

			//help message (on loadout change)
			if(
				should_display_info_msg &&
				cvar_enable.BoolValue &&
				!g_hClientMessageCookie.GetInt(client, cvar_no_reverts_info_by_default.BoolValue ? 1 : 0) //inverted because the default is zero
			) {
				char msg[6][256];
				int count = 0;
				int variant_idx;
				for (int i = 0; i < NUM_ITEMS; i++) {
					if(
						player_weapons[client][i] &&
						ItemIsEnabled(i)
					) {
						variant_idx = GetItemVariant(i);
						if (variant_idx > -1) {
							Format(msg[count], sizeof(msg[count]), "{gold}%T {lightgreen}- %T", items[i].key, client, items_desc[i][variant_idx], client);
							count++;
						}
					}
				}
				if(count) {
					CPrintToChat(client, "{gold}%t", "REVERT_LOADOUT_CHANGE_INIT");
					for(int i = 0; i < count; i++) {
						CPrintToChat(client, "%s", msg[i]);
					}
					//one time notice about disabling the help info
					if (!players[client].received_help_notice) {
						CPrintToChat(client,"{gold}%t", "REVERT_LOADOUT_CHANGE_DISABLE_HINT");
						players[client].received_help_notice = true;
					}
				}
			}
		}
	}

	if (StrEqual(name, "item_pickup")) {
		client = GetClientOfUserId(GetEventInt(event, "userid"));

		GetEventString(event, "item", class, sizeof(class));

		if (
			StrContains(class, "ammopack_") == 0 || // normal map pickups
			StrContains(class, "tf_ammo_") == 0 // ammo dropped on death
		) {
			players[client].ammo_grab_frame = GetGameTickCount();
		}
	}

	return Plugin_Continue;
}

Action CommandListener_EurekaTeleport(int client, const char[] command, int argc) {
	if (TF2_GetPlayerClass(client) != TFClass_Engineer)
		return Plugin_Continue;

	if (
		ItemIsEnabled(Wep_EurekaEffect) &&
		client >= 1 &&
		client <= MaxClients
	) {

		if (argc == 0) {
			players[client].eureka_teleport_target = EUREKA_TELEPORT_HOME;
			return Plugin_Continue;
		}
		
		char buf[8];
		GetCmdArg(1, buf, sizeof(buf));
		int teleport_target = StringToInt(buf);

		if (teleport_target != EUREKA_TELEPORT_TELEPORTER_EXIT) {
			teleport_target = EUREKA_TELEPORT_HOME;
		}

		players[client].eureka_teleport_target = teleport_target;
	}

	return Plugin_Continue;
}

Action OnSoundNormal(
	int clients[MAXPLAYERS], int& clients_num, char sample[PLATFORM_MAX_PATH], int& entity, int& channel,
	float& volume, int& level, int& pitch, int& flags, char soundentry[PLATFORM_MAX_PATH], int& seed
) {
	int idx;

	if (StrContains(sample, "player/pl_impact_stun") == 0) {
		for (idx = 1; idx <= MaxClients; idx++) {
			if (
				ItemIsEnabled(Wep_Sandman) &&
				players[idx].projectile_touch_frame == GetGameTickCount()
			) {
				// cancel duplicate sandman stun sounds
				// we cancel the default stun and apply our own
				return Plugin_Stop;
			}

			if (
				ItemIsEnabled(Wep_Bonk) &&
				players[idx].bonk_cond_frame == GetGameTickCount()
			) {
				// cancel bonk stun sound
				return Plugin_Stop;
			}
		}
	}
	if (cvar_old_falldmg_sfx.BoolValue)
	{
		if (StrContains(sample, "pl_fallpain") != -1)
		{
			for (idx = 1; idx <= MaxClients; idx++)
			{
				if (players[idx].fall_dmg_tick == GetGameTickCount())
				{
					// play old bone crunch
					strcopy(sample, PLATFORM_MAX_PATH, "player/pl_fleshbreak.wav");
					pitch = 92;
					return Plugin_Changed;
				}
			}
		}
		else if (StrContains(sample, "PainSevere") != -1)
		{
			for (idx = 1; idx <= MaxClients; idx++)
			{
				if (players[idx].fall_dmg_tick == GetGameTickCount())
				{
					// cancel hurt sound by fall dmg
					return Plugin_Stop;
				}
			}
		}
	}

	// override shield bash sound for targe and turner at short range
	if (StrContains(sample, "demo_charge_hit_flesh_range") != -1) {
		for (idx = 1; idx <= MaxClients; idx++) {
			if (
				((ItemIsEnabled(Wep_CharginTarge) && player_weapons[idx][Wep_CharginTarge]) ||
				(ItemIsEnabled(Wep_TideTurner) && player_weapons[idx][Wep_TideTurner])) &&
				TF2_IsPlayerInCondition(idx, TFCond_Charging)
			) {
				char path[64];
				float charge = GetEntPropFloat(idx, Prop_Send, "m_flChargeMeter");
				if (charge > 40.0)
				{
					Format(path, sizeof(path), "weapons/demo_charge_hit_flesh%d.wav", GetRandomInt(1, 3));
					strcopy(sample, PLATFORM_MAX_PATH, path);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

Action SDKHookCB_Spawn(int entity) {
	char class[64];
	char scene[128];
	int owner;

	GetEntityClassname(entity, class, sizeof(class));

	if (StrContains(class, "tf_projectile_") == 0) {
		entities[entity].spawn_time = GetGameTime();
	}

	if (StrEqual(class, "instanced_scripted_scene")) {

		GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scene, sizeof(scene));
		if (StrEqual(scene, "scenes/player/engineer/low/taunt_drg_melee.vcd")) {
			owner = GetEntPropEnt(entity, Prop_Data, "m_hOwner");

			if (
				owner >= 1 &&
				owner <= MaxClients
			) {
				if (ItemIsEnabled(Wep_EurekaEffect)) {
					players[owner].is_eureka_teleporting = true;
				}
			}
		}
	}

	return Plugin_Continue;
}

void SDKHookCB_SpawnPost(int entity) {
	char class[64];
	float maxs[3];
	float mins[3];
	int owner;
	int weapon;

	// for some reason this is called twice
	// on the first call m_hLauncher is empty??

	GetEntityClassname(entity, class, sizeof(class));

	{
		// bison/pomson hitboxes

		if (StrEqual(class, "tf_projectile_energy_ring")) {
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");

			if (
				owner > 0 &&
				weapon > 0
			) {
				GetEntityClassname(weapon, class, sizeof(class));

				if (
					(ItemIsEnabled(Wep_Bison) && StrEqual(class, "tf_weapon_raygun")) ||
					(ItemIsEnabled(Wep_Pomson) && StrEqual(class, "tf_weapon_drg_pomson"))
				) {
					maxs[0] = 2.0;
					maxs[1] = 2.0;
					maxs[2] = 10.0;

					mins[0] = (0.0 - maxs[0]);
					mins[1] = (0.0 - maxs[1]);
					mins[2] = (0.0 - maxs[2]);

					SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
					SetEntPropVector(entity, Prop_Send, "m_vecMins", mins);

					SetEntProp(entity, Prop_Send, "m_usSolidFlags", (GetEntProp(entity, Prop_Send, "m_usSolidFlags") | FSOLID_USE_TRIGGER_BOUNDS));
					SetEntProp(entity, Prop_Send, "m_triggerBloat", 24);
				}
			}
		}
	}
}

Action SDKHookCB_Touch(int entity, int other) {
	char class[64];
	int owner;
	int weapon;

	GetEntityClassname(entity, class, sizeof(class));

	{
		// projectile touch

		if (StrContains(class, "tf_projectile_") == 0) {
			if (
				other >= 1 &&
				other <= MaxClients
			) {
				players[other].projectile_touch_frame = GetGameTickCount();
				players[other].projectile_touch_entity = entity;
			}
		}
	}

	{
		// pomson pass thru team

		if (StrEqual(class, "tf_projectile_energy_ring")) {
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");

			if (
				other >= 1 &&
				other <= MaxClients
			) {
				

				if (
					owner > 0 &&
					weapon > 0
				) {
					// Bison and Pomson lighting up friendly Huntsman arrows
					GetEntityClassname(weapon, class, sizeof(class));

					if (
						(ItemIsEnabled(Wep_Bison) && StrEqual(class, "tf_weapon_raygun") || 
						ItemIsEnabled(Wep_Pomson) && StrEqual(class, "tf_weapon_drg_pomson")) &&
						TF2_GetClientTeam(other) == TF2_GetClientTeam(owner)
					) {
						weapon = GetEntPropEnt(other, Prop_Send, "m_hActiveWeapon");
						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));
							if (StrEqual(class, "tf_weapon_compound_bow") && weapon == GetEntPropEnt(other, Prop_Send, "m_hActiveWeapon")) 
								SetEntProp(weapon, Prop_Send, "m_bArrowAlight", true);
						}
						
						// Pomson pass through teammates, unless pre-Gun Mettle variant is used
						if (
							ItemIsEnabled(Wep_Pomson) &&
							GetItemVariant(Wep_Pomson) != 2
						) {
							return Plugin_Handled;
						}
					}
				}
			} else if (
				other > MaxClients &&
				owner > 0 &&
				weapon > 0
			) {
				GetEntityClassname(weapon, class, sizeof(class));
				
				if (
					(ItemIsEnabled(Wep_Bison) && StrEqual(class, "tf_weapon_raygun")) || 
					(ItemIsEnabled(Wep_Pomson) && StrEqual(class, "tf_weapon_drg_pomson"))
				) {
					GetEntityClassname(other, class, sizeof(class));

					// Pomson pass through teammate buildings
					if (
						(StrEqual(class, "obj_sentrygun") ||
						StrEqual(class, "obj_dispenser") ||
						StrEqual(class, "obj_teleporter")) &&
						AreEntitiesOnSameTeam(entity, other)
					) {
						return Plugin_Handled;
					}
					
					// Don't collide with projectiles
					if (StrContains(class, "tf_projectile_") == 0) {
						return Plugin_Handled;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

Action SDKHookCB_TraceAttack(
	int victim, int& attacker, int& inflictor, float& damage,
	int& damage_type, int& ammo_type, int hitbox, int hitgroup
) {
	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		if (
			hitgroup == 1 &&
			(
				(damage_type & DMG_USE_HITLOCATIONS) != 0 || // for ambassador
				TF2_GetPlayerClass(attacker) == TFClass_Sniper // for sydney sleeper
			)
		) {
			players[attacker].headshot_frame = GetGameTickCount();
		}
	}

	return Plugin_Continue;
}

Action SDKHookCB_OnTakeDamage(
	int victim, int& attacker, int& inflictor, float& damage, int& damage_type,
	int& weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	int idx;
	char class[64];
	float pos1[3];
	float pos2[3];
	float stun_amt;
	float stun_dur;
	int stun_fls;
	float charge;
	float damage1;
	int health_cur;
	int health_max;
	int weapon1;

	bool resist_damage = false;
	if (weapon > 0) {
		// Don't resist if weapon pierces resists (vanilla Enforcer)
		if (TF2Attrib_HookValueInt(0, "mod_pierce_resists_absorbs", weapon) == 0) {
			resist_damage = true;
		}
	} else {
		resist_damage = true;
	}

	if (
		victim >= 1 &&
		victim <= MaxClients
	) {
		// damage from any source

		{
			// track when victim is damaged for use with conch and amputator reverts
			players[victim].damage_received_time = GetGameTime();
		}

		{
			// save fall dmg tick for overriding with old fall dmg sound
			if (damage_type & DMG_FALL) players[victim].fall_dmg_tick = GetGameTickCount();
		}

		{
			// dead ringer cvars set

			if (TF2_GetPlayerClass(victim) == TFClass_Spy) {
				weapon1 = GetPlayerWeaponSlot(victim, TFWeaponSlot_Building);

				if (weapon1 > 0) {
					GetEntityClassname(weapon1, class, sizeof(class));

					if (
						StrEqual(class, "tf_weapon_invis") &&
						GetEntProp(weapon1, Prop_Send, "m_iItemDefinitionIndex") == 59
					) {
						switch (GetItemVariant(Wep_DeadRinger)) {
							case 0, 3: {
								// "Old-Style" Dead Ringer Stats
								cvar_ref_tf_feign_death_duration.FloatValue = 0.0;
								cvar_ref_tf_feign_death_speed_duration.FloatValue = 0.0;
								cvar_ref_tf_feign_death_activate_damage_scale.FloatValue = 0.10;
								cvar_ref_tf_feign_death_damage_scale.FloatValue = 0.10;
							}
							case 2: {
								// Pre-Tough Break Dead Ringer Initial Damage Resist Stat
								cvar_ref_tf_feign_death_duration.RestoreDefault();
								cvar_ref_tf_feign_death_speed_duration.RestoreDefault();
								cvar_ref_tf_feign_death_activate_damage_scale.FloatValue = 0.50;
								cvar_ref_tf_feign_death_damage_scale.RestoreDefault();
							}
							case -1, 1: {
								// Pre-Inferno and Vanilla Dead Ringer Stat reset
								cvar_ref_tf_feign_death_duration.RestoreDefault();
								cvar_ref_tf_feign_death_speed_duration.RestoreDefault();
								cvar_ref_tf_feign_death_activate_damage_scale.RestoreDefault();
								cvar_ref_tf_feign_death_damage_scale.RestoreDefault();
							}
						}
					}
				}

				// "old-style" dead ringer track when feign begins
				if (
					GetItemVariant(Wep_DeadRinger) == 0 ||
					GetItemVariant(Wep_DeadRinger) == 3
				) {
					if (
						GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") &&
						players[victim].spy_is_feigning == false
					) {
						players[victim].feign_ready_tick = GetGameTickCount();
					}
				}
			}
		}

		{
			// turner charge loss on damage taken

			if (
				ItemIsEnabled(Wep_TideTurner) &&
				victim != attacker &&
				(damage_type & DMG_FALL) == 0 &&
				TF2_GetPlayerClass(victim) == TFClass_DemoMan &&
				TF2_IsPlayerInCondition(victim, TFCond_Charging)
			) {
				for (idx = (MaxClients + 1); idx < 2048; idx++) {
					if (
						entities[idx].exists &&
						entities[idx].is_demo_shield &&
						IsValidEntity(idx)
					) {
						GetEntityClassname(idx, class, sizeof(class));

						if (
							StrEqual(class, "tf_wearable_demoshield") &&
							GetEntPropEnt(idx, Prop_Send, "m_hOwnerEntity") == victim &&
							GetEntProp(idx, Prop_Send, "m_iItemDefinitionIndex") == 1099
						) {
							charge = GetEntPropFloat(victim, Prop_Send, "m_flChargeMeter");

							charge = (charge - damage);
							charge = (charge < 0.0 ? 0.0 : charge);

							SetEntPropFloat(victim, Prop_Send, "m_flChargeMeter", charge);

							break;
						}
					}
				}
			}
		}

		{
			// wrangler variant no falloff
			if (
				GetItemVariant(Wep_Wrangler) == 1 &&
				damage_custom == TF_DMG_CUSTOM_PLAYER_SENTRY &&
				damage_type & DMG_USEDISTANCEMOD != 0
			) {
				// calculate rampup based on Engineer's position
				damage_type ^= DMG_USEDISTANCEMOD;
				damage1 = damage;

				GetClientEyePosition(attacker, pos1);

				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

				pos2[2] += PLAYER_CENTER_HEIGHT;

				damage *= 1.0 + 0.20 * (1.0 - GetVectorDistance(pos1, pos2) / 1024.00); // apply 20% rampup

				if (damage < damage1) // no falloff
					damage = damage1;

				return Plugin_Changed;
			}
		}

		{
			// spunup resistance regardless of health

			if (
				TF2_GetPlayerClass(victim) == TFClass_Heavy &&
				TF2_IsPlayerInCondition(victim, TFCond_Slowed) &&
				resist_damage
			) {
				weapon1 = GetPlayerWeaponSlot(victim, TFWeaponSlot_Primary);

				if (weapon1 > 0) {
					GetEntityClassname(weapon1, class, sizeof(class));

					if (StrEqual(class, "tf_weapon_minigun")) {

						if (
							ItemIsEnabled(Wep_BrassBeast) &&
							GetEntProp(weapon1, Prop_Send, "m_iItemDefinitionIndex") == 312 ||
							GetItemVariant(Wep_Natascha) == 0 &&
							GetEntProp(weapon1, Prop_Send, "m_iItemDefinitionIndex") == 41
						) {
							float spunup_resist = TF2Attrib_HookValueFloat(1.0, "spunup_damage_resistance", weapon1);
							if (
								spunup_resist > 0.0 &&
								spunup_resist != 1.0
							) {
								// play damage resist sound
								EmitGameSoundToAll("Player.ResistanceLight", victim);

								// increase crit vuln here for proper resist on crits and minicrits
								// (multiplicative inverse of spunup resist value)
								TF2Attrib_SetByDefIndex(weapon1, 63, 1.0 / spunup_resist); // mult_dmgtaken_from_crit
								TF2Attrib_SetByDefIndex(weapon1, 852, spunup_resist); // mult_dmgtaken_active
								TF2Attrib_SetByDefIndex(weapon1, 738, 1.0); // spunup_damage_resistance
							}
						}
					}
				}
			}
		}
	}

	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		// damage from players only

		if (weapon > MaxClients) {
			GetEntityClassname(weapon, class, sizeof(class));

			{
				// caber damage

				if (
					ItemIsEnabled(Wep_Caber) &&
					StrEqual(class, "tf_weapon_stickbomb")
				) {
					if (
						damage_custom == TF_DMG_CUSTOM_NONE &&
						damage == 55.0
					) {
						// melee damage is always 35
						damage = 35.0;
						return Plugin_Changed;
					}

					if (damage_custom == TF_DMG_CUSTOM_STICKBOMB_EXPLOSION) {
						// base explosion is 100 damage
						damage = 100.0;

						if (
							victim != attacker &&
							(damage_type & DMG_CRIT) == 0
						) {
							GetClientEyePosition(attacker, pos1);

							GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

							pos2[2] += PLAYER_CENTER_HEIGHT;

							// ghetto ramp up calculation
							// current tf2 applies 10% ramp up, we apply ~37% extra here (old was 50%)
							damage = (damage * (1.0 + (0.37 * (1.0 - (GetVectorDistance(pos1, pos2) / 512.0)))));
						}

						return Plugin_Changed;
					}
				}
			}

			{
				// cannon impact damage

				if (
					ItemIsEnabled(Wep_LooseCannon) &&
					StrEqual(class, "tf_weapon_cannon")
				) {
					if (
						damage_custom == TF_DMG_CUSTOM_CANNONBALL_PUSH &&
						damage > 20.0 &&
						damage < 51.0
					) {
						damage = 60.0;
						return Plugin_Changed;
					}
				}
			}

			{
				// grenade damage variance on hit location
				
				if (
					ItemIsEnabled(Feat_Grenade) &&
					StrEqual(class, "tf_weapon_grenadelauncher")
				) {
					// Vary damage by up to 10%, with most damage at the player's feet and least at the head
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos1);
					damage *= ValveRemapVal(FloatAbs(pos1[2] - damage_position[2]), 0.0, 2.0 * PLAYER_CENTER_HEIGHT, 1.1, 0.9);
					return Plugin_Changed;
				}
			}

			{
				// ambassador headshot crits

				if (
					ItemIsEnabled(Wep_Ambassador) &&
					StrEqual(class, "tf_weapon_revolver") &&
					players[attacker].headshot_frame == GetGameTickCount() &&
					(
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 61 ||
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 1006
					)
				) {
					damage_type = (damage_type | DMG_CRIT);
					return Plugin_Changed;
				}
			}

			{
				// equalizer damage bonus

				if (
					ItemIsEnabled(Wep_Pickaxe) &&
					damage_custom == TF_DMG_CUSTOM_PICKAXE &&
					StrEqual(class, "tf_weapon_shovel") &&
					(
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 128 ||
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 775
					)
				) {
					health_cur = GetClientHealth(attacker);
					health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

					float multiplier = 1.0;

					switch (GetItemVariant(Wep_Pickaxe))
					{
						case 0: multiplier = 1.65; // Pre-Pyromania Equalizer (pre-June 27, 2012); 107 dmg at 1 HP
						case 1: multiplier = 1.75; // Pre-Hatless Update Equalizer (pre-April 14, 2011); 113 dmg at 1 HP
						case 2: multiplier = 2.50; // Release Equalizer (pre-April 15, 2010); 162 dmg at 1 HP
					}

					damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), multiplier, 0.5));

					return Plugin_Changed;
				}
			}

			{
				// reserve airborne minicrits

				if (
					ItemIsEnabled(Wep_ReserveShooter) &&
					StrContains(class, "tf_weapon_shotgun") == 0 &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 415
				) {
					if (
						(GetEntityFlags(victim) & FL_ONGROUND) == 0 &&
						GetEntProp(victim, Prop_Data, "m_nWaterLevel") == 0 &&
						TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeathSilent) == false
					) {
						if (
							(GetItemVariant(Wep_ReserveShooter) == 0 &&
							(players[attacker].ticks_since_switch < 66 * 5)) ||
							(GetItemVariant(Wep_ReserveShooter) == 1 &&
							TF2_IsPlayerInCondition(victim, TFCond_KnockedIntoAir) == true) ||
							(GetItemVariant(Wep_ReserveShooter) == 2 &&
							(players[attacker].ticks_since_switch < 66 * 3))
						) {
							// seems to be the best way to force a minicrit
							TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
						}
					}
				}
			}

			{
				// soda popper minicrits

				if (
					GetItemVariant(Wep_SodaPopper) == 0 &&
					TF2_IsPlayerInCondition(attacker, TFCond_CritHype) == true &&
					TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeathSilent) == false
				) {
					TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
				}
			}

			{
				// pre-bluemoon atomizer airborne minicrits

				if (
					GetItemVariant(Wep_Atomizer) == 1 &&
					StrEqual(class, "tf_weapon_bat") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 450 &&
					(GetEntityFlags(attacker) & FL_ONGROUND) == 0 &&
					GetEntProp(attacker, Prop_Data, "m_nWaterLevel") == 0 &&
					TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeathSilent) == false
				) {
					TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
				}
			}

			{
				// sandman stun

				if (
					ItemIsEnabled(Wep_Sandman) &&
					damage_custom == TF_DMG_CUSTOM_BASEBALL &&
					!StrEqual(class, "tf_weapon_bat_giftwrap") //reflected wrap will stun I think, lol!
				) {
					damage = 15.0; // always deal 15 impact damage at any range

					if (players[victim].projectile_touch_frame == GetGameTickCount()) {
						players[victim].projectile_touch_frame = 0;

						TF2_RemoveCondition(victim, TFCond_Dazed);

						if (GetEntProp(victim, Prop_Data, "m_nWaterLevel") != 3) {
							// exact replica of the original stun time formula as far as I can tell (from the source leak)

							stun_amt = (GetGameTime() - entities[players[victim].projectile_touch_entity].spawn_time);

							if (stun_amt > 1.0) stun_amt = 1.0;
							if (stun_amt > 0.1) {
								stun_dur = stun_amt;
								stun_dur = (stun_dur * 6.0);

								if ((damage_type & DMG_CRIT) != 0) {
									stun_dur = (stun_dur + 2.0);
								}

								stun_fls = GetItemVariant(Wep_Sandman) == 0 ? TF_STUNFLAGS_SMALLBONK : TF_STUNFLAGS_NORMALBONK;

								if (stun_amt >= 1.0) {
									// moonshot!

									stun_dur = (stun_dur + 1.0);
									stun_fls = TF_STUNFLAGS_BIGBONK;

									if (cvar_show_moonshot.BoolValue) {
										SetHudTextParams(-1.0, 0.09, 4.0, 255, 255, 255, 255, 2, 0.5, 0.01, 1.0);

										char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH];
										GetClientName(attacker, attackerName, sizeof(attackerName));
										GetClientName(victim, victimName, sizeof(victimName));

										for (idx = 1; idx <= MaxClients; idx++) {
											if (IsClientInGame(idx) && !IsFakeClient(idx) && !IsClientSourceTV(idx) && !IsClientReplay(idx) && g_hClientShowMoonshot.GetInt(idx, 1)) {
												ShowSyncHudText(idx, hudsync, "%t", "REVERT_MOONSHOT_MESSAGE", attackerName, victimName);
											}
										}
									}
								}

								TF2_StunPlayer(victim, stun_dur, 0.5, stun_fls, attacker);

								players[victim].stunball_fix_time_bonk = GetGameTime();
								players[victim].stunball_fix_time_wear = 0.0;
							}
						}
					}

					return Plugin_Changed;
				}
			}

			{
				// sleeper jarate mechanics

				if (
					ItemIsEnabled(Wep_SydneySleeper) &&
					StrEqual(class, "tf_weapon_sniperrifle") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 230
				) {
					charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");

					if (
						(GetItemVariant(Wep_SydneySleeper) == 0 &&
						charge > 0.1) ||
						(GetItemVariant(Wep_SydneySleeper) >= 1 &&
						charge > 0.1 &&
						GetGameTime() - players[attacker].aiming_cond_time >= 1.0)
					) {
						if (
							GetItemVariant(Wep_SydneySleeper) == 2 ||
							PlayerIsInvulnerable(victim) == false
						) {
							players[attacker].sleeper_piss_frame = GetGameTickCount();
							players[attacker].sleeper_piss_explode = false;

							// this should cause a jarate application
							switch (GetItemVariant(Wep_SydneySleeper)) {
								case 0: {
									players[attacker].sleeper_piss_duration = ValveRemapVal(charge, 50.0, 150.0, 2.0, 8.0);
									if (
										charge > 149.0 ||
										players[attacker].headshot_frame == GetGameTickCount()
									) {
										// this should also cause a jarate explosion
										players[attacker].sleeper_piss_explode = true;
									}

									// Remove sleeper attrib for now to prevent vanilla headshot bonuses
									// Attrib will get restored in OnTakeDamagePost
									TF2Attrib_SetByDefIndex(weapon, 175, 0.0);
								}
								case 1, 2:
									players[attacker].sleeper_piss_duration = 8.0;
							}
						}
					}

					if (
						GetItemVariant(Wep_SydneySleeper) == 2 &&
						cvar_ref_tf_weapon_criticals.BoolValue
					) {
						// workaround for enabling random crits on release sydney sleeper

						// Random crit chance
						float crit_mult = float(GetEntProp(attacker, Prop_Send, "m_iCritMult"));
						crit_mult = ValveRemapVal(crit_mult, 0.0, 255.0, 1.0, 4.0);
						float crit_threshold = 0.02 * crit_mult;
						float crit_roll = GetRandomFloat(0.0, 1.0);

						//PrintToChat(attacker, "crit_threshold: %f", crit_threshold);
						//PrintToChat(attacker, "crit_roll: %f", crit_roll);

						if (crit_roll <= crit_threshold) {
							damage_type |= DMG_CRIT;
							//PrintToChat(attacker, "Random crit! crit_roll is less than crit_threshold", 0);
							// critical hit lightning sound doesn't play, so add it back.
							EmitGameSoundToAll("Weapon_SydneySleeper.SingleCrit", attacker);
							
							return Plugin_Changed;
						}
					}
				}
			}

			{
				// zatoichi duels

				if (StrEqual(class, "tf_weapon_katana")) {
					weapon1 = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");

					if (weapon1 > 0) {
						GetEntityClassname(weapon1, class, sizeof(class));

						if (StrEqual(class, "tf_weapon_katana")) {
							if (ItemIsEnabled(Wep_Zatoichi)) {
								damage1 = (float(GetEntProp(victim, Prop_Send, "m_iHealth")) * 3.0);

								if (damage1 > damage) {
									damage = damage1;
								}

								damage_type = (damage_type | DMG_DONT_COUNT_DAMAGE_TOWARDS_CRIT_RATE);

								return Plugin_Changed;
							}
						}
					}
					return Plugin_Continue;
				}
			}

			{
				// guillotine minicrits

				if (
					ItemIsEnabled(Wep_Cleaver) &&
					damage > 20.0 && // don't count bleed damage
					StrEqual(class, "tf_weapon_cleaver")
				) {
					if (
						players[victim].projectile_touch_frame == GetGameTickCount() &&
						(GetGameTime() - entities[players[victim].projectile_touch_entity].spawn_time) >= 1.0
					) {
						TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
					}
					return Plugin_Continue;
				}
			}

			{
				// backstab detection for eternal reward fix

				if (
					damage_custom == TF_DMG_CUSTOM_BACKSTAB &&
					StrEqual(class, "tf_weapon_knife")
				) {
					players[attacker].backstab_time = GetGameTime();
				}
			}

			{
				// pre-GM Black Box heal on hit
				if (
					ItemIsEnabled(Wep_BlackBox) &&
					StrEqual(class,"tf_weapon_rocketlauncher") &&
					(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 228 ||
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 1085) &&
					attacker != victim &&
					TF2_GetClientTeam(attacker) != TF2_GetClientTeam(victim) &&
					!TF2_IsPlayerInCondition(victim, TFCond_Disguised) &&
					!TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)
				) {
					// Show that attacker got healed.
					Event event = CreateEvent("player_healonhit", true);
					event.SetInt("amount", 15);
					event.SetInt("entindex", attacker);
					event.Fire();

					// Add health.
					TF2Util_TakeHealth(attacker, 15.0);
				}
			}

			{
				// shield bash
				if (
					damage_custom == TF_DMG_CUSTOM_CHARGE_IMPACT &&
					((ItemIsEnabled(Wep_CharginTarge) && player_weapons[attacker][Wep_CharginTarge]) ||
					(ItemIsEnabled(Wep_SplendidScreen) && player_weapons[attacker][Wep_SplendidScreen]) ||
					(ItemIsEnabled(Wep_TideTurner) && player_weapons[attacker][Wep_TideTurner])) &&
					StrEqual(class, "tf_wearable_demoshield")
				) {
					// crit after shield bash if melee is active weapon
					weapon1 = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
					if (weapon1 == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
						TF2_AddCondition(attacker, TFCond_CritOnDamage, 0.5, 0);

					// if using splendid screen, bash damage at any range
					// other shields can only bash at the end of a charge
					if (player_weapons[attacker][Wep_SplendidScreen] == false)
					{
						if (GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter") > 40.0)
						{
							return Plugin_Handled;
						}
					}

					// set bash damage with base of 50 and add 10 damage per head, up to 5 heads
					// bash damage had no rampup based on charge depleted
					damage = 50.0 + 10.0 * intMin(GetEntProp(attacker, Prop_Send, "m_iDecapitations"), 5);

					// increase damage from splendid screen attribute
					damage *= TF2Attrib_HookValueFloat(1.0, "charge_impact_damage", weapon);
					
					return Plugin_Changed;
				}
			}

			{
				// Natascha stun. Stun amount/duration taken from TF2 source code. Imported from NotnHeavy's pre-GM plugin
				if (
					GetItemVariant(Wep_Natascha) == 1 &&
					StrEqual(class,"tf_weapon_minigun") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 41
				) {
					// Slow enemy on hit, unless they're being healed by a medic
					if (!TF2_IsPlayerInCondition(victim, TFCond_Healing))
						TF2_StunPlayer(victim, 0.20, 0.60, TF_STUNFLAG_SLOWDOWN, attacker);
				}
			}
        
			{
				// Cow Mangler Revert No Crit Boost Attribute Fix for all variants
				// Somehow even with the "cannot be crit boosted" attribute, 
				// the reverted Cow Mangler still does crits while crit boosted even when the crit boost glow doesn't show up.
				if (
					ItemIsEnabled(Wep_CowMangler) &&
					StrEqual(class, "tf_weapon_particle_cannon") &&
					damage_type & DMG_CRIT != 0
				) {
					damage_type ^= DMG_CRIT;
					return Plugin_Changed;
				}
			}

			if (inflictor > MaxClients) {
				GetEntityClassname(inflictor, class, sizeof(class));

				{
					// bison/pomson stuff

					if (StrEqual(class, "tf_projectile_energy_ring")) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							(ItemIsEnabled(Wep_Bison) && StrEqual(class, "tf_weapon_raygun")) ||
							(ItemIsEnabled(Wep_Pomson) && StrEqual(class, "tf_weapon_drg_pomson"))
						) {
							if (
								(players[victim].bison_hit_frame + 0) == GetGameTickCount() ||
								(players[victim].bison_hit_frame + 1) == GetGameTickCount()
							) {
								// don't allow bison to hit more than once every other frame
								return Plugin_Stop;
							}

							GetEntPropVector(inflictor, Prop_Send, "m_vecOrigin", pos1);
							GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

							pos2[2] += PLAYER_CENTER_HEIGHT;

							TR_TraceRayFilter(pos1, pos2, MASK_SOLID, RayType_EndPoint, TraceFilter_ExcludePlayers);

							if (TR_DidHit()) {
								// there's a wall between the projectile and the target, cancel the hit
								return Plugin_Stop;
							}

							bool should_penetrate = TF2Attrib_HookValueInt(0, "energy_weapon_penetration", weapon) != 0;
							
							// this prevents energy projectiles from hitting the same enemy too much and killing them too quickly	
							if (should_penetrate) {
								pos1[2] = 0.0;
								pos2[2] = 0.0;

								if (GetVectorDistance(pos1, pos2) > 55.0) {
									// target is too far from the projectile, cancel the hit
									return Plugin_Stop;
								}

								players[victim].bison_hit_frame = GetGameTickCount();
							}

							// cloak/uber drain is done in OnTakeDamagePost

							// Historically accurate Pre-TB Bison/Pomson damage numbers against players ported from NotnHeavy's pre-GM plugin
							if (
								(GetItemVariant(Wep_Bison) == 1 && should_penetrate) ||
								(GetItemVariant(Wep_Pomson) == 2 && !should_penetrate)
							) {
								// Do not use internal rampup/falloff.
								if (damage_type & DMG_USEDISTANCEMOD != 0) damage_type ^= DMG_USEDISTANCEMOD;
								
								// Deal damage with 125% rampup, 75% falloff.
								float base_dmg = should_penetrate ? 16.00 : 48.00;
								damage = base_dmg * ValveRemapVal(floatMin(0.35, GetGameTime() - entities[players[victim].projectile_touch_entity].spawn_time), 0.35 / 2, 0.35, 1.25, 0.75);
							}

							// Remove bullet damage flag so it's untyped damage
							if (damage_type & DMG_BULLET != 0) damage_type ^= DMG_BULLET;
							// Enable sonic damage flag so the Fists of Steel ranged resistance works correctly
							if (damage_type & DMG_SONIC == 0) damage_type |= DMG_SONIC;
							// Restore knockback
							if (damage_type & DMG_PREVENT_PHYSICS_FORCE != 0) damage_type ^= DMG_PREVENT_PHYSICS_FORCE;

							return Plugin_Changed;
						}
					}
				}

				/*
				{
					// Release Cow Mangler 5000 old damage rampup
					// Doesn't work.

					if (StrEqual(class, "tf_projectile_energy_ball")) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							ItemIsEnabled(Wep_CowMangler) &&
							GetItemVariant(Wep_CowMangler) == 0 &&
							StrEqual(class, "tf_weapon_particle_cannon")
						) {
							GetEntPropVector(inflictor, Prop_Send, "m_vecOrigin", pos1);
							GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

							// Supposed to deal 81 base damage with 150% rampup (121 dmg), 52.8% falloff (43 dmg) against players.
							damage = 81.00 * ValveRemapVal(GetVectorDistance(pos1, pos2), 512.0, 1024.0, 1.50, 0.528);

							return Plugin_Changed;
						}

						return Plugin_Continue;
					}
				}
				*/
			}
		}
	}

	return Plugin_Continue;
}

Action SDKHookCB_OnTakeDamage_Building(
	int victim, int& attacker, int& inflictor, float& damage, int& damage_type,
	int& weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	//int idx;
	char class[64];
	int health_cur;
	int health_max;
	//float damage1;
	//int weapon1;

	if (
		attacker >= 1 && attacker <= MaxClients &&
		weapon > MaxClients
	) {
		GetEntityClassname(weapon, class, sizeof(class));

		{
			// caber damage

			if (
				ItemIsEnabled(Wep_Caber) &&
				StrEqual(class, "tf_weapon_stickbomb")
			) {
				if (
					damage_custom == TF_DMG_CUSTOM_NONE &&
					damage == 55.0
				) {
					// melee damage is always 35
					damage = 35.0;
					return Plugin_Changed;
				}

				if (damage_custom == TF_DMG_CUSTOM_STICKBOMB_EXPLOSION) {
					// base explosion is 100 damage
					damage = 100.0;
					return Plugin_Changed;
				}
			}
		}
		{
			// cannon impact damage

			if (
				ItemIsEnabled(Wep_LooseCannon) &&
				StrEqual(class, "tf_weapon_cannon") &&
				damage_custom == TF_DMG_CUSTOM_CANNONBALL_PUSH
			) {
				damage = 60.0;
				return Plugin_Changed;
			}
		}
		{
			// equalizer damage bonus

			if (
				ItemIsEnabled(Wep_Pickaxe) &&
				damage_custom == TF_DMG_CUSTOM_PICKAXE &&
				StrEqual(class, "tf_weapon_shovel") &&
				(
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 128 ||
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 775
				)
			) {
				health_cur = GetClientHealth(attacker);
				health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

				float multiplier = 1.0;

				switch (GetItemVariant(Wep_Pickaxe))
				{
					case 0: multiplier = 1.65; // Pre-Pyromania Equalizer (pre-June 27, 2012); 107 dmg at 1 HP
					case 1: multiplier = 1.75; // Pre-Hatless Update Equalizer (pre-April 14, 2011); 113 dmg at 1 HP
					case 2: multiplier = 2.50; // Release Equalizer (pre-April 15, 2010); 162 dmg at 1 HP
				}

				damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), multiplier, 0.5));

				return Plugin_Changed;
			}
		}
		/*
		{
			// Release Cow Mangler 5000 building damage
			// Commenting this because I can't figure out how to revert the old damage falloff against players

			if (
				ItemIsEnabled(Wep_CowMangler) &&
				GetItemVariant(Wep_CowMangler) == 0 &&
				StrEqual(class, "tf_weapon_particle_cannon")
			) {
				// Building base damage should be 16 dmg
				damage = 81.0;

				return Plugin_Changed;
			}
		}
		*/
	}

	return Plugin_Continue;
}

Action SDKHookCB_OnTakeDamageAlive(
	int victim, int& attacker, int& inflictor, float& damage, int& damage_type,
	int& weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	Action returnValue = Plugin_Continue;
	char class[64];

	bool resist_damage = false;
	if (weapon > 0) {
		// Don't resist if weapon pierces resists (vanilla Enforcer)
		if (TF2Attrib_HookValueInt(0, "mod_pierce_resists_absorbs", weapon) == 0) {
			resist_damage = true;
		}
	} else {
		resist_damage = true;
	}

	if (
		victim >= 1 &&
		victim <= MaxClients
	) {
		{
			// dead ringer damage modification

			if (
				players[victim].spy_is_feigning &&
				players[victim].spy_under_feign_buffs &&
				TF2_GetPlayerClass(victim) == TFClass_Spy &&
				resist_damage
			) {
				damage *= 0.125; // compensates for passive 20% resist of cloak, resulting in total resist being 90%
				returnValue = Plugin_Changed;
			}
		}
		{
			// pre-WAR! sandman victims take 75% of damage dealt

			if (
				GetItemVariant(Wep_Sandman) == 1 &&
				TF2_IsPlayerInCondition(victim, TFCond_Dazed) &&
				resist_damage
			) {
				int stun_fls = GetEntProp(victim, Prop_Send, "m_iStunFlags");
				if (
					stun_fls & TF_STUNFLAG_BONKSTUCK != 0 &&
					stun_fls & TF_STUNFLAG_NOSOUNDOREFFECT == 0
				) {
					damage *= 0.75;
					returnValue = Plugin_Changed;
				}
			}
		}
	}

	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		{
			// sleeper jarate application

			if (
				ItemIsEnabled(Wep_SydneySleeper) &&
				players[attacker].sleeper_piss_frame == GetGameTickCount()
			) {
				// condition must be added in OnTakeDamageAlive, otherwise initial shot will crit
				TF2_AddCondition(victim, TFCond_Jarated, players[attacker].sleeper_piss_duration, 0);

				if (players[attacker].sleeper_piss_explode) {
					// call into game code to cause a jarate explosion on the target
					SDKCall(
						sdkcall_JarExplode, victim, attacker, inflictor, inflictor, damage_position, GetClientTeam(attacker),
						100.0, TFCond_Jarated, players[attacker].sleeper_piss_duration, "peejar_impact", "Jar.Explode"
					);
				} else {
					ParticleShowSimple("peejar_impact_small", damage_position);
				}
			}
		}
		{
			// pre-2014 grenade random damage spread
			if (
				ItemIsEnabled(Feat_Grenade) &&
				damage_type & DMG_CRIT == 0 &&
				cvar_ref_tf_damage_disablespread.BoolValue == false
			) {
				if (weapon > MaxClients) {
					GetEntityClassname(weapon, class, sizeof(class));

					if (StrEqual(class, "tf_weapon_grenadelauncher")) {
						// values chosen to be approximately +/- 15% random variance in total
						damage *= GetRandomFloat(0.867, 1.127);
						returnValue = Plugin_Changed;
					}
				}
			}
		}
		{
			if (
				victim == attacker &&
				damage > 0 &&
				damage_type & DMG_BLAST != 0
			) {
				if (
					// Kamikaze taunt tanking for all Rocket Jumper variants
					(ItemIsEnabled(Wep_RocketJumper) &&
					player_weapons[victim][Wep_RocketJumper] &&
					damage_custom == TF_DMG_CUSTOM_TAUNTATK_GRENADE) ||
					// All self blast damage tanking for some Rocket Jumper and Sticky Jumper variants
					(GetItemVariant(Wep_RocketJumper) >= 1 &&
					player_weapons[victim][Wep_RocketJumper]) ||
					(GetItemVariant(Wep_StickyJumper) >= 2 &&
					player_weapons[victim][Wep_StickyJumper])
				) {
					players[victim].old_health = GetClientHealth(victim);
					SetEntityHealth(victim, 500);
				}
			}
		}
		{
			// 90% damage resistance revert for Release and March 2012 Phlog variants
			if (
				(GetItemVariant(Wep_Phlogistinator) == 2 || GetItemVariant(Wep_Phlogistinator) == 3) &&
				player_weapons[victim][Wep_Phlogistinator] &&
				TF2_IsPlayerInCondition(victim, TFCond_DefenseBuffMmmph) &&
				damage_custom != TF_DMG_CUSTOM_BACKSTAB && // Defense buff does not protect against backstabs according to the Wiki.
				resist_damage
			) {
				// Phlogistinator 90% damage resistance when taunting (still damaged by crits!)
				// TFCond_DefenseBuffMmmph applies 75% resistance normally, buff it here by 60% for 90% resistance
				damage *= 0.40; // will also resist taunt kills!
				returnValue = Plugin_Changed;
			}
		}
	}

	return returnValue;
}

void SDKHookCB_OnTakeDamagePost(
	int victim, int attacker, int inflictor, float damage, int damage_type,
	int weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	//int idx;
	char class[64];
	float pos1[3];
	float pos2[3];
	float charge;
	float damage1;
	int weapon1;

	if (
		victim >= 1 &&
		victim <= MaxClients
	) {
		{
			// dead ringer damage tracking

			if (
				players[victim].spy_is_feigning &&
				players[victim].spy_under_feign_buffs &&
				TF2_GetPlayerClass(victim) == TFClass_Spy
			) {
				players[victim].damage_taken_during_feign += damage;
			}
		}
		{
			// spunup resistance regardless of health

			if (TF2_GetPlayerClass(victim) == TFClass_Heavy) {
				weapon1 = GetPlayerWeaponSlot(victim, TFWeaponSlot_Primary);

				if (weapon1 > 0) {
					GetEntityClassname(weapon1, class, sizeof(class));

					if (StrEqual(class, "tf_weapon_minigun")) {

						if (
							ItemIsEnabled(Wep_BrassBeast) &&
							GetEntProp(weapon1, Prop_Send, "m_iItemDefinitionIndex") == 312 ||
							GetItemVariant(Wep_Natascha) == 0 &&
							GetEntProp(weapon1, Prop_Send, "m_iItemDefinitionIndex") == 41
						) {
							// remove temp attribs
							TF2Attrib_RemoveByDefIndex(weapon1, 63);
							TF2Attrib_RemoveByDefIndex(weapon1, 738);
							TF2Attrib_RemoveByDefIndex(weapon1, 852);
						}
					}
				}
			}
		}
	}

	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		if (
			victim == attacker &&
			damage > 0 &&
			damage_type & DMG_BLAST != 0
		) {
			if (
				(ItemIsEnabled(Wep_RocketJumper) &&
				player_weapons[victim][Wep_RocketJumper] &&
				damage_custom == TF_DMG_CUSTOM_TAUNTATK_GRENADE) ||
				(GetItemVariant(Wep_RocketJumper) >= 1 &&
				player_weapons[victim][Wep_RocketJumper]) ||
				(GetItemVariant(Wep_StickyJumper) >= 2 &&
				player_weapons[victim][Wep_StickyJumper])
			) {
				// Restore health after tanking self blast damage
				SetEntityHealth(victim, players[victim].old_health);
			}
		}

		if (
			GetItemVariant(Wep_SydneySleeper) == 0 &&
			players[attacker].sleeper_piss_frame == GetGameTickCount() &&
			weapon > 0
		) {
			if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 230) {
				// Restore sleeper attrib
				TF2Attrib_SetByDefIndex(weapon, 175, 8.0);
			}
		}

		if (inflictor > MaxClients) {
			GetEntityClassname(inflictor, class, sizeof(class));

			// pomson cloak/uber drain

			if (StrEqual(class, "tf_projectile_energy_ring")) {
				GetEntityClassname(weapon, class, sizeof(class));

				if (
					ItemIsEnabled(Wep_Pomson) &&
					StrEqual(class, "tf_weapon_drg_pomson") &&
					PlayerIsInvulnerable(victim) == false &&
					(players[attacker].drain_victim != victim ||
					GetGameTime() - players[attacker].drain_time > 0.3)
				) {
					GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", pos1);
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos2);

					damage1 = ValveRemapVal(Pow(GetVectorDistance(pos1, pos2), 2.0), Pow(512.0, 2.0), Pow(1536.0, 2.0), 1.0, 0.0);

					if (TF2_GetPlayerClass(victim) == TFClass_Medic) {
						weapon1 = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);

						if (weapon1 > 0) {
							GetEntityClassname(weapon1, class, sizeof(class));

							if (StrEqual(class, "tf_weapon_medigun")) {
								if (
									GetEntProp(weapon1, Prop_Send, "m_bChargeRelease") == 0 ||
									GetEntProp(weapon1, Prop_Send, "m_bHolstered") == 1
								) {
									damage1 = (10.0 * (1.0 - damage1));
									damage1 = float(RoundToCeil(damage1));

									charge = GetEntPropFloat(weapon1, Prop_Send, "m_flChargeLevel");

									charge = (charge - (damage1 / 100.0));
									charge = (charge < 0.0 ? 0.0 : charge);

									if (charge > 0.1) {
										// fix 0.89999999 values
										charge = (charge += 0.001);
									}

									SetEntPropFloat(weapon1, Prop_Send, "m_flChargeLevel", charge);
								}
							}
						}
					}

					if (TF2_GetPlayerClass(victim) == TFClass_Spy) {
						damage1 = (20.0 * (1.0 - damage1));
						damage1 = float(RoundToCeil(damage1));
						
						charge = GetEntPropFloat(victim, Prop_Send, "m_flCloakMeter");
						
						charge = (charge - damage1);
						charge = (charge < 0.0 ? 0.0 : charge);
						
						SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", charge);
					}

					players[attacker].drain_victim = victim;
					players[attacker].drain_time = GetGameTime();
				}
			}
		}
	}
}

void SDKHookCB_WeaponSwitchPost(int client, int weapon)
{
	players[client].ticks_since_switch = 0;
}

public Action OnPlayerRunCmd(
	int client, int& buttons, int& impulse, float vel[3], float angles[3],
	int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]
) {
	Action returnValue = Plugin_Continue;

	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
		{
			if (
				GetItemVariant(Wep_BabyFace) == 1 &&
				player_weapons[client][Wep_BabyFace]
			) {
				// Release Baby Face's Blaster boost reset on jump
				if (buttons & IN_JUMP != 0)
				{
					if (!players[client].holding_jump)
					{
						if (
							GetEntPropFloat(client, Prop_Send, "m_flHypeMeter") > 0.0 && 
							GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1 && // don't reset if swimming 
							buttons & IN_DUCK == 0 && // don't reset if crouching
							(GetEntityFlags(client) & FL_ONGROUND) != 0 // don't reset if airborne, the attribute will handle air jumps
						) {
							SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", 0.0);
							TF2Util_UpdatePlayerSpeed(client);
						}
						players[client].holding_jump = true;
					}
				}
				else
				{
					players[client].holding_jump = false;
				}
			}
		}
	}
	
	return returnValue;
}

Action Command_Menu(int client, int args) {
	if (client <= 0) {
		return Plugin_Handled;
	}

	if (cvar_enable.BoolValue) {
		Menu menu_main = new Menu(MenuHandler_Main, MenuAction_Select);
		menu_main.Pagination = MENU_NO_PAGINATION;
		menu_main.ExitButton = true;
		menu_main.SetTitle("%T", "REVERT_MENU_TITLE", client);

		char localizedClassInfo[64], localizedInfo[64], localizedInfoToggle[64];
		Format(localizedClassInfo, sizeof(localizedClassInfo), "%T", "REVERT_MENU_SHOW_CLASSINFO", client);
		Format(localizedInfo, sizeof(localizedInfo), "%T", "REVERT_MENU_SHOW_ALL", client);
		Format(localizedInfoToggle, sizeof(localizedInfoToggle), "%T", "REVERT_MENU_TOGGLE_LOADOUT_CHANGE", client);

		menu_main.AddItem("classinfo", localizedClassInfo);
		menu_main.AddItem("info", localizedInfo);
		menu_main.AddItem("infotoggle", localizedInfoToggle);

		if (cvar_show_moonshot.BoolValue) {
			char localizedMoonshotToggle[64];
			Format(localizedMoonshotToggle, sizeof(localizedMoonshotToggle), "%T", "REVERT_MENU_TOGGLE_MOONSHOT", client);
			menu_main.AddItem("moonshottoggle", localizedMoonshotToggle);
		}

		menu_main.Display(client, MENU_TIME_FOREVER);
	} else {
		ReplyToCommand(client, "[SM] %t", "REVERT_REVERTS_DISABLED");
	}

	return Plugin_Handled;
}

Action Command_Info(int client, int args) {
	if (client > 0) {
		ShowItemsDetails(client);
	}

	return Plugin_Handled;
}

Action Command_ClassInfo(int client, int args) {
	if (client > 0) {
		ShowClassReverts(client);
	}

	return Plugin_Handled;
}

Action Command_ToggleInfo(int client, int args) {
	if (client > 0) {
		ToggleLoadoutInfo(client);
	}

	return Plugin_Handled;
}

void SetConVarMaybe(ConVar cvar, const char[] value, bool maybe) {
	maybe ? cvar.SetString(value) : cvar.RestoreDefault();
}

// bool TraceFilter_ExcludeSingle(int entity, int contentsmask, any data) {
// 	return (entity != data);
// }

bool TraceFilter_ExcludePlayers(int entity, int contentsmask, any data) {
	return (entity < 1 || entity > MaxClients);
}

bool TraceFilter_CustomShortCircuit(int entity, int contentsmask, any data) {
	char class[64];

	// ignore the target projectile
	if (entity == data) {
		return false;
	}

	// ignore players
	if (entity <= MaxClients) {
		return false;
	}

	GetEntityClassname(entity, class, sizeof(class));

	// ignore buildings and other projectiles
	if (
		StrContains(class, "obj_") == 0 ||
		StrContains(class, "tf_projectile_") == 0
	) {
		return false;
	}

	// ignore respawn room visualizers
	if (StrEqual(class, "func_respawnroomvisualizer")) {
		return false;
	}

	//PrintToChatAll("Short Circuit trace hit blocked by %s", class);

	return true;
}

int GetFeignBuffsEnd(int client)
{
	int reduction_by_dmg_taken = GetItemVariant(Wep_DeadRinger) == 0 ? RoundFloat(players[client].damage_taken_during_feign * 1.1) : 0;
	return players[client].feign_ready_tick + RoundFloat(66 * 6.5) - reduction_by_dmg_taken;
}

bool PlayerIsInvulnerable(int client) {
	return (
		TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_PasstimeInterception)
	);
}

/*
TFCond critboosts[] =
{
	TFCond_Kritzkrieged,
	TFCond_HalloweenCritCandy,
	TFCond_CritCanteen,
	TFCond_CritOnFirstBlood,
	TFCond_CritOnWin,
	TFCond_CritOnFlagCapture,
	TFCond_CritOnKill,
	TFCond_CritMmmph,
	TFCond_CritOnDamage,
	TFCond_CritRuneTemp
};

bool PlayerIsCritboosted(int client) {
	for (int i = 0; i < sizeof(critboosts); ++i)
	{
		if (TF2_IsPlayerInCondition(client, critboosts[i]))
			return true;
	}

	return false;
}
*/

float ValveRemapVal(float val, float a, float b, float c, float d) {
	// https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/public/mathlib/mathlib.h#L648

	float tmp;

	if (a == b) {
		return (val >= b ? d : c);
	}

	tmp = ((val - a) / (b - a));

	if (tmp < 0.0) tmp = 0.0;
	if (tmp > 1.0) tmp = 1.0;

	return (c + ((d - c) * tmp));
}

void ParticleShowSimple(const char[] name, float position[3]) {
	int idx;
	int table;
	int strings;
	int particle;
	char tmp[64];

	table = FindStringTable("ParticleEffectNames");
	strings = GetStringTableNumStrings(table);

	particle = -1;

	for (idx = 0; idx < strings; idx++) {
		ReadStringTable(table, idx, tmp, sizeof(tmp));

		if (StrEqual(tmp, name)) {
			particle = idx;
			break;
		}
	}

	if (particle >= 0) {
		TE_Start("TFParticleEffect");
		TE_WriteFloat("m_vecOrigin[0]", position[0]);
		TE_WriteFloat("m_vecOrigin[1]", position[1]);
		TE_WriteFloat("m_vecOrigin[2]", position[2]);
		TE_WriteNum("m_iParticleSystemIndex", particle);
		TE_SendToAllInRange(position, RangeType_Visibility, 0.0);
	}
}

void ParticleShow(char[] name, float origin[3], float start[3], float angles[3]) {
	int idx;
	int table;
	int strings;
	int particle;
	char tmp[64];

	table = FindStringTable("ParticleEffectNames");
	strings = GetStringTableNumStrings(table);

	particle = -1;

	for (idx = 0; idx < strings; idx++) {
		ReadStringTable(table, idx, tmp, sizeof(tmp));

		if (StrEqual(tmp, name)) {
			particle = idx;
			break;
		}
	}

	if (particle >= 0) {
		TE_Start("TFParticleEffect");
		TE_WriteFloat("m_vecOrigin[0]", origin[0]);
		TE_WriteFloat("m_vecOrigin[1]", origin[1]);
		TE_WriteFloat("m_vecOrigin[2]", origin[2]);
		TE_WriteFloat("m_vecStart[0]", start[0]);
		TE_WriteFloat("m_vecStart[1]", start[1]);
		TE_WriteFloat("m_vecStart[2]", start[2]);
		TE_WriteVector("m_vecAngles", angles);
		TE_WriteNum("m_iParticleSystemIndex", particle);
		TE_SendToAllInRange(origin, RangeType_Visibility, 0.0);
	}
}

/**
 * Define an item used for reverts.
 * 
 * @param key				Key for item used for the cvar and as the item name key in
 * 							the translation file.
 * @param desc				Key for description of the item in the translation file.
 * @param flags				Class flags.
 * @param wep_enum			Weapon enum, this identifies a weapon.
 * @param mem_patch			This revert requires a memory patch?
 */
void ItemDefine(const char[] key, const char[] desc, int flags, int wep_enum, bool mem_patch=false) {
	strcopy(items[wep_enum].key, sizeof(items[].key), key);
	strcopy(items_desc[wep_enum][0], sizeof(items_desc[][]), desc);
	items[wep_enum].flags = flags;
	items[wep_enum].num_variants = 0;
	items[wep_enum].mem_patch = mem_patch;
}

/**
 * Define an item variant.
 * 
 * @param wep_enum		Weapon enum.
 * @param desc			Key for description of the item variant in the translation file.
 */
void ItemVariant(int wep_enum, const char[] desc) {
	int variant_idx = ++items[wep_enum].num_variants;

	if (items[wep_enum].num_variants > MAX_VARIANTS) {
		SetFailState("Tried to define more than %d variants", MAX_VARIANTS);
	}

	strcopy(items_desc[wep_enum][variant_idx], sizeof(items_desc[][]), desc);
}

void ItemFinalize() {
	int idx;
	char cvar_name[64];
	char cvar_desc[2048];

	for (idx = 0; idx < NUM_ITEMS; idx++) {
		if (items[idx].cvar != null) {
			SetFailState("Tried to initialize items more than once");
		}

		Format(cvar_name, sizeof(cvar_name), "sm_reverts__item_%s", items[idx].key);
		Format(cvar_desc, sizeof(cvar_desc), (PLUGIN_NAME ... " - Revert nerfs to %T\n\n"), items[idx].key, LANG_SERVER);
		StrCat(cvar_desc, sizeof(cvar_desc), "0: Disable\n");
		char item_desc[256];
		Format(item_desc, sizeof(item_desc), "1: %T\n", items_desc[idx][0], LANG_SERVER);
		StrCat(cvar_desc, sizeof(cvar_desc), item_desc);
		for (int i = 1; i <= items[idx].num_variants; i++) {
			Format(item_desc, sizeof(item_desc), "%d: %T\n", i + 1, items_desc[idx][i], LANG_SERVER);
			StrCat(cvar_desc, sizeof(cvar_desc), item_desc);
		}

		items[idx].cvar = CreateConVar(cvar_name, items[idx].flags & ITEMFLAG_DISABLED == 0 ? "1" : "0", cvar_desc, FCVAR_NOTIFY, true, 0.0, true, float(items[idx].num_variants + 1));
#if defined MEMORY_PATCHES
		if (items[idx].mem_patch) {
			items[idx].cvar.AddChangeHook(OnServerCvarChanged);
		}
#endif
	}
}

/**
 * Check if an item is enabled.
 * 
 * @param wep_enum		Weapon enum.
 * @return				True if an item revert is enabled on the server, false otherwise.
 */
bool ItemIsEnabled(int wep_enum) {
	return cvar_enable.BoolValue && items[wep_enum].cvar.IntValue >= 1;
}

/**
 * Get the item variant enabled on a server.
 * 
 * @param wep_enum		Weapon enum.
 * @return				The weapon variant.
 */
int GetItemVariant(int wep_enum) {
	return cvar_enable.BoolValue ? items[wep_enum].cvar.IntValue - 1 : -1;
}

int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			GetMenuItem(menu, param2, info, sizeof(info));

			if (StrEqual(info, "info")) {
				RevertInfoMenu(param1);
			}
			else if (StrEqual(info, "classinfo")) {
				ShowClassReverts(param1);
			}
			else if (StrEqual(info, "infotoggle")) {
				ToggleLoadoutInfo(param1);
			}
			else if (StrEqual(info, "moonshottoggle")) {
				ToggleMoonshotMessage(param1);
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

int MenuHandler_Info(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char info[64];
			GetMenuItem(menu, param2, info, sizeof(info));
			char msg[256];
			int variant_idx;

			for (int idx = 0; idx < NUM_ITEMS; idx++) {
				if (ItemIsEnabled(idx)) {
					if (StrEqual(info,items[idx].key)) {
						variant_idx = GetItemVariant(idx);
						if (variant_idx > -1) {
							Format(msg, sizeof(msg), "{gold}%T {lightgreen}- %T", items[idx].key, param1, items_desc[idx][variant_idx], param1);
							CPrintToChat(param1, "%s", msg);
							break;
						}
					}
				}
			}
			RevertInfoMenu(param1,menu.Selection);
		}
		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void RevertInfoMenu(int client, int selection = 0){
	if (!cvar_enable.BoolValue) return;

	Menu menu_info = new Menu(MenuHandler_Info, MenuAction_Select);
	menu_info.SetTitle("%T", "REVERT_MENU_TITLE", client);

	int count;
	char item_name[64];
	for (int idx = 0; idx < NUM_ITEMS; idx++) {
		if (ItemIsEnabled(idx)) {
			Format(item_name,sizeof(item_name),"%T",items[idx].key,client);
			menu_info.AddItem(items[idx].key,item_name);
			count++;
		}
	}

	if (count) menu_info.DisplayAt(client, selection, MENU_TIME_FOREVER);
}

void ShowItemsDetails(int client) {
	int idx;
	int count;
	char msg[NUM_ITEMS][256];
	int variant_idx;

	count = 0;

	if (cvar_enable.BoolValue) {
		for (idx = 0; idx < NUM_ITEMS; idx++) {
			if (ItemIsEnabled(idx)) {
				variant_idx = GetItemVariant(idx);
				if (variant_idx > -1) {
					Format(msg[count], sizeof(msg[]), "%T - %T", items[idx].key, client, items_desc[idx][variant_idx], client);
					count++;
				}
			}
		}
	}

	ReplyToCommand(client, "[SM] %t", "REVERT_PRINT_TO_CONSOLE_HINT");

	PrintToConsole(client, "\n");
	PrintToConsole(client, "%t", "REVERT_ENABLED_REVERTS_HINT");

	if (count > 0) {
		for (idx = 0; idx < sizeof(msg); idx++) {
			if (strlen(msg[idx]) > 0) {
				PrintToConsole(client, "  %s", msg[idx]);
			}
		}
	} else {
		PrintToConsole(client, "%t :\\", "REVERT_EMPTY_REVERTS");
	}

	PrintToConsole(client, "");
}

void ShowClassReverts(int client) {
	int idx;
	int count;
	char msg[NUM_ITEMS][256];
	int class_idx;
	TFTeam team;
	int variant_idx;

	count = 0;
	class_idx = view_as<int>(TF2_GetPlayerClass(client)) - 1;
	team = TF2_GetClientTeam(client);

	// Return if unknown class or in spectator/unassigned team
	if (
		(team == TFTeam_Unassigned) ||
		(team == TFTeam_Spectator)
	) {
		ReplyToCommand(client, "You need to be in a team to use this command");
		return;
	} else if (class_idx == -1) {
		ReplyToCommand(client, "Your class needs to be valid to use this command");
		return;
	}

	if (cvar_enable.BoolValue) {
		for (idx = 0; idx < NUM_ITEMS; idx++) {
			if (ItemIsEnabled(idx)) {
				variant_idx = GetItemVariant(idx);
				if (variant_idx > -1) {
					if (items[idx].flags & (1 << class_idx) == 0)
						continue;
					Format(msg[count], sizeof(msg[]), "{gold}%T {lightgreen}- %T", items[idx].key, client, items_desc[idx][variant_idx], client);
					count++;
				}
			}
		}
	}

	ReplyToCommand(client, "%t", "REVERT_ENABLED_CLASS_REVERTS_HINT", class_names[class_idx]);

	if (count > 0) {
		for (idx = 0; idx < sizeof(msg); idx++) {
			if (strlen(msg[idx]) > 0) {
				CReplyToCommand(client, "%s", msg[idx]);
			}
		}
	} else {
		CReplyToCommand(client, "{lightgreen}%t :\\", "REVERT_EMPTY_CLASS_REVERTS", class_names[class_idx]);
	}
}

void ToggleLoadoutInfo(int client) {
	if (AreClientCookiesCached(client))
	{
		int config_value = g_hClientMessageCookie.GetInt(client, cvar_no_reverts_info_by_default.BoolValue ? 1 : 0);
		ReplyToCommand(client, "%t", config_value ? "REVERT_LOADOUT_CHANGE_ENABLED" : "REVERT_LOADOUT_CHANGE_DISABLED");
		g_hClientMessageCookie.SetInt(client, config_value ? 0 : 1);
	}
}

void ToggleMoonshotMessage(int client) {
	if (AreClientCookiesCached(client)) {
		int configValue = g_hClientShowMoonshot.GetInt(client, 1);
		ReplyToCommand(client, "%t", configValue ? "REVERT_MOONSHOT_DISABLED" : "REVERT_MOONSHOT_ENABLED");
		g_hClientShowMoonshot.SetInt(client, configValue ? 0 : 1);
	}
}

int HealBuilding(int buildingIndex, int engineerIndex) {
	// It's Sigafoo save time BABY!

	// Hook attribute class to get repair amount
	float RepairAmountFloat = TF2Attrib_HookValueFloat(0.0, "arrow_heals_buildings", engineerIndex);

	// Reduce healing amount if wrangled sentry.
	// If wrangler revert is enabled, then the sentry is faked as unshielded, thus allowing full heals
	if (HasEntProp(buildingIndex, Prop_Send, "m_nShieldLevel")) {
		if (GetEntProp(buildingIndex, Prop_Send, "m_nShieldLevel") == SHIELD_NORMAL) {
			RepairAmountFloat *= SHIELD_NORMAL_VALUE;
		}
	}

	RepairAmountFloat = floatMin(RepairAmountFloat,float(GetEntProp(buildingIndex, Prop_Data, "m_iMaxHealth") - GetEntProp(buildingIndex, Prop_Data, "m_iHealth")));

	int currentHealth = GetEntProp(buildingIndex, Prop_Data, "m_iHealth");
	int RepairAmount = RoundToNearest(RepairAmountFloat);
	if (RepairAmountFloat > 0.0) {

		SetVariantInt(RepairAmount);
		AcceptEntityInput(buildingIndex, "AddHealth", engineerIndex);
		int newHealth = GetEntProp(buildingIndex, Prop_Send, "m_iHealth");
		Event event = CreateEvent("building_healed");

		if (event != null)
		{
			event.SetInt("priority", 1); // HLTV event priority, not transmitted
			event.SetInt("building", buildingIndex); // self-explanatory.
			event.SetInt("healer", engineerIndex); // Index of the engineer who healed the building.
			event.SetInt("amount", newHealth - currentHealth); // Repair amount to display.

			event.Fire(); // FIRE IN THE HOLE!!!!!!!
		}

		// Check if building owner and the engineer who shot the bolt
		// are the same person, if not. Give them progress on
		// the "Circle the Wagons" achivement.
		int buildingOwner = GetEntPropEnt(buildingIndex,Prop_Send,"m_hBuilder");
		if (buildingOwner != engineerIndex) {
			AddProgressOnAchievement(engineerIndex,1836,RepairAmount);
		}
	} else {
		RepairAmount = 0;
	}

	return RepairAmount;
}

int GetEntityOwner(int entityIndex)
{
	if (!IsValidEntity(entityIndex))
		return -1; // Invalid entity

	int owner = GetEntPropEnt(entityIndex, Prop_Send, "m_hOwnerEntity");

	if (!IsFakeClient(owner) || IsFakeClient(owner))
		return owner; // Returns the player (or bot) index of the owner

	return -1; // Owner not found
}

bool AreEntitiesOnSameTeam(int entity1, int entity2)
{
	if (!IsValidEntity(entity1) || !IsValidEntity(entity2))
		return false;

	int team1 = GetEntProp(entity1, Prop_Send, "m_iTeamNum");
	int team2 = GetEntProp(entity2, Prop_Send, "m_iTeamNum");

	return (team1 == team2);
}

bool IsBuildingValidHealTarget(int buildingIndex, int engineerIndex)
{
	if (!IsValidEntity(buildingIndex))
		return false;

	char classname[64];
	GetEntityClassname(buildingIndex, classname, sizeof(classname));

	if (
		!StrEqual(classname, "obj_sentrygun", false) &&
		!StrEqual(classname, "obj_teleporter", false) &&
		!StrEqual(classname, "obj_dispenser", false)
	) {
		//PrintToChatAll("Entity did not match buildings");
		return false;
	}

	if (
		GetEntProp(buildingIndex, Prop_Send, "m_bHasSapper") ||
		GetEntProp(buildingIndex, Prop_Send, "m_bPlasmaDisable") ||
		GetEntProp(buildingIndex, Prop_Send, "m_bBuilding") ||
		GetEntProp(buildingIndex, Prop_Send, "m_bPlacing")
	) {
		//PrintToChatAll("Big if statement about sappers etc triggered");
		return false;
	}

	if (!AreEntitiesOnSameTeam(buildingIndex, engineerIndex)) {
		//PrintToChatAll("Entities were not on the same team");
		return false;
	}

	return true;
}

void AttachTEParticleToEntityAndSend(int entityIndex, int particleID, int attachType)
{
	if (!IsValidEntity(entityIndex))
	return;

	TE_Start("TFParticleEffect");

	TE_WriteNum("m_iParticleSystemIndex", particleID); // Particle effect ID (not string)
	TE_WriteNum("m_iAttachType", attachType);   // Attachment type (e.g., follow entity)
	TE_WriteNum("entindex", entityIndex);           // Attach to the given entity

	TE_SendToAll();
}

bool AddProgressOnAchievement(int playerID, int achievementID, int Amount) {
	if (sdkcall_AwardAchievement == null || achievementID < 1 || Amount < 1) {
		return false; //SDKcall not prepared or Handle not created.
	}

	if (!IsFakeClient(playerID)) {
		return false; //Client (aka player) is not valid, are they connected?
	}
		SDKCall(sdkcall_AwardAchievement, playerID, achievementID, Amount);

	return true;
}

// Get the sentry of a specific engineer
// WARNING: Do not use in MVM!
int FindSentryGunOwnedByClient(int client)
{
	if (cvar_ref_tf_gamemode_mvm.BoolValue)
		return -1;

	if (!IsClientInGame(client) || GetClientTeam(client) < 2)
		return -1;

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
	{
		int owner = GetEntPropEnt(ent,Prop_Send,"m_hBuilder");
		if (owner == client)
			return ent;
	}

	return -1;
}

// Get the built (construction finished) teleporter exit of a specific engineer
int FindBuiltTeleporterExitOwnedByClient(int client)
{
	if (!IsClientInGame(client) || GetClientTeam(client) < 2)
		return -1;

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
	{
		int owner = GetEntPropEnt(ent,Prop_Send,"m_hBuilder");
		if (
			owner == client &&
			GetEntProp(ent, Prop_Send, "m_iState") != 0 && // TELEPORTER_STATE_BUILDING
			GetEntProp(ent, Prop_Data, "m_iTeleportType") == 2 // TTYPE_EXIT
		)
			return ent;
	}

	return -1;
}

MRESReturn DHookCallback_CTFWeaponBase_PrimaryAttack(int entity) {
	int owner;
	char class[64];

	if (
		GetItemVariant(Wep_ShortCircuit) == 1 ||
		GetItemVariant(Wep_ShortCircuit) == 2
	) {
		GetEntityClassname(entity, class, sizeof(class));
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (
			owner > 0 &&
			StrEqual(class, "tf_weapon_mechanical_arm")
		) {
			// short circuit primary fire
			// Base amount is 0 because we rely on the default primary fire metal consumption (5)
			switch (GetItemVariant(Wep_ShortCircuit)) {
				case 1: {
					DoShortCircuitProjectileRemoval(owner, entity, 0, 15);
				}
				case 2: {
					DoShortCircuitProjectileRemoval(owner, entity, 0, 0);
				}
			}
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFWeaponBase_SecondaryAttack(int entity) {
	int idx;
	int owner;
	char class[64];
	int metal;

	GetEntityClassname(entity, class, sizeof(class));

	owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (owner > 0) {
		if (
			StrEqual(class, "tf_weapon_flamethrower") ||
			StrEqual(class, "tf_weapon_rocketlauncher_fireball")
		) {
			// airblast set type cvar

			SetConVarMaybe(cvar_ref_tf_airblast_cray, "0", ItemIsEnabled(Feat_Airblast));

			return MRES_Ignored;
		}
		if (
			GetItemVariant(Wep_ShortCircuit) == 0 &&
			StrEqual(class, "tf_weapon_mechanical_arm")
		) {
			// short circuit secondary fire

			SetEntPropFloat(entity, Prop_Send, "m_flNextPrimaryAttack", (GetGameTime() + BALANCE_CIRCUIT_RECOVERY));
			SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", (GetGameTime() + BALANCE_CIRCUIT_RECOVERY));

			metal = GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);

			if (metal >= BALANCE_CIRCUIT_METAL) {
				for (idx = 1; idx <= MaxClients; idx++) {
					if (
						IsClientInGame(idx) &&
						(
							idx != owner ||
							metal < 65
						)
					) {
						EmitGameSoundToClient(idx, "Weapon_BarretsArm.Shot", owner);
					}
				}
				DoShortCircuitProjectileRemoval(owner, entity, BALANCE_CIRCUIT_METAL, 0, BALANCE_CIRCUIT_DAMAGE);
			}

			return MRES_Supercede;
		}

		if (
			(GetItemVariant(Wep_ShortCircuit) == 1 ||
			GetItemVariant(Wep_ShortCircuit) == 2) &&
			StrEqual(class, "tf_weapon_mechanical_arm")
		) {
			// prevent alt-fire for pre-gunmettle short circuit
			return MRES_Supercede;
		}

		if (
			ItemIsEnabled(Wep_Shortstop) &&
			cvar_enable_shortstop_shove.BoolValue == false &&
			StrEqual(class, "tf_weapon_handgun_scout_primary")
		) {
			// shortstop shove removal
			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

/**
 * Removes projectiles and optionally damages players in front of the Short Circuit user.
 *
 * @param owner                Client index of the player using the Short Circuit.
 * @param entity               Entity index of the Short Circuit weapon.
 * @param base_amount          Amount of metal to consume on use (0 for none).
 * @param amount_per_destroyed Additional metal to consume per destroyed projectile (0 for none).
 * @param damage               Damage to apply to players hit (default 0.0 for none).
 *
 */
void DoShortCircuitProjectileRemoval(int owner, int entity, int base_amount, int amount_per_destroyed, float damage = 0.0) {
	int idx;
	char class[64];
	float player_pos[3];
	float target_pos[3];
	float angles1[3];
	float angles2[3];
	float vector[3];
	float distance;
	float limit;
	int metal;

	metal = GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);

	if (base_amount) {
		SetEntProp(owner, Prop_Data, "m_iAmmo", (metal - base_amount), 4, 3);
	}

	GetClientEyePosition(owner, player_pos);
	GetClientEyeAngles(owner, angles1);

	// scan for entities to hit
	for (idx = 1; idx < 2048; idx++) {
		if (IsValidEntity(idx)) {
			GetEntityClassname(idx, class, sizeof(class));

			// only hit players and some projectiles
			if (
				(idx <= MaxClients) ||
				(StrContains(class, "tf_projectile_") == 0 &&
				StrContains(class, "tf_projectile_spell") == -1 &&
				!StrEqual(class, "tf_projectile_energy_ring") &&
				!StrEqual(class, "tf_projectile_grapplinghook") &&
				!StrEqual(class, "tf_projectile_syringe"))
			) {
				// don't hit stuff on the same team
				if (GetEntProp(idx, Prop_Send, "m_iTeamNum") != GetClientTeam(owner)) {
					GetEntPropVector(idx, Prop_Send, "m_vecOrigin", target_pos);

					// if hitting a player, compare to center
					if (idx <= MaxClients) {
						target_pos[2] += PLAYER_CENTER_HEIGHT;
					}

					distance = GetVectorDistance(player_pos, target_pos);

					// absolute max distance
					if (distance < 300.0) {
						MakeVectorFromPoints(player_pos, target_pos, vector);

						GetVectorAngles(vector, angles2);

						angles2[1] = FixViewAngleY(angles2[1]);

						angles1[0] = 0.0;
						angles2[0] = 0.0;

						// more strict angles vs players than projectiles
						if (idx <= MaxClients) {
							limit = ValveRemapVal(distance, 0.0, 150.0, 70.0, 25.0);
						} else {
							limit = ValveRemapVal(distance, 0.0, 200.0, 80.0, 40.0);
						}

						// check if view angle relative to target is in range
						if (CalcViewsOffset(angles1, angles2) < limit) {
							// trace from player camera pos to target
							TR_TraceRayFilter(player_pos, target_pos, MASK_SOLID, RayType_EndPoint, TraceFilter_CustomShortCircuit, idx);

							// didn't hit anything on the way to the target, so proceed
							if (TR_DidHit() == false) {
								if (idx <= MaxClients) {
									// damage players
									if (damage != 0.0) {
										SDKHooks_TakeDamage(idx, entity, owner, damage, DMG_SHOCK, entity, NULL_VECTOR, target_pos, false);

										// show particle effect
										ParticleShow("dxhr_arm_muzzleflash", player_pos, target_pos, angles1);
									}
								} else {
									// delete projectiles
									if (amount_per_destroyed)
									{
										metal = GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);
										if (metal < (base_amount + amount_per_destroyed)) break;
										SetEntProp(owner, Prop_Data, "m_iAmmo", (metal - amount_per_destroyed), 4, 3);
									}

									// show particle effect
									ParticleShow("dxhr_arm_muzzleflash", player_pos, target_pos, angles1);

									RemoveEntity(idx);
								}
							}
						}
					}
				}
			}
		}
	}
}

MRESReturn DHookCallback_CTFBaseRocket_GetRadius(int entity, DHookReturn returnValue) {
	int owner;
	int weapon;
	char class[64];

	GetEntityClassname(entity, class, sizeof(class));

	owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");

	if (
		owner > 0 &&
		owner <= MaxClients && // rockets can be fired by non-player entities
		weapon > 0
	) {
		if (StrEqual(class, "tf_projectile_rocket")) {
			GetEntityClassname(weapon, class, sizeof(class));

			if (
				ItemIsEnabled(Wep_Airstrike) &&
				StrEqual(class, "tf_weapon_rocketlauncher_airstrike") &&
				IsPlayerAlive(owner) &&
				TF2_IsPlayerInCondition(owner, TFCond_BlastJumping)
			) {
				returnValue.Value = view_as<float>(returnValue.Value) * 1.25;
				return MRES_Override;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFPlayer_CalculateMaxSpeed(int entity, DHookReturn returnValue) {
	if (
		entity >= 1 &&
		entity <= MaxClients &&
		IsValidEntity(entity) &&
		IsClientInGame(entity)
	) {
		if (TF2_GetPlayerClass(entity) == TFClass_Scout) {
			float multiplier = 1.0;
			if (
				ItemIsEnabled(Wep_CritCola) &&
				GetItemVariant(Wep_CritCola) != 4 &&
				TF2_IsPlayerInCondition(entity, TFCond_CritCola) &&
				player_weapons[entity][Wep_CritCola]
			) {
				// Crit-a-Cola speed boost.
				multiplier *= 1.25;
			}

			if (
				GetItemVariant(Wep_BabyFace) == 1 &&
				player_weapons[entity][Wep_BabyFace]
			) {
				// Release Baby Face's Blaster proper speed application.
				// Without this, the max boost speed would be only 376 HU/s, so we boost it further by ~38% at max boost
				float boost = GetEntPropFloat(entity, Prop_Send, "m_flHypeMeter");
				multiplier *= ValveRemapVal(boost, 0.0, 100.0, 1.0, 1.3829787);
			}

			if (multiplier != 1.0)
			{
				returnValue.Value = view_as<float>(returnValue.Value) * multiplier;
				return MRES_Override;
			}
		}

		if (
			ItemIsEnabled(Wep_BuffaloSteak) &&
			TF2_IsPlayerInCondition(entity, TFCond_CritCola) &&
			TF2_GetPlayerClass(entity) == TFClass_Heavy &&
			player_weapons[entity][Wep_BuffaloSteak]
		)
		{
			// Buffalo Steak Sandvich Pre-MyM Speed boost Revert.
			// Detect if the player is equipping the GRU or Eviction Notice, if true, then do not adjust the speed
			int weapon = GetPlayerWeaponSlot(entity, TFWeaponSlot_Melee);

			if (weapon > 0)
			{
				int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

				// Release steak + GRU move speed stacking imitation code
				// resulting speed should be 403.65 HU/s since old GRU + Buffalo Steak speed stack was 403.65 HU/s (230*1.30*1.35)
				// note: whip speedboost doesn't stack with old steak + GRU speed stacking. the same behavior also exists for vanilla steak + GRU.
				if(GetItemVariant(Wep_BuffaloSteak) == 1 && (index == 239 || index == 1084 || index == 1100)) {				
					returnValue.Value = view_as<float>(returnValue.Value) * 1.30; 
					// it rounds to 403.50 HU/s for some reason via cl_showpos 1, i gave up trying to get it to the exact value but this should be good enough
					// technically 403.50 HU/s isn't historically accurate, but i have no idea why i can't get it to 403.65 HU/s despite setting it to exactly that value before
					return MRES_Override;	
				}

				if (!(index == 239 || index == 1084 || index == 1100 || (index == 426 && GetItemVariant(Wep_Eviction) == 0)))
				{
					// Change the speed to 310.5 HU/s when Buffalo Steak Sandvich is used.
					// Note: The speedboost for the Eviction Notice gets capped at 310.5 HU/s whenever the reverted Steak buff is in effect. This happpens too with Vanilla.	
					// initial returnValue.Value = ~299 HU/s
					if ((index == 426) && (GetItemVariant(Wep_Eviction) == 1) && TF2_IsPlayerInCondition(entity, TFCond_SpeedBuffAlly)) {
						// Cap speed to 310.5 HU/s when speedboost on hit is active while under reverted Steak buff for the Gun Mettle variant of the Eviction Notice
						returnValue.Value = view_as<float>(returnValue.Value) * 1.00;
						return MRES_Override;
					}
					else if ((index == 426) && (GetItemVariant(Wep_Eviction) == -1)) {
						// Cap speed to 310.5 HU/s while under reverted Steak buff when using the vanilla Eviction Notice
						returnValue.Value = view_as<float>(returnValue.Value) * 1.00;
						return MRES_Override;
					}				
					// increase speed to 310.5 HU/s
					else returnValue.Value = view_as<float>(returnValue.Value) * 1.038;
					return MRES_Override;
				}
				
			
			}
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFPlayer_CanDisguise(int entity, DHookReturn returnValue) {
	if (
		IsPlayerAlive(entity) &&
		TF2_GetPlayerClass(entity) == TFClass_Spy &&
		(GetGameTime() - players[entity].backstab_time) > 0.0 &&
		(GetGameTime() - players[entity].backstab_time) < 0.5 &&
		ItemIsEnabled(Wep_EternalReward)
	) {
		// CanDisguise() is being called from the eternal reward's DisguiseOnKill()
		// so we have to overwrite the result, otherwise the "cannot disguise" attrib will block it

		bool value = true;

		char class[64];

		int flag = GetEntPropEnt(entity, Prop_Send, "m_hItem");

		if (flag > 0) {
			GetEntityClassname(flag, class, sizeof(class));

			if (
				StrEqual(class, "item_teamflag") &&
				GetEntProp(flag, Prop_Send, "m_nType") != TF_FLAGTYPE_PLAYER_DESTRUCTION
			) {
				value = false;
			}
		}

		if (GetEntProp(entity, Prop_Send, "m_bHasPasstimeBall")) {
			value = false;
		}

		int weapon = GetPlayerWeaponSlot(entity, TFWeaponSlot_Grenade); // wtf valve?

		if (weapon > 0) {
			GetEntityClassname(weapon, class, sizeof(class));

			if (StrEqual(class, "tf_weapon_pda_spy") == false) {
				value = false;
			}
		} else {
			value = false;
		}

		returnValue.Value = value;

		return MRES_Override;
	}

	return MRES_Ignored;
}

float PersuaderPackRatios[] =
{
	0.25,	// SMALL
	0.5,	// MEDIUM
	1.0,	// FULL
};

MRESReturn DHookCallback_CAmmoPack_MyTouch(int entity, DHookReturn returnValue, DHookParam parameters)
{
	int client = parameters.Get(1);
	if (
		client > 0 &&
		client <= MaxClients
	) {
		int pack_size = SDKCall(sdkcall_CAmmoPack_GetPowerupSize, entity);
		if (
			ItemIsEnabled(Wep_Persian) &&
			TF2Attrib_HookValueInt(0, "ammo_becomes_health", client) == 1
		) {
			// Health pickup with the Persian Persuader.
			returnValue.Value = false;
			int health = GetClientHealth(client);
			int health_max = SDKCall(sdkcall_GetMaxHealth, client);
			if (health < health_max)
			{
				// Get amount to heal.
				int heal = RoundFloat(40 * PersuaderPackRatios[pack_size]);

				// Add health and show that the player got healed.
				Event event = CreateEvent("player_healonhit", true);
				event.SetInt("amount", TF2Util_TakeHealth(client, float(heal)));
				event.SetInt("entindex", client);
				event.Fire();

				// remove afterburn and bleed debuffs on heal
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Bleeding);

				// Play pickup sound
				EmitSoundToAll("items/gunpickup2.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL);
				returnValue.Value = true;
			}
			return MRES_Supercede;
		}
		if (
			GetItemVariant(Wep_DeadRinger) == 0 &&
			GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") < 100.0
		) {
			int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Building);
			if (weapon > 0) {
				if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 59) {
					// cap cloak gain to 35% per pack
					float multiplier = 1.0;
					if (pack_size > 0) {
						multiplier = (pack_size == 1) ? 0.7 : 0.35;
					}
					TF2Attrib_SetByDefIndex(weapon, 729, multiplier); // ReducedCloakFromAmmo
					players[client].cloak_gain_capped = true;
				}
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFAmmoPack_PackTouch(int entity, DHookParam parameters)
{
	int client = parameters.Get(1);
	if (
		client > 0 &&
		client <= MaxClients
	) {
		if (
			ItemIsEnabled(Wep_Persian) &&
			TF2Attrib_HookValueInt(0, "ammo_becomes_health", client) == 1
		) {
			// Health pickup with the Persian Persuader from dropped ammo packs.
			int health = GetClientHealth(client);
			int health_max = SDKCall(sdkcall_GetMaxHealth, client);
			if (health < health_max)
			{
				// Add health and show that the player got healed.
				Event event = CreateEvent("player_healonhit", true);
				event.SetInt("amount", TF2Util_TakeHealth(client, 20.0));
				event.SetInt("entindex", client);
				event.Fire();

				// remove afterburn and bleed debuffs on heal
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Bleeding);

				// Play pickup sound
				// If you're wondering why EmitSoundToAll below is repeated in a different channel,
				// it's so it sounds louder to be like the actual in-game sound and because I can't increase the volume beyond 1.0 for some reason.
				EmitSoundToAll("items/ammo_pickup.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL); // If ammo_pickup sound doesn't play, this should make it play.
				EmitSoundToAll("items/ammo_pickup.wav", entity, SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL); // and I am forced to do this to make it louder. I tried. Why?
				RemoveEntity(entity);
			}
			return MRES_Supercede;
		}
		if (
			GetItemVariant(Wep_DeadRinger) == 0 &&
			GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") < 100.0
		) {
			int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Building);
			if (weapon > 0) {
				if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 59) {
					// cap cloak gain to 35% per pack
					TF2Attrib_SetByDefIndex(weapon, 729, 0.7); // ReducedCloakFromAmmo
					players[client].cloak_gain_capped = true;
				}
			}
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFProjectile_Arrow_BuildingHealingArrow_Pre(int arrowEntity, DHookParam parameters) {
	MRESReturn returnValue = MRES_Ignored;
	int engineerIndex = GetEntityOwner(arrowEntity); // Get attacking entity.
	int sentry = parameters.Get(1);

#if defined MEMORY_PATCHES
	// Do not allow healing on mini sentries.
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(sentry, Prop_Send, "m_bMiniBuilding")
	) {
		return MRES_Supercede;
	}
#endif

	if (ItemIsEnabled(Wep_RescueRanger)) {
		int weapon;
		char class[64];
		// Grab weapon.
		weapon = GetPlayerWeaponSlot(engineerIndex, TFWeaponSlot_Primary);

		if (weapon > 0) {
			GetEntityClassname(weapon, class, sizeof(class));

			if (
				StrEqual(class, "tf_weapon_shotgun_building_rescue") &&
				GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 997
			) {
				returnValue = MRES_Supercede; // Weapon is a Rescue Ranger, so we cancel pre to handle building healing in post.
			}
		}
	}
	
	// Fake the sentry being unshielded to allow for maximum healing potential.
	if (
		ItemIsEnabled(Wep_Wrangler) &&
		IsValidEntity(sentry) &&
		HasEntProp(sentry, Prop_Send, "m_nShieldLevel")
	) {
		entities[sentry].old_shield = GetEntProp(sentry, Prop_Send, "m_nShieldLevel");
		SetEntProp(sentry, Prop_Send, "m_nShieldLevel", SHIELD_NONE);
	}

	return returnValue;
}

MRESReturn DHookCallback_CTFProjectile_Arrow_BuildingHealingArrow_Post(int arrowEntity, DHookParam parameters) {
	MRESReturn returnValue = MRES_Ignored;
	int buildingIndex = parameters.Get(1);
	int engineerIndex = GetEntityOwner(arrowEntity);

#if defined MEMORY_PATCHES
	// Do not allow healing on mini sentries.
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(buildingIndex, Prop_Send, "m_bMiniBuilding")
	) {
		return MRES_Supercede;
	}
#endif

	if (ItemIsEnabled(Wep_RescueRanger)) {
		int weapon;
		char class[64];

		// Grab weapon.
		weapon = GetPlayerWeaponSlot(engineerIndex, TFWeaponSlot_Primary);

		if (weapon > 0) {
			GetEntityClassname(weapon, class, sizeof(class));

			if (
				StrEqual(class, "tf_weapon_shotgun_building_rescue") &&
				GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 997
			) {
				// Now we can proceed with healing the building etc.
				// Sentry and Engineer must be on the same team for heal to happen.
				if (IsBuildingValidHealTarget(buildingIndex, engineerIndex)) {
					int RepairAmount = HealBuilding(buildingIndex, engineerIndex);

					// Spawn some particles if healing occured.
					if (RepairAmount > 0) {

						// HERE WE CALL FUNCTION TO SPAWN TE PARTICLES
						int teamNum = GetEntProp(arrowEntity,Prop_Data,"m_iTeamNum");
						if (teamNum == 2) {
							// [1699] repair_claw_heal_red
							// PATTACH_ABSORIGIN_FOLLOW
							AttachTEParticleToEntityAndSend(arrowEntity, 1699, 1); // Red
						} else {
							// [1696] repair_claw_heal_blue
							AttachTEParticleToEntityAndSend(arrowEntity, 1696, 1); // Blue
						}
					}
				}
				returnValue = MRES_Supercede;
			}
		}
	}

	// Revert the sentry's shield.
	if (
		ItemIsEnabled(Wep_Wrangler) &&
		IsValidEntity(buildingIndex) &&
		HasEntProp(buildingIndex, Prop_Send, "m_nShieldLevel")
	) {
		SetEntProp(buildingIndex, Prop_Send, "m_nShieldLevel", entities[buildingIndex].old_shield);
	}

	return returnValue;
}

#if defined MEMORY_PATCHES
MRESReturn DHookCallback_CTFAmmoPack_MakeHolidayPack(int pThis) {
	if (cvar_dropped_weapon_enable.BoolValue) {
		return MRES_Supercede;
	}
	return MRES_Ignored;
}
#endif

MRESReturn DHookCallback_CTFPlayer_AddToSpyKnife(int entity, DHookReturn returnValue, DHookParam parameters)
{
	if (ItemIsEnabled(Wep_Spycicle))
	{
		// Prevent ammo pick-up with the spycicle when cloak meter AND ammo are full.
		returnValue.Value = false;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFPlayer_RegenThink(int client)
{
	int weapon;
	bool full_regen = false;
	float regen_amount;
	float time_since_damage;
	float regen_scale;

	// Don't proceed if in MvM
    if (cvar_ref_tf_gamemode_mvm.BoolValue)
		return MRES_Ignored;

	if (
		client > 0 &&
		client <= MaxClients
	) {
		// Grab secondary weapon
		weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

		if (
			ItemIsEnabled(Wep_Concheror) &&
			weapon > 0
		) {
			if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 354) {
				// Weapon is a Concheror, increase regen amount for this instance
				full_regen = true;
			}
		}
	
		// Grab active weapon
		weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if (
			ItemIsEnabled(Wep_Amputator) &&
			weapon > 0
		) {
			if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 304) {
				// Weapon is an Amputator, increase regen amount for this instance
				full_regen = true;
			}
		}

		if (full_regen) {
			regen_amount = TF2Attrib_HookValueFloat(0.0, "add_health_regen", client);
			time_since_damage = GetGameTime() - players[client].damage_received_time;
			regen_scale = 1.0;

			if (time_since_damage < 5.0) {
				regen_scale = 4.0; // 1 / 0.25
			} else {
				// inverse of flScale = RemapValClamped( flTimeSinceDamage, 5.0f, 10.0f, 0.5f, 1.0f );
				// third parameter is 9.0 to minimize chance of regen overshooting
				regen_scale = ValveRemapVal(time_since_damage, 5.0, 9.0, 2.0, 1.0);
			}

			// apply regen
			regen_amount *= regen_scale - 1.0; // compensate for original regen source
			if (regen_amount > 0.0) {
				TF2Attrib_AddCustomPlayerAttribute(client, "health regen", regen_amount, 0.001);
			}

			return MRES_Ignored;
		}
	}
	
    return MRES_Ignored;
}

MRESReturn DHookCallback_CObjectDispenser_DispenseAmmo(int entity, DHookReturn returnValue, DHookParam parameters) {
	int client = parameters.Get(1);
	if (
		client > 0 &&
		client <= MaxClients
	) {
		if (
			ItemIsEnabled(Wep_Persian) &&
			TF2Attrib_HookValueInt(0, "ammo_becomes_health", client) == 1
		) {
			// Prevent ammo pick-up from Dispensers with Persian Persuader equipped.
			returnValue.Value = false;
			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CObjectSentrygun_OnWrenchHit_Pre(int entity, DHookReturn returnValue, DHookParam parameters) {
	// Fake the sentry being unshielded to allow for full repair.
	if (
		ItemIsEnabled(Wep_Wrangler) &&
		IsValidEntity(entity) &&
		HasEntProp(entity, Prop_Send, "m_nShieldLevel")
	) {
		entities[entity].old_shield = GetEntProp(entity, Prop_Send, "m_nShieldLevel");
		SetEntProp(entity, Prop_Send, "m_nShieldLevel", SHIELD_NONE);
	}

#if defined MEMORY_PATCHES
	// Do not allow repairs on mini sentries. Mini sentries can still get refilled with ammo.
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding")
	) {
		// Refill ammo for mini sentry. Logic sourced from TF2 source code

		bool did_work = false;
		int client = parameters.Get(1);
		if (
			client > 0 &&
			client <= MaxClients
		) {
			int metal = GetEntProp(client, Prop_Send, "m_iAmmo", 4, 3);
			int sentry_ammo = GetEntProp(entity, Prop_Send, "m_iAmmoShells");
			int sentry_max_ammo = SENTRYGUN_MAX_SHELLS_1;

			if (sentry_ammo < sentry_max_ammo && metal > 0) {
				float amount_to_add_float = float(intMin(SENTRYGUN_ADD_SHELLS, metal));

				if (GetEntProp(entity, Prop_Send, "m_nShieldLevel") == SHIELD_NORMAL) {
					amount_to_add_float *= SHIELD_NORMAL_VALUE;
				}

				amount_to_add_float = floatMin(float(sentry_max_ammo - sentry_ammo), amount_to_add_float);

				int amount_to_add = RoundToNearest(amount_to_add_float);
				SetEntProp(client, Prop_Send, "m_iAmmo", intMax(metal - amount_to_add, 0), 4, 3);
				SetEntProp(entity, Prop_Send, "m_iAmmoShells", sentry_ammo + amount_to_add);

				if (amount_to_add > 0) {
					did_work = true;
				}
			}
		}
		returnValue.Value = did_work;
		return MRES_Supercede;
	}
#endif

	return MRES_Ignored;
}

MRESReturn DHookCallback_CObjectSentrygun_OnWrenchHit_Post(int entity, DHookReturn returnValue, DHookParam parameters) {
	// Revert the sentry's shield.
	if (
		ItemIsEnabled(Wep_Wrangler) &&
		IsValidEntity(entity) &&
		HasEntProp(entity, Prop_Send, "m_nShieldLevel")
	) {
		SetEntProp(entity, Prop_Send, "m_nShieldLevel", entities[entity].old_shield);
	}

	return MRES_Ignored;
}

#if defined MEMORY_PATCHES
MRESReturn DHookCallback_CObjectSentrygun_StartBuilding(int entity, DHookReturn returnValue, DHookParam parameters) {
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding") &&
		!GetEntProp(entity, Prop_Send, "m_bCarryDeploy")
	) {
		// Mini sentries always start off at max health.
		StoreToAddress(GetEntityAddress(entity) + CBaseObject_m_flHealth, 100.00, NumberType_Int32);
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CObjectSentrygun_Construct_Pre(int entity, DHookReturn returnValue, DHookParam parameters) {
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding")
	) {
		Address m_flHealth = GetEntityAddress(entity) + CBaseObject_m_flHealth;
		entities[entity].minisentry_health = view_as<float>(LoadFromAddress(m_flHealth, NumberType_Int32));
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CObjectSentrygun_Construct_Post(int entity, DHookReturn returnValue, DHookParam parameters) {
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding")
	) {
		Address m_flHealth = GetEntityAddress(entity) + CBaseObject_m_flHealth;
		if (SDKCall(sdkcall_CBaseObject_GetReversesBuildingConstructionSpeed, entity))
			StoreToAddress(m_flHealth, view_as<float>(LoadFromAddress(m_flHealth, NumberType_Int32)) - 0.5, NumberType_Int32);
		else if (GetItemVariant(Wep_Gunslinger) == 0) {
			// Pre-GM Gunslinger, prevent mini sentries from gaining health while being built.
			StoreToAddress(m_flHealth, entities[entity].minisentry_health, NumberType_Int32);
		} else {
			// Release Gunslinger double heal rate on construction
			float delta = view_as<float>(LoadFromAddress(m_flHealth, NumberType_Int32)) - entities[entity].minisentry_health;
			if (delta > 0.0) {
				StoreToAddress(m_flHealth, floatMin(entities[entity].minisentry_health + 2 * delta, 100.0), NumberType_Int32);
			}
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CBaseObject_OnConstructionHit(int entity, DHookReturn returnValue) {
	char class[64];
	if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding")
	) {
		GetEntityClassname(entity, class, sizeof(class));

		if (StrEqual(class, "obj_sentrygun")) {
			// Do not allow mini sentries to be construction boosted.
			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CBaseObject_CreateAmmoPack(int entity, DHookReturn returnValue, DHookParam parameters)
{
	// Allow metal to be picked up from mini sentry gibs.
    if (
		ItemIsEnabled(Wep_Gunslinger) &&
		GetEntProp(entity, Prop_Send, "m_bMiniBuilding")
	) {
        parameters.Set(2, 7);
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

#endif

float CalcViewsOffset(float angle1[3], float angle2[3]) {
	float v1;
	float v2;

	v1 = FloatAbs(angle1[0] - angle2[0]);
	v2 = FloatAbs(angle1[1] - angle2[1]);

	v2 = FixViewAngleY(v2);

	return SquareRoot(Pow(v1, 2.0) + Pow(v2, 2.0));
}

float FixViewAngleY(float angle) {
	return (angle > 180.0 ? (angle - 360.0) : angle);
}

/** 
 * Get an absolute value of an integer.
 * 
 * @param x		Integer.
 * @retrun		Absolute value of x.
 */
int abs(int x)
{
	int mask = x >> 31;
	return (x + mask) ^ mask;
}

/**
 * Get the lesser integer between two integers.
 * 
 * @param x		Integer x.
 * @param y		Integer y.
 * @return		The lesser integer between x and y.
 */
int intMin(int x, int y)
{
	return x > y ? y : x;
}

/**
 * Get the greater integer between two integers.
 * 
 * @param x		Integer x.
 * @param y		Integer y.
 * @return		The greater integer between x and y.
 */
int intMax(int x, int y)
{
	return x > y ? x : y;
}

/**
 * Get the lesser float between two floats.
 * 
 * @param x		Float x.
 * @param y		Float y.
 * @return		The lesser float between x and y.
 */
float floatMin(float x, float y)
{
	return x > y ? y : x;
}

/**
 * Get the greater float between two floats.
 * 
 * @param x		Float x.
 * @param y		Float y.
 * @return		The greater float between x and y.
 */
float floatMax(float x, float y)
{
    return x > y ? x : y;
}

