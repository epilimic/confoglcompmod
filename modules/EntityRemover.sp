#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define DEBUG_ER					0

new Handle:kERData = INVALID_HANDLE;
new Handle:ER_hRemoveCab;
new Handle:ER_hKillParachutist;
new bool:ER_bKillParachutist=true;
new bool:ER_bRemoveCab=true;


#define ER_KV_ACTION_KILL			1

#define ER_KV_PROPTYPE_INT		1
#define ER_KV_PROPTYPE_FLOAT		2
#define ER_KV_PROPTYPE_BOOL		3
#define ER_KV_PROPTYPE_STRING		4

#define ER_KV_CONDITION_EQUAL		1
#define ER_KV_CONDITION_NEQUAL	2
#define ER_KV_CONDITION_LESS		3
#define ER_KV_CONDITION_GREAT		4
#define ER_KV_CONDITION_CONTAINS	5


public ER_OnModuleStart()
{
	HookEvent("round_start",ER_RoundStart_Event);
	
	ER_hRemoveCab = CreateConVarEx("remove_cabinets", "1", "Removes all health cabinets to further reduce pill density");
	ER_hKillParachutist = CreateConVarEx("remove_parachutist", "1", "Removes the parachutist from c3m2");
	HookConVarChange(ER_hRemoveCab,ER_ConVarChange);
	HookConVarChange(ER_hKillParachutist,ER_ConVarChange);
	
	
	ER_KV_Load();
	
	RegAdminCmd("confogl_erdata_reload", ER_KV_CmdReload, ADMFLAG_CONFIG);
}

public ER_OnModuleEnd()
{
	ER_KV_Close();
}

public ER_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ER_bRemoveCab = GetConVarBool(ER_hRemoveCab);
	ER_bKillParachutist = GetConVarBool(ER_hKillParachutist);
}

ER_KV_Close()
{
	if(kERData == INVALID_HANDLE) return;
	CloseHandle(kERData);
	kERData = INVALID_HANDLE;
}

ER_KV_Load()
{
	decl String:sNameBuff[64], String:sDescBuff[256], String:sValBuff[32];
	
	if(DEBUG_ER || IsDebugEnabled())
		LogMessage("[ER] Loading EntityRemover KeyValues");
		
	kERData = CreateKeyValues("EntityRemover");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/confogl/entityremove.txt"); //Build our filepath
	if (!FileToKeyValues(kERData, sNameBuff))
	{
		LogError("[ER] Couldn't load EntityRemover data!");
		ER_KV_Close();
		return;	
	}
	
	// Create cvars for all entity removes
	if(CV_DEBUG || IsDebugEnabled())
		LogMessage("[ER] Creating entry CVARs");
	
	KvGotoFirstSubKey(kERData);
	do
	{
			KvGotoFirstSubKey(kERData);
			do
			{
				KvGetString(kERData, "cvar", sNameBuff, sizeof(sNameBuff));
				KvGetString(kERData, "cvar_desc", sDescBuff, sizeof(sDescBuff));
				KvGetString(kERData, "cvar_val", sValBuff, sizeof(sValBuff));
				CreateConVarEx(sNameBuff, sValBuff, sDescBuff);
				if(CV_DEBUG || IsDebugEnabled())
					LogMessage("[ER] Creating CVAR %s", sNameBuff);
				
			} while(KvGotoNextKey(kERData));
			KvGoBack(kERData);
	} while(KvGotoNextKey(kERData));
	KvRewind(kERData);
}


public Action:ER_KV_CmdReload(client, args)
{
	if (!IsPluginEnabled()) return Plugin_Continue;
	
	ReplyToCommand(client, "[ER] Reloading EntityRemoveData");
	ER_KV_Reload();
	return Plugin_Handled;
}

ER_KV_Reload()
{
	ER_KV_Close();
	ER_KV_Load();	
}

