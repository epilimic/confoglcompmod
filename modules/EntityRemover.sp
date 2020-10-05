#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define DEBUG_ER                    0

KeyValues   kvERData;
ConVar      ER_cvKillParachutist;
ConVar      ER_cvReplaceGhostHurt;
bool        ER_bReplaceGhostHurt;
bool        ER_bKillParachutist     = true;


#define ER_KV_ACTION_KILL           1

#define ER_KV_PROPTYPE_INT          1
#define ER_KV_PROPTYPE_FLOAT        2
#define ER_KV_PROPTYPE_BOOL         3
#define ER_KV_PROPTYPE_STRING       4

#define ER_KV_CONDITION_EQUAL       1
#define ER_KV_CONDITION_NEQUAL      2
#define ER_KV_CONDITION_LESS        3
#define ER_KV_CONDITION_GREAT       4
#define ER_KV_CONDITION_CONTAINS    5


void ER_OnModuleStart()
{
    HookEvent("round_start", ER_RoundStart_Event);

    ER_cvKillParachutist  = CreateConVarEx("remove_parachutist", "1", "Removes the parachutist from c3m2");
    ER_cvReplaceGhostHurt = CreateConVarEx("disable_ghost_hurt", "0", "Replaces all trigger_ghost_hurt with trigger_hurt, blocking ghost spawns from dying.");
    ER_bKillParachutist  = ER_cvKillParachutist.BoolValue;
    ER_bReplaceGhostHurt = ER_cvReplaceGhostHurt.BoolValue;
    ER_cvKillParachutist.AddChangeHook(ER_ConVarChange);
    ER_cvReplaceGhostHurt.AddChangeHook(ER_ConVarChange);

    ER_KV_Load();

    RegAdminCmd("confogl_erdata_reload", ER_KV_CmdReload, ADMFLAG_CONFIG);
}

public void ER_OnModuleEnd()
{
    ER_KV_Close();
}

public void ER_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ER_bKillParachutist  = ER_cvKillParachutist.BoolValue;
    ER_bReplaceGhostHurt = ER_cvReplaceGhostHurt.BoolValue;
}

void ER_KV_Close()
{
    if (kvERData == INVALID_HANDLE) return;
    delete kvERData;
}

void ER_KV_Load()
{
    char sNameBuff[PLATFORM_MAX_PATH];
    char sValBuff[32];
    char sDescBuff[256];

    if (DEBUG_ER || IsDebugEnabled())
        LogMessage("[ER] Loading EntityRemover KeyValues");

    kvERData = new KeyValues("EntityRemover");
    BuildConfigPath(sNameBuff, sizeof(sNameBuff), "entityremove.txt"); //Build our filepath
    if (!kvERData.ImportFromFile(sNameBuff))
    {
        LogError("[ER] Couldn't load EntityRemover data!");
        ER_KV_Close();
        return;
    }

    // Create cvars for all entity removes
    if (DEBUG_ER || IsDebugEnabled())
        LogMessage("[ER] Creating entry CVARs");

    kvERData.GotoFirstSubKey();
    do
    {
            kvERData.GotoFirstSubKey();
            do
            {
                kvERData.GetString("cvar", sNameBuff, sizeof(sNameBuff));
                kvERData.GetString("cvar_desc", sDescBuff, sizeof(sDescBuff));
                kvERData.GetString("cvar_val", sValBuff, sizeof(sValBuff));
                CreateConVarEx(sNameBuff, sValBuff, sDescBuff);
                if (DEBUG_ER || IsDebugEnabled())
                    LogMessage("[ER] Creating CVAR %s", sNameBuff);

            } while (kvERData.GotoNextKey());
            kvERData.GoBack();
    } while (kvERData.GotoNextKey());
    kvERData.Rewind();
}


