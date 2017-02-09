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
#if SOURCEMOD_V_MINOR > 6
  #pragma newdecls required
#endif

#if SOURCEMOD_V_MINOR > 6
  Database g_hDatabase;
  char g_sTable[20];
  
  bool g_bIsLog[10];
  char sSay[9][] = {"say", "say_team", "sm_say", "sm_chat", "sm_csay", "sm_tsay", "sm_msay", "sm_hsay", "sm_psay"};
  
  StringMap g_hDataTrie[MAXPLAYERS+1];
  
  public Plugin myinfo = 
#else
  new Handle:g_hDatabase;
  new String:g_sTable[20];
  
  new bool:g_bIsLog[10];
  new String:sSay[9][] = {"say", "say_team", "sm_say", "sm_chat", "sm_csay", "sm_tsay", "sm_msay", "sm_hsay", "sm_psay"};
  
  new Handle:g_hDataTrie[MAXPLAYERS+1];
  
  public Plugin:myinfo = 
#endif
{
	name = "Chat Logging",
	author = "R1KO",
	version = "1.0"
}
#if SOURCEMOD_V_MINOR > 6
  public void OnPluginStart()
#else
  public OnPluginStart()
#endif
{
	#if SOURCEMOD_V_MINOR > 6
	  for(int i=1; i <= 64; i++)
	#else
	  for(new i=1; i <= 64; i++)
	#endif
		g_hDataTrie[i] = CreateTrie();

	#if SOURCEMOD_V_MINOR > 6
	  ConVar hCvar;
	#else
	  new Handle:hCvar;
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_table", "chatlog", "Таблица логов чата в базе данных")), OnTableChange);
	GetConVarString(hCvar, g_sTable, sizeof(g_sTable));
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_triggers", "0", "Запись в лог чат-триггеров")), OnLogTriggersChange);
	g_bIsLog[9] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_say", "1", "Запись в лог общего чата")), OnLogSayChange);
	g_bIsLog[0] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_say_team", "1", "Запись в лог командного чата")), OnLogSayTeamChange);
	g_bIsLog[1] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_sm_say", "1", "Запись в лог команды sm_say")), OnLogSmSayChange);
	g_bIsLog[2] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif
	
	HookConVarChange((hCvar = CreateConVar("sm_chat_log_chat", "1", "Запись в лог команды sm_chat")), OnLogChatChange);
	g_bIsLog[3] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_csay", "1", "Запись в лог команды sm_csay")), OnLogCSayChange);
	g_bIsLog[4] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_tsay", "1", "Запись в лог команды sm_tsay")), OnLogTSayChange);
	g_bIsLog[5] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_msay", "1", "Запись в лог команды sm_msay")), OnLogMSayChange);
	g_bIsLog[6] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_hsay", "1", "Запись в лог команды sm_hsay")), OnLogHSayChange);
	g_bIsLog[7] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	HookConVarChange((hCvar = CreateConVar("sm_chat_log_psay", "1", "Запись в лог команды sm_psay")), OnLogPSayChange);
	g_bIsLog[8] = GetConVarBool(hCvar);
	#if SOURCEMOD_V_MINOR > 6
	  delete hCvar;
	#else
	  CloseHandle(hCvar);
	#endif

	AutoExecConfig(true, "chat_log");

	#if SOURCEMOD_V_MINOR > 6
	  for(int i=0; i < 9; i++)
	#else
	  for(new i=0; i < 9; i++)
	#endif
		AddCommandListener(Say_Callback, sSay[i]);
	
	HookEvent("player_changename", Event_NameChange);
}

#if SOURCEMOD_V_MINOR > 6
  public void OnTableChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
#else
  public OnTableChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
#endif
{
	GetConVarString(hCvar, g_sTable, sizeof(g_sTable));
	OnConfigsExecuted();
}

