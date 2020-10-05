#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define CVAR_PREFIX         "confogl_"
#define CVAR_FLAGS          FCVAR_NONE
#define CVAR_PRIVATE        (FCVAR_DONTRECORD | FCVAR_PROTECTED)

ConVar CreateConVarEx(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
    char sBuffer[128];
    ConVar cvar;
    Format(sBuffer,sizeof(sBuffer),"%s%s", CVAR_PREFIX, name);
    flags = flags | CVAR_FLAGS;
    cvar = CreateConVar(sBuffer, defaultValue, description, flags, hasMin, min, hasMax, max);

    return cvar;
}

ConVar FindConVarEx(const char[] name)
{
    char sBuffer[128];
    Format(sBuffer, sizeof(sBuffer), "%s%s", CVAR_PREFIX, name);
    return FindConVar(sBuffer);
}

bool bIsPluginEnabled = false;

bool IsHumansOnServer()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && !IsFakeClient(i)) return true;
    }
    return false;
}

bool IsVersus()
{
    char GameMode[32];
    FindConVar("mp_gamemode").GetString(GameMode, sizeof(GameMode));
    return StrContains(GameMode, "versus", false) != -1;
}

bool IsScavenge()
{
    char GameMode[32];
    FindConVar("mp_gamemode").GetString(GameMode, sizeof(GameMode));
    return StrContains(GameMode, "scavenge", false) != -1;
}

bool IsPluginEnabled(bool bSetStatus = false, bool bStatus = false)
{
    if (bSetStatus) bIsPluginEnabled = bStatus;
    return bIsPluginEnabled;
}

stock int GetSurvivorPermanentHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock int GetSurvivorTempHealth(int client)
{
    int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
    return temphp > 0 ? temphp : 0;
}

stock int GetSurvivorIncapCount(int client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

stock bool IsSurvivor(int client)
{
    return IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock void ZeroVector(float vector[3])
{
    vector = NULL_VECTOR;
}

stock void AddToVector(float to[3], float from[3])
{
    to[0] += from[0];
    to[1] += from[1];
    to[2] += from[2];
}

stock void CopyVector(float to[3], float from[3])
{
    to = from;
}

stock int GetURandomIntRange(int min, int max) { return RoundToNearest((GetURandomFloat() * (max-min)) + min); }

/**
 * Finds the first occurrence of a pattern in another string.
 *
 * @param str           String to search in.
 * @param pattern       String pattern to search for
 * @param reverse       False (default) to search forward, true to search
 *                      backward.
 * @return              The index of the first character of the first
 *                      occurrence of the pattern in the string, or -1 if the
 *                      character was not found.
 */
stock int FindPatternInString(const char[] str, const char[] pattern, bool reverse = false)
{
    int i, c, len;

    len = strlen(pattern);
    c = pattern[0];
    while (i < len && (i = FindCharInString(str[i], c, reverse)) != -1)
    {
        if (strncmp(str[i], pattern, len)) return i;
    }
    return -1;
}

/**
 * Counts the number of occurences of pattern in another string.
 *
 * @param str           String to search in.
 * @param pattern       String pattern to search for
 * @param overlap       False (default) to count only non-overlapping
 *                      occurences, true to count matches within other
 *                      occurences.
 * @return              The number of occurences of the pattern in the string
 */
stock int CountPatternsInString(const char[] str, const char[] pattern, bool overlap = false)
{
    int off, i, delta, cnt;
    int len = strlen(str);

    delta = overlap ? strlen(pattern) : 1;
    while (i < len && (off = FindPatternInString(str[i], pattern)) != -1)
    {
        cnt++;
        i += off + delta;
    }
    return cnt;
}

/**
 * Counts the number of occurences of pattern in another string.
 *
 * @param str           String to search in.
 * @param c             Character to search for.
 * @return              The number of occurences of the pattern in the string
 */
stock int CountCharsInString(const char[] str, char c)
{
    int off, i, cnt;
    int len = strlen(str);

    while (i < len && (off = FindCharInString(str[i], c)) != -1)
    {
        cnt++;
        i += off + 1;
    }
    return cnt;
}
