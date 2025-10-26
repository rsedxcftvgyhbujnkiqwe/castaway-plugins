#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <morecolors>

public Plugin myinfo = {
    name = "Chat Adverts",
    author = "random",
    description = "Automatically send configured messages to chat using crontabs",
    version = "1.0",
    url = "https://castaway.tf"
};

enum struct CronSchedule {
    int min[2];
    int hour[2];
    int dom[2];
    int mon[2];
    int dow[2];

}

enum MessageGroupSendType {
    SEND_SEQUENTIAL,
    SEND_RANDOM,
    SEND_PICKRANDOM,
}

enum struct MessageGroup {
    CronSchedule cron;
    int msg_count;
    int msg_index;
    int picked_msg;
    MessageGroupSendType send_type;
}

#define MAX_GROUPS 16
#define MAX_MSGS 32
#define MAX_MSG_LEN 256
#define CRON_FIELD_SIZE 64

char g_Messages[MAX_GROUPS][MAX_MSGS][MAX_MSG_LEN];
MessageGroup g_MessageGroups[MAX_GROUPS];
int g_MessageGroupCount;
int g_LastMin;
ConVar g_cvAllowClientsDisable;
Cookie g_cChatDisable;

public void OnPluginStart() {
    LoadTranslations("chatadverts.phrases");

    g_cvAllowClientsDisable = CreateConVar("sm_chat_adverts_allow_clients_disable", "1", "Allow clients to disable chat adverts.");
    g_cChatDisable = new Cookie("Chat adverts disable", "Disable chat adverts", CookieAccess_Private);
    RegAdminCmd("sm_chatadverts_reload", Cmd_Reload, ADMFLAG_RCON);
    RegConsoleCmd("sm_toggleadverts", Cmd_ToggleAdverts, "Toggle chat adverts");
    CCheckTrie();
    LoadCustomColors();
    LoadCrons();
    g_LastMin = GetTime() / 60;
    CreateTimer(1.0, CronDaemon,_,TIMER_REPEAT);

    AutoExecConfig();
}

public Action Cmd_Reload(int client, int args) {
    LoadCustomColors();
    LoadCrons();
    ReplyToCommand(client, "[ChatAdverts] Reloaded config.");
    return Plugin_Handled;
}

public Action Cmd_ToggleAdverts(int client, int args) {
    if (!g_cvAllowClientsDisable.BoolValue) {
        ReplyToCommand(client, "%t", "CHAT_ADVERTS_TOGGLE_NOT_ALLOWED");
        return Plugin_Handled;
    }
    if (AreClientCookiesCached(client)) {
        int configValue = g_cChatDisable.GetInt(client, 0);
        ReplyToCommand(client, "%t", configValue ? "CHAT_ADVERTS_ENABLED" : "CHAT_ADVERTS_DISABLED");
        g_cChatDisable.SetInt(client, configValue ? 0 : 1);
    }
    return Plugin_Handled;
}

Action CronDaemon(Handle timer, any data) {
    int timestamp = GetTime();
    int cur_min = timestamp/60;
    if (cur_min != g_LastMin) {
        g_LastMin =  cur_min;
        CheckAndRunCrons(timestamp);
    }
    return Plugin_Continue;
}

void LoadCustomColors() {
    // load file
    char cfg_file[64] = "configs/chatadverts.cfg";
    KeyValues kv = new KeyValues("ChatAdverts");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), cfg_file);
    if (!kv.ImportFromFile(path))  { 
        LogError("ChatAdverts: failed to read %s", path);
        delete kv;
        return;
    }

    // iterate over contents
    kv.Rewind();
    if (!kv.JumpToKey("CustomColors", false)) { 
        LogError("ChatAdverts: CustomColors block missing in %s", path);
        delete kv;
        return;
    }
    if (kv.GotoFirstSubKey(false))
    {
        char name[64], hex[7];
        do {
            kv.GetSectionName(name, sizeof(name));
            kv.GetString(NULL_STRING, hex, sizeof(hex));
            SetTrieValue(CTrie, name, StringToInt(hex, 16));
        } while (kv.GotoNextKey(false));
    }
    delete kv;
    PrintToServer("[Chat Adverts]: Loaded Custom Colors");
}

