#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <adminmenu>

#define PLUGIN_VERSION "2.0.0"

#define MAX_CONNECTIONS 5
#define ZERO_VECTOR view_as<float>({0.0, 0.0, 0.0})

/** ----------------------------- CVar container ------------------------------ */

enum struct SSHCVars
{
    ConVar enabled;
    ConVar antiOverlap;
    ConVar auth;
    ConVar maxDist;
    ConVar refresh;
    ConVar global;
    ConVar location;
    ConVar hudTime;
	ConVar removeOnDC;
}
SSHCVars cvar;

/** ----------------------------- Spray state -------------------------------- */

enum struct SprayData
{
    char  name[MAX_NAME_LENGTH];
    char  steam2[32];
    float pos[3];
    int   time;
    char  auth[128];
    int   hudTarget;
    float traceTime[2];

    void clear()
    {
        this.pos = ZERO_VECTOR;
        this.name[0] = '\0';
        this.steam2[0] = '\0';
        this.auth[0] = '\0';
        this.time = 0;
        this.hudTarget = -1;
        this.traceTime[0] = 0.0;
        this.traceTime[1] = 0.0;
    }
}
SprayData g_Spray[MAXPLAYERS + 1];

/** ----------------------------- Globals ------------------------------------ */

// Timer
Handle g_hSprayTimer;

// HUD support
bool g_bCanUseHUD;
int  g_iHudLoc;
Handle g_hHUD;

// Admin menu
TopMenu g_hAdminMenu;
TopMenuObject menu_category = INVALID_TOPMENUOBJECT;

// Glow effect
int g_PrecacheRedGlow;

/** ----------------------------- Plugin info -------------------------------- */

public Plugin myinfo =
{
    name = "Super Spray Handler",
    description = "Ultimate Tool for Admins to manage Sprays on their servers.",
    author = "shavit, Nican132, CptMoore, Lebson506th, and TheWreckingCrew6",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/member.php?u=163134"
};

/** ----------------------------- Startup ------------------------------------ */

public void OnPluginStart()
{
    LoadTranslations("ssh.phrases");
    LoadTranslations("common.phrases");

    CreateConVar("sm_spray_version", PLUGIN_VERSION, "Super Spray Handler plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    CreateConVar("sm_ssh_version",   PLUGIN_VERSION, "Super Spray Handler version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

    // Spray Manager CVars
    cvar.enabled     = CreateConVar("sm_ssh_enabled", "1", "Enable \"Super Spray Handler\"?", 0, true, 0.0, true, 1.0);
    cvar.antiOverlap = CreateConVar("sm_ssh_overlap", "0", "Prevent spray-on-spray overlapping? Distance in units.", 0, true, 0.0);
    cvar.auth        = CreateConVar("sm_ssh_auth", "1", "HUD identifiers bitmask: 1=Name 2=SteamID 4=IP", 0, true, 1.0);
    cvar.removeOnDC  = CreateConVar("sm_ssh_remove_on_disconnect", "1", "Remove a player's spray when they disconnect? 0=no 1=yes", 0, true, 1.0);

    // SSH CVars
    cvar.refresh  = CreateConVar("sm_ssh_refresh","1.0","Trace refresh rate. 0 disables.");
    cvar.maxDist  = CreateConVar("sm_ssh_dista","50.0","Max distance to match a spray.");
    cvar.global   = CreateConVar("sm_ssh_global","1","Track sprays after a player leaves?");
    cvar.location = CreateConVar("sm_ssh_location","1","Display: 0=Off 1=KeyHint 2=Hint 3=Center 4=HUD");
    cvar.hudTime  = CreateConVar("sm_ssh_hudtime","1.0","Time HUD messages persist after look-away.");

    cvar.refresh.AddChangeHook(TimerChanged);
    cvar.location.AddChangeHook(LocationChanged);
    g_iHudLoc = cvar.location.IntValue;

    AutoExecConfig(true, "plugin.ssh");

    // Tempent hook
    AddTempEntHook("Player Decal", Player_Decal);

    // HUD support per game
    char gamename[32];
    GetGameFolderName(gamename, sizeof(gamename));
    g_bCanUseHUD =
        StrEqual(gamename, "tf", false) ||
        StrEqual(gamename, "hl2mp", false) ||
        StrEqual(gamename, "synergy", false) ||
        StrEqual(gamename, "sourceforts", false) ||
        StrEqual(gamename, "obsidian", false) ||
        StrEqual(gamename, "left4dead", false) ||
        StrEqual(gamename, "l4d", false);

    if (g_bCanUseHUD) {
        g_hHUD = CreateHudSynchronizer();
    }

    if (g_hHUD == null && cvar.location.IntValue == 4) {
        cvar.location.SetInt(1, true);
        LogError("[Super Spray Handler] This game can't use HUD messages, forcing sm_ssh_location to 1.");
    }

    // Admin menu
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
        OnAdminMenuReady(topmenu);
    }

    // Commands
    RegAdminCmd("sm_spraytrace",       Command_TraceSpray,      ADMFLAG_BAN, "Look up the owner of the logo in front of you.");
    RegAdminCmd("sm_removespray",      Command_RemoveSpray,     ADMFLAG_BAN, "Remove the logo in front of you.");
    RegAdminCmd("sm_adminspray",       Command_AdminSpray,      ADMFLAG_BAN, "Sprays the named player's logo in front of you.");
    RegAdminCmd("sm_qremovespray",     Command_QuickRemoveSpray,ADMFLAG_BAN, "Remove the logo without opening a menu.");
    RegAdminCmd("sm_removeallsprays",  Command_RemoveAllSprays, ADMFLAG_BAN, "Remove all sprays from the map.");
}

