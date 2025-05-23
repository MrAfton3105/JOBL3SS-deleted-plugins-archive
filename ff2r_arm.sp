/*
	"rage_custom_arms"
	{
		"arm_model"	"models/weapons/c_models/c_scout_arms.mdl"

		"plugin_name"	"ff2r_arm"
	}
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2 Rewrite: Custom Arm Animations"
#define PLUGIN_AUTHOR 	"Sandy"
#define PLUGIN_DESC 	"FF2R Subplugin to allow bosses to give custom arms"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS	MAXPLAYERS+1

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

public void OnPluginStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

public Action OnWeaponEquip(int client, int weapon) {
	if (IsValidEntity(weapon)) {
		BossData boss = FF2R_GetBossData(client);
		if (boss) {
			AbilityData ability = boss.GetAbility("rage_custom_arms");
			if (!ability.IsMyPlugin()) {
				return Plugin_Continue;
			}
			
			char model[PLATFORM_MAX_PATH];
			if (ability.GetString("arm_model", model, sizeof(model)) && FileExists(model, true)) {
				PrecacheModel(model);
				
				SetEntityModel(weapon, model);
				SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));
				SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));
			}
		}
	}
	
	return Plugin_Continue;
}