void LoadCrons() {
    // load file
    char cfg_file[64] = "configs/chatadverts.cfg";
    KeyValues kv = new KeyValues("ChatAdverts");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), cfg_file);
    if (!kv.ImportFromFile(path))  { 
        LogError("ChatAdverts: failed to read %s", path);
        delete kv;
        return;
    }

    // reset necessary vars
    int group_index = 0;
    g_MessageGroupCount = 0;
    char group_name[128];

    // iterate over contents
    kv.Rewind();
    if (!kv.JumpToKey("MessageGroups", false)) { 
        LogError("ChatAdverts: MessageGroups block missing in %s", path);
        delete kv;
        return;
    }
    if (kv.GotoFirstSubKey(false))
    {
        do {
            if (g_MessageGroupCount >= MAX_GROUPS) { 
                LogError("ChatAdverts: reached MAX_GROUPS=%d; extra groups ignored", MAX_GROUPS);
                break;
            }

            group_index = g_MessageGroupCount++;

            group_name[0] = '\0';
            kv.GetSectionName(group_name, sizeof(group_name));

            // read configured values in
            char sMinute[CRON_FIELD_SIZE], sHour[CRON_FIELD_SIZE], sDOW[CRON_FIELD_SIZE], sDOM[CRON_FIELD_SIZE], sMon[CRON_FIELD_SIZE], sType[CRON_FIELD_SIZE];
            kv.GetString("minute",     sMinute, sizeof(sMinute), "*");
            kv.GetString("hour",       sHour,   sizeof(sHour),   "*");
            kv.GetString("dayofweek",  sDOW,    sizeof(sDOW),    "*");
            kv.GetString("dayofmonth", sDOM,    sizeof(sDOM),    "*");
            kv.GetString("month",      sMon,    sizeof(sMon),    "*");
            kv.GetString("type",       sType,   sizeof(sType),   "sequential");

            // parse cron configs
            if (!ParseCronField(sMinute, g_MessageGroups[group_index].cron.min, 0, 59, false)) {
                LogError("Invalid cron '%s' for field minute in group '%s'", sMinute, group_name);
                g_MessageGroupCount--;
                continue;
            }
            if (!ParseCronField(sHour, g_MessageGroups[group_index].cron.hour, 0, 23, false)) {
                LogError("Invalid cron '%s' for field hour in group '%s'", sHour, group_name);
                g_MessageGroupCount--;
                continue;
            }
            if (!ParseCronField(sDOW, g_MessageGroups[group_index].cron.dow, 0, 7, true)) {
                LogError("Invalid cron '%s' for field day of week in group '%s'", sDOW, group_name);
                g_MessageGroupCount--;
                continue;
            }
            if (!ParseCronField(sDOM, g_MessageGroups[group_index].cron.dom, 1, 31, false)) {
                LogError("Invalid cron '%s' for field day of month in group '%s'", sDOM, group_name);
                g_MessageGroupCount--;
                continue;
            }
            if (!ParseCronField(sMon, g_MessageGroups[group_index].cron.mon, 1, 12, false)) {
                LogError("Invalid cron '%s' for field month in group '%s'", sMon, group_name);
                g_MessageGroupCount--;
                continue;
            }

            // send type
            if (StrEqual(sType, "random", false)) {
                g_MessageGroups[group_index].send_type = SEND_RANDOM;
                g_MessageGroups[group_index].msg_index = GetNextMessageIndex(group_index);
            }
            else if (StrEqual(sType, "pickrandom", false)) {
                g_MessageGroups[group_index].send_type = SEND_PICKRANDOM;
                g_MessageGroups[group_index].msg_index = GetNextMessageIndex(group_index);
            }
            else {
                g_MessageGroups[group_index].send_type = SEND_SEQUENTIAL;
                g_MessageGroups[group_index].msg_index = 0;
            }

            // iterate through messages
            g_MessageGroups[group_index].msg_count = 0;
            if (!kv.JumpToKey("Messages", false)) {
                LogError("ChatAdverts: group '%s' missing Messages block", group_name);
                g_MessageGroupCount--;
                continue;
            } else {
                int count = 0;
                if (kv.GotoFirstSubKey(false))
                {
                    do {
                        char msg[MAX_MSG_LEN];
                        kv.GetString(NULL_STRING, msg, sizeof(msg), "");
                        if (msg[0] == '\0') continue;
                        if (count >= MAX_MSGS) { 
                            LogError("ChatAdverts: group '%s' exceeded MAX_MSGS=%d; extra messages dropped", group_name, MAX_MSGS);
                            break;
                        }
                        strcopy(g_Messages[group_index][count], MAX_MSG_LEN, msg);
                        count++;
                    } while (kv.GotoNextKey(false));
                    kv.GoBack();
                }
                g_MessageGroups[group_index].msg_count = count;
                kv.GoBack();
                if (count == 0) LogError("ChatAdverts: group '%s' has zero messages", group_name);
            }
        } while (kv.GotoNextKey(false));
    }
    delete kv;
    PrintToServer("[Chat Adverts]: Loaded Message Groups");
}

