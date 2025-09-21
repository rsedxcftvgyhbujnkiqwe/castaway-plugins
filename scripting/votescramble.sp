#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#define PLUGIN_AUTHOR "Nanochip, viora, raspy, random"
#define PLUGIN_VERSION "1.5.1"

#include <sourcemod>
#include <sdktools>
#include <regex>
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
ConVar cvarVanillaScrambleTimeout;
ConVar cvarMapExcludeListPath;

int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;
int g_iVoteCooldownExpireTime;
bool g_bVoted[MAXPLAYERS + 1];
bool g_bVoteCooldown;
bool g_bScrambleTeams;
bool g_bCanScramble;
bool g_bIsArena;
bool g_bServerWaitingForPlayers;
bool g_bScrambleTeamsInProgress;
bool g_bIsMapAllowed = true;
Handle g_tRoundResetTimer;
ArrayList g_aMapExclusionList;

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	delete g_tRoundResetTimer;
	g_bCanScramble = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//this runs both here and on round end just in case. no harm no foul
	delete g_tRoundResetTimer;
	g_bCanScramble = true;
	//arena is special, prevention timer should be lower
	float reset_delay = g_bIsArena ? 3.0 : cvarRoundResetDelay.FloatValue;
	g_tRoundResetTimer = CreateTimer(reset_delay,Timer_PreventScramble);
	if (g_bScrambleTeams) {
		g_bScrambleTeams = false;
		ScheduleScramble(true);
	}
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("votescramble.phrases");

	CreateConVar("nano_votescramble_version", PLUGIN_VERSION, "Vote Scramble Version", FCVAR_DONTRECORD);

	cvarVoteTime = CreateConVar("nano_votescramble_time", "20.0", "Time in seconds the vote menu should last.", 0);
	cvarVoteTimeDelay = CreateConVar("nano_votescramble_delay", "180.0", "Time in seconds before players can initiate another team scramble vote.", 0);
	cvarRoundResetDelay = CreateConVar("nano_votescramble_roundreset", "30.0", "Time in seconds after round start where scrambles are delayed until next round.", 0);
	cvarVoteChatPercent = CreateConVar("nano_votescramble_chat_percentage", "0.20", "How many players are required for the chat vote to pass? 0.20 = 20%.", 0, true, 0.05, true, 1.0);
	cvarVoteMenuPercent = CreateConVar("nano_votescramble_menu_percentage", "0.60", "How many players are required for the menu vote to pass? 0.60 = 60%.", 0, true, 0.05, true, 1.0);
	cvarMinimumVotesNeeded = CreateConVar("nano_votescramble_minimum", "3", "What are the minimum number of votes needed to initiate a chat vote?", 0);
	cvarSkipSecondVote = CreateConVar("nano_votescramble_skip_second_vote", "0", "Should the second vote be skipped?", 0, true, 0.0, true, 1.0);
	cvarVanillaScrambleTimeout = CreateConVar("nano_votescramble_vanilla_scramble_timeout", "1", "Should scramble follow timeout sequence", 0, true, 0.0, true, 1.0);
	cvarMapExcludeListPath = CreateConVar("nano_votescramble_exclusion_list_path", "", "Path to the map exclusion list relative to SourceMod root. (Defaults to configs/votescramble_exclude.txt)");

	RegConsoleCmd("sm_votescramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_vscramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_scramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegAdminCmd("sm_forcescramble", Cmd_ForceScramble, ADMFLAG_VOTE, "Force a team scramble vote.");
	RegServerCmd("sm_reload_votescramble_exclusion_list", Cmd_ReloadExclusionList, "Reload map exclusion list.");

	HookEvent("teamplay_win_panel", Event_RoundWin, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

	AutoExecConfig(true);
}

public void OnMapEnd() {
	LoadExclusionList(false);
	delete g_tRoundResetTimer;
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

public void OnConfigsExecuted() {
	LoadExclusionList(false);
	g_bIsMapAllowed = !IsCurrentMapInExclusionList();
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

	g_bIsMapAllowed = !IsCurrentMapInExclusionList();

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

public Action Cmd_ReloadExclusionList(int args) {
	LoadExclusionList();
	g_bIsMapAllowed = !IsCurrentMapInExclusionList();
	return Plugin_Handled;
}

public Action OnScrambleVoteCall(int client, NativeVotesOverride overrideType, const char[] voteArgument)
{
	AttemptVoteScramble(client, true);
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (StrEqual(sArgs, "votescramble", false)
		|| StrEqual(sArgs, "vscramble", false)
		|| StrEqual(sArgs, "scramble", false)
		|| StrEqual(sArgs, "scrimblo", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptVoteScramble(client, false);

		SetCmdReplySource(old);
	}
}

void AttemptVoteScramble(int client, bool isVoteCalledFromMenu=false)
{
	char errorMsg[MAX_NAME_LENGTH] = "";
	if (!g_bIsMapAllowed)
	{
		if (isVoteCalledFromMenu)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Disabled);
			return;
		}
		Format(errorMsg, sizeof(errorMsg), "%T", "VOTESCRAMBLE_MAP_DISABLED", client);
	}
	if (g_bServerWaitingForPlayers)
	{
		if (isVoteCalledFromMenu)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Waiting);
			return;
		}
		if (g_bIsMapAllowed) {
			Format(errorMsg, sizeof(errorMsg), "%T", "VOTESCRAMBLE_WAITING_FOR_PLAYERS", client);
		}
	}
	if (g_bScrambleTeams)
	{
		Format(errorMsg, sizeof(errorMsg), "%T", "VOTESCRAMBLE_ATTEMPT_SCRAMBLE_NEXT_ROUND", client);
	}
	if (g_bVoteCooldown)
	{
		if (isVoteCalledFromMenu)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Recent, g_iVoteCooldownExpireTime - GetTime());
			return;
		}
		Format(errorMsg, sizeof(errorMsg), "%T", "VOTESCRAMBLE_COOLDOWN", client);
	}
	if (g_bVoted[client])
	{
		Format(errorMsg, sizeof(errorMsg), "%T", "VOTESCRAMBLE_VOTED", client, g_iVotes, g_iVotesNeeded);
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

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	g_iVotes++;
	g_bVoted[client] = true;
	PrintToChatAll("%t", "VOTESCRAMBLE_VOTE_ANNOUNCE", name, g_iVotes, g_iVotesNeeded);

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
	g_iVoteCooldownExpireTime = GetTime() + RoundToNearest(cvarVoteTimeDelay.FloatValue);
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
		PrintToConsoleAll("[SM] %t", "VOTESCRAMBLE_VOTE_IN_PROGRESS");
		return;
	}

	NativeVote vote = new NativeVote(NativeVote_Handler, NativeVotesType_Custom_Mult, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Display | MenuAction_DisplayItem);

	vote.SetTitle("VOTESCRAMBLE_VOTE_TITLE");

	vote.AddItem("yes", "Yes");
	vote.AddItem("no", "No");
	vote.DisplayVoteToAll(cvarVoteTime.IntValue);
}

