#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG_MI        0

KeyValues       kMIData;

static bool     MapDataAvailable;
static float    Start_Point[3];
static float    End_Point[3];
static float    Start_Dist;
static float    Start_Extra_Dist;
static float    End_Dist;

static int      iMapMaxDistance;
static int      iIsInEditMode[MAXPLAYERS];
static float    fLocTemp[MAXPLAYERS][3];

void MI_OnModuleStart()
{
    MI_KV_Load();

    RegAdminCmd("confogl_midata_save",   MI_KV_CmdSave,    ADMFLAG_CONFIG);
    RegAdminCmd("confogl_save_location", MI_KV_CmdSaveLoc, ADMFLAG_CONFIG);

    HookEvent("player_disconnect", PlayerDisconnect_Event);
}

void MI_APL()
{
    CreateNative("LGO_IsMapDataAvailable", _native_IsMapDataAvailable);
    CreateNative("LGO_GetMapValueInt",     _native_GetMapValueInt);
    CreateNative("LGO_GetMapValueFloat",   _native_GetMapValueFloat);
    CreateNative("LGO_GetMapValueVector",  _native_GetMapValueVector);
    CreateNative("LGO_GetMapValueString",  _native_GetMapValueString);
    CreateNative("LGO_CopyMapSubsection",  _native_CopyMapSubsection);
}

void MI_OnMapStart()
{
    MI_KV_UpdateMapInfo();
}

void MI_OnMapEnd()
{
    kMIData.Rewind();
    MapDataAvailable = false;
    for (int i; i < MAXPLAYERS; i++) iIsInEditMode[i] = 0;
}

public void MI_OnModuleEnd()
{
    MI_KV_Close();
}

public void PlayerDisconnect_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > -1 && client < MAXPLAYERS) iIsInEditMode[client] = 0;
}

public Action MI_KV_CmdSave(int client, int args)
{
    char sCurMap[128];
    GetCurrentMap(sCurMap, sizeof(sCurMap));

    if (kMIData.JumpToKey(sCurMap, true))
    {
        kMIData.SetVector("start_point", Start_Point);
        kMIData.SetFloat("start_dist", Start_Dist);
        kMIData.SetFloat("start_extra_dist", Start_Extra_Dist);

        char sNameBuff[PLATFORM_MAX_PATH];
        BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt");

        kMIData.Rewind();

        kMIData.ExportToFile(sNameBuff);

        ReplyToCommand(client, "%s has been added to %s.", sCurMap, sNameBuff);
    }
}

public Action MI_KV_CmdSaveLoc(int client, int args)
{
    bool updateinfo;
    char sCurMap[128];
    GetCurrentMap(sCurMap, sizeof(sCurMap));

    if (!iIsInEditMode[client])
    {
        if (!args)
        {
            ReplyToCommand(client, "Move to the location of the medkits, then enter the point type (start_point or end_point)");
            return Plugin_Handled;
        }

        char sBuffer[16];
        GetCmdArg(1, sBuffer, sizeof(sBuffer));

        if (StrEqual(sBuffer, "start_point", true))
        {
            iIsInEditMode[client] = 1;
            ReplyToCommand(client, "Move a few feet from the medkits and enter this command again to set the start_dist for this point");
        }
        else if (StrEqual(sBuffer, "end_point", true))
        {
            iIsInEditMode[client] = 2;
            ReplyToCommand(client, "Move to the farthest point in the saferoom and enter this command again to set the end_dist for this point");
        }
        else
        {
            ReplyToCommand(client, "Please enter the location type: start_point, end_point");
            return Plugin_Handled;
        }

        if (kMIData.JumpToKey(sCurMap, true))
        {
            GetClientAbsOrigin(client, fLocTemp[client]);
            kMIData.SetVector(sBuffer, fLocTemp[client]);
        }
        updateinfo = true;
    }
    else if (iIsInEditMode[client] == 1)
    {
        iIsInEditMode[client] = 3;
        float fDistLoc[3];
        float fDistance;
        GetClientAbsOrigin(client, fDistLoc);
        fDistance = GetVectorDistance(fDistLoc, fLocTemp[client]);
        if (kMIData.JumpToKey(sCurMap, true)) kMIData.SetFloat("start_dist", fDistance);

        ReplyToCommand(client, "Move to the farthest point in the saferoom and enter this command again to set start_extra_dist for this point");

        updateinfo = true;
    }
    else if (iIsInEditMode[client] == 2)
    {
        iIsInEditMode[client] = 0;
        float fDistLoc[3];
        float fDistance;
        GetClientAbsOrigin(client, fDistLoc);
        fDistance = GetVectorDistance(fDistLoc, fLocTemp[client]);
        if (kMIData.JumpToKey(sCurMap, true)) kMIData.SetFloat("end_dist", fDistance);

        updateinfo = true;
    }
    else if (iIsInEditMode[client] == 3)
    {
        iIsInEditMode[client] = 0;
        float fDistLoc[3];
        float fDistance;
        GetClientAbsOrigin(client, fDistLoc);
        fDistance = GetVectorDistance(fDistLoc, fLocTemp[client]);
        if (kMIData.JumpToKey(sCurMap, true)) kMIData.SetFloat("start_extra_dist", fDistance);

        updateinfo = true;
    }

    if (updateinfo)
    {
        char sNameBuff[PLATFORM_MAX_PATH];
        BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt");

        kMIData.Rewind();
        kMIData.ExportToFile(sNameBuff);

        ReplyToCommand(client, "mapinfo.txt has been updated!");
    }

    return Plugin_Handled;
}