public void OnMapStart()
{
    CreateTimers();
    g_PrecacheRedGlow = PrecacheModel("sprites/redglow1.vmt");

    for (int i = 1; i <= MaxClients; i++) {
        g_Spray[i].clear();
    }
}

public void OnClientDisconnect(int client)
{
    if (cvar.removeOnDC.BoolValue) {
        RemovePlayerSpray(client);
    }
	
    if (!cvar.global.BoolValue || cvar.removeOnDC.BoolValue) {
        g_Spray[client].clear();
    }
}

public void OnClientPutInServer(int client)
{
    g_Spray[client].pos = ZERO_VECTOR;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "adminmenu")) {
        g_hAdminMenu = null;
    }
}

/** ----------------------------- Tracing HUD loop --------------------------- */

public void CheckAllTraces(Handle timer)
{
    if (!GetClientCount(true)) {
        return;
    }

    int hudType = (g_bCanUseHUD ? g_iHudLoc : 0);
    float gameTime = GetGameTime();
    bool hudParamsSet = false;

    float endPos[3];
    char msg[128];

    for (int client = 1; client <= MaxClients; client++) {
        if (!IsValidClient(client) || IsFakeClient(client)) {
            g_Spray[client].hudTarget = -1;
            continue;
        }

        // Clear lingering non-HUD text
        switch (hudType) {
            case 1: Client_PrintKeyHintText(client, "");
            case 2: Client_PrintHintText(client, "");
            case 3: PrintCenterText(client, "");
        }

        if (!GetClientEyeEndLocation(client, endPos)) {
            ClearHud(client, hudType, gameTime);
            continue;
        }

        bool fullAccess = CheckCommandAccess(client, "ssh_hud_access_full", ADMFLAG_GENERIC, true);
        if (!fullAccess && !CheckCommandAccess(client, "ssh_hud_access", 0, true)) {
            continue;
        }

        bool canTraceAdmins = CheckCommandAccess(client, "ssh_hud_can_trace_admins", 0, true);
        int target = FindSprayAt(endPos, cvar.maxDist.FloatValue);
        if (!IsValidClient(target)) {
            ClearHud(client, hudType, gameTime);
            continue;
        }

        bool targetIsAdmin = CheckCommandAccess(target, "ssh_hud_is_admin", ADMFLAG_GENERIC, true);
        if (!canTraceAdmins && targetIsAdmin) {
            ClearHud(client, hudType, gameTime);
            continue;
        }

        if (CheckForZero(g_Spray[target].pos)) {
            ClearHud(client, hudType, gameTime);
            continue;
        }

        FormatEx(msg, sizeof(msg), "Sprayed by:\n%s", fullAccess ? g_Spray[target].auth : g_Spray[target].name);

        switch (hudType) {
            case 1: Client_PrintKeyHintText(client, msg);
            case 2: Client_PrintHintText(client, msg);
            case 3: PrintCenterText(client, msg);
            case 4:
            {
                if (!hudParamsSet) {
                    hudParamsSet = true;
                    SetHudTextParams(0.04, 0.6, 15.0, 255, 12, 39, 240 + (RoundToFloor(gameTime) % 2), _, 0.2);
                }

                if (gameTime > g_Spray[client].traceTime[1] + 14.5 || target != g_Spray[client].hudTarget) {
                    ShowSyncHudText(client, g_hHUD, msg);
                    g_Spray[client].hudTarget = target;
                    g_Spray[client].traceTime[1] = gameTime;
                }
                g_Spray[client].traceTime[0] = gameTime;
            }
        }
    }
}