public Action ER_KV_CmdReload(int client, int args)
{
    if (!IsPluginEnabled()) return Plugin_Continue;

    ReplyToCommand(client, "[ER] Reloading EntityRemoveData");
    ER_KV_Reload();
    return Plugin_Handled;
}

void ER_KV_Reload()
{
    ER_KV_Close();
    ER_KV_Load();
}

bool ER_KV_TestCondition(int lhsval, int rhsval, int condition)
{
    switch (condition)
    {
        case ER_KV_CONDITION_EQUAL:
        {
            return lhsval == rhsval;
        }
        case ER_KV_CONDITION_NEQUAL:
        {
            return lhsval != rhsval;
        }
        case ER_KV_CONDITION_LESS:
        {
            return lhsval < rhsval;
        }
        case ER_KV_CONDITION_GREAT:
        {
            return lhsval > rhsval;
        }
    }

    return false;
}

bool ER_KV_TestConditionFloat(float lhsval, float rhsval, int condition)
{
    switch (condition)
    {
        case ER_KV_CONDITION_EQUAL:
        {
            return lhsval == rhsval;
        }
        case ER_KV_CONDITION_NEQUAL:
        {
            return lhsval != rhsval;
        }
        case ER_KV_CONDITION_LESS:
        {
            return lhsval < rhsval;
        }
        case ER_KV_CONDITION_GREAT:
        {
            return lhsval > rhsval;
        }
    }

    return false;
}

bool ER_KV_TestConditionString(char[] lhsval, char[] rhsval, int condition)
{
    switch (condition)
    {
        case ER_KV_CONDITION_EQUAL:
        {
            return StrEqual(lhsval, rhsval);
        }
        case ER_KV_CONDITION_NEQUAL:
        {
            return !StrEqual(lhsval, rhsval);
        }
        case ER_KV_CONDITION_CONTAINS:
        {
            return StrContains(lhsval, rhsval) != -1;
        }
    }

    return false;
}

// Returns true if the entity is still alive (not killed)
bool ER_KV_ParseEntity(KeyValues kvEntry, int iEntity)
{
    char sBuffer[64];
    char mapname[64];

    // Check CVAR for this entry
    kvEntry.GetString("cvar", sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer) && !FindConVarEx(sBuffer).BoolValue) return true;

    // Check MapName for this entry
    GetCurrentMap(mapname, sizeof(mapname));
    kvEntry.GetString("map", sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer) && StrContains(sBuffer, mapname) == -1) return true;

    kvEntry.GetString("excludemap", sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer) && StrContains(sBuffer, mapname) != -1) return true;

    // Do property check for this entry
    kvEntry.GetString("property", sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer))
    {
        int proptype = kvEntry.GetNum("proptype");

        switch (proptype)
        {
            case ER_KV_PROPTYPE_INT, ER_KV_PROPTYPE_BOOL:
            {
                int rhsval = kvEntry.GetNum("propval");
                int lhsval = GetEntProp(iEntity, view_as<PropType>(kvEntry.GetNum("propdata")), sBuffer);
                if (!ER_KV_TestCondition(lhsval, rhsval, kvEntry.GetNum("condition"))) return true;
            }
            case ER_KV_PROPTYPE_FLOAT:
            {
                float rhsval = kvEntry.GetFloat("propval");
                float lhsval = GetEntPropFloat(iEntity, view_as<PropType>(kvEntry.GetNum("propdata")), sBuffer);
                if (!ER_KV_TestConditionFloat(lhsval, rhsval, kvEntry.GetNum("condition"))) return true;
            }
            case ER_KV_PROPTYPE_STRING:
            {
                char rhsval[64];
                char lhsval[64];
                kvEntry.GetString("propval", rhsval, sizeof(rhsval));
                GetEntPropString(iEntity, view_as<PropType>(kvEntry.GetNum("propdata")), sBuffer, lhsval, sizeof(lhsval));
                if (!ER_KV_TestConditionString(lhsval, rhsval, kvEntry.GetNum("condition"))) return true;
            }
        }
    }
    return ER_KV_TakeAction(kvEntry.GetNum("action"), iEntity);

}

