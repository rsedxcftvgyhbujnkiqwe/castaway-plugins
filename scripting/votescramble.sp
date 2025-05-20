#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#define PLUGIN_AUTHOR "Nanochip, viora, raspy, random"
#define PLUGIN_VERSION "1.5.1"

#include <sourcemod>
#include <sdktools>
#include <nativevotes>
#include <tf2>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[TF2] Vote Scramble",
	author = PLUGIN_AUTHOR,
	description = "Vote to scramble teams.",
	version = PLUGIN_VERSION,
	url = "https://castaway.tf"
};

ConVar cvarVoteTime;
ConVar cvarVoteTimeDelay;
ConVar cvarRoundResetDelay;
ConVar cvarVoteChatPercent;
ConVar cvarVoteMenuPercent;
ConVar cvarMinimumVotesNeeded;
ConVar cvarSkipSecondVote;

int g_iTeamManagerRed;
int g_iTeamManagerBlue;
int g_iPlayerManager;
int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;
bool g_bVoted[MAXPLAYERS + 1];
bool g_bVoteCooldown;
bool g_bScrambleTeams;
bool g_bScrambleTeamsInProgress;
bool g_bCanScramble;
bool g_bIsArena;
bool g_bServerWaitingForPlayers;
Handle g_tRoundResetTimer;

#define SPECTATOR 1
#define RED 2
#define BLU 3
#define AUTOASSIGN 5

enum struct ScoreData
{
	int client;
	int score;
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	if (IsValidHandle(g_tRoundResetTimer)) KillTimer(g_tRoundResetTimer);
	g_bCanScramble = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//this runs both here and on round end just in case. no harm no foul
	if (IsValidHandle(g_tRoundResetTimer)) KillTimer(g_tRoundResetTimer);
	g_bCanScramble = true;
	//arena is special, prevention timer should be lower
	float reset_delay = g_bIsArena ? 3.0 : cvarRoundResetDelay.FloatValue;
	g_tRoundResetTimer = CreateTimer(reset_delay,Timer_PreventScramble, _, TIMER_FLAG_NO_MAPCHANGE);
	if (g_bScrambleTeams) {
		g_bScrambleTeams = false;
		ScheduleScramble();
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("silent"))
	{
		if (g_bScrambleTeamsInProgress)
		{
			event.BroadcastDisabled = true;
		}
		else
		{
			event.BroadcastDisabled = false;
		}
	}
}

public void OnPluginStart()
{
	CreateConVar("nano_votescramble_version", PLUGIN_VERSION, "Vote Scramble Version", FCVAR_DONTRECORD);

	cvarVoteTime = CreateConVar("nano_votescramble_time", "20.0", "Time in seconds the vote menu should last.", 0);
	cvarVoteTimeDelay = CreateConVar("nano_votescramble_delay", "180.0", "Time in seconds before players can initiate another team scramble vote.", 0);
	cvarRoundResetDelay = CreateConVar("nano_votescramble_roundreset", "30.0", "Time in seconds after round start where scrambles are delayed until next round.", 0);
	cvarVoteChatPercent = CreateConVar("nano_votescramble_chat_percentage", "0.20", "How many players are required for the chat vote to pass? 0.20 = 20%.", 0, true, 0.05, true, 1.0);
	cvarVoteMenuPercent = CreateConVar("nano_votescramble_menu_percentage", "0.60", "How many players are required for the menu vote to pass? 0.60 = 60%.", 0, true, 0.05, true, 1.0);
	cvarMinimumVotesNeeded = CreateConVar("nano_votescramble_minimum", "3", "What are the minimum number of votes needed to initiate a chat vote?", 0);
	cvarSkipSecondVote = CreateConVar("nano_votescramble_skip_second_vote", "0", "Should the second vote be skipped?", 0, true, 0.0, true, 1.0);

	// cvarTimeLimit = FindConVar("mp_timelimit");
	// cvarMaxRounds = FindConVar("mp_maxrounds");
	// cvarWinLimit = FindConVar("mp_winlimit");

	RegConsoleCmd("sm_votescramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_vscramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_scramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegAdminCmd("sm_forcescramble", Cmd_ForceScramble, ADMFLAG_VOTE, "Force a team scramble vote.");

	HookEvent("teamplay_win_panel", Event_RoundWin);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

	// CreateTimer(60.0, Timer_CountMinutes, _, TIMER_REPEAT);

	AutoExecConfig(true);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "nativevotes", false) && NativeVotes_IsVoteTypeSupported(NativeVotesType_ScrambleNow))
	{
		NativeVotes_RegisterVoteCommand(NativeVotesOverride_Scramble, OnScrambleVoteCall);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "nativevotes", false) && NativeVotes_IsVoteTypeSupported(NativeVotesType_ScrambleNow))
	{
		NativeVotes_UnregisterVoteCommand(NativeVotesOverride_Scramble, OnScrambleVoteCall);
	}
}

