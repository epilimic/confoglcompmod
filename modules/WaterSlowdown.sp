#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar          WS_cvEnable;
ConVar          WS_cvFactor;

bool            WS_bEnabled = true;
bool            WS_bPlayerInWater[MAXPLAYERS + 1];
bool            WS_bJockeyInWater = false;

void WS_OnModuleStart()
{
    WS_cvEnable = CreateConVarEx("waterslowdown",   "1",    "Enables additional water slowdown");
    WS_cvFactor = CreateConVarEx("slowdown_factor", "0.90", "Sets how much water will slow down survivors. 1.00 = Vanilla");
    WS_cvEnable.AddChangeHook(WS_ConVarChange);

    HookEvent("round_start",     WS_RoundStart);
    HookEvent("jockey_ride",     WS_JockeyRide);
    HookEvent("jockey_ride_end", WS_JockeyRideEnd);
}

void WS_OnModuleEnd()
{
    WS_SetStatus(false);
}

void WS_OnGameFrame()
{
    if (!IsServerProcessing() || !IsPluginEnabled() || !WS_bEnabled) return;
    int client;
    int flags;

    for (int i = 0; i < NUM_OF_SURVIVORS; i++)
    {
        client = GetSurvivorIndex(i);
        if (client != 0 && IsValidEntity(client))
        {
            flags = GetEntityFlags(client);

            if (!(flags & IN_JUMP && WS_bPlayerInWater[client]))
            {
                if (flags & FL_INWATER)
                {
                    if (!WS_bPlayerInWater[client])
                    {
                        WS_bPlayerInWater[client] = true;
                        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", GetConVarFloat(WS_cvFactor));
                    }
                }
                else
                {
                    if (WS_bPlayerInWater[client])
                    {
                        WS_bPlayerInWater[client] = false;
                        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
                    }
                }
            }
        }
    }
}

public void WS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    WS_SetStatus();
}

public Action WS_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    WS_SetStatus();
}

void WS_OnMapEnd()
{
    WS_SetStatus(false);
}

public Action WS_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int jockey = GetClientOfUserId(event.GetInt("userid"));

    if (WS_bPlayerInWater[victim] && !WS_bJockeyInWater)
    {
        WS_bJockeyInWater = true;
        SetEntPropFloat(jockey, Prop_Send, "m_flLaggedMovementValue", GetConVarFloat(WS_cvFactor));
    }
    else if (!WS_bPlayerInWater[victim] && WS_bJockeyInWater)
    {
        WS_bJockeyInWater = false;
        SetEntPropFloat(jockey, Prop_Send, "m_flLaggedMovementValue", 1.0);
    }
}

public Action WS_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
    int jockey = GetClientOfUserId(event.GetInt("userid"));

    WS_bJockeyInWater = false;
    if (jockey && IsValidEntity(jockey))
    {
        SetEntPropFloat(jockey, Prop_Send, "m_flLaggedMovementValue", 1.0);
    }
}

void WS_SetStatus(bool enable = true)
{
    if (!enable)
    {
        WS_bEnabled = false;
        return;
    }
    WS_bEnabled = WS_cvEnable.BoolValue;
}
