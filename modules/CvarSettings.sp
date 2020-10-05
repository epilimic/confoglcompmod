#pragma semicolon 1
#pragma newdecls required

#define CVS_CVAR_MAXLEN 128

#define CVARS_DEBUG     0

enum struct CVSEntry
{
    ConVar CVSE_cvar;
    char CVSE_oldval[CVS_CVAR_MAXLEN];
    char CVSE_newval[CVS_CVAR_MAXLEN];
}

int CVSEntry_blocksize = 0;

static ArrayList CvarSettingsArray;
static bool bTrackingStarted;

void CVS_OnModuleStart()
{
    CVSEntry tmp;
    CVSEntry_blocksize = sizeof(tmp);
    CvarSettingsArray = new ArrayList(CVSEntry_blocksize);

    RegConsoleCmd("confogl_cvarsettings", CVS_CvarSettings_Cmd, "List all ConVars being enforced by Confogl");
    RegConsoleCmd("confogl_cvardiff",     CVS_CvarDiff_Cmd,     "List any ConVars that have been changed from their initialized values");

    RegServerCmd("confogl_addcvar",       CVS_AddCvar_Cmd,      "Add a ConVar to be set by Confogl");
    RegServerCmd("confogl_setcvars",      CVS_SetCvars_Cmd,     "Starts enforcing ConVars that have been added.");
    RegServerCmd("confogl_resetcvars",    CVS_ResetCvars_Cmd,   "Resets enforced ConVars.  Cannot be used during a match!");
}

void CVS_OnModuleEnd()
{
    ClearAllSettings();
}

void CVS_OnConfigsExecuted()
{
    if (bTrackingStarted) SetEnforcedCvars();
}

public Action CVS_SetCvars_Cmd(int args)
{
    if (IsPluginEnabled())
    {
        if (bTrackingStarted)
        {
            PrintToServer("Tracking has already been started");
            return;
        }
        #if CVARS_DEBUG
            LogMessage("[Confogl] CvarSettings: No longer accepting new ConVars");
        #endif
        SetEnforcedCvars();
        bTrackingStarted = true;
    }
}

public Action CVS_AddCvar_Cmd(int args)
{
    if (args != 2)
    {
        PrintToServer("Usage: confogl_addcvar <cvar> <newValue>");
        if (IsDebugEnabled())
        {
            char cmdbuf[MAX_NAME_LENGTH];
            GetCmdArgString(cmdbuf, sizeof(cmdbuf));
            LogError("[Confogl] Invalid Cvar Add: %s", cmdbuf);
        }
        return Plugin_Handled;
    }

    char cvar[CVS_CVAR_MAXLEN];
    char newval[CVS_CVAR_MAXLEN];
    GetCmdArg(1, cvar,   sizeof(cvar));
    GetCmdArg(2, newval, sizeof(newval));

    AddCvar(cvar, newval);

    return Plugin_Handled;
}

public Action CVS_ResetCvars_Cmd(int args)
{
    if (IsPluginEnabled())
    {
        PrintToServer("Can't reset tracking in the middle of a match");
        return Plugin_Handled;
    }
    ClearAllSettings();
    PrintToServer("Server CVar Tracking Information Reset!");
    return Plugin_Handled;
}

public Action CVS_CvarSettings_Cmd(int client, int args)
{
    if (!IsPluginEnabled()) return Plugin_Handled;

    if (!bTrackingStarted)
    {
        ReplyToCommand(client, "[Confogl] CVar tracking has not been started!! THIS SHOULD NOT OCCUR DURING A MATCH!");
        return Plugin_Handled;
    }

    int cvscount = CvarSettingsArray.Length;
    CVSEntry cvsetting;
    char buffer[CVS_CVAR_MAXLEN];
    char name[CVS_CVAR_MAXLEN];

    ReplyToCommand(client, "[Confogl] Enforced Server CVars (Total %d)", cvscount);

    GetCmdArg(1, buffer, sizeof(buffer));
    int offset = StringToInt(buffer);

    if (offset < 0 || offset > cvscount) return Plugin_Handled;

    int temp = cvscount;
    if (offset + 20 < cvscount) temp = offset + 20;

    for (int i = offset; i < temp && i < cvscount; i++)
    {
        CvarSettingsArray.GetArray(i, cvsetting);
        cvsetting.CVSE_cvar.GetString(buffer, sizeof(buffer));
        cvsetting.CVSE_cvar.GetName(name, sizeof(name));
        ReplyToCommand(client, "[Confogl] Server CVar: %s, Desired Value: %s, Current Value: %s", name, cvsetting.CVSE_newval, buffer);
    }
    if (offset + 20 < cvscount) ReplyToCommand(client, "[Confogl] To see more CVars, use confogl_cvarsettings %d", offset+20);
    return Plugin_Handled;
}

