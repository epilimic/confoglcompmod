#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define DEBUG_SM                    0

int             SM_iFirstScore;
int             SM_iDefaultSurvivalBonus;
int             SM_iDefaultTieBreaker;
int             SM_iPillPercent;
int             SM_iAdrenPercent;

float           SM_fHealPercent;
float           SM_fMapMulti;
float           SM_fHBRatio;
float           SM_fSurvivalBonusRatio;
float           SM_fTempMulti[3];

bool            SM_bModuleIsEnabled;
bool            SM_bHooked;

// Saves first round score
bool            SM_bIsFirstRoundOver;
bool            SM_bIsSecondRoundStarted;
bool            SM_bIsSecondRoundOver;

// Cvars
ConVar          SM_cvEnable;
ConVar          SM_cvHBRatio;
ConVar          SM_cvSurvivalBonusRatio;
ConVar          SM_cvMapMulti;
ConVar          SM_cvCustomMaxDistance;

// Default Cvar Values
ConVar          SM_cvSurvivalBonus;
ConVar          SM_cvTieBreaker;
ConVar          SM_cvHealPercent;
ConVar          SM_cvPillPercent;
ConVar          SM_cvAdrenPercent;
ConVar          SM_cvTempMulti0;
ConVar          SM_cvTempMulti1;
ConVar          SM_cvTempMulti2;

void SM_OnModuleStart()
{
    SM_cvEnable              = CreateConVarEx("SM_enable", "1", "L4D2 Custom Scoring - Enable/Disable", CVAR_FLAGS);
    SM_cvEnable.AddChangeHook(SM_ConVarChanged_Enable);

    SM_cvHBRatio             = CreateConVarEx("SM_healthbonusratio", "2.0", "L4D2 Custom Scoring - Healthbonus Multiplier", CVAR_FLAGS, true, 0.25, true, 5.0);
    SM_cvHBRatio.AddChangeHook(SM_CVChanged_HealthBonusRatio);

    SM_cvSurvivalBonusRatio  = CreateConVarEx("SM_survivalbonusratio", "0.0", "Ratio to be used for a static survival bonus against Map distance. 25% == 100 points maximum health bonus on a 400 distance map", CVAR_FLAGS);
    SM_cvSurvivalBonusRatio.AddChangeHook(SM_CVChanged_SurvivalBonusRatio);

    SM_cvTempMulti0          = CreateConVarEx("SM_tempmulti_incap_0", "0.30625", "L4D2 Custom Scoring - How important temp health is on survivors who have had no incaps", CVAR_FLAGS, true, 0.0, true, 1.0);
    SM_cvTempMulti0.AddChangeHook(SM_ConVarChanged_TempMulti0);

    SM_cvTempMulti1          = CreateConVarEx("SM_tempmulti_incap_1", "0.17500", "L4D2 Custom Scoring - How important temp health is on survivors who have had one incap", CVAR_FLAGS, true, 0.0, true, 1.0);
    SM_cvTempMulti1.AddChangeHook(SM_ConVarChanged_TempMulti1);

    SM_cvTempMulti2          = CreateConVarEx("SM_tempmulti_incap_2", "0.10000", "L4D2 Custom Scoring - How important temp health is on survivors who have had two incaps (black and white)", CVAR_FLAGS, true, 0.0, true, 1.0);
    SM_cvTempMulti2.AddChangeHook(SM_ConVarChanged_TempMulti2);

    SM_fTempMulti[0]         = SM_cvTempMulti0.FloatValue;
    SM_fTempMulti[1]         = SM_cvTempMulti1.FloatValue;
    SM_fTempMulti[2]         = SM_cvTempMulti2.FloatValue;

    SM_cvMapMulti            = CreateConVarEx("SM_mapmulti",          "1", "L4D2 Custom Scoring - Increases Healthbonus Max to Distance Max", CVAR_FLAGS);
    SM_cvCustomMaxDistance   = CreateConVarEx("SM_custommaxdistance", "0", "L4D2 Custom Scoring - Custom max distance from config", CVAR_FLAGS);

    SM_cvSurvivalBonus       = FindConVar("vs_survival_bonus");
    SM_cvTieBreaker          = FindConVar("vs_tiebreak_bonus");
    SM_cvHealPercent         = FindConVar("first_aid_heal_percent");
    SM_cvPillPercent         = FindConVar("pain_pills_health_value");
    SM_cvAdrenPercent        = FindConVar("adrenaline_health_buffer");

    SM_iDefaultSurvivalBonus = SM_cvSurvivalBonus.IntValue;
    SM_iDefaultTieBreaker    = SM_cvTieBreaker.IntValue;
    SM_fHealPercent          = SM_cvHealPercent.FloatValue;
    SM_iPillPercent          = SM_cvPillPercent.IntValue;
    SM_iAdrenPercent         = SM_cvAdrenPercent.IntValue;

    SM_cvHealPercent.AddChangeHook(SM_ConVarChanged_Health);
    SM_cvPillPercent.AddChangeHook(SM_ConVarChanged_Health);
    SM_cvAdrenPercent.AddChangeHook(SM_ConVarChanged_Health);

    RegConsoleCmd("sm_health", SM_Cmd_Health);
}

