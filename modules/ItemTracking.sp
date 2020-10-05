#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

// Item lists for tracking/decoding/etc
enum ItemList {
    IL_PainPills,
    IL_Adrenaline,
    IL_PipeBomb,
    IL_Molotov,
    IL_VomitJar,
    IL_Size = 5
};

// Names for cvars, kv, descriptions
enum ItemNames {
    IN_shortname,
    IN_longname,
    IN_officialname,
    IN_modelname,
    IN_Size = 4
};

static StringMap g_smItemListTrie;

static const char g_sItemNames[IL_Size][IN_Size][] =
{
    { "pills", "pain pills", "pain_pills", "painpills" },
    { "adrenaline", "adrenaline shots", "adrenaline", "pipebomb" },
    { "pipebomb", "pipe bombs", "pipe_bomb", "pipebomb" },
    { "molotov", "molotovs", "molotov", "molotov" },
    { "vomitjar", "bile bombs", "vomitjar", "bile_flask" }
};

// For spawn entires adt_array
enum struct ItemTracking {
    int   IT_entity;
    float IT_origins;
    float IT_origins1;
    float IT_origins2;
    float IT_angles;
    float IT_angles1;
    float IT_angles2;
}

int ItemTracking_blocksize = 0;

static ConVar g_cvCvarEnabled;
static ConVar g_cvCvarConsistentSpawns;
static ConVar g_cvCvarMapSpecificSpawns;
static ConVar g_cvSurvivorLimit;
static ConVar g_cvCvarLimits[view_as<int>(IL_Size)];
// ADT Array Handle for actual item spawns
static ArrayList g_alItemSpawns[view_as<int>(IL_Size)];
// CVAR Handle Array for item limits
// Current item limits array
static int g_iSurvivorLimit;
static int g_iSaferoomCount[2];
static int g_iItemLimits[view_as<int>(IL_Size)];
// Is round 1 over?
static bool g_bIsRound1Over;

static bool IsModuleEnabled() {
    return IsPluginEnabled() && g_cvCvarEnabled.BoolValue;
}

static bool UseConsistentSpawns() {
    return g_cvCvarConsistentSpawns.BoolValue;
}

static int GetMapInfoMode() {
    return g_cvCvarMapSpecificSpawns.IntValue;
}

void IT_OnModuleStart()
{
    char sNameBuf[64];
    char sCvarDescBuf[256];

    g_cvCvarEnabled           = CreateConVarEx("enable_itemtracking",      "0", "Enable the itemtracking module");
    g_cvCvarConsistentSpawns  = CreateConVarEx("itemtracking_savespawns",  "0", "Keep item spawns the same on both rounds");
    g_cvCvarMapSpecificSpawns = CreateConVarEx("itemtracking_mapspecific", "0", "Change how mapinfo.txt overrides work. 0 = ignore mapinfo.txt, 1 = allow limit reduction, 2 = allow limit increases,");

    // Create itemlimit cvars
    for (int i = 0; i < view_as<int>(IL_Size); i++)
    {
        Format(sNameBuf,     sizeof(sNameBuf),     "%s_limit",                                                                    g_sItemNames[i][IN_shortname]);
        Format(sCvarDescBuf, sizeof(sCvarDescBuf), "Limits the number of %s on each map. -1: no limit; >=0: limit to cvar value", g_sItemNames[i][IN_longname]);
        g_cvCvarLimits[i] = CreateConVarEx(sNameBuf, "-1", sCvarDescBuf);
    }

    // Create name translation trie
    g_smItemListTrie = CreateItemListTrie();

    ItemTracking itTemp;
    ItemTracking_blocksize = sizeof(itTemp);
    // Create item spawns array;
    for (int i = 0; i < view_as<int>(IL_Size); i++)
    {
        g_alItemSpawns[i] = new ArrayList(ItemTracking_blocksize);
    }


    HookEvent("round_start", _IT_RoundStartEvent, EventHookMode_PostNoCopy);
    HookEvent("round_end",   _IT_RoundEndEvent,   EventHookMode_PostNoCopy);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(_IT_SurvivorLimit_Change);
}

