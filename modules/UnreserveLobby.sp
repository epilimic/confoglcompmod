#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar UL_cvEnable;

void UL_OnModuleStart()
{
    UL_cvEnable  = CreateConVarEx("match_killlobbyres", "1", "Sets whether the plugin will clear lobby reservation once a match have begun");
    RegAdminCmd("sm_killlobbyres", UL_KillLobbyRes, ADMFLAG_BAN, "Forces the plugin to kill lobby reservation");
}

bool UL_CheckVersion()
{
    return FindConVar("left4dhooks_version") == INVALID_HANDLE;
}

void UL_OnClientPutInServer()
{
    if (!IsPluginEnabled() || !UL_cvEnable.BoolValue) return;

    if (UL_CheckVersion())
    {
        LogError("Failed to unreserve lobby. Left4Dhooks is outdated!");
        return;
    }

    L4D_LobbyUnreserve();
}

public Action UL_KillLobbyRes(int client, int args)
{
    if (UL_CheckVersion())
    {
        LogError("Failed to unreserve lobby. Left4Dhooks is outdated!");
        return;
    }

    L4D_LobbyUnreserve();
}
