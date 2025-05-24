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
#define VERDIUS_PATCHES

//#define WINDOWS32
#define LINUX32
/*
 ^ ^ ^ ^ ^ ^ ^ ^ ^
	Additionally, you will need to select your compile arch.
	Above are the compile variables for server architecture.
	Memory patches are different for windows and linux servers,
	so you should leave defined the version your server will be using
	and comment out the other.
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

#define PLUGIN_NAME "TF2 Weapon Reverts"
#define PLUGIN_DESC "Reverts nerfed weapons back to their glory days"
#define PLUGIN_AUTHOR "Bakugo, random, huutti, VerdiusArcana, MindfulProtons"

// Add a OS suffix if VerdiusArcanas patches are used
// so it becomes easier to for server owners to judge if they simply ran the wrong compiled .smx on their server
// if they encounter issues. To server owners, before you raise hell, do: sm plugins list and check that you
// compiled for the correct OS.
#if defined WINDOWS32
#define PLUGIN_VERSION "1.3.2-win32"
#elseif defined LINUX32
#define PLUGIN_VERSION "1.3.2-linux32"
#else
#define PLUGIN_VERSION "1.3.2"
#endif

#define PLUGIN_URL "https://steamcommunity.com/profiles/76561198020610103"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	description = PLUGIN_DESC,
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

#define ITEMS_MAX 100
#define ITEM_MENU_TIME (60*3)
#define BALANCE_CIRCUIT_METAL 10
#define BALANCE_CIRCUIT_DAMAGE 10.0
#define BALANCE_CIRCUIT_RECOVERY 0.25
#define PLAYER_CENTER_HEIGHT (82.0 / 2.0) // constant for tf2 players

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
#define TF_DMG_CUSTOM_STICKBOMB_EXPLOSION 42
#define TF_DMG_CUSTOM_CANNONBALL_PUSH 61
#define TF_DEATH_FEIGN_DEATH 0x20
#define TF_FLAGTYPE_PLAYER_DESTRUCTION 6

#define CLASSFLAG_SCOUT		(1<<0)
#define CLASSFLAG_SNIPER	(1<<1)
#define CLASSFLAG_SOLDIER	(1<<2)
#define CLASSFLAG_DEMOMAN	(1<<3)
#define CLASSFLAG_MEDIC		(1<<4)
#define CLASSFLAG_HEAVY		(1<<5)
#define CLASSFLAG_PYRO		(1<<6)
#define CLASSFLAG_SPY		(1<<7)
#define CLASSFLAG_ENGINEER	(1<<8)

char class_names[9][16] = {
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer"
};

enum struct Item {
	char key[64];
	char name[64];
	char desc[256];
	int classflags;
	Handle cvar;
}

enum struct Player {
	bool items_pick[ITEMS_MAX]; // enabled items the player has chosen
	bool items_life[ITEMS_MAX]; // enabled items for this life (inc cvar)
	bool change; // are there pending attrib changes?
	bool picked; // made any changes in the pick menu
	int respawn; // frame to force a respawn after

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
	int sleeper_ammo;
	int sleeper_piss_frame;
	float sleeper_piss_duration;
	bool sleeper_piss_explode;
	int medic_medigun_defidx;
	float medic_medigun_charge;
	float parachute_cond_time;
	float cleaver_regen_time;
	float icicle_regen_time;
	int scout_airdash_value;
	int scout_airdash_count;
	float backstab_time;
	int old_health;
	int ticks_since_feign_ready;
	float damage_taken_during_feign;
	bool is_under_hype;
	bool crit_flag;
	int charge_tick;
	int fall_dmg_tick;
}

//item sets
#define ItemSet_Saharan 1

enum struct Entity {
	bool exists;
	float spawn_time;
	bool is_demo_shield;
}

Handle cvar_enable;
Handle cvar_extras;
Handle cvar_jumper_flag_run;
Handle cvar_old_falldmg_sfx;
Handle cvar_ref_tf_airblast_cray;
Handle cvar_ref_tf_bison_tick_time;
Handle cvar_ref_tf_dropped_weapon_lifetime;
Handle cvar_ref_tf_feign_death_activate_damage_scale;
Handle cvar_ref_tf_feign_death_damage_scale;
Handle cvar_ref_tf_feign_death_duration;
Handle cvar_ref_tf_feign_death_speed_duration;
Handle cvar_ref_tf_fireball_radius;
Handle cvar_ref_tf_parachute_aircontrol;
Handle cvar_ref_tf_parachute_maxspeed_onfire_z;
Handle cvar_ref_tf_scout_hype_mod;
#if defined VERDIUS_PATCHES
MemoryPatch Verdius_RevertDisciplinaryAction;
// If Windows, prepare additional vars for Disciplinary Action.
#if defined WINDOWS32
float g_flNewDiscilplinaryAllySpeedBuffTimer = 3.0;
// Address of our float:
Address AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer;
#endif

// The Dragons Fury needs 5 memorypatches for Linux and only 1 for Windows.
// Check if we are compiling for Linux, if not then use the Windows one.
#if defined LINUX32
MemoryPatch Verdius_RevertTraceReqDragonsFury_JA;
MemoryPatch Verdius_RevertTraceReqDragonsFury_JNZ;
MemoryPatch Verdius_RevertTraceReqDragonsFury_JZ;
MemoryPatch Verdius_RevertTraceReqDragonsFury_JNZ2;
MemoryPatch Verdius_RevertTraceReqDragonsFury_FinalJNZ;
#else
// Dragons Fury Memorypatch for Windows.
MemoryPatch Verdius_RevertTraceReqDragonsFury_NOP_JZ;
#endif

MemoryPatch Verdius_RevertFirstSecondDamageLossOnMiniguns;
MemoryPatch Verdius_RevertFirstSecondAccuracyLossOnMiniguns;
MemoryPatch Verdius_RevertWranglerShieldHealNerfOnWrenches;
MemoryPatch Verdius_RevertWranglerShieldShellRefillNerfOnWrenches;
MemoryPatch Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches;
MemoryPatch Verdius_RevertCozyCamperFlinch;
MemoryPatch Verdius_RevertQuickFixUberCannotCapturePoint;

// =============== Dalokohs Bar ===========================
MemoryPatch Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat; 
MemoryPatch Verdius_RevertDalokohsBar_MOV_400; 

float g_flDalokohsBarCanOverHealTo = 400.0; // Float to use for revert

// Address of our float to use for the MOVSS part of revert:
Address AddressOf_g_flDalokohsBarCanOverHealTo;
// ========================================================

Handle sdkcall_AwardAchievement;
DHookSetup dHooks_CTFProjectile_Arrow_BuildingHealingArrow;
#endif
Handle sdkcall_JarExplode;
Handle sdkcall_GetMaxHealth;
Handle sdkcall_CAmmoPack_GetPowerupSize;
Handle dhook_CTFWeaponBase_PrimaryAttack;
Handle dhook_CTFWeaponBase_SecondaryAttack;
Handle dhook_CTFBaseRocket_GetRadius;
Handle dhook_CTFPlayer_CanDisguise;
Handle dhook_CTFPlayer_CalculateMaxSpeed;
Handle dhook_CAmmoPack_MyTouch;
Handle dhook_CTFAmmoPack_PackTouch;

// Spycicle ammo pickup fix imported from NotnHeavy's plugin
DHookSetup dhook_CTFPlayer_AddToSpyKnife;

Item items[ITEMS_MAX];
Player players[MAXPLAYERS+1];
Entity entities[2048];
int frame;
Handle hudsync;
Menu menu_main;
// Menu menu_pick;
int rocket_create_entity;
int rocket_create_frame;

//weapon caching
//this would break if you ever enabled picking up weapons from the ground!
//add weapons to the FRONT of this enum to maintain the player_weapons array size
enum
{
	Wep_CritCola,
	Wep_Bonk,
	Wep_BrassBeast,
	Wep_Natascha,
	Wep_RocketJumper,
	Wep_CharginTarge,
	Wep_SplendidScreen,
	Wep_TideTurner,
	Wep_PersianPersuader,
	Wep_Placeholder
}
bool player_weapons[MAXPLAYERS+1][Wep_Placeholder];

// debuff conditions
TFCond debuffs[] =
{
	TFCond_OnFire,
	TFCond_Jarated,
	TFCond_Bleeding,
	TFCond_Milked,
	TFCond_Gas
};

public void OnPluginStart() {
	int idx;
	Handle conf;
	// char tmp[64];
	
	CCheckTrie();

	CreateConVar("sm_reverts__version", PLUGIN_VERSION, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));

	cvar_enable = CreateConVar("sm_reverts__enable", "1", (PLUGIN_NAME ... " - Enable plugin"), _, true, 0.0, true, 1.0);
	cvar_extras = CreateConVar("sm_reverts__extras", "0", (PLUGIN_NAME ... " - Enable some fun extra features"), _, true, 0.0, true, 1.0);
	cvar_jumper_flag_run = CreateConVar("sm_reverts__jumper_flag_run", "0", (PLUGIN_NAME ... " - Enable intel pick-up for jumper weapons"), _, true, 0.0, true, 1.0);
	cvar_old_falldmg_sfx = CreateConVar("sm_reverts__old_falldmg_sfx", "1", (PLUGIN_NAME ... " - Enable old (pre-inferno) fall damage sound (old bone crunch, no hurt voicelines)"), _, true, 0.0, true, 1.0);

	HookConVarChange(cvar_jumper_flag_run, JumperFlagRunCvarChange);

	ItemDefine("Airblast", "airblast", "All flamethrowers' airblast mechanics are reverted to pre-inferno", CLASSFLAG_PYRO);
	ItemDefine("Air Strike", "airstrike", "Reverted to pre-toughbreak, no extra blast radius penalty when blast jumping", CLASSFLAG_SOLDIER);
#if defined VERDIUS_PATCHES
	ItemDefine("All Miniguns", "miniramp", "Reverted to pre-love&war, full damage and accuracy immediately on spinning up", CLASSFLAG_HEAVY);
#endif
	ItemDefine("All Swords", "swords", "Reverted to pre-toughbreak, no holster and deploy penalty", CLASSFLAG_DEMOMAN);
	ItemDefine("Ambassador", "ambassador", "Reverted to pre-inferno, deals full headshot damage (102) at all ranges", CLASSFLAG_SPY);
	ItemDefine("Atomizer", "atomizer", "Reverted to pre-inferno, can always triple jump, taking 10 damage each time", CLASSFLAG_SCOUT);
	ItemDefine("Axtinguisher", "axtinguish", "Reverted to pre-love&war, always deals 195 damage crits to burning targets", CLASSFLAG_PYRO);
	ItemDefine("Backburner", "backburner", "Reverted to Hatless update, 10% damage bonus", CLASSFLAG_PYRO);
	ItemDefine("B.A.S.E. Jumper", "basejump", "Reverted to pre-toughbreak, can redeploy, more air control, fire updraft", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN);
	ItemDefine("Baby Face's Blaster", "babyface", "Reverted to pre-gunmettle, no boost loss on damage, only -25% on jump", CLASSFLAG_SCOUT);
	ItemDefine("Beggar's Bazooka", "beggars", "Reverted to pre-2013, no radius penalty, misfires don't remove ammo", CLASSFLAG_SOLDIER);
	ItemDefine("Black Box", "blackbox", "Reverted to pre-gunmettle, flat +15 per hit, uncapped", CLASSFLAG_SOLDIER);
	ItemDefine("Bonk! Atomic Punch", "bonk", "Reverted to pre-inferno, no longer slows after the effect wears off", CLASSFLAG_SCOUT);
	ItemDefine("Booties & Bootlegger", "booties", "Reverted to pre-matchmaking, shield not required for speed bonus", CLASSFLAG_DEMOMAN);
	ItemDefine("Brass Beast", "brassbeast", "Reverted to pre-matchmaking, 20% damage resistance when spun up at any health", CLASSFLAG_HEAVY);
	ItemDefine("Bushwacka", "bushwacka", "Reverted to pre-love&war, 20% fire vuln at all times, random crits enabled", CLASSFLAG_SNIPER);
	ItemDefine("Chargin' Targe", "targe", "Reverted to pre-toughbreak, 40% blast resistance, afterburn immunity, crit after bash, no debuff removal", CLASSFLAG_DEMOMAN);
	ItemDefine("Claidheamh Mòr", "claidheamh", "Reverted to pre-toughbreak, -15 health, no damage vuln, longer charge also applies when holstered", CLASSFLAG_DEMOMAN);
	ItemDefine("Cleaner's Carbine", "carbine", "Reverted to release, crits for 3 seconds on kill", CLASSFLAG_SNIPER);
#if defined VERDIUS_PATCHES
	ItemDefine("Cozy Camper","cozycamper","Reverted to pre-matchmaking, flinch resist at any charge level", CLASSFLAG_SNIPER);
#endif
	ItemDefine("Crit-a-Cola", "critcola", "Reverted to pre-matchmaking, +25% movespeed, +10% damage taken, no mark-for-death on attack", CLASSFLAG_SCOUT);
#if defined VERDIUS_PATCHES
	ItemDefine("Dalokohs Bar", "dalokohsbar", "Reverted to Gun Mettle update, can now overheal to 400 hp again", CLASSFLAG_HEAVY);
#endif	
	ItemDefine("Darwin's Danger Shield", "darwin", "Reverted to pre-inferno, +25 max health, 15% bullet resist, 20% blast vuln, no fire resists", CLASSFLAG_SNIPER);
	ItemDefine("Dead Ringer", "ringer", "Reverted to pre-gunmettle, can pick up ammo, 90% dmg resist for up to 6.5s (reduced by dmg taken)", CLASSFLAG_SPY);
	ItemDefine("Degreaser", "degreaser", "Reverted to pre-toughbreak, full switch speed for all weapons, old penalties", CLASSFLAG_PYRO);
#if defined VERDIUS_PATCHES
	ItemDefine("Disciplinary Action", "disciplinary", "Reverted to pre-matchmaking, give allies 3 seconds of speed buff on hit", CLASSFLAG_SOLDIER);
#endif
#if defined VERDIUS_PATCHES
	ItemDefine("Dragon's Fury", "dragonfury", "Reverted to release, increased projectile size and no center-hit requirement for bonus damage", CLASSFLAG_PYRO);
#else
	ItemDefine("Dragon's Fury", "dragonfury", "Partially reverted to release, increased projectile size", CLASSFLAG_PYRO);
#endif
	ItemDefine("Enforcer", "enforcer", "Reverted to pre-gunmettle, damage bonus while undisguised, no piercing", CLASSFLAG_SPY);
	ItemDefine("Equalizer & Escape Plan", "equalizer", "Reverted to pre-Pyromania, merged back together, no healing, no mark-for-death", CLASSFLAG_SOLDIER);
	ItemDefine("Eviction Notice", "eviction", "Reverted to pre-inferno, no health drain, +20% damage taken", CLASSFLAG_HEAVY);
	ItemDefine("Fists of Steel", "fiststeel", "Reverted to pre-inferno, no healing penalties", CLASSFLAG_HEAVY);
	ItemDefine("Flying Guillotine", "guillotine", "Reverted to pre-inferno, stun crits, distance mini-crits, no recharge", CLASSFLAG_SCOUT);
	ItemDefine("Gloves of Running Urgently", "glovesru", "Reverted to pre-inferno, no health drain, marks for death", CLASSFLAG_HEAVY);
	ItemDefine("Half-Zatoichi", "zatoichi", "Reverted to pre-toughbreak, fast switch, less range, cannot switch until kill, full heal, crits", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN);
	ItemDefine("Liberty Launcher", "liberty", "Reverted to release, +40% projectile speed, -25% clip size", CLASSFLAG_SOLDIER);
	ItemDefine("Loch n Load", "lochload", "Reverted to pre-gunmettle, +20% damage against everything", CLASSFLAG_DEMOMAN);
	ItemDefine("Loose Cannon", "cannon", "Reverted to pre-toughbreak, +50% projectile speed, constant 60 dmg impacts", CLASSFLAG_DEMOMAN);
	ItemDefine("Market Gardener", "gardener", "Reverted to pre-toughbreak, no attack speed penalty", CLASSFLAG_SOLDIER);
	ItemDefine("Natascha", "natascha", "Reverted to pre-matchmaking, 20% damage resistance when spun up at any health", CLASSFLAG_HEAVY);
	ItemDefine("Panic Attack", "panic", "Reverted to pre-inferno, hold fire to load, let go to release, fire faster with bigger spread on lower health", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO | CLASSFLAG_HEAVY | CLASSFLAG_ENGINEER);
	ItemDefine("Persian Persuader", "persuader", "Reverted to pre-toughbreak, picks up ammo as health, +100% charge recharge rate, no max ammo penalty", CLASSFLAG_DEMOMAN);
	ItemDefine("Pomson 6000", "pomson", "Increased hitbox size (same as Bison), passes through team, no uber & cloak drain fall-off at any range", CLASSFLAG_ENGINEER);
	ItemDefine("Powerjack", "powerjack", "Reverted to pre-gunmettle, +75 HP on kill with overheal, +15% move speed & 20% dmg vuln while active", CLASSFLAG_PYRO);
	ItemDefine("Pretty Boy's Pocket Pistol", "pocket", "Reverted to release, +15 health, no fall damage, slower firing speed, increased fire vuln", CLASSFLAG_SCOUT);
#if defined VERDIUS_PATCHES
	ItemDefine("Quick-Fix", "quickfix", "Reverted to pre-toughbreak, +25% uber build rate, can capture objectives when ubered", CLASSFLAG_MEDIC);
#else
	ItemDefine("Quick-Fix", "quickfix", "Reverted to pre-matchmaking, +25% uber build rate", CLASSFLAG_MEDIC);
#endif
	ItemDefine("Razorback","razorback","Reverted to pre-inferno, can be overhealed, shield does not regenerate", CLASSFLAG_SNIPER);
#if defined VERDIUS_PATCHES
	ItemDefine("Rescue Ranger", "rescueranger", "Reverted to pre-gunmettle, heals +75 flat, no metal cost, 130 cost long ranged pickups", CLASSFLAG_ENGINEER);
#endif
	ItemDefine("Reserve Shooter", "reserve", "Reverted to pre-inferno, deals minicrits to airblasted targets again", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO);
	ItemDefine("Righteous Bison", "bison", "Reverted to pre-matchmaking, increased hitbox size, can hit the same player more times", CLASSFLAG_SOLDIER);
	ItemDefine("Rocket Jumper", "rocketjmp", "Reverted to pre-2013, grants immunity to self-damage from Equalizer/Escape Plan taunt kill", CLASSFLAG_SOLDIER);
	ItemDefine("Saharan Spy", "saharan", "Restored release item set bonus, quiet decloak, 0.5s longer cloak blink time. Familiar Fez not required", CLASSFLAG_SPY);
	ItemDefine("Sandman", "sandman", "Reverted to pre-inferno, stuns players on hit again, 15 sec ball recharge time", CLASSFLAG_SCOUT);
	ItemDefine("Scottish Resistance", "scottish", "Reverted to release, 0.4 arm time penalty (from 0.8), no fire rate bonus", CLASSFLAG_DEMOMAN);
	ItemDefine("Short Circuit", "circuit", "Reverted to post-gunmettle, alt fire destroys projectiles, -cost +speed", CLASSFLAG_ENGINEER);
	ItemDefine("Shortstop", "shortstop", "Reverted to pre-Manniversary, faster reload time, no push force penalty, shares pistol ammo; modern shove is kept", CLASSFLAG_SCOUT);
	ItemDefine("Soda Popper", "sodapop", "Reverted to pre-Smissmas 2013, run to build hype and auto gain minicrits", CLASSFLAG_SCOUT);
	ItemDefine("Solemn Vow", "solemn", "Reverted to pre-gunmettle, firing speed penalty removed", CLASSFLAG_MEDIC);
	ItemDefine("Splendid Screen", "splendid", "Reverted to pre-toughbreak, 15% blast resist, no faster recharge, old shield mechanics, bash dmg at any range", CLASSFLAG_DEMOMAN);
	ItemDefine("Spy-cicle", "spycicle", "Reverted to pre-gunmettle, fire immunity for 2s, silent killer, cannot regenerate from ammo sources", CLASSFLAG_SPY);
	ItemDefine("Sticky Jumper", "stkjumper", "Reverted to Pyromania update, can have 8 stickybombs out at once again", CLASSFLAG_DEMOMAN);
	ItemDefine("Sydney Sleeper", "sleeper", "Reverted to pre-2018, restored jarate explosion, no headshots", CLASSFLAG_SNIPER);
	ItemDefine("Tide Turner", "turner", "Reverted to pre-toughbreak, can deal full crits, 25% blast and fire resist, crit after bash, no debuff removal", CLASSFLAG_DEMOMAN);
	ItemDefine("Tomislav", "tomislav", "Reverted to pre-pyromania, 40% faster spinup, no accuracy bonus, no barrel spin sound, 20% slower firing speed", CLASSFLAG_HEAVY);	
	ItemDefine("Tribalman's Shiv", "tribalshiv", "Reverted to release, 8 second bleed, 35% damage penalty", CLASSFLAG_SNIPER);
	ItemDefine("Ullapool Caber", "caber", "Reverted to pre-gunmettle, always deals 175+ damage on melee explosion", CLASSFLAG_DEMOMAN);
	ItemDefine("Vita-Saw", "vitasaw", "Reverted to pre-inferno, always preserves up to 20% uber on death", CLASSFLAG_MEDIC);
	ItemDefine("Warrior's Spirit", "warrior", "Reverted to pre-tough break, heals 10 on hit, no damage vuln, -20 max health", CLASSFLAG_HEAVY);
#if defined VERDIUS_PATCHES
	ItemDefine("Wrangler", "wrangler", "Reverted to pre-gunmettle (shieldvalues only), fully repair and refill while shield is up", CLASSFLAG_ENGINEER);
#endif
	ItemDefine("Your Eternal Reward", "eternal", "Reverted to pre-inferno, cannot disguise, no cloak drain penalty", CLASSFLAG_SPY);

	menu_main = CreateMenu(MenuHandler_Main, (MenuAction_Select));
	SetMenuTitle(menu_main, "Weapon Reverts");
	SetMenuPagination(menu_main, MENU_NO_PAGINATION);
	SetMenuExitButton(menu_main, true);
	AddMenuItem(menu_main, "classinfo", "Show reverts for your current class");
	AddMenuItem(menu_main, "info", "Show information about each revert");

	ItemFinalize();

	AutoExecConfig(false, "reverts", "sourcemod");

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
	cvar_ref_tf_scout_hype_mod = FindConVar("tf_scout_hype_mod");

	RegConsoleCmd("sm_revert", Command_Menu, (PLUGIN_NAME ... " - Open reverts menu"), 0);
	RegConsoleCmd("sm_reverts", Command_Menu, (PLUGIN_NAME ... " - Open reverts menu"), 0);
	RegConsoleCmd("sm_revertinfo", Command_Info, (PLUGIN_NAME ... " - Show reverts info in console"), 0);
	RegConsoleCmd("sm_revertsinfo", Command_Info, (PLUGIN_NAME ... " - Show reverts info in console"), 0);
	RegConsoleCmd("sm_classrevert", Command_ClassInfo, (PLUGIN_NAME ... " - Show reverts for the current class"), 0);
	RegConsoleCmd("sm_classreverts", Command_ClassInfo, (PLUGIN_NAME ... " - Show reverts for the current class"), 0);

	HookEvent("player_spawn", OnGameEvent, EventHookMode_Post);
	HookEvent("player_death", OnGameEvent, EventHookMode_Pre);
	HookEvent("post_inventory_application", OnGameEvent, EventHookMode_Post);
	HookEvent("item_pickup", OnGameEvent, EventHookMode_Post);
#if defined VERDIUS_PATCHES
	HookEvent("server_cvar", OnServerCvarChanged, EventHookMode_Pre);
#endif

	AddNormalSoundHook(OnSoundNormal);

	{
		conf = LoadGameConfigFile("reverts");

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

		dhook_CTFWeaponBase_PrimaryAttack = DHookCreateFromConf(conf, "CTFWeaponBase::PrimaryAttack");
		dhook_CTFWeaponBase_SecondaryAttack = DHookCreateFromConf(conf, "CTFWeaponBase::SecondaryAttack");
		dhook_CTFBaseRocket_GetRadius = DHookCreateFromConf(conf, "CTFBaseRocket::GetRadius");
		dhook_CTFPlayer_CanDisguise = DHookCreateFromConf(conf, "CTFPlayer::CanDisguise");
		dhook_CTFPlayer_CalculateMaxSpeed = DHookCreateFromConf(conf, "CTFPlayer::TeamFortress_CalculateMaxSpeed");
		dhook_CTFPlayer_AddToSpyKnife = DHookCreateFromConf(conf, "CTFPlayer::AddToSpyKnife");
		dhook_CAmmoPack_MyTouch = DHookCreateFromConf(conf, "CAmmoPack::MyTouch");
		dhook_CTFAmmoPack_PackTouch =  DHookCreateFromConf(conf, "CTFAmmoPack::PackTouch");

		delete conf;
	}

#if defined VERDIUS_PATCHES
	{
		conf = LoadGameConfigFile("verdiusarcana_reverts");

		if (conf == null) SetFailState("Failed to load Verdius conf");

		Verdius_RevertDisciplinaryAction = 
			MemoryPatch.CreateFromConf(conf,
			"CTFWeaponBaseMelee::OnSwingHit_2fTO3fOnAllySpeedBuff");
#if defined WINDOWS32
		// If on Windows, perform the Address of Natives so we can patch in the address for the Discilpinary Action Ally Speedbuff.
		AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer = GetAddressOfCell(g_flNewDiscilplinaryAllySpeedBuffTimer);
#endif
#if defined WINDOWS32
		// Dragons fury need only one MemoryPatch on Windows.

			Verdius_RevertTraceReqDragonsFury_NOP_JZ = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_NOP_JZ");
#else
		Verdius_RevertTraceReqDragonsFury_JA = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_JA");
		Verdius_RevertTraceReqDragonsFury_JNZ = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_JNZ");
		Verdius_RevertTraceReqDragonsFury_JZ = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_JZ");
		Verdius_RevertTraceReqDragonsFury_JNZ2 = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_JNZ_Second");
		Verdius_RevertTraceReqDragonsFury_FinalJNZ = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFProjectile_BallOfFire::Burn_CenterTraceReqForBonus_FinalJNZ");
#endif		
		Verdius_RevertFirstSecondDamageLossOnMiniguns = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFMinigun::GetProjectileDamage_JumpOverCheck");
		Verdius_RevertFirstSecondAccuracyLossOnMiniguns = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFMinigun::GetWeaponSpread_JumpOverCheck");
		Verdius_RevertWranglerShieldHealNerfOnWrenches = 
			MemoryPatch.CreateFromConf(conf, 
			"CObjectSentrygun::OnWrenchHit_ShieldHealRevert");
		Verdius_RevertWranglerShieldShellRefillNerfOnWrenches = 
			MemoryPatch.CreateFromConf(conf, 
			"CObjectSentrygun::OnWrenchHit_ShieldShellRefillRevert");
		Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches = 
			MemoryPatch.CreateFromConf(conf, 
			"CObjectSentrygun::OnWrenchHit_ShieldRocketRefillRevert");
		Verdius_RevertCozyCamperFlinch = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFPlayer::ApplyPunchImpulseX_FakeThirdALtoBeTrue");
		Verdius_RevertQuickFixUberCannotCapturePoint = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFGameRules::PlayerMayCapturePoint_QuickFixUberCannotCaptureRevert");
		Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOVSS_AddrTo_400");
		Verdius_RevertDalokohsBar_MOV_400 = 
			MemoryPatch.CreateFromConf(conf, 
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOV_400");			

    	StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CBaseMultiplayerPlayer::AwardAchievement");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
		sdkcall_AwardAchievement = EndPrepSDKCall();

		dHooks_CTFProjectile_Arrow_BuildingHealingArrow = DHookCreateFromConf(conf, "CTFProjectile_Arrow::BuildingHealingArrow");

		DHookEnableDetour(dHooks_CTFProjectile_Arrow_BuildingHealingArrow, false, PreHealingBoltImpact);
		DHookEnableDetour(dHooks_CTFProjectile_Arrow_BuildingHealingArrow, true, PostHealingBoltImpact);

		if (sdkcall_AwardAchievement == null) SetFailState("Failed to create sdkcall_AwardAchievement");
		if (!ValidateAndNullCheck(Verdius_RevertDisciplinaryAction)) SetFailState("Failed to create Verdius_RevertDisciplinaryAction");
		
		// Because we use only one MemoryPatch for Windows, we need to make sure we only try to Validate and Nullcheck one MemoryPatch.
#if defined WINDOWS32
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_NOP_JZ)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_NOP_JZ");
#else
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_JA)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_JA");
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_JNZ)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_JNZ");
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_JZ)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_JZ");
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_JNZ2)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_JNZ2");
			if (!ValidateAndNullCheck(Verdius_RevertTraceReqDragonsFury_FinalJNZ)) SetFailState("Failed to create Verdius_RevertTraceReqDragonsFury_FinalJNZ");
#endif

		if (!ValidateAndNullCheck(Verdius_RevertFirstSecondDamageLossOnMiniguns)) SetFailState("Failed to create Verdius_RevertFirstSecondDamageLossOnMiniguns");
		if (!ValidateAndNullCheck(Verdius_RevertFirstSecondAccuracyLossOnMiniguns)) SetFailState("Failed to create Verdius_RevertFirstSecondAccuracyLossOnMiniguns");
		if (!ValidateAndNullCheck(Verdius_RevertWranglerShieldHealNerfOnWrenches)) SetFailState("Failed to create Verdius_RevertWranglerShieldHealNerfOnWrenches");
		if (!ValidateAndNullCheck(Verdius_RevertWranglerShieldShellRefillNerfOnWrenches)) SetFailState("Failed to create Verdius_RevertWranglerShieldShellRefillNerfOnWrenches");
		if (!ValidateAndNullCheck(Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches)) SetFailState("Failed to create Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches");
		if (!ValidateAndNullCheck(Verdius_RevertCozyCamperFlinch)) SetFailState("Failed to create Verdius_RevertCozyCamperFlinch");
		if (!ValidateAndNullCheck(Verdius_RevertQuickFixUberCannotCapturePoint)) SetFailState("Failed to create Verdius_RevertQuickFixUberCannotCapturePoint");
		if (!ValidateAndNullCheck(Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat)) SetFailState("Failed to create Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat");
		if (!ValidateAndNullCheck(Verdius_RevertDalokohsBar_MOV_400)) SetFailState("Failed to create Verdius_RevertDalokohsBar_MOV_400");
		AddressOf_g_flDalokohsBarCanOverHealTo = GetAddressOfCell(g_flDalokohsBarCanOverHealTo);


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
	if (dhook_CTFWeaponBase_PrimaryAttack == null) SetFailState("Failed to create dhook_CTFWeaponBase_PrimaryAttack");
	if (dhook_CTFWeaponBase_SecondaryAttack == null) SetFailState("Failed to create dhook_CTFWeaponBase_SecondaryAttack");
	if (dhook_CTFBaseRocket_GetRadius == null) SetFailState("Failed to create dhook_CTFBaseRocket_GetRadius");
	if (dhook_CTFPlayer_CanDisguise == null) SetFailState("Failed to create dhook_CTFPlayer_CanDisguise");
	if (dhook_CTFPlayer_CalculateMaxSpeed == null) SetFailState("Failed to create dhook_CTFPlayer_CalculateMaxSpeed");
	if (dhook_CTFPlayer_AddToSpyKnife == null) SetFailState("Failed to create dhook_CTFPlayer_AddToSpyKnife");
  	if (dhook_CAmmoPack_MyTouch == null) SetFailState("Failed to create dhook_CAmmoPack_MyTouch");
	if (dhook_CTFAmmoPack_PackTouch == null) SetFailState("Failed to create dhook_CTFAmmoPack_PackTouch");

	DHookEnableDetour(dhook_CTFPlayer_CanDisguise, true, DHookCallback_CTFPlayer_CanDisguise);
	DHookEnableDetour(dhook_CTFPlayer_CalculateMaxSpeed, true, DHookCallback_CTFPlayer_CalculateMaxSpeed);
  	DHookEnableDetour(dhook_CTFPlayer_AddToSpyKnife, false, DHookCallback_CTFPlayer_AddToSpyKnife);
	DHookEnableDetour(dhook_CTFAmmoPack_PackTouch, false, DHookCallback_CTFAmmoPack_PackTouch);

	for (idx = 1; idx <= MaxClients; idx++) {
		if (IsClientConnected(idx)) OnClientConnected(idx);
		if (IsClientInGame(idx)) OnClientPutInServer(idx);
	}
}

public void JumperFlagRunCvarChange(Handle convar, const char[] oldValue, const char[] newValue) {
	UpdateJumperDescription();
}

void UpdateJumperDescription() {
	for (int i = 0; i < ITEMS_MAX; i++) {
		if (StrEqual(items[i].key, "rocketjmp") || StrEqual(items[i].key, "stkjumper")) {
			char intelMsg[] = ", wearer can pick up intel";
			if (GetConVarBool(cvar_jumper_flag_run)) {
				if (StrContains(items[i].desc, intelMsg) == -1) {
					Format(items[i].desc, sizeof(items[].desc), "%s%s", items[i].desc, intelMsg);
				}
			} else {
				ReplaceString(items[i].desc, sizeof(items[].desc), intelMsg, "");
			}
		}
	}
}

public void OnConfigsExecuted() {
#if defined VERDIUS_PATCHES
	VerdiusTogglePatches(ItemIsEnabled("disciplinary"),"disciplinary");
	VerdiusTogglePatches(ItemIsEnabled("dragonfury"),"dragonfury");
	VerdiusTogglePatches(ItemIsEnabled("miniramp"),"miniramp");
	VerdiusTogglePatches(ItemIsEnabled("wrangler"),"wrangler");
	VerdiusTogglePatches(ItemIsEnabled("cozycamper"),"cozycamper");
	VerdiusTogglePatches(ItemIsEnabled("quickfix"),"quickfix");
	VerdiusTogglePatches(ItemIsEnabled("dalokohsbar"),"dalokohsbar");
#endif
	UpdateJumperDescription();
}

#if defined VERDIUS_PATCHES
bool ValidateAndNullCheck(MemoryPatch patch) {
	return (patch.Validate() && patch != null);
}

Action OnServerCvarChanged(Event event, const char[] name, bool dontBroadcast)
{
    char cvarName[128];
    event.GetString("cvarname", cvarName, sizeof(cvarName));
    if (StrContains(cvarName, "sm_reverts__item_") != -1)
    {
    	char item[64];
		strcopy(item,sizeof(item),cvarName[strlen("sm_reverts__item_")]);
		VerdiusTogglePatches(ItemIsEnabled(item),item);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void VerdiusTogglePatches(bool enable, char[] name) {
	if (StrEqual(name,"disciplinary")){
		if (enable) {			
#if defined WINDOWS32
				Verdius_RevertDisciplinaryAction.Enable();
				// The Windows port of Disciplinary Action Revert requires a extra step.
				StoreToAddress(Verdius_RevertDisciplinaryAction.Address + view_as<Address>(0x02), view_as<int>(AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer), NumberType_Int32);
#else
				Verdius_RevertDisciplinaryAction.Enable();
#endif
		} else {
			Verdius_RevertDisciplinaryAction.Disable();
		}
	}
	else if (StrEqual(name,"dragonfury")){
		if (enable) {
#if defined WINDOWS32
				Verdius_RevertTraceReqDragonsFury_NOP_JZ.Enable();
#else
				Verdius_RevertTraceReqDragonsFury_JA.Enable();
				Verdius_RevertTraceReqDragonsFury_JZ.Enable();
				Verdius_RevertTraceReqDragonsFury_JNZ.Enable();
				Verdius_RevertTraceReqDragonsFury_JNZ2.Enable();
				Verdius_RevertTraceReqDragonsFury_FinalJNZ.Enable();
#endif			
		} else {
#if defined WINDOWS32
				Verdius_RevertTraceReqDragonsFury_NOP_JZ.Disable();
#else
				Verdius_RevertTraceReqDragonsFury_JA.Disable();
				Verdius_RevertTraceReqDragonsFury_JZ.Disable();
				Verdius_RevertTraceReqDragonsFury_JNZ.Disable();
				Verdius_RevertTraceReqDragonsFury_JNZ2.Disable();
				Verdius_RevertTraceReqDragonsFury_FinalJNZ.Disable();
#endif		
		}
	}
	else if (StrEqual(name,"miniramp")){
		if (enable) {
			Verdius_RevertFirstSecondDamageLossOnMiniguns.Enable();
			Verdius_RevertFirstSecondAccuracyLossOnMiniguns.Enable();
		} else {
			Verdius_RevertFirstSecondDamageLossOnMiniguns.Disable();
			Verdius_RevertFirstSecondAccuracyLossOnMiniguns.Disable();
		}
	}
	else if (StrEqual(name,"wrangler")){
		if (enable) {
			Verdius_RevertWranglerShieldHealNerfOnWrenches.Enable();
			Verdius_RevertWranglerShieldShellRefillNerfOnWrenches.Enable();
			Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches.Enable();
		} else {
			Verdius_RevertWranglerShieldHealNerfOnWrenches.Disable();
			Verdius_RevertWranglerShieldShellRefillNerfOnWrenches.Disable();
			Verdius_RevertWranglerShieldRocketRefillNerfOnWrenches.Disable();
		}
	}
	else if (StrEqual(name,"cozycamper")){
		if (enable) {
			Verdius_RevertCozyCamperFlinch.Enable();
		} else {
			Verdius_RevertCozyCamperFlinch.Disable();
		}
	}
	else if (StrEqual(name,"quickfix")){
		if (enable) {
			Verdius_RevertQuickFixUberCannotCapturePoint.Enable();
		} else {
			Verdius_RevertQuickFixUberCannotCapturePoint.Disable();
		}
	}
	else if (StrEqual(name,"dalokohsbar")){
		if (enable) {
			Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat.Enable();
			Verdius_RevertDalokohsBar_MOV_400.Enable();

			// Due to it being a MOVSS instruction that needs
			// a Address instead of values, there's some extra steps to be done in here:
			StoreToAddress(Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat.Address + view_as<Address>(0x04), view_as<int>(AddressOf_g_flDalokohsBarCanOverHealTo), NumberType_Int32);
		} else {
			Verdius_RevertDalokohsBar_MOVSS_ChangeAddressTo_CustomDalokohsHPFloat.Disable();
			Verdius_RevertDalokohsBar_MOV_400.Disable();
		}
	}		
}
#endif

public void OnMapStart() {
	PrecacheSound("misc/banana_slip.wav");
	PrecacheSound("items/gunpickup2.wav");
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
	int ent;
	float timer;
	float pos1[3];
	float pos2[3];
	float maxs[3];
	float mins[3];
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

					if (players[idx].respawn > 0) {
						if ((players[idx].respawn + 2) == GetGameTickCount()) {
							TF2_RespawnPlayer(idx);
							players[idx].respawn = 0;

							PrintToChat(idx, "[SM] Revert changes have been applied");
						}

						continue;
					}
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
								if (ItemIsEnabled("atomizer")) {
									airdash_limit_new = 2;
								} else {
									if (weapon == GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon")) {
										airdash_limit_old = 2;
										airdash_limit_new = 2;
									}
								}
							}
						}

						if (TF2_IsPlayerInCondition(idx, TFCond_CritHype)) {
							airdash_limit_old = 5;

							if (ItemIsEnabled("sodapop") == false) {
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
								players[idx].scout_airdash_count == 2 &&
								ItemIsEnabled("atomizer")
							) {
								// atomizer global jump
								SDKHooks_TakeDamage(idx, idx, idx, 10.0, (DMG_BULLET|DMG_PREVENT_PHYSICS_FORCE), -1, NULL_VECTOR, NULL_VECTOR);

								if (airdash_limit_new > airdash_limit_old) {
									// only play sound if the game doesn't play it
									EmitSoundToAll("misc/banana_slip.wav", idx, SNDCHAN_AUTO, 30, (SND_CHANGEVOL|SND_CHANGEPITCH), 1.0, 100);
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
						// shortstop shove

						if (ItemIsEnabled("shortstop")) {
							weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_handgun_scout_primary")) {
									// Shortstop shove leftover code from Bakugo
									// disable secondary attack
									// this is somewhat broken, can still shove by holding m2 when reload ends
									// SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", (GetGameTime() + 1.0));
								}
							}
						}
					}

					{
						// guillotine recharge

						if (ItemIsEnabled("guillotine")) {
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

						if (ItemIsEnabled("sodapop"))
						{
							if (players[idx].is_under_hype)
							{
								// allow mini-crit buff to last indefinitely
								SetEntPropFloat(idx, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
							}

							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

							weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (
									StrEqual(class, "tf_weapon_soda_popper") &&
									players[idx].is_under_hype == false &&
									TF2_IsPlayerInCondition(idx, TFCond_CritHype) == false
								) {
									if (GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter") >= 100.0) {
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
										hype = (hype / GetConVarFloat(cvar_ref_tf_scout_hype_mod));
										hype = (hype + GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter"));
										hype = (hype > 100.0 ? 100.0 : hype);

										SetEntPropFloat(idx, Prop_Send, "m_flHypeMeter", hype);
									}
								}

								// hype meter drain on minicrit condition
								if (players[idx].is_under_hype) {
									hype = GetEntPropFloat(idx, Prop_Send, "m_flHypeMeter");
									
									if (hype <= 0.0)
									{
										players[idx].is_under_hype = false;
										TF2_RemoveCondition(idx, TFCond_CritCola);
									}
									else
									{
										hype -= 9.375 * GetTickInterval(); // m_fEnergyDrinkConsumeRate*0.75f
										SetEntPropFloat(idx, Prop_Send, "m_flHypeMeter", hype);
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
									ItemIsEnabled("beggars") &&
									players[idx].beggars_ammo == 3 &&
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
						// sleeper teammate extinguish

						// shots are detected via ammo change, again pretty hacky
						// no lagcomp so a decently large hull trace is used instead

						weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

						if (weapon > 0) {
							GetEntityClassname(weapon, class, sizeof(class));

							if (
								StrEqual(class, "tf_weapon_sniperrifle") &&
								GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 230
							) {
								ammo = GetEntProp(idx, Prop_Send, "m_iAmmo", 4, 1);

								if (
									ItemIsEnabled("sleeper") &&
									ammo == (players[idx].sleeper_ammo - 1)
								) {
									GetClientEyePosition(idx, pos1);

									GetClientEyeAngles(idx, pos2);
									GetAngleVectors(pos2, pos2, NULL_VECTOR, NULL_VECTOR);
									ScaleVector(pos2, 10000.0);
									AddVectors(pos1, pos2, pos2);

									maxs[0] = 20.0;
									maxs[1] = 20.0;
									maxs[2] = 5.0;

									mins[0] = (0.0 - maxs[0]);
									mins[1] = (0.0 - maxs[1]);
									mins[2] = (0.0 - maxs[2]);

									TR_TraceHullFilter(pos1, pos2, mins, maxs, MASK_SOLID, TraceFilter_ExcludeSingle, idx);

									if (TR_DidHit()) {
										ent = TR_GetEntityIndex();

										if (
											ent >= 1 &&
											ent <= MaxClients &&
											GetClientTeam(ent) == GetClientTeam(idx) &&
											TF2_IsPlayerInCondition(ent, TFCond_OnFire)
										) {
											// this will remove fire and play the appropriate sound
											AcceptEntityInput(ent, "ExtinguishPlayer");
										}
									}
								}

								players[idx].sleeper_ammo = ammo;
							}
						}
					}
				}

				if (TF2_GetPlayerClass(idx) == TFClass_Spy) {
					{
						// dead ringer cloak meter mechanics

						if (players[idx].spy_is_feigning == false) {
							if (TF2_IsPlayerInCondition(idx, TFCond_DeadRingered)) {
								players[idx].spy_is_feigning = true;
							}
						} else {
							if (
								TF2_IsPlayerInCondition(idx, TFCond_Cloaked) == false &&
								TF2_IsPlayerInCondition(idx, TFCond_DeadRingered) == false
							) {
								players[idx].spy_is_feigning = false;

								if (ItemIsEnabled("ringer")) {
									// when uncloaking, cloak is drained to 40%

									if (GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter") > 40.0) {
										SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", 40.0);
									}
								}
							}
						}

						cloak = GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter");

						if (ItemIsEnabled("ringer")) {
							if (
								(cloak - players[idx].spy_cloak_meter) > 35.0 &&
								(players[idx].ammo_grab_frame + 1) == GetGameTickCount()
							) {
								weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Building);

								if (weapon > 0) {
									GetEntityClassname(weapon, class, sizeof(class));

									if (
										StrEqual(class, "tf_weapon_invis") &&
										GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 59
									) {
										// ammo boxes only give 35% cloak max

										cloak = (players[idx].spy_cloak_meter + 35.0);
										SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", cloak);
									}
								}
							}
						}

						players[idx].spy_cloak_meter = cloak;
					}

					{
						// deadringer cancel condition when feign buff ends
						if (
							ItemIsEnabled("ringer") &&
							players[idx].spy_is_feigning &&
							GetFeignBuffsEnd(idx) < GetGameTickCount() &&
							TF2_IsPlayerInCondition(idx, TFCond_DeadRingered)
						) {
							TF2_RemoveCondition(idx, TFCond_DeadRingered);
						}
					}

					{
						// spycicle recharge

						if (ItemIsEnabled("spycicle")) {
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
				}

				if (
					TF2_GetPlayerClass(idx) == TFClass_Soldier ||
					TF2_GetPlayerClass(idx) == TFClass_DemoMan
				) {
					{
						// zatoichi honorbound

						if (ItemIsEnabled("zatoichi")) {
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

					{
						// parachute redeploy & updraft

						if (TF2_IsPlayerInCondition(idx, TFCond_Parachute)) {
							players[idx].parachute_cond_time = GetGameTime();

							if (
								ItemIsEnabled("basejump") &&
								TF2_IsPlayerInCondition(idx, TFCond_OnFire) &&
								GetEntProp(idx, Prop_Data, "m_nWaterLevel") == 0
							) {
								GetEntPropVector(idx, Prop_Data, "m_vecVelocity", pos1);

								if (pos1[2] < GetConVarFloat(cvar_ref_tf_parachute_maxspeed_onfire_z)) {
									pos1[2] = GetConVarFloat(cvar_ref_tf_parachute_maxspeed_onfire_z);

									// don't use TeleportEntity to avoid the trigger re-entry bug
									SetEntPropVector(idx, Prop_Data, "m_vecAbsVelocity", pos1);
								}
							}
						} else {
							if (
								TF2_IsPlayerInCondition(idx, TFCond_ParachuteDeployed) &&
								(GetGameTime() - players[idx].parachute_cond_time) > 0.2 &&
								ItemIsEnabled("basejump")
							) {
								// this cond is what stops redeploy
								// tf_parachute_deploy_toggle_allowed can also be used
								TF2_RemoveCondition(idx, TFCond_ParachuteDeployed);
							}
						}
					}
				}
			} else {
				// reset if player is dead
				players[idx].spy_is_feigning = false;
				players[idx].scout_airdash_value = 0;
				players[idx].scout_airdash_count = 0;
				players[idx].is_under_hype = false;
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

			// weapon pickups are disabled to ensure attribute consistency
			SetConVarMaybe(cvar_ref_tf_dropped_weapon_lifetime, "0", GetConVarBool(cvar_enable));

			// these cvars are changed just-in-time, reset them
			SetConVarReset(cvar_ref_tf_airblast_cray);
			SetConVarReset(cvar_ref_tf_feign_death_duration);
			SetConVarReset(cvar_ref_tf_feign_death_speed_duration);
			SetConVarReset(cvar_ref_tf_feign_death_activate_damage_scale);
			SetConVarReset(cvar_ref_tf_feign_death_damage_scale);

			// these cvars are global, set them to the desired value
			SetConVarMaybe(cvar_ref_tf_bison_tick_time, "0.001", ItemIsEnabled("bison"));
			SetConVarMaybe(cvar_ref_tf_fireball_radius, "30.0", ItemIsEnabled("dragonfury"));
			SetConVarMaybe(cvar_ref_tf_parachute_aircontrol, "5", ItemIsEnabled("basejump"));
			// By setting tf_parachute_maxspeed_onfire_z = 10.0, fire updraft is back again. Valve set this to -100 for some reason by default.
			SetConVarMaybe(cvar_ref_tf_parachute_maxspeed_onfire_z, "10.0", ItemIsEnabled("basejump"));	
		}
	}
}

public void OnClientConnected(int client) {

	// apply item picks
	ItemPlayerApply(client);
	players[client].change = IsClientInGame(client);

	// reset these per player
	players[client].respawn = 0;
	players[client].resupply_time = 0.0;
	players[client].medic_medigun_defidx = 0;
	players[client].medic_medigun_charge = 0.0;
	players[client].parachute_cond_time = 0.0;
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_TraceAttack, SDKHookCB_TraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDKHookCB_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_OnTakeDamagePost);
}

public void OnEntityCreated(int entity, const char[] class) {
	if (entity < 0 || entity >= 2048) {
		// sourcemod calls this with entrefs for non-networked ents ??
		return;
	}

	entities[entity].exists = true;
	entities[entity].spawn_time = 0.0;
	entities[entity].is_demo_shield = false;

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

	if (StrEqual(class, "tf_projectile_rocket")) {
		// keep track of when rockets are created

		rocket_create_entity = entity;
		rocket_create_frame = GetGameTickCount();

		DHookEntity(dhook_CTFBaseRocket_GetRadius, true, entity, _, DHookCallback_CTFBaseRocket_GetRadius);
	}

	if (
		StrEqual(class, "tf_weapon_flamethrower") ||
		StrEqual(class, "tf_weapon_rocketlauncher_fireball")
	) {
		DHookEntity(dhook_CTFWeaponBase_SecondaryAttack, false, entity, _, DHookCallback_CTFWeaponBase_SecondaryAttack);
	}

	if (StrEqual(class, "tf_weapon_mechanical_arm")) {
		DHookEntity(dhook_CTFWeaponBase_PrimaryAttack, false, entity, _, DHookCallback_CTFWeaponBase_PrimaryAttack);
		DHookEntity(dhook_CTFWeaponBase_SecondaryAttack, false, entity, _, DHookCallback_CTFWeaponBase_SecondaryAttack);
	}
	if (StrContains(class, "item_ammopack") == 0)
	{
		DHookEntity(dhook_CAmmoPack_MyTouch, false, entity, _, DHookCallback_CAmmoPack_MyTouch);
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

	// this function is called on a per-frame basis
	// if two conds are added within the same game frame,
	// they will both be present when this is called for each

	{
		// bonk cancel stun

		if (
			ItemIsEnabled("bonk") &&
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
			ItemIsEnabled("sodapop") &&
			condition == TFCond_CritHype &&
			(player_weapons[client][Wep_Bonk] || player_weapons[client][Wep_CritCola]) == false
		) {
			TF2_RemoveCondition(client, TFCond_CritHype);
		}
	}

	{
		// dead ringer stuff

		if (
			ItemIsEnabled("ringer") &&
			TF2_GetPlayerClass(client) == TFClass_Spy
		) {
			if (condition == TFCond_DeadRingered) {
				cloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter");

				if (
					cloak > 49.0 &&
					cloak < 51.0
				) {
					// undo 50% drain on activated
					SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 100.0);
				}
			}

			if (TF2_IsPlayerInCondition(client, TFCond_DeadRingered)) {
				
				if (
					condition == TFCond_AfterburnImmune &&
					TF2_IsPlayerInCondition(client, TFCond_FireImmune) == false // didn't use spycicle
				) {
					// grant aferburn immunity for a bit

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
			ItemIsEnabled("spycicle") &&
			TF2_GetPlayerClass(client) == TFClass_Spy &&
			condition == TFCond_FireImmune &&
			TF2_IsPlayerInCondition(client, TFCond_AfterburnImmune)
		) {
			TF2_RemoveCondition(client, TFCond_FireImmune);
			TF2_RemoveCondition(client, TFCond_AfterburnImmune);

			TF2_AddCondition(client, TFCond_FireImmune, 2.0, 0);
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	{
		// if player is under minicrits but the cond was removed (e.g. via resupply), re-add it
		if (
			ItemIsEnabled("sodapop") &&
			condition == TFCond_CritCola &&
			players[client].is_under_hype == true &&
			TF2_GetPlayerClass(client) == TFClass_Scout
		) {
			TF2_AddCondition(client, TFCond_CritCola, 11.0, 0);
		}
	}
}

public Action TF2_OnAddCond(int client, TFCond &condition, float &time, int &provider) {
	{
		// prevent speed boost being applied on feign death
		if (
			ItemIsEnabled("ringer") &&
			condition == TFCond_SpeedBuffAlly &&
			TF2_GetPlayerClass(client) == TFClass_Spy &&
			players[client].ticks_since_feign_ready == GetGameTickCount()
		) {
			return Plugin_Handled;
		}
	}
	{
		// save charge tick (for preventing debuff removal)
		if (condition == TFCond_Charging) {
			players[client].charge_tick = GetGameTickCount();
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action TF2_OnRemoveCond(int client, TFCond &condition, float &timeleft, int &provider) {
	{
		// prevent debuff removal for shields
		if (
			((ItemIsEnabled("targe") && player_weapons[client][Wep_CharginTarge]) ||
			 (ItemIsEnabled("splendid") && player_weapons[client][Wep_SplendidScreen]) ||
			 (ItemIsEnabled("turner") && player_weapons[client][Wep_TideTurner])) &&
			players[client].charge_tick == GetGameTickCount()
		) {
			for (int i = 0; i < sizeof(debuffs); ++i)
			{
				if (condition == debuffs[i])
					return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] class, int index, Handle& item) {
	Handle item1;

	if (
		ItemIsEnabled("ambassador") &&
		StrEqual(class, "tf_weapon_revolver") &&
		(index == 61 || index == 1006)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 868, 0.0); // crit dmg falloff
	}

	else if (
		ItemIsEnabled("atomizer") &&
		StrEqual(class, "tf_weapon_bat") &&
		(index == 450)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 5, 1.30); // fire rate penalty
		TF2Items_SetAttribute(item1, 1, 138, 0.80); // dmg penalty vs players
		TF2Items_SetAttribute(item1, 2, 250, 0.0); // air dash count
		TF2Items_SetAttribute(item1, 3, 773, 1.0); // single wep deploy time increased
	}

	else if (
		ItemIsEnabled("axtinguish") &&
		StrEqual(class, "tf_weapon_fireaxe") &&
		(index == 38 || index == 457 || index == 1000)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 7);
		TF2Items_SetAttribute(item1, 0, 1, 1.00); // damage penalty
		TF2Items_SetAttribute(item1, 1, 15, 0.0); // crit mod disabled
		TF2Items_SetAttribute(item1, 2, 20, 1.0); // crit vs burning players
		TF2Items_SetAttribute(item1, 3, 21, 0.50); // dmg penalty vs nonburning
		TF2Items_SetAttribute(item1, 4, 22, 1.0); // no crit vs nonburning
		TF2Items_SetAttribute(item1, 5, 772, 1.00); // single wep holster time increased
		TF2Items_SetAttribute(item1, 6, 2067, 0.0); // attack minicrits and consumes burning
	}

	else if (
		ItemIsEnabled("babyface") &&
		StrEqual(class, "tf_weapon_pep_brawler_blaster")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 419, 25.0); // hype resets on jump
		TF2Items_SetAttribute(item1, 1, 733, 0.0); // lose hype on take damage
	}

	else if (
		ItemIsEnabled("backburner") &&
		StrEqual(class, "tf_weapon_flamethrower") &&
		(index == 40 || index == 1146 )
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 1, 2, 1.1); // 20% increased damage
	}

	else if (
		ItemIsEnabled("rocketjmp") &&
		StrEqual(class, "tf_weapon_rocketlauncher") &&
		index == 237 &&
		GetConVarBool(cvar_jumper_flag_run)
	) {
		item1 = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 400, 0.0);
	}

	else if (
		ItemIsEnabled("beggars") &&
		StrEqual(class, "tf_weapon_rocketlauncher") &&
		(index == 730)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 100, 1.0); // blast radius decreased
	}

	else if (
		ItemIsEnabled("blackbox") &&
		StrEqual(class, "tf_weapon_rocketlauncher") &&
		(index == 228 || index == 1085)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 741, 0.0); // falloff-based heal
		// heal per hit handled elsewhere
	}

	else if (
		ItemIsEnabled("booties") &&
		StrEqual(class, "tf_wearable") &&
		(index == 405 || index == 608)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 107, 1.10); // move speed bonus
		TF2Items_SetAttribute(item1, 1, 788, 1.00); // move speed bonus shield required
	}
	
	else if (
		ItemIsEnabled("brassbeast") &&
		StrEqual(class, "tf_weapon_minigun") &&
		(index == 312)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 738, 1.00); // spunup damage resistance
	}

	else if (
		ItemIsEnabled("bushwacka") &&
		StrEqual(class, "tf_weapon_club") &&
		(index == 232)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 128, 0.0); // provide on active
		TF2Items_SetAttribute(item1, 1, 412, 1.00); // 0% damage vulnerability on wearer
		TF2Items_SetAttribute(item1, 2, 15, 1.0); // random crits enabled
		TF2Items_SetAttribute(item1, 3, 61, 1.20); // 20% fire damage vulnerability on wearer
	}

	else if (
		ItemIsEnabled("caber") &&
		StrEqual(class, "tf_weapon_stickbomb")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 5, 1.00); // fire rate penalty
		TF2Items_SetAttribute(item1, 1, 773, 1.00); // single wep deploy time increased
	}

	else if (
		ItemIsEnabled("cannon") &&
		StrEqual(class, "tf_weapon_cannon")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 103, 1.50); // projectile speed increased
	}

	else if (
		ItemIsEnabled("carbine") &&
		StrEqual(class, "tf_weapon_charged_smg")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 31, 3.0); // crit on kill
		TF2Items_SetAttribute(item1, 1, 779, 0.0); // minicrit on charge
		TF2Items_SetAttribute(item1, 2, 780, 0.0); // gain charge on hit
		TF2Items_SetAttribute(item1, 3, 5, 1.35); // 35% firing speed penalty
	}

	else if (
		ItemIsEnabled("claidheamh") &&
		StrEqual(class, "tf_weapon_sword") &&
		(index == 327)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		bool swords = ItemIsEnabled("swords");
		TF2Items_SetNumAttributes(item1, swords ? 5 : 3);
		TF2Items_SetAttribute(item1, 0, 412, 1.00); // dmg taken
		TF2Items_SetAttribute(item1, 1, 128, 0.0); // provide on active
		TF2Items_SetAttribute(item1, 2, 125, -15.0); // max health additive penalty
		//sword holster code handled here
		if(swords) {
			TF2Items_SetAttribute(item1, 3, 781, 0.0); // is a sword
			TF2Items_SetAttribute(item1, 4, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
		}
	}

	else if (
		ItemIsEnabled("critcola") &&
		StrEqual(class, "tf_weapon_lunchbox_drink") &&
		(index == 163)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 814, 0.0); // no mark-for-death on attack
		TF2Items_SetAttribute(item1, 1, 798, 1.10); // +10% damage vulnerability while under the effect
	}

	else if (
		ItemIsEnabled("darwin") &&
		StrEqual(class, "tf_wearable") &&
		(index == 231)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 5);
		TF2Items_SetAttribute(item1, 0, 60, 1.0); // +0% fire damage resistance on wearer
		TF2Items_SetAttribute(item1, 1, 527, 0.0); // remove afterburn immunity
		TF2Items_SetAttribute(item1, 2, 26, 25.0); // +25 max health on wearer
		TF2Items_SetAttribute(item1, 3, 66, 0.85); // +15% bullet damage resistance on wearer
		TF2Items_SetAttribute(item1, 4, 65, 1.20); // 20% explosive damage vulnerability on wearer
	}

	else if (
		ItemIsEnabled("degreaser") &&
		StrEqual(class, "tf_weapon_flamethrower") &&
		(index == 215)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 6);
		TF2Items_SetAttribute(item1, 0, 1, 0.90); // damage penalty
		TF2Items_SetAttribute(item1, 1, 72, 0.75); // weapon burn dmg reduced
		TF2Items_SetAttribute(item1, 2, 170, 1.00); // airblast cost increased
		TF2Items_SetAttribute(item1, 3, 178, 0.35); // deploy time decreased
		TF2Items_SetAttribute(item1, 4, 199, 1.00); // switch from wep deploy time decreased
		TF2Items_SetAttribute(item1, 5, 547, 1.00); // single wep deploy time decreased
	}

	else if (
		ItemIsEnabled("enforcer") &&
		StrEqual(class, "tf_weapon_revolver") &&
		(index == 460)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 3);
		TF2Items_SetAttribute(item1, 0, 410, 0.83334); // -16.667% damage bonus while disguised; cancels out the 20% dmg bonus to make it 0% total (1.0/1.2 = 0.833...)
		TF2Items_SetAttribute(item1, 1, 797, 0.0); // dmg pierces resists absorbs
		TF2Items_SetAttribute(item1, 2, 2, 1.20); // 20% damage bonus
		// When the Spy fires while disguised, he gives less damage to both players and buildings.
	}

	else if (
		ItemIsEnabled("equalizer") &&
		StrEqual(class, "tf_weapon_shovel") &&
		(index == 128 || index == 775)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 236, 1.0); // mod weapon blocks healing
		TF2Items_SetAttribute(item1, 1, 414, 0.0); // self mark for death
		TF2Items_SetAttribute(item1, 2, 740, 1.0); // reduced healing from medics

		if (index == 128) {
			TF2Items_SetAttribute(item1, 3, 115, 2.0); // mod shovel damage boost
		} else {
			TF2Items_SetAttribute(item1, 3, 235, 2.0); // mod shovel speed boost
		}
	}

	else if (
		ItemIsEnabled("eternal") &&
		StrEqual(class, "tf_weapon_knife") &&
		(index == 225 || index == 574)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 34, 1.00); // mult cloak meter consume rate
		TF2Items_SetAttribute(item1, 1, 155, 1.00); // cannot disguise
	}

	else if (
		ItemIsEnabled("eviction") &&
		StrEqual(class, "tf_weapon_fists") &&
		(index == 426)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 852, 1.20); // dmg taken increased
		TF2Items_SetAttribute(item1, 1, 855, 0.0); // mod maxhealth drain rate
	}

	else if (
		ItemIsEnabled("fiststeel") &&
		StrEqual(class, "tf_weapon_fists") &&
		(index == 331)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 853, 1.0); // mult patient overheal penalty active
		TF2Items_SetAttribute(item1, 1, 854, 1.0); // mult health fromhealers penalty active
	}

	else if (
		ItemIsEnabled("gardener") &&
		StrEqual(class, "tf_weapon_shovel") &&
		(index == 416)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 5, 1.0); // fire rate penalty
	}

	else if (
		ItemIsEnabled("glovesru") &&
		StrEqual(class, "tf_weapon_fists") &&
		(index == 239 || index == 1084 || index == 1100)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 1, 0.75); // damage penalty
		TF2Items_SetAttribute(item1, 1, 414, 3.0); // self mark for death
		TF2Items_SetAttribute(item1, 2, 772, 1.5); // single wep holster time increased
		TF2Items_SetAttribute(item1, 3, 855, 0.0); // mod maxhealth drain rate
	}

	else if (
		ItemIsEnabled("guillotine") &&
		StrEqual(class, "tf_weapon_cleaver")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 437, 65536.0); // crit vs stunned players
	}

	else if (
		ItemIsEnabled("liberty") &&
		StrEqual(class, "tf_weapon_rocketlauncher") &&
		(index == 414)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 1, 1.00); // damage penalty
		TF2Items_SetAttribute(item1, 1, 3, 0.75); // clip size penalty
		TF2Items_SetAttribute(item1, 2, 4, 1.00); // clip size bonus
		TF2Items_SetAttribute(item1, 3, 135, 1.00); // rocket jump damage reduction
	}

	else if (
		ItemIsEnabled("lochload") &&
		StrEqual(class, "tf_weapon_grenadelauncher") &&
		(index == 308)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 2, 1.20); // damage bonus
		TF2Items_SetAttribute(item1, 1, 137, 1.00); // dmg bonus vs buildings
		// for pre smissmas 2014 loch
		// TF2Items_SetAttribute(item1, 2, 207, 1.25); // self damage
		// TF2Items_SetAttribute(item1, 3, 100, 1.00); // radius penalty
		// TF2Items_SetAttribute(item1, 4, 3, 0.50); // clip size
	}

	else if (
		ItemIsEnabled("natascha") &&
		StrEqual(class, "tf_weapon_minigun") &&
		(index == 41)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 738, 1.00); // spunup damage resistance
	}

	else if (
		ItemIsEnabled("panic") &&
		StrEqual(class, "tf_weapon_shotgun") &&
		(index == 1153)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 13);
		TF2Items_SetAttribute(item1, 1, 1, 1.00); // 0% damage penalty
		TF2Items_SetAttribute(item1, 2, 45, 1.00); // +0% bullets per shot
		TF2Items_SetAttribute(item1, 4, 808, 0.00); // Successive shots become less accurate
		TF2Items_SetAttribute(item1, 5, 809, 0.00); // Fires a wide, fixed shot pattern

		TF2Items_SetAttribute(item1, 6, 97, 0.50); // 50% faster reload time
		TF2Items_SetAttribute(item1, 7, 394, 0.70); // 30% faster firing speed
		TF2Items_SetAttribute(item1, 8, 424, 0.66); // -34% clip size
		TF2Items_SetAttribute(item1, 3, 547, 0.50); // This weapon deploys 50% faster
		TF2Items_SetAttribute(item1, 9, 651, 0.50); // Fire rate increases as health decreases.
		TF2Items_SetAttribute(item1, 10, 708, 1.00); // Hold fire to load up to 4 shells
		TF2Items_SetAttribute(item1, 11, 709, 2.5); // Weapon spread increases as health decreases.
		TF2Items_SetAttribute(item1, 12, 710, 1.00); // Attrib_AutoFiresFullClipNegative
	}

	else if (
		ItemIsEnabled("pocket") &&
		StrEqual(class, "tf_weapon_handgun_scout_secondary") &&
		(index == 773)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 8);
		TF2Items_SetAttribute(item1, 0, 6, 1.0); // fire rate bonus
		TF2Items_SetAttribute(item1, 1, 16, 0.0); // heal on hit
		TF2Items_SetAttribute(item1, 2, 3, 1.0); // clip size
		TF2Items_SetAttribute(item1, 3, 5, 1.25); // fire rate penalty
		TF2Items_SetAttribute(item1, 4, 128, 0.0); // provide on active
		TF2Items_SetAttribute(item1, 5, 26, 15.0); // max health additive bonus
		TF2Items_SetAttribute(item1, 6, 275, 1.0); // cancel falling damage
		TF2Items_SetAttribute(item1, 7, 61, 1.50); // dmg taken from fire increased
	}

	else if (
		ItemIsEnabled("powerjack") &&
		StrEqual(class, "tf_weapon_fireaxe") &&
		(index == 214)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 180, 0.0); // remove +25 hp on kill attribute
		// health bonus with overheal handled elsewhere
	}

	else if (
		ItemIsEnabled("persuader") &&
		StrEqual(class, "tf_weapon_sword") &&
		(index == 404)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		bool swords = ItemIsEnabled("swords");
		TF2Items_SetNumAttributes(item1, swords ? 8 : 6);
		TF2Items_SetAttribute(item1, 0, 77, 1.00); // -0% max primary ammo on wearer  
		TF2Items_SetAttribute(item1, 1, 79, 1.00); // -0% max secondary ammo on wearer 
		TF2Items_SetAttribute(item1, 2, 778, 0.00); // remove "Melee hits refill 20% of your charge meter" attribute
		TF2Items_SetAttribute(item1, 3, 782, 0.0); // remove "Ammo boxes collected also give Charge"
		TF2Items_SetAttribute(item1, 4, 249, 2.00); // +100% increase in charge recharge rate, shields should take around 6 seconds to charge with persuader
		TF2Items_SetAttribute(item1, 5, 258, 1.0); // Ammo collected from ammo boxes becomes health (doesn't work, using two DHooks instead)
		if(swords) {
			TF2Items_SetAttribute(item1, 6, 781, 0.0); // is a sword
			TF2Items_SetAttribute(item1, 7, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
		}		
	}

	else if (
		ItemIsEnabled("razorback") &&
		StrEqual(class, "tf_wearable_razorback")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 800, 1.0); //overheal penalty
		TF2Items_SetAttribute(item1, 1, 874, 10000.0); //shield regen time. big number so it never respawns 
	}

	else if (
	ItemIsEnabled("quickfix") &&
	StrEqual(class, "tf_weapon_medigun") &&
	(index == 411)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 10, 1.25); // +25% ÜberCharge rate
	}

#if defined VERDIUS_PATCHES
	else if (
		ItemIsEnabled("rescueranger") &&
		StrEqual(class, "tf_weapon_shotgun_building_rescue")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 469, 130.0); //ranged pickup metal cost
	}
#endif
	else if (
		ItemIsEnabled("ringer") &&
		StrEqual(class, "tf_weapon_invis") &&
		(index == 59)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 5);
		TF2Items_SetAttribute(item1, 0, 35, 1.8); // mult cloak meter regen rate
		TF2Items_SetAttribute(item1, 1, 82, 1.6); // cloak consume rate increased
		TF2Items_SetAttribute(item1, 2, 83, 1.0); // cloak consume rate decreased
		TF2Items_SetAttribute(item1, 3, 726, 1.0); // cloak consume on feign death activate
		TF2Items_SetAttribute(item1, 4, 810, 0.0); // mod cloak no regen from items
	}

	else if (
		ItemIsEnabled("sandman") &&
		StrEqual(class, "tf_weapon_bat_wood") &&
		(index == 44)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 278, 1.50); //effect bar recharge rate increased attribute; this number increases ball recharge time from 10s to 15s
	}

	else if (
		ItemIsEnabled("scottish") &&
		StrEqual(class, "tf_weapon_pipebomblauncher") &&
		(index == 130)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 6, 1.0); // fire rate bonus
		TF2Items_SetAttribute(item1, 1, 120, 0.4); // sticky arm time penalty
	}

	else if (
		ItemIsEnabled("shortstop") &&
		StrEqual(class, "tf_weapon_handgun_scout_primary")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 5);
		TF2Items_SetAttribute(item1, 0, 241, 1.0); // reload time increased hidden
		TF2Items_SetAttribute(item1, 1, 534, 1.00); // airblast vulnerability multiplier hidden
		TF2Items_SetAttribute(item1, 2, 535, 1.00); // damage force increase hidden
		TF2Items_SetAttribute(item1, 3, 536, 1.00); // damage force increase text
		TF2Items_SetAttribute(item1, 4, 76, 1.125); // 12.5% max primary ammo on wearer, reverts max ammo back to 36, required for ammo sharing to work
	}

	else if (
		ItemIsEnabled("sleeper") &&
		StrEqual(class, "tf_weapon_sniperrifle") &&
		(index == 230)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 42, 0.0); // sniper no headshots
		TF2Items_SetAttribute(item1, 1, 175, 0.0); // jarate duration
	}

	else if (
		ItemIsEnabled("sodapop") &&
		StrEqual(class, "tf_weapon_soda_popper")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 15, 0.0); // crit mod disabled
		TF2Items_SetAttribute(item1, 1, 793, 0.0); // hype on damage
	}

	else if (
		ItemIsEnabled("solemn") &&
		StrEqual(class, "tf_weapon_bonesaw") &&
		(index == 413)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 5, 1.0); // fire rate penalty
	}

	else if (
		ItemIsEnabled("splendid") &&
		StrEqual(class, "tf_wearable_demoshield") &&
		(index == 406)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 3);
		TF2Items_SetAttribute(item1, 0, 64, 0.85); // dmg taken from blast reduced
		TF2Items_SetAttribute(item1, 1, 249, 1.00); // remove +50% increase in charge recharge rate
		TF2Items_SetAttribute(item1, 2, 247, 1.0); // can deal charge impact damage at any range
	}

	else if (
		ItemIsEnabled("spycicle") &&
		StrEqual(class, "tf_weapon_knife") &&
		(index == 649)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 1);
		TF2Items_SetAttribute(item1, 0, 156, 1.0); // silent killer
	}

	else if (
		ItemIsEnabled("stkjumper") &&
		StrEqual(class, "tf_weapon_pipebomblauncher") &&
		(index == 265)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, GetConVarBool(cvar_jumper_flag_run) ? 2 : 1);
		TF2Items_SetAttribute(item1, 0, 89, 0.0); // max pipebombs decreased
		if (GetConVarBool(cvar_jumper_flag_run)) {
			TF2Items_SetAttribute(item1, 1, 400, 0.0);
		}
	}

	else if (
		ItemIsEnabled("targe") &&
		StrEqual(class, "tf_wearable_demoshield") &&
		(index == 131)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 64, 0.6); // dmg taken from blast reduced
		TF2Items_SetAttribute(item1, 1, 527, 1.0); // afterburn immunity
	}

	else if (
		ItemIsEnabled("tomislav") &&
		StrEqual(class, "tf_weapon_minigun") &&
		(index == 424)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 87, 0.60); // 40% minigun spinup time decreased; mult_minigun_spinup_time
		TF2Items_SetAttribute(item1, 1, 106, 1.0); // 0% accuracy attribute; weapon spread bonus; mult_spread_scale
		// Note: It is recommended for the minigun ramp-up revert to be active so that the reverted pre-Pyromania Tomislav is historically and functionally accurate!
	}

	else if (
		ItemIsEnabled("turner") &&
		StrEqual(class, "tf_wearable_demoshield") &&
		(index == 1099)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 3);
		TF2Items_SetAttribute(item1, 0, 676, 0.0); // lose demo charge on damage when charging
		TF2Items_SetAttribute(item1, 1, 60, 0.75); // 25% fire damage resistance on wearer
		TF2Items_SetAttribute(item1, 2, 64, 0.75); // 25% explosive damage resistance on wearer
	}

	else if (
		ItemIsEnabled("tribalshiv") &&
		StrEqual(class, "tf_weapon_club") &&
		(index == 171)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 149, 8.0); // bleed duration
		TF2Items_SetAttribute(item1, 1, 1, 0.65); // dmg penalty
	}

	else if (
		ItemIsEnabled("vitasaw") &&
		StrEqual(class, "tf_weapon_bonesaw") &&
		(index == 173)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 188, 20.0); // preserve ubercharge (doesn't work)
		TF2Items_SetAttribute(item1, 1, 811, 0.0); // ubercharge preserved on spawn max
	}

	else if (
		ItemIsEnabled("warrior") &&
		StrEqual(class, "tf_weapon_fists") &&
		(index == 310)
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 5);
		TF2Items_SetAttribute(item1, 0, 412, 1.0); // damage vuln
		TF2Items_SetAttribute(item1, 1, 180, 0.0); // heal on kill
		TF2Items_SetAttribute(item1, 2, 110, 10.0); // heal on hit
		TF2Items_SetAttribute(item1, 3, 128, 0.0); // provide on active
		TF2Items_SetAttribute(item1, 4, 125, -20.0); // max health additive penalty
	}

	else if (
		ItemIsEnabled("zatoichi") &&
		StrEqual(class, "tf_weapon_katana")
	) {
		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 4);
		TF2Items_SetAttribute(item1, 0, 15, 1.0); // crit mod disabled
		TF2Items_SetAttribute(item1, 1, 220, 0.0); // restore health on kill
		TF2Items_SetAttribute(item1, 2, 226, 0.0); // honorbound
		TF2Items_SetAttribute(item1, 3, 781, 0.0); // is a sword
		//zatoichi has different sword logic, so don't handle here unlike claid
	}

	//swords should be handled at the very end, so other reverts take precednece 
	//if the code makes it here, that means the other reverts aren't active
	//so only apply this one
	else if (
		ItemIsEnabled("swords") &&
		( StrEqual(class, "tf_weapon_sword") ||
		StrEqual(class, "tf_weapon_katana") )
	) {

		item1 = TF2Items_CreateItem(0);
		TF2Items_SetFlags(item1, (OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES));
		TF2Items_SetNumAttributes(item1, 2);
		TF2Items_SetAttribute(item1, 0, 781, 0.0); // is a sword
		TF2Items_SetAttribute(item1, 1, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
	}

	if (item1 != null) {
		item = item1;
		return Plugin_Changed;
	}
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

		{
			// apply attrib changes

			if (IsPlayerAlive(client)) {
				ItemPlayerApply(client);

				if (players[client].change) {
					// tf2 only respawns a player's weapon/wearable entities when those entities are different from
					// the ones that should be equipped, aka when the player changes class or equips a different weapon.
					// we manually force it to happen by removing the entities and respawning the player a few ticks later.

					PlayerRemoveEquipment(client);

					players[client].respawn = GetGameTickCount();
					players[client].change = false;
				}
			}
		}

		{
			// vitasaw charge apply

			if (
				ItemIsEnabled("vitasaw") &&
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

		if (
			client > 0 &&
			client <= MaxClients &&
			attacker > 0 &&
			attacker <= MaxClients &&
			IsClientInGame(client) &&
			IsClientInGame(attacker)
		) {
			{
				// zatoichi heal on kill

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
							ItemIsEnabled("zatoichi") &&
							StrEqual(class, "tf_weapon_katana")
						) {
							health_cur = GetClientHealth(attacker);
							health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

							if (health_cur < health_max) {
								SetEntProp(attacker, Prop_Send, "m_iHealth", health_max);

								event1 = CreateEvent("player_healonhit", true);

								SetEventInt(event1, "amount", health_max);
								SetEventInt(event1, "entindex", attacker);
								SetEventInt(event1, "weapon_def_index", -1);

								FireEvent(event1);
							}
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
							ItemIsEnabled("ambassador") &&
							StrEqual(class, "tf_weapon_revolver")
						) {
							SetEventInt(event, "customkill", TF_CUSTOM_HEADSHOT);

							return Plugin_Changed;
						}
					}
				}
			}

			{
				// Powerjack heal on kill with overheal copied from NotnHeavy's code
				if (
					client != attacker &&
					(GetEventInt(event, "death_flags") & TF_DEATH_FEIGN_DEATH) == 0 &&
					GetEventInt(event, "inflictor_entindex") == attacker && // make sure it wasn't a "finished off" kill
					IsPlayerAlive(attacker) &&
					// fix to prevent powerjack gaining hp while active from players burning to death by flamethrowers, flareguns and reflected burning arrows
					GetEventInt(event,"customkill") == TF_DMG_CUSTOM_NONE // powerjack melee kill has a customkill value of 0, thanks huutti; -mindfulprotons
				) {
					weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

					if (weapon > 0) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							ItemIsEnabled("powerjack") &&
							StrEqual(class, "tf_weapon_fireaxe") &&
							GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 214
						) {
							health_cur = GetClientHealth(attacker);
							int pyro_overheal_max = 260; // this needs to be adjusted in case the backburner is reverted to the release version
							{
								event1 = CreateEvent("player_healonhit", true);
								SetEventInt(event1, "amount", intMin(pyro_overheal_max - health_cur, 75));
								SetEventInt(event1, "entindex", attacker);
								SetEventInt(event1, "weapon_def_index", -1);
								FireEvent(event1);
								// Set health
								if(health_cur <= pyro_overheal_max) {
									SetEntityHealth(attacker, intMin(GetClientHealth(attacker) + 75, pyro_overheal_max));
								}
								// prevent removing extra hp beyond normal max overheal in case the pyro uses the 2x overheal spell during halloween
								// pyro will not get extra hp when killing an enemy. this is a niche case for halloween
								else if(health_cur > pyro_overheal_max) {
									SetEntityHealth(attacker, health_cur);
								}
							}
						}
					}
				}
			}

			{
				// fix sydney sleeper headshot kill icon (unless crit-boosted)

				if (
					GetEventInt(event, "customkill") == TF_CUSTOM_HEADSHOT &&
					players[attacker].headshot_frame == GetGameTickCount() &&
					PlayerIsCritboosted(attacker) == false
				) {
					weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

					if (weapon > 0) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							ItemIsEnabled("sleeper") &&
							StrEqual(class, "tf_weapon_sniperrifle") &&
							GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 230
						) {
							SetEventInt(event, "customkill", TF_DMG_CUSTOM_NONE);
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

		//cache players weapons for later funcs
		{
			for (int i = 0; i < Wep_Placeholder; i++) {
				player_weapons[client][i] = false;
			}

			int length = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
			for (int i;i < length; i++)
			{
				weapon = GetEntPropEnt(client,Prop_Send,"m_hMyWeapons",i);
				if (weapon != -1)
				{
					GetEntityClassname(weapon, class, sizeof(class));
					index = GetEntProp(weapon,Prop_Send,"m_iItemDefinitionIndex");

					if(
						StrEqual(class,"tf_weapon_lunchbox_drink") &&
						(index == 163)
					) {
						player_weapons[client][Wep_CritCola] = true;
					}

					else if (
						StrEqual(class,"tf_weapon_lunchbox_drink") &&
						(index == 46 || index == 1145)
					) {
						player_weapons[client][Wep_Bonk] = true;
					}

					else if (
						StrEqual(class,"tf_weapon_minigun") &&
						(index == 312)
					) {
						player_weapons[client][Wep_BrassBeast] = true;
					}

					else if (
						StrEqual(class,"tf_weapon_minigun") &&
						(index == 41)
					) {
						player_weapons[client][Wep_Natascha] = true;
					}

					else if (
						StrEqual(class,"tf_weapon_rocketlauncher") &&
						(index == 237)
					) {
						player_weapons[client][Wep_RocketJumper] = true;
					}

					else if (
						StrEqual(class, "tf_weapon_sword") &&
						(index == 404)
					) {
						player_weapons[client][Wep_PersianPersuader] = true;
					}
          
          				// shortstop primary ammo sharing with secondary pistol ammo
					else if (
						ItemIsEnabled("shortstop") &&
						StrEqual(class,"tf_weapon_handgun_scout_primary")
					) {
						int SCOUT_PISTOL_AMMO_TYPE = 2;
						SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", SCOUT_PISTOL_AMMO_TYPE);
          				}
				}
			}
			int num_wearables = TF2Util_GetPlayerWearableCount(client);
			for (int i = 0; i < num_wearables; i++)
			{
				int wearable = TF2Util_GetPlayerWearable(client, i);			
				GetEntityClassname(wearable, class, sizeof(class));
				index = GetEntProp(wearable,Prop_Send,"m_iItemDefinitionIndex");
				
				if (
					StrEqual(class,"tf_wearable_demoshield") &&
					(index == 131)
				) {
					player_weapons[client][Wep_CharginTarge] = true;
				}

				else if (
					StrEqual(class,"tf_wearable_demoshield") &&
					(index == 406)
				) {
					player_weapons[client][Wep_SplendidScreen] = true;
				}

				else if (
					StrEqual(class,"tf_wearable_demoshield") &&
					(index == 1099)
				) {
					player_weapons[client][Wep_TideTurner] = true;
				}
			}
		}

		//item sets
		if (
			ItemIsEnabled("saharan")
		) {
			// reset set bonuses on loadout changes
			TFClassType client_class = TF2_GetPlayerClass(client);
			switch (client_class)
			{
				case TFClass_Spy:
				{
					TF2Attrib_SetByDefIndex(client, 159, 0.0); // SET BONUS: cloak blink time penalty
					TF2Attrib_SetByDefIndex(client, 160, 0.0); // SET BONUS: quiet unstealth
				}
			}
			

			//handle item sets
			int wep_count = 0;
			int active_set = 0;

			int length = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
			for (int i;i < length; i++)
			{
				weapon = GetEntPropEnt(client,Prop_Send,"m_hMyWeapons",i);
				if (weapon != -1)
				{
					char classname[64];
					GetEntityClassname(weapon, classname, sizeof(class));
					int item_index = GetEntProp(weapon,Prop_Send,"m_iItemDefinitionIndex");

					// Saharan Spy
					if(
						ItemIsEnabled("saharan") &&
						(StrEqual(classname, "tf_weapon_revolver") &&
						(item_index == 224)) ||
						(StrEqual(classname, "tf_weapon_knife") &&
						(item_index == 225 || item_index == 574))
					) {
						wep_count++;
						if(wep_count == 2) active_set = ItemSet_Saharan;
					}
				}
			}

			if (active_set)
			{
				bool validSet = true;

				// bool validSet = false;
				// int num_wearables = TF2Util_GetPlayerWearableCount(client);
				// for (int i = 0; i < num_wearables; i++)
				// {
				// 	int wearable = TF2Util_GetPlayerWearable(client, i);
				// 	int item_index = GetEntProp(wearable,Prop_Send,"m_iItemDefinitionIndex");
				// 	if(
				// 		(active_set == ItemSet_Saharan) &&
				// 		(item_index == 223)
				// 	) {
				// 		validSet = true;
				// 		break;
				// 	}
				// }

				if (validSet)
				{
					switch (active_set)
					{
						case ItemSet_Saharan:
						{
							TF2Attrib_SetByDefIndex(client, 159, 0.5); // SET BONUS: cloak blink time penalty
							TF2Attrib_SetByDefIndex(client, 160, 1.0); // SET BONUS: quiet unstealth
						}
					}
				}
			}

		}

		{
			// if player has a drink item, end minicrits and apply hype

			if (players[client].is_under_hype)
			{
				bool has_lunchbox = (player_weapons[client][Wep_Bonk] || player_weapons[client][Wep_CritCola]);
				if (has_lunchbox)
				{
					players[client].is_under_hype = false;
					TF2_AddCondition(client, TFCond_CritHype, 11.0, 0);
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

Action OnSoundNormal(
	int clients[MAXPLAYERS], int& clients_num, char sample[PLATFORM_MAX_PATH], int& entity, int& channel,
	float& volume, int& level, int& pitch, int& flags, char soundentry[PLATFORM_MAX_PATH], int& seed
) {
	int idx;

	if (StrContains(sample, "player/pl_impact_stun") == 0) {
		for (idx = 1; idx <= MaxClients; idx++) {
			if (
				ItemIsEnabled("sandman") &&
				players[idx].projectile_touch_frame == GetGameTickCount()
			) {
				// cancel duplicate sandman stun sounds
				// we cancel the default stun and apply our own
				return Plugin_Stop;
			}

			if (
				ItemIsEnabled("bonk") &&
				players[idx].bonk_cond_frame == GetGameTickCount()
			) {
				// cancel bonk stun sound
				return Plugin_Stop;
			}
		}
	}
	if (GetConVarBool(cvar_old_falldmg_sfx))
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

	return Plugin_Continue;
}

Action SDKHookCB_Spawn(int entity) {
	char class[64];

	GetEntityClassname(entity, class, sizeof(class));

	if (StrContains(class, "tf_projectile_") == 0) {
		entities[entity].spawn_time = GetGameTime();
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
					(ItemIsEnabled("bison") && StrEqual(class, "tf_weapon_raygun")) ||
					(ItemIsEnabled("pomson") && StrEqual(class, "tf_weapon_drg_pomson"))
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
			if (
				other >= 1 &&
				other <= MaxClients
			) {
				owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
				weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");

				if (
					owner > 0 &&
					weapon > 0
				) {
					GetEntityClassname(weapon, class, sizeof(class));

					if (StrEqual(class, "tf_weapon_drg_pomson")) {
						if (
							ItemIsEnabled("pomson") &&
							TF2_GetClientTeam(owner) == TF2_GetClientTeam(other)
						) {
							return Plugin_Handled;
						}
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
	int health_new;
	int weapon1;

	if (
		victim >= 1 &&
		victim <= MaxClients
	) {
		// damage from any source

		{
			// save fall dmg tick for overriding with old fall dmg sound
			if (damage_type & DMG_FALL)
				players[victim].fall_dmg_tick = GetGameTickCount();
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
						if (ItemIsEnabled("ringer")) {
							SetConVarFloat(cvar_ref_tf_feign_death_duration, 6.5);
							SetConVarFloat(cvar_ref_tf_feign_death_speed_duration, 6.5);
							SetConVarFloat(cvar_ref_tf_feign_death_activate_damage_scale, 0.10);
							SetConVarFloat(cvar_ref_tf_feign_death_damage_scale, 0.10);
						} else {
							SetConVarReset(cvar_ref_tf_feign_death_duration);
							SetConVarReset(cvar_ref_tf_feign_death_speed_duration);
							SetConVarReset(cvar_ref_tf_feign_death_activate_damage_scale);
							SetConVarReset(cvar_ref_tf_feign_death_damage_scale);
						}
					}
				}
				
				// dead ringer track when feign begins
				if (ItemIsEnabled("ringer")) {
					if (
						GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") &&
						players[victim].spy_is_feigning == false
					) {
						players[victim].ticks_since_feign_ready = GetGameTickCount();
						players[victim].damage_taken_during_feign  = 0.0;
					}
				}
			}
		}

		{
			// turner charge loss on damage taken

			if (
				ItemIsEnabled("turner") &&
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
	}

	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		// damage from players only

		// useful for checking minicrits in OnTakeDamageAlive
		players[victim].crit_flag = (damage_type & DMG_CRIT != 0) ? true : false;

		if (weapon > MaxClients) {
			GetEntityClassname(weapon, class, sizeof(class));

			{
				// caber damage

				if (
					ItemIsEnabled("caber") &&
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
					ItemIsEnabled("cannon") &&
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
				// ambassador headshot crits

				if (
					ItemIsEnabled("ambassador") &&
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
					ItemIsEnabled("equalizer") &&
					StrEqual(class, "tf_weapon_shovel") &&
					damage_custom == TF_DMG_CUSTOM_PICKAXE &&
					(
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 128 ||
						GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 775
					)
				) {
					health_cur = GetClientHealth(attacker);
					health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

					damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), 1.65, 0.5));

					return Plugin_Changed;
				}
			}

			{
				// reserve airblast minicrits

				if (
					ItemIsEnabled("reserve") &&
					StrContains(class, "tf_weapon_shotgun") == 0 &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 415
				) {
					if (
						(GetEntityFlags(victim) & FL_ONGROUND) == 0 &&
						GetEntProp(victim, Prop_Data, "m_nWaterLevel") == 0 &&
						TF2_IsPlayerInCondition(victim, TFCond_KnockedIntoAir) == true &&
						TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeathSilent) == false
					) {
						// seems to be the best way to force a minicrit
						TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
					}
				}
			}

			{
				// soda popper minicrits

				if (
					ItemIsEnabled("sodapop") &&
					TF2_IsPlayerInCondition(attacker, TFCond_CritHype) == true &&
					TF2_IsPlayerInCondition(victim, TFCond_MarkedForDeathSilent) == false
				) {
					TF2_AddCondition(victim, TFCond_MarkedForDeathSilent, 0.001, 0);
				}
			}

			{
				// sandman stun

				if (
					ItemIsEnabled("sandman") &&
					damage_custom == TF_DMG_CUSTOM_BASEBALL &&
					!StrEqual(class, "tf_weapon_bat_giftwrap") //reflected wrap will stun I think, lol!
				) {
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

								stun_fls = TF_STUNFLAGS_SMALLBONK;

								if (stun_amt >= 1.0) {
									// moonshot!

									stun_dur = (stun_dur + 1.0);
									stun_fls = TF_STUNFLAGS_BIGBONK;

									if (GetConVarBool(cvar_extras)) {
										SetHudTextParams(-1.0, 0.09, 4.0, 255, 255, 255, 255, 2, 0.5, 0.01, 1.0);

										for (idx = 1; idx <= MaxClients; idx++) {
											if (IsClientInGame(idx)) {
												ShowSyncHudText(idx, hudsync, "%N just landed a MOONSHOT on %N !", attacker, victim);
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

					if (damage == 22.5) {
						// always deal 15 impact damage at any range
						damage = 15.0;
					}

					return Plugin_Changed;
				}
			}

			{
				// sleeper jarate mechanics

				if (
					ItemIsEnabled("sleeper") &&
					StrEqual(class, "tf_weapon_sniperrifle") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 230
				) {
					if (
						GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") > 0.1 &&
						PlayerIsInvulnerable(victim) == false
					) {
						charge = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");

						// this should cause a jarate application
						players[attacker].sleeper_piss_frame = GetGameTickCount();
						players[attacker].sleeper_piss_duration = ValveRemapVal(charge, 50.0, 150.0, 2.0, 8.0);
						players[attacker].sleeper_piss_explode = false;

						if (
							GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") > 149.0 ||
							players[attacker].headshot_frame == GetGameTickCount()
						) {
							// this should also cause a jarate explosion
							players[attacker].sleeper_piss_explode = true;
						}
					}

					// disable headshot crits
					// ...is this even needed?
					if (
						damage_type & DMG_CRIT != 0 &&
						PlayerIsCritboosted(attacker) == false
					) {
						damage_type = (damage_type & ~DMG_CRIT);
						return Plugin_Changed;
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
							if (ItemIsEnabled("zatoichi")) {
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
					ItemIsEnabled("guillotine") &&
					StrEqual(class, "tf_weapon_cleaver") &&
					damage > 20.0 // don't count bleed damage
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
					StrEqual(class, "tf_weapon_knife") &&
					damage_custom == TF_DMG_CUSTOM_BACKSTAB
				) {
					players[attacker].backstab_time = GetGameTime();
				}
			}

			{
				if (
					ItemIsEnabled("blackbox") && 
					StrEqual(class,"tf_weapon_rocketlauncher") &&
					(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 228 ||
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 1085) &&
					attacker != victim &&
					TF2_GetClientTeam(attacker) != TF2_GetClientTeam(victim) &&
					!TF2_IsPlayerInCondition(victim, TFCond_Disguised) &&
					!TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)
					// reverted black box will heal on Bonked Scouts
					// for some reason adding TF2_IsPlayerInCondition(victim, TFCond_Bonked) makes the healing not work
				) {
					// Show that attacker got healed.
					Handle event = CreateEvent("player_healonhit", true);
					SetEventInt(event, "amount", 15);
					SetEventInt(event, "entindex", attacker);
					FireEvent(event);

					// Set health.
					health_cur = GetClientHealth(attacker);
					health_new = health_cur + 15;
					health_max = SDKCall(sdkcall_GetMaxHealth, attacker);

					if(health_max > health_new) {
						SetEntityHealth(attacker, health_new);						
					}				
					else if(health_max > health_cur) { 
						SetEntityHealth(attacker, health_max); //check if the current health is 14HP less than the max health
					}	
					else if(health_max < health_cur) { 
						SetEntityHealth(attacker, health_cur); //don't remove overheal (still shows +15 HP on hit)
					}					
				}
			}

			{
				// shield bash
				if (
					((ItemIsEnabled("targe") && player_weapons[attacker][Wep_CharginTarge]) ||
					 (ItemIsEnabled("splendid") && player_weapons[attacker][Wep_SplendidScreen]) ||
					 (ItemIsEnabled("turner") && player_weapons[attacker][Wep_TideTurner])) &&
					StrEqual(class, "tf_wearable_demoshield") &&
					damage_custom == TF_DMG_CUSTOM_CHARGE_IMPACT
				) {
					// crit after shield bash if melee is active weapon
					weapon1 = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
					if (weapon1 == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
						TF2_AddCondition(attacker, TFCond_CritOnDamage, 0.5, 0);

					// apply shield bash damage at the end of a charge, unless using splendid screen
					if (player_weapons[attacker][Wep_SplendidScreen] == false)
					{
						charge = GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter");
						if (charge > 40.0) // check if this is the correct value
						{
							return Plugin_Handled;
						}
					}
				}
			}

			if (inflictor > MaxClients) {
				GetEntityClassname(inflictor, class, sizeof(class));

				{
					// bison/pomson stuff

					if (StrEqual(class, "tf_projectile_energy_ring")) {
						GetEntityClassname(weapon, class, sizeof(class));

						if (
							(ItemIsEnabled("bison") && StrEqual(class, "tf_weapon_raygun")) ||
							(ItemIsEnabled("pomson") && StrEqual(class, "tf_weapon_drg_pomson"))
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

							if (StrEqual(class, "tf_weapon_raygun")) {
								pos1[2] = 0.0;
								pos2[2] = 0.0;

								if (GetVectorDistance(pos1, pos2) > 55.0) {
									// target is too far from the projectile, cancel the hit
									return Plugin_Stop;
								}

								players[victim].bison_hit_frame = GetGameTickCount();
							}

							if (
								StrEqual(class, "tf_weapon_drg_pomson") &&
								PlayerIsInvulnerable(victim) == false
							) {
								// cloak/uber drain

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
							}
						}

						return Plugin_Continue;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

Action SDKHookCB_OnTakeDamageAlive(
	int victim, int& attacker, int& inflictor, float& damage, int& damage_type,
	int& weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	Action returnValue = Plugin_Continue;
	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		{
			// sleeper jarate application

			if (
				ItemIsEnabled("sleeper") &&
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
			if (
				((ItemIsEnabled("brassbeast") && player_weapons[victim][Wep_BrassBeast]) ||
				(ItemIsEnabled("natascha") && player_weapons[victim][Wep_Natascha])) &&
				TF2_IsPlayerInCondition(victim, TFCond_Slowed) &&
				TF2_GetPlayerClass(victim) == TFClass_Heavy
			) {
				// Brass Beast damage resistance when spun up
				
				// play damage resist sound
				EmitGameSoundToAll("Player.ResistanceLight", victim);
				
				// apply resistance
				if (damage_type & DMG_CRIT != 0)
					damage *= players[victim].crit_flag ? 0.93333333 : 0.851851851; // for crits and minicrits, respectively
				else
					damage *= 0.80;
				
				returnValue = Plugin_Changed;
			}
		}
		{
			if(
				ItemIsEnabled("rocketjmp") &&
				victim == attacker &&
				damage_custom == TF_DMG_CUSTOM_TAUNTATK_GRENADE &&
				player_weapons[victim][Wep_RocketJumper]
			) {
				// save old health and set health to 500 to tank the grenade blast
				// do it this way in order to preserve knockback caused by the explosion
				players[victim].old_health = GetClientHealth(victim);
				SetEntityHealth(victim, 500);
			}
		}
	}

	return returnValue;
}

void SDKHookCB_OnTakeDamagePost(
	int victim, int attacker, int inflictor, float damage, int damage_type,
	int weapon, float damage_force[3], float damage_position[3], int damage_custom
) {
	if (
		victim >= 1 &&
		victim <= MaxClients &&
		TF2_GetPlayerClass(victim) == TFClass_Spy
	) {
		// dead ringer damage tracking
		if (TF2_IsPlayerInCondition(victim, TFCond_DeadRingered)) {
			players[victim].damage_taken_during_feign += damage;
		}
	}

	if (
		victim >= 1 && victim <= MaxClients &&
		attacker >= 1 && attacker <= MaxClients
	) {
		if(
			ItemIsEnabled("rocketjmp") &&
			victim == attacker &&
			damage_custom == TF_DMG_CUSTOM_TAUNTATK_GRENADE &&
			player_weapons[victim][Wep_RocketJumper]
		) {
			// set back saved health after tauntkill
			SetEntityHealth(victim, players[victim].old_health);
		}
	}
}

Action Command_Menu(int client, int args) {
	if (client > 0) {
		if (GetConVarBool(cvar_enable)) {
			DisplayMenu(menu_main, client, ITEM_MENU_TIME);
		} else {
			ReplyToCommand(client, "[SM] Weapon reverts are not enabled right now");
		}
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


void SetConVarMaybe(Handle cvar, char[] value, bool maybe) {
	if (maybe) {
		SetConVarString(cvar, value);
	} else {
		SetConVarReset(cvar);
	}
}

void SetConVarReset(Handle cvar) {
	char tmp[64];
	GetConVarDefault(cvar, tmp, sizeof(tmp));
	SetConVarString(cvar, tmp);
}

bool TraceFilter_ExcludeSingle(int entity, int contentsmask, any data) {
	return (entity != data);
}

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

	return true;
}

int GetFeignBuffsEnd(int client)
{
    return players[client].ticks_since_feign_ready + RoundFloat(66 * 6.5) - RoundFloat(players[client].damage_taken_during_feign * 1.1);
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

void PlayerRemoveEquipment(int client) {
	int idx;
	char class[64];

	TF2_RemoveAllWeapons(client);

	for (idx = (MaxClients + 1); idx < 2048; idx++) {
		if (IsValidEntity(idx)) {
			GetEntityClassname(idx, class, sizeof(class));

			if (
				StrContains(class, "tf_wearable") == 0 &&
				GetEntPropEnt(idx, Prop_Send, "m_hOwnerEntity") == client
			) {
				TF2_RemoveWearable(client, idx);
			}
		}
	}
}

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

void ParticleShowSimple(char[] name, float position[3]) {
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

void ItemDefine(char[] name, char[] key, char[] desc, int classflags) {
	int idx;

	for (idx = 0; idx < ITEMS_MAX; idx++) {
		if (strlen(items[idx].key) == 0) {
			strcopy(items[idx].key, sizeof(items[].key), key);
			strcopy(items[idx].name, sizeof(items[].name), name);
			strcopy(items[idx].desc, sizeof(items[].desc), desc);
			items[idx].classflags = classflags;
			return;
		}
	}

	SetFailState("Not enough item slots to define new item");
}

void ItemFinalize() {
	int idx;
	char cvar_name[64];
	char cvar_desc[256];

	for (idx = 0; idx < ITEMS_MAX; idx++) {
		if (strlen(items[idx].key) > 0) {
			if (items[idx].cvar != null) {
				SetFailState("Tried to initialize items more than once");
			}

			// AddMenuItem(menu_pick, items[idx].key, "ERROR", _);

			Format(cvar_name, sizeof(cvar_name), "sm_reverts__item_%s", items[idx].key);
			Format(cvar_desc, sizeof(cvar_desc), (PLUGIN_NAME ... " - Revert nerfs to %s"), items[idx].name);

			items[idx].cvar = CreateConVar(cvar_name, "1", cvar_desc, FCVAR_NOTIFY, true, 0.0, true, 1.0);
		}
	}
}

int ItemKeyToNum(char[] key) {
	int idx;

	for (idx = 0; idx < ITEMS_MAX; idx++) {
		if (
			items[idx].key[0] != 0 &&
			StrEqual(key, items[idx].key)
		) {
			return idx;
		}
	}

	return -1;
}


bool ItemIsEnabled(char[] key) {
	int item = ItemKeyToNum(key);
	return (
		GetConVarBool(cvar_enable) &&
		GetConVarBool(items[item].cvar)
	);
}

void ItemPlayerApply(int client) {
	int idx;
	bool value;

	for (idx = 0; idx < ITEMS_MAX; idx++) {
		if (strlen(items[idx].key) > 0) {
			value = false;

			if (
				GetConVarBool(cvar_enable) &&
				GetConVarBool(items[idx].cvar)
			) {
				value = true;
			}

			if (players[client].items_life[idx] != value) {
				players[client].items_life[idx] = value;
				players[client].change = true;
			}
		}
	}
}

int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2) {
	char info[64];

	if (menu == menu_main) {
		if (action == MenuAction_Select) {
			GetMenuItem(menu, param2, info, sizeof(info));

			if (StrEqual(info, "info")) {
				ShowItemsDetails(param1);
			}
			else if (StrEqual(info, "classinfo")) {
				ShowClassReverts(param1);
			}
		}
	}

	return 0;
}

void ShowItemsDetails(int client) {
	int idx;
	int count;
	char msg[ITEMS_MAX][256];

	count = 0;

	if (GetConVarBool(cvar_enable)) {
		for (idx = 0; idx < ITEMS_MAX; idx++) {
			if (
				strlen(items[idx].key) > 0 &&
				GetConVarBool(items[idx].cvar)
			) {
				Format(msg[count], sizeof(msg[]), "%s - %s", items[idx].name, items[idx].desc);
				count++;
			}
		}
	}

	ReplyToCommand(client, "[SM] Weapon revert details printed to console");

	PrintToConsole(client, "\n");
	PrintToConsole(client, "Weapon reverts currently enabled on this server:");

	if (count > 0) {
		for (idx = 0; idx < sizeof(msg); idx++) {
			if (strlen(msg[idx]) > 0) {
				PrintToConsole(client, "  %s", msg[idx]);
			}
		}
	} else {
		PrintToConsole(client, "  There's nothing here... for some reason, all item cvars are off :\\");
	}

	PrintToConsole(client, "");
}

void ShowClassReverts(int client) {
	int idx;
	int count;
	char msg[ITEMS_MAX][256];
	int class_idx;
	TFTeam team;

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

	if (GetConVarBool(cvar_enable)) {
		for (idx = 0; idx < ITEMS_MAX; idx++) {
			if (
				strlen(items[idx].key) > 0 &&
				GetConVarBool(items[idx].cvar)
			) {
				if (items[idx].classflags & (1 << class_idx) == 0)
					continue;
				Format(msg[count], sizeof(msg[]), "{gold}%s {lightgreen}- %s", items[idx].name, items[idx].desc);
				count++;
			}
		}
	}

	ReplyToCommand(client, "Weapon reverts currently enabled for %s:", class_names[class_idx]);

	if (count > 0) {
		for (idx = 0; idx < sizeof(msg); idx++) {
			if (strlen(msg[idx]) > 0) {
				CReplyToCommand(client, "%s", msg[idx]);
			}
		}
	} else {
		CReplyToCommand(client, "{lightgreen}There's nothing here... for some reason, all %s reverts are disabled :\\", class_names[class_idx]);
	}
}

#if defined VERDIUS_PATCHES
int HealBuilding(int buildingIndex, int engineerIndex) {
    float RepairAmountFloat = 75.0; //It's Sigafoo save time BABY!
    RepairAmountFloat = fmin(RepairAmountFloat,float(GetEntProp(buildingIndex, Prop_Data, "m_iMaxHealth") - GetEntProp(buildingIndex, Prop_Data, "m_iHealth")));
    int currentHealth = GetEntProp(buildingIndex, Prop_Data, "m_iHealth");
    //int maxHealth = GetEntProp(buildingIndex, Prop_Data, "m_iMaxHealth");
    int RepairAmount = RoundToNearest(RepairAmountFloat);
    if (RepairAmountFloat > 0.0) {

    //Need to calc limits ourself.

    SetVariantInt(RepairAmount);
    AcceptEntityInput(buildingIndex, "AddHealth", engineerIndex);
    int newHealth = GetEntProp(buildingIndex, Prop_Send, "m_iHealth");
    Event event = CreateEvent("building_healed");

    if (event != null)
    {
        event.SetInt("priority", 1); // HLTV event priority, not transmitted
        event.SetInt("building", buildingIndex); // self-explanatory.
        event.SetInt("healer", engineerIndex); // Index of the engineer who healed the building.
        event.SetInt("amount", currentHealth - newHealth); // Repairamount to display. Will be something between 1-75.

        FireEvent(event); // FIRE IN THE HOLE!!!!!!!
    }

    // Check if building owner and the engineer who shot the bolt
    // are the same person, if not. Give them progress on
    // the "Circle the Wagons" achivement.
    int buildingOwner = GetEntPropEnt(buildingIndex,Prop_Send,"m_hBuilder");
    if (buildingOwner != engineerIndex) {
        AddProgressOnAchievement(engineerIndex,1836,RepairAmount);
    }
    } else {RepairAmount = 0;}
    
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

    if (!StrEqual(classname, "obj_sentrygun", false) 
     && !StrEqual(classname, "obj_teleporter", false) 
     && !StrEqual(classname, "obj_dispenser", false))
    {
        //PrintToChatAll("Entity did not match buildings");
        return false;
    }

	if (GetEntProp(buildingIndex, Prop_Send, "m_bHasSapper")
	 || GetEntProp(buildingIndex, Prop_Send, "m_bPlasmaDisable")
	 || GetEntProp(buildingIndex, Prop_Send, "m_bBuilding")
	 || GetEntProp(buildingIndex, Prop_Send, "m_bPlacing"))
	{
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

public float fmin(float a, float b) {
    return a < b ? a : b;
}

public bool AddProgressOnAchievement(int playerID, int achievementID, int Amount) {
    if (sdkcall_AwardAchievement == null || achievementID < 1 || Amount < 1) {
		return false; //SDKcall not prepared or Handle not created.
	}

	if (!IsFakeClient(playerID)) {
		return false; //Client (aka player) is not valid, are they connected?
	}
		SDKCall(sdkcall_AwardAchievement, playerID, achievementID, Amount);

	return true;
}
#endif

MRESReturn DHookCallback_CTFWeaponBase_PrimaryAttack(int entity) {
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFWeaponBase_SecondaryAttack(int entity) {
	int idx;
	int owner;
	char class[64];
	float player_pos[3];
	float target_pos[3];
	float angles1[3];
	float angles2[3];
	float vector[3];
	float distance;
	float limit;
	int metal;

	GetEntityClassname(entity, class, sizeof(class));

	owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (owner > 0) {
		if (
			StrEqual(class, "tf_weapon_flamethrower") ||
			StrEqual(class, "tf_weapon_rocketlauncher_fireball")
		) {
			// airblast set type cvar

			SetConVarMaybe(cvar_ref_tf_airblast_cray, "0", ItemIsEnabled("airblast"));

			return MRES_Ignored;
		}

		if (
			ItemIsEnabled("circuit") &&
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

				SetEntProp(owner, Prop_Data, "m_iAmmo", (metal - BALANCE_CIRCUIT_METAL), 4, 3);

				GetClientEyePosition(owner, player_pos);
				GetClientEyeAngles(owner, angles1);

				// scan for entities to hit
				for (idx = 1; idx < 2048; idx++) {
					if (IsValidEntity(idx)) {
						GetEntityClassname(idx, class, sizeof(class));

						// only hit players and some projectiles
						if (
							(idx <= MaxClients) ||
							StrEqual(class, "tf_projectile_rocket") ||
							StrEqual(class, "tf_projectile_sentryrocket") ||
							StrEqual(class, "tf_projectile_pipe") ||
							StrEqual(class, "tf_projectile_pipe_remote") ||
							StrEqual(class, "tf_projectile_arrow") ||
							StrEqual(class, "tf_projectile_flare") ||
							StrEqual(class, "tf_projectile_stun_ball") ||
							StrEqual(class, "tf_projectile_ball_ornament") ||
							StrEqual(class, "tf_projectile_cleaver")
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
												SDKHooks_TakeDamage(idx, entity, owner, BALANCE_CIRCUIT_DAMAGE, DMG_SHOCK, entity, NULL_VECTOR, target_pos, false);
											} else {
												// delete projectiles
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

			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFBaseRocket_GetRadius(int entity, Handle return_) {
	int owner;
	int weapon;
	char class[64];
	float value;

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
				ItemIsEnabled("airstrike") &&
				StrEqual(class, "tf_weapon_rocketlauncher_airstrike") &&
				IsPlayerAlive(owner) &&
				TF2_IsPlayerInCondition(owner, TFCond_BlastJumping)
			) {
				// for some reason, doing this in one line doesn't work
				// we have to get the value to a var and then set it

				value = DHookGetReturn(return_);
				value = (value / 0.80); // undo airstrike attrib
				DHookSetReturn(return_, value);

				return MRES_Override;
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFPlayer_CalculateMaxSpeed(int entity, DHookReturn returnValue) {
	if (
		entity >= 1 && entity <= MaxClients
	) {
		if (
			ItemIsEnabled("critcola") &&
			IsValidEntity(entity) &&
			TF2_IsPlayerInCondition(entity, TFCond_CritCola) &&
			TF2_GetPlayerClass(entity) == TFClass_Scout &&
			player_weapons[entity][Wep_CritCola]
		) 
		{
			// Crit-a-Cola speed boost.
			returnValue.Value = view_as<float>(returnValue.Value) * 1.25;
			return MRES_Override;
		}
	}
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFPlayer_CanDisguise(int entity, Handle return_) {
	if (
		IsPlayerAlive(entity) &&
		TF2_GetPlayerClass(entity) == TFClass_Spy &&
		(GetGameTime() - players[entity].backstab_time) > 0.0 &&
		(GetGameTime() - players[entity].backstab_time) < 0.5 &&
		ItemIsEnabled("eternal")
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

		DHookSetReturn(return_, value);

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
	int client = GetEntityFromAddress(parameters.Get(1));
    if (ItemIsEnabled("persuader") && player_weapons[client][Wep_PersianPersuader])
    {
		// Health pickup with the Persian Persuader.
        returnValue.Value = false;
		int health = GetClientHealth(client);
        int health_max = SDKCall(sdkcall_GetMaxHealth, client);
        if (health < health_max)
        {
            // Get amount to heal.
            int heal = RoundFloat(40 * PersuaderPackRatios[SDKCall(sdkcall_CAmmoPack_GetPowerupSize, entity)]);

            // Show that the player got healed.
            Handle event = CreateEvent("player_healonhit", true);
            SetEventInt(event, "amount", heal);
            SetEventInt(event, "entindex", client);
            FireEvent(event);

            // Set health.
            SetEntityHealth(client, intMin(health + heal, health_max));
            EmitSoundToAll("items/gunpickup2.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL);
            returnValue.Value = true;
        }
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

MRESReturn DHookCallback_CTFAmmoPack_PackTouch(int entity, DHookParam parameters)
{
	int client = parameters.Get(1);
    if (ItemIsEnabled("persuader") && client > 0 && client <= MaxClients && player_weapons[client][Wep_PersianPersuader])
    {
		// Health pickup with the Persian Persuader from dropped ammo packs.
        int health = GetClientHealth(client);
		int health_max = SDKCall(sdkcall_GetMaxHealth, client);
        if (health < health_max)
        {
            // Show that the player got healed.
            Handle event = CreateEvent("player_healonhit", true);
            SetEventInt(event, "amount", 20);
            SetEventInt(event, "entindex", client);
            FireEvent(event);

            // Set health.
            SetEntityHealth(client, intMin(health + 20, health_max));
            RemoveEntity(entity);
        }
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

#if defined VERDIUS_PATCHES
MRESReturn PreHealingBoltImpact(int arrowEntity, DHookParam parameters)
{
    // Just ignore PreHealing moment and do everything in post.
    if (ItemIsEnabled("rescueranger")) {
        return MRES_Supercede;
    }

    // If fix is not enabled, then let the game execute function as normal.
    return MRES_Ignored;
}

MRESReturn PostHealingBoltImpact(int arrowEntity, DHookParam parameters) {
	if (ItemIsEnabled("rescueranger")) {
	    int buildingIndex = parameters.Get(1);
	    int engineerIndex = GetEntityOwner(arrowEntity);

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
					AttachTEParticleToEntityAndSend(arrowEntity,1699,1); //Red
				} else {
					// [1696] repair_claw_heal_blue
					AttachTEParticleToEntityAndSend(arrowEntity,1696,1); // Blu
				}
			}
		}

	    return MRES_Supercede;
	    }

	// If fix is not enabled, then let the game execute function as normal.
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

int abs(int x)
{
	int mask = x >> 31;
	return (x + mask) ^ mask;
}

MRESReturn DHookCallback_CTFPlayer_AddToSpyKnife(int entity, DHookReturn returnValue, DHookParam parameters)
{
    if (ItemIsEnabled("spycicle"))
    {
        // Prevent ammo pick-up with the spycicle when cloak meter AND ammo are full.
        returnValue.Value = false;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

//Get the smaller integral value
int intMin(int x, int y)
{
    return x > y ? y : x;
}

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
