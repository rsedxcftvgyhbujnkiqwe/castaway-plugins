#include <sourcemod>
#include <morecolors>

public Plugin myinfo = {
    name = "Chat Adverts",
    author = "random",
    description = "Automatically send configured messages to chat using crontabs",
    version = "1.0",
    url = "https://castaway.tf"
};

#define MAX_GROUPS 64
#define MAX_MSGS 128
#define MAX_MSG_LEN 256

enum CronFieldType {
    CF_MINUTE = 60,
    CF_HOUR = 24,
    CF_DOM = 32,
    CF_MONTH = 13,
    CF_DOW = 7,
}

enum struct CronSpec {
    bool min[CF_MINUTE];
    bool hour[CF_HOUR];
    bool dom[CF_DOM];
    bool mon[CF_MONTH];
    bool dow[CF_DOW];
}

enum MessageGroupSendType {
    SEND_SEQUENTIAL,
    SEND_RANDOM,
    SEND_PICKRANDOM,
}

enum struct MessageGroup {
    char name[96];
    CronSpec cron_data;
    MessageGroupSendType send_type;
    int msg_count;
    Handle timer;
    int next_seq_index;
    int pr_order[MAX_MSGS];
    int pr_len;
    int pr_pos;
}

char g_Messages[MAX_GROUPS][MAX_MSGS][MAX_MSG_LEN];
MessageGroup g_MessageGroups[MAX_GROUPS];
int g_MessageGroupCount = 0;

public void OnPluginStart() {
    CCheckTrie();
    LoadCustomColors();
    LoadMessageGroups();
    RescheduleAll();
    RegAdminCmd("sm_chatadverts_reload", Cmd_Reload, ADMFLAG_RCON);
}

public void OnPluginEnd() {
    KillAllTimers();
}

public Action Cmd_Reload(int client, int args) {
    LoadCustomColors();
    LoadMessageGroups();
    RescheduleAll();
    ReplyToCommand(client, "[ChatAdverts] Reloaded config and rescheduled.");
    return Plugin_Handled;
}

void LoadCustomColors() {
    char cfg_file[64] = "configs/chatadverts.cfg";
    KeyValues kv = new KeyValues("ChatAdverts");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), cfg_file);
    if (!kv.ImportFromFile(path))  { LogError("ChatAdverts: failed to read %s", path); delete kv; return; }
    kv.Rewind();
    if (!kv.JumpToKey("CustomColors", false)) { LogError("ChatAdverts: CustomColors block missing in %s", path); delete kv; return; }
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

