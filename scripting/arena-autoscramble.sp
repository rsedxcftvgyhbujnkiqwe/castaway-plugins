public Plugin myinfo =
{
	name = "arena-autoscramble",
	author = "random",
	description = "Autoscrambles arena teams after a configured win streak",
	version = "1.0",
	url = "http://castaway.tf"
};

#include <sdktools>
#include <tf2>
#include <scramble>

ConVar cvar_WinStreak;
bool g_bIsArena;
bool g_bScrambleTeamsInProgress;

public void OnPluginStart() {
	cvar_WinStreak = CreateConVar("sm_arena_autoscramble_streak", "3.0", "Win Streak before scramble, 0 disables autoscramble", FCVAR_DONTRECORD,true,0.0,false);

	HookEvent("teamplay_round_start",OnPreRoundStart);
}


public void OnMapStart() {
	g_bIsArena = false;

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_logic_arena")) != -1)
	{
		g_bIsArena = true;
		break;
	}
}

public void OnPreRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_bIsArena && cvar_WinStreak.IntValue > 0) {
		int score_red;
		int score_blue;

		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "tf_team")) != -1) {
			switch(GetEntProp(ent,Prop_Send,"m_iTeamNum")) {
				case RED: score_red = GetEntProp(ent,Prop_Send,"m_iRoundsWon");
				case BLU: score_blue = GetEntProp(ent,Prop_Send,"m_iRoundsWon");
			}
		}

		if (abs(score_red-score_blue) >= cvar_WinStreak.IntValue) {
			g_bScrambleTeamsInProgress = true;
			ScrambleTeams();
			g_bScrambleTeamsInProgress = false;
		}

	}
}

//hides the team swap message
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("silent")) event.BroadcastDisabled = g_bScrambleTeamsInProgress;
}