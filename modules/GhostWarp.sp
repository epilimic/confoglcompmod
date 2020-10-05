#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar          GW_cvGhostWarp;
ConVar          GW_cvGhostWarpReload;
bool            GW_bEnabled = true;
bool            GW_bReload = false;
bool            GW_bDelay[MAXPLAYERS+1];
int             GW_iLastTarget[MAXPLAYERS+1] = -1;

void GW_OnModuleStart()
{
    // GhostWarp
    GW_cvGhostWarp       = CreateConVarEx("ghost_warp",        "1", "Sets whether infected ghosts can right click for warp to next survivor");
    GW_cvGhostWarpReload = CreateConVarEx("ghost_warp_reload", "0", "Sets whether to use mouse2 or reload for ghost warp.");

    // Ghost Warp
    HookEvent("player_death", GW_PlayerDeath_Event);
    GW_cvGhostWarp.AddChangeHook(GW_ConVarChange);
    RegConsoleCmd("sm_warptosurvivor", GW_Cmd_WarpToSurvivor);

    GW_bEnabled = GW_cvGhostWarp.BoolValue;
    GW_bReload = GW_cvGhostWarpReload.BoolValue;
}

bool GW_OnPlayerRunCmd(int client, int buttons)
{
    if (!IsPluginEnabled() || !GW_bEnabled || GW_bDelay[client] || ! IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED || GetEntProp(client, Prop_Send, "m_isGhost", 1) != 1) return false;
    if (GW_bReload && !(buttons & IN_RELOAD))   return false;
    if (!GW_bReload && !(buttons & IN_ATTACK2)) return false;

    GW_bDelay[client] = true;
    CreateTimer(0.25, GW_ResetDelay, client);

    GW_WarpToSurvivor(client, 0);

    return true;
}

public void GW_PlayerDeath_Event(Event event, const char[] name, bool dB)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    GW_iLastTarget[client] = -1;
}

public void GW_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GW_bEnabled = GW_cvGhostWarp.BoolValue;
}

public Action GW_ResetDelay(Handle timer, any client)
{
    GW_bDelay[client] = false;
}

public Action GW_Cmd_WarpToSurvivor(int client, int args)
{
    if (!IsPluginEnabled() || !GW_bEnabled || args != 1 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED || GetEntProp(client,Prop_Send,"m_isGhost",1) != 1) return Plugin_Handled;

    char buffer[2];
    GetCmdArg(1, buffer, 2);
    if (strlen(buffer) == 0) return Plugin_Handled;
    int character = (StringToInt(buffer));

    GW_WarpToSurvivor(client, character);

    return Plugin_Handled;
}
 
void GW_WarpToSurvivor(int client, int character)
{
    int target;

    if (character <= 0)
    {
        target = GW_FindNextSurvivor(client,GW_iLastTarget[client]);
    }
    else if (character <= 4)
    {
        target = GetSurvivorIndex(character - 1);
    }
    else
    {
        return;
    }

    if (target == 0) return;

    // Prevent people from spawning and then warp to survivor
    SetEntProp(client, Prop_Send, "m_ghostSpawnState", 256);

    float position[3];
    float anglestarget[3];

    GetClientAbsOrigin(target, position);
    GetClientAbsAngles(target, anglestarget);
    TeleportEntity(client, position, anglestarget, NULL_VECTOR);

    return;
}
 
int GW_FindNextSurvivor(int client, int character)
{
    if (!IsAnySurvivorsAlive())
    {
        return 0;
    }

    int havelooped = false;
    character++;
    if (character >= NUM_OF_SURVIVORS) character = 0;

    for (int index = character; index < MaxClients; index++)
    {
        if (index >= NUM_OF_SURVIVORS)
        {
            if (havelooped) break;
            havelooped = true;
            index = 0;
        }
       
        if (GetSurvivorIndex(index) == 0) continue;
       
        GW_iLastTarget[client] = index;
        return GetSurvivorIndex(index);
    }

    return 0;
}