void LoadMessageGroups() {
    char cfg_file[64] = "configs/chatadverts.cfg";
    KeyValues kv = new KeyValues("ChatAdverts");
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), cfg_file);
    if (!kv.ImportFromFile(path))  { LogError("ChatAdverts: failed to read %s", path); delete kv; return; }
    g_MessageGroupCount = 0;
    for (int i = 0; i < MAX_GROUPS; i++) {
        g_MessageGroups[i].name[0] = '\0';
        g_MessageGroups[i].msg_count = 0;
        g_MessageGroups[i].send_type = SEND_SEQUENTIAL;
        g_MessageGroups[i].timer = null;
        g_MessageGroups[i].next_seq_index = 0;
        g_MessageGroups[i].pr_len = 0;
        g_MessageGroups[i].pr_pos = 0;
        ResetArray(g_MessageGroups[i].cron_data.min,  CF_MINUTE, false);
        ResetArray(g_MessageGroups[i].cron_data.hour, CF_HOUR,   false);
        ResetArray(g_MessageGroups[i].cron_data.dom,  CF_DOM,    false);
        ResetArray(g_MessageGroups[i].cron_data.mon,  CF_MONTH,  false);
        ResetArray(g_MessageGroups[i].cron_data.dow,  CF_DOW,    false);
    }
    kv.Rewind();
    if (!kv.JumpToKey("MessageGroups", false)) { LogError("ChatAdverts: MessageGroups block missing in %s", path); delete kv; return; }
    if (kv.GotoFirstSubKey(false))
    {
        do {
            if (g_MessageGroupCount >= MAX_GROUPS) { LogError("ChatAdverts: reached MAX_GROUPS=%d; extra groups ignored", MAX_GROUPS); break; }
            int gi = g_MessageGroupCount++;
            char gname[96] = "";
            kv.GetSectionName(gname, sizeof(gname));
            strcopy(g_MessageGroups[gi].name, sizeof(g_MessageGroups[gi].name), gname);

            char sMinute[64], sHour[64], sDOW[64], sDOM[64], sMon[64], sType[32];
            kv.GetString("minute",     sMinute, sizeof(sMinute), "*");
            kv.GetString("hour",       sHour,   sizeof(sHour),   "*");
            kv.GetString("dayofweek",  sDOW,    sizeof(sDOW),    "*");
            kv.GetString("dayofmonth", sDOM,    sizeof(sDOM),    "*");
            kv.GetString("month",      sMon,    sizeof(sMon),    "*");
            kv.GetString("type",       sType,   sizeof(sType),   "sequential");

            bool okMin = ParseCronFieldIntoArray(sMinute, CF_MINUTE, g_MessageGroups[gi].cron_data.min);
            bool okHr  = ParseCronFieldIntoArray(sHour,   CF_HOUR,   g_MessageGroups[gi].cron_data.hour);
            bool okDom = ParseCronFieldIntoArray(sDOM,    CF_DOM,    g_MessageGroups[gi].cron_data.dom);
            bool okMon = ParseCronFieldIntoArray(sMon,    CF_MONTH,  g_MessageGroups[gi].cron_data.mon);
            bool okDow = ParseCronFieldIntoArray(sDOW,    CF_DOW,    g_MessageGroups[gi].cron_data.dow);
            if (!okMin) LogError("ChatAdverts: invalid cron '%s' for field minute in group '%s'", sMinute, g_MessageGroups[gi].name);
            if (!okHr)  LogError("ChatAdverts: invalid cron '%s' for field hour in group '%s'", sHour, g_MessageGroups[gi].name);
            if (!okDom) LogError("ChatAdverts: invalid cron '%s' for field dayofmonth in group '%s'", sDOM, g_MessageGroups[gi].name);
            if (!okMon) LogError("ChatAdverts: invalid cron '%s' for field month in group '%s'", sMon, g_MessageGroups[gi].name);
            if (!okDow) LogError("ChatAdverts: invalid cron '%s' for field dayofweek in group '%s'", sDOW, g_MessageGroups[gi].name);

            if      (StrEqual(sType, "sequential", false)) g_MessageGroups[gi].send_type = SEND_SEQUENTIAL;
            else if (StrEqual(sType, "random",     false)) g_MessageGroups[gi].send_type = SEND_RANDOM;
            else if (StrEqual(sType, "pickrandom", false)) g_MessageGroups[gi].send_type = SEND_PICKRANDOM;
            else                                            g_MessageGroups[gi].send_type = SEND_SEQUENTIAL;

            g_MessageGroups[gi].msg_count = 0;
            if (!kv.JumpToKey("Messages", false)) {
                LogError("ChatAdverts: group '%s' missing Messages block", g_MessageGroups[gi].name);
            } else {
                int count = 0;
                if (kv.GotoFirstSubKey(false))
                {
                    do {
                        char msg[MAX_MSG_LEN];
                        kv.GetString(NULL_STRING, msg, sizeof(msg), "");
                        if (msg[0] == '\0') continue;
                        if (count >= MAX_MSGS) { LogError("ChatAdverts: group '%s' exceeded MAX_MSGS=%d; extra messages dropped", g_MessageGroups[gi].name, MAX_MSGS); break; }
                        strcopy(g_Messages[gi][count], MAX_MSG_LEN, msg);
                        count++;
                    } while (kv.GotoNextKey(false));
                    kv.GoBack();
                }
                g_MessageGroups[gi].msg_count = count;
                kv.GoBack();
                if (count == 0) LogError("ChatAdverts: group '%s' has zero messages", g_MessageGroups[gi].name);
            }
        } while (kv.GotoNextKey(false));
    }
    delete kv;
    PrintToServer("[Chat Adverts]: Loaded Message Groups");
}

stock void RescheduleAll() {
    KillAllTimers();
    InitializeRuntimeState();
    for (int i = 0; i < g_MessageGroupCount; i++)
    {
        if (g_MessageGroups[i].msg_count <= 0) continue;
        ScheduleGroupTimer(i);
    }
}

