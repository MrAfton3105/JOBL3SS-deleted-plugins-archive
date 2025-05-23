/*

    "fake_death"
    {
        "slot"          "0"
        "repeat"        "2"            // How many times the boss can fake death
        "chance"        "50.0"         // Chance to trigger fake death (50%)
        "health"        "500"          // Health formula (can be a formula like "500 + 100 * n")
        "sound"         "vo/sniper_specialcompleted07.mp3"  // Sound to play on fake death
        "speed"         "400.0"        // Speed after fake death
        "block_attack"  "1"            // Block attacks during fake death
        
        "plugin_name"    "ff2r_fakedeath"
    }

*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>  
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Fake Death"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Fake Death ability for FF2R"
#define PLUGIN_VERSION 	"1.0.0"

#define FAKE_DEATH_ABILITY "fake_death"

// Variables
int FAKE_Repeat[MAXPLAYERS + 1];
float FAKE_Chance[MAXPLAYERS + 1];
char FAKE_Health[MAXPLAYERS + 1][1024];
char FAKE_SoundSection[MAXPLAYERS + 1][256];
float FAKE_Speed[MAXPLAYERS + 1];
bool FAKE_BlockAttack[MAXPLAYERS + 1];
int FAKE_RepeatTimes[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("teamplay_round_win", Event_RoundEnd);
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
	if (!cfg.IsMyPlugin() || !StrEqual(ability, FAKE_DEATH_ABILITY))
		return;

	FAKE_Repeat[client] = cfg.GetInt("repeat", 1);
	FAKE_Chance[client] = cfg.GetFloat("chance", 100.0);
	cfg.GetString("health", FAKE_Health[client], sizeof(FAKE_Health[]));
	cfg.GetString("sound", FAKE_SoundSection[client], sizeof(FAKE_SoundSection[]));
	FAKE_Speed[client] = cfg.GetFloat("speed", 340.0);
	FAKE_BlockAttack[client] = cfg.GetBool("block_attack", false);

	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (FF2R_GetBossIndex(victim) == -1)
		return Plugin_Continue;

	int boss = FF2R_GetBossIndex(victim);
	if (FF2R_GetBossHealth(boss) <= damage && FAKE_RepeatTimes[victim] < FAKE_Repeat[victim])
	{
		float chance = GetRandomFloat(0.0, 100.0);
		if (chance <= FAKE_Chance[victim])
		{
			damage = 0.0;
			FF2R_SetBossHealth(boss, 1);
			FakeDeath_Invoke(victim);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public void FakeDeath_Invoke(int client)
{
	if (FAKE_BlockAttack[client])
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 1000000.0);

	SDKHook(client, SDKHook_PreThink, OnPreThink);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	// Drop fake ragdoll
	int ragdoll = CreateEntityByName("tf_ragdoll");
	if (ragdoll != -1)
	{
		float pos[3];
		GetClientAbsOrigin(client, pos);
		TeleportEntity(ragdoll, pos, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
		DispatchSpawn(ragdoll);
		CreateTimer(20.0, Timer_RemoveRagdoll, ragdoll);
	}

	// Make boss invisible
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 255, 255, 0);
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);

	CreateTimer(8.2, Timer_FakeDeathEnd, GetClientUserId(client));
}

public Action Timer_FakeDeathEnd(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	SetEntityRenderMode(client, RENDER_NORMAL);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);

	int boss = FF2R_GetBossIndex(client);
	if (boss != -1)
	{
		int health = ParseFormula(boss, FAKE_Health[client], FF2R_GetBossMaxHealth(boss), GetClientCount(true));
		FF2R_SetBossMaxHealth(boss, health);
		FF2R_SetBossHealth(boss, health);
	}

	FAKE_RepeatTimes[client]++;
	return Plugin_Stop;
}

public Action OnPreThink(int client)
{
	if (FAKE_Speed[client] != -1)
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", FAKE_Speed[client]);

	TF2_RemoveCondition(client, TFCond_OnFire);
	TF2_RemoveCondition(client, TFCond_Bleeding);
	TF2_RemoveCondition(client, TFCond_Jarated);
	TF2_RemoveCondition(client, TFCond_Milked);
	TF2_RemoveCondition(client, TFCond_MarkedForDeath);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	damage = 0.0;
	return Plugin_Changed;
}

public Action Timer_RemoveRagdoll(Handle timer, int ragdoll)
{
	if (IsValidEntity(ragdoll))
		AcceptEntityInput(ragdoll, "Kill");
	return Plugin_Stop;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client))
		FAKE_RepeatTimes[client] = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			SDKUnhook(i, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
			SDKUnhook(i, SDKHook_PreThink, OnPreThink);
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client))))
		return false;
	return true;
}

stock int ParseFormula(int boss, const char[] formula, int defaultValue, int playerCount)
{
	return defaultValue;
}

native int FF2R_GetBossIndex(int client);
native int FF2R_GetBossHealth(int boss);
native void FF2R_SetBossHealth(int boss, int health);
native int FF2R_GetBossMaxHealth(int boss);
native void FF2R_SetBossMaxHealth(int boss, int health);