void ClearHud(int client, int hudType, float gameTime)
{
    if (gameTime > g_Spray[client].traceTime[0] + cvar.hudTime.FloatValue - cvar.refresh.FloatValue) {
        if (g_Spray[client].hudTarget != -1) {
            if (g_hHUD != null) {
                ClearSyncHud(client, g_hHUD);
            } else {
                switch (hudType) {
                    case 1: Client_PrintKeyHintText(client, "");
                    case 2: Client_PrintHintText(client, "");
                    case 3: PrintCenterText(client, "");
                }
            }
        }
        g_Spray[client].hudTarget = -1;
    }
}

bool UserCanTarget(int client, int target)
{
    AdminId clientAdm = GetUserAdmin(client);
    if (clientAdm != INVALID_ADMIN_ID && IsClientInGame(target)) {
        return clientAdm.CanTarget(GetUserAdmin(target));
    }
    return true;
}

/** ----------------------------- Admin menu -------------------------------- */

public void CategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayTitle) {
        FormatEx(buffer, maxlength, "Spray Commands: ");
    } else if (action == TopMenuAction_DisplayOption) {
        FormatEx(buffer, maxlength, "Spray Commands");
    }
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    if (menu_category == INVALID_TOPMENUOBJECT) {
        OnAdminMenuCreated(topmenu);
    }

    if (topmenu == g_hAdminMenu) {
        return;
    }

    g_hAdminMenu = topmenu;

    g_hAdminMenu.AddItem("sm_spraytrace",      AdminMenu_TraceSpray,      menu_category, "sm_spraytrace", ADMFLAG_BAN);
    g_hAdminMenu.AddItem("sm_removespray",     AdminMenu_SprayRemove,     menu_category, "sm_removespray", ADMFLAG_BAN);
    g_hAdminMenu.AddItem("sm_adminspray",      AdminMenu_AdminSpray,      menu_category, "sm_adminspray", ADMFLAG_BAN);
    g_hAdminMenu.AddItem("sm_qremovespray",    AdminMenu_QuickSprayRemove,menu_category, "sm_qremovespray", ADMFLAG_BAN);
    g_hAdminMenu.AddItem("sm_removeallsprays", AdminMenu_RemoveAllSprays, menu_category, "sm_removeallsprays", ADMFLAG_BAN);
}

public void OnAdminMenuCreated(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    if (topmenu == g_hAdminMenu && menu_category != INVALID_TOPMENUOBJECT) {
        return;
    }
    menu_category = topmenu.AddCategory("Spray Commands", CategoryHandler);
}

/** ----------------------------- TempEnt hook -------------------------------- */