bool IsCurrentMapInExclusionList() {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	return IsMapInExclusionList(mapName);
}

void LoadExclusionList(bool printResult=true) {
	if (g_aMapExclusionList == null) {
		g_aMapExclusionList = new ArrayList(ByteCountToCells(64));
	} else {
		g_aMapExclusionList.Clear();
	}

	char cvarPath[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
	cvarMapExcludeListPath.GetString(cvarPath, sizeof(cvarPath));
	if (strlen(cvarPath)) {
		BuildPath(Path_SM, path, sizeof(path), cvarPath);
		if (!FileExists(path)) {
			ThrowError("File \"%s\" doesn't exist.", cvarPath);
		}
	}
	if (!strlen(path)) {
		BuildPath(Path_SM, path, sizeof(path), "configs/votescramble_exclude.txt");
	}
	if (!FileExists(path)) {
		return;
	}

	File exclusionList = OpenFile(path, "r");
	if (exclusionList == null) {
		ThrowError("Exclusion list file \"%s\" cannot be opened.", path);
		return;
	}

	while (!exclusionList.EndOfFile()) {
		char line[64];
		exclusionList.ReadLine(line, sizeof(line));
		TrimString(line);
		if (!strlen(line) || (line[0] == '/' && line[1] == '/')) {
			continue;
		}
		g_aMapExclusionList.PushString(line);
	}

	delete exclusionList;

	if (printResult) {
		PrintToServer("Reloaded map exclusion list for votescramble.");
	}
}

bool IsMapInExclusionList(const char[] mapName) {
	if (g_aMapExclusionList == null || !g_aMapExclusionList.Length) {
		return false;
	}

	bool match = false;
	for (int i = 0; i < g_aMapExclusionList.Length; i++) {
		char patternStr[64], regexErrorMsg[128];
		g_aMapExclusionList.GetString(i, patternStr, sizeof(patternStr));
		RegexError regexError;
		Regex pattern = new Regex(patternStr, _, regexErrorMsg, sizeof(regexErrorMsg), regexError);
		if (regexError != REGEX_ERROR_NONE) {
			delete pattern;
			ThrowError("Error encountered while compiling regex pattern \"%s\". Error Message: %s", patternStr, regexErrorMsg);
		}
		if (pattern.Match(mapName) > 0) {
			delete pattern;
			match = true;
			break;
		}
		delete pattern;
	}
	return match;
}

public int NativeVote_Handler(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: 
		{
			vote.Close();
		}
		case MenuAction_Display:
		{
			char title[64], targetStr[64];
			vote.GetTitle(title, sizeof(title));
			Format(targetStr, sizeof(targetStr), "%T", title, param1);
			return view_as<int>(NativeVotes_RedrawVoteTitle(targetStr));
		}
		case MenuAction_DisplayItem:
		{
			char sourceInfoStr[64], sourceDispStr[64], targetStr[64];
			vote.GetItem(param2, sourceInfoStr, sizeof(sourceInfoStr), sourceDispStr, sizeof(sourceDispStr));
			if (StrEqual(sourceInfoStr, "yes") || StrEqual(sourceInfoStr, "no")) {
				Format(targetStr, sizeof(targetStr), "%T", sourceDispStr, param1);
				return view_as<int>(NativeVotes_RedrawVoteItem(targetStr));
			}
		}
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			vote.GetItem(param1, item, sizeof(item));

			percent = float(votes) / float(totalVotes);
			limit = cvarVoteMenuPercent.FloatValue;

			if (FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes"))
			{
				if (g_bCanScramble)
				{
					vote.DisplayPass("%t", "VOTESCRAMBLE_SCRAMBLING_TEAMS");
					ScheduleScramble();
				}
				else
				{
					vote.DisplayPass("%t", "VOTESCRAMBLE_SCRAMBLE_NEXT_ROUND");
					g_bScrambleTeams = true;
				}
			}
			else vote.DisplayFail(NativeVotesFail_Loses);
		}
	}
	return 0;
}

