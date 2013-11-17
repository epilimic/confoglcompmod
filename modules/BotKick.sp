#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new bool:	BK_bAllowBot 	= false;
new bool:	BK_bEnable 		= true;
new Handle:	BK_hEnable;

BK_OnModuleStart()
{
	HookEvent("tank_spawn", BK_TankSpawn);
	
	BK_hEnable = CreateConVarEx("blockinfectedbots","1","Blocks infected bots from joining the game, minus when a tank spawns (allows players to spawn a AI infected first before taking control of the tank)");
	HookConVarChange(BK_hEnable,BK_ConVarChange);
	
	BK_bEnable = GetConVarBool(BK_hEnable);
}

public BK_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	BK_bEnable = GetConVarBool(BK_hEnable);
}

public BK_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	BK_bAllowBot = true;
}

public bool:OnClientConnect(client, String:rejectmsg[],maxlen)
{
	if(!IsFakeClient(client) || !BK_bEnable || !IsPluginEnabled())
	{
		return true;
	}
	
	decl String:name[10];
	GetClientName(client, name, sizeof(name));
	
	if(StrContains(name, "smoker", false) == -1 && 
		StrContains(name, "boomer", false) == -1 && 
		StrContains(name, "hunter", false) == -1 && 
		StrContains(name, "spitter", false) == -1 && 
		StrContains(name, "jockey", false) == -1 && 
		StrContains(name, "charger", false) == -1)
	{
		return true;
	}
	
	if(BK_bAllowBot)
	{
		BK_bAllowBot = false;
		return true;
	}
	
	KickClient(client,"[Confogl] Kicking infected bot...");
	
	return false;
}