void MI_KV_Close()
{
    if (kMIData == INVALID_HANDLE) return;
    delete kMIData;
}

void MI_KV_Load()
{
    char sNameBuff[PLATFORM_MAX_PATH];

    // TODO improve debugging methods
    if (DEBUG_MI || IsDebugEnabled())
        Debug_LogMessage("[MI] Loading MapInfo KeyValues");

    kMIData = new KeyValues("MapInfo");
    BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt"); // Build our filepath
    if (!kMIData.ImportFromFile(sNameBuff))
    {
        LogError("[MI] Couldn't load MapInfo data from path %s", sNameBuff);
        MI_KV_Close();
        return;
    }
}

void MI_KV_UpdateMapInfo()
{
    char sCurMap[128];
    GetCurrentMap(sCurMap, sizeof(sCurMap));

    if (kMIData.JumpToKey(sCurMap))
    {
        kMIData.GetVector("start_point", Start_Point);
        kMIData.GetVector("end_point", End_Point);
        Start_Dist = kMIData.GetFloat("start_dist");
        Start_Extra_Dist = kMIData.GetFloat("start_extra_dist");
        End_Dist = kMIData.GetFloat("end_dist");
        iMapMaxDistance = kMIData.GetNum("max_distance", -1);

        MapDataAvailable = true;
    }
    else
    {
        MapDataAvailable = false;
        Start_Dist = FindStartPointHeuristic(Start_Point);
        if (Start_Dist > 0.0)
        {
            // This is the largest Start Extra Dist we've encountered;
            // May be too much
            Start_Extra_Dist = 500.0;
        }
        else
        {
            ZeroVector(Start_Point);
            Start_Dist = -1.0;
            Start_Extra_Dist = -1.0;
        }

        ZeroVector(End_Point);
        End_Dist = -1.0;
        iMapMaxDistance = -1;
        LogMessage("[MI] MapInfo for %s is missing.", sCurMap);
    }
}

static stock float FindStartPointHeuristic(float result[3])
{
    int kits;
    float kitOrigin[4][3];
    float averageOrigin[3];
    int entcount = GetEntityCount();
    char entclass[128];
    for (int iEntity = 1; iEntity <= entcount && kits < 4; iEntity++)
    {
        if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) continue;
        GetEdictClassname(iEntity, entclass, sizeof(entclass));
        if (StrEqual(entclass, "weapon_first_aid_kit_spawn"))
        {
            GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", kitOrigin[kits]);
            AddToVector(averageOrigin, kitOrigin[kits]);
            kits++;
        }
    }
    if (kits < 4) return -1.0;
    ScaleVector(averageOrigin, 0.25);

    float greatestDist;
    float tempDist;

    for (int i = 0; i < 4; i++)
    {
        tempDist = GetVectorDistance(averageOrigin, kitOrigin[i]);
        if (tempDist > greatestDist) greatestDist = tempDist;
    }
    CopyVector(result, averageOrigin);
    return greatestDist + 1.0;
}

// Old Functions (Avoid using these, use the ones below)
stock float GetMapStartOriginX()
{
    return Start_Point[0];
}

stock float GetMapStartOriginY()
{
    return Start_Point[1];
}

stock float GetMapStartOriginZ()
{
    return Start_Point[2];
}

stock float GetMapEndOriginX()
{
    return End_Point[0];
}

stock float GetMapEndOriginY()
{
    return End_Point[1];
}

stock float GetMapEndOriginZ()
{
    return End_Point[2];
}

// New Super Awesome Functions!!!

stock bool IsMapFinale()
{
    return L4D_IsMissionFinalMap();
}

