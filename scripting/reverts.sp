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

#define PLUGIN_NAME "TF2 Weapon Reverts"
#define PLUGIN_DESC "Reverts nerfed weapons back to their glory days"
#define PLUGIN_AUTHOR "Bakugo, NotnHeavy, random, huutti, VerdiusArcana, MindfulProtons"

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

#define ITEM_MENU_TIME (60*3)
#define BALANCE_CIRCUIT_METAL 15
#define BALANCE_CIRCUIT_DAMAGE 20.0
#define BALANCE_CIRCUIT_RECOVERY 0.5
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
	int ticks_since_switch;
	bool player_jumped;
}

enum struct Entity {
	bool exists;
	float spawn_time;
	bool is_demo_shield;
}

ConVar cvar_enable;
ConVar cvar_extras;
ConVar cvar_old_falldmg_sfx;
ConVar cvar_no_reverts_info_by_default;
ConVar cvar_dropped_weapon_enable;
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
ConVar cvar_ref_tf_scout_hype_mod;
#if defined MEMORY_PATCHES
MemoryPatch patch_RevertDisciplinaryAction;
// If Windows, prepare additional vars for Disciplinary Action.
#if defined WIN32
float g_flNewDiscilplinaryAllySpeedBuffTimer = 3.0;
// Address of our float:
Address AddressOf_g_flNewDiscilplinaryAllySpeedBuffTimer;
#endif

MemoryPatch patch_RevertDragonsFury_CenterHitForBonusDmg;

MemoryPatch patch_RevertMiniguns_RampupNerf_Dmg;
MemoryPatch patch_RevertMiniguns_RampupNerf_Spread;
MemoryPatch patch_RevertWrangler_WrenchRepairNerf;
MemoryPatch patch_RevertWrangler_WrenchRefillNerf_Shells;
MemoryPatch patch_RevertWrangler_WrenchRefillNerf_Rockets;
MemoryPatch patch_RevertCozyCamper_FlinchNerf;
MemoryPatch patch_RevertQuickFix_Uber_CannotCapturePoint;

// Changes float addr to point to our plugin declared "AddressOf_g_flDalokohsBarCanOverHealTo"
MemoryPatch patch_RevertDalokohsBar_ChgFloatAddr; 
// Changes a MOV to 400. Basically it's for setup of the function that deals with
// Consuming Dalokohs bar.
MemoryPatch patch_RevertDalokohsBar_ChgTo400;
float g_flDalokohsBarCanOverHealTo = 400.0; // Float to use for Dalokohs Bar revert
// Address of our float to use for the MOVSS part of revert:
Address AddressOf_g_flDalokohsBarCanOverHealTo;

Handle sdkcall_AwardAchievement;
DHookSetup dHooks_CTFProjectile_Arrow_BuildingHealingArrow;

Handle dhook_CTFAmmoPack_MakeHolidayPack;
MemoryPatch Patch_DroppedWeapon;
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

Player players[MAXPLAYERS+1];
Entity entities[2048];
int frame;
Handle hudsync;
// Menu menu_pick;
int rocket_create_entity;
int rocket_create_frame;

//cookies
Cookie g_hClientMessageCookie;

//weapon caching
//this would break if you ever enabled picking up weapons from the ground!
//add weapons to the FRONT of this enum to maintain the player_weapons array size
enum
{
	//Generic class features
	Feat_Airblast,
	Feat_Minigun, // All Miniguns
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
	Wep_CozyCamper,
	Wep_Claidheamh,
	Wep_CleanerCarbine,
	Wep_CritCola,
	Wep_Dalokoh,
	Wep_Darwin,
	Wep_DeadRinger,	
	Wep_Degreaser,
	Wep_Disciplinary,
	Wep_DragonFury,
	Wep_Enforcer,
	Wep_Pickaxe, // Equalizer
	Wep_Eviction,
	Wep_FistsSteel,
	Wep_Cleaver, // Flying Guillotine
	Wep_MarketGardener,
	Wep_GRU,
	Wep_Gunboats,
	Wep_Zatoichi, // Half-Zatoichi
	Wep_Jag,
	Wep_LibertyLauncher,
	Wep_LochLoad,
	Wep_LooseCannon,
	Wep_Natascha,
	Wep_PanicAttack,
	Wep_Persian,
	Wep_PocketPistol,
	Wep_Pomson,
	Wep_Powerjack,
	Wep_QuickFix,
	Wep_Quickiebomb,
	Wep_Razorback,
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

#define MAX_VARIANTS 4 // not including base version
char items_desc[NUM_ITEMS][MAX_VARIANTS+1][256];

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

	LoadTranslations("reverts.phrases.txt");

#if defined GIT_COMMIT
	CreateConVar("sm_reverts__version", PLUGIN_VERSION_GIT, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));
#else
	CreateConVar("sm_reverts__version", PLUGIN_VERSION, (PLUGIN_NAME ... " - Version"), (FCVAR_NOTIFY|FCVAR_DONTRECORD));
#endif

	cvar_enable = CreateConVar("sm_reverts__enable", "1", (PLUGIN_NAME ... " - Enable plugin"), _, true, 0.0, true, 1.0);
	cvar_extras = CreateConVar("sm_reverts__extras", "0", (PLUGIN_NAME ... " - Enable some fun extra features"), _, true, 0.0, true, 1.0);
	cvar_old_falldmg_sfx = CreateConVar("sm_reverts__old_falldmg_sfx", "1", (PLUGIN_NAME ... " - Enable old (pre-inferno) fall damage sound (old bone crunch, no hurt voicelines)"), _, true, 0.0, true, 1.0);
	cvar_dropped_weapon_enable = CreateConVar("sm_reverts__enable_dropped_weapon", "0", (PLUGIN_NAME ... " - Revert dropped weapon behaviour"), _, true, 0.0, true, 1.0);
	cvar_no_reverts_info_by_default = CreateConVar("sm_reverts__no_reverts_info_on_spawn", "0", (PLUGIN_NAME ... " - Disable loadout change reverts info by default"), _, true, 0.0, true, 1.0);

	cvar_dropped_weapon_enable.AddChangeHook(OnDroppedWeaponCvarChange);

	ItemDefine("airblast", "Airblast_PreJI", CLASSFLAG_PYRO, Feat_Airblast);
	ItemDefine("airstrike", "Airstrike_PreTB", CLASSFLAG_SOLDIER, Wep_Airstrike);
#if defined MEMORY_PATCHES
	ItemDefine("miniramp", "Minigun_ramp_PreLW", CLASSFLAG_HEAVY, Feat_Minigun);