void CheckAndRunCrons(int timestamp) {
    int min,hour,dow,dom,mon;
    GetDateValues(timestamp, mon, dom, hour, min, dow);

    for (int i = 0; i < g_MessageGroupCount; i++) {
        CronSchedule c;
        c = g_MessageGroups[i].cron;
        if (
            (c.min[min/32] & (1 << (min%32))) &&
            (c.hour[0] & (1 << hour)) &&
            (c.mon[0] & (1 << mon)) &&
            ((c.dow[0] & (1 << dow)) ||
            (c.dom[0] & (1 << dom)))
        ) {
            ExecuteMessageGroup(i);
        }
    }
}

void ExecuteMessageGroup(int group_index) {
    CPrintToChatAllOnPref("%s", g_Messages[group_index][g_MessageGroups[group_index].msg_index]);
    g_MessageGroups[group_index].msg_index = GetNextMessageIndex(group_index);
}

void CPrintToChatAllOnPref(const char[] message, any...) {
    CCheckTrie();
    char buffer[MAX_BUFFER_LENGTH], buffer2[MAX_BUFFER_LENGTH];
    bool canClientDisable = g_cvAllowClientsDisable.BoolValue;
    for (int i = 1; i <= MaxClients; i++) {
        if(!IsClientInGame(i) || CSkipList[i]) {
            CSkipList[i] = false;
            continue;
        }

        if (canClientDisable && g_cChatDisable.GetInt(i, 0)) {
            continue;
        }

        Format(buffer, sizeof(buffer), "\x01%s", message);
        VFormat(buffer2, sizeof(buffer2), buffer, 2);
        CReplaceColorCodes(buffer2);
        CSendMessage(i, buffer2);
    }
}

int GetNextMessageIndex(int group_index) {
    int message_index = 0;
    switch(g_MessageGroups[group_index].send_type) {
        case SEND_SEQUENTIAL: {
            message_index = (g_MessageGroups[group_index].msg_index + 1)%g_MessageGroups[group_index].msg_count;
        }
        case SEND_RANDOM: {
            message_index = GetRandomInt(0,g_MessageGroups[group_index].msg_count-1);
        }
        case SEND_PICKRANDOM: {
            int mask = (1 << g_MessageGroups[group_index].msg_count) - 1;
            if ((g_MessageGroups[group_index].picked_msg & mask) == mask) {
                g_MessageGroups[group_index].picked_msg = 0;
            }
            for (;;) {
                int random_pick = GetRandomInt(0,g_MessageGroups[group_index].msg_count-1);
                if (g_MessageGroups[group_index].picked_msg & (1 << random_pick)) {
                    continue;
                } else {
                    g_MessageGroups[group_index].picked_msg |= 1 << random_pick;
                    message_index = random_pick;
                    break;
                }
            }
        }
    }
    return message_index;
}