public Action Player_Decal(const char[] name, const int[] clients, int count, float delay)
{
    if (!cvar.enabled.BoolValue) {
        return Plugin_Continue;
    }

    int client = TE_ReadNum("m_nPlayer");

    if (IsValidClient(client) && !IsClientReplay(client) && !IsClientSourceTV(client)) {
        float fSprayVector[3];
        TE_ReadVector("m_vecOrigin", fSprayVector);

        // anti-overlap
        if (cvar.antiOverlap.FloatValue > 0.0) {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsValidClient(i) && i != client && !CheckForZero(g_Spray[i].pos)) {
                    if (GetVectorDistance(fSprayVector, g_Spray[i].pos) <= cvar.antiOverlap.FloatValue) {
                        PrintToChat(client, "\x04[Super Spray Handler]\x01 Your spray is too close to \x05%N\x01's spray.", i);
                        return Plugin_Handled;
                    }
                }
            }
        }

        // record
        g_Spray[client].pos = fSprayVector;
        g_Spray[client].time = RoundFloat(GetGameTime());
        GetClientName(client, g_Spray[client].name, sizeof(g_Spray[].name));
        if (!GetClientAuthId(client, AuthId_Steam2, g_Spray[client].steam2, sizeof(g_Spray[].steam2))) {
            g_Spray[client].steam2[0] = '\0';
        }

        // build auth string by mask
        g_Spray[client].auth[0] = '\0';
        bool any = false;

        if (cvar.auth.IntValue & 1) {
            Format(g_Spray[client].auth, sizeof(g_Spray[].auth), "%N", client);
            any = true;
        }
        if (cvar.auth.IntValue & 2) {
            Format(g_Spray[client].auth, sizeof(g_Spray[].auth), "%s%s(%s)",
                   g_Spray[client].auth, any ? "\n" : "", g_Spray[client].steam2);
            any = true;
        }
        if (cvar.auth.IntValue & 4) {
            char ip[32];
            GetClientIP(client, ip, sizeof(ip));
            Format(g_Spray[client].auth, sizeof(g_Spray[].auth), "%s%s(%s)",
                   g_Spray[client].auth, any ? "\n" : "", ip);
        }
    }

    return Plugin_Continue;
}

/** ----------------------------- CVar change hooks -------------------------- */

public void LocationChanged(ConVar hConVar, const char[] oldValue, const char[] newValue)
{
    g_iHudLoc = hConVar.IntValue;
    cvar.location.SetInt(StringToInt(newValue), true, false);
}

public void TimerChanged(ConVar hConVar, const char[] oldValue, const char[] newValue)
{
    delete g_hSprayTimer;
    CreateTimers();
}