#endif
	ItemDefine("swords", "Swords_PreTB", CLASSFLAG_DEMOMAN, Feat_Sword);
	ItemDefine("ambassador", "Ambassador_PreJI", CLASSFLAG_SPY, Wep_Ambassador);
	ItemDefine("atomizer", "Atomizer_PreJI", CLASSFLAG_SCOUT, Wep_Atomizer);
	ItemDefine("axtinguish", "Axtinguisher_PreLW", CLASSFLAG_PYRO, Wep_Axtinguisher);
	ItemVariant(Wep_Axtinguisher, "Axtinguisher_PreTB");
	ItemDefine("backburner", "Backburner_PreHat", CLASSFLAG_PYRO, Wep_Backburner);
	ItemVariant(Wep_Backburner, "Backburner_119");
	ItemDefine("basejump", "BaseJumper_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN, Wep_BaseJumper);
	ItemDefine("babyface", "BabyFace_PreGM", CLASSFLAG_SCOUT, Wep_BabyFace);
	ItemVariant(Wep_BabyFace, "BabyFace_Release");
	ItemDefine("beggars", "Beggars_Pre2013", CLASSFLAG_SOLDIER, Wep_Beggars);
	ItemDefine("blackbox", "BlackBox_PreGM", CLASSFLAG_SOLDIER, Wep_BlackBox);
	ItemDefine("bonk", "Bonk_PreJI", CLASSFLAG_SCOUT, Wep_Bonk);
	ItemDefine("booties", "Booties_PreMYM", CLASSFLAG_DEMOMAN, Wep_Booties);
	ItemDefine("brassbeast", "BrassBeast_PreMYM", CLASSFLAG_HEAVY, Wep_BrassBeast);
	ItemDefine("bushwacka", "Bushwacka_PreLW", CLASSFLAG_SNIPER, Wep_Bushwacka);
	ItemDefine("buffalosteak", "BuffaloSteak_PreMYM", CLASSFLAG_HEAVY, Wep_BuffaloSteak);
	ItemVariant(Wep_BuffaloSteak, "BuffaloSteak_Release");
	ItemVariant(Wep_BuffaloSteak, "BuffaloSteak_Pre2013");
	ItemDefine("targe", "Targe_PreTB", CLASSFLAG_DEMOMAN, Wep_CharginTarge);
	ItemDefine("claidheamh", "Claidheamh_PreTB", CLASSFLAG_DEMOMAN, Wep_Claidheamh);
	ItemDefine("carbine", "Carbine_Release", CLASSFLAG_SNIPER, Wep_CleanerCarbine);
#if defined MEMORY_PATCHES
	ItemDefine("cozycamper","CozyCamper_PreMYM", CLASSFLAG_SNIPER, Wep_CozyCamper);
#endif
	ItemDefine("critcola", "CritCola_PreMYM", CLASSFLAG_SCOUT, Wep_CritCola);
	ItemDefine("crocostyle", "CrocoStyle_Release", CLASSFLAG_SNIPER, Set_CrocoStyle);
#if defined MEMORY_PATCHES
	ItemDefine("dalokohsbar", "DalokohsBar_PreMYM", CLASSFLAG_HEAVY, Wep_Dalokoh);
#endif
	ItemDefine("darwin", "Darwin_Pre2013", CLASSFLAG_SNIPER, Wep_Darwin);
	ItemVariant(Wep_Darwin, "Darwin_PreJI");
	ItemDefine("ringer", "Ringer_PreGM", CLASSFLAG_SPY, Wep_DeadRinger);
	ItemDefine("degreaser", "Degreaser_PreTB", CLASSFLAG_PYRO, Wep_Degreaser);
#if defined MEMORY_PATCHES
	ItemDefine("disciplinary", "Disciplinary_PreMYM", CLASSFLAG_SOLDIER, Wep_Disciplinary);
#endif
#if defined MEMORY_PATCHES
	ItemDefine("dragonfury", "DragonFury_Release", CLASSFLAG_PYRO, Wep_DragonFury);
#else
	ItemDefine("dragonfury", "DragonFury_Release_Patchless", CLASSFLAG_PYRO, Wep_DragonFury);
#endif
	ItemDefine("enforcer", "Enforcer_PreGM", CLASSFLAG_SPY, Wep_Enforcer);
	ItemVariant(Wep_Enforcer, "Enforcer_Release");
	ItemDefine("equalizer", "Equalizer_PrePyro", CLASSFLAG_SOLDIER, Wep_Pickaxe);
	ItemVariant(Wep_Pickaxe, "Equalizer_PreHat");
	ItemVariant(Wep_Pickaxe, "Equalizer_Release");
	ItemDefine("eviction", "Eviction_PreJI", CLASSFLAG_HEAVY, Wep_Eviction);
	ItemVariant(Wep_Eviction, "Eviction_PreMYM");
	ItemDefine("expert", "Expert_Release", CLASSFLAG_DEMOMAN, Set_Expert);
	ItemDefine("fiststeel", "FistSteel_PreJI", CLASSFLAG_HEAVY, Wep_FistsSteel);
	ItemDefine("guillotine", "Guillotine_PreJI", CLASSFLAG_SCOUT, Wep_Cleaver);
	ItemDefine("gasjockey", "GasJockey_Release", CLASSFLAG_PYRO, Set_GasJockey);
	ItemDefine("glovesru", "GlovesRU_PreTB", CLASSFLAG_HEAVY, Wep_GRU);
	ItemVariant(Wep_GRU, "GlovesRU_PrePyro");
	ItemDefine("gunboats", "Gunboats_Release", CLASSFLAG_SOLDIER, Wep_Gunboats);
	ItemDefine("zatoichi", "Zatoichi_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_DEMOMAN, Wep_Zatoichi);
	ItemDefine("hibernate", "Hibernate_Release", CLASSFLAG_HEAVY, Set_Hibernate);
	ItemDefine("jag", "Jag_PreTB", CLASSFLAG_ENGINEER, Wep_Jag);
	ItemVariant(Wep_Jag, "Jag_PreGM");  
	ItemDefine("liberty", "Liberty_Release", CLASSFLAG_SOLDIER, Wep_LibertyLauncher);
	ItemDefine("lochload", "LochLoad_PreGM", CLASSFLAG_DEMOMAN, Wep_LochLoad);
	ItemVariant(Wep_LochLoad, "LochLoad_2013");
	ItemDefine("cannon", "Cannon_PreTB", CLASSFLAG_DEMOMAN, Wep_LooseCannon);
	ItemDefine("gardener", "Gardener_PreTB", CLASSFLAG_SOLDIER, Wep_MarketGardener);
	ItemDefine("natascha", "Natascha_PreMYM", CLASSFLAG_HEAVY, Wep_Natascha);
	ItemDefine("panic", "Panic_PreJI", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO | CLASSFLAG_HEAVY | CLASSFLAG_ENGINEER, Wep_PanicAttack);
	ItemDefine("persuader", "Persuader_PreTB", CLASSFLAG_DEMOMAN, Wep_Persian);
	ItemDefine("pomson", "Pomson_PreGM", CLASSFLAG_ENGINEER, Wep_Pomson);
	ItemVariant(Wep_Pomson, "Pomson_Release");
	ItemDefine("powerjack", "Powerjack_PreGM", CLASSFLAG_PYRO, Wep_Powerjack);
	ItemVariant(Wep_Powerjack, "Powerjack_Release");
	ItemVariant(Wep_Powerjack, "Powerjack_Pre2013");	
	ItemDefine("pocket", "Pocket_Release", CLASSFLAG_SCOUT, Wep_PocketPistol);
	ItemVariant(Wep_PocketPistol, "Pocket_PreBM");
#if defined MEMORY_PATCHES
	ItemDefine("quickfix", "Quickfix_PreTB", CLASSFLAG_MEDIC, Wep_QuickFix);
#else
	ItemDefine("quickfix", "Quickfix_PreMYM", CLASSFLAG_MEDIC, Wep_QuickFix);
#endif
	ItemDefine("quickiebomb", "Quickiebomb_PreMYM", CLASSFLAG_DEMOMAN, Wep_Quickiebomb);
	ItemDefine("razorback","Razorback_PreJI", CLASSFLAG_SNIPER, Wep_Razorback);
#if defined MEMORY_PATCHES
	ItemDefine("rescueranger", "RescueRanger_PreGM", CLASSFLAG_ENGINEER, Wep_RescueRanger);
#endif
	ItemDefine("reserve", "Reserve_PreTB", CLASSFLAG_SOLDIER | CLASSFLAG_PYRO, Wep_ReserveShooter);
	ItemVariant(Wep_ReserveShooter, "Reserve_PreJI");
	ItemDefine("bison", "Bison_PreMYM", CLASSFLAG_SOLDIER, Wep_Bison);
	ItemDefine("rocketjmp", "RocketJmp_Pre2013", CLASSFLAG_SOLDIER, Wep_RocketJumper);
	ItemVariant(Wep_RocketJumper, "RocketJmp_Pre2013_Intel");
	ItemDefine("saharan", "Saharan_Release", CLASSFLAG_SPY, Set_Saharan);
	ItemDefine("sandman", "Sandman_PreJI", CLASSFLAG_SCOUT, Wep_Sandman);
	ItemDefine("scottish", "Scottish_Release", CLASSFLAG_DEMOMAN, Wep_Scottish);
	ItemDefine("circuit", "Circuit_PreMYM", CLASSFLAG_ENGINEER, Wep_ShortCircuit);
	ItemVariant(Wep_ShortCircuit, "Circuit_PreGM");
	ItemDefine("shortstop", "Shortstop_PreMnvy_Shove", CLASSFLAG_SCOUT, Wep_Shortstop);
	ItemVariant(Wep_Shortstop, "Shortstop_PreMnvy");
	ItemVariant(Wep_Shortstop, "Shortstop_PreGM_Shove");
	ItemVariant(Wep_Shortstop, "Shortstop_PreGM");
	ItemDefine("sodapop", "Sodapop_Pre2013", CLASSFLAG_SCOUT, Wep_SodaPopper);
	ItemVariant(Wep_SodaPopper, "Sodapop_PreMYM");
	ItemDefine("solemn", "Solemn_PreGM", CLASSFLAG_MEDIC, Wep_Solemn);
	ItemDefine("spdelivery", "SpDelivery_Release", CLASSFLAG_SCOUT, Set_SpDelivery);
	ItemDefine("splendid", "Splendid_PreTB", CLASSFLAG_DEMOMAN, Wep_SplendidScreen);
	ItemDefine("spycicle", "SpyCicle_PreGM", CLASSFLAG_SPY, Wep_Spycicle);
	ItemDefine("stkjumper", "StkJumper_Pre2013", CLASSFLAG_DEMOMAN, Wep_StickyJumper);
	ItemVariant(Wep_StickyJumper, "StkJumper_Pre2013_Intel");
	ItemDefine("sleeper", "Sleeper_PreBM", CLASSFLAG_SNIPER, Wep_SydneySleeper);
	ItemDefine("turner", "Turner_PreTB", CLASSFLAG_DEMOMAN, Wep_TideTurner);
	ItemDefine("tomislav", "Tomislav_PrePyro", CLASSFLAG_HEAVY, Wep_Tomislav);
	ItemVariant(Wep_Tomislav, "Tomislav_Release");
	ItemDefine("tribalshiv", "TribalShiv_Release", CLASSFLAG_SNIPER, Wep_TribalmansShiv);
	ItemDefine("caber", "Caber_PreGM", CLASSFLAG_DEMOMAN, Wep_Caber);
	ItemDefine("vitasaw", "VitaSaw_PreJI", CLASSFLAG_MEDIC, Wep_VitaSaw);
	ItemDefine("warrior", "Warrior_PreTB", CLASSFLAG_HEAVY, Wep_WarriorSpirit);
#if defined MEMORY_PATCHES
	ItemDefine("wrangler", "Wrangler_PreGM", CLASSFLAG_ENGINEER, Wep_Wrangler);
#endif
	ItemDefine("eternal", "Eternal_PreJI", CLASSFLAG_SPY, Wep_EternalReward);

	ItemFinalize();

	AutoExecConfig(false, "reverts", "sourcemod");

	g_hClientMessageCookie = RegClientCookie("reverts_messageinfo_cookie","Weapon Reverts Message Info Cookie",CookieAccess_Protected);

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
	RegConsoleCmd("sm_toggleinfo", Command_ToggleInfo, (PLUGIN_NAME ... " - Toggle the revert info dump in chat when changing loadouts"), 0);

	HookEvent("player_spawn", OnGameEvent, EventHookMode_Post);
	HookEvent("player_death", OnGameEvent, EventHookMode_Pre);
	HookEvent("post_inventory_application", OnGameEvent, EventHookMode_Post);
	HookEvent("item_pickup", OnGameEvent, EventHookMode_Post);
#if defined MEMORY_PATCHES
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

#if defined MEMORY_PATCHES
	{
		conf = LoadGameConfigFile("memorypatch_reverts");

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

		patch_RevertMiniguns_RampupNerf_Dmg =
			MemoryPatch.CreateFromConf(conf,
			"CTFMinigun::GetProjectileDamage_JumpOver1SecondCheck");
		patch_RevertMiniguns_RampupNerf_Spread =
			MemoryPatch.CreateFromConf(conf,
			"CTFMinigun::GetWeaponSpread_JumpOver1SecondCheck");
		patch_RevertWrangler_WrenchRepairNerf =
			MemoryPatch.CreateFromConf(conf,
			"CObjectSentrygun::OnWrenchHit_ShieldPreNerfRepair");
		patch_RevertWrangler_WrenchRefillNerf_Shells =
			MemoryPatch.CreateFromConf(conf,
			"CObjectSentrygun::OnWrenchHit_ShieldPreNerfShellRefill");
		patch_RevertWrangler_WrenchRefillNerf_Rockets =
			MemoryPatch.CreateFromConf(conf,
			"CObjectSentrygun::OnWrenchHit_ShieldPreNerfRocketRefill");
		patch_RevertCozyCamper_FlinchNerf =
			MemoryPatch.CreateFromConf(conf,
			"CTFPlayer::ApplyPunchImpulseX_FakeFullyChargedCondition");
		patch_RevertQuickFix_Uber_CannotCapturePoint =
			MemoryPatch.CreateFromConf(conf,
			"CTFGameRules::PlayerMayCapturePoint_QuickFixUberCanCapturePoint");
		patch_RevertDalokohsBar_ChgFloatAddr =
			MemoryPatch.CreateFromConf(conf,
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOVSS_AddrTo_400");
		patch_RevertDalokohsBar_ChgTo400 =
			MemoryPatch.CreateFromConf(conf,
			"CTFLunchBox::ApplyBiteEffect_Dalokohs_MOV_400");

		Patch_DroppedWeapon = MemoryPatch.CreateFromConf(conf, "CTFPlayer::DropAmmoPack");
		dhook_CTFAmmoPack_MakeHolidayPack = DHookCreateFromConf(conf, "CTFAmmoPack::MakeHolidayPack");
		DHookEnableDetour(dhook_CTFAmmoPack_MakeHolidayPack, false, DHookCallback_CTFAmmoPack_MakeHolidayPack);
		if (dhook_CTFAmmoPack_MakeHolidayPack == null) SetFailState("Failed to create dhook_CTFAmmoPack_MakeHolidayPack");

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CBaseMultiplayerPlayer::AwardAchievement");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		sdkcall_AwardAchievement = EndPrepSDKCall();

		dHooks_CTFProjectile_Arrow_BuildingHealingArrow = DHookCreateFromConf(conf, "CTFProjectile_Arrow::BuildingHealingArrow");

		DHookEnableDetour(dHooks_CTFProjectile_Arrow_BuildingHealingArrow, false, PreHealingBoltImpact);
		DHookEnableDetour(dHooks_CTFProjectile_Arrow_BuildingHealingArrow, true, PostHealingBoltImpact);

		if (sdkcall_AwardAchievement == null) SetFailState("Failed to create sdkcall_AwardAchievement");
		if (!ValidateAndNullCheck(patch_RevertDisciplinaryAction)) SetFailState("Failed to create patch_RevertDisciplinaryAction");

		if (!ValidateAndNullCheck(patch_RevertDragonsFury_CenterHitForBonusDmg)) SetFailState("Failed to create patch_RevertDragonsFury_CenterHitForBonusDmg");

		if (!ValidateAndNullCheck(patch_RevertMiniguns_RampupNerf_Dmg)) SetFailState("Failed to create patch_RevertMiniguns_RampupNerf_Dmg");
		if (!ValidateAndNullCheck(patch_RevertMiniguns_RampupNerf_Spread)) SetFailState("Failed to create patch_RevertMiniguns_RampupNerf_Spread");
		if (!ValidateAndNullCheck(patch_RevertWrangler_WrenchRepairNerf)) SetFailState("Failed to create patch_RevertWrangler_WrenchRepairNerf");
		if (!ValidateAndNullCheck(patch_RevertWrangler_WrenchRefillNerf_Shells)) SetFailState("Failed to create patch_RevertWrangler_WrenchRefillNerf_Shells");
		if (!ValidateAndNullCheck(patch_RevertWrangler_WrenchRefillNerf_Rockets)) SetFailState("Failed to create patch_RevertWrangler_WrenchRefillNerf_Rockets");
		if (!ValidateAndNullCheck(patch_RevertCozyCamper_FlinchNerf)) SetFailState("Failed to create patch_RevertCozyCamper_FlinchNerf");
		if (!ValidateAndNullCheck(patch_RevertQuickFix_Uber_CannotCapturePoint)) SetFailState("Failed to create patch_RevertQuickFix_Uber_CannotCapturePoint");
		if (!ValidateAndNullCheck(patch_RevertDalokohsBar_ChgFloatAddr)) SetFailState("Failed to create patch_RevertDalokohsBar_ChgFloatAddr");
		if (!ValidateAndNullCheck(patch_RevertDalokohsBar_ChgTo400)) SetFailState("Failed to create patch_RevertDalokohsBar_ChgTo400");
		if (!ValidateAndNullCheck(Patch_DroppedWeapon)) SetFailState("Failed to create Patch_DroppedWeapon");
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

public void OnDroppedWeaponCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	// weapon pickups are disabled to ensure attribute consistency
	SetConVarMaybe(cvar_ref_tf_dropped_weapon_lifetime, "0", !convar.BoolValue);
	if (convar.BoolValue) {
		Patch_DroppedWeapon.Enable();
	} else {
		Patch_DroppedWeapon.Disable();
	}
}

public void OnConfigsExecuted() {
#if defined MEMORY_PATCHES
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_Disciplinary),Wep_Disciplinary);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_DragonFury),Wep_DragonFury);
	ToggleMemoryPatchReverts(ItemIsEnabled(Feat_Minigun),Feat_Minigun);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_Wrangler),Wep_Wrangler);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_CozyCamper),Wep_CozyCamper);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_QuickFix),Wep_QuickFix);
	ToggleMemoryPatchReverts(ItemIsEnabled(Wep_Dalokoh),Wep_Dalokoh);
