#define PLUGIN_NAME         "Chat Adverts"
#define PLUGIN_VERSION      "1.0"
#define PLUGIN_AUTHOR       "random"
#define PLUGIN_DESCRIPTION  "Tiny plugin for posting chat messages on a timer"

#include <sourcemod>
#include <morecolors>

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://castaway.tf"
};

#define MESSAGE_TAG "{day9}[Castaway]{default}"

char ChatMessages[8][255] = {
    "Visit our website at https://castaway.tf for the map list, server list, steam group, and for news!",
    "Tip: You can use !scramble if you want to scramble the teams. Teams will be scrambled on round end.",
    "This server isn't active 24/7, add us to your favorites and check the website/steam group for play schedules.",
    "Join the steam group to discuss with other players! Link is also on the website. https://steamcommunity.com/groups/castawaytf",
    "Tip: Nominate a map you want to play with !nominate, so it shows up on the next map vote.",
    "Want to change to a different map? Use !rtv to start a vote.",
    "This is a Weapon Revert server. Type !reverts for more information.",
    "This server has SourceTV enabled. Check the website for recorded demos of all matches!"
}

int message_counter = 0

public void OnPluginStart()
{
    //add custom color(s) to morecolors
    CCheckTrie();
    SetTrieValue(CTrie,"day9",0xFFA71A);

    CreateTimer(480.0, Timer_SendAdvert,_,TIMER_REPEAT);
    
    HookEvent("teamplay_round_start",EventRoundStart,EventHookMode_PostNoCopy);
}

public Action Timer_SendAdvert(Handle timer)
{
    message_counter = (++message_counter)%sizeof(ChatMessages)
    CPrintToChatAll("%s %s",MESSAGE_TAG,ChatMessages[message_counter])
    return Plugin_Continue;
}

public Action EventRoundStart(Event event, const char[] name, bool dontbroadcast) {
    int time = GetTime();

    char day_str[8];
    FormatTime(day_str,sizeof(day_str),"%d",time);
    int day = StringToInt(day_str);

    char month_str[8];
    FormatTime(month_str,sizeof(month_str),"%m",time);
    int month = StringToInt(month_str);

    if(month==6 && day > 11 && day < 20) {
        CPrintToChatAll("{legendary}Happy birthday Castaway!");
    }
    return Plugin_Continue;
}