public void OnMapStart()
{
	g_iVoters = 0;
	g_iVotesNeeded = 0;
	g_iVotes = 0;
	g_bVoteCooldown = false;
	g_bScrambleTeams = false;
	g_bScrambleTeamsInProgress = false;
	g_bServerWaitingForPlayers = false;
	g_bCanScramble = false;
	g_bIsArena = false;
	g_iPlayerManager = GetPlayerResourceEntity();

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_logic_arena")) != -1)
	{
		g_bIsArena = true;
		break;
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_team")) != -1)
	{
		switch(GetEntProp(ent,Prop_Send,"m_iTeamNum"))
		{
			case RED: g_iTeamManagerRed = ent;
			case BLU: g_iTeamManagerBlue = ent;
		}
	}
}

public void TF2_OnWaitingForPlayersStart() {
	if (!g_bIsArena) {
		g_bServerWaitingForPlayers = true;
	}
}

public void TF2_OnWaitingForPlayersEnd() {
	if (!g_bIsArena) {
		g_bServerWaitingForPlayers = false;
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!StrEqual(auth, "BOT"))
	{
		g_bVoted[client] = false;
		g_iVoters++;
		g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
		if (g_iVotesNeeded < cvarMinimumVotesNeeded.IntValue) g_iVotesNeeded = cvarMinimumVotesNeeded.IntValue;
	}
}

public void OnClientDisconnect(int client)
{
	if (g_iVotes > 0 && g_bVoted[client]) g_iVotes--;
	g_iVoters--;
	g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
	if (g_iVotesNeeded < cvarMinimumVotesNeeded.IntValue) g_iVotesNeeded = cvarMinimumVotesNeeded.IntValue;
}

public Action Cmd_ForceScramble(int client, int args)
{
	StartVoteScramble();
	return Plugin_Handled;
}

public Action Cmd_VoteScramble(int client, int args)
{
	AttemptVoteScramble(client, false);
	return Plugin_Handled;
}

public Action OnScrambleVoteCall(int client, NativeVotesOverride overrideType, const char[] voteArgument)
{
	AttemptVoteScramble(client, true);
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(sArgs, "votescramble", false) == 0 || strcmp(sArgs, "vscramble", false) == 0 || strcmp(sArgs, "scramble", false) == 0 || strcmp(sArgs, "scrimblo", false) == 0 )
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptVoteScramble(client, false);

		SetCmdReplySource(old);
	}
}