stock int GetCustomMapMaxScore()
{
    return iMapMaxDistance;
}

stock int GetMapMaxScore()
{
    return L4D_GetVersusMaxCompletionScore();
}

stock void SetMapMaxScore(int score)
{
    L4D_SetVersusMaxCompletionScore(score);
}

stock bool IsMapDataAvailable()
{
    return MapDataAvailable;
}


/**
 * Determines if an entity is in a start or end saferoom (based on mapinfo.txt or automatically generated info)
 *
 * @param ent           The entity to be checked
 * @param saferoom      START_SAFEROOM (1) = Start saferoom, END_SAFEROOM (2) = End saferoom (including finale area), 3 = both
 * @return              True if it is one of the specified saferoom(s)
 *                      False if it is not in the specified saferoom(s)
 *                      False if no saferoom specified
 */
stock bool IsEntityInSaferoom(int ent, int saferoom = 3)
{
    float origins[3];
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origins);

    if ((saferoom & START_SAFEROOM) && (GetVectorDistance(origins, Start_Point) <= (Start_Extra_Dist > Start_Dist ? Start_Extra_Dist : Start_Dist))) return true;
    else if ((saferoom & END_SAFEROOM) && (GetVectorDistance(origins, End_Point) <= End_Dist)) return true;
    else return false;
}

stock int GetMapValueInt(const char[] key, int defvalue = 0)
{
    return kMIData.GetNum(key, defvalue);
}
stock float GetMapValueFloat(const char[] key, float defvalue = 0.0)
{
    return kMIData.GetFloat(key, defvalue);
}
stock void GetMapValueVector(const char[] key, float vector[3], float defvalue[3] = NULL_VECTOR)
{
    kMIData.GetVector(key, vector, defvalue);
}
stock void GetMapValueString(const char[] key, char[] value, int maxlength, const char[] defvalue)
{
    kMIData.GetString(key, value, maxlength, defvalue);
}

stock void CopyMapSubsection(KeyValues kv, const char[] section)
{
    if (kMIData.JumpToKey(section, false))
    {
        KvCopySubkeys(kMIData, kv);
        kMIData.GoBack();
    }
}

stock void GetMapStartOrigin(float origin[3])
{
    origin[0] = Start_Point[0];
    origin[1] = Start_Point[1];
    origin[2] = Start_Point[2];
}

stock void GetMapEndOrigin(float origin[3])
{
    origin[0] = End_Point[0];
    origin[1] = End_Point[1];
    origin[2] = End_Point[2];
}

stock float GetMapEndDist()
{
    return End_Dist;
}

stock float GetMapStartDist()
{
    return Start_Dist;
}

stock float GetMapStartExtraDist()
{
    return Start_Extra_Dist;
}

public int _native_IsMapDataAvailable(Handle plugin, int numParams)
{
    return IsMapDataAvailable();
}

public int _native_GetMapValueInt(Handle plugin, int numParams)
{
    int len, defval;

    GetNativeStringLength(1, len);
    char[] key = new char[len+1];
    GetNativeString(1, key, len+1);

    defval = GetNativeCellRef(2);

    return GetMapValueInt(key, defval);
}

public int _native_GetMapValueFloat(Handle plugin, int numParams)
{
    int len;
    float defval;

    GetNativeStringLength(1, len);
    char[] key = new char[len+1];
    GetNativeString(1, key, len+1);

    defval = GetNativeCellRef(2);

    return view_as<int>(GetMapValueFloat(key, defval));
}

public int _native_GetMapValueVector(Handle plugin, int numParams)
{
    int len;
    float defval[3];
    float value[3];

    GetNativeStringLength(1, len);
    char[] key = new char[len+1];
    GetNativeString(1, key, len+1);

    GetNativeArray(3, defval, 3);

    GetMapValueVector(key, value, defval);

    SetNativeArray(2, value, 3);
}

public int _native_GetMapValueString(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);
    char[] key = new char[len+1];
    GetNativeString(1, key, len+1);

    GetNativeStringLength(4, len);
    char[] defval = new char[len+1];
    GetNativeString(4, defval, len+1);

    len = GetNativeCell(3);
    char[] buf = new char[len+1];

    GetMapValueString(key, buf, len, defval);

    SetNativeString(2, buf, len);
}

public int _native_CopyMapSubsection(Handle plugin, int numParams)
{
    int len;
    KeyValues kv;

    GetNativeStringLength(2, len);
    char[] key = new char[len+1];
    GetNativeString(2, key, len+1);

    kv = GetNativeCell(1);

    CopyMapSubsection(kv, key);
}
