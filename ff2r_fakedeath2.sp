
/*
"fake_death"
{
    "repeat"            "1"        // How many times can the boss fake death
    "chance"            "100.0"    // Chance to trigger fake death (0-100)
    "health_formula"    "500*n"    // Health formula after reviving
    "sound_section"     ""         // Sound to play when faking death
    "speed"             "340.0"    // Movement speed during fake death (-1 to disable)
    "block_attack"      "0"        // Block attacks during fake death (1 = yes, 0 = no)
    "auto_trigger"      "0"        // Automatically trigger at specific health (0 = disable, >0 = health threshold)
    
    "plugin_name"       "ff2r_fakedeath2"
}	
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <cfgmap>
#include <ff2r>

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Fake Death"
#define PLUGIN_AUTHOR   "J0BL3SS"
#define PLUGIN_DESC     "Pre-nerf Dead Ringer effect for bosses"

#define MAJOR_REVISION  "1"
#define MINOR_REVISION  "3"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION  MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS   MAXPLAYERS+1
#define FAKE_DEATH      "fake_death"

// Configuration variables
int FAKE_Repeat[MAXTF2PLAYERS];
float FAKE_Chance[MAXTF2PLAYERS];
char FAKE_Health[MAXTF2PLAYERS][1024];
char FAKE_SoundSection[MAXTF2PLAYERS][256];
float FAKE_Speed[MAXTF2PLAYERS];
bool FAKE_BlockAttack[MAXTF2PLAYERS];
int FAKE_AutoTrigger[MAXTF2PLAYERS];

// Internal variables
int FAKE_RepeatTimes[MAXTF2PLAYERS];
char DamageList[MAXTF2PLAYERS][768];
Handle FakeHud, FakeHud2;
int LastHealth[MAXTF2PLAYERS];

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
};

public void OnPluginStart()
{
    HookEvent("arena_round_start", Event_RoundStart);
    HookEvent("teamplay_round_active", Event_RoundStart);
    
    FakeHud = CreateHudSynchronizer();
    FakeHud2 = CreateHudSynchronizer();
    
    PrecacheSound("*/saxton_hale/9000.wav", true);
    
    CreateTimer(0.1, Timer_CheckHealth, _, TIMER_REPEAT);
}

public Action Timer_CheckHealth(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && FAKE_AutoTrigger[client] > 0)
        {
            BossData boss = FF2R_GetBossData(client);
            if (boss && boss.GetAbility(FAKE_DEATH).IsMyPlugin())
            {
                int currentHealth = GetClientHealth(client);
                
                if (LastHealth[client] > FAKE_AutoTrigger[client] && currentHealth <= FAKE_AutoTrigger[client] && 
                    currentHealth > 0 && FAKE_Repeat[client] > FAKE_RepeatTimes[client])
                {
                    SetEntityHealth(client, 1);
                    FakeDeath_Invoke(client);
                }
                LastHealth[client] = currentHealth;
            }
        }
    }
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client))
        {
            ClearEverything(client);
            LastHealth[client] = 0;
        }
    }
}

public void OnPluginEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            ClearEverything(i);
        }
    }
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup)
{
    if (!setup)
    {
        ClearEverything(client);
        HookAbilities(client, cfg);
        LastHealth[client] = cfg.GetInt("max_health");
    }
}

public void FF2R_OnBossRemoved(int client)
{
    ClearEverything(client);
    LastHealth[client] = 0;
}

public void ClearEverything(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, FakeDeath_NoDamage);
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
    SDKUnhook(client, SDKHook_PreThink, FAKE_Prethink);
    
    FAKE_RepeatTimes[client] = 0;
}

public void HookAbilities(int client, BossData cfg)
{
    if (cfg.GetAbility(FAKE_DEATH).IsMyPlugin())
    {
        FAKE_Repeat[client] = cfg.GetAbility(FAKE_DEATH).GetInt("repeat", 1);
        FAKE_Chance[client] = cfg.GetAbility(FAKE_DEATH).GetFloat("chance", 100.0);
        cfg.GetAbility(FAKE_DEATH).GetString("health_formula", FAKE_Health[client], sizeof(FAKE_Health[]));
        cfg.GetAbility(FAKE_DEATH).GetString("sound_section", FAKE_SoundSection[client], sizeof(FAKE_SoundSection[]));
        FAKE_Speed[client] = cfg.GetAbility(FAKE_DEATH).GetFloat("speed", 340.0);
        FAKE_BlockAttack[client] = cfg.GetAbility(FAKE_DEATH).GetBool("block_attack", false);
        FAKE_AutoTrigger[client] = cfg.GetAbility(FAKE_DEATH).GetInt("auto_trigger", 0);
        
        if (cfg.GetInt("lives", 1) == 1)
        {
            SDKHook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
        }
    }
}