public void SM_OnModuleEnd()
{
    PluginDisable(false);
}

public void SM_OnMapStart()
{
    if (!IsPluginEnabled()) return;

    if (!SM_cvMapMulti.BoolValue) SM_fMapMulti = 1.00;
    else SM_fMapMulti = float(GetMapMaxScore()) / 400.0;

    SM_bModuleIsEnabled = SM_cvEnable.BoolValue;

    if (SM_bModuleIsEnabled && !SM_bHooked) PluginEnable();
    if (SM_bModuleIsEnabled) SM_cvTieBreaker.IntValue = 0;
    if (SM_bModuleIsEnabled && SM_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1)
    {
        SetMapMaxScore(GetCustomMapMaxScore());
        // to allow a distance score of 0 and a health bonus
        if (GetCustomMapMaxScore() > 0) SM_fMapMulti = float(GetCustomMapMaxScore()) / 400.0;
    }

    SM_bIsFirstRoundOver     = false;
    SM_bIsSecondRoundStarted = false;
    SM_bIsSecondRoundOver    = false;
    SM_iFirstScore           = 0;

    SM_fTempMulti[0]         = SM_cvTempMulti0.FloatValue;
    SM_fTempMulti[1]         = SM_cvTempMulti1.FloatValue;
    SM_fTempMulti[2]         = SM_cvTempMulti2.FloatValue;
}

public void SM_ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (StringToInt(newValue) == 0)
    {
        PluginDisable();
        SM_bModuleIsEnabled = false;
    }
    else
    {
        PluginEnable();
        SM_bModuleIsEnabled = true;
    }
}

public void SM_ConVarChanged_TempMulti0(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fTempMulti[0] = StringToFloat(newValue);
}

public void SM_ConVarChanged_TempMulti1(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fTempMulti[1] = StringToFloat(newValue);
}

public void SM_ConVarChanged_TempMulti2(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fTempMulti[2] = StringToFloat(newValue);
}

public void SM_CVChanged_HealthBonusRatio(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fHBRatio = StringToFloat(newValue);
}

public void SM_CVChanged_SurvivalBonusRatio(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fSurvivalBonusRatio = StringToFloat(newValue);
}

public void SM_ConVarChanged_Health(ConVar convar, const char[] oldValue, const char[] newValue)
{
    SM_fHealPercent  = SM_cvHealPercent.FloatValue;
    SM_iPillPercent  = SM_cvPillPercent.IntValue;
    SM_iAdrenPercent = SM_cvAdrenPercent.IntValue;
}

void PluginEnable()
{
    HookEvent("door_close",             SM_DoorClose_Event);
    HookEvent("player_death",           SM_PlayerDeath_Event);
    HookEvent("round_end",              SM_RoundEnd_Event);
    HookEvent("round_start",            SM_RoundStart_Event);
    HookEvent("finale_vehicle_leaving", SM_FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);

    RegConsoleCmd("say",      SM_Command_Say);
    RegConsoleCmd("say_team", SM_Command_Say);

    SM_fHBRatio              = SM_cvHBRatio.FloatValue;
    SM_fSurvivalBonusRatio   = SM_cvSurvivalBonusRatio.FloatValue;
    SM_iDefaultSurvivalBonus = SM_cvSurvivalBonus.IntValue;
    SM_iDefaultTieBreaker    = SM_cvTieBreaker.IntValue;
    SM_cvTieBreaker.IntValue = 0;
    SM_fHealPercent          = SM_cvHealPercent.FloatValue;
    SM_iPillPercent          = SM_cvPillPercent.IntValue;
    SM_iAdrenPercent         = SM_cvAdrenPercent.IntValue;
    SM_bHooked               = true;
}