public Action Timer_Scramble(Handle timer, bool roundStart) {
	PrintToChatAll("%t", "VOTESCRAMBLE_SCRAMBLE_IN_PROGRESS");
	bool vanillaTimeout = cvarVanillaScrambleTimeout.BoolValue;
	CreateTimer(!roundStart && vanillaTimeout ? 2.0 : 0.0, Timer_StartScramble, vanillaTimeout);	
	return Plugin_Continue;
}

public Action Timer_StartScramble(Handle timer, bool vanillaTimeout) {
	Event scramble_team_alert = CreateEvent("teamplay_alert");
	scramble_team_alert.SetInt("alert_type", 0);
	scramble_team_alert.Fire();

	if (!vanillaTimeout) {
		ImmediateScramble();
		return Plugin_Continue;
	}

	CreateTimer(0.0, Timer_Countdown, 5);
	return Plugin_Continue;
}

public Action Timer_Countdown(Handle timer, int sec) {
	if (sec != 0) {
		char soundScript[30];
		Format(soundScript, sizeof(soundScript), "Announcer.RoundBegins%dSeconds", sec);
		EmitGameSoundToAll(soundScript);
		CreateTimer(1.0, Timer_Countdown, sec - 1);
	} else {
		ImmediateScramble();	
	}
	return Plugin_Continue;
}

public Action Timer_Retry(Handle timer)
{
	VoteScrambleMenu();
	return Plugin_Continue;
}

void ScheduleScramble(bool roundStart=false)
{
	CreateTimer(0.1, Timer_Scramble, roundStart);
}

void ImmediateScramble() {
	g_bScrambleTeamsInProgress = true;
	ScrambleTeams();
	g_bScrambleTeamsInProgress = false;
}

public Action Timer_PreventScramble(Handle timer)
{
	g_bCanScramble = false;
	g_tRoundResetTimer = null;
	return Plugin_Continue;
}

//hides the team swap message
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("silent")) event.BroadcastDisabled = g_bScrambleTeamsInProgress;
}