stock void CreateTimers()
{
    float t = cvar.refresh.FloatValue;
    if (t > 0.0) {
        g_hSprayTimer = CreateTimer(t, CheckAllTraces, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

/** ----------------------------- Commands: trace ---------------------------- */

public Action Command_TraceSpray(int client, int args)
{
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    float pos[3];
    if (GetClientEyeEndLocation(client, pos)) {
        int target = FindSprayAt(pos, cvar.maxDist.FloatValue);
        if (IsValidClient(target) && UserCanTarget(client, target)) {
            int elapsed = RoundFloat(GetGameTime()) - g_Spray[target].time;
            PrintToChat(client, "[SSH] %T", "Spray By", client, g_Spray[target].name, g_Spray[target].steam2, elapsed);
            GlowEffect(client, g_Spray[target].pos, 2.0, 0.3, 255, g_PrecacheRedGlow);
            return Plugin_Handled;
        }
    }

    PrintToChat(client, "[SSH] %T", "No Spray", client);
    return Plugin_Handled;
}

public void AdminMenu_TraceSpray(TopMenu hTopMenu, TopMenuAction action, TopMenuObject id, int param, char[] buf, int maxlen)
{
    if (!IsValidClient(param)) return;

    switch (action) {
        case TopMenuAction_DisplayOption: Format(buf, maxlen, "%T", "Trace", param);
        case TopMenuAction_SelectOption:  Command_TraceSpray(param, 0);
    }
}

/** ----------------------------- Commands: remove --------------------------- */

stock void RemovePlayerSpray(int target)
{
    if (!IsValidClient(target)) return;
    if (CheckForZero(g_Spray[target].pos)) return;

    float dummy[3]; // zero vector is fine
    SprayDecal(target, 0, dummy);
    g_Spray[target].pos = ZERO_VECTOR;
}

public Action Command_RemoveSpray(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;

    float pos[3];
    if (GetClientEyeEndLocation(client, pos)) {
        char adminName[MAX_NAME_LENGTH];
        GetClientName(client, adminName, sizeof(adminName));

        int target = FindSprayAt(pos, cvar.maxDist.FloatValue);
        if (IsValidClient(target) && UserCanTarget(client, target)) {
            float endPos[3];
            PrintToChat(client, "[SSH] %T", "Spray By", client, g_Spray[target].name, g_Spray[target].steam2, RoundFloat(GetGameTime()) - g_Spray[target].time);
            SprayDecal(target, 0, endPos);
            g_Spray[target].pos = ZERO_VECTOR;
            PrintToChat(client, "[SSH] %T", "Spray Removed", client, g_Spray[target].name, g_Spray[target].steam2, adminName);
            LogAction(client, -1, "[SSH] %T", "Spray Removed", LANG_SERVER, g_Spray[target].name, g_Spray[target].steam2, adminName);
            return Plugin_Handled;
        }
    }

    PrintToChat(client, "[SSH] %T", "No Spray", client);
    return Plugin_Handled;
}

public void AdminMenu_SprayRemove(TopMenu hTopMenu, TopMenuAction action, TopMenuObject id, int param, char[] buf, int maxlen)
{
    if (!IsValidClient(param)) return;

    switch (action) {
        case TopMenuAction_DisplayOption: Format(buf, maxlen, "%T", "Remove", param);
        case TopMenuAction_SelectOption:  Command_RemoveSpray(param, 0);
    }
}

/** ----------------------------- Commands: quick remove --------------------- */

public Action Command_QuickRemoveSpray(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;

    float pos[3];
    if (GetClientEyeEndLocation(client, pos)) {
        char adminName[MAX_NAME_LENGTH];
        GetClientName(client, adminName, sizeof(adminName));

        int target = FindSprayAt(pos, cvar.maxDist.FloatValue);
        if (IsValidClient(target) && UserCanTarget(client, target)) {
            float endPos[3];
            PrintToChat(client, "[SSH] %T", "Spray By", client, g_Spray[target].name, g_Spray[target].steam2, RoundFloat(GetGameTime()) - g_Spray[target].time);
            SprayDecal(target, 0, endPos);
            g_Spray[target].pos = ZERO_VECTOR;
            PrintToChat(client, "[SSH] %T", "Spray Removed", client, g_Spray[target].name, g_Spray[target].steam2, adminName);
            LogAction(client, -1, "[SSH] %T", "Spray Removed", LANG_SERVER, g_Spray[target].name, g_Spray[target].steam2, adminName);
            return Plugin_Handled;
        }
    }

    PrintToChat(client, "[SSH] %T", "No Spray", client);
    return Plugin_Handled;
}

public void AdminMenu_QuickSprayRemove(TopMenu hTopMenu, TopMenuAction action, TopMenuObject id, int param, char[] buf, int maxlen)
{
    if (!IsValidClient(param)) return;

    switch (action) {
        case TopMenuAction_DisplayOption: Format(buf, maxlen, "Quickly Remove Spray", param);
        case TopMenuAction_SelectOption:
        {
            Command_QuickRemoveSpray(param, 0);
            g_hAdminMenu.Display(param, TopMenuPosition_LastCategory);
        }
    }
}

/** ----------------------------- Commands: remove all ----------------------- */

public Action Command_RemoveAllSprays(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;

    char adminName[MAX_NAME_LENGTH];
    GetClientName(client, adminName, sizeof(adminName));

    for (int i = 1; i <= MaxClients; i++) {
        if (!UserCanTarget(client, i)) continue;
        float endPos[3];
        SprayDecal(i, 0, endPos);
        g_Spray[i].pos = ZERO_VECTOR;
    }

    PrintToChat(client, "[SSH] %T", "Sprays Removed", client, adminName);
    LogAction(client, -1, "[SSH] %T", "Sprays Removed", LANG_SERVER, adminName);
    return Plugin_Handled;
}

public void AdminMenu_RemoveAllSprays(TopMenu hTopMenu, TopMenuAction action, TopMenuObject id, int param, char[] buf, int maxlen)
{
    if (!IsValidClient(param)) return;

    switch (action) {
        case TopMenuAction_DisplayOption: Format(buf, maxlen, "Remove All Sprays", param);
        case TopMenuAction_SelectOption:
        {
            Command_RemoveAllSprays(param, 0);
            g_hAdminMenu.Display(param, TopMenuPosition_LastCategory);
        }
    }
}

/** ----------------------------- Commands: admin spray ---------------------- */

public Action Command_AdminSpray(int client, int args)
{
    if (!IsValidClient(client)) {
        if (client == 0) {
            ReplyToCommand(client, "[SSH] Command is in-game only.");
        }
        return Plugin_Handled;
    }

    char arg[MAX_NAME_LENGTH];
    int target = client;

    if (args >= 1) {
        GetCmdArg(1, arg, sizeof(arg));
        target = FindTarget(client, arg, false, false);
        if (!IsValidClient(target)) {
            return Plugin_Handled;
        }
        if (!UserCanTarget(client, target)) {
            return Plugin_Handled;
        }
    }

    if (!GoSpray(client, target)) {
        ReplyToCommand(client, "%s[SSH] %T", GetCmdReplySource() == SM_REPLY_TO_CHAT ? "\x04" : "", "Cannot Spray", client);
    } else {
        ReplyToCommand(client, "%s[SSH] %T", GetCmdReplySource() == SM_REPLY_TO_CHAT ? "\x04" : "", "Admin Sprayed", client, client, target);
        LogAction(client, -1, "[SSH] %T", "Admin Sprayed", LANG_SERVER, client, target);
    }

    return Plugin_Handled;
}

void DisplayAdminSprayMenu(int client, int pos = 0)
{
    if (!IsValidClient(client)) return;

    Menu menu = new Menu(MenuHandler_AdminSpray);
    menu.SetTitle("%T", "Admin Spray Menu", client);
    menu.ExitBackButton = true;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            char info[8], name[MAX_NAME_LENGTH];
            IntToString(GetClientUserId(i), info, sizeof(info));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(info, name);
        }
    }

    if (pos == 0) menu.Display(client, MENU_TIME_FOREVER);
    else          menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public void AdminMenu_AdminSpray(TopMenu hTopMenu, TopMenuAction action, TopMenuObject id, int param, char[] buf, int maxlen)
{
    if (!IsValidClient(param)) return;

    switch (action) {
        case TopMenuAction_DisplayOption: Format(buf, maxlen, "%T", "AdminSpray", param);
        case TopMenuAction_SelectOption:  DisplayAdminSprayMenu(param);
    }
}

public void MenuHandler_AdminSpray(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action) {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));

            int target = GetClientOfUserId(StringToInt(info));
            if (target == 0 || !IsClientInGame(target)) {
                PrintToChat(param1, "[SSH] %T", "Could Not Find", param1);
            } else {
                GoSpray(param1, target);
            }
            DisplayAdminSprayMenu(param1, menu.Selection);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack && g_hAdminMenu != null) {
                g_hAdminMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

/** ----------------------------- Spray helpers ------------------------------ */

public bool GoSpray(int client, int target)
{
    if (!UserCanTarget(client, target)) {
        return false;
    }

    char spray[8];
    if (!GetPlayerDecalFile(target, spray, sizeof(spray))) {
        return false;
    }

    float endPos[3];
    if (!GetClientEyeEndLocation(client, endPos)) {
        return false;
    }

    int traceEntIndex = TR_GetEntityIndex();
    if (traceEntIndex < 0) traceEntIndex = 0;

    SprayDecal(target, traceEntIndex, endPos);
    EmitSoundToAll("player/sprayer.wav", SOUND_FROM_WORLD, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, _, _, _, endPos);
    return true;
}

public void SprayDecal(int client, int entIndex, float vecPos[3])
{
    if (!IsValidClient(client)) return;

    TE_Start("Player Decal");
    TE_WriteVector("m_vecOrigin", vecPos);
    TE_WriteNum("m_nEntity", entIndex);
    TE_WriteNum("m_nPlayer", client);
    TE_SendToAll();
}

/** ----------------------------- Utility ----------------------------------- */

stock int FindSprayAt(const float pos[3], float maxDist)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !CheckForZero(g_Spray[i].pos)) {
            if (GetVectorDistance(pos, g_Spray[i].pos) <= maxDist) {
                return i;
            }
        }
    }
    return -1;
}