stock bool ComputeNextRunWithinOneWeek(const CronSpec spec, int nowEpoch, int &nextEpochOut)
{
    int t0 = RoundUpToNextMinute(nowEpoch + 1);
    int y, mon, d, h, mi, dow;
    GetLocalPartsFull(t0, y, mon, d, h, mi, dow);
    for (int dayOffset = 0; dayOffset <= 6; dayOffset++)
    {
        int cy = y, cmon = mon, cd = d, ch = h, cmi = mi;
        if (dayOffset > 0) {
            cd++;
            int dim = DaysInMonth(cy, cmon);
            if (cd > dim) { cd = 1; cmon++; if (cmon > 12) { cmon = 1; cy++; } }
            ch = 0; cmi = 0;
        }
        if (!spec.mon[cmon]) continue;
        if (!DayMatches(spec, cy, cmon, cd)) continue;
        int startHour = (dayOffset == 0) ? ch : 0;
        int hour = NextAllowedGE(spec.hour, CF_HOUR, startHour);
        while (hour != -1)
        {
            int startMin = 0;
            if (dayOffset == 0 && hour == ch) startMin = cmi;
            int minute = NextAllowedGE(spec.min, CF_MINUTE, startMin);
            if (minute != -1) {
                int ts = MakeLocalTimestamp(cy, cmon, cd, hour, minute);
                if (ts >= 0 && ts >= t0) { nextEpochOut = ts; return true; }
            }
            hour = NextAllowedGE(spec.hour, CF_HOUR, (hour == -1) ? 0 : (hour + 1));
        }
    }
    return false;
}

stock bool ScheduleGroupTimer(int gi, int fromEpoch = -1) {
    int now = (fromEpoch >= 0) ? fromEpoch : GetTime();
    int nextEpoch;
    bool hasExact = ComputeNextRunWithinOneWeek(g_MessageGroups[gi].cron_data, now, nextEpoch);
    if (!hasExact) { LogError("ChatAdverts: no next run within 7 days for group '%s'", g_MessageGroups[gi].name); return false; }
    float delay = float(nextEpoch - GetTime());
    if (delay < 0.05) delay = 0.05;
    if (g_MessageGroups[gi].timer != null) {
        CloseHandle(g_MessageGroups[gi].timer);
        g_MessageGroups[gi].timer = null;
    }
    g_MessageGroups[gi].timer = CreateTimer(delay, Timer_FireGroup, gi, _);
    if (g_MessageGroups[gi].timer == null) { LogError("ChatAdverts: failed to create timer for group '%s'", g_MessageGroups[gi].name); return false; }
    return true;
}

public Action Timer_FireGroup(Handle timer, any data) {
    int gi = data;
    if (gi < 0 || gi >= g_MessageGroupCount) return Plugin_Stop;
    if (g_MessageGroups[gi].timer == timer)
        g_MessageGroups[gi].timer = null;
    SendGroupMessage(gi);
    ScheduleGroupTimer(gi, GetTime());
    return Plugin_Stop;
}

stock void SendGroupMessage(int gi) {
    if (g_MessageGroups[gi].msg_count <= 0) return;
    int mi = NextMessageIndex(g_MessageGroups[gi]);
    if (mi < 0 || mi >= g_MessageGroups[gi].msg_count) return;
    CPrintToChatAll("%s", g_Messages[gi][mi]);
}

stock int NextMessageIndex(MessageGroup grp) {
    if (grp.msg_count <= 0) return -1;
    switch (grp.send_type)
    {
        case SEND_SEQUENTIAL:
        {
            int idx = grp.next_seq_index;
            grp.next_seq_index = (grp.next_seq_index + 1) % grp.msg_count;
            return idx;
        }
        case SEND_RANDOM:
        {
            return GetRandomInt(0, grp.msg_count - 1);
        }
        case SEND_PICKRANDOM:
        {
            if (grp.pr_len != grp.msg_count || grp.pr_len == 0)
                InitPickRandomOrder(grp);
            if (grp.pr_pos >= grp.pr_len)
                InitPickRandomOrder(grp);
            return grp.pr_order[grp.pr_pos++];
        }
    }
    return 0;
}