public Action CVS_CvarDiff_Cmd(int client, int args)
{
    if (!IsPluginEnabled()) return Plugin_Handled;

    if (!bTrackingStarted)
    {
        ReplyToCommand(client, "[Confogl] CVar tracking has not been started!! THIS SHOULD NOT OCCUR DURING A MATCH!");
        return Plugin_Handled;
    }

    CVSEntry cvsetting;
    int cvscount = CvarSettingsArray.Length;
    char buffer[CVS_CVAR_MAXLEN];
    char name[CVS_CVAR_MAXLEN];

    GetCmdArg(1, buffer, sizeof(buffer));
    int offset = StringToInt(buffer);

    if (offset > cvscount) return Plugin_Handled;

    int foundCvars;

    while (offset < cvscount && foundCvars < 20)
    {
        CvarSettingsArray.GetArray(offset, cvsetting);
        cvsetting.CVSE_cvar.GetString(buffer, sizeof(buffer));
        cvsetting.CVSE_cvar.GetName(name, sizeof(name));
        if (!StrEqual(cvsetting.CVSE_newval, buffer))
        {
            ReplyToCommand(client, "[Confogl] Server CVar: %s, Desired Value: %s, Current Value: %s", name, cvsetting.CVSE_newval, buffer);
            foundCvars++;
        }
        offset++;
    }

    if (offset < cvscount) ReplyToCommand(client, "[Confogl] To see more CVars, use confogl_cvarsettings %d", offset);

    return Plugin_Handled;
}

static void ClearAllSettings()
{
    bTrackingStarted = false;
    CVSEntry cvsetting;
    for (int i; i < CvarSettingsArray.Length; i++)
    {
        CvarSettingsArray.GetArray(i, cvsetting);

        cvsetting.CVSE_cvar.RemoveChangeHook(CVS_ConVarChange);
        cvsetting.CVSE_cvar.SetString(cvsetting.CVSE_oldval);
    }

    CvarSettingsArray.Clear();
}

static void SetEnforcedCvars()
{
    CVSEntry cvsetting;
    for (int i; i < CvarSettingsArray.Length; i++)
    {
        CvarSettingsArray.GetArray(i, cvsetting);
        #if CVARS_DEBUG
            char debug_buffer[CVS_CVAR_MAXLEN];
            cvsetting.CVSE_cvar.GetName(debug_buffer, sizeof(debug_buffer));
            LogMessage("cvar = %s, newval = %s", debug_buffer, cvsetting.CVSE_newval.);
        #endif
        cvsetting.CVSE_cvar.SetString(cvsetting.CVSE_newval);
    }
}

static void AddCvar(const char[] cvar, const char[] newval)
{
    if (bTrackingStarted)
    {
        #if CVARS_DEBUG
        LogMessage("[Confogl] CvarSettings: Attempt to track new cvar %s during a match!", cvar);
        #endif
        return;
    }
    if (strlen(cvar) >= CVS_CVAR_MAXLEN)
    {
        LogError("[Confogl] CvarSettings: CVar Specified (%s) is longer than max cvar/value length (%d)", cvar, CVS_CVAR_MAXLEN);
        return;
    }
    if (strlen(newval) >= CVS_CVAR_MAXLEN)
    {
        LogError("[Confogl] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", newval, CVS_CVAR_MAXLEN);
        return;
    }

    ConVar newCvar = FindConVar(cvar);

    if (newCvar == INVALID_HANDLE)
    {
        LogError("[Confogl] CvarSettings: Could not find CVar specified (%s)", cvar);
        return;
    }

    CVSEntry newEntry;
    char cvarBuffer[CVS_CVAR_MAXLEN];
    for (int i = 0; i < CvarSettingsArray.Length; i++)
    {
        CvarSettingsArray.GetArray(i, newEntry);
        newEntry.CVSE_cvar.GetName(cvarBuffer, CVS_CVAR_MAXLEN);
        if (StrEqual(cvar, cvarBuffer, false))
        {
            LogError("[Confogl] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", cvar);
            return;
        }
    }

    newCvar.GetString(cvarBuffer, CVS_CVAR_MAXLEN);

    newEntry.CVSE_cvar = newCvar;
    strcopy(newEntry.CVSE_oldval, CVS_CVAR_MAXLEN, cvarBuffer);
    strcopy(newEntry.CVSE_newval, CVS_CVAR_MAXLEN, newval);

    newCvar.AddChangeHook(CVS_ConVarChange);

    #if CVARS_DEBUG
        LogMessage("[Confogl] CvarSettings: cvar = %s, newval = %s, oldval = %s", cvar, newval, cvarBuffer);
    #endif

    CvarSettingsArray.PushArray(newEntry);
}

public void CVS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (bTrackingStarted)
    {
        char name[CVS_CVAR_MAXLEN];
        convar.GetName(name, sizeof(name));
        PrintToChatAll("!!! [Confogl] Tracked Server CVar \"%s\" changed from \"%s\" to \"%s\" !!!", name, oldValue, newValue);
    }
}