void IT_OnMapStart()
{
    for (int i = 0; i < view_as<int>(IL_Size); i++)
    {
        g_iItemLimits[i] = g_cvCvarLimits[i].IntValue;
    }

    if (GetMapInfoMode())
    {
        int itemlimit;
        KeyValues kvOverrideLimits = new KeyValues("ItemLimits");
        CopyMapSubsection(kvOverrideLimits, "ItemLimits");

        for (int i = 0; i < view_as<int>(IL_Size); i++)
        {
            itemlimit = g_cvCvarLimits[i].IntValue;
            int temp = kvOverrideLimits.GetNum(g_sItemNames[i][IN_officialname], itemlimit);
            if (((g_iItemLimits[i] > temp) && (GetMapInfoMode() & 1)) || ((g_iItemLimits[i] < temp) && (GetMapInfoMode() & 2)))
            {
                g_iItemLimits[i] = temp;
            }
            g_alItemSpawns[i].Clear();
        }
        delete kvOverrideLimits;
    }
    g_bIsRound1Over = false;
}

public void _IT_RoundEndEvent(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsRound1Over = true;
}

public void _IT_RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
    g_iSaferoomCount[START_SAFEROOM - 1] = 0;
    g_iSaferoomCount[END_SAFEROOM - 1]   = 0;
    // Mapstart happens after round_start most of the time, so we need to wait for g_bIsRound1Over.
    // Plus, we don't want to have conflicts with EntityRemover.
    CreateTimer(1.0, IT_RoundStartTimer);
}

public Action IT_RoundStartTimer(Handle timer)
{
    if (!g_bIsRound1Over)
    {
        // Round1
        if (IsModuleEnabled())
        {
            EnumAndElimSpawns();
        }
    }
    else
    {
        // Round2
        if (IsModuleEnabled())
        {
            if (UseConsistentSpawns())
            {
                GenerateStoredSpawns();
            }
            else
            {
                EnumAndElimSpawns();
            }
        }
    }
    return Plugin_Handled;
}

public void _IT_SurvivorLimit_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_iSurvivorLimit = StringToInt(newValue);
}

static void EnumAndElimSpawns()
{
    Debug_LogMessage("[IT] Resetting g_iSaferoomCount and Enumerating and eliminating spawns...");
    EnumerateSpawns();
    RemoveToLimits();
}

static void GenerateStoredSpawns()
{
    KillRegisteredItems();
    SpawnItems();
}

// Produces the lookup trie for weapon spawn entities
// to translate to our ADT array of spawns
static StringMap CreateItemListTrie()
{
    StringMap mytrie = new StringMap();
    mytrie.SetValue("weapon_pain_pills_spawn", IL_PainPills);
    mytrie.SetValue("weapon_pain_pills",       IL_PainPills);
    mytrie.SetValue("weapon_adrenaline_spawn", IL_Adrenaline);
    mytrie.SetValue("weapon_adrenaline",       IL_Adrenaline);
    mytrie.SetValue("weapon_pipe_bomb_spawn",  IL_PipeBomb);
    mytrie.SetValue("weapon_pipe_bomb",        IL_PipeBomb);
    mytrie.SetValue("weapon_molotov_spawn",    IL_Molotov);
    mytrie.SetValue("weapon_molotov",          IL_Molotov);
    mytrie.SetValue("weapon_vomitjar_spawn",   IL_VomitJar);
    mytrie.SetValue("weapon_vomitjar",         IL_VomitJar);

    return mytrie;
}

static void KillRegisteredItems()
{
    ItemList itemindex;
    int psychonic = GetEntityCount();

    for (int i = 0; i < psychonic; i++)
    {
        if (IsValidEntity(i))
        {
            itemindex = GetItemIndexFromEntity(i);
            if (itemindex >= view_as<ItemList>(0) )
            {
                if (IsEntityInSaferoom(i, START_SAFEROOM) && g_iSaferoomCount[START_SAFEROOM - 1] < g_iSurvivorLimit)
                {
                    g_iSaferoomCount[START_SAFEROOM - 1]++;
                }
                else if (IsEntityInSaferoom(i, END_SAFEROOM) && g_iSaferoomCount[END_SAFEROOM - 1] < g_iSurvivorLimit)
                {
                    g_iSaferoomCount[END_SAFEROOM - 1]++;
                }
                else
                {
                    // Kill items we're tracking;
                    if (!AcceptEntityInput(i, "kill"))
                    {
                        LogError("[IT] Error killing instance of item %s", g_sItemNames[itemindex][IN_longname]);
                    }
                }
            }
        }
    }
}

