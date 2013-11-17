#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if(GT_OnTankSpawn_Forward() == Plugin_Handled)
		return Plugin_Handled;
	BS_OnTankSpawn_Forward();
	return Plugin_Continue;
}