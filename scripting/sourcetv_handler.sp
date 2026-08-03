public Plugin myinfo =
{
	name = "SourceTV Handler",
	author = "random",
	description = "Various utilities for SourceTV recording",
	version = "1.0",
	url = "http://castaway.tf"
};

bool g_bRecording;
ConVar cvarMinRecordPlayers;

ConVar cvarTvEnable;
ConVar cvarTvAutorecord;
ConVar cvarTvMaxClients;

public void OnPluginStart()
{
	cvarMinRecordPlayers = CreateConVar("sm_stvhandler_min_players", "2", "Minimum number of players to start recording", _, true, 1.0);

	cvarTvEnable = FindConVar("tv_enable");
	cvarTvAutorecord = FindConVar("tv_autorecord");
	cvarTvMaxClients = FindConVar("tv_maxclients");

	cvarTvEnable.SetBool(true);
	cvarTvAutorecord.SetBool(false);
	cvarTvMaxClients.SetInt(0);
	g_bRecording = false;

	// SourceTV crashes the server if you hit max player count on the first map after a server restart
	// Immediate changelevel fixes this
	char current_map[255];
	GetCurrentMap(current_map,sizeof(current_map));
	ForceChangeLevel(current_map,"Fixing crash");


	if (CountClientsInServer() >= cvarMinRecordPlayers.IntValue) {
		StartSourceTVRecord();
	}
}

public void OnConfigsExecuted() {
	if (CountClientsInServer() >= cvarMinRecordPlayers.IntValue) {
		StartSourceTVRecord();
	}
}

public void OnMapEnd() {
	g_bRecording = false;
}

public void OnClientPutInServer(int client) {
	if (CountClientsInServer() >= cvarMinRecordPlayers.IntValue) {
		StartSourceTVRecord();
	}
}

public void OnClientDisconnect_Post(int client) {
	if (CountClientsInServer() < cvarMinRecordPlayers.IntValue) {
		StopSourceTVRecord();
	}
}

int CountClientsInServer() {
	int idx, count;
	for (idx = 1; idx <= MaxClients; idx++) {
		if (IsClientInGame(idx) && !IsFakeClient(idx)) count++;
	}
	return count;
}

void StartSourceTVRecord() {
	if (g_bRecording) return;

	char map[64];
	GetCurrentMap(map, sizeof(map));
	
	char timestamp[32];
	FormatTime(timestamp, sizeof(timestamp), "%Y%m%d-%H%M");

	char demo_name[PLATFORM_MAX_PATH];
	FormatEx(demo_name, sizeof(demo_name),"auto-%s-%s",timestamp,map);

	ServerCommand("tv_record \"%s\"", demo_name);
	ServerExecute();
	g_bRecording = true;
}

void StopSourceTVRecord() {
	if (!g_bRecording) return;

	ServerCommand("tv_stoprecord");
	ServerExecute();
	g_bRecording = false;
}