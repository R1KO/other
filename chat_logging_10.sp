//------------------------------------------------------------------------------
// GPL LISENCE (short)
//------------------------------------------------------------------------------
/*
 * Copyright (c) 2014 R1KO

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 * ChangeLog:
		1.0	- 	Релиз
*/

#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

new Handle:g_hDatabase,
	String:g_sTable[20];

new bool:g_bIsLog[10];
new String:sSay[9][] = {"say", "say_team", "sm_say", "sm_chat", "sm_csay", "sm_tsay", "sm_msay", "sm_hsay", "sm_psay"};

new Handle:g_hDataTrie[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Chat Logging",
	author = "R1KO",
	version = "1.0"
}

public OnPluginStart()
{
	for(new i=1; i <= 64; i++) g_hDataTrie[i] = CreateTrie();

	new Handle:hCvar;

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_table", "chatlog", "Таблица логов чата в базе данных", FCVAR_PLUGIN)), OnTableChange);
	GetConVarString(hCvar, g_sTable, sizeof(g_sTable));

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_triggers", "0", "Запись в лог чат-триггеров", FCVAR_PLUGIN)), OnLogTriggersChange);
	g_bIsLog[9] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_say", "1", "Запись в лог общего чата", FCVAR_PLUGIN)), OnLogSayChange);
	g_bIsLog[0] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_say_team", "1", "Запись в лог командного чата", FCVAR_PLUGIN)), OnLogSayTeamChange);
	g_bIsLog[1] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_sm_say", "1", "Запись в лог команды sm_say", FCVAR_PLUGIN)), OnLogSmSayChange);
	g_bIsLog[2] = GetConVarBool(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_chat_log_chat", "1", "Запись в лог команды sm_chat", FCVAR_PLUGIN)), OnLogChatChange);
	g_bIsLog[3] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_csay", "1", "Запись в лог команды sm_csay", FCVAR_PLUGIN)), OnLogCSayChange);
	g_bIsLog[4] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_tsay", "1", "Запись в лог команды sm_tsay", FCVAR_PLUGIN)), OnLogTSayChange);
	g_bIsLog[5] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_msay", "1", "Запись в лог команды sm_msay", FCVAR_PLUGIN)), OnLogMSayChange);
	g_bIsLog[6] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_hsay", "1", "Запись в лог команды sm_hsay", FCVAR_PLUGIN)), OnLogHSayChange);
	g_bIsLog[7] = GetConVarBool(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_psay", "1", "Запись в лог команды sm_psay", FCVAR_PLUGIN)), OnLogPSayChange);
	g_bIsLog[8] = GetConVarBool(hCvar);

	AutoExecConfig(true, "chat_log");

	CloseHandle(hCvar);

	for(new i=0; i < 9; i++) AddCommandListener(Say_Callback, sSay[i]);
	
	HookEvent("player_changename", Event_NameChange);
}

public OnTableChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(hCvar, g_sTable, sizeof(g_sTable));
	OnConfigsExecuted();
}

public OnLogTriggersChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[9] = GetConVarBool(hCvar);
public OnLogSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[0] = GetConVarBool(hCvar);
public OnLogSayTeamChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[1] = GetConVarBool(hCvar);
public OnLogSmSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[2] = GetConVarBool(hCvar);
public OnLogChatChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[3] = GetConVarBool(hCvar);
public OnLogCSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[4] = GetConVarBool(hCvar);
public OnLogTSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[5] = GetConVarBool(hCvar);
public OnLogMSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[6] = GetConVarBool(hCvar);
public OnLogHSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[7] = GetConVarBool(hCvar);
public OnLogPSayChange(Handle:hCvar, const String:oldValue[], const String:newValue[]) g_bIsLog[8] = GetConVarBool(hCvar);

public Action:Say_Callback(iClient, const String:sCommand[], args)
{
	if(iClient)
	{
		decl String:sText[255];
		GetCmdArgString(sText, sizeof(sText));
		if((IsChatTrigger() && g_bIsLog[9]) || !IsChatTrigger())
		{
			for(new i=0; i < 9; i++)
			{
				if(StrEqual(sCommand, sSay[i], false) && g_bIsLog[i])
				{
					decl String:sQuery[1024], String:sName[150], String:sAuth[2][150], String:sMsg[511];
					GetTrieString(g_hDataTrie[iClient], "auth", sAuth[0], sizeof(sAuth[]));
					GetTrieString(g_hDataTrie[iClient], "ip", sAuth[1], sizeof(sAuth[]));
					GetTrieString(g_hDataTrie[iClient], "name", sName, sizeof(sName));
					TrimString(sText);
					StripQuotes(sText);
					SQL_EscapeString(g_hDatabase, sText, sMsg, sizeof(sMsg));
					
					FormatEx(sQuery, sizeof(sQuery) - 1, "INSERT INTO `%s` (`auth`, `ip`, `name`, `team`, `alive`, `timestamp`, `type`, `message`) VALUES ('%s', '%s', '%s', '%d', '%d', '%d', '%s', '%s');", g_sTable, sAuth[0], sAuth[1], sName, GetClientTeam(iClient), IsPlayerAlive(iClient) ? 1:0, GetTime(), sCommand, sMsg);
					SQL_TQuery(g_hDatabase, SQL_CheckError, sQuery);
					break;
				}
			}
		}
	}
}

public SQL_CheckError(Handle:owner, Handle:hndle, const String:sError[], any:data)
{
	if(sError[0]) LogError("[Chat log] Query Failed: %s", sError);
}

public OnConfigsExecuted()
{
	if(g_hDatabase != INVALID_HANDLE) CloseHandle(g_hDatabase);
	if(!SQL_CheckConfig("chatlog")) SetFailState("Database failure: Could not find Database conf \"chatlog\"");
	SQL_TConnect(SQL_OnConnect, "chatlog");
	decl String:sError[512];
	g_hDatabase = SQL_Connect("chatlog", false, sError, sizeof(sError));
	if(g_hDatabase == INVALID_HANDLE) SetFailState("[Chat log] Не удалось подключиться к базе данных (%s)", sError);

	
}

public SQL_OnConnect(Handle:owner, Handle:hndl, const String:sError[], any:data)
{
	if (hndl == INVALID_HANDLE) SetFailState("[Chat log] Не удалось подключиться к базе данных (%s)", sError);
	else
	{
		g_hDatabase = hndl;

		decl String:sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "SET NAMES \"UTF8\"");
		SQL_TQuery(g_hDatabase, SQL_CheckError, sQuery);
		
		SQL_LockDatabase(g_hDatabase);
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`msg_id` MEDIUMINT UNSIGNED NOT NULL auto_increment PRIMARY KEY, `auth` VARCHAR(65) NOT NULL, `ip` VARCHAR(65) NOT NULL, `name` VARCHAR(65) NOT NULL, `team` INT (1) NOT NULL, `alive` INT (1) NOT NULL, `timestamp` INT UNSIGNED NOT NULL, `message` VARCHAR(255) NOT NULL, `type` VARCHAR(20) NOT NULL) ENGINE = MyISAM CHARACTER SET utf8 COLLATE utf8_general_ci;", g_sTable);
		SQL_FastQuery(g_hDatabase, sQuery);
		SQL_FastQuery(g_hDatabase, "SET NAMES 'utf8'");
		SQL_FastQuery(g_hDatabase, "SET CHARSET 'utf8'");
		SQL_UnlockDatabase(g_hDatabase);
	}
}