#endif
	OnDroppedWeaponCvarChange(cvar_dropped_weapon_enable, "0", "0");
}

#if defined MEMORY_PATCHES
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
		for (int i; i < NUM_ITEMS; i++) {
			if (StrEqual(items[i].key,item)) {
				ToggleMemoryPatchReverts(ItemIsEnabled(i),i);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
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
		case Feat_Minigun: {
			if (enable) {
				patch_RevertMiniguns_RampupNerf_Dmg.Enable();
				patch_RevertMiniguns_RampupNerf_Spread.Enable();
			} else {
				patch_RevertMiniguns_RampupNerf_Dmg.Disable();
				patch_RevertMiniguns_RampupNerf_Spread.Disable();
			}
		}
		case Wep_Wrangler: {
			if (enable) {
				patch_RevertWrangler_WrenchRepairNerf.Enable();
				patch_RevertWrangler_WrenchRefillNerf_Shells.Enable();
				patch_RevertWrangler_WrenchRefillNerf_Rockets.Enable();
			} else {
				patch_RevertWrangler_WrenchRepairNerf.Disable();
				patch_RevertWrangler_WrenchRefillNerf_Shells.Disable();
				patch_RevertWrangler_WrenchRefillNerf_Rockets.Disable();
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
		case Wep_Dalokoh: {
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
								if (ItemIsEnabled(Wep_Atomizer)) {
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
								players[idx].scout_airdash_count == 2 &&
								ItemIsEnabled(Wep_Atomizer)
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
						// shortstop shove removal

						if (GetItemVariant(Wep_Shortstop) == 1 || GetItemVariant(Wep_Shortstop) == 3) {
							weapon = GetEntPropEnt(idx, Prop_Send, "m_hActiveWeapon");

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_handgun_scout_primary")) {
									// disable secondary attack
									// this is somewhat broken, can still shove by holding m2 when reload ends
									SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", (GetGameTime() + 1.0));
								}
							}
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

						if (ItemIsEnabled(Wep_SodaPopper))
						{
							if (
								GetItemVariant(Wep_SodaPopper) == 0 &&
								players[idx].is_under_hype
							) {
								// allow mini-crit buff to last indefinitely
								SetEntPropFloat(idx, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
							}

							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Primary);

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
									ItemIsEnabled(Wep_Beggars) &&
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

				if (TF2_GetPlayerClass(idx) == TFClass_Engineer) {
					{
						// short circuit alt-fire prevention
						if (GetItemVariant(Wep_ShortCircuit) == 1)
						{
							weapon = GetPlayerWeaponSlot(idx, TFWeaponSlot_Secondary);

							if (weapon > 0) {
								GetEntityClassname(weapon, class, sizeof(class));

								if (StrEqual(class, "tf_weapon_mechanical_arm")) {
									SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", (GetGameTime() + 1.0));
								}
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
									ItemIsEnabled(Wep_SydneySleeper) &&
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

								if (ItemIsEnabled(Wep_DeadRinger)) {
									// when uncloaking, cloak is drained to 40%

									if (GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter") > 40.0) {
										SetEntPropFloat(idx, Prop_Send, "m_flCloakMeter", 40.0);
									}
								}
							}
						}

						cloak = GetEntPropFloat(idx, Prop_Send, "m_flCloakMeter");

						if (ItemIsEnabled(Wep_DeadRinger)) {
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
							ItemIsEnabled(Wep_DeadRinger) &&
							players[idx].spy_is_feigning &&
							GetFeignBuffsEnd(idx) < GetGameTickCount() &&
							TF2_IsPlayerInCondition(idx, TFCond_DeadRingered)
						) {
							TF2_RemoveCondition(idx, TFCond_DeadRingered);
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

					{
						// parachute redeploy & updraft

						if (TF2_IsPlayerInCondition(idx, TFCond_Parachute)) {
							players[idx].parachute_cond_time = GetGameTime();

							if (
								ItemIsEnabled(Wep_BaseJumper) &&
								TF2_IsPlayerInCondition(idx, TFCond_OnFire) &&
								GetEntProp(idx, Prop_Data, "m_nWaterLevel") == 0
							) {
								GetEntPropVector(idx, Prop_Data, "m_vecVelocity", pos1);

								if (pos1[2] < cvar_ref_tf_parachute_maxspeed_onfire_z.FloatValue) {
									pos1[2] = cvar_ref_tf_parachute_maxspeed_onfire_z.FloatValue;

									// don't use TeleportEntity to avoid the trigger re-entry bug
									SetEntPropVector(idx, Prop_Data, "m_vecAbsVelocity", pos1);
								}
							}
						} else {
							if (
								TF2_IsPlayerInCondition(idx, TFCond_ParachuteDeployed) &&
								(GetGameTime() - players[idx].parachute_cond_time) > 0.2 &&
								ItemIsEnabled(Wep_BaseJumper)
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
				players[idx].player_jumped = false;
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
			ResetConVar(cvar_ref_tf_airblast_cray);
			ResetConVar(cvar_ref_tf_feign_death_duration);
			ResetConVar(cvar_ref_tf_feign_death_speed_duration);
			ResetConVar(cvar_ref_tf_feign_death_activate_damage_scale);
			ResetConVar(cvar_ref_tf_feign_death_damage_scale);

			// these cvars are global, set them to the desired value
			SetConVarMaybe(cvar_ref_tf_bison_tick_time, "0.001", ItemIsEnabled(Wep_Bison));
			SetConVarMaybe(cvar_ref_tf_fireball_radius, "30.0", ItemIsEnabled(Wep_DragonFury));
			SetConVarMaybe(cvar_ref_tf_parachute_aircontrol, "5", ItemIsEnabled(Wep_BaseJumper));
			// By setting tf_parachute_maxspeed_onfire_z = 10.0, fire updraft is back again. Valve set this to -100 for some reason by default.
			SetConVarMaybe(cvar_ref_tf_parachute_maxspeed_onfire_z, "10.0", ItemIsEnabled(Wep_BaseJumper));
		}
	}
}

public void OnClientConnected(int client) {
	// reset these per player
	//players[client].respawn = 0;
	players[client].resupply_time = 0.0;
	players[client].medic_medigun_defidx = 0;
	players[client].medic_medigun_charge = 0.0;
	players[client].parachute_cond_time = 0.0;
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
		// dead ringer stuff

		if (
			ItemIsEnabled(Wep_DeadRinger) &&
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
			TF2_AddCondition(client, TFCond_MarkedForDeathSilent); // historically didn't have the Marked-for-Death symbol in HUD, but a visual cue is good
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
			!TF2_IsPlayerInCondition(client, TFCond_CritCola) &&
			!TF2_IsPlayerInCondition(client, TFCond_RestrictToMelee) &&
			TF2_IsPlayerInCondition(client, TFCond_MarkedForDeathSilent)
		) {
			TF2_RemoveCondition(client, TFCond_MarkedForDeathSilent);
		}			
	}

}

public Action TF2_OnAddCond(int client, TFCond &condition, float &time, int &provider) {
	{
		// prevent speed boost being applied on feign death
		if (
			ItemIsEnabled(Wep_DeadRinger) &&
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
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.30); // fire rate penalty
			TF2Items_SetAttribute(itemNew, 1, 138, 0.80); // dmg penalty vs players
			TF2Items_SetAttribute(itemNew, 2, 250, 0.0); // air dash count
			TF2Items_SetAttribute(itemNew, 3, 773, 1.0); // single wep deploy time increased
		}}
		case 38, 457, 1000: { if (ItemIsEnabled(Wep_Axtinguisher)) {
			TF2Items_SetNumAttributes(itemNew, 5);
			TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // damage penalty
			TF2Items_SetAttribute(itemNew, 1, 21, 0.50); // dmg penalty vs nonburning
			TF2Items_SetAttribute(itemNew, 2, 772, 1.00); // single wep holster time increased
			TF2Items_SetAttribute(itemNew, 3, 2067, 0.0); // attack minicrits and consumes burning
			TF2Items_SetAttribute(itemNew, 4, GetItemVariant(Wep_Axtinguisher) == 1 ? 638 : 20, 1.0); // axtinguisher properties, crit on burning players
		}}
		case 772: { if (ItemIsEnabled(Wep_BabyFace)) {
			bool release = GetItemVariant(Wep_BabyFace) == 1;
			TF2Items_SetNumAttributes(itemNew, release ? 6 : 2);
			TF2Items_SetAttribute(itemNew, 0, 733, 0.0); // lose hype on take damage
			if (release)
			{
				TF2Items_SetAttribute(itemNew, 1, 1, 0.70); // damage penalty
				TF2Items_SetAttribute(itemNew, 2, 3, 1.00); // clip size penalty
				TF2Items_SetAttribute(itemNew, 3, 54, 0.65); // move speed penalty
				TF2Items_SetAttribute(itemNew, 4, 106, 0.60); // weapon spread bonus
				TF2Items_SetAttribute(itemNew, 5, 419, 100.0); // hype resets on jump
			}
			else
			{
				TF2Items_SetAttribute(itemNew, 1, 419, 25.0); // hype resets on jump
			}
		}}
		case 40, 1146: { if (ItemIsEnabled(Wep_Backburner)) {
			bool airblast = GetItemVariant(Wep_Backburner) == 0;
			TF2Items_SetNumAttributes(itemNew, airblast ? 1 : 2);
			if (airblast) {
				TF2Items_SetAttribute(itemNew, 0, 2, 1.1); // 10% damage bonus
			} else {
				TF2Items_SetAttribute(itemNew, 0, 2, 1.2); // 20% damage bonus
				TF2Items_SetAttribute(itemNew, 1, 356, 1.0); // no airblast
			}
		}}
		case 237: { if (GetItemVariant(Wep_RocketJumper) == 1) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 400, 0.0);
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
		case 312: { if (ItemIsEnabled(Wep_BrassBeast)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 738, 1.00); // spunup damage resistance
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
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 128, 0.0); // provide on active
			TF2Items_SetAttribute(itemNew, 1, 412, 1.00); // 0% damage vulnerability on wearer
			TF2Items_SetAttribute(itemNew, 2, 15, 1.0); // random crits enabled
			TF2Items_SetAttribute(itemNew, 3, 61, 1.20); // 20% fire damage vulnerability on wearer
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
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 31, 3.0); // crit on kill
			TF2Items_SetAttribute(itemNew, 1, 779, 0.0); // minicrit on charge
			TF2Items_SetAttribute(itemNew, 2, 780, 0.0); // gain charge on hit
			TF2Items_SetAttribute(itemNew, 3, 5, 1.35); // 35% firing speed penalty
		}}
		case 327: { if (ItemIsEnabled(Wep_Claidheamh)) {
			bool swords = ItemIsEnabled(Feat_Sword);
			TF2Items_SetNumAttributes(itemNew, swords ? 5 : 3);
			TF2Items_SetAttribute(itemNew, 0, 412, 1.00); // dmg taken
			TF2Items_SetAttribute(itemNew, 1, 128, 0.0); // provide on active
			TF2Items_SetAttribute(itemNew, 2, 125, -15.0); // max health additive penalty
			// sword holster code handled here
			if (swords) {
				TF2Items_SetAttribute(itemNew, 3, 781, 0.0); // is a sword
				TF2Items_SetAttribute(itemNew, 4, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
			}
			sword_reverted = true;
		}}
		case 163: { if (ItemIsEnabled(Wep_CritCola)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 814, 0.0); // no mark-for-death on attack
			TF2Items_SetAttribute(itemNew, 1, 798, 1.10); // +10% damage vulnerability while under the effect
		}}
		case 231: { if (ItemIsEnabled(Wep_Darwin)) {
			bool dmg_mods = GetItemVariant(Wep_Darwin) == 1;
			TF2Items_SetNumAttributes(itemNew, dmg_mods ? 5 : 3);
			TF2Items_SetAttribute(itemNew, 0, 60, 1.0); // +0% fire damage resistance on wearer
			TF2Items_SetAttribute(itemNew, 1, 527, 0.0); // remove afterburn immunity
			TF2Items_SetAttribute(itemNew, 2, 26, 25.0); // +25 max health on wearer
			if (dmg_mods) {
				TF2Items_SetAttribute(itemNew, 3, 66, 0.85); // +15% bullet damage resistance on wearer
				TF2Items_SetAttribute(itemNew, 4, 65, 1.20); // 20% explosive damage vulnerability on wearer
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
			bool releaseVer = GetItemVariant(Wep_Enforcer) == 1;
			TF2Items_SetNumAttributes(itemNew, releaseVer ? 6 : 3);
			TF2Items_SetAttribute(itemNew, 0, 797, 0.0); // dmg pierces resists absorbs
			TF2Items_SetAttribute(itemNew, 1, 2, 1.20); // 20% damage bonus
			// When the Spy fires while disguised, he gives less damage to both players and buildings.
			if (releaseVer) {
				TF2Items_SetAttribute(itemNew, 2, 5, 1.00); // increase back the firing rate to same as stock revolver; fire rate penalty attribute
				TF2Items_SetAttribute(itemNew, 3, 15, 1.0); // add back random crits; crit mod enabled 
				TF2Items_SetAttribute(itemNew, 4, 253, 0.5); // 0.5 sec increase in time taken to cloak
				TF2Items_SetAttribute(itemNew, 5, 410, 1.0); // remove damage bonus while disguised
			} else {
				TF2Items_SetAttribute(itemNew, 2, 410, 1.0 / 1.2); // -16.667% damage bonus while disguised; cancels out the 20% dmg bonus to make it 0% total
			}
		}}
		case 128, 775: { if (ItemIsEnabled(Wep_Pickaxe)) {
			TF2Items_SetNumAttributes(itemNew, 4);
			TF2Items_SetAttribute(itemNew, 0, 236, 1.0); // mod weapon blocks healing
			TF2Items_SetAttribute(itemNew, 1, 414, 0.0); // self mark for death
			TF2Items_SetAttribute(itemNew, 2, 740, 1.0); // reduced healing from medics
			TF2Items_SetAttribute(itemNew, 3, index == 128 ? 115 : 235, 2.0); // mod shovel damage boost
		}}
		case 225, 574: { if (ItemIsEnabled(Wep_EternalReward)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 34, 1.00); // mult cloak meter consume rate
			TF2Items_SetAttribute(itemNew, 1, 155, 1.00); // cannot disguise
		}}		
		case 426: { if (ItemIsEnabled(Wep_Eviction)) {
			bool gunMettleVer = GetItemVariant(Wep_Eviction) == 1;
			TF2Items_SetNumAttributes(itemNew, gunMettleVer ? 3 : 2);
			TF2Items_SetAttribute(itemNew, 0, 855, 0.0); // mod maxhealth drain rate
			if (gunMettleVer) {
				TF2Items_SetAttribute(itemNew, 1, 851, 1.00); // +0% faster move speed on wearer; mult_player_movespeed_active
				TF2Items_SetAttribute(itemNew, 2, 6, 0.50); // set faster firing speed to +50%; 
			} else {
				TF2Items_SetAttribute(itemNew, 1, 852, 1.20); // dmg taken increased
			}
			// Eviction Notice stacking speedboost on hit with reverted Buffalo Steak Sandvich handled elsewhere
		}}
		case 331: { if (ItemIsEnabled(Wep_FistsSteel)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 853, 1.0); // mult patient overheal penalty active
			TF2Items_SetAttribute(itemNew, 1, 854, 1.0); // mult health fromhealers penalty active
		}}
		case 416: { if (ItemIsEnabled(Wep_MarketGardener)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.0); // fire rate penalty
		}}
		case 239, 1084, 1100: { if (ItemIsEnabled(Wep_GRU)) {
			TF2Items_SetNumAttributes(itemNew, 4);
			switch (GetItemVariant(Wep_GRU)) {
				case 0: {
					// Pre-Tough Break version of the GRU
					TF2Items_SetAttribute(itemNew, 0, 1, 0.75); // damage penalty
					TF2Items_SetAttribute(itemNew, 1, 414, 3.0); // self mark for death
					TF2Items_SetAttribute(itemNew, 2, 772, 1.0); // single wep holster time increased
					TF2Items_SetAttribute(itemNew, 3, 855, 0.0); // mod maxhealth drain rate
				}
				case 1: {
					// Pre-Pyromania version of the GRU
					TF2Items_SetAttribute(itemNew, 0, 1, 0.50); // 50% damage penalty
					TF2Items_SetAttribute(itemNew, 1, 191, -6.0); // drain 6HP/s while actve; small knockback while active is supposed to happen (called GRU jumping)
					TF2Items_SetAttribute(itemNew, 2, 772, 1.0); // single wep holster time is normal
					TF2Items_SetAttribute(itemNew, 3, 855, 0.0); // mod maxhealth drain rate
				}
			}
		}}
		case 133: { if (ItemIsEnabled(Wep_Gunboats)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 135, 0.25); // -75% blast damage from rocket jumps
		}}			
		case 812, 833: { if (ItemIsEnabled(Wep_Cleaver)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 437, 65536.0); // crit vs stunned players
		}}
		case 329: { if (ItemIsEnabled(Wep_Jag)) {
			bool preToughBreak = GetItemVariant(Wep_Jag) == 1;
			TF2Items_SetNumAttributes(itemNew, preToughBreak ? 3 : 1);
			TF2Items_SetAttribute(itemNew, 0, 775, 1.00); // -0% damage penalty vs buildings
			if (preToughBreak) {
				TF2Items_SetAttribute(itemNew, 1, 6, 1.00); // +0% faster firing speed
				TF2Items_SetAttribute(itemNew, 2, 95, 1.00); // -0% slower repair rate
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
			bool pre2014 = GetItemVariant(Wep_LochLoad) == 1;
			TF2Items_SetNumAttributes(itemNew, pre2014 ? 6 : 2);
			TF2Items_SetAttribute(itemNew, 0, 2, 1.20); // damage bonus
			TF2Items_SetAttribute(itemNew, 1, 137, 1.00); // dmg bonus vs buildings
			if (pre2014) {
				TF2Items_SetAttribute(itemNew, 2, 207, 1.25); // self damage
				TF2Items_SetAttribute(itemNew, 3, 100, 1.00); // radius penalty
				TF2Items_SetAttribute(itemNew, 4, 3, 0.50); // clip size
				TF2Items_SetAttribute(itemNew, 5, 681, 0.00); // grenade no spin
			}
		}}
		case 41: { if (ItemIsEnabled(Wep_Natascha)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 738, 1.00); // spunup damage resistance
		}}
		case 1153: { if (ItemIsEnabled(Wep_PanicAttack)) {
			TF2Items_SetNumAttributes(itemNew, 11);
			TF2Items_SetAttribute(itemNew, 0, 1, 1.00); // 0% damage penalty
			TF2Items_SetAttribute(itemNew, 1, 45, 1.00); // +0% bullets per shot
			TF2Items_SetAttribute(itemNew, 2, 808, 0.00); // Successive shots become less accurate
			TF2Items_SetAttribute(itemNew, 3, 809, 0.00); // Fires a wide, fixed shot pattern

			TF2Items_SetAttribute(itemNew, 4, 97, 0.50); // 50% faster reload time
			TF2Items_SetAttribute(itemNew, 5, 394, 0.70); // 30% faster firing speed
			TF2Items_SetAttribute(itemNew, 6, 424, 0.66); // -34% clip size
			TF2Items_SetAttribute(itemNew, 7, 651, 0.50); // Fire rate increases as health decreases.
			TF2Items_SetAttribute(itemNew, 8, 708, 1.00); // Hold fire to load up to 4 shells
			TF2Items_SetAttribute(itemNew, 9, 709, 2.5); // Weapon spread increases as health decreases.
			TF2Items_SetAttribute(itemNew, 10, 710, 1.00); // Attrib_AutoFiresFullClipNegative
		}}
		case 773: { if (ItemIsEnabled(Wep_PocketPistol)) {
			bool release = GetItemVariant(Wep_PocketPistol) == 0;
			TF2Items_SetNumAttributes(itemNew, release ? 8 : 1);
			if (release) {
				TF2Items_SetAttribute(itemNew, 0, 6, 1.0); // fire rate bonus
				TF2Items_SetAttribute(itemNew, 1, 16, 0.0); // heal on hit
				TF2Items_SetAttribute(itemNew, 2, 3, 1.0); // clip size
				TF2Items_SetAttribute(itemNew, 3, 5, 1.25); // fire rate penalty
				TF2Items_SetAttribute(itemNew, 4, 128, 0.0); // provide on active
				TF2Items_SetAttribute(itemNew, 5, 26, 15.0); // max health additive bonus
				TF2Items_SetAttribute(itemNew, 6, 275, 1.0); // cancel falling damage
				TF2Items_SetAttribute(itemNew, 7, 61, 1.50); // dmg taken from fire increased
			} else {
				TF2Items_SetAttribute(itemNew, 0, 16, 7.0); // On Hit: Gain up to +7 health
			}
		}}
		case 588: { if (ItemIsEnabled(Wep_Pomson) && GetItemVariant(Wep_Pomson) == 1) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 283, 1.0); // energy_weapon_penetration; NOTE: turns pomson projectile into bison projectile
		}}		
		case 214: { if (ItemIsEnabled(Wep_Powerjack)) {
			// health bonus with overheal for all variants handled elsewhere
			switch (GetItemVariant(Wep_Powerjack)) {
				case 0: {
					// Pre-Gun Mettle Powerjack (pre-2015)
					TF2Items_SetNumAttributes(itemNew, 1);
					TF2Items_SetAttribute(itemNew, 0, 180, 0.0); // remove +25 hp on kill attribute
					}
				case 1: {
					// Release Powerjack (2010)
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 180, 0.0); // remove +25 hp on kill attribute
					TF2Items_SetAttribute(itemNew, 1, 107, 1.00); // remove faster move speed on wearer while active
					TF2Items_SetAttribute(itemNew, 2, 412, 1.0); // remove damage vulnerability on wearer while active 
					TF2Items_SetAttribute(itemNew, 3, 2, 1.25); // add +25% damage bonus
					TF2Items_SetAttribute(itemNew, 4, 15, 0.0); // no random crits mod
					}
				case 2: {
					// Hatless Update Powerjack (2011 to 2013)
					TF2Items_SetNumAttributes(itemNew, 4);
					TF2Items_SetAttribute(itemNew, 0, 180, 0.0); // remove +25 hp on kill attribute
					TF2Items_SetAttribute(itemNew, 1, 107, 1.00); // remove faster move speed on wearer while active
					TF2Items_SetAttribute(itemNew, 2, 412, 1.0); // remove damage vulnerability on wearer while active 
					TF2Items_SetAttribute(itemNew, 3, 206, 1.20); // add +20% damage from melee sources while active 
				}
			}
		}}
		case 404: { if (ItemIsEnabled(Wep_Persian)) {
			bool swords = ItemIsEnabled(Feat_Sword);
			TF2Items_SetNumAttributes(itemNew, swords ? 8 : 6);
			TF2Items_SetAttribute(itemNew, 0, 77, 1.00); // -0% max primary ammo on wearer
			TF2Items_SetAttribute(itemNew, 1, 79, 1.00); // -0% max secondary ammo on wearer
			TF2Items_SetAttribute(itemNew, 2, 778, 0.00); // remove "Melee hits refill 20% of your charge meter" attribute
			TF2Items_SetAttribute(itemNew, 3, 782, 0.0); // remove "Ammo boxes collected also give Charge"
			TF2Items_SetAttribute(itemNew, 4, 249, 2.00); // +100% increase in charge recharge rate, shields should take around 6 seconds to charge with persuader
			TF2Items_SetAttribute(itemNew, 5, 258, 1.0); // Ammo collected from ammo boxes becomes health (doesn't work, using two DHooks instead)
			if (swords) {
				TF2Items_SetAttribute(itemNew, 6, 781, 0.0); // is a sword
				TF2Items_SetAttribute(itemNew, 7, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
			}
			sword_reverted = true;
		}}
		case 57: { if (ItemIsEnabled(Wep_Razorback)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 800, 1.0); //overheal penalty
			TF2Items_SetAttribute(itemNew, 1, 874, 10000.0); //shield regen time. big number so it never respawns
		}}
		case 411: { if (ItemIsEnabled(Wep_QuickFix)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 10, 1.25); // +25% ÜberCharge rate
		}}
		case 1150: { if (ItemIsEnabled(Wep_Quickiebomb)) {
			TF2Items_SetNumAttributes(itemNew, 4); // attributes ported from NotnHeavy's pre-Gun Mettle plugin
			TF2Items_SetAttribute(itemNew, 0, 727, 1.25); // Up to +25% damage based on charge
			TF2Items_SetAttribute(itemNew, 1, 3, 0.75); // -25% clip size
			TF2Items_SetAttribute(itemNew, 2, 669, 4.00); // Stickybombs fizzle 4 seconds after landing
			TF2Items_SetAttribute(itemNew, 3, 670, 0.50); // Max charge time decreased by 50%
		}}		