void PluginDisable(bool unhook=true)
{
    if (unhook)
    {
        UnhookEvent("door_close",             SM_DoorClose_Event);
        UnhookEvent("player_death",           SM_PlayerDeath_Event);
        UnhookEvent("round_end",              SM_RoundEnd_Event, EventHookMode_PostNoCopy);
        UnhookEvent("round_start",            SM_RoundStart_Event, EventHookMode_PostNoCopy);
        UnhookEvent("finale_vehicle_leaving", SM_FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
    }

    SM_cvSurvivalBonus.IntValue = SM_iDefaultSurvivalBonus;
    SM_cvTieBreaker.IntValue    = SM_iDefaultTieBreaker;
    SM_bHooked                  = false;
}

public Action SM_DoorClose_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;
    if (event.GetBool("checkpoint"))
    {
        SM_cvSurvivalBonus.IntValue = SM_CalculateSurvivalBonus();
    }
}

public Action SM_PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    // Can't just check for fakeclient
    if (client && GetClientTeam(client) == 2) SM_cvSurvivalBonus.IntValue = (SM_CalculateSurvivalBonus());
}

public Action SM_RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;
    if (!SM_bIsFirstRoundOver)
    {
        // First round just ended, save the current score.
        int iAliveCount;
        SM_bIsFirstRoundOver = true;
        SM_iFirstScore = RoundToFloor(SM_CalculateAvgHealth(iAliveCount) * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio * iAliveCount / 4.0);

        // If the score is nonzero, trust the SurvivalBonus var.
        SM_iFirstScore = (SM_iFirstScore ? SM_cvSurvivalBonus.IntValue * iAliveCount : 0);
        PrintToChatAll("\x01[\x05Confogl\x01] Round 1 Bonus: \x04%d", SM_iFirstScore);
        if (SM_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1) PrintToChatAll("\x01[\x05Confogl\x01] Custom Max Distance: \x04%d", GetCustomMapMaxScore());
    }
    else if (SM_bIsSecondRoundStarted && !SM_bIsSecondRoundOver)
    {
        SM_bIsSecondRoundOver = true;
        // Second round has ended, print scores
        int iAliveCount;
        int iScore = RoundToFloor(SM_CalculateAvgHealth(iAliveCount) * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio * iAliveCount / 4.0);
        // If the score is nonzero, trust the SurvivalBonus var.
        iScore = iScore ? SM_cvSurvivalBonus.IntValue * iAliveCount : 0;
        PrintToChatAll("\x01[\x05Confogl\x01] Round 1 Bonus: \x04%d", SM_iFirstScore);
        PrintToChatAll("\x01[\x05Confogl\x01] Round 2 Bonus: \x04%d", iScore);
        if (SM_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1) PrintToChatAll("\x01[\x05Confogl\x01] Custom Max Distance: \x04%d", GetCustomMapMaxScore());
    }
}
public Action SM_RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;
    // Mark the beginning of the second round.
    if (SM_bIsFirstRoundOver) SM_bIsSecondRoundStarted = true;
}

public Action SM_FinaleVehicleLeaving_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;

    SM_cvSurvivalBonus.IntValue = SM_CalculateSurvivalBonus();
}

int SM_IsPlayerIncap(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

public Action SM_Cmd_Health(int client, int args)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return;

    int iAliveCount;
    float fAvgHealth = SM_CalculateAvgHealth(iAliveCount);

    if (SM_bIsSecondRoundStarted) PrintToChat(client, "\x01[\x05Confogl\x01] Round 1 Bonus: \x04%d", SM_iFirstScore);

    if (client) PrintToChat(client, "\x01[\x05Confogl\x01] Average Health: \x04%.02f", fAvgHealth);
    else PrintToServer("[Confogl] Average Health: %.02f", fAvgHealth);

    int iScore = RoundToFloor(fAvgHealth * SM_fMapMulti * SM_fHBRatio) * iAliveCount ;

    if (DEBUG_SM || IsDebugEnabled())
        LogMessage("[ScoreMod] CalcScore: %d MapMulti: %.02f Multiplier %.02f", iScore, SM_fMapMulti, SM_fHBRatio);

    if (client)
    {
        PrintToChat(client, "\x01[\x05Confogl\x01] Health Bonus: \x04%d", iScore );
        if (SM_fSurvivalBonusRatio != 0.0) PrintToChat(client, "\x01[\x05Confogl\x01] Static Survival Bonus Per Survivor: \x04%d", RoundToFloor(400 * SM_fMapMulti * SM_fSurvivalBonusRatio));
        if (SM_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1) PrintToChat(client, "\x01[\x05Confogl\x01] Custom Max Distance: \x04%d", GetCustomMapMaxScore());
    }
    else
    {
        PrintToServer("[Confogl] Health Bonus: %d", iScore );
        if (SM_fSurvivalBonusRatio != 0.0) PrintToServer("[Confogl] Static Survival Bonus Per Survivor: %d", RoundToFloor(400 * SM_fMapMulti * SM_fSurvivalBonusRatio));
        if (SM_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1) PrintToServer("[Confogl] Custom Max Distance: %d", GetCustomMapMaxScore());
    }


}