// Returns true if the entity is still alive (not killed)
bool ER_KV_TakeAction(int action, int iEntity)
{
    switch (action)
    {
        case ER_KV_ACTION_KILL:
        {
            if (DEBUG_ER || IsDebugEnabled())
                LogMessage("[ER]     Killing!");

            AcceptEntityInput(iEntity, "Kill");
            return false;
        }
        default:
        {
            LogError("[ER] ParseEntity Encountered bad action!");
        }
    }
    return true;
}

bool ER_KillParachutist(int ent)
{
    char buf[32];
    GetCurrentMap(buf, sizeof(buf));
    if (StrEqual(buf, "c3m2_swamp"))
    {
        GetEntPropString(ent, Prop_Data, "m_iName", buf, sizeof(buf));
        if (!strncmp(buf, "parachute_", 10))
        {
            AcceptEntityInput(ent, "Kill");
            return true;
        }
    }
    return false;
}

bool ER_ReplaceTriggerHurtGhost(int ent)
{
    char buf[32];
    GetEdictClassname(ent, buf, sizeof(buf));
    if (StrEqual(buf, "trigger_hurt_ghost"))
    {
        // Replace trigger_hurt_ghost with trigger_hurt
        int replace = CreateEntityByName("trigger_hurt");
        if (replace == -1)
        {
            LogError("[ER] Could not create trigger_hurt entity!");
            return false;
        }

        // Get modelname
        char model[16];
        GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));

        // Get position and rotation
        float pos[3];
        float ang[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin",   pos);
        GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);

        // Kill the old one
        AcceptEntityInput(ent, "Kill");

        // Set the values for the new one
        DispatchKeyValue(replace, "StartDisabled", "0");
        DispatchKeyValue(replace, "spawnflags",    "67");
        DispatchKeyValue(replace, "damagetype",    "32");
        DispatchKeyValue(replace, "damagemodel",   "0");
        DispatchKeyValue(replace, "damagecap",     "10000");
        DispatchKeyValue(replace, "damage",        "10000");
        DispatchKeyValue(replace, "model",         model);
        DispatchKeyValue(replace, "filtername",    "filter_infected");

        // Spawn the new one
        TeleportEntity(replace, pos, ang, NULL_VECTOR);
        DispatchSpawn(replace);
        ActivateEntity(replace);

        return true;
    }

    return false;
}

public Action ER_RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.3, ER_RoundStart_Timer);
}

public Action ER_RoundStart_Timer(Handle timer)
{
    if (!IsPluginEnabled()) return;

    char sBuffer[64];
    if (DEBUG_ER || IsDebugEnabled())
        LogMessage("[ER] Starting RoundStart Event");

    if (kvERData != INVALID_HANDLE) kvERData.Rewind();

    int iEntCount = GetEntityCount();
    for (int ent = MAXPLAYERS + 1; ent < iEntCount; ent++)
    {
        if (IsValidEntity(ent))
        {
            GetEdictClassname(ent, sBuffer, sizeof(sBuffer));
            if (ER_bKillParachutist && ER_KillParachutist(ent))
            {
            }
            else if (ER_bReplaceGhostHurt, ER_ReplaceTriggerHurtGhost(ent))
            {
            }
            else if (kvERData != INVALID_HANDLE && kvERData.JumpToKey(sBuffer))
            {
                if (DEBUG_ER || IsDebugEnabled())
                    LogMessage("[ER] Dealing with an instance of %s", sBuffer);

                kvERData.GotoFirstSubKey();
                do
                {
                    // Parse each entry for this entity's classname
                    // Stop if we run out of entries or we have killed the entity
                    if (!ER_KV_ParseEntity(kvERData, ent)) break;
                } while (kvERData.GotoNextKey());
                kvERData.Rewind();
            }
        }
    }
}
