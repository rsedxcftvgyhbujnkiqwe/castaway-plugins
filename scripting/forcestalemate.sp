#include <sourcemod>
#include <regex>
#include <sourcescramble>
#include <sdktools>

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
ConVar cvar_use_regex_pattern;
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

	cvar_temp_disable_forcestalemate = CreateConVar("sm_forcestalemate__tempdisable", "0", (PLUGIN_NAME ... " - Temporarily enable/disable forced stalemates (does not disable the plugin itself)."), FCVAR_HIDDEN, true, 0.0, true, 1.0);
	cvar_use_regex_pattern = CreateConVar("sm_forcestalemate__regex", "0", (PLUGIN_NAME ... " - Use regex patterns when matching map name."), _, true, 0.0, true, 1.0);
	RegServerCmd("sm_forcestalemate__recheck", Command_RecheckExceptions, "Manually re-check forcestalemate exceptions.");
	// Load the exceptions file
	LoadExceptionsFile();

	AutoExecConfig();
}

public void OnMapStart() {
	bool should_patch = ShouldPatchMap();
	if (should_patch) {
		patch_ForceAlways_StalemateOrOvertime.Enable();
	} else {
		patch_ForceAlways_StalemateOrOvertime.Disable();
	}
}

bool ShouldPatchMap() {

	// Control Points
	int ent = -1;
	if ((ent = FindEntityByClassname(ent, "team_control_point_master")) != -1) {
		if (
			(GetEntProp(ent,Prop_Send,"m_iInvalidCapWinner") == 0) || // Attack/Defend
			(FindEntityByClassname(-1,"tf_logic_koth") == -1) // KOTH
		) {
			return true; // Symmetric control points (3cp/5cp)
		}
	}

	// Flags
	ent = -1;
	int team = -1;
	while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1) {
		int current_team = GetEntProp(ent,Prop_Send,"m_iTeamNum");
		if (team != -1) {
			if (current_team != team) {
				return true; // Capture the Flag
			} else {
				team = current_team;
			}
		}
	}
	return false;
}

bool ValidateAndNullCheck(MemoryPatch patch) {
	return (patch.Validate() && patch != null);
}

public void OnConfigsExecuted() {
	//ApplyBlackList();
}

void ApplyBlackList() {
	if (cvar_temp_disable_forcestalemate.BoolValue) {
		patch_ForceAlways_StalemateOrOvertime.Disable();
		PrintToServer("[ForceStalemate] Forced stalemate on servertime end disabled for current map due to server command!");
		PrintToServer("[ForceStalemate] Don't forget to do \"sm_forcestalemate__tempdisable 0\" if you used tempdisable for testing.");
		return;
	}

	if (IsMapInExceptions()) { // Check if current map is blacklisted.
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
		
		if (!strlen(line))
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

	bool useRegex = cvar_use_regex_pattern.BoolValue;

	char buffer[64];
	for (int i = 0; i < g_MapsExceptedFromForcedStalemates.Length; i++)
	{
		g_MapsExceptedFromForcedStalemates.GetString(i, buffer, sizeof(buffer));
		if (useRegex) {
			char regexErrorMsg[128];
			RegexError regexError;
			Regex pattern = new Regex(buffer, _, regexErrorMsg, sizeof(regexErrorMsg), regexError);
			if (regexError != REGEX_ERROR_NONE) {
				delete pattern;
				ThrowError("Error encountered while compiling regex pattern \"%s\". Error Message: %s", buffer, regexErrorMsg);
			}
			if (pattern.Match(mapname) > 0) {
				delete pattern;
				return true;
			}
			delete pattern;
		} else {
			if (StrEqual(buffer, mapname, false))
				return true;
		}
	}
	return false;
}

public bool IsMapInExceptions()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	return IsMapInExceptionList(map);
}

Action Command_RecheckExceptions(int args)
{
	LoadExceptionsFile();
	PrintToServer("[ForceStalemate] Reloaded Exceptions file! Rechecking exceptions...");

	ApplyBlackList();

	return Plugin_Handled;
}
