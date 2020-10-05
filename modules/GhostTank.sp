#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define         ZOMBIECLASS_TANK                        8

const   float   THROWRANGE                              = 99999999.0;
const   float   FIREIMMUNITY_TIME                       = 5.0;
const           INCAPHEALTH                             = 300;
const   float   SPECHUD_UPDATEINTERVAL                  = 0.5;

int             passes;
int             g_iGT_TankClient;
bool            g_bGT_TankIsInPlay;
bool            g_bGT_TankHasFireImmunity;
bool            g_bGT_FinaleVehicleIncoming;

ConVar          g_cvGT_Enabled;
ConVar          g_cvGT_RemoveEscapeTank;
ConVar          g_cvGT_BlockPunchRock;
Handle          g_hGT_TankDeathTimer = INVALID_HANDLE;

// Disable Tank Hordes items
static  ConVar  g_cvGT_DisableTankHordes;
static  bool    g_bGT_HordesDisabled;

void GT_OnModuleStart()
{
    g_cvGT_Enabled           = CreateConVarEx("boss_tank",           "1", "Tank can't be prelight, frozen and ghost until player takes over, punch fix, and no rock throw for AI tank while waiting for player");
    g_cvGT_RemoveEscapeTank  = CreateConVarEx("remove_escape_tank",  "1", "Remove tanks that spawn as the rescue vehicle is incoming on finales.");
    g_cvGT_DisableTankHordes = CreateConVarEx("disable_tank_hordes", "0", "Disable natural hordes while tanks are in play");
    g_cvGT_BlockPunchRock    = CreateConVarEx("block_punch_rock",    "0", "Block tanks from punching and throwing a rock at the same time");

    HookEvent("tank_spawn",              GT_TankSpawn);
    HookEvent("player_death",            GT_TankKilled);
    HookEvent("player_hurt",             GT_TankOnFire);
    HookEvent("round_start",             GT_RoundStart);
    HookEvent("item_pickup",             GT_ItemPickup);
    HookEvent("player_incapacitated",    GT_PlayerIncap);
    HookEvent("finale_vehicle_incoming", GT_FinaleVehicleIncoming);
}

// For other modules to use
public bool IsTankInPlay()
{
    return g_bGT_TankIsInPlay;
}

Action GT_OnTankSpawn_Forward()
{
    if (IsPluginEnabled() && GetConVarBool(g_cvGT_RemoveEscapeTank) && g_bGT_FinaleVehicleIncoming)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D_OnCThrowActivate()
{
    if (IsPluginEnabled() && IsTankInPlay() && GetConVarBool(g_cvGT_BlockPunchRock) && GetClientButtons(g_iGT_TankClient) & IN_ATTACK)
    {
        Debug_LogMessage("[GT] Blocking Haymaker on %L", g_iGT_TankClient);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

Action GT_OnSpawnMob_Forward(int &amount)
{
    // quick fix. needs normalize_hordes 1
    if (IsPluginEnabled())
    {
        Debug_LogMessage("[GT] SpawnMob(%d), HordesDisabled: %d TimerDuration: %f Minimum: %f Remaining: %f",
        amount, g_bGT_HordesDisabled, L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer),
        FindConVar("z_mob_spawn_min_interval_normal").FloatValue, L4D2_CTimerGetRemainingTime(L4D2CT_MobSpawnTimer));

        if (g_bGT_HordesDisabled)
        {
            static ConVar mob_spawn_interval_min;
            static ConVar mob_spawn_interval_max;
            static ConVar mob_spawn_size_min;
            static ConVar mob_spawn_size_max;
            if (mob_spawn_interval_min == INVALID_HANDLE)
            {
                mob_spawn_interval_min = FindConVar("z_mob_spawn_min_interval_normal");
                mob_spawn_interval_max = FindConVar("z_mob_spawn_max_interval_normal");
                mob_spawn_size_min = FindConVar("z_mob_spawn_min_size");
                mob_spawn_size_max = FindConVar("z_mob_spawn_max_size");
            }

            int minsize = mob_spawn_size_min.IntValue;
            int maxsize = mob_spawn_size_max.IntValue;
            if (amount < minsize || amount > maxsize)        return Plugin_Continue;
            if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer)) return Plugin_Continue;

            float duration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
            if (duration < mob_spawn_interval_min.FloatValue || duration > mob_spawn_interval_max.FloatValue) return Plugin_Continue;

            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

// Disable stasis when we're using GhostTank
Action GT_OnTryOfferingTankBot(bool &enterStasis)
{
    passes++;
    if (IsPluginEnabled())
    {
        if (GetConVarBool(g_cvGT_Enabled)) enterStasis = false;
        if (GetConVarBool(g_cvGT_RemoveEscapeTank) && g_bGT_FinaleVehicleIncoming) return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void GT_FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
    g_bGT_FinaleVehicleIncoming = true;
    if (g_bGT_TankIsInPlay && IsFakeClient(g_iGT_TankClient))
    {
        KickClient(g_iGT_TankClient);
        GT_Reset();
    }
}

public void GT_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bGT_TankIsInPlay) return;

    char item[64];
    event.GetString("item", item, sizeof(item));

    if (StrEqual(item, "tank_claw")) 
    {
        g_iGT_TankClient = GetClientOfUserId(event.GetInt("userid"));
        if (g_hGT_TankDeathTimer != INVALID_HANDLE)
        {
            KillTimer(g_hGT_TankDeathTimer);
            g_hGT_TankDeathTimer = INVALID_HANDLE;
        }
    }
}

static void DisableNaturalHordes()
{
    // 0x7fff = 16 bit signed max value. Over 9 hours.
    g_bGT_HordesDisabled = true;
}

static void EnableNaturalHordes()
{
    g_bGT_HordesDisabled = false;
}

public void GT_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bGT_FinaleVehicleIncoming = false;
    GT_Reset();
}

public void GT_TankKilled(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bGT_TankIsInPlay) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client != g_iGT_TankClient) return;
    g_hGT_TankDeathTimer = CreateTimer(1.0, GT_TankKilled_Timer);
}

