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
#include <scramble>

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

int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;
bool g_bVoted[MAXPLAYERS + 1];
bool g_bVoteCooldown;
bool g_bScrambleTeams;
bool g_bCanScramble;
bool g_bIsArena;
bool g_bServerWaitingForPlayers;
Handle g_tRoundResetTimer;

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

	RegConsoleCmd("sm_votescramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_vscramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_scramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegAdminCmd("sm_forcescramble", Cmd_ForceScramble, ADMFLAG_VOTE, "Force a team scramble vote.");

	HookEvent("teamplay_win_panel", Event_RoundWin);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

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

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_logic_arena")) != -1)
	{
		g_bIsArena = true;
		break;
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
	char errorMsg[MAX_NAME_LENGTH] = "";
	if (g_bServerWaitingForPlayers)
	{
		errorMsg = "Server is still waiting for players.";
	}
	if (g_bScrambleTeams)
	{
		errorMsg = "A previous vote scramble has succeeded. Teams will be scrambled next round.";
	}
	if (g_bVoteCooldown)
	{
		errorMsg = "Sorry, votescramble is currently on cool-down.";
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if (g_bVoted[client])
	{
		Format(errorMsg, sizeof(errorMsg), "You have already voted for a team scramble. [%d/%d votes required]", g_iVoters, g_iVotesNeeded);
	}

	if (!StrEqual(errorMsg, ""))
	{
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

public Action Timer_Scramble(Handle timer) {
	PrintToChatAll("Scrambling the teams due to vote.");
	ScrambleTeams();
	return Plugin_Continue;
}

public Action Timer_Retry(Handle timer)
{
	VoteScrambleMenu();
	return Plugin_Continue;
}

void ScheduleScramble()
{
	CreateTimer(0.1, Timer_Scramble);
}

public Action Timer_PreventScramble(Handle timer)
{
	g_bCanScramble = false;
	return Plugin_Stop;
}

//hides the team swap message
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("silent")) event.BroadcastDisabled = g_bScrambleTeamsInProgress;
}