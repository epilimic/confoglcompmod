#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define         RM_DEBUG                0

#define         RM_DEBUG_PREFIX         "[ReqMatch]"

const   float  MAPRESTARTTIME           = 3.0;
const   float  RESETMINTIME             = 60.0;

bool           RM_bMatchRequest[2];
bool           RM_bIsMatchModeLoaded;
bool           RM_bIsAMatchActive;
bool           RM_bIsPluginsLoaded;
bool           RM_bIsMapRestarted;
ConVar         RM_cvDoRestart;
ConVar         RM_cvAllowVoting;
ConVar         RM_cvReloaded;
ConVar         RM_cvAutoLoad;
ConVar         RM_cvAutoCfg;
GlobalForward  RM_gFwdMatchLoad;
GlobalForward  RM_gFwdMatchUnload;
ConVar         RM_cvConfigFile_On;
ConVar         RM_cvConfigFile_Plugins;
ConVar         RM_cvConfigFile_Off;

void RM_OnModuleStart()
{
    RM_cvDoRestart           = CreateConVarEx("match_restart",         "1",                    "Sets whether the plugin will restart the map upon match mode being forced or requested");
    RM_cvAllowVoting         = CreateConVarEx("match_allowvoting",     "1",                    "Sets whether players can vote/request for match mode");
    RM_cvAutoLoad            = CreateConVarEx("match_autoload",        "0",                    "Has match mode start up automatically when a player connects and the server is not in match mode");
    RM_cvAutoCfg             = CreateConVarEx("match_autoconfig",      "",                     "Specify which config to load if the autoloader is enabled");
    RM_cvConfigFile_On       = CreateConVarEx("match_execcfg_on",      "confogl.cfg",          "Execute this config file upon match mode starts and every map after that.");
    RM_cvConfigFile_Plugins  = CreateConVarEx("match_execcfg_plugins", "confogl_plugins.cfg",  "Execute this config file upon match mode starts. This will only get executed once and meant for plugins that needs to be loaded.");
    RM_cvConfigFile_Off      = CreateConVarEx("match_execcfg_off",     "confogl_off.cfg",      "Execute this config file upon match mode ends.");


    RegAdminCmd("sm_forcematch",    RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
    RegAdminCmd("sm_fm",            RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
    RegAdminCmd("sm_resetmatch",    RM_Cmd_ResetMatch, ADMFLAG_CONFIG, "Forces match mode to turn off REGRADLESS for always on or forced match");

    RM_cvReloaded = FindConVarEx("match_reloaded");
    if (RM_cvReloaded == INVALID_HANDLE)
    {
        RM_cvReloaded = CreateConVarEx("match_reloaded", "0", "DONT TOUCH THIS CVAR! This is to prevent match feature keep looping, however the plugin takes care of it. Don't change it!", FCVAR_DONTRECORD | FCVAR_UNLOGGED);
    }

    bool bIsReloaded = RM_cvReloaded.BoolValue;
    if (bIsReloaded)
    {
        if (RM_DEBUG || IsDebugEnabled()) LogMessage("%s Plugin was reloaded from match mode, executing match load", RM_DEBUG_PREFIX);
        RM_bIsPluginsLoaded = true;
        RM_cvReloaded.IntValue = 0;
        RM_Match_Load();
    }
}

void RM_APL()
{
    RM_gFwdMatchLoad   = new GlobalForward("LGO_OnMatchModeLoaded",   ET_Event);
    RM_gFwdMatchUnload = new GlobalForward("LGO_OnMatchModeUnloaded", ET_Event);
    CreateNative("LGO_IsMatchModeLoaded", native_IsMatchModeLoaded);
}

public int native_IsMatchModeLoaded(Handle plugin, int numParams)
{
    return RM_bIsMatchModeLoaded;
}

void RM_OnMapStart()
{
    if (!RM_bIsMatchModeLoaded) return;

    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s New map, executing match config...", RM_DEBUG_PREFIX);

    RM_Match_Load();
}

void RM_OnClientPutInServer()
{
    if (!GetConVarBool(RM_cvAutoLoad) || RM_bIsAMatchActive) return;

    char buffer[128];
    RM_cvAutoCfg.GetString(buffer, sizeof(buffer));

    RM_UpdateCfgOn(buffer);
    RM_Match_Load();
}

void RM_Match_Load()
{
    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Match Load", RM_DEBUG_PREFIX);

    if (!RM_bIsAMatchActive)
    {
        RM_bIsAMatchActive = true;
    }

    FindConVar("sb_all_bot_game").IntValue = 1;
    // FIXME quick an dirty fix for OnPluginEnd() not being called because of Left4Dhooks unload
    ServerCommand("confogl_resetclientcvars");
    ServerCommand("confogl_resetcvars");

    char sBuffer[128];

    if (!RM_bIsPluginsLoaded)
    {
        if (RM_DEBUG || IsDebugEnabled())
            LogMessage("%s Loading plugins and reload self",RM_DEBUG_PREFIX);

        RM_cvReloaded.IntValue = 1;
        RM_cvConfigFile_Plugins.GetString(sBuffer, sizeof(sBuffer));
        ExecuteCfg(sBuffer);
        return;
    }

    RM_cvConfigFile_On.GetString(sBuffer, sizeof(sBuffer));
    ExecuteCfg(sBuffer);
    if (RM_DEBUG || IsDebugEnabled()) LogMessage("%s Match config executed", RM_DEBUG_PREFIX);

    if (RM_bIsMatchModeLoaded) return;

    if (RM_DEBUG || IsDebugEnabled()) LogMessage("%s Setting match mode active", RM_DEBUG_PREFIX);

    RM_bIsMatchModeLoaded = true;
    IsPluginEnabled(true, true);

    PrintToChatAll("\x01[\x05Confogl\x01] Match mode loaded!");

    if (!RM_bIsMapRestarted && GetConVarBool(RM_cvDoRestart))
    {
        PrintToChatAll("\x01[\x05Confogl\x01] Restarting map!");
        CreateTimer(MAPRESTARTTIME,RM_Match_MapRestart_Timer);
    }

    if (RM_DEBUG || IsDebugEnabled()) LogMessage("%s Match mode loaded!", RM_DEBUG_PREFIX);

    Call_StartForward(RM_gFwdMatchLoad);
    Call_Finish();
}

void RM_Match_Unload(bool bForced = false)
{
    if (!IsHumansOnServer() || bForced)
    {
        if (RM_DEBUG || IsDebugEnabled())
            LogMessage("%s Match ?s no longer active, sb_all_bot_game reset to 0, IsHumansOnServer %b, bForced %b", RM_DEBUG_PREFIX, IsHumansOnServer(), bForced);

        RM_bIsAMatchActive = false;
        FindConVar("sb_all_bot_game").IntValue = 0;
    }

    if (IsHumansOnServer() && !bForced) return;

    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Unloading match mode...", RM_DEBUG_PREFIX);

    char sBuffer[128];
    RM_bIsMatchModeLoaded = false;
    IsPluginEnabled(true,false);
    RM_bIsMapRestarted = false;
    RM_bIsPluginsLoaded = false;

    Call_StartForward(RM_gFwdMatchUnload);
    Call_Finish();

    PrintToChatAll("\x01[\x05Confogl\x01] Match mode unloaded!");

    RM_cvConfigFile_Off.GetString(sBuffer, sizeof(sBuffer));
    ExecuteCfg(sBuffer);

    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Match mode unloaded!", RM_DEBUG_PREFIX);

}

public Action RM_Match_MapRestart_Timer(Handle timer)
{
    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Restarting map...", RM_DEBUG_PREFIX);

    char sBuffer[128];
    GetCurrentMap(sBuffer, sizeof(sBuffer));
    ServerCommand("changelevel %s", sBuffer);
    RM_bIsMapRestarted = true;
}

void RM_UpdateCfgOn(const char[] cfgfile)
{
    if (SetCustomCfg(cfgfile))
    {
        PrintToChatAll("\x01[\x05Confogl\x01] Using \"\x04%s\x01\" config.", cfgfile);
        if (RM_DEBUG || IsDebugEnabled())
        {
            LogMessage("%s Starting match on config %s", RM_DEBUG_PREFIX, cfgfile);
        }
    }
    else
    {
        PrintToChatAll("\x01[\x05Confogl\x01] Config \"\x04%s\x01\" not found, using default config!", cfgfile);
    }

}

public Action RM_Cmd_ForceMatch(int client, int args)
{
    if (RM_bIsMatchModeLoaded)
    {
        if (RM_DEBUG || IsDebugEnabled())
            LogMessage("%s Unloading match mode...", RM_DEBUG_PREFIX);

        Call_StartForward(RM_gFwdMatchUnload);
        Call_Finish();

        if (RM_DEBUG || IsDebugEnabled())
            LogMessage("%s Match mode unloaded!", RM_DEBUG_PREFIX);
        RM_bIsMatchModeLoaded = false;
        IsPluginEnabled(true, false);
        RM_bIsMapRestarted = false;
        RM_bIsPluginsLoaded = false;
        RM_bIsAMatchActive = false;
    }

    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Match mode forced to load!", RM_DEBUG_PREFIX);

    if (args > 0) // cfgfile specified
    {
        static char sBuffer[128];
        GetCmdArg(1, sBuffer, sizeof(sBuffer));
        RM_UpdateCfgOn(sBuffer);
    }
    else
    {
        SetCustomCfg("");
    }

    RM_Match_Load();

    return Plugin_Handled;
}

public Action RM_Cmd_ResetMatch(int client, int args)
{
    if (!RM_bIsMatchModeLoaded) return Plugin_Handled;

    if (RM_DEBUG || IsDebugEnabled())
        LogMessage("%s Match mode forced to unload!",RM_DEBUG_PREFIX);

    RM_Match_Unload(true);

    return Plugin_Handled;
}

public Action RM_Cmd_Match(int client, int args)
{
    if (RM_bIsMatchModeLoaded || (!IsVersus() && !IsScavenge()) || !GetConVarBool(RM_cvAllowVoting)) return Plugin_Handled;

    int iTeam = GetClientTeam(client);
    if ((iTeam == TEAM_SURVIVOR || iTeam == TEAM_INFECTED) && !RM_bMatchRequest[iTeam - 2])
    {
        RM_bMatchRequest[iTeam - 2] = true;
    }
    else
    {
        return Plugin_Handled;
    }

    if (RM_bMatchRequest[0] && RM_bMatchRequest[1])
    {
        PrintToChatAll("\x01[\x05Confogl\x01] Both teams have agreed to start a competitive match!");
        RM_Match_Load();
    }
    else if (RM_bMatchRequest[0] || RM_bMatchRequest[1])
    {
        PrintToChatAll("\x01[\x05Confogl\x01] The \x04%s \x01have requested to start a competitive match. The \x04%s \x01must accept with \x04/match \x01command!",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
        if (args > 0) // cfgfile specified
        {
            static char sBuffer[128];
            GetCmdArg(1, sBuffer, sizeof(sBuffer));
            RM_UpdateCfgOn(sBuffer);
        }
        else
        {
            SetCustomCfg("");
        }
        CreateTimer(30.0, RM_MatchRequestTimeout);
    }

    return Plugin_Handled;
}

public Action RM_MatchRequestTimeout(Handle timer)
{
    RM_ResetMatchRequest();
}

public Action RM_MatchResetTimer(Handle timer)
{
    RM_Match_Unload();
}

void RM_OnClientDisconnect(int client)
{
    if (IsFakeClient(client) || !RM_bIsMatchModeLoaded) return;
    CreateTimer(RESETMINTIME, RM_MatchResetTimer);
}

void RM_ResetMatchRequest()
{
    RM_cvConfigFile_On.RestoreDefault();
    RM_bMatchRequest[0] = false;
    RM_bMatchRequest[1] = false;
}
