/*

"rage_projectile_0"
{
    "projectile"        "tf_projectile_rocket"  // Projectile type (e.g., rocket)  
    "velocity"          "1100.0"                // Projectile speed  
    "min_damage"        "50"                    // Minimum damage  
    "max_damage"        "100"                   // Maximum damage  
    "model"             "models/weapons/w_models/w_rocket.mdl"  // Projectile model  
    "crit"              "-1"                    // Critical hits (-1 = random, 1 = always, 0 = never)  
    
    "plugin_name"       "ff2r_castprojectile"   
}
"rage_projectile_1"
{
    "projectile"        "tf_projectile_arrow"   // Projectile type (e.g., arrow)  
    "velocity"          "1500.0"                // Projectile speed  
    "min_damage"        "75"                    // Minimum damage  
    "max_damage"        "125"                   // Maximum damage  
    "model"             "models/weapons/w_models/w_arrow.mdl"  // Projectile model  
    "crit"              "1"                     // Always critical hits  
    
    "plugin_name"       "ff2r_castprojectile"   
}

"rage_projectile_2"
{
    "projectile"        "tf_projectile_pipe"    // Projectile type (e.g., grenade)  
    "velocity"          "900.0"                 // Projectile speed  
    "min_damage"        "30"                    // Minimum damage  
    "max_damage"        "60"                    // Maximum damage  
    "model"             "models/weapons/w_models/w_grenade.mdl"  // Projectile model  
    "crit"              "0"                     // Never critical hits  
    
    "plugin_name"       "ff2r_castprojectile"  
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

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Cast Projectile"
#define PLUGIN_AUTHOR 	"J0BL3SS"  // Update Haunted Bone for FF2R
#define PLUGIN_DESC 	"Rage projectile ability with various settings"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"2"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS	MAXPLAYERS + 1

enum Operators
{
    Operator_None = 0,
    Operator_Add,
    Operator_Subtract,
    Operator_Multiply,
    Operator_Divide,
    Operator_Exponent,
};

bool AMS_PRJ[10][MAXTF2PLAYERS];				
char PRJ_EntityName[10][768];					
float PRJ_Velocity[10][MAXTF2PLAYERS];			
char PRJ_MinDamage[10][MAXTF2PLAYERS][1024]; 	
char PRJ_MaxDamage[10][MAXTF2PLAYERS][1024];	
char PRJ_NewModel[10][PLATFORM_MAX_PATH];		
int PRJ_Crit[10][MAXTF2PLAYERS];				

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
}

public void OnPluginEnd()
{
	for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if (IsValidClient(clientIdx))
		{
			FF2R_OnBossRemoved(clientIdx);
		}
	}
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	for (int Num = 0; Num < 10; Num++)
	{
		AMS_PRJ[Num][clientIdx] = false;
	}
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
	if (!setup)
	{
		char AbilityName[96];
		for (int Num = 0; Num < 10; Num++)
		{
			Format(AbilityName, sizeof(AbilityName), "rage_projectile_%i", Num);
			if (cfg.GetAbility(AbilityName).IsMyPlugin())
			{
				AMS_PRJ[Num][clientIdx] = true;
			}
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(clientIdx) && FF2R_GetBossData(clientIdx))
	{
		CreateTimer(0.3, Timer_PrepareHooks, GetClientUserId(clientIdx), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_PrepareHooks(Handle timer, int userid)
{
	int clientIdx = GetClientOfUserId(userid);
	if (IsValidClient(clientIdx) && FF2R_GetBossData(clientIdx))
	{
		HookAbilities(clientIdx);
	}
	return Plugin_Continue;
}

public void HookAbilities(int clientIdx)
{
	char AbilityName[96], AbilityShort[96];
	for (int Num = 0; Num < 10; Num++)
	{
		Format(AbilityName, sizeof(AbilityName), "rage_projectile_%i", Num);
		if (FF2R_GetBossData(clientIdx).GetAbility(AbilityName).IsMyPlugin())
		{
			AMS_PRJ[Num][clientIdx] = true;
			Format(AbilityShort, sizeof(AbilityShort), "PRJ%i", Num);
		}
	}
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if (!cfg.IsMyPlugin())
		return;

	for (int Num = 0; Num < 10; Num++)
	{
		char AbilityName[96];
		Format(AbilityName, sizeof(AbilityName), "rage_projectile_%i", Num);
		if (StrEqual(ability, AbilityName))
		{
			if (AMS_PRJ[Num][clientIdx])
			{
				CastSpell(clientIdx, ability, Num);
			}
		}
	}
}

public void CastSpell(int clientIdx, const char[] ability_name, int Num)
{
	BossData cfg = FF2R_GetBossData(clientIdx);
	cfg.GetAbility(ability_name).GetString("projectile", PRJ_EntityName[Num], sizeof(PRJ_EntityName[]));
	PRJ_Velocity[Num][clientIdx] = cfg.GetAbility(ability_name).GetFloat("velocity", 1100.0);
	cfg.GetAbility(ability_name).GetString("min_damage", PRJ_MinDamage[Num][clientIdx], sizeof(PRJ_MinDamage[]));
	cfg.GetAbility(ability_name).GetString("max_damage", PRJ_MaxDamage[Num][clientIdx], sizeof(PRJ_MaxDamage[]));
	cfg.GetAbility(ability_name).GetString("model", PRJ_NewModel[Num], sizeof(PRJ_NewModel[]));
	PRJ_Crit[Num][clientIdx] = cfg.GetAbility(ability_name).GetInt("crit", -1);

	float flAng[3], flPos[3];
	GetClientEyeAngles(clientIdx, flAng);
	GetClientEyePosition(clientIdx, flPos);

	int iTeam = GetClientTeam(clientIdx);
	int iProjectile = CreateEntityByName(PRJ_EntityName[Num]);

	float flVel1[3], flVel2[3];
	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);

	flVel1[0] = flVel2[0] * PRJ_Velocity[Num][clientIdx];
	flVel1[1] = flVel2[1] * PRJ_Velocity[Num][clientIdx];
	flVel1[2] = flVel2[2] * PRJ_Velocity[Num][clientIdx];

	SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", clientIdx);
	if (!IsProjectileTypeSpell(PRJ_EntityName[Num]))
	{
		SetEntDataFloat(iProjectile, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4,
		GetRandomFloat(float(ParseFormula(cfg, PRJ_MinDamage[Num][clientIdx], 30, GetTotalPlayerCount())), 
		float(ParseFormula(cfg, PRJ_MaxDamage[Num][clientIdx], 110, GetTotalPlayerCount()))), true);

		int CritValue;
		if (PRJ_Crit[Num][clientIdx] == 1) CritValue = 1;
		else if (PRJ_Crit[Num][clientIdx] == 0) CritValue = 0;
		else CritValue = (GetRandomInt(0, 100) <= 3 ? 1 : 0);

		SetEntProp(iProjectile, Prop_Send, "m_bCritical", CritValue, 1);
	}
	SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iProjectile, Prop_Send, "m_nSkin", (iTeam - 2));

	if (!IsModelPrecached(PRJ_NewModel[Num]))
	{
		if (FileExists(PRJ_NewModel[Num], true))
		{
			PrecacheModel(PRJ_NewModel[Num]);
		}
		else
		{
			return;
		}
	}
	SetEntityModel(iProjectile, PRJ_NewModel[Num]);

	TeleportEntity(iProjectile, flPos, flAng, NULL_VECTOR);

	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "SetTeam", -1, -1, 0);

	DispatchSpawn(iProjectile);
	TeleportEntity(iProjectile, NULL_VECTOR, NULL_VECTOR, flVel1);
}

stock bool IsValidClient(int clientIdx, bool replaycheck = true)
{
	if (clientIdx <= 0 || clientIdx > MaxClients)
		return false;
	if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
		return false;
	if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
		return false;
	return true;
}

stock bool IsProjectileTypeSpell(const char[] entity_name)
{
	if (StrContains(entity_name, "tf_projectile_spell", false) != -1 || StrEqual(entity_name, "tf_projectile_lightningorb"))
		return true;
	return false;
}

public int ParseFormula(BossData cfg, const char[] key, int defaultValue, int playing)
{
    char formula[1024], bossName[64];
    cfg.GetString("name", bossName, sizeof(bossName), "Unknown Boss");

    strcopy(formula, sizeof(formula), key);
    int size = 1;
    int matchingBrackets;
    for (int i = 0; i <= strlen(formula); i++)
    {
        if (formula[i] == '(')
        {
            if (!matchingBrackets)
            {
                size++;
            }
            else
            {
                matchingBrackets--;
            }
        }
        else if (formula[i] == ')')
        {
            matchingBrackets++;
        }
    }

    ArrayList sumArray = CreateArray(_, size), _operator = CreateArray(_, size);
    int bracket = 0;
    sumArray.Set(0, 0.0);
    _operator.Set(bracket, Operator_None);

    char character[2], value[16];
    for (int i = 0; i <= strlen(formula); i++)
    {
        character[0] = formula[i];
        switch (character[0])
        {
            case ' ', '\t':
            {
                continue;
            }
            case '(':
            {
                bracket++;
                sumArray.Set(bracket, 0.0);
                _operator.Set(bracket, Operator_None);
            }
            case ')':
            {
                OperateString(sumArray, bracket, value, sizeof(value), _operator);
                if (_operator.Get(bracket) != Operator_None)
                {
                    delete sumArray;
                    delete _operator;
                    return defaultValue;
                }

                if (--bracket < 0)
                {
                    delete sumArray;
                    delete _operator;
                    return defaultValue;
                }

                Operate(sumArray, bracket, sumArray.Get(bracket + 1), _operator);
            }
            case '\0':
            {
                OperateString(sumArray, bracket, value, sizeof(value), _operator);
            }
            case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
            {
                StrCat(value, sizeof(value), character);
            }
            case 'n', 'x':
            {
                Operate(sumArray, bracket, float(playing), _operator);
            }
            case '+', '-', '*', '/', '^':
            {
                OperateString(sumArray, bracket, value, sizeof(value), _operator);
                switch (character[0])
                {
                    case '+': _operator.Set(bracket, Operator_Add);
                    case '-': _operator.Set(bracket, Operator_Subtract);
                    case '*': _operator.Set(bracket, Operator_Multiply);
                    case '/': _operator.Set(bracket, Operator_Divide);
                    case '^': _operator.Set(bracket, Operator_Exponent);
                }
            }
        }
    }

    float result = sumArray.Get(0);
    delete sumArray;
    delete _operator;
    if (result <= 0)
    {
        return defaultValue;
    }
    return RoundFloat(result);
}

stock void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if (!StrEqual(value, ""))
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

stock void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
{
	float sum = sumArray.Get(bracket);
	switch (_operator.Get(bracket))
	{
		case Operator_Add: sumArray.Set(bracket, sum + value);
		case Operator_Subtract: sumArray.Set(bracket, sum - value);
		case Operator_Multiply: sumArray.Set(bracket, sum * value);
		case Operator_Divide:
		{
			if (!value)
			{
				bracket = 0;
				return;
			}
			sumArray.Set(bracket, sum / value);
		}
		case Operator_Exponent: sumArray.Set(bracket, Pow(sum, value));
		default: sumArray.Set(bracket, value);
	}
	_operator.Set(bracket, Operator_None);
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