#if SOURCEMOD_V_MINOR > 6
  public void OnLogTriggersChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[9] = GetConVarBool(hCvar); }
  public void OnLogSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[0] = GetConVarBool(hCvar); }
  public void OnLogSayTeamChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[1] = GetConVarBool(hCvar); }
  public void OnLogSmSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[2] = GetConVarBool(hCvar); }
  public void OnLogChatChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[3] = GetConVarBool(hCvar); }
  public void OnLogCSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[4] = GetConVarBool(hCvar); }
  public void OnLogTSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[5] = GetConVarBool(hCvar); }
  public void OnLogMSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[6] = GetConVarBool(hCvar); }
  public void OnLogHSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[7] = GetConVarBool(hCvar); }
  public void OnLogPSayChange(ConVar hCvar, const char[] oldValue, const char[] newValue) { g_bIsLog[8] = GetConVarBool(hCvar); }
#else
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
#endif

#if SOURCEMOD_V_MINOR > 6
  public Action Say_Callback(int iClient, const char[] sCommand, int args)
#else
  public Action:Say_Callback(iClient, const String:sCommand[], args)
#endif
{
	if(iClient)
	{
		#if SOURCEMOD_V_MINOR > 6
		  char sText[255];
		#else
		  decl String:sText[255];
		#endif
		GetCmdArgString(sText, sizeof(sText));
		if((IsChatTrigger() && g_bIsLog[9]) || !IsChatTrigger())
		{
			#if SOURCEMOD_V_MINOR > 6
			  for(int i=0; i < 9; i++)
			#else
			  for(new i=0; i < 9; i++)
			#endif
			{
				if(StrEqual(sCommand, sSay[i], false) && g_bIsLog[i])
				{
					#if SOURCEMOD_V_MINOR > 6
					  char sQuery[1024], sName[150], sAuth[2][150], sMsg[511];
					#else
					  decl String:sQuery[1024], String:sName[150], String:sAuth[2][150], String:sMsg[511];
					#endif
					GetTrieString(g_hDataTrie[iClient], "auth", sAuth[0], sizeof(sAuth[]));
					GetTrieString(g_hDataTrie[iClient], "ip", sAuth[1], sizeof(sAuth[]));
					GetTrieString(g_hDataTrie[iClient], "name", sName, sizeof(sName));
					TrimString(sText);
					StripQuotes(sText);
					SQL_EscapeString(g_hDatabase, sText, sMsg, sizeof(sMsg));
					
					FormatEx(sQuery, sizeof(sQuery) - 1, "INSERT INTO `%s` (`auth`, `ip`, `name`, `team`, `alive`, `timestamp`, `type`, `message`) VALUES ('%s', '%s', '%s', '%d', '%d', '%d', '%s', '%s');", g_sTable, sAuth[0], sAuth[1], sName, GetClientTeam(iClient), IsPlayerAlive(iClient) ? 1:0, GetTime(), sCommand, sMsg);
					#if SOURCEMOD_V_MINOR > 6
					  g_hDatabase.Query(SQL_CheckError, sQuery);
					#else
					  SQL_TQuery(g_hDatabase, SQL_CheckError, sQuery);
					#endif
					
					break;
				}
			}
		}
	}
}

#if SOURCEMOD_V_MINOR > 6
  public void SQL_CheckError(Database hDB, DBResultSet hResults, const char[] sError, any data)
#else
  public SQL_CheckError(Handle:hDB, Handle:hResults, const String:sError[], any:data)
#endif
{
	if(sError[0]) LogError("[Chat log] Query Failed: %s", sError);
}

#if SOURCEMOD_V_MINOR > 6
  public void OnConfigsExecuted()
#else
  public OnConfigsExecuted()
#endif
{
	#if SOURCEMOD_V_MINOR > 6
	  if(g_hDatabase != null) {
	  	delete g_hDatabase;
	  	g_hDatabase = null;
	  }
	#else
	  if(g_hDatabase != INVALID_HANDLE) {
	  	CloseHandle(g_hDatabase);
	  	g_hDatabase = INVALID_HANDLE;
	  }
	#endif
	
	if(!SQL_CheckConfig("chatlog")) SetFailState("Database failure: Could not find Database conf \"chatlog\"");
	#if SOURCEMOD_V_MINOR > 6
	  Database.Connect(SQL_OnConnect, "chatlog");
	#else
	  SQL_TConnect(SQL_OnConnect, "chatlog");
	#endif
}

