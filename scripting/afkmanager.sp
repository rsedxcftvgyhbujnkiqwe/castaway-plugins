public Plugin myinfo =
{
	name = "AFK Manager",
	author = "random",
	description = "Customized AFK management",
	version = "1.0",
	url = "http://castaway.tf"
};

#include <tf2_stocks>
#include <sdktools_voice>

// only look for relevant buttons when performing button checks
// do not check for 32!
#define ACTION_BUTTONS (1 + 2 + 4 + 8 + 16 + 512 + 1024 + 2048 + 8192 + 65536)

int g_iLastPressTime[MAXPLAYERS+1];
bool g_bMovedToSpec[MAXPLAYERS+1];
int g_iCurrentTime = 0;

ConVar g_cvEnabled;
ConVar g_cvAfkAction;
ConVar g_cvAfkAliveTime;
ConVar g_cvAfkSpecTime;
ConVar g_cvAfkSpecMovedTime;
ConVar g_cvMinPlayerCount;

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_afkmanager_enabled","1","Enable AFK Manager", _, true, 0.0, true, 1.0);
    g_cvAfkAction = CreateConVar("sm_afkmanager_afk_action", "1", "What action to take upon AFK players.\n0 = Kick immediately\n1 = Move to spectator, and kick AFK specators\n2 = Move to spectator, but don't kick spectators");
    g_cvAfkAliveTime = CreateConVar("sm_afkmanager_alive_time", "180", "How long a player must be AFK for for action to be taken upon them, in seconds.", _, true, 60.0);
    g_cvAfkSpecTime = CreateConVar("sm_afkmanager_spec_time", "300", "How long a player must be AFK in spectator before they are kicked, in seconds.", _, true, 60.0);
    g_cvAfkSpecMovedTime = CreateConVar("sm_afkmanager_spec_moved_time", "60", "How long a player must be AFK in spectator for, after being moved to it due to being afk, before they are kicked, in seconds.", _, true, 60.0);
    g_cvMinPlayerCount = CreateConVar("sm_afkmanager_min_player_count", "12", "Minimum number of players on the server before the AFK manager starts taking action on players.");

	AutoExecConfig(true, "afkmanager", "sourcemod");

	HookEvent("player_team", OnGameEvent, EventHookMode_Post);
	HookEvent("player_changeclass", OnGameEvent, EventHookMode_Post);

	AddCommandListener(OnSpecChanged,"spec_next");
	AddCommandListener(OnSpecChanged,"spec_prev");

	FindConVar("mp_idledealmethod").SetInt(0);

    CreateTimer(1.0, AfkDaemon,_,TIMER_REPEAT);
}

public void OnMapStart() {
	for (int idx = 1; idx <= MaxClients; idx++) {
		ClientPressedButton(idx);
	}
}

public void OnClientConnected(int client) {
	ClientPressedButton(client);
}

public void OnGameFrame() {
	int idx;
	int buttons;
	for (idx = 1; idx <= MaxClients; idx++) {
		if (
			IsClientInGame(idx) &&
			!IsFakeClient(idx)
		) {
			buttons = GetEntProp(idx, Prop_Data, "m_nButtons");

			if (
				(buttons & ACTION_BUTTONS > 0)
			) {
				ClientPressedButton(idx);
			}
		}
	}
}

public void OnClientSpeaking(int client) {
	ClientPressedButton(client);
}

Action OnSpecChanged(int client, const char[] command, int argc) {
	// spectators moving cameras is not covered by button checks (annoyingly!)
	ClientPressedButton(client);
	return Plugin_Continue;
}

Action OnGameEvent(Event event, const char[] name, bool dontbroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ClientPressedButton(client);
	return Plugin_Continue;
}

Action AfkDaemon(Handle timer, any data) {
	g_iCurrentTime = GetTime();

	if (g_cvEnabled.BoolValue) {
		AfkManage();
	}

    return Plugin_Continue;
}

void ClientPressedButton(int client) {
	g_iLastPressTime[client] = g_iCurrentTime;
	g_bMovedToSpec[client] = false;
}

void Kick(int client) {
	KickClient(client,"#TF_Idle_kicked");
}

void AfkManage() {
	int action = g_cvAfkAction.IntValue;
	int alive_time = g_cvAfkAliveTime.IntValue;
	int spec_time = g_cvAfkSpecTime.IntValue;
	int spec_moved_time = g_cvAfkSpecMovedTime.IntValue;
	int min_count = g_cvMinPlayerCount.IntValue;
	int client_time;
	int elapsed;
	int idx;
	TFTeam team;

	bool low_count = GetClientCount(true) < min_count;

	for (idx = 1; idx <= MaxClients; idx++) {
		if (
			IsClientInGame(idx) &&
			!IsFakeClient(idx)
		) {
			// reset this var on low counts constantly
			// so that counting only "begins" when threshold reached
			if (low_count) {
				ClientPressedButton(idx);
				continue;
			}

			client_time = g_iLastPressTime[idx];

			if (client_time == 0) {
				continue;
			}

			elapsed = g_iCurrentTime - client_time;

			team = TF2_GetClientTeam(idx);
			
			if (
				team == TFTeam_Unassigned ||
				team == TFTeam_Spectator 
			) {
				if (action==0) {
					if (elapsed > spec_time) {
						Kick(idx);
					}
				} else if (action==1) {
					if (
						(g_bMovedToSpec[idx] && elapsed > spec_moved_time) ||
						(!g_bMovedToSpec[idx] && elapsed > spec_time)
					) {
						Kick(idx);
					}
				}
			} else if (
				team == TFTeam_Red ||
				team == TFTeam_Blue
			) {
				if (!IsPlayerAlive(idx) && TF2_GetPlayerClass(idx) != TFClass_Unknown) {
					// don't count time spent dead
					// but do count class select time
					g_iLastPressTime[idx]++;
					continue;
				}
				if (elapsed > alive_time) {
					if (action==0) {
						Kick(idx);
					} else if (action==1) {
						TF2_ChangeClientTeam(idx, TFTeam_Spectator);
						ClientPressedButton(idx);
						g_bMovedToSpec[idx] = true;
					} else if (action==2) {
						TF2_ChangeClientTeam(idx, TFTeam_Spectator);
					}
				}
			}
		}
	}
}