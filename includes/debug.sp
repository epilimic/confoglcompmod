#pragma semicolon 1
#pragma newdecls required

#if DEBUG_ALL
#define DEBUG_DEFAULT "1"
#else
#define DEBUG_DEFAULT "0"
#endif

bool debug_confogl;

ConVar cvDebugConVar;

public void Debug_OnModuleStart()
{
    cvDebugConVar = CreateConVarEx("debug", DEBUG_DEFAULT, "Turn on Debug Logging in all Confogl Modules");
    cvDebugConVar.AddChangeHook(Debug_ConVarChange);
    debug_confogl = cvDebugConVar.BoolValue;
}

public void Debug_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    debug_confogl = cvDebugConVar.BoolValue;
}

stock bool IsDebugEnabled()
{
    return debug_confogl || DEBUG_ALL;
}

void Debug_LogMessage(const char[] msg, any ...)
{
    if (!IsDebugEnabled()) return;

    char buf[512];
    VFormat(buf, sizeof(buf), msg, 2);
    LogMessage(buf);
}
