#include <sourcemod>
#include <sdktools>

new Handle:UB_hEnable;
new bool:UB_bEnabled = true;

UB_OnModuleStart()
{
	UB_hEnable = CreateConVarEx("boss_unprohibit", "1", "Enable bosses spawning on all maps, even through they normally aren't allowed");
	
	HookConVarChange(UB_hEnable,UB_ConVarChange);
	
	UB_bEnabled = GetConVarBool(UB_hEnable);
}

public UB_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UB_bEnabled = GetConVarBool(UB_hEnable);
}

public Action:L4D_OnGetScriptValueInt(const String:key[], &retVal)
{
	if(!IsPluginEnabled() || !UB_bEnabled || !StrEqual(key, "ProhibitBosses")){return Plugin_Continue;}
	retVal = 0;
	return Plugin_Handled;
}