public void FF2R_OnLivesChanged(int client, int newLives)
{
    BossData boss = FF2R_GetBossData(client);
    if (boss && boss.GetAbility(FAKE_DEATH).IsMyPlugin())
    {
        if (newLives == 1)
        {
            SDKHook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
        }
        else
        {
            SDKUnhook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
        }
    }
}

public Action HealthCheck_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (IsValidClient(victim))
    {
        BossData boss = FF2R_GetBossData(victim);
        if (boss && boss.GetAbility(FAKE_DEATH).IsMyPlugin())
        {
            int lives = boss.GetInt("lives", 1);
            int health = GetClientHealth(victim);
            
            // Auto trigger check
            if (FAKE_AutoTrigger[victim] > 0 && health <= FAKE_AutoTrigger[victim] && health > 1)
            {
                if (FAKE_Repeat[victim] > FAKE_RepeatTimes[victim])
                {
                    damage = 0.0;
                    SetEntityHealth(victim, 1);
                    FakeDeath_Invoke(victim);
                    return Plugin_Changed;
                }
            }
            
            // Original death check
            if (lives == 1 && health - damage <= 0)
            {
                int Chance = GetRandomInt(0, 100);
                
                if (Chance <= FAKE_Chance[victim] && (FAKE_Repeat[victim] > FAKE_RepeatTimes[victim]))
                {
                    damage = 0.0;
                    SetEntityHealth(victim, 1);
                    FakeDeath_Invoke(victim);
                    return Plugin_Changed;
                }
            }
        }
    }
    return Plugin_Continue;
}

public void FAKE_Prethink(int client)
{
    if (FAKE_Speed[client] != -1)
        SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", FAKE_Speed[client]);
        
    if (TF2_IsPlayerInCondition(client, TFCond_Dazed))
        TF2_RemoveCondition(client, TFCond_Dazed);
            
    if (TF2_IsPlayerInCondition(client, TFCond_OnFire))
        TF2_RemoveCondition(client, TFCond_OnFire);
    
    if (TF2_IsPlayerInCondition(client, TFCond_Bleeding))
        TF2_RemoveCondition(client, TFCond_Bleeding);
    
    if (TF2_IsPlayerInCondition(client, TFCond_Jarated))
        TF2_RemoveCondition(client, TFCond_Jarated);
        
    if (TF2_IsPlayerInCondition(client, TFCond_Milked))
        TF2_RemoveCondition(client, TFCond_Milked);
        
    if (TF2_IsPlayerInCondition(client, TFCond_Gas))
        TF2_RemoveCondition(client, TFCond_Gas);
        
    if (TF2_IsPlayerInCondition(client, TFCond_MarkedForDeath))
        TF2_RemoveCondition(client, TFCond_MarkedForDeath);

    if (TF2_IsPlayerInCondition(client, TFCond_MarkedForDeathSilent))
        TF2_RemoveCondition(client, TFCond_MarkedForDeathSilent);
            
    if (GetEntProp(client, Prop_Send, "m_bGlowEnabled"))
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
}

public void FakeDeath_Invoke(int client)
{
    if (FAKE_BlockAttack[client])
    {
        SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 1000000.0);
    }
    
    SDKHook(client, SDKHook_PreThink, FAKE_Prethink);
    SDKHook(client, SDKHook_OnTakeDamage, FakeDeath_NoDamage);
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
    
    if (GetAliveTeamCount(GetClientTeam(client)) <= 1) 
    {
        for (int p = 1; p <= MaxClients; p++)
        {
            DamageList[p][0] = '\0';
        }
        
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidClient(i))
            {
                int damage = GetRandomInt(1000, 5000);
                if (damage >= 9000)
                {
                    EmitSoundToAll("*/saxton_hale/9000.wav");
                    EmitSoundToAll("*/saxton_hale/9000.wav");
                }
                Format(DamageList[i], 768, "%i-%N", damage, i);
            }
        }
    
        SortStrings(DamageList, MAXTF2PLAYERS, Sort_Descending);    
        
        char HUDStatus[768];    
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidClient(i))
            {
                SetHudTextParams(-1.0, 0.39, 6.25, 255, 255, 255, 255);
                Format(HUDStatus, sizeof(HUDStatus), "Most damage dealt by:\n1) %s \n2) %s \n3) %s",
                DamageList[0], DamageList[1], DamageList[2]);
                
                ShowSyncHudText(i, FakeHud, HUDStatus);
                
                SetHudTextParams(-1.0, 0.63, 6.25, 255, 255, 255, 255);
                Format(HUDStatus, sizeof(HUDStatus), "You dealt %i damage in this round\nYou earned %i points in this round", 
                GetRandomInt(1000, 5000), GetRandomInt(1, 10));
                ShowSyncHudText(i, FakeHud2, HUDStatus);
                
                if (i != client)
                    TF2_AddCondition(i, view_as<TFCond>(38), 8.0);        
            }
        }
    }
    
    if (FAKE_SoundSection[client][0] != '\0')
    {
        EmitSoundToAll(FAKE_SoundSection[client]);
        EmitSoundToAll(FAKE_SoundSection[client]);
    }

    // Create ragdoll
    int ragdoll = CreateRagdoll(client);
    if (ragdoll != -1)
    {
        CreateTimer(20.0, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll));
    }
    
    // Full invisibility and invulnerability
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 255, 255, 255, 0);
    SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
    SetEntProp(client, Prop_Send, "m_CollisionGroup", 2);
    TF2_AddCondition(client, TFCond_Stealthed, 8.2);
    TF2_AddCondition(client, TFCond_UberchargedHidden, 8.2);
    
    CreateTimer(8.2, FakeDeath_Fix, client, TIMER_FLAG_NO_MAPCHANGE);
}

