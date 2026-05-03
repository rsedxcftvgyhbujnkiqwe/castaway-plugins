#pragma semicolon 1
#pragma newdecls required

#include <tf2_stocks>
#include <sdktools>
#include <dhooks>
#include <tf2condhooks>

#define ptr 				Address
#define nullptr 			Address_Null
#define int(%1) 			view_as< int >(%1)
#define Address(%1) 		view_as< Address >(%1)

public Plugin myinfo = 
{
	name = "[TF2] Condition Manager", 
	author = "Scag", 
	description = "Condition add and removal control for developers", 
	version = "1.0.0", 
	url = "https://github.com/Scags/"
};

GlobalForward hAddCond;
GlobalForward hRemoveCond;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int max)
{
	hAddCond = new GlobalForward("TF2_OnAddCond", ET_Hook, Param_Cell, Param_CellByRef, Param_FloatByRef, Param_CellByRef);
	hRemoveCond = new GlobalForward("TF2_OnRemoveCond", ET_Hook, Param_Cell, Param_CellByRef, Param_FloatByRef, Param_CellByRef);
	RegPluginLibrary("tf2condhooks");
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData conf = new GameData("tf2.condmgr");
	Handle h = DHookCreateDetourEx(conf, "CTFPlayerShared::AddCond", CallConv_THISCALL, ReturnType_Void, ThisPointer_Address);
	DHookAddParam(h, HookParamType_Int);
	DHookAddParam(h, HookParamType_Float);
	DHookAddParam(h, HookParamType_Int);	// Pass as Int so null providers aren't "world"
	if (!DHookEnableDetour(h, false, CTFPlayerShared_AddCond))
		SetFailState("Could not load hook for CTFPlayerShared::AddCond!");

//	h = DHookCreateDetourEx(conf, "CTFConditionList::Remove", CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
//	DHookAddParam(h, HookParamType_Int);
//	DHookAddParam(h, HookParamType_Bool);
//	if (!DHookEnableDetour(h, false, CTFConditionList_Remove))
//		SetFailState("Could not load hook for CTFConditionList::Remove!");

	h = DHookCreateDetourEx(conf, "CTFPlayerShared::RemoveCond", CallConv_THISCALL, ReturnType_Void, ThisPointer_Address);
	DHookAddParam(h, HookParamType_Int);
	DHookAddParam(h, HookParamType_Bool);
	if (!DHookEnableDetour(h, false, CTFPlayerShared_RemoveCond))
		SetFailState("Could not load hook for CTFPlayerShared::RemoveCond!");

	delete conf;
}

public MRESReturn CTFPlayerShared_AddCond(Address pThis, Handle hParams)
{
	Address m_pOuter = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_nHalloweenBombHeadStage") - FindSendPropInfo("CTFPlayer", "m_Shared") + 4);
	int client = GetEntityFromAddress(view_as<Address>(Dereference(pThis + m_pOuter)));
	TFCond cond = DHookGetParam(hParams, 1);
	float time = DHookGetParam(hParams, 2);
	int provider = !DHookGetParam(hParams, 3) ? -1 : GetEntityFromAddress(DHookGetParam(hParams, 3));
	Action action;

	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))	// Sanity check
		return MRES_Ignored;

	Call_StartForward(hAddCond);
	Call_PushCell(client);
	Call_PushCellRef(cond);
	Call_PushFloatRef(time);
	Call_PushCellRef(provider);
	Call_Finish(action);

	if (action == Plugin_Changed)
	{
		DHookSetParam(hParams, 1, cond);
		DHookSetParam(hParams, 2, time);
		if (provider == -1 || provider == 0xFFF)
			provider = 0;
		DHookSetParam(hParams, 3, provider == 0 ? provider : view_as< int >(GetEntityAddress(provider)));	// Fucking ok
		return MRES_ChangedHandled;
	}
	else if (action >= Plugin_Handled)
		return MRES_Supercede;

	return MRES_Ignored;
}

public MRESReturn CTFPlayerShared_RemoveCond(Address pThis, Handle hParams)
{
	Address m_pOuter = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_nHalloweenBombHeadStage") - FindSendPropInfo("CTFPlayer", "m_Shared") + 4);
	int client = GetEntityFromAddress(view_as<Address>(Dereference(pThis + m_pOuter)));
	TFCond cond = DHookGetParam(hParams, 1);
//	bool ignore_duration = DHookGetParam(hParams, 2);	// Unused
	Action action;

	// Sanity checks
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !TF2_IsPlayerInCondition(client, cond))
		return MRES_Ignored;

//	int	m_nPreventedDamageFromCondition;
//	float	m_flExpireTime;
//	CNetworkHandle( CBaseEntity, m_pProvider );
//	bool	m_bPrevActive;

	Address m_ConditionData = view_as<Address>(Dereference(pThis, 8));
	int offset = view_as< int >(cond) * 20;
//	ptr pCond = ptr(Dereference(m_ConditionData, offset));
	float timeleft = view_as< float >(Dereference(m_ConditionData, offset + 8));
	int provider = Dereference(m_ConditionData, offset + 12) & 0xFFF;

	// Keep accustom to all the regular sourcemod shiz and make NULL ents -1
	// 4095 provider is -1
	if (provider == 0xFFF || !provider)
		provider = -1;

	// Have to baby these coders that assume what they do will actually work
	float oldtime = timeleft;
	TFCond oldcond = cond;

	Call_StartForward(hRemoveCond);
	Call_PushCell(client);
	Call_PushCellRef(cond);