stock int SM_CalculateSurvivalBonus()
{
    return RoundToFloor(SM_CalculateAvgHealth() * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio);
}

stock int SM_CalculateScore()
{
    int iAliveCount;
    float fScore = SM_CalculateAvgHealth(iAliveCount);

    return RoundToFloor(fScore * SM_fMapMulti * SM_fHBRatio + 400 * SM_fMapMulti * SM_fSurvivalBonusRatio) * iAliveCount;
}

stock float SM_CalculateAvgHealth(int &iAliveCount = 0)
{
    int iTotalHealth;
    int iTotalTempHealth[3];

    float fTotalAdjustedTempHealth;
    bool IsFinale = IsMapFinale();
    // Temporary Storage Variables for inventory
    int iTemp;
    int iCurrHealth;
    int iCurrTemp;
    int iIncapCount;
    char strTemp[50];

    int iSurvCount;
    iAliveCount = 0;

    for (int index = 1; index <= MaxClients; index++)
    {
        if (IsSurvivor(index))
        {
            iSurvCount++;
            if (IsPlayerAlive(index))
            {

                if (!SM_IsPlayerIncap(index))
                {
                    // Get Main health stats
                    iCurrTemp   = GetSurvivorTempHealth(index);
                    iCurrHealth = GetSurvivorPermanentHealth(index);
                    iIncapCount = GetSurvivorIncapCount(index);
                    // Adjust for kits
                    iTemp       = GetPlayerWeaponSlot(index, 3);
                    if (iTemp > -1)
                    {
                        GetEdictClassname(iTemp, strTemp, sizeof(strTemp));
                        if (StrEqual(strTemp, "weapon_first_aid_kit"))
                        {
                            iCurrTemp   = 0;
                            iIncapCount = 0;
                            iCurrHealth = RoundToFloor(iCurrHealth + ((100 - iCurrHealth) * SM_fHealPercent));
                        }
                    }
                    // Adjust for pills/adrenaline
                    iTemp = GetPlayerWeaponSlot(index, 4);
                    if (iTemp > -1)
                    {
                        GetEdictClassname(iTemp, strTemp, sizeof(strTemp));
                        if (StrEqual(strTemp, "weapon_pain_pills"))      iCurrTemp += SM_iPillPercent;
                        else if (StrEqual(strTemp, "weapon_adrenaline")) iCurrTemp += SM_iAdrenPercent;
                    }
                    // Enforce max 100 total health points
                    if ((iCurrTemp + iCurrHealth) > 100) iCurrTemp = 100 - iCurrHealth;
                    iAliveCount++;

                    iTotalHealth += iCurrHealth;
                    if (iIncapCount < 0 )       iIncapCount = 0;
                    else if (iIncapCount > 2 )  iIncapCount = 2;
                    iTotalTempHealth[iIncapCount] += iCurrTemp;
                }
                else if (!IsFinale)
                {
                    iAliveCount++;
                }
            }
        }
    }

    for (int i; i < 3; i++) fTotalAdjustedTempHealth += iTotalTempHealth[i] * SM_fTempMulti[i];

    // Total Score = Average Health points * numAlive

    // Average Health points = Total Health Points / Survivor Count
    // Total Health Points = Total Permanent Health + Total Adjusted Temp Health

    // return Average Health Points
    float fAvgHealth  = (iTotalHealth + fTotalAdjustedTempHealth) / iSurvCount;

    #if DEBUG_SM
        LogMessage("[ScoreMod] TotalPerm: %d TotalAdjustedTemp: %.02f SurvCount: %d AliveCount: %d AvgHealth: %.02f",
            iTotalHealth, fTotalAdjustedTempHealth, iSurvCount, iAliveCount, fAvgHealth);
    #endif

    return fAvgHealth;
}

public Action SM_Command_Say(int client, int args)
{
    if (!SM_bModuleIsEnabled || !IsPluginEnabled()) return Plugin_Continue;

    char sMessage[MAX_NAME_LENGTH];
    GetCmdArg(1, sMessage, sizeof(sMessage));

    if (StrEqual(sMessage, "!health")) return Plugin_Handled;

    return Plugin_Continue;
}
