#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar  WC_cvLimitCount;

int     WC_iLimitCount      = 1;
int     WC_iLastWeapon      = -1;
int     WC_iLastClient      = -1;
char    WC_sLastWeapon[64];

void WC_OnModuleStart()
{
    WC_cvLimitCount = CreateConVarEx("limit_sniper", "1", "Limits the maximum number of sniping rifles at one time to this number", 0, true, 0.0, true, 4.0);
    WC_iLimitCount  = WC_cvLimitCount.IntValue;
    WC_cvLimitCount.AddChangeHook(WC_ConVarChange);

    HookEvent("player_use",  WC_PlayerUse_Event);
    HookEvent("weapon_drop", WC_WeaponDrop_Event);
}

public void WC_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    WC_iLimitCount = WC_cvLimitCount.IntValue;
}

public Action WC_WeaponDrop_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsPluginEnabled()) return;
    WC_iLastWeapon = event.GetInt("propid");
    WC_iLastClient = GetClientOfUserId(event.GetInt("userid"));
    event.GetString("item", WC_sLastWeapon, sizeof(WC_sLastWeapon));
}

public Action WC_PlayerUse_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsPluginEnabled()) return;

    int client = GetClientOfUserId(event.GetInt("userid"));

    int primary = GetPlayerWeaponSlot(client, 0);
    if (!IsValidEdict(primary)) return;

    char primary_name[64];
    GetEdictClassname(primary, primary_name, sizeof(primary_name));

    if (StrEqual(primary_name, "weapon_hunting_rifle") || StrEqual(primary_name, "weapon_sniper_military") || StrEqual(primary_name, "weapon_sniper_awp") || StrEqual(primary_name, "weapon_sniper_scout") || StrEqual(primary_name, "weapon_rifle_sg552"))
    {
        if (SniperCount(client) >= WC_iLimitCount)
        {
            if (IsValidEdict(primary))
            {
                RemovePlayerItem(client, primary);
                PrintToChat(client, "\x01[\x05Confogl\x01] Maximum \x04%d \x01sniping rifle(s) is enforced.", WC_iLimitCount);
            }

            if (WC_iLastClient == client)
            {
                if (IsValidEdict(WC_iLastWeapon))
                {
                    AcceptEntityInput(WC_iLastWeapon, "Kill");
                    int flags = GetCommandFlags("give");
                    SetCommandFlags("give", flags ^ FCVAR_CHEAT);

                    char sTemp[64];
                    Format(sTemp, sizeof(sTemp), "give %s", WC_sLastWeapon);
                    FakeClientCommand(client, sTemp);

                    SetCommandFlags("give", flags);
                }
            }
        }
    }

    WC_iLastWeapon    = -1;
    WC_iLastClient    = -1;
    WC_sLastWeapon[0] = 0;
}

int SniperCount(int client)
{
    int count = 0;
    for (int i = 0; i < 4; i++)
    {
        int index = GetSurvivorIndex(i);
        if (index != client && index != 0 && IsClientConnected(index))
        {
            int ent = GetPlayerWeaponSlot(index, 0);
            if (IsValidEdict(ent))
            {
                char temp[64];
                GetEdictClassname(ent, temp, sizeof(temp));
                if (StrEqual(temp, "weapon_hunting_rifle") || StrEqual(temp, "weapon_sniper_military") || StrEqual(temp, "weapon_sniper_awp") || StrEqual(temp, "weapon_sniper_scout") || StrEqual(temp, "weapon_rifle_sg552")) count++;
            }
        }
    }

    return count;
}
