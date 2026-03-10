public Plugin myinfo =
{
	name = "MGE Handler",
	author = "random",
	description = "Handles MGE map switching at player count thresholds",
	version = "1.0",
	url = "http://castaway.tf"
};

#include <sourcemod>
#include <mapchooser>

ConVar cvar_player_threshold;
ConVar cvar_switch_timer;
bool g_timer_active;

#define LIBRARY "nativevotes"

char MGE_MAPS[][PLATFORM_MAX_PATH] = { "mge_bball_v2", "mge_chillypunch_final4_fix2", "mge_dueling_v1_fix1", "mge_oihguv_sucks_a12", "mge_oihguv_sucks_b5", "mge_training_v8_beta4b", "mge_triumph_beta7_rc1" };

public void OnPluginStart()
{
	cvar_player_threshold = CreateConVar("sm_mgehandler__player_threshold", "10", "Above this number, MGE map switching will occur", FCVAR_HIDDEN, true, 0.0);
	cvar_switch_timer = CreateConVar("sm_mgehandler__switch_timer", "60", "Number of seconds to wait after player threshold is passed to attempt a switch", FCVAR_HIDDEN, true, 0.0);
}

public void OnConfigsExecuted() {
	g_timer_active = false;
	OnClientPutInServer(0);
}

public void OnClientPutInServer(int client) {
	if (IsAboveThreshold()) {
		if (IsMgeMap()) {
			if (!g_timer_active) {
				g_timer_active = true;
				CreateTimer(cvar_switch_timer.FloatValue,SwitchTimer,_,TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

Action SwitchTimer(Handle timer, any data) {
	if (IsAboveThreshold() && IsMgeMap()) {
		bool next_map_not_mge = true;

		PrintToChatAll("[SM] MGE Player Threshold reached.");

		char map[PLATFORM_MAX_PATH];
		if (GetNextMap(map, sizeof(map)))
		{
			if (ArrayContains(MGE_MAPS, sizeof(MGE_MAPS), map)) {
				next_map_not_mge = false;
			}
		}
		
		if (next_map_not_mge && EndOfMapVoteEnabled() && HasEndOfMapVoteFinished()) {
			GetMapDisplayName(map, map, sizeof(map));
			
			PrintToChatAll("[SM] %t", "Changing Maps", map);
			CreateTimer(5.0, ChangeTimer, _, TIMER_FLAG_NO_MAPCHANGE);
		} else {
			for (int i = 0; i < sizeof(MGE_MAPS); i++) {
				RemoveNominationByMap(MGE_MAPS[i]);
			}
			InitiateMapChooserVote(view_as<MapChange>(0))
		}
	} else {
		g_timer_active = false;
	}
	return Plugin_Stop;
}

Action ChangeTimer(Handle timer)
{	
	LogMessage("MGE Handler changing map manually");
	
	char map[PLATFORM_MAX_PATH];
	if (GetNextMap(map, sizeof(map)))
	{	
		ForceChangeLevel(map, "MGE Handler after mapvote");
	}
	
	return Plugin_Stop;
}

bool IsMgeMap() {
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	if (
		ArrayContains(MGE_MAPS, sizeof(MGE_MAPS), map)
	 ) {
		return true;
	}
	return false;

}

bool IsAboveThreshold() {
	int count = 0;
	for (int idx = 1; idx <= MaxClients; idx++) {
		if (IsClientInGame(idx)) count++;
	}
	return count > cvar_player_threshold.IntValue;
}

bool ArrayContains(const char array[][PLATFORM_MAX_PATH], int size, const char[] value) {
	for (int i = 0; i < size; i++) {
		if (StrEqual(array[i], value)) {
			return true
		}
	}
	return false
}