public void GT_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_iGT_TankClient = client;

    if (g_bGT_TankIsInPlay) return;

    g_bGT_TankIsInPlay = true;

    if (g_cvGT_DisableTankHordes.BoolValue)
    {
        DisableNaturalHordes();
    }

    if (!IsPluginEnabled() || !g_cvGT_Enabled.BoolValue) return;
    
    
    // Spec HUD
    float fFireImmunityTime = FIREIMMUNITY_TIME;
    float fSelectionTime = FindConVar("director_tank_lottery_selection_time").FloatValue;

    if (IsFakeClient(client))
    {
        GT_PauseTank();
        CreateTimer(fSelectionTime, GT_ResumeTankTimer);
        fFireImmunityTime += fSelectionTime;
    }

    CreateTimer(fFireImmunityTime, GT_FireImmunityTimer);
}

public void GT_TankOnFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bGT_TankIsInPlay || !g_bGT_TankHasFireImmunity || !IsPluginEnabled() || !g_cvGT_Enabled.BoolValue) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (g_iGT_TankClient != client || !IsValidClient(client)) return;
    
    int dmgtype = event.GetInt("type");
    
    if (dmgtype != 8) return;
    
    ExtinguishEntity(client);
    int CurHealth = GetClientHealth(client);
    int DmgDone   = event.GetInt("dmg_health");
    SetEntityHealth(client, (CurHealth + DmgDone));
}

public void GT_PlayerIncap(Event event, const char[] event_name, bool dontBroadcast)
{
    if (!g_bGT_TankIsInPlay || !IsPluginEnabled() || !g_cvGT_Enabled.BoolValue) return;
    
    char weapon[16];
    event.GetString("weapon", weapon, 16);
    
    if (!StrEqual(weapon, "tank_claw")) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client)) return;
    
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
    SetEntityHealth(client, 1);
    CreateTimer(0.4, GT_IncapTimer, client);
}

public Action GT_IncapTimer(Handle timer, any client)
{
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
    SetEntityHealth(client, INCAPHEALTH);
}

public Action GT_ResumeTankTimer(Handle timer)
{
    GT_ResumeTank();
}

public Action GT_FireImmunityTimer(Handle timer)
{
    g_bGT_TankHasFireImmunity = false;
}

void GT_PauseTank()
{
    FindConVar("tank_throw_allow_range").FloatValue = THROWRANGE;
    if (!IsValidEntity(g_iGT_TankClient)) return;
    SetEntityMoveType(g_iGT_TankClient, MOVETYPE_NONE);
    SetEntProp(g_iGT_TankClient, Prop_Send, "m_isGhost", 1, 1);
}

void GT_ResumeTank()
{
    FindConVar("tank_throw_allow_range").RestoreDefault();
    if (!IsValidEntity(g_iGT_TankClient)) return;
    SetEntityMoveType(g_iGT_TankClient, MOVETYPE_CUSTOM);
    SetEntProp(g_iGT_TankClient, Prop_Send, "m_isGhost", 0, 1);
}

int GT_Reset()
{
    passes = 0;
    g_hGT_TankDeathTimer = INVALID_HANDLE;
    if (g_bGT_HordesDisabled) EnableNaturalHordes();
    g_bGT_TankIsInPlay = false;
    g_bGT_TankHasFireImmunity = true;
}

public Action GT_TankKilled_Timer(Handle timer)
{
    GT_Reset();
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}