static void SpawnItems()
{
    ItemTracking curitem;
    float origins[3];
    float angles[3];
    int arrsize;
    int itement;
    char sModelname[PLATFORM_MAX_PATH];
    WeaponIDs wepid;

    for (int itemidx = 0; itemidx < view_as<int>(IL_Size); itemidx++)
    {
        Format(sModelname, sizeof(sModelname), "models/w_models/weapons/w_eq_%s.mdl", g_sItemNames[itemidx][IN_modelname]);
        arrsize = g_alItemSpawns[itemidx].Length;

        for (int idx = 0; idx < arrsize; idx++)
        {
            g_alItemSpawns[itemidx].GetArray(idx, curitem);
            GetSpawnOrigins(origins, curitem);
            GetSpawnAngles(angles, curitem);
            wepid = GetWeaponIDFromItemList(view_as<ItemList>(itemidx));

            Debug_LogMessage("[IT] Spawning an instance of item %s (%d, wepid %d), number %d, at %.02f %.02f %.02f",
                g_sItemNames[itemidx][IN_officialname], itemidx, wepid, idx, origins[0], origins[1], origins[2]);

            itement = CreateEntityByName("weapon_spawn");
            SetEntProp(itement, Prop_Send, "m_weaponID", wepid);
            SetEntityModel(itement, sModelname);
            DispatchKeyValue(itement, "count", "1");
            TeleportEntity(itement, origins, angles, NULL_VECTOR);
            DispatchSpawn(itement);
            SetEntityMoveType(itement, MOVETYPE_NONE);
        }
    }
}

static void EnumerateSpawns()
{
    ItemList itemindex;
    ItemTracking curitem;
    float origins[3];
    float angles[3];
    int psychonic = GetEntityCount();

    for (int i = 0; i < psychonic; i++)
    {
        if (IsValidEntity(i))
        {
            itemindex = GetItemIndexFromEntity(i);
            if (itemindex >= view_as<ItemList>(0))
            {
                if (IsEntityInSaferoom(i, START_SAFEROOM))
                {
                    if (g_iSaferoomCount[START_SAFEROOM - 1] < g_iSurvivorLimit)
                        g_iSaferoomCount[START_SAFEROOM - 1]++;
                    else if (!AcceptEntityInput(i, "kill"))
                        LogError("[IT] Error killing instance of item %s", g_sItemNames[itemindex][IN_longname]);
                }
                else if (IsEntityInSaferoom(i, END_SAFEROOM))
                {
                    if (g_iSaferoomCount[END_SAFEROOM - 1] < g_iSurvivorLimit)
                        g_iSaferoomCount[END_SAFEROOM - 1]++;
                    else if (!AcceptEntityInput(i, "kill"))
                        LogError("[IT] Error killing instance of item %s", g_sItemNames[itemindex][IN_longname]);
                }
                else
                {
                    int mylimit = GetItemLimit(itemindex);
                    Debug_LogMessage("[IT] Found an instance of item %s (%d), with limit %d", g_sItemNames[itemindex][IN_longname], itemindex, mylimit);
                    // Item limit is zero, justkill it as we find it
                    if (!mylimit)
                    {
                        Debug_LogMessage("[IT] Killing spawn");
                        if (!AcceptEntityInput(i, "kill"))
                        {
                            LogError("[IT] Error killing instance of item %s", g_sItemNames[itemindex][IN_longname]);
                        }
                    }
                    else
                    {
                        // Store entity, angles, origin
                        curitem.IT_entity = i;
                        GetEntPropVector(i, Prop_Send, "m_vecOrigin",   origins);
                        GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
                        Debug_LogMessage("[IT] Saving spawn #%d at %.02f %.02f %.02f", g_alItemSpawns[itemindex].Length, origins[0], origins[1], origins[2]);
                        SetSpawnOrigins(origins, curitem);
                        SetSpawnAngles(angles, curitem);

                        // Push this instance onto our array for that item
                        g_alItemSpawns[itemindex].PushArray(curitem);
                    }
                }
            }
        }
    }
}

