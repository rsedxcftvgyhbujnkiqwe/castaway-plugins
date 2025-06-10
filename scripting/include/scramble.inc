#define SPECTATOR 1
#define RED 2
#define BLU 3
#define AUTOASSIGN 5

bool g_bScrambleTeamsInProgress = false;
int g_iTeamManagerRed;
int g_iTeamManagerBlue;
int g_iPlayerManager;

enum struct ScoreData
{
	int client;
	int score;
}

void ScrambleTeams()
{
	g_bScrambleTeamsInProgress = true;
	Event scramble_team_alert = CreateEvent("teamplay_alert");
	scramble_team_alert.SetInt("alert_type", 0);
	scramble_team_alert.Fire();

	g_iPlayerManager = GetPlayerResourceEntity();
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_team")) != -1)
	{
		switch(GetEntProp(ent,Prop_Send,"m_iTeamNum"))
		{
			case RED: g_iTeamManagerRed = ent;
			case BLU: g_iTeamManagerBlue = ent;
		}
	}

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

	//reset setup timer
	int timer = FindEntityByClassname(-1, "team_round_timer");
	if (timer != -1)
	{
		int m_nSetupTimeLength = GetEntProp(timer, Prop_Send, "m_nSetupTimeLength");
		SetEntPropFloat(timer,Prop_Send,"m_flTimerEndTime",GetGameTime() + m_nSetupTimeLength);
	}
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

int abs(int x)
{
	int mask = x >> 31;
	return (x + mask) ^ mask;
}
