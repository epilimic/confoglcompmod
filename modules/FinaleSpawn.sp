#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define STATE_SPAWNREADY            0
#define STATE_TOOCLOSE              256
#define SPAWN_RANGE                 150

ConVar              FS_hEnabled;
bool                FS_bIsFinale;
bool                FS_bEnabled     = true;

void FS_OnModuleStart()
{
    FS_hEnabled = CreateConVarEx("reduce_finalespawnrange", "1", "Adjust the spawn range on finales for infected, to normal spawning range");
    FS_bEnabled = FS_hEnabled.BoolValue;
    FS_hEnabled.AddChangeHook(FS_ConVarChange);

    HookEvent("round_end",    FS_Round_Event,       EventHookMode_PostNoCopy);
    HookEvent("round_start",  FS_Round_Event,       EventHookMode_PostNoCopy);
    HookEvent("finale_start", FS_FinaleStart_Event, EventHookMode_PostNoCopy);
}

public Action FS_Round_Event(Event event, const char[] name, bool dontBroadcast)
{
    FS_bIsFinale = false;
}

public Action FS_FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    FS_bIsFinale = true;
}

public void FS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    FS_bEnabled = FS_hEnabled.BoolValue;
}

public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_PreThinkPost, HookCallback);
}

public void HookCallback(int client)
{
    if (!FS_bEnabled || !IsPluginEnabled) return;
    if (!FS_bIsFinale) return;
    if (GetClientTeam(client) != TEAM_INFECTED) return;
    if (GetEntProp(client,Prop_Send,"m_isGhost",1) != 1) return;

    if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") == STATE_TOOCLOSE)
    {
        if (!TooClose(client)) SetEntProp(client, Prop_Send, "m_ghostSpawnState", STATE_SPAWNREADY);
    }
}

bool TooClose(int client)
{
    float fInfLocation[3];
    float fSurvLocation[3];
    float fVector[3];
    GetClientAbsOrigin(client, fInfLocation);

    for (int i = 0; i < 4; i++)
    {
        int index = GetSurvivorIndex(i);
        if (index == 0) continue;
        if (!IsPlayerAlive(index)) continue;
        GetClientAbsOrigin(index, fSurvLocation);

        MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);

        if (GetVectorLength(fVector) <= SPAWN_RANGE) return true;
    }
    return false;
}