#if defined MEMORY_PATCHES
		case 997: { if (ItemIsEnabled(Wep_RescueRanger)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 469, 130.0); //ranged pickup metal cost
		}}
#endif
		case 415: { if (GetItemVariant(Wep_ReserveShooter) == 0) {
			TF2Items_SetNumAttributes(itemNew, 3);
			TF2Items_SetAttribute(itemNew, 0, 114, 0.0); // mod mini-crit airborne
			TF2Items_SetAttribute(itemNew, 1, 178, 0.85); // 15% faster weapon switch
			TF2Items_SetAttribute(itemNew, 2, 547, 1.0); // This weapon deploys 0% faster
		}}
		case 59: { if (ItemIsEnabled(Wep_DeadRinger)) {
			TF2Items_SetNumAttributes(itemNew, 5);
			TF2Items_SetAttribute(itemNew, 0, 35, 1.8); // mult cloak meter regen rate
			TF2Items_SetAttribute(itemNew, 1, 82, 1.6); // cloak consume rate increased
			TF2Items_SetAttribute(itemNew, 2, 83, 1.0); // cloak consume rate decreased
			TF2Items_SetAttribute(itemNew, 3, 726, 1.0); // cloak consume on feign death activate
			TF2Items_SetAttribute(itemNew, 4, 810, 0.0); // mod cloak no regen from items
		}}
		case 44: { if (ItemIsEnabled(Wep_Sandman)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 278, 1.50); //effect bar recharge rate increased attribute; this number increases ball recharge time from 10s to 15s
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
				case 0, 1: {
					// Pre-Manniversary Shortstop
					TF2Items_SetNumAttributes(itemNew, 5);
					TF2Items_SetAttribute(itemNew, 0, 76, 1.125); // 12.5% max primary ammo on wearer, reverts max ammo back to 36, required for ammo sharing to work
					TF2Items_SetAttribute(itemNew, 1, 241, 1.0); // reload time increased hidden
					TF2Items_SetAttribute(itemNew, 2, 534, 1.00); // airblast vulnerability multiplier hidden
					TF2Items_SetAttribute(itemNew, 3, 535, 1.00); // damage force increase hidden
					TF2Items_SetAttribute(itemNew, 4, 536, 1.00); // damage force increase text
				}
				case 2, 3: {
					// Pre-Gun Mettle Shortstop
					TF2Items_SetNumAttributes(itemNew, 6);
					TF2Items_SetAttribute(itemNew, 1, 526, 1.20); // 20% bonus healing from all sources
					TF2Items_SetAttribute(itemNew, 2, 534, 1.40); // airblast vulnerability multiplier hidden
					TF2Items_SetAttribute(itemNew, 3, 535, 1.40); // damage force increase hidden
					TF2Items_SetAttribute(itemNew, 4, 536, 1.40); // damage force increase text
					TF2Items_SetAttribute(itemNew, 5, 128, 0.0); // disable provide_on_active so push force penalty is active at all times
				}
			}	
		}}
		case 230: { if (ItemIsEnabled(Wep_SydneySleeper)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 42, 0.0); // sniper no headshots
			TF2Items_SetAttribute(itemNew, 1, 175, 0.0); // jarate duration
		}}
		case 448: { if (ItemIsEnabled(Wep_SodaPopper)) {
			bool minicrits = GetItemVariant(Wep_SodaPopper) == 0;
			TF2Items_SetNumAttributes(itemNew, minicrits ? 2 : 1);
			TF2Items_SetAttribute(itemNew, 0, 793, 0.0); // hype on damage
			if (minicrits) {
				TF2Items_SetAttribute(itemNew, 1, 15, 0.0); // crit mod disabled
			}
		}}
		case 413: { if (ItemIsEnabled(Wep_Solemn)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 5, 1.0); // fire rate penalty
		}}
		case 406: { if (ItemIsEnabled(Wep_SplendidScreen)) {
			TF2Items_SetNumAttributes(itemNew, 3);
			TF2Items_SetAttribute(itemNew, 0, 64, 0.85); // dmg taken from blast reduced
			TF2Items_SetAttribute(itemNew, 1, 249, 1.00); // remove +50% increase in charge recharge rate
			TF2Items_SetAttribute(itemNew, 2, 247, 1.0); // can deal charge impact damage at any range
		}}
		case 649: { if (ItemIsEnabled(Wep_Spycicle)) {
			TF2Items_SetNumAttributes(itemNew, 1);
			TF2Items_SetAttribute(itemNew, 0, 156, 1.0); // silent killer
		}}
		case 265: { if (ItemIsEnabled(Wep_StickyJumper)) {
			bool flag_pickup = GetItemVariant(Wep_StickyJumper) == 1;
			TF2Items_SetNumAttributes(itemNew, flag_pickup ? 2 : 1);
			TF2Items_SetAttribute(itemNew, 0, 89, 0.0); // max pipebombs decreased
			if (flag_pickup) {
				TF2Items_SetAttribute(itemNew, 1, 400, 0.0);
			}
		}}
		case 131, 1144: { if (ItemIsEnabled(Wep_CharginTarge)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 64, 0.6); // dmg taken from blast reduced
			TF2Items_SetAttribute(itemNew, 1, 527, 1.0); // afterburn immunity
		}}
		case 424: { if (ItemIsEnabled(Wep_Tomislav)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			// 75% minigun spinup time decreased on release
			// 40% minigun spinup time decreased on current
			// mult_minigun_spinup_time
			TF2Items_SetAttribute(itemNew, 0, 87, GetItemVariant(Wep_Tomislav) == 1 ? 0.25 : 0.60);
			TF2Items_SetAttribute(itemNew, 1, 106, 1.0); // 0% accuracy attribute; weapon spread bonus; mult_spread_scale
			// Note: It is recommended for the minigun ramp-up revert to be active so that the reverted pre-Pyromania Tomislav is historically and functionally accurate!
		}}
		case 1099: { if (ItemIsEnabled(Wep_TideTurner)) {
			TF2Items_SetNumAttributes(itemNew, 3);
			TF2Items_SetAttribute(itemNew, 0, 676, 0.0); // lose demo charge on damage when charging
			TF2Items_SetAttribute(itemNew, 1, 60, 0.75); // 25% fire damage resistance on wearer
			TF2Items_SetAttribute(itemNew, 2, 64, 0.75); // 25% explosive damage resistance on wearer
		}}
		case 171: { if (ItemIsEnabled(Wep_TribalmansShiv)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 149, 8.0); // bleed duration
			TF2Items_SetAttribute(itemNew, 1, 1, 0.65); // dmg penalty
		}}
		case 173: { if (ItemIsEnabled(Wep_VitaSaw)) {
			TF2Items_SetNumAttributes(itemNew, 2);
			TF2Items_SetAttribute(itemNew, 0, 188, 20.0); // preserve ubercharge (doesn't work)
			TF2Items_SetAttribute(itemNew, 1, 811, 0.0); // ubercharge preserved on spawn max
		}}
		case 310: { if (ItemIsEnabled(Wep_WarriorSpirit)) {
			TF2Items_SetNumAttributes(itemNew, 5);
			TF2Items_SetAttribute(itemNew, 0, 412, 1.0); // damage vuln
			TF2Items_SetAttribute(itemNew, 1, 180, 0.0); // heal on kill
			TF2Items_SetAttribute(itemNew, 2, 110, 10.0); // heal on hit
			TF2Items_SetAttribute(itemNew, 3, 128, 0.0); // provide on active
			TF2Items_SetAttribute(itemNew, 4, 125, -20.0); // max health additive penalty
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
		( StrEqual(class, "tf_weapon_sword") ||
		(!ItemIsEnabled(Wep_Zatoichi) && (index == 357)) )
	) {
		TF2Items_SetNumAttributes(itemNew, 2);
		TF2Items_SetAttribute(itemNew, 0, 781, 0.0); // is a sword
		TF2Items_SetAttribute(itemNew, 1, 264, 1.0); // melee range multiplier; 1.0 somehow corresponds to 72 hammer units from testing
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

#if defined MEMORY_PATCHES
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
#endif

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
							ItemIsEnabled(Wep_Zatoichi) &&
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
							ItemIsEnabled(Wep_Ambassador) &&
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
							ItemIsEnabled(Wep_Powerjack) &&
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
							ItemIsEnabled(Wep_SydneySleeper) &&
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
				weapon = GetEntPropEnt(client,Prop_Send,"m_hMyWeapons",i);
				if (weapon != -1)
				{
					GetEntityClassname(weapon, class, sizeof(class));
					index = GetEntProp(weapon,Prop_Send,"m_iItemDefinitionIndex");

					if (
						(index != 594) &&
						(StrEqual(class, "tf_weapon_flamethrower") ||
						StrEqual(class, "tf_weapon_rocketlauncher_fireball"))
					) {
						player_weapons[client][Feat_Airblast] = true;
					}

					else if (
						StrEqual(class, "tf_weapon_minigun")
					) {
						player_weapons[client][Feat_Minigun] = true;
					}

					else if (
						( StrEqual(class, "tf_weapon_sword") ||
						(!ItemIsEnabled(Wep_Zatoichi) && StrEqual(class, "tf_weapon_katana")) )
					) {
						player_weapons[client][Feat_Sword] = true;
					}

					switch (index) {
						case 1104:player_weapons[client][Wep_Airstrike] = true;
						case 61: player_weapons[client][Wep_Ambassador] = true;
						case 1006: player_weapons[client][Wep_Ambassador] = true;
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
						case 159, 433: player_weapons[client][Wep_Dalokoh] = true;
						case 447: player_weapons[client][Wep_Disciplinary] = true;
						case 1178: player_weapons[client][Wep_DragonFury] = true;
						case 996: player_weapons[client][Wep_LooseCannon] = true;
						case 751: player_weapons[client][Wep_CleanerCarbine] = true;
						case 327: player_weapons[client][Wep_Claidheamh] = true;
						case 163: player_weapons[client][Wep_CritCola] = true;
						case 215: player_weapons[client][Wep_Degreaser] = true;
						case 460: player_weapons[client][Wep_Enforcer] = true;
						case 128, 775: player_weapons[client][Wep_Pickaxe] = true;
						case 225, 574: player_weapons[client][Wep_EternalReward] = true;
						case 426: player_weapons[client][Wep_Eviction] = true;
						case 331: player_weapons[client][Wep_FistsSteel] = true;
						case 416: player_weapons[client][Wep_MarketGardener] = true;
						case 239, 1084, 1100: player_weapons[client][Wep_GRU] = true;
						case 812, 833: player_weapons[client][Wep_Cleaver] = true;
						case 329: player_weapons[client][Wep_Jag] = true;
						case 414: player_weapons[client][Wep_LibertyLauncher] = true;
						case 308: player_weapons[client][Wep_LochLoad] = true;
						case 41: player_weapons[client][Wep_Natascha] = true;
						case 1153: player_weapons[client][Wep_PanicAttack] = true;
						case 773: player_weapons[client][Wep_PocketPistol] = true;
						case 588: player_weapons[client][Wep_Pomson] = true;
						case 214: player_weapons[client][Wep_Powerjack] = true;
						case 404: player_weapons[client][Wep_Persian] = true;
						case 411: player_weapons[client][Wep_QuickFix] = true;
						case 1150: player_weapons[client][Wep_Quickiebomb] = true;
						case 997: player_weapons[client][Wep_RescueRanger] = true;
						case 415: player_weapons[client][Wep_ReserveShooter] = true;
						case 59: player_weapons[client][Wep_DeadRinger] = true;
						case 44: player_weapons[client][Wep_Sandman] = true;
						case 130: player_weapons[client][Wep_Scottish] = true;
						case 230: player_weapons[client][Wep_SydneySleeper] = true;
						case 448: player_weapons[client][Wep_SodaPopper] = true;
						case 413: player_weapons[client][Wep_Solemn] = true;
						case 528: player_weapons[client][Wep_ShortCircuit] = true;
						case 649: player_weapons[client][Wep_Spycicle] = true;
						case 265: player_weapons[client][Wep_StickyJumper] = true;
						case 424: player_weapons[client][Wep_Tomislav] = true;
						case 171: player_weapons[client][Wep_TribalmansShiv] = true;
						case 173: player_weapons[client][Wep_VitaSaw] = true;
						case 310: player_weapons[client][Wep_WarriorSpirit] = true;
						case 140, 1086, 30668: player_weapons[client][Wep_Wrangler] = true;
						case 357: player_weapons[client][Wep_Zatoichi] = true;
						case 220: {
							player_weapons[client][Wep_Shortstop] = true;
							if (ItemIsEnabled(Wep_Shortstop)) {
								int SCOUT_PISTOL_AMMO_TYPE = 2;
								SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", SCOUT_PISTOL_AMMO_TYPE);
							}
						}
					}
				}
			}
			int num_wearables = TF2Util_GetPlayerWearableCount(client);
			for (int i = 0; i < num_wearables; i++)
			{
				int wearable = TF2Util_GetPlayerWearable(client, i);
				GetEntityClassname(wearable, class, sizeof(class));
				index = GetEntProp(wearable,Prop_Send,"m_iItemDefinitionIndex");

				switch (index) {
					case 405, 608: player_weapons[client][Wep_Booties] = true;
					case 642: player_weapons[client][Wep_CozyCamper] = true;
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
					TF2Attrib_SetByDefIndex(client, 517, 0.0); // SET BONUS: max health additive bonus
				}
				case TFClass_Pyro:
				{
					TF2Attrib_SetByDefIndex(client, 489, 1.0); // SET BONUS: move speed set bonus
					TF2Attrib_SetByDefIndex(client, 516, 1.0); // SET BONUS: dmg taken from bullets increased 
				}
				case TFClass_DemoMan:
				{
					TF2Attrib_SetByDefIndex(client, 492, 1.0); // SET BONUS: dmg taken from fire reduced set bonus
				}
				case TFClass_Heavy:
				{
					TF2Attrib_SetByDefIndex(client, 491, 1.0); // SET BONUS: dmg taken from crit reduced set bonus
				}
				case TFClass_Sniper:
				{
					TF2Attrib_SetByDefIndex(client, 176, 0.0); // SET BONUS: no death from headshots
				}
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

					switch(item_index) {
						// Special Delivery
						case 220, 221, 222: {
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
							if(ItemIsEnabled(Set_Saharan)) {
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
					// this code can also be used if you want cosmetics to be a part of item sets
					int num_wearables = TF2Util_GetPlayerWearableCount(client);
					for (int i = 0; i < num_wearables; i++)
					{
						int wearable = TF2Util_GetPlayerWearable(client, i);
						int item_index = GetEntProp(wearable,Prop_Send,"m_iItemDefinitionIndex");
						if (
							// This code only checks for Darwin's Danger Shield (231)
							(item_index == 231)
						) {
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
				bool has_lunchbox = (player_weapons[client][Wep_Bonk] || player_weapons[client][Wep_CritCola]);
				if (has_lunchbox)
				{
					players[client].is_under_hype = false;
					TF2_AddCondition(client, TFCond_CritHype, 11.0, 0);
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
							ItemIsEnabled(Wep_Pomson) &&
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
						if (ItemIsEnabled(Wep_DeadRinger)) {
							cvar_ref_tf_feign_death_duration.FloatValue = 6.5;
							cvar_ref_tf_feign_death_speed_duration.FloatValue = 6.5;
							cvar_ref_tf_feign_death_activate_damage_scale.FloatValue = 0.10;
							cvar_ref_tf_feign_death_damage_scale.FloatValue = 0.10;
						} else {
							ResetConVar(cvar_ref_tf_feign_death_duration);
							ResetConVar(cvar_ref_tf_feign_death_speed_duration);
							ResetConVar(cvar_ref_tf_feign_death_activate_damage_scale);
							ResetConVar(cvar_ref_tf_feign_death_damage_scale);
						}
					}
				}

				// dead ringer track when feign begins
				if (ItemIsEnabled(Wep_DeadRinger)) {
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
					ItemIsEnabled(Wep_Caber) &&
					StrEqual(class, "tf_weapon_stickbomb")
				) {
					if (
						damage_custom == TF_DMG_CUSTOM_NONE &&
						damage == 55.0
					) {
						// melee damage is always 35
						damage = 35.0;
						LogMessage("Caber melee damage for %N attacking %N - %d, %f", attacker, victim, damage_custom, damage);
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

						LogMessage("Caber explosion damage for %N attacking %N", attacker, victim);
						return Plugin_Changed;
					}
					LogMessage("Caber damage passed through for %N attacking %N - %d, %f", attacker, victim, damage_custom, damage);
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
				// loch-n-load damage spread
				
				if (
					GetItemVariant(Wep_LochLoad) == 1 &&
					StrEqual(class, "tf_weapon_grenadelauncher") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 308
				) {
					// don't apply spread on crits
					if (damage_type & DMG_CRIT != 0)
						return Plugin_Continue;
					
					// apply ±15% damage variance
					damage *= GetRandomFloat(0.85, 1.15);
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

					if(GetItemVariant(Wep_Pickaxe) == 0) // Pre-Pyromania Equalizer (pre-June 27, 2012); 107 dmg at 1 hp
						damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), 1.65, 0.5));
					else if(GetItemVariant(Wep_Pickaxe) == 1) // Pre-Hatless Update Equalizer (pre-April 14, 2011); 113 dmg at 1 hp
						damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), 1.75, 0.5));
					else if(GetItemVariant(Wep_Pickaxe) == 2) // Release Equalizer (pre-April 15, 2010); 162 dmg at 1 hp
						damage = (damage * ValveRemapVal(float(health_cur), 0.0, float(health_max), 2.50, 0.5));

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
							TF2_IsPlayerInCondition(victim, TFCond_KnockedIntoAir) == true)
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
				// sandman stun

				if (
					ItemIsEnabled(Wep_Sandman) &&
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

									if (cvar_extras.BoolValue) {
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
					ItemIsEnabled(Wep_SydneySleeper) &&
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
				if (
					ItemIsEnabled(Wep_BlackBox) &&
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
							
							// this prevents energy projectiles from hitting the same enemy too much and killing them too quickly	
							if (
								StrEqual(class, "tf_weapon_raygun") || 
								(GetItemVariant(Wep_Pomson) && StrEqual(class, "tf_weapon_drg_pomson") && GetItemVariant(Wep_Pomson) == 1) // check for release pomson variant
							) {
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

									// Bug fix to trigger Dead Ringer feign death from distances greater than 512 hammer units
									// This drains 20% cloak from distances greater than 512 hammer units on feign,
									// But for some reason when its less than 512 hammer units, ~70% cloak is drained.
									// Because w/ vanilla DR, 50% cloak is removed when less than 512 HU with the Pomson. So 50% + 20% = 70% cloak reduction
									// Need to investigate more in older TF2 builds.
									if (
										damage1 > 0 && 
										GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") &&
										players[victim].spy_is_feigning == false
									) {
										TF2_AddCondition(victim, TFCond_DeadRingered);
									}									
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
			if (
				((ItemIsEnabled(Wep_BrassBeast) && player_weapons[victim][Wep_BrassBeast]) ||
				(ItemIsEnabled(Wep_Natascha) && player_weapons[victim][Wep_Natascha])) &&
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
				ItemIsEnabled(Wep_RocketJumper) &&
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
			ItemIsEnabled(Wep_RocketJumper) &&
			victim == attacker &&
			damage_custom == TF_DMG_CUSTOM_TAUNTATK_GRENADE &&
			player_weapons[victim][Wep_RocketJumper]
		) {
			// set back saved health after tauntkill
			SetEntityHealth(victim, players[victim].old_health);
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
	if (TF2_GetPlayerClass(client) == TFClass_Scout) {
		if (
			GetItemVariant(Wep_BabyFace) == 1 &&
			player_weapons[client][Wep_BabyFace]
		) {
			// Release Baby Face's Blaster boost reset on jump
			switch (buttons & IN_JUMP != 0)
			{
				case true:
				{
					if (!players[client].player_jumped)
					{
						if (
							GetEntPropFloat(client, Prop_Send, "m_flHypeMeter") > 0.0 && 
							GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1 && // don't reset if swimming 
							buttons & IN_DUCK == 0 && // don't reset if crouching
							(GetEntityFlags(client) & FL_ONGROUND) != 0 // don't reset if airborne
							// the attrib for reducing boost will reset for air jumps
						) {
							SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", 0.0);
							// apply the following so movement gets reset immediately, maybe there's a better way
							TF2Attrib_AddCustomPlayerAttribute(client, "move speed penalty", 0.99, 0.001);
						}
						players[client].player_jumped = true;
					}
				}
				case false:
				{
					players[client].player_jumped = false;
				}
			}
		}
	}
	
	return Plugin_Continue;
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
		menu_main.Display(client, ITEM_MENU_TIME);
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

void SetConVarMaybe(Handle cvar, const char[] value, bool maybe) {
	maybe ? SetConVarString(cvar, value) : ResetConVar(cvar);
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

/**
 * Define an item used for reverts.
 * 
 * @param key				Key for item used for the cvar and as the item name key in
 * 							the translation file.
 * @param desc				Key for description of the item in the translation file.
 * @param flags				Class flags.
 * @param wep_enum			Weapon enum, this identifies a weapon.
 */
void ItemDefine(char[] key, char[] desc, int flags, int wep_enum) {
	strcopy(items[wep_enum].key, sizeof(items[].key), key);
	strcopy(items_desc[wep_enum][0], sizeof(items_desc[][]), desc);
	items[wep_enum].flags = flags;
	items[wep_enum].num_variants = 0;
}

/**
 * Define an item variant.
 * 
 * @param wep_enum		Weapon enum.
 * @param desc			Key for description of the item variant in the translation file.
 */
void ItemVariant(int wep_enum, char[] desc) {
	int variant_idx = ++items[wep_enum].num_variants;
	strcopy(items_desc[wep_enum][variant_idx], sizeof(items_desc[][]), desc);
}

void ItemFinalize() {
	int idx;
	char cvar_name[64];
	char cvar_desc[256];

	for (idx = 0; idx < NUM_ITEMS; idx++) {
		if (items[idx].cvar != null) {
			SetFailState("Tried to initialize items more than once");
		}

		if (items[idx].num_variants > MAX_VARIANTS) {
			SetFailState("Tried to initialize an item with more than %d variants", MAX_VARIANTS);
		}

		Format(cvar_name, sizeof(cvar_name), "sm_reverts__item_%s", items[idx].key);
		Format(cvar_desc, sizeof(cvar_desc), (PLUGIN_NAME ... " - Revert nerfs to %T"), items[idx].key, LANG_SERVER);

		items[idx].cvar = CreateConVar(cvar_name, "1", cvar_desc, FCVAR_NOTIFY, true, 0.0, true, float(items[idx].num_variants + 1));
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
				ShowItemsDetails(param1);
			}
			else if (StrEqual(info, "classinfo")) {
				ShowClassReverts(param1);
			}
			else if (StrEqual(info, "infotoggle")) {
				ToggleLoadoutInfo(param1);
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
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
		int config_value = g_hClientMessageCookie.GetInt(client, cvar_no_reverts_info_by_default ? 1 : 0);
		if (config_value) {
			ReplyToCommand(client, "%t", "REVERT_LOADOUT_CHANGE_ENABLED");
		} else {
			ReplyToCommand(client, "%t", "REVERT_LOADOUT_CHANGE_DISABLED");
		}
		g_hClientMessageCookie.SetInt(client, config_value ? 0 : 1);
	}
}

#if defined MEMORY_PATCHES
int HealBuilding(int buildingIndex, int engineerIndex) {
	float RepairAmountFloat = 75.0; //It's Sigafoo save time BABY!
	RepairAmountFloat = fmin(RepairAmountFloat,float(GetEntProp(buildingIndex, Prop_Data, "m_iMaxHealth") - GetEntProp(buildingIndex, Prop_Data, "m_iHealth")));
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
		event.SetInt("amount", currentHealth - newHealth); // Repairamount to display. Will be something between 1-75.

		event.Fire(); // FIRE IN THE HOLE!!!!!!!
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

// Get the sentry of a specific engineer
// WARNING: Do not use in MVM!

int FindSentryGunOwnedByClient(int client)
{
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


#endif

MRESReturn DHookCallback_CTFWeaponBase_PrimaryAttack(int entity) {
	int owner;
	char class[64];
	int metal;

	if (GetItemVariant(Wep_ShortCircuit) == 1) {
		GetEntityClassname(entity, class, sizeof(class));
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (
			owner > 0 &&
			StrEqual(class, "tf_weapon_mechanical_arm")
		) {
			// short circuit primary fire

			metal = GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);

			if (metal >= (5 + BALANCE_CIRCUIT_METAL)) {
				DoShortCircuitProjectileRemoval(owner, entity, true);
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
				DoShortCircuitProjectileRemoval(owner, entity, false);
			}

			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

void DoShortCircuitProjectileRemoval(int owner, int entity, bool consume_per_destroyed) {
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

	if (!consume_per_destroyed) SetEntProp(owner, Prop_Data, "m_iAmmo", (metal - BALANCE_CIRCUIT_METAL), 4, 3);

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
									if (!consume_per_destroyed)
										SDKHooks_TakeDamage(idx, entity, owner, BALANCE_CIRCUIT_DAMAGE, DMG_SHOCK, entity, NULL_VECTOR, target_pos, false);
								} else {
									// delete projectiles
									if (consume_per_destroyed)
									{
										metal = GetEntProp(owner, Prop_Data, "m_iAmmo", 4, 3);
										if (metal < (5 + BALANCE_CIRCUIT_METAL)) break;
										SetEntProp(owner, Prop_Data, "m_iAmmo", (metal - BALANCE_CIRCUIT_METAL), 4, 3);
									}
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
				ItemIsEnabled(Wep_Airstrike) &&
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
		entity >= 1 &&
		entity <= MaxClients &&
		IsValidEntity(entity) &&
		IsClientInGame(entity)
	) {
		if (TF2_GetPlayerClass(entity) == TFClass_Scout) {
			float multiplier = 1.0;
			if (
				ItemIsEnabled(Wep_CritCola) &&
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

MRESReturn DHookCallback_CTFPlayer_CanDisguise(int entity, Handle return_) {
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
	if (ItemIsEnabled(Wep_Persian) && player_weapons[client][Wep_Persian])
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
			SetEventInt(event, "amount", intMin(health_max - health, heal));
			SetEventInt(event, "entindex", client);
			FireEvent(event);

			// remove afterburn and bleed debuffs on heal
			if (TF2_IsPlayerInCondition(client, TFCond_OnFire) || TF2_IsPlayerInCondition(client, TFCond_Bleeding))
			{
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Bleeding);
			}

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
	if (ItemIsEnabled(Wep_Persian) && client > 0 && client <= MaxClients && player_weapons[client][Wep_Persian])
	{
		// Health pickup with the Persian Persuader from dropped ammo packs.
		int health = GetClientHealth(client);
		int health_max = SDKCall(sdkcall_GetMaxHealth, client);
		if (health < health_max)
		{
			// Show that the player got healed.
			Handle event = CreateEvent("player_healonhit", true);
			SetEventInt(event, "amount", intMin(health_max - health, 20));
			SetEventInt(event, "entindex", client);
			FireEvent(event);

			// remove afterburn and bleed debuffs on heal
			if (TF2_IsPlayerInCondition(client, TFCond_OnFire) || TF2_IsPlayerInCondition(client, TFCond_Bleeding))
			{
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Bleeding);
			}

			// Set health.
			SetEntityHealth(client, intMin(health + 20, health_max));
			// If you're wondering why EmitSoundToAll below is repeated in a different channel,
			// it's so it sounds louder to be like the actual in-game sound and because I can't increase the volume beyond 1.0 for some reason.
			EmitSoundToAll("items/ammo_pickup.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL); // If ammo_pickup sound doesn't play, this should make it play.
			EmitSoundToAll("items/ammo_pickup.wav", entity, SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_CHANGEPITCH | SND_CHANGEVOL); // and I am forced to do this to make it louder. I tried. Why?
			RemoveEntity(entity);
		}
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

#if defined MEMORY_PATCHES
MRESReturn PreHealingBoltImpact(int arrowEntity, DHookParam parameters)
{
	
	if (ItemIsEnabled(Wep_RescueRanger)) {
		int engineerIndex = GetEntityOwner(arrowEntity); // Get attacking entity.
		int weapon;
		char class[64];
		// Grab weapon.
		weapon = GetPlayerWeaponSlot(engineerIndex, TFWeaponSlot_Primary);

		if (weapon > 0) {
			GetEntityClassname(weapon, class, sizeof(class));

			if (
				StrEqual(class, "tf_weapon_shotgun_building_rescue") &&
				GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 997)
			{
				return MRES_Supercede; // Weapon is a Rescue Ranger, so we cancel pre to handle building healing in post.
			}
		}
	}
	// If fix is not enabled or if the "If" statements above failed, let the function proceed as normal.
	return MRES_Ignored;
}

MRESReturn PostHealingBoltImpact(int arrowEntity, DHookParam parameters) {
	if (ItemIsEnabled(Wep_RescueRanger)) {
		int buildingIndex = parameters.Get(1);
		int engineerIndex = GetEntityOwner(arrowEntity);


		int weapon;
		char class[64];
		// Grab weapon.
		weapon = GetPlayerWeaponSlot(engineerIndex, TFWeaponSlot_Primary);

		if (weapon > 0) {
			GetEntityClassname(weapon, class, sizeof(class));

				if (
					StrEqual(class, "tf_weapon_shotgun_building_rescue") &&
					GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 997)
				{
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
								AttachTEParticleToEntityAndSend(arrowEntity,1699,1); //Red
							} else {
								// [1696] repair_claw_heal_blue
								AttachTEParticleToEntityAndSend(arrowEntity,1696,1); // Blu
							}
						}
					}
					return MRES_Supercede;
				}
			}
		}

	// If fix is not enabled or if the "If" statements above failed, let the function proceed as normal.
	return MRES_Ignored;
}

MRESReturn DHookCallback_CTFAmmoPack_MakeHolidayPack(int pThis) {
	if (cvar_dropped_weapon_enable.BoolValue) {
		return MRES_Supercede;
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

/**
 * Get the smaller integer between two integers.
 * 
 * @param x		Integer x.
 * @param y		Integer y.
 * @return		The smaller integer between x and y.
 */
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