static void RemoveToLimits()
{
    int curlimit;
    ItemTracking curitem;

    for (int itemidx = 0; itemidx < view_as<int>(IL_Size); itemidx++)
    {
        curlimit = GetItemLimit(view_as<ItemList>(itemidx));
        if (curlimit > 0)
        {
            // Kill off item spawns until we've reduced the item to the limit
            while (g_alItemSpawns[itemidx].Length > curlimit)
            {
                // Pick a random
                int killidx = GetURandomIntRange(0, g_alItemSpawns[itemidx].Length - 1);
                Debug_LogMessage("[IT] Killing randomly chosen %s (%d) #%d", g_sItemNames[itemidx][IN_longname], itemidx, killidx);
                g_alItemSpawns[itemidx].GetArray(killidx, curitem);
                if (IsValidEntity(curitem.IT_entity) && !AcceptEntityInput(curitem.IT_entity, "kill"))
                {
                    LogError("[IT] Error killing instance of item %s", g_sItemNames[itemidx][IN_longname]);
                }
                g_alItemSpawns[itemidx].Erase(killidx);
            }
        }
        // If limit is 0, they're already dead. If it's negative, we kill nothing.
    }
}

static void SetSpawnOrigins(const float buf[3], ItemTracking spawn)
{
    spawn.IT_origins  = buf[0];
    spawn.IT_origins1 = buf[1];
    spawn.IT_origins2 = buf[2];
}

static void SetSpawnAngles(const float buf[3], ItemTracking spawn)
{
    spawn.IT_angles  = buf[0];
    spawn.IT_angles1 = buf[1];
    spawn.IT_angles2 = buf[2];
}

static void GetSpawnOrigins(float buf[3], ItemTracking spawn)
{
    buf[0] = spawn.IT_origins;
    buf[1] = spawn.IT_origins1;
    buf[2] = spawn.IT_origins2;
}

static void GetSpawnAngles(float buf[3], ItemTracking spawn)
{
    buf[0] = spawn.IT_angles;
    buf[1] = spawn.IT_angles1;
    buf[2] = spawn.IT_angles2;
}

static int GetItemLimit(ItemList itemidx)
{
    return g_iItemLimits[itemidx];
}


static WeaponIDs GetWeaponIDFromItemList(ItemList id)
{
    switch(id)
    {
        case IL_PainPills:
        {
            return WEPID_PAIN_PILLS;
        }
        case IL_Adrenaline:
        {
            return  WEPID_ADRENALINE;
        }
        case IL_PipeBomb:
        {
            return WEPID_PIPE_BOMB;
        }
        case IL_Molotov:
        {
            return WEPID_MOLOTOV;
        }
        case IL_VomitJar:
        {
            return WEPID_VOMITJAR;
        }
    }

    return view_as<WeaponIDs>(-1);
}

static ItemList GetItemIndexFromEntity(int entity)
{
    static char classname[128];
    ItemList index;
    GetEdictClassname(entity, classname, sizeof(classname));

    if (g_smItemListTrie.GetValue(classname, index))
    {
        return index;
    }

    if (StrEqual(classname, "weapon_spawn") || StrEqual(classname, "weapon_item_spawn"))
    {
        WeaponIDs id = view_as<WeaponIDs>(GetEntProp(entity, Prop_Send, "m_weaponID"));

        switch(id)
        {
            case WEPID_VOMITJAR:
            {
                return IL_VomitJar;
            }
            case WEPID_PIPE_BOMB:
            {
                return IL_PipeBomb;
            }
            case WEPID_MOLOTOV:
            {
                return IL_Molotov;
            }
            case WEPID_PAIN_PILLS:
            {
                return IL_PainPills;
            }
            case WEPID_ADRENALINE:
            {
                return IL_Adrenaline;
            }
        }
    }

    return view_as<ItemList>(-1);
}