public int GetClientFromAuthID(const char[] auth)
{
    char other[32];
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            if (GetClientAuthId(i, AuthId_Steam2, other, sizeof(other))) {
                if (strcmp(other, auth) == 0) {
                    return i;
                }
            }
        }
    }
    return 0;
}

public bool TraceEntityFilter_NoPlayers(int entity, int contentsMask) { return entity > MaxClients; }
public bool TraceEntityFilter_OnlyWorld(int entity, int contentsMask) { return entity == 0; }

stock bool CheckForZero(const float v[3]) { return v[0]==0.0 && v[1]==0.0 && v[2]==0.0; }
stock bool IsValidClient(int c) { return (0 < c <= MaxClients && IsClientInGame(c)); }

public void GlowEffect(int client, float pos[3], float life, float size, int bright, int model)
{
    if (!IsValidClient(client)) return;

    int one[1]; one[0] = client;
    TE_SetupGlowSprite(pos, model, life, size, bright);
    TE_Send(one, 1);
}

public bool GetClientEyeEndLocation(int client, float outVec[3])
{
    if (!IsValidClient(client)) {
        return false;
    }

    float origin[3], angles[3];
    GetClientEyePosition(client, origin);
    GetClientEyeAngles(client, angles);

    Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, ValidSpray);

    if (TR_DidHit(trace)) {
        TR_GetEndPosition(outVec, trace);
        delete trace;
        return true;
    }

    delete trace;
    return false;
}

