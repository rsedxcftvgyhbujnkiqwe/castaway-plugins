//This plugin only has gamedata for linux for the time being
//it will NOT work on windows!!!!!!!!

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_NAME "Force Stalemate"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = "random, VerdiusArcana",
	description = "Force stalemates when map time runs out",
	version = "1.1",
	url = "https://castaway.tf"
};

ArrayList g_MapsExceptedFromForcedStalemates; // We use this instead of constantly loading the exceptions file.
ConVar cvar_temp_disable_forcestalemate; // If tempDisable true: Current map will not have SD. Resets to 0
MemoryPatch patch_ForceAlways_StalemateOrOvertime;


public void OnPluginStart() {
	Handle conf;
	conf = LoadGameConfigFile("stalemate");
	if (conf == null) SetFailState("Failed to load stalemate conf");
	patch_ForceAlways_StalemateOrOvertime = 
		MemoryPatch.CreateFromConf(conf,
		"ForceAlways_StalemateOrOvertime");
	if (!ValidateAndNullCheck(patch_ForceAlways_StalemateOrOvertime)) SetFailState("Failed to create ForceAlways_StalemateOrOvertime");
	delete conf;



	cvar_temp_disable_forcestalemate = CreateConVar("sm_forcestalemate__tempdisable", "0", (PLUGIN_NAME ... " - Temporarily enable/disable forced stalemates (does not disable the plugin itself)."), _, true, 0.0, true, 1.0);
	RegConsoleCmd("sm_forcestalemate__recheck", Command_RecheckExceptions, "Manually re-check forcestalemate exceptions.");
	// Load the exceptions file
	LoadExceptionsFile();
	
}

bool ValidateAndNullCheck(MemoryPatch patch) {
	return (patch.Validate() && patch != null);
}

public void OnMapStart() {
	
	bool result;
	result = IsMapInExceptions(); // Check if current map is blacklisted.
	if (cvar_temp_disable_forcestalemate.BoolValue) {
	patch_ForceAlways_StalemateOrOvertime.Disable();
	PrintToServer("[ForceStalemate] Forced stalemate on servertime end disabled for current map due to server command!");
	PrintToServer("[ForceStalemate] Don't forget to do \"sm_forcestalemate__tempdisable 0\" if you used tempdisable for testing.");
	} else if (result) {
		patch_ForceAlways_StalemateOrOvertime.Disable();
		PrintToServer("[ForceStalemate] Forced stalemate on servertime end disabled due to current map being blacklisted!");
	}
 	else {
		patch_ForceAlways_StalemateOrOvertime.Enable();
	}
}

public void LoadExceptionsFile()
{
    if (g_MapsExceptedFromForcedStalemates == null)
        g_MapsExceptedFromForcedStalemates = new ArrayList(ByteCountToCells(64));
    else
        g_MapsExceptedFromForcedStalemates.Clear();

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/forcestalemate_map_blacklist.txt");

    // Try to open in read mode
    File file = OpenFile(path, "r");
    if (file == null)
    {
        LogError("[ForceStalemate] Exception file not found, creating default at: %s", path);

        File newfile = OpenFile(path, "w");
        if (newfile != null)
        {
            newfile.WriteLine("// List of maps that should NOT have forced stalemates applied.");
            newfile.WriteLine("// One map per line. Example:");
            newfile.WriteLine("// pl_upward");
            delete newfile;
        }
        else
        {
            LogError("[ForceStalemate] Failed to create fallback exception file.");
        }

        return; // Don't apply exceptions until they exist
    }

    int count = 0;
    char line[128];

    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
    {
        TrimString(line);
        if (line[0] == '\0' || line[0] == '/' || line[0] == ';')
            continue;

        g_MapsExceptedFromForcedStalemates.PushString(line);
        count++;
    }

    delete file;

    if (count == 0)
    {
        LogMessage("[ForceStalemate] Loaded 0 entries from exceptions file. All maps will be patched.");
    }
    else
    {
        LogMessage("[ForceStalemate] Loaded %d map exception(s) from: %s", count, path);
    }
}

bool IsMapInExceptionList(const char[] mapname)
{
    if (g_MapsExceptedFromForcedStalemates == null)
        return false;

    char buffer[64];
    for (int i = 0; i < g_MapsExceptedFromForcedStalemates.Length; i++)
    {
        g_MapsExceptedFromForcedStalemates.GetString(i, buffer, sizeof(buffer));
        if (StrEqual(buffer, mapname, false))
            return true;
    }
    return false;
}

public bool IsMapInExceptions()
{
    char map[64];
    GetCurrentMap(map, sizeof(map));
    return IsMapInExceptionList(map);
}

Action Command_RecheckExceptions(int client, int args)
{
    if (client != 0)
    {
        ReplyToCommand(client, "[ForceStalemate] This command can only be run from server console.");
        return Plugin_Handled;
    }

    LoadExceptionsFile();
    PrintToServer("[ForceStalemate] Reloaded Exceptions file! Rechecking exceptions...");

    bool result;
	result = IsMapInExceptions(); // Check if current map is blacklisted.
	if (cvar_temp_disable_forcestalemate.BoolValue) {
	patch_ForceAlways_StalemateOrOvertime.Disable();
	PrintToServer("[ForceStalemate] Forced stalemate on servertime end disabled for current map due to server command!");
	PrintToServer("[ForceStalemate] Don't forget to do \"sm_forcestalemate__tempdisable 0\" if you used tempdisable for testing.");
	} else if (result) {
		patch_ForceAlways_StalemateOrOvertime.Disable();
		PrintToServer("[ForceStalemate] Forced stalemate on servertime end disabled due to current map being blacklisted!");
	}
 	else {
		patch_ForceAlways_StalemateOrOvertime.Enable();
	}

    return Plugin_Handled;
}


