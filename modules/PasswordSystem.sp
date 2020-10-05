#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar          PS_cvPassword;
ConVar          PS_cvReloaded;
bool            PS_bIsPassworded;
bool            PS_bSuppress;
char            PS_sPassword[128];

void PS_OnModuleStart()
{
    PS_cvPassword = CreateConVarEx("password", "", "Set a password on the server, if empty password disabled. See Confogl's wiki for more information", FCVAR_DONTRECORD | FCVAR_PROTECTED);
    PS_cvPassword.AddChangeHook(PS_ConVarChange);

    HookEvent("player_disconnect", PS_SuppressDisconnectMsg, EventHookMode_Pre);

    PS_cvReloaded = FindConVarEx("password_reloaded");
    if (PS_cvReloaded == INVALID_HANDLE)
    {
        PS_cvReloaded = CreateConVarEx("password_reloaded", "", "DONT TOUCH THIS CVAR! This will is to make sure that the password gets set upon the plugin is reloaded", FCVAR_DONTRECORD | FCVAR_UNLOGGED);
    }
    else
    {
        char sBuffer[128];
        PS_cvReloaded.GetString(sBuffer, sizeof(sBuffer));

        PS_cvPassword.SetString(sBuffer);
        PS_cvReloaded.SetString("");

        PS_cvPassword.GetString(PS_sPassword, sizeof(PS_sPassword));
        PS_bIsPassworded = true;
        PS_SetPasswordOnClients();
    }
}

void PS_OnModuleEnd()
{
    if (!PS_bIsPassworded) return;
    PS_cvReloaded.SetString(PS_sPassword);
}

void PS_CheckPassword(int client)
{
    if (!PS_bIsPassworded || !IsPluginEnabled()) return;
    CreateTimer(0.1, PS_CheckPassword_Timer, client, TIMER_REPEAT);
}

public Action PS_CheckPassword_Timer(Handle timer, any client)
{
    if (!IsClientConnected(client) || IsFakeClient(client)) return Plugin_Stop;
    if (!IsClientInGame(client)) return Plugin_Continue;
    QueryClientConVar(client, "sv_password", PS_ConVarDone);

    return Plugin_Stop;
}

public void PS_ConVarDone(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
    if (result == ConVarQuery_Okay)
    {
        char buffer[128];
        PS_cvPassword.GetString(buffer, sizeof(buffer));

        if (StrEqual(buffer, cvarValue))
        {
            return;
        }
    }

    PS_bSuppress = true;
    KickClient(client, "Bad password");
}

public void PS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    PS_cvPassword.GetString(PS_sPassword, sizeof(PS_sPassword));
    if (strlen(PS_sPassword) > 0)
    {
        PS_bIsPassworded = true;
        PS_SetPasswordOnClients();
    }
    else
    {
        PS_bIsPassworded = false;
    }
}

public Action PS_SuppressDisconnectMsg(Event event, const char[] name, bool dontBroadcast)
{
    if (dontBroadcast || !PS_bSuppress) return Plugin_Continue;

    char clientName[33];
    char networkID[22];
    char reason[65];
    event.GetString("name", clientName, sizeof(clientName));
    event.GetString("networkid", networkID, sizeof(networkID));
    event.GetString("reason", reason, sizeof(reason));

    Event newEvent = CreateEvent("player_disconnect", true);
    newEvent.SetInt("userid", event.GetInt("userid"));
    newEvent.SetString("reason", reason);
    newEvent.SetString("name", clientName);
    newEvent.SetString("networkid", networkID);
    newEvent.Fire(true);

    PS_bSuppress = false;
    return Plugin_Handled;
}

void PS_OnMapEnd()
{
    PS_SetPasswordOnClients();
}

void PS_OnClientPutInServer(int client)
{
    PS_CheckPassword(client);
}

void PS_SetPasswordOnClients()
{
    char pwbuffer[128];
    PS_cvPassword.GetString(pwbuffer, sizeof(pwbuffer));

    for (int client = 1; client < MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;
        Debug_LogMessage("Set password on %N, password %s", client, pwbuffer);
        ClientCommand(client, "sv_password \"%s\"", pwbuffer);
    }
}
