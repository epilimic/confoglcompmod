#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
    if (GT_OnTankSpawn_Forward() == Plugin_Handled) return Plugin_Handled;
    BS_OnTankSpawn_Forward();

    return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &amount)
{
    if (GT_OnSpawnMob_Forward(amount) == Plugin_Handled) return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
    if (GT_OnTryOfferingTankBot(enterStasis) == Plugin_Handled) return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D_OnGetMissionVSBossSpawning(float &spawn_pos_min, float &spawn_pos_max, float &tank_chance, float &witch_chance)
{
    if (UB_OnGetMissionVSBossSpawning() == Plugin_Handled) return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
    if (UB_OnGetScriptValueInt(key, retVal) == Plugin_Handled) return Plugin_Handled;

    return Plugin_Continue;
}

public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
    // Workaround to make tank horde blocking always work
    // Makes the first horde always start 100s after survivors leave saferoom
    static ConVar MobSpawnTimeMin;
    static ConVar MobSpawnTimeMax;

    if (MobSpawnTimeMin == INVALID_HANDLE)
    {
        MobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
        MobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
    }
    L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(GetConVarFloat(MobSpawnTimeMin), GetConVarFloat(MobSpawnTimeMax)));
}
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    if (IsPluginEnabled()) CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);

    return Plugin_Continue;
}
