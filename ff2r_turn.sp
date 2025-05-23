/*
    "roll_screen"
    {
        "slot"            "0"
        "distance"        "9999.0"  // Effect range  
        "duration"        "10.0"    // Effect duration  
        "angle_x"         "0.0"     // Rotation angle on the X-axis  
        "angle_y"         "0.0"     // Rotation angle on the Y-axis  
        "angle_z"         "180.0"   // Rotation angle on the Z-axis (full rotation)  

        "plugin_name"    "ff2r_turn"
    }
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Turn Screen"
#define PLUGIN_AUTHOR   "J0BL3SS"  // Update Haunted Bone for FF2R
#define PLUGIN_DESC     "Spin my head right round"
#define PLUGIN_VERSION  "1.0.0"

#define MAXTF2PLAYERS    MAXPLAYERS + 1

#define ROLL "roll_screen"

float ROLL_Distance[MAXTF2PLAYERS];
float ROLL_Duration[MAXTF2PLAYERS];
float ROLL_Angle[MAXTF2PLAYERS][3];

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
};

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if(!cfg.IsMyPlugin())
        return;

    if(!StrContains(ability, ROLL, false))
    {
        ROLL_Distance[clientIdx] = cfg.GetFloat("distance", 1024.0);
        ROLL_Duration[clientIdx] = cfg.GetFloat("duration", 10.0);
        ROLL_Angle[clientIdx][0] = cfg.GetFloat("angle_x", 0.0);
        ROLL_Angle[clientIdx][1] = cfg.GetFloat("angle_y", 0.0);
        ROLL_Angle[clientIdx][2] = cfg.GetFloat("angle_z", 0.0);

        ROLL_Invoke(clientIdx);
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsValidClient(clientIdx))
    {
        ROLL_Distance[clientIdx] = 0.0;
        ROLL_Duration[clientIdx] = 0.0;
        ROLL_Angle[clientIdx][0] = 0.0;
        ROLL_Angle[clientIdx][1] = 0.0;
        ROLL_Angle[clientIdx][2] = 0.0;
    }
}

public void ROLL_Invoke(int clientIdx)
{
    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && (GetClientTeam(i) != GetClientTeam(clientIdx) || HasThriperson(i)))
        {
            float clientPos[3];
            GetClientAbsOrigin(i, clientPos);

            if(GetVectorDistance(bossPos, clientPos) <= ROLL_Distance[clientIdx])
            {
                float angles[3];
                GetClientEyeAngles(i, angles);

                angles[0] += ROLL_Angle[clientIdx][0];
                angles[1] += ROLL_Angle[clientIdx][1];
                angles[2] += ROLL_Angle[clientIdx][2];

                TeleportEntity(i, NULL_VECTOR, angles, NULL_VECTOR);

                CreateTimer(ROLL_Duration[clientIdx], Timer_ResetView, i, TIMER_FLAG_NO_MAPCHANGE);
            }
        }
    }
}

public Action Timer_ResetView(Handle timer, int clientIdx)
{
    if(IsValidClient(clientIdx))
    {
        float angles[3];
        GetClientEyeAngles(clientIdx, angles);
        angles[0] -= ROLL_Angle[clientIdx][0];
        angles[1] -= ROLL_Angle[clientIdx][1];
        angles[2] -= ROLL_Angle[clientIdx][2];
        TeleportEntity(clientIdx, NULL_VECTOR, angles, NULL_VECTOR);
    }
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
    if(clientIdx <= 0 || clientIdx > MaxClients)
        return false;

    if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
        return false;

    if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
        return false;

    if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
        return false;

    return true;
}

stock bool HasThriperson(int clientIdx)
{
    return GetEntProp(clientIdx, Prop_Send, "m_bThriperson") == 1;
}