bool ParseCronField(const char[] fieldStr, int result[2], int minv, int maxv, bool wrap) {
    if(fieldStr[0]=='\0') {
        LogError("Empty cron field");
        return false;
    }
    result[0] = 0;
    result[1] = 0;
    char parts[32][8],current[8],leftpart[8],rightpart[8];
    int num_parts = ExplodeString(fieldStr,",",parts,32,8);
    bool left = true;
    bool range,step;
    int count,leftint,rightint;
    for (int i = 0; i < num_parts; i++) {
        strcopy(current,sizeof(current),parts[i]);

        if (current[0] == '\0') {
            continue;
        }

        leftpart[0] = '\0';
        rightpart[0] = '\0';
        range = false;
        step = false;
        left = true;
        count = 0;

        for (int j = 0; j < sizeof(parts[i]); j++) {
            if ((current[j] >= '0' && current[j] <= '9') || current[j] == '*' || current[j] == '\0') {
                if(left) {
                    leftpart[count] = current[j];
                } else {
                    rightpart[count] = current[j];
                }
                count++;
                if (current[j] == '\0') break;
            } else if (current[j]=='-' && range == false) {
                leftpart[count] = '\0';
                left = false;
                count = 0;
                range = true;
            } else if (current[j]=='/' && step == false) {
                leftpart[count] = '\0';
                left = false;
                count = 0;
                step = true;
            } else if (current[j]==' ') {
                // ignore
            } else {
                // unparseable cron!
                LogError("Invalid character %c for cron field %s",current[j],fieldStr);
                return false;
            }
        }

        // if wildcard is second, just ignore it
        if (StrEqual(rightpart,"*")) {
            left = true;
        }

        leftint = StringToInt(leftpart,10);
        if (
            (leftint == 0 && 
            !StrEqual(leftpart,"0") && 
            !StrEqual(leftpart,"*")) || 
            leftint > maxv ||
            (leftint < minv &&
            !StrEqual(leftpart,"*"))
        ) {
            // conversion failure
            LogError("Invalid lefthand side %s for cron part %s",leftpart,current);
            return false;
        }

        if (left) {
            if(StrEqual(leftpart, "*")) {
                // wildcard, return all
                result[0] = ~0;
                result[1] = ~0;
                return true;
            }

            // single int, just set that bit flag only
            result[leftint/32] |= 1 << (leftint%32);
        } else {
            // right int technically can be arbitrarily large and it will just run once
            rightint = StringToInt(rightpart,10);
            if (rightint == 0) {
                LogError("Invalid righthand side %s for cron part %s",rightpart,current);
                // no zero or wildcard
                return false;
            }
            if (range) {
                // *-n -> *
                // I don't know who would use this syntax but whatever
                if(StrEqual(leftpart,"*")) {
                    result[0] = ~0;
                    result[1] = ~0;
                    return true;
                }

                // invalid range
                if (leftint > rightint) {
                    LogError("Invalid range %s for cron part",current);
                    return false;
                }

                // x-y
                // set all from x to y
                for (int j=leftint; j<=rightint; j++) {
                    result[j/32] |= 1 << (j%32);
                }
            } else if (step) {

                // in this case * functions as zero 
                // so no handling is needed for the left side

                for (int j=leftint; j<=maxv; j += rightint) {
                    result[j/32] |= 1 << (j%32);
                }
            } else {
                LogError("Side flag checked incorrectly for %s",current);
                return false;
            }
        }
    }

    if (wrap) {
        if(result[maxv/32] & 1 << (maxv%32)) {
            result[minv/32] |= 1 << minv;
        }
    }
    return true;
}

stock void GetDateValues(int t, int &mon, int &dom, int &hour, int &min, int &dow) {
    char buf[32];
    FormatTime(buf, sizeof(buf), "%m %d %H %M %w", t);
    char parts[5][8];
    ExplodeString(buf, " ", parts, sizeof(parts), sizeof(parts[]));
    mon  = StringToInt(parts[0]);
    dom  = StringToInt(parts[1]);
    hour = StringToInt(parts[2]);
    min  = StringToInt(parts[3]);
    dow  = StringToInt(parts[4]);
}