bool:ER_KV_TestCondition(lhsval, rhsval, condition)
{
	switch(condition)
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

bool:ER_KV_TestConditionFloat(Float:lhsval, Float:rhsval, condition)
{
	switch(condition)
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

bool:ER_KV_TestConditionString(String:lhsval[], String:rhsval[], condition)
{
	switch(condition)
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
ER_KV_ParseEntity(Handle:kEntry, iEntity)
{
	decl String:sBuffer[64];
	
	// Check CVAR for this entry
	KvGetString(kEntry, "cvar", sBuffer, sizeof(sBuffer));	
	if(strlen(sBuffer) && !GetConVarBool(FindConVarEx(sBuffer))) return true;
	
	// Check MapName for this entry
	KvGetString(kEntry, "map", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer))
	{
		decl String:mapname[64];
		GetCurrentMap(mapname, sizeof(mapname));
		if(!StrEqual(mapname, sBuffer))
			return true;
	}
	
	// Do property check for this entry
	KvGetString(kEntry, "property", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer))
	{
		new proptype = KvGetNum(kEntry, "proptype");
		
		switch(proptype)
		{
			case ER_KV_PROPTYPE_INT, ER_KV_PROPTYPE_BOOL:
			{
				new rhsval = KvGetNum(kEntry, "propval");
				new lhsval = GetEntProp(iEntity, PropType:KvGetNum(kEntry, "propdata"), sBuffer);
				if(!ER_KV_TestCondition(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
			case ER_KV_PROPTYPE_FLOAT:
			{
				new Float:rhsval = KvGetFloat(kEntry, "propval");
				new Float:lhsval = GetEntPropFloat(iEntity, PropType:KvGetNum(kEntry, "propdata"), sBuffer);
				if(!ER_KV_TestConditionFloat(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
			case ER_KV_PROPTYPE_STRING:
			{
				decl String:rhsval[64], String:lhsval[64];
				KvGetString(kEntry, "propval", rhsval, sizeof(rhsval));
				GetEntPropString(iEntity, PropType:KvGetNum(kEntry, "propdata"), sBuffer, lhsval, sizeof(lhsval));
				if(!ER_KV_TestConditionString(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
		}
	}
	return ER_KV_TakeAction(KvGetNum(kEntry, "action"), iEntity);

}

// Returns true if the entity is still alive (not killed)
ER_KV_TakeAction(action, iEntity)
{
	switch(action)
	{
		case ER_KV_ACTION_KILL:
		{
			if(CV_DEBUG || IsDebugEnabled())
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

bool:ER_KillParachutist(ent)
{
	decl String:buf[32];
	GetCurrentMap(buf, sizeof(buf));
	if (StrEqual(buf, "c3m2_swamp"))
	{
		GetEntPropString(ent, Prop_Data, "m_iName", buf, sizeof(buf));
		if(!strncmp(buf, "parachute_", 10))
		{
			AcceptEntityInput(ent, "Kill");
			return true;
		}
	}
	return false;
}

public Action:ER_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.3,  ER_RoundStart_Timer);
}

public Action:ER_RoundStart_Timer(Handle:timer)
{
	if (!IsPluginEnabled()) return;
	
	decl String:sBuffer[64];
	if(CV_DEBUG || IsDebugEnabled())
		LogMessage("[ER] Starting RoundStart Event");
	
	if(kERData != INVALID_HANDLE) KvRewind(kERData);
	decl Float:fCabinetLocation[2][3];
	new iCabCount = 0;
	
	new iEntCount = GetEntityCount();
	for (new ent = MAXPLAYERS+1; ent < iEntCount; ent++)
	{
		if (IsValidEntity(ent))
		{
			GetEdictClassname(ent, sBuffer, sizeof(sBuffer));
			if (ER_bRemoveCab && StrEqual("prop_health_cabinet", sBuffer))
			{
				GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fCabinetLocation[iCabCount]);
				fCabinetLocation[iCabCount++][2] += 50;
				AcceptEntityInput(ent, "Kill");
			}
			else if (ER_bKillParachutist && ER_KillParachutist(ent))
			{
			}
			else if (kERData != INVALID_HANDLE && KvJumpToKey(kERData, sBuffer))
			{
				if(CV_DEBUG || IsDebugEnabled())
					LogMessage("[ER] Dealing with an instance of %s", sBuffer);
				
				KvGotoFirstSubKey(kERData);
				do
				{
					// Parse each entry for this entity's classname
					// Stop if we run out of entries or we have killed the entity
					if(!ER_KV_ParseEntity(kERData, ent)) break;	
				} while (KvGotoNextKey(kERData));
				KvRewind(kERData);
			}
		}
	}

	
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	if (iCabCount == 0 || !ER_bRemoveCab || StrContains(sBuffer, "c4m2") != -1) return;
	
	new Float:fLocation[3];
	for (new ent = MAXPLAYERS+1; ent < iEntCount; ent++)
	{
		for (new i = 0; i < iCabCount; i++)
		{
			if (!IsValidEntity(ent)) continue;
			
			GetEdictClassname(ent, sBuffer, sizeof(sBuffer));
			if (!StrEqual("weapon_pain_pills_spawn", sBuffer)) continue;
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fLocation);
			if (GetVectorDistance(fLocation, fCabinetLocation[i]) < 20.0)
			{
				AcceptEntityInput(ent, "Kill");	
			}
		}
	}
}