stock void ShuffleIntArray(int[] arr, int len) {
    for (int i = len - 1; i > 0; i--) {
        int j = GetRandomInt(0, i);
        int tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;
    }
}

stock void InitPickRandomOrder(MessageGroup grp) {
    grp.pr_len = grp.msg_count;
    grp.pr_pos = 0;
    for (int i = 0; i < grp.pr_len; i++)
        grp.pr_order[i] = i;
    ShuffleIntArray(grp.pr_order, grp.pr_len);
}

stock bool ParseCronFieldIntoArray(const char[] cron_field, CronFieldType type, bool[] type_array)
{
    int idx = 0;
    int idy = 0;
    char token[64];
    char lhs[4];
    char base[6];
    char field[64];
    if (strlen(cron_field) >= sizeof(field)) {
        return false;
    }
    strcopy(field, sizeof(field), cron_field);
    DeleteSpaces(field);
    for (;;)
    {
        int next = SplitString(field[idx], ",", token, sizeof(token));
        if (next == -1) {
            strcopy(token, sizeof(token), field[idx]);
        }
        if (!token[0]) return false;
        idy = SplitString(token, "/", base, sizeof(base));
        {
            int delimLen = 1;
            int expected = (idy == -1) ? strlen(token) : (idy - delimLen);
            if (expected >= sizeof(base)) return false;
        }
        if (idy == -1) {
            strcopy(base, sizeof(base), token);
        }
        int interval = 0;
        if (idy >= 0) {
            int rem = strlen(token) - idy;
            if (rem <= 0) return false;
            if (!IsStringNumeric(token[idy], rem)) return false;
            interval = StringToInt(token[idy]);
            if (interval <= 0) return false;
        }
        int range_max = -1;
        idy = SplitString(base, "-", lhs, sizeof(lhs));
        {
            int delimLen = 1;
            int expected = (idy == -1) ? strlen(base) : (idy - delimLen);
            if (expected >= sizeof(lhs)) return false;
        }
        if (idy == -1) {
            strcopy(lhs, sizeof(lhs), base);
        } else {
            int rem = strlen(base) - idy;
            if (rem <= 0) return false;
            if (!IsStringNumeric(base[idy], rem)) return false;
            range_max = StringToInt(base[idy]);
        }
        int range_min = -1;
        if (!StrEqual(lhs, "*")) {
            int lenR = strlen(lhs);
            if (lenR <= 0) return false;
            if (!IsStringNumeric(lhs, lenR)) return false;
            range_min = StringToInt(lhs);
        } else if (range_max >= 0) {
            return false;
        }
        int min = range_min;
        int max = range_max;
        if (type == CF_DOW) {
            if (min == 7) min = 0;
            if (max == 7) max = 0;
        }
        if (range_max != -1 && !ValidateNumericType(max, type)) return false;
        if (range_min != -1 && !ValidateNumericType(min, type)) return false;
        if (range_max != -1 && range_min != -1 && range_max < range_min) return false;
        int lo, hi;
        GetFieldBounds(type, lo, hi);
        int from, to, offset;
        if (range_min == -1 && range_max == -1) {
            from = lo; to = hi; offset = lo;
        } else {
            from = min;
            to = (range_max == -1) ? ((interval > 0) ? hi : min) : max;
            offset = (range_min == -1) ? lo : min;
        }
        if (interval == 0) {
            for (int v = from; v <= to; v++) {
                if (ValidateNumericType(v, type)) {
                    type_array[v] = true;
                }
            }
        } else {
            int rem = ModNonNeg(from - offset, interval);
            int first = (rem == 0) ? from : (from + (interval - rem));
            for (int v = first; v <= to; v += interval) {
                if (ValidateNumericType(v, type)) {
                    type_array[v] = true;
                }
            }
        }
        if (next == -1) break;
        idx += next;
    }
    return true;
}

stock void ResetArray(bool[] array, int array_size, bool value) {
    for (int i = 0; i < array_size; i++)
        array[i] = value;
}

stock bool ValidateNumericType(int value, CronFieldType type) {
    int lo, hi;
    GetFieldBounds(type, lo, hi);
    return (value >= lo && value <= hi);
}

stock bool IsStringNumeric(const char[] string, int size) {
    for (int i = 0; i < size; i++) {
        if (!IsCharNumeric(string[i])) return false;
    }
    return size > 0;
}