void AttemptVoteScramble(int client, bool isVoteCalledFromMenu)
{
	if (g_bServerWaitingForPlayers)
	{
		char errorMsg[] = "Server is still waiting for players.";
		if (isVoteCalledFromMenu)
		{
			PrintToChat(client, errorMsg);
		}
		else 
		{
			ReplyToCommand(client, errorMsg);
		}
		return;
	}
	if (g_bScrambleTeams)
	{
		char errorMsg[] = "A previous vote scramble has succeeded. Teams will be scrambled next round.";
		if (isVoteCalledFromMenu)
		{
			PrintToChat(client, errorMsg);
		}
		else 
		{
			ReplyToCommand(client, errorMsg);
		}
		return;
	}
	if (g_bVoteCooldown)
	{
		char errorMsg[] = "Sorry, votescramble is currently on cool-down.";
		if (isVoteCalledFromMenu)
		{
			PrintToChat(client, errorMsg);
		}
		else
		{
			ReplyToCommand(client, errorMsg);
		}
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if (g_bVoted[client])
	{
		char errorMsg[] = "You have already voted for a team scramble. [%d/%d votes required]";
		if (isVoteCalledFromMenu)
		{
			PrintToChat(client, errorMsg, g_iVotes, g_iVotesNeeded);
		}
		else
		{
			ReplyToCommand(client, errorMsg, g_iVotes, g_iVotesNeeded);
		}
		return;
	}

	g_iVotes++;
	g_bVoted[client] = true;
	PrintToChatAll("%s wants to scramble teams. [%d/%d votes required]", name, g_iVotes, g_iVotesNeeded);

	if (g_iVotes >= g_iVotesNeeded)
	{
		StartVoteScramble();
	}
}

void StartVoteScramble()
{
	if (cvarSkipSecondVote.IntValue == 1) {
		ScheduleScramble();
	} else {
		VoteScrambleMenu();
	}

	ResetVoteScramble();
	g_bVoteCooldown = true;
	CreateTimer(cvarVoteTimeDelay.FloatValue, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle timer)
{
	g_bVoteCooldown = false;
	return Plugin_Continue;
}

void ResetVoteScramble()
{
	g_iVotes = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) g_bVoted[i] = false;
}

void VoteScrambleMenu()
{
	if (NativeVotes_IsVoteInProgress())
	{
		CreateTimer(10.0, Timer_Retry, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToConsoleAll("[SM] Can't vote scramble because there is already a vote in progress. Retrying in 10 seconds...");
		return;
	}

	Handle vote = NativeVotes_Create(NativeVote_Handler, NativeVotesType_Custom_Mult);

	NativeVotes_SetTitle(vote, "Scramble teams?");

	NativeVotes_AddItem(vote, "yes", "Yes");
	NativeVotes_AddItem(vote, "no", "No");
	NativeVotes_DisplayToAll(vote, cvarVoteTime.IntValue);
}

public int NativeVote_Handler(Handle vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: NativeVotes_Close(vote);
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(vote, param1, item, sizeof(item));

			percent = float(votes) / float(totalVotes);
			limit = cvarVoteMenuPercent.FloatValue;

			if (FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes"))
			{
				if (g_bCanScramble)
				{
					NativeVotes_DisplayPass(vote, "Scrambling teams...");
					ScheduleScramble();
				}
				else
				{
					NativeVotes_DisplayPass(vote, "Teams will be scrambled next round.");
					g_bScrambleTeams = true;
				}
			}
			else NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
		}
	}
	return 0;
}

// public Action Timer_CountMinutes(Handle timer) {
// 	g_iMinutesSinceLastScramble++;
// 	return Plugin_Continue;
// }

public Action Timer_Scramble(Handle timer) {
	PrintToChatAll("Scrambling the teams due to vote.");
	ScrambleTeams();
	return Plugin_Continue;
}

// public Action Timer_DelayLimitsUpdate(Handle timer) {
// 	// subtract from maxrounds/winlimit after scramble to prevent artificial superextension of maps
// 	// assume no limit if 0, don't set negatives
// 	if (cvarMaxRounds.IntValue != 0) {
// 		SetConVarInt(cvarMaxRounds, cvarMaxRounds.IntValue - g_iRoundsSinceLastScramble, false, true);
// 	}

// 	if (cvarWinLimit.IntValue != 0) {
// 		int rounds;
// 		rounds = cvarWinLimit.IntValue - g_iRoundsSinceLastScramble;
// 		rounds = rounds > 1 ? rounds : 1;
// 		SetConVarInt(cvarWinLimit, rounds, false, true);
// 	}

// 	if (cvarTimeLimit.IntValue != 0) {
// 		int time = cvarTimeLimit.IntValue - g_iMinutesSinceLastScramble;
// 		time = time > 5 ? time : 5;
// 		LogMessage("Time: %d, time limit: %d, minutes since scramble: %d",time,cvarTimeLimit.IntValue,g_iMinutesSinceLastScramble);
// 		SetConVarInt(cvarTimeLimit, time, false, true);
// 	}

// 	g_iRoundsSinceLastScramble = 0;
// 	g_iMinutesSinceLastScramble = 0;

// 	return Plugin_Continue;
// }

public Action Timer_Retry(Handle timer)
{
	VoteScrambleMenu();
	return Plugin_Continue;
}

void ScheduleScramble()
{
	CreateTimer(0.1, Timer_Scramble);
	//unnecessary now?
	//CreateTimer(1.0, Timer_DelayLimitsUpdate);
}

public Action Timer_PreventScramble(Handle timer)
{
	g_bCanScramble = false;
	return Plugin_Stop;
}

void ForceRespawn()
{
	int flags = GetCommandFlags("mp_forcerespawnplayers");
	SetCommandFlags("mp_forcerespawnplayers", flags & ~FCVAR_CHEAT);
	ServerCommand("mp_forcerespawnplayers");
	// wait 0.1 seconds before resetting flag or else it would complain
	// about not having sv_cheats 1
	CreateTimer(0.1, Post_RespawnCommandRun, flags);
}

public Action Post_RespawnCommandRun(Handle timer, int flags) {
	SetCommandFlags("mp_forcerespawnplayers", flags);
	return Plugin_Continue;
}

void TF2_ResetTeamScore(int team) {
	if (team != BLU && team != RED) return;

	int team_manager = team == RED ? g_iTeamManagerRed : g_iTeamManagerBlue;

	//sdktools setteamscore does not set roundswon
	SetEntProp(team_manager,Prop_Send,"m_iScore",0);
	SetEntProp(team_manager,Prop_Send,"m_iRoundsWon",0);
}

int TF2_GetPlayerScore(int client) {
	if (!IsClientConnected(client))
		return -1;

	int offset = FindSendPropInfo("CTFPlayerResource", "m_iTotalScore");
	if (offset < 1)
		return -1;

	if (g_iPlayerManager == -1)
		g_iPlayerManager = GetPlayerResourceEntity();
		if(g_iPlayerManager == -1)
			return -1;

	return GetEntData(g_iPlayerManager, offset + (client*4));
}

int SortByScore(int index1, int index2, Handle array, Handle hndl)
{
    int score1 = view_as<ArrayList>(array).Get(index1, ScoreData::score);
    int score2 = view_as<ArrayList>(array).Get(index2, ScoreData::score);
    return score1 < score2;
}

int GetTeamScoreDiff(ArrayList clientList, int &score_red, int &score_blue)
{

	for (int i=0;i<clientList.Length;i++)
	{
		int client = clientList.Get(i, ScoreData::client);
		int score = clientList.Get(i, ScoreData::score);
		if(GetClientTeam(client)==RED)
		{
			score_red += score;
		}
		else
		{
			score_blue += score;
		}
	}

	//abs value
	int diff = score_red - score_blue;
	return abs(diff);
}

void ScrambleTeams()
{
	g_bScrambleTeamsInProgress = true;
	Event scramble_team_alert = CreateEvent("teamplay_alert");
	scramble_team_alert.SetInt("alert_type", 0);
	scramble_team_alert.Fire();
	// replica of the way scrambles are performed in the TF2 code
	// src/game/shared/tf/tf_gamerules.cpp:L16071
	ArrayList clientList = new ArrayList(sizeof(ScoreData));
	int num_red = 0;
	int num_blue = 0;

	for (int i = 1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		int team = GetClientTeam(i);
		if (team != RED && team != BLU)
			continue;
		if (TF2_IsPlayerInDuel(i))
		{
			//for autoassign logic later
			if (team==RED) num_red++;
			else if (team==BLU) num_blue++;
			continue;
		}

		ScoreData data;
		data.client = i;
		data.score = TF2_GetPlayerScore(i);

		clientList.PushArray(data);

		ChangeClientTeam(i,SPECTATOR);
	}

	clientList.SortCustom(SortByScore);

	//initial naive scramble
	for (int i=0;i<clientList.Length;i++)
	{
		int client = clientList.Get(i, ScoreData::client);

		//autoassign doesn't appear to work all the time
		//recreation of the autoassign logic
		int team = 0;
		if (num_red < num_blue)
			team = RED;
		else if (num_blue < num_red)
			team = BLU;
		else
			team = GetRandomInt(0, 1) ? RED : BLU;

		if (team == RED) num_red++;
		else if (team == BLU) num_blue++;

		ChangeClientTeam(client,team);
	}

	if (clientList.Length > 2)
	{
		int score_red = 0;
		int score_blue = 0;
		int delta = GetTeamScoreDiff(clientList,score_red,score_blue);

		if(delta > 1)
		{
			ConVar mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
			int iOrigValue = mp_teams_unbalance_limit.IntValue;
			mp_teams_unbalance_limit.SetInt(0);

			int iPassLimit = 8;
			for(int i = 0; i<iPassLimit && FindAndSwapPlayers(clientList,delta);++i) {}

			mp_teams_unbalance_limit.SetInt(iOrigValue);
		}
	}

	delete clientList;

	//reset scores
	TF2_ResetTeamScore(RED);
	TF2_ResetTeamScore(BLU);

	ForceRespawn();

	g_bScrambleTeamsInProgress = false;

}

bool FindAndSwapPlayers(ArrayList clientList, int &delta)
{
	int score_red = 0;
	int score_blue = 0;
	GetTeamScoreDiff(clientList,score_red,score_blue);

	for (int i=0;i<clientList.Length;i++)
	{
		int client_red = clientList.Get(i, ScoreData::client);
		if(GetClientTeam(client_red) != RED)
			continue;
		int client_red_score = clientList.Get(i, ScoreData::score);

		// Check against players on the other team
		for (int j=0;j<clientList.Length;j++)
		{
			int client_blue = clientList.Get(j, ScoreData::client);
			if(GetClientTeam(client_blue) != BLU)
				continue;
			int client_blue_score = clientList.Get(j, ScoreData::score);

			int diff = abs(client_red_score - client_blue_score);
			if(diff)
			{
				int new_score_red = score_red;
				int new_score_blue = score_blue;

				if(client_red_score > client_blue_score)
				{
					new_score_red -= diff;
					new_score_blue += diff;
				}
				else
				{
					new_score_red += diff;
					new_score_blue -= diff;
				}

				int new_delta = abs(new_score_red - new_score_blue);
				if(new_delta < delta)
				{
					ChangeClientTeam(client_red,BLU);
					ChangeClientTeam(client_blue,RED);
					delta = GetTeamScoreDiff(clientList,score_red,score_blue);
					return true;
				}
			}
		}
	}
	return false;
}

int abs(int x)
{
	int mask = x >> 31;
	return (x + mask) ^ mask;
}
