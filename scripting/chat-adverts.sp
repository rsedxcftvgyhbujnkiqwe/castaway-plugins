#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
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
#define CRON_FIELD_SIZE 256

char g_Messages[MAX_GROUPS][MAX_MSGS][MAX_MSG_LEN];
MessageGroup g_MessageGroups[MAX_GROUPS];
int g_MessageGroupCount;

public void OnPluginStart() {
    CCheckTrie();
    LoadCustomColors();
    LoadCrons();
    CreateTimer(1.0, CronDaemon,_,TIMER_REPEAT);
}

Action CronDaemon(Handle timer, any data) {
    int timestamp = GetTime();
    if (timestamp % 60 == 0) {
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
            if (!ParseCronField(sMinute, g_MessageGroups[group_index].cron.min, 59, false)) {
                LogError("Invalid cron '%s' for field minute in group '%s'", sMinute, group_name);
                group_index--;
                continue;
            }
            if (!ParseCronField(sHour, g_MessageGroups[group_index].cron.hour, 23, false)) {
                LogError("Invalid cron '%s' for field hour in group '%s'", sHour, group_name);
                group_index--;
                continue;
            }
            if (!ParseCronField(sDOW, g_MessageGroups[group_index].cron.dow, 7, true)) {
                LogError("Invalid cron '%s' for field day of week in group '%s'", sDOW, group_name);
                group_index--;
                continue;
            }
            if (!ParseCronField(sDOM, g_MessageGroups[group_index].cron.dom, 30, false)) {
                LogError("Invalid cron '%s' for field day of month in group '%s'", sDOM, group_name);
                group_index--;
                continue;
            }
            if (!ParseCronField(sMon, g_MessageGroups[group_index].cron.mon, 11, false)) {
                LogError("Invalid cron '%s' for field month in group '%s'", sMon, group_name);
                group_index--;
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
                group_index--;
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
    MessageGroup grp;
    grp = g_MessageGroups[group_index];
    CPrintToChatAll("%s", g_Messages[group_index][grp.msg_index]);
    grp.msg_index = GetNextMessageIndex(group_index);
}

int GetNextMessageIndex(int group_index) {
    MessageGroup grp;
    grp = g_MessageGroups[group_index];
    int message_index = 0;
    switch(grp.send_type) {
        case SEND_SEQUENTIAL: {
            message_index = (message_index + 1)%grp.msg_count;
        }
        case SEND_RANDOM: {
            message_index = GetRandomInt(0,grp.msg_count-1);
        }
        case SEND_PICKRANDOM: {
            if (grp.picked_msg & ((1 << grp.msg_count) - 1)) {
                grp.picked_msg = 0;
            }
            for (;;) {
                int random_pick = GetRandomInt(0,grp.msg_count-1);
                if (grp.picked_msg & (1 << random_pick)) {
                    continue;
                } else {
                    grp.picked_msg |= 1 << random_pick;
                    message_index = random_pick;
                    break;
                }
            }
        }
    }
    return message_index;
}

bool ParseCronField(const char[] fieldStr, int result[2], int max, bool wrap) {
    if(fieldStr[0]=='\0') {
        return false;
    }
    result[0] = 0;
    result[1] = 0;
    char part[16],current[CRON_FIELD_SIZE],buffer[CRON_FIELD_SIZE],leftpart[16],rightpart[16];
    strcopy(current, sizeof(current), fieldStr);
    bool left = true;
    bool range,step;
    int previous,count,leftint,rightint;
    do {
        strcopy(buffer, sizeof(buffer), current[previous]);
        strcopy(current, sizeof(current), buffer);
        previous = SplitString(buffer,",",part,sizeof(part)) + 1;

        if (part[0] == '\0') {
            continue;
        }

        leftpart[0] = '\0';
        rightpart[0] = '\0';
        range = false;
        step = false;
        left = true;
        count = 0;

        for (int i = 0; i < sizeof(part); i++) {
            if ((part[i] >= '0' && part[i] <= '9') || part[i] == '*') {
                if(left) {
                    leftpart[count] = part[i];
                } else {
                    rightpart[count] = part[i];
                }
                count++;
            } else if (part[i]=='-' && range == false) {
                leftpart[count] = '\0';
                left = false;
                count = 0;
                range = true;
            } else if (part[i]=='/' && step == false) {
                leftpart[count] = '\0';
                left = false;
                count = 0;
                step = true;
            } else {
                // unparseable cron!
                return false;
            }
        }
        rightpart[count] = '\0';

        // if wildcard is second, just ignore it
        if (StrEqual(rightpart,"*")) {
            left = true;
        }

        if (left) {
            if(StrEqual(leftpart, "*")) {
                // wildcard, return all
                result[0] = ~0;
                result[1] = ~0;
                return true;
            }

            leftint = StringToInt(leftpart,10);

            if (leftint == 0 && !StrEqual(leftpart,"0") || leftint > max) {
                // conversion failure
                return false;
            }

            // single int, just set that bit flag only
            result[1] |= 1 << leftint;
        } else {
            leftint = StringToInt(leftpart,10);
            rightint = StringToInt(rightpart,10);
            // right int technically can be arbitrarily large and it will just run once
            if (rightint == 0) {
                return false;
            }
            if (leftint > max) {
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
                    return false;
                }

                // x-y
                // set all from x to y
                for (int i=leftint; i<=rightint; i++) {
                    result[i/32] |= 1 << (i%32);
                }
            } else if (step) {

                // in this case * functions as zero 
                // so no handling is needed for the left side

                for (int i=leftint; i<max; i += rightint) {
                    result[i/32] |= 1 << (i%32);
                }
            } else {
                return false;
            }
        }

    } while (previous != 0);

    if (wrap) {
        if(result[0] & 1) {
            result[max/32] |= 1 << (max%32);
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
