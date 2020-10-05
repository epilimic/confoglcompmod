#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

static ConVar      BK_cvEnable;
static bool        BK_bEnable;

static int         BK_lastvalidbot      = -1;

static const float CHECKALLOWEDTIME     = 0.1;
static const float BOTREPLACEVALIDTIME  = 0.2;


void BK_OnModuleStart()
{
    HookEvent("player_bot_replace", BK_PlayerBotReplace);

    BK_cvEnable = CreateConVarEx("blockinfectedbots", "1", "Blocks infected bots from joining the game, minus when a tank spawns (1 allows bots from tank spawns, 2 removes all infected bots)");
    BK_cvEnable.AddChangeHook(BK_ConVarChange);

    BK_bEnable = BK_cvEnable.BoolValue;
}

public void BK_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    BK_bEnable = BK_cvEnable.BoolValue;
}

public void BK_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsTankInPlay()) return;
    int client = GetClientOfUserId(event.GetInt("player"));
    if (client && IsClientInGame(client) && GetClientTeam(client) == 3)
    {
        BK_lastvalidbot = GetClientOfUserId(event.GetInt("bot"));
        CreateTimer(BOTREPLACEVALIDTIME, BK_CancelValidBot_Timer);
    }
}

public Action BK_CancelValidBot_Timer(Handle timer)
{
    BK_lastvalidbot = -1;
}

public Action BK_CheckInfBotReplace_Timer(Handle timer, any data)
{
    int client = data;
    if (client != BK_lastvalidbot && IsClientInGame(client) && IsFakeClient(client))
    {
        KickClient(client,"[Confogl] Kicking late infected bot...");
    }
    else
    {
        BK_lastvalidbot = -1;
    }

    return Plugin_Handled;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
    if (!IsFakeClient(client) || !BK_bEnable || !IsPluginEnabled()) // If the BK_bEnable is false, we don't do anything
    {
        return true;
    }

    char name[11];
    GetClientName(client, name, sizeof(name));

    if (StrContains(name, "smoker", false) == -1 && // If the client doesn't have a bot infected's name, let it in
        StrContains(name, "boomer", false) == -1 &&
        StrContains(name, "hunter", false) == -1 &&
        StrContains(name, "spitter", false) == -1 &&
        StrContains(name, "jockey", false) == -1 &&
        StrContains(name, "charger", false) == -1)
    {
        return true;
    }

    if (BK_bEnable && IsTankInPlay()) // Bots only allowed to try to connect when there's a tank in play.
    {
        // Check this bot in CHECKALLOWEDTIME seconds to see if he's supposed to be allowed.
        CreateTimer(CHECKALLOWEDTIME, BK_CheckInfBotReplace_Timer, client);
        return true;
    }

    KickClient(client, "[Confogl] Kicking infected bot..."); // If all else fails, bots arent allowed and must be kicked

    return false;
}