//	Call_PushCellRef(ignore_duration);
	Call_PushFloatRef(timeleft);
	Call_PushCellRef(provider);
	Call_Finish(action);

	if (action == Plugin_Changed)
	{
		DHookSetParam(hParams, 1, cond);

		// If cond was changed, make sure they're in this cond
		if (TF2_IsPlayerInCondition(client, cond))
		{
			offset = view_as< int >(cond) * 20;
			StoreToAddress(Transpose(m_ConditionData, offset + 8), view_as< int >(timeleft), NumberType_Int32);
			StoreToAddress(Transpose(m_ConditionData, offset + 12), view_as< int >(GetEHandle(provider)), NumberType_Int32);
		}

		// If they only changed the time and return Changed, supercede to prevent removal
		if (timeleft != oldtime && cond == oldcond)
			return MRES_Supercede;

		return MRES_ChangedHandled;
	}
	else if (action >= Plugin_Handled)
		return MRES_Supercede;

	return MRES_Ignored;
}

// Hours of my life I'm not getting back
#if 0
// Legacy condition manager. This is the main reason why condition removal forward doesn't pass
// conds by reference. I'm *not* dying on that hill
public MRESReturn CTFConditionList_Remove(Address pThis, Handle hReturn, Handle hParams)
{
	TFCond cond = DHookGetParam(hParams, 1);
	if (cond >= view_as< TFCond >(32))		// Conds >= 32 are handled earlier
		return MRES_Ignored;

	// ignore_duration doesn't even work?
//	bool ignore_duration = DHookGetParam(hParams, 2);
	Action action;

	// To get the client (and all the other shit), gotta pull some magic out of my ass
	int client, provider;
	float timeleft;
	int conditioncount = Dereference(pThis, 16);
	ptr _conditions = ptr(Dereference(pThis, 4));	// CUtlVector< CTFCondition* > _conditions

	ptr pCond;
//	float			_min_duration;
//	float			_max_duration;
//	const ETFCond	_type;
//	CTFPlayer*		_outer;
//	CHandle< CBaseEntity >	_provider;

	for (int i = 0; i < conditioncount; ++i)
	{
		pCond = ptr(Dereference(_conditions, i * 4));
		if (!pCond)
			continue;

		if (view_as< TFCond >(Dereference(pCond, 12)) == cond)	// If this cond is the cond
		{
			timeleft = view_as< float >(Dereference(pCond, 8));			// _max_duration
			client = GetEntityFromAddress(ptr(Dereference(pCond, 16)));	// _outer
			provider = Dereference(pCond, 20) & 0xFFF;					// _provider
			break;
		}
	}

	if (!client || !IsPlayerAlive(client))	// Sanity check
		return MRES_Ignored;

//	PrintToChatAll("Remove");
	// Can't trust people to do it themselves, so do it for them
	if (!TF2_IsPlayerInCondition(client, cond))
		return MRES_Ignored;

	// Keep accustom to all the regular sourcemod shiz and make NULL ents -1
	// 4095 provider is -1
	if (provider == 0xFFF || !provider)
		provider = -1;

	Call_StartForward(hRemoveCond);
	Call_PushCell(client);
	Call_PushCell(cond);
//	Call_PushCellRef(ignore_duration);
	Call_PushFloatRef(timeleft);
	Call_PushCell(provider);
	Call_Finish(action);

	if (action == Plugin_Changed)
	{
		StoreToAddress(Transpose(pCond, 8), view_as< int >(timeleft), NumberType_Int32);
		StoreToAddress(Transpose(pCond, 20), view_as< int >(GetEHandle(provider)), NumberType_Int32);

		// If they changed the time and return Changed, supercede to prevent removal
		if (timeleft != 0.0)
		{
			// Return true to prevent CTFPlayerShared::RemoveCond from changing the bits
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}

		return MRES_Ignored;
	}
	else if (action >= Plugin_Handled)
	{
		// Return true to prevent CTFPlayerShared::RemoveCond from changing the bits
		DHookSetReturn(hReturn, true);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}
#endif

stock Handle DHookCreateDetourEx(GameData conf, const char[] name, CallingConvention callConv, ReturnType returntype, ThisPointerType thisType)
{
	Handle h = DHookCreateDetour(Address_Null, callConv, returntype, thisType);
	if (h)
		if (!DHookSetFromConf(h, conf, SDKConf_Signature, name))
			SetFailState("Could not set %s from config!", name);
	return h;
}

// Props to nosoop
stock int GetEntityFromAddress(Address pEntity)
{
	return Dereference(pEntity, FindDataMapInfo(0, "m_angRotation") + 12) & 0xFFF;
}

stock Address GetEHandle(int entity)
{
	if (entity == -1)
		return view_as<Address>(-1);
	return view_as<Address>(Dereference(GetEntityAddress(entity), FindDataMapInfo(0, "m_angRotation") + 12));
}

stock int ReadInt(Address pAddr)
{
	if (pAddr == Address_Null)
		return -1;
	
	return LoadFromAddress(pAddr, NumberType_Int32);
}
stock Address Transpose(Address pAddr, int iOffset)
{
	return view_as<Address>(int(pAddr) + iOffset);
}
stock int Dereference(Address pAddr, int iOffset = 0)
{
	if (pAddr == Address_Null)
		return -1;

	return ReadInt(Transpose(pAddr, iOffset));
}