public OnClientPostAdminCheck(iClient)
{
	if(iClient)
	{
		ClearTrie(g_hDataTrie[iClient]);
		if(!IsFakeClient(iClient))
		{
			decl String:sBuffer[64], String:sBuffer2[150];
			GetClientAuthString(iClient, sBuffer, sizeof(sBuffer)-1);
			SetTrieString(g_hDataTrie[iClient], "auth", sBuffer);
			GetClientIP(iClient, sBuffer, sizeof(sBuffer)-1);
			SetTrieString(g_hDataTrie[iClient], "ip", sBuffer);
			GetClientName(iClient, sBuffer, sizeof(sBuffer) - 1);
			SQL_EscapeString(g_hDatabase, sBuffer, sBuffer2, sizeof(sBuffer2)-1);
			SetTrieString(g_hDataTrie[iClient], "name", sBuffer2);
		}
	}
}

public Action:Event_NameChange(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(iClient && !IsFakeClient(iClient))
	{
		decl String:sNewName[MAX_NAME_LENGTH], String:sBuffer[150];
		GetEventString(event, "newname", sNewName, sizeof(sNewName));
		SQL_EscapeString(g_hDatabase, sNewName, sBuffer, sizeof(sBuffer)-1);
		SetTrieString(g_hDataTrie[iClient], "name", sBuffer);
	}
	return Plugin_Continue;
}