#if SOURCEMOD_V_MINOR > 6
  public void SQL_OnConnect(Database hDatabase, const char[] sError, any data)
#else
  public SQL_OnConnect(Handle:hDriver, Handle:hDatabase, const String:sError[], any:data)
#endif
{
#if SOURCEMOD_V_MINOR > 6
	if (hDatabase == null)
#else
	if (hDatabase == INVALID_HANDLE)
#endif
		SetFailState("[Chat log] Не удалось подключиться к базе данных (%s)", sError);
	else
	{
		g_hDatabase = hDatabase;

		SQL_SetCharset(g_hDatabase, "utf8");
		
		SQL_LockDatabase(g_hDatabase);
		
		#if SOURCEMOD_V_MINOR > 6
		  char sQuery[460];
		#else
		  decl String:sQuery[460];
		#endif
		
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`msg_id` MEDIUMINT UNSIGNED NOT NULL auto_increment PRIMARY KEY, `auth` VARCHAR(65) NOT NULL, `ip` VARCHAR(65) NOT NULL, `name` VARCHAR(65) NOT NULL, `team` INT (1) NOT NULL, `alive` INT (1) NOT NULL, `timestamp` INT UNSIGNED NOT NULL, `message` VARCHAR(255) NOT NULL, `type` VARCHAR(20) NOT NULL) ENGINE = MyISAM CHARACTER SET utf8 COLLATE utf8_general_ci;", g_sTable);
		SQL_FastQuery(g_hDatabase, sQuery);
		SQL_FastQuery(g_hDatabase, "SET NAMES 'utf8'");
		SQL_FastQuery(g_hDatabase, "SET CHARSET 'utf8'");
		SQL_UnlockDatabase(g_hDatabase);
	}
}

#if SOURCEMOD_V_MINOR > 6
  public void OnClientPostAdminCheck(int iClient)
#else
  public OnClientPostAdminCheck(iClient)
#endif
{
	if(iClient)
	{
		ClearTrie(g_hDataTrie[iClient]);
		if(!IsFakeClient(iClient))
		{
			#if SOURCEMOD_V_MINOR > 6
			  char sBuffer[64], sBuffer2[150];
			  GetClientAuthId(iClient, AuthId_Steam2, sBuffer, sizeof(sBuffer)-1);
			#else
			  decl String:sBuffer[64], String:sBuffer2[150];
			  GetClientAuthString(iClient, sBuffer, sizeof(sBuffer)-1);
			#endif
			
			SetTrieString(g_hDataTrie[iClient], "auth", sBuffer);
			GetClientIP(iClient, sBuffer, sizeof(sBuffer)-1);
			SetTrieString(g_hDataTrie[iClient], "ip", sBuffer);
			GetClientName(iClient, sBuffer, sizeof(sBuffer) - 1);
			SQL_EscapeString(g_hDatabase, sBuffer, sBuffer2, sizeof(sBuffer2)-1);
			SetTrieString(g_hDataTrie[iClient], "name", sBuffer);
		}
	}
}

#if SOURCEMOD_V_MINOR > 6
  public Action Event_NameChange(Event hEvent, const char[] name, bool dontBroadcast)
#else
  public Action:Event_NameChange(Handle:hEvent, const String:name[], bool:dontBroadcast)
#endif
{
	#if SOURCEMOD_V_MINOR > 6
	  int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	#else
	  new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	#endif
	if(iClient && !IsFakeClient(iClient))
	{
		#if SOURCEMOD_V_MINOR > 6
		  char sNewName[MAX_NAME_LENGTH], sBuffer[150];
		#else
		  decl String:sNewName[MAX_NAME_LENGTH], String:sBuffer[150];
		#endif
		
		GetEventString(hEvent, "newname", sNewName, sizeof(sNewName));
		SQL_EscapeString(g_hDatabase, sNewName, sBuffer, sizeof(sBuffer)-1);
		SetTrieString(g_hDataTrie[iClient], "name", sBuffer);
	}
	return Plugin_Continue;
}