public bool ValidSpray(int entity, int contentsmask) { return entity > MaxClients; }

/** ----------------------------- Text helpers --------------------------------
 * HintText and KeyHintText writers kept as stock utilities
 */

stock bool Client_PrintHintText(int client, const char[] format, any ...)
{
    Handle msg = StartMessageOne("HintText", client);
    if (msg == INVALID_HANDLE) {
        return false;
    }

    char buffer[254];
    SetGlobalTransTarget(client);
    VFormat(buffer, sizeof(buffer), format, 3);

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available
        && GetUserMessageType() == UM_Protobuf)
    {
        PbSetString(msg, "text", buffer);
    }
    else
    {
        BfWriteByte(msg, 1);
        BfWriteString(msg, buffer);
    }

    EndMessage();
    return true;
}

stock bool Client_PrintKeyHintText(int client, const char[] format, any ...)
{
    Handle msg = StartMessageOne("KeyHintText", client);
    if (msg == INVALID_HANDLE) {
        return false;
    }

    char buffer[254];
    SetGlobalTransTarget(client);
    VFormat(buffer, sizeof(buffer), format, 3);

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available
        && GetUserMessageType() == UM_Protobuf)
    {
        // KeyHintText uses a repeated "hints" field under protobuf
        PbAddString(msg, "hints", buffer);
    }
    else
    {
        BfWriteByte(msg, 1);
        BfWriteString(msg, buffer);
    }

    EndMessage();
    return true;
}