stock void GetFieldBounds(CronFieldType type, int &lo, int &hi) {
    switch (type) {
        case CF_MINUTE: {lo = 0; hi = 59;}
        case CF_HOUR:   {lo = 0; hi = 23;}
        case CF_DOW:    {lo = 0; hi = 6;}
        case CF_DOM:    {lo = 1; hi = 31;}
        case CF_MONTH:  {lo = 1; hi = 12;}
    }
}

stock int ModNonNeg(int x, int m) {
    int r = x % m;
    if (r < 0) r += m;
    return r;
}

stock void DeleteSpaces(char[] s) {
    int i = 0, j = 0;
    while (s[i] != '\0')
    {
        if (s[i] != ' ')
            s[j++] = s[i];
        i++;
    }
    s[j] = '\0';
}

stock int RoundUpToNextMinute(int t) {
    return (t + 59) - ((t + 59) % 60);
}

stock void GetLocalPartsFull(int t, int &year, int &mon, int &dom, int &hour, int &min, int &dow) {
    char buf[32];
    FormatTime(buf, sizeof(buf), "%Y %m %d %H %M %w", t);
    char parts[6][8];
    ExplodeString(buf, " ", parts, sizeof(parts), sizeof(parts[]));
    year = StringToInt(parts[0]);
    mon  = StringToInt(parts[1]);
    dom  = StringToInt(parts[2]);
    hour = StringToInt(parts[3]);
    min  = StringToInt(parts[4]);
    dow  = StringToInt(parts[5]);
}

stock bool IsLeapYear(int y) {
    if (y % 400 == 0) return true;
    if (y % 100 == 0) return false;
    return (y % 4 == 0);
}

stock int DaysInMonth(int y, int m) {
    switch (m) {
        case 1,3,5,7,8,10,12: return 31;
        case 4,6,9,11: return 30;
        case 2: return IsLeapYear(y) ? 29 : 28;
    }
    return 30;
}

stock int CalcDOW(int y, int m, int d) {
    static const int t[12] = {0,3,2,5,0,3,5,1,4,6,2,4};
    if (m < 3) y -= 1;
    return (y + y/4 - y/100 + y/400 + t[m-1] + d) % 7;
}

stock bool DayFieldAllTrue(const bool[] arr, CronFieldType type) {
    int lo, hi; GetFieldBounds(type, lo, hi);
    for (int v = lo; v <= hi; v++) if (!arr[v]) return false;
    return true;
}

stock bool DayMatches(const CronSpec spec, int y, int m, int d) {
    int dow = CalcDOW(y, m, d);
    bool domOk = spec.dom[d];
    bool dowOk = spec.dow[dow];
    bool domAll = DayFieldAllTrue(spec.dom, CF_DOM);
    bool dowAll = DayFieldAllTrue(spec.dow, CF_DOW);
    if (domAll && dowAll) return true;
    if (domAll && !dowAll) return dowOk;
    if (!domAll && dowAll) return domOk;
    return (domOk || dowOk);
}

stock int NextAllowedGE(const bool[] allowed, CronFieldType type, int start) {
    int lo, hi; GetFieldBounds(type, lo, hi);
    if (start < lo) start = lo;
    for (int v = start; v <= hi; v++)
        if (allowed[v]) return v;
    return -1;
}

stock int MakeLocalTimestamp(int y, int mon, int d, int h, int mi) {
    char s[32];
    Format(s, sizeof(s), "%04d-%02d-%02d %02d:%02d", y, mon, d, h, mi);
    return ParseTime(s, "%Y-%m-%d %H:%M");
}

stock void KillAllTimers() {
    for (int i = 0; i < MAX_GROUPS; i++)
    {
        if (g_MessageGroups[i].timer != null)
        {
            CloseHandle(g_MessageGroups[i].timer);
            g_MessageGroups[i].timer = null;
        }
    }
}

stock void InitializeRuntimeState() {
    for (int i = 0; i < g_MessageGroupCount; i++)
    {
        g_MessageGroups[i].next_seq_index = 0;
        g_MessageGroups[i].pr_len = 0;
        g_MessageGroups[i].pr_pos = 0;
    }
}
