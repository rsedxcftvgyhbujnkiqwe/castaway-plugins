public Plugin myinfo =
{
	name = "Vote Randomizer",
	author = "random",
	description = "Adds a vote to enable the randomizer plugin",
	version = "1.0",
	url = "http://castaway.tf"
};

#include <sourcemod>
#include <nativevotes>

bool g_voting_allowed;
bool g_randomizer_active;
ConVar randomizer;
NativeVote g_Vote = null;

public void OnPluginStart()
{
	randomizer = FindConVar("randomizer_enabled");
	g_randomizer_active = randomizer.BoolValue;

	RegConsoleCmd("sm_voterandomizer", Cmd_VoteRandomizer, "Initiate a vote to enable Randomizer for the rest of the map!");
	RegConsoleCmd("sm_voterandom", Cmd_VoteRandomizer, "Initiate a vote to enable Randomizer for the rest of the map!");
	RegConsoleCmd("sm_randomizer", Cmd_VoteRandomizer, "Initiate a vote to enable Randomizer for the rest of the map!");
	RegConsoleCmd("sm_callrandom", Cmd_VoteRandomizer, "Initiate a vote to enable Randomizer for the rest of the map!");
}

public void OnMapStart() {
	randomizer.SetBool(false);
	g_randomizer_active = false;
	g_voting_allowed = false;
	CreateTimer(900.0, Timer_EnableVote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Cmd_VoteRandomizer(int client, int args) {
	if (g_randomizer_active) {
		ReplyToCommand(client,"[SM] Randomizer is already active!");
	} else if (!CreateVote()) {
		ReplyToCommand(client,"[SM] You cannot vote at this time, try again later.")
	}
	return Plugin_Handled;
}

Action Timer_EnableRandomizer(Handle timer, any data) {
	randomizer.SetBool(true);
    return Plugin_Stop;
}

Action Timer_EnableVote(Handle timer, any data) {
	g_voting_allowed = true;
    return Plugin_Stop;
}

bool CreateVote()
{
    if (NativeVotes_IsVoteInProgress())
        return false;
	
	if (!g_voting_allowed)
		return false;

    g_Vote = new NativeVote(VoteHandler, NativeVotesType_Custom_YesNo);

    if (g_Vote == null)
        return false;

    g_Vote.SetTitle("Enable Randomizer for the rest of this map?");

	g_voting_allowed = false;
    if (!g_Vote.DisplayVoteToAll(15))
    {
		g_voting_allowed = true;
        g_Vote.Close();
        g_Vote = null;
        return false;
    }

    return true;
}

public int VoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            PrintToServer("[VR] Vote concluded");
            int winningVotes;
			int totalVotes;
			NativeVotes_GetInfo(param2, winningVotes, totalVotes);

			bool yesWon = param1 == NATIVEVOTES_VOTE_YES;
    		bool passed = yesWon && float(winningVotes) / float(totalVotes) > 0.50;

			if (passed)
            {
                PrintToServer("[VR] Vote passed");
                vote.DisplayPassCustom("%s", "Enabling Randomizer!");
                CreateTimer(0.5, Timer_EnableRandomizer, _, TIMER_FLAG_NO_MAPCHANGE);
				g_randomizer_active = true;
            }
            else
            {
                PrintToServer("[VR] Vote failed");
                vote.DisplayFail(yesWon ? NativeVotesFail_NotEnoughVotes : NativeVotesFail_Loses);
				CreateTimer(300.0, Timer_EnableVote, _, TIMER_FLAG_NO_MAPCHANGE);
            }
        }

        case MenuAction_VoteCancel:
        {
            PrintToServer("[VR] Vote cancelled");
            vote.DisplayFail(NativeVotesFail_Generic);
        }

        case MenuAction_End:
        {
            PrintToServer("[VR] Vote ended");
            vote.Close();

            if (vote == g_Vote)
                g_Vote = null;
        }
    }

    return 0;
}
