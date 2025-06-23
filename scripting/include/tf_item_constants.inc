//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_ITEM_CONSTANTS
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_ITEM_CONSTANTS

#pragma semicolon true 
#pragma newdecls required

//////////////////////////////////////////////////////////////////////////////
// TF_ITEM_CONSTANTS.H DATA                                                 //
//////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------
// Weapon Types
//-----------------------------------------------------------------------------
enum
{
	TF_WPN_TYPE_PRIMARY = 0,
	TF_WPN_TYPE_SECONDARY,
	TF_WPN_TYPE_MELEE,
	TF_WPN_TYPE_GRENADE,
	TF_WPN_TYPE_BUILDING,
	TF_WPN_TYPE_PDA,
	TF_WPN_TYPE_ITEM1,
	TF_WPN_TYPE_ITEM2,
	TF_WPN_TYPE_HEAD,
	TF_WPN_TYPE_MISC,
	TF_WPN_TYPE_MELEE_ALLCLASS,
	TF_WPN_TYPE_SECONDARY2,
	TF_WPN_TYPE_PRIMARY2,


	//
	// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
	//

	TF_WPN_TYPE_COUNT,
};

//-----------------------------------------------------------------------------
// Purpose: Slots for items within loadouts
//-----------------------------------------------------------------------------
enum loadout_positions_t
{
	LOADOUT_POSITION_INVALID = -1,

	// Weapons & Equipment
	LOADOUT_POSITION_PRIMARY = 0,
	LOADOUT_POSITION_SECONDARY,
	LOADOUT_POSITION_MELEE,
	LOADOUT_POSITION_UTILITY,
	LOADOUT_POSITION_BUILDING,
	LOADOUT_POSITION_PDA,
	LOADOUT_POSITION_PDA2,

	// Wearables. If you add new wearable slots, make sure you add them to IsWearableSlot() below this.
	LOADOUT_POSITION_HEAD,
	LOADOUT_POSITION_MISC,

	// other
	LOADOUT_POSITION_ACTION,

	// More wearables, yay!
	LOADOUT_POSITION_MISC2,

	// taunts
	LOADOUT_POSITION_TAUNT,
	LOADOUT_POSITION_TAUNT2,
	LOADOUT_POSITION_TAUNT3,
	LOADOUT_POSITION_TAUNT4,
	LOADOUT_POSITION_TAUNT5,
	LOADOUT_POSITION_TAUNT6,
	LOADOUT_POSITION_TAUNT7,
	LOADOUT_POSITION_TAUNT8,

	CLASS_LOADOUT_POSITION_COUNT,
};

enum account_loadout_positions_t
{
	ACCOUNT_LOADOUT_POSITION_ACCOUNT1,
	ACCOUNT_LOADOUT_POSITION_ACCOUNT2,
	ACCOUNT_LOADOUT_POSITION_ACCOUNT3,

	ACCOUNT_LOADOUT_POSITION_COUNT,
};

stock bool IsMiscSlot( any iSlot )
{
	return iSlot == LOADOUT_POSITION_MISC
		|| iSlot == LOADOUT_POSITION_MISC2
		|| iSlot == LOADOUT_POSITION_HEAD;
}

stock bool IsBuildingSlot( any iSlot )
{
    return iSlot == LOADOUT_POSITION_BUILDING;
}

stock bool IsTauntSlot( any iSlot )
{
	return iSlot == LOADOUT_POSITION_TAUNT
		|| iSlot == LOADOUT_POSITION_TAUNT2
		|| iSlot == LOADOUT_POSITION_TAUNT3
		|| iSlot == LOADOUT_POSITION_TAUNT4
		|| iSlot == LOADOUT_POSITION_TAUNT5
		|| iSlot == LOADOUT_POSITION_TAUNT6
		|| iSlot == LOADOUT_POSITION_TAUNT7
		|| iSlot == LOADOUT_POSITION_TAUNT8;
}

stock bool IsWearableSlot( any iSlot ) 
{
	return iSlot == LOADOUT_POSITION_HEAD
		|| iSlot == LOADOUT_POSITION_MISC
		|| iSlot == LOADOUT_POSITION_ACTION
		|| IsMiscSlot( iSlot )
		|| IsTauntSlot( iSlot );
}

stock bool IsQuestSlot( any iSlot )
{
	return iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT1
		|| iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT2
		|| iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT3;
}

stock bool IsValidItemSlot( any iSlot )
{
	return iSlot > LOADOUT_POSITION_INVALID && iSlot < CLASS_LOADOUT_POSITION_COUNT;
}

stock bool IsValidPickupWeaponSlot( any iSlot )
{
	return iSlot == LOADOUT_POSITION_PRIMARY
		|| iSlot == LOADOUT_POSITION_SECONDARY
		|| iSlot == LOADOUT_POSITION_MELEE;
}

// The total number of loadouts to track for each player.
// Right now, hardcoded to match TF's 10 classes.
#define LOADOUT_COUNT					(10+1)	// 0th class is undefined

enum EHalloweenMap
{
	kHalloweenMap_MannManor,
	kHalloweenMap_Viaduct,
	kHalloweenMap_Lakeside,
	kHalloweenMap_Hightower,

	kHalloweenMapCount
};

enum EHalloweenGiftSpawnMetaInfo
{
	kHalloweenGiftMeta_IsUnderworldOnViaduct_DEPRECATED		= 0x01,
};