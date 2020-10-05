#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar          UB_cvEnable;
bool            UB_bEnabled = true;

void UB_OnModuleStart()
{
    UB_cvEnable = CreateConVarEx("boss_unprohibit", "1", "Enable bosses spawning on all maps, even through they normally aren't allowed");
    UB_cvEnable.AddChangeHook(UB_ConVarChange);
    UB_bEnabled = UB_cvEnable.BoolValue;
}

public void UB_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UB_bEnabled = UB_cvEnable.BoolValue;
}

Action UB_OnGetScriptValueInt(const char[] key, int &retVal)
{
    if (IsPluginEnabled() && UB_bEnabled)
    {
        if (StrEqual(key, "DisallowThreatType"))
        {
            retVal = 0;
            return Plugin_Handled;
        }

        if (StrEqual(key, "ProhibitBosses"))
        {
            retVal = 0;
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action UB_OnGetMissionVSBossSpawning()
{
    if (UB_bEnabled)
    {
        char mapbuf[32];
        GetCurrentMap(mapbuf, sizeof(mapbuf));
        if (StrEqual(mapbuf, "c7m1_docks") || StrEqual(mapbuf, "c13m2_southpinestream")) return Plugin_Continue;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
