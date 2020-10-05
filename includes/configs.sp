#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#if defined __CONFOGL_CONFIGS__
#endinput
#endif
#define __CONFOGL_CONFIGS__

static ConVar cvCustomConfig;

static char customCfgDir[] = "cfgogl";
static char configsPath[PLATFORM_MAX_PATH];
static char cfgPath[PLATFORM_MAX_PATH];
static char customCfgPath[PLATFORM_MAX_PATH];
static char DirSeparator;

void Configs_OnModuleStart()
{
    InitPaths();
    cvCustomConfig = CreateConVarEx("customcfg", "", "DONT TOUCH THIS CVAR! This is more magic bullshit!", FCVAR_DONTRECORD | FCVAR_UNLOGGED);
    char cfgString[64];
    cvCustomConfig.GetString(cfgString, sizeof(cfgString));
    SetCustomCfg(cfgString);
    cvCustomConfig.RestoreDefault();
}
void Configs_APL()
{
    CreateNative("LGO_BuildConfigPath",  _native_BuildConfigPath);
    CreateNative("LGO_ExecuteConfigCfg", _native_ExecConfigCfg);
}

void InitPaths()
{
    BuildPath(Path_SM, configsPath, sizeof(configsPath), "configs/confogl/");
    BuildPath(Path_SM, cfgPath,     sizeof(cfgPath),     "../../cfg/");
    DirSeparator = cfgPath[strlen(cfgPath) - 1];
}

bool SetCustomCfg(const char[] cfgname)
{
    if (!strlen(cfgname))
    {
        customCfgPath[0] = 0;
        cvCustomConfig.RestoreDefault();
        Debug_LogMessage("[Configs] Custom Config Path Reset - Using Default");
        return true;
    }

    Format(customCfgPath, sizeof(customCfgPath), "%s%s%c%s", cfgPath, customCfgDir, DirSeparator, cfgname);
    if (!DirExists(customCfgPath))
    {
        LogError("[Configs] Custom config directory %s does not exist!", customCfgPath);
        // Revert customCfgPath
        customCfgPath[0] = 0;
        return false;
    }
    int thislen = strlen(customCfgPath);
    if (thislen + 1 < sizeof(customCfgPath))
    {
        customCfgPath[thislen] = DirSeparator;
        customCfgPath[thislen+1] = 0;
    }
    else
    {
        LogError("[Configs] Custom config directory %s path too long!", customCfgPath);
        customCfgPath[0]=0;
        return false;
    }

    cvCustomConfig.SetString(cfgname);

    return true;
}

void BuildConfigPath(char[] buffer, int maxlength, const char[] sFileName)
{
    if (customCfgPath[0])
    {
        Format(buffer, maxlength, "%s%s", customCfgPath, sFileName);
        if (FileExists(buffer))
        {
            Debug_LogMessage("[Configs] Built custom config path: %s", buffer);
            return;
        }
        else
        {
            Debug_LogMessage("[Configs] Custom config not available: %s", buffer);
        }
    }

    Format(buffer, maxlength, "%s%s", configsPath, sFileName);
    Debug_LogMessage("[Configs] Built default config path: %s", buffer);

}

void ExecuteCfg(const char[] sFileName)
{
    if (strlen(sFileName) == 0)
    {
        return;
    }

    char sFilePath[PLATFORM_MAX_PATH];

    if (customCfgPath[0])
    {
        Format(sFilePath, sizeof(sFilePath), "%s%s", customCfgPath, sFileName);
        if (FileExists(sFilePath))
        {
            Debug_LogMessage("[Configs] Executing custom cfg file %s", sFilePath);
            ServerCommand("exec %s%s", customCfgPath[strlen(cfgPath)], sFileName);

            return;
        }
        else
        {
            Debug_LogMessage("[Configs] Couldn't find custom cfg file %s, trying default", sFilePath);
        }
    }

    Format(sFilePath, sizeof(sFilePath), "%s%s", cfgPath, sFileName);


    if (FileExists(sFilePath))
    {
        Debug_LogMessage("[Configs] Executing default config %s", sFilePath);
        ServerCommand("exec %s", sFileName);
    }
    else
    {
        LogError("[Configs] Could not execute server config \"%s\", file not found", sFilePath);
    }
}

public int _native_BuildConfigPath(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(3, len);
    char[] filename = new char[len + 1];
    GetNativeString(3, filename, len + 1);

    len = GetNativeCell(2);
    char[] buf = new char[len];
    BuildConfigPath(buf, len, filename);

    SetNativeString(1, buf, len);
}

public int _native_ExecConfigCfg(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);
    char[] filename = new char[len + 1];
    GetNativeString(1, filename, len + 1);

    ExecuteCfg(filename);
}