int CreateRagdoll(int client)
{
    int ragdoll = CreateEntityByName("tf_ragdoll");
    if (ragdoll != -1 && IsValidEntity(ragdoll))
    {
        float origin[3], angles[3], velocity[3];
        GetClientAbsOrigin(client, origin);
        GetClientAbsAngles(client, angles);
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
        
        TeleportEntity(ragdoll, origin, angles, velocity);
        
        SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
        SetEntProp(ragdoll, Prop_Send, "m_bIceRagdoll", 1);
        SetEntProp(ragdoll, Prop_Send, "m_iTeam", GetClientTeam(client));
        SetEntProp(ragdoll, Prop_Send, "m_iClass", _:TF2_GetPlayerClass(client));
        SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", velocity);
        
        DispatchSpawn(ragdoll);
        
        SetEntProp(ragdoll, Prop_Send, "m_nForceBone", 1);
        SetEntPropFloat(ragdoll, Prop_Send, "m_flHeadScale", 1.0);
        
        return ragdoll;
    }
    return -1;
}

public Action Timer_RemoveRagdoll(Handle timer, any ragdollRef)
{
    int ragdoll = EntRefToEntIndex(ragdollRef);
    if (ragdoll != INVALID_ENT_REFERENCE && IsValidEntity(ragdoll))
    {
        AcceptEntityInput(ragdoll, "Kill");
    }
}

public Action FakeDeath_Fix(Handle timer, int client)
{
    if (IsValidClient(client))
    {
        BossData boss = FF2R_GetBossData(client);
        if (boss && boss.GetAbility(FAKE_DEATH).IsMyPlugin())
        {
            SDKUnhook(client, SDKHook_PreThink, FAKE_Prethink);
            
            int health = ParseFormula(client, FAKE_Health[client], boss.GetInt("max_health"), GetTotalPlayerCount());
            health = (health <= 0) ? 1 : health;
            
            boss.SetInt("max_health", health);
            SetEntityHealth(client, health);
            
            SDKUnhook(client, SDKHook_OnTakeDamage, FakeDeath_NoDamage);
            
            // Restore visibility and collision
            SetEntityRenderMode(client, RENDER_NORMAL);
            SetEntityRenderColor(client, 255, 255, 255, 255);
            SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
            SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);
            TF2_RemoveCondition(client, TFCond_Stealthed);
            TF2_RemoveCondition(client, TFCond_UberchargedHidden);
            
            SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 1.0);
            
            FAKE_RepeatTimes[client]++;
            
            if (FAKE_Repeat[client] > FAKE_RepeatTimes[client])
            {
                SDKHook(client, SDKHook_OnTakeDamageAlive, HealthCheck_OnTakeDamageAlive);
            }
        }
    }
    return Plugin_Continue;
}

public Action FakeDeath_NoDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    damage = 0.0;
    return Plugin_Changed;
}

public int ParseFormula(int client, const char[] key, int defaultValue, int playing)
{
    char formula[1024];
    strcopy(formula, sizeof(formula), key);
    
    ReplaceString(formula, sizeof(formula), "{health}", "", false);
    ReplaceString(formula, sizeof(formula), "{players}", "", false);
    
    float result = float(defaultValue);
    if (strlen(formula) > 0)
    {
        result = StringToFloat(formula);
    }
    
    return RoundFloat(result);
}

stock int GetAliveTeamCount(int team)
{
    int number = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) 
            number++;
    }
    return number;
}

stock int GetTotalPlayerCount()
{
    int total;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            total++;
        }
    }
    return total;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client) || !IsClientConnected(client))
        return false;

    if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
        return false;

    if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
        return false;

    return true;
}