#include <sourcemod>
#include <adminmenu>
#pragma semicolon 1

#define QUERY_SIZE 256

new Handle:g_hDatabase,
	Handle:hTopMenu,
	String:DatabasePrefix[10] = "sb",
	serverID,
	g_iLimit,
	g_iAdminID[MAXPLAYERS+1],
	String:g_sQuery[MAXPLAYERS+1][QUERY_SIZE];

public Plugin:myinfo = 
{
	name = "Unban Sourcebans",
	author = "R1KO",
	version = "1.0.2 beta"
};

public OnPluginStart()
{
	new Handle:hCvar;
	HookConVarChange((hCvar = CreateConVar("sm_sourcrbans_menu_limit", "20", "Максимальное количество банов в меню")), OnLimitChange);
	g_iLimit = GetConVarInt(hCvar);
	CloseHandle(hCvar);

	new Handle:hPlugin = FindPluginByFile("sourcebans.smx"); 
	if (hPlugin != INVALID_HANDLE)
	{
		if (GetPluginStatus(hPlugin) != Plugin_Running) SetFailState("[Unban Sourcebans] Sourcebans не запущен!");
	}

	decl String:sError[255];
	g_hDatabase = SQL_Connect("sourcebans", false, sError, sizeof(sError));
	if(g_hDatabase == INVALID_HANDLE) SetFailState("[Unban Sourcebans] Unable to connect to database (%s)", sError);
	
	decl String:sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SET NAMES \"UTF8\"");
	SQL_TQuery(g_hDatabase, ErrorCheckCallback, sQuery);

	new Handle:topmenu = GetAdminTopMenu();
	if (topmenu != INVALID_HANDLE) OnAdminMenuReady(topmenu);
}

public ErrorCheckCallback(Handle:owner, Handle:hndle, const String:error[], any:data)
{
	if(error[0]) LogError("[Unban Sourcebans] Query Failed: %s", error);
}

public OnLimitChange(Handle:hCvar, const String:sOld[], const String:sNew[]) g_iLimit = GetConVarInt(hCvar);

public OnConfigsExecuted()
{
	decl String:sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/sourcebans/sourcebans.cfg");
	new Handle:hKV = CreateKeyValues("SourceBans");
	if(FileToKeyValues(hKV, sBuffer))
	{
		KvRewind(hKV);
		if(KvJumpToKey(hKV, "Config", false))
		{
			KvGetString(hKV, "DatabasePrefix", DatabasePrefix, sizeof(DatabasePrefix), "sb");
			if(DatabasePrefix[0] == '\0') DatabasePrefix = "sb";
			serverID = KvGetNum(hKV, "ServerID", -1);
			if(serverID == -1) InsertServerInfo();
		}
	}
	CloseHandle(hKV);
}

stock InsertServerInfo()
{
	if(g_hDatabase == INVALID_HANDLE) return;
	
	decl String:sQuery[QUERY_SIZE],
		String:ServerIp[32];

	new ServerPort = GetConVarInt(FindConVar("hostport")),
		hostip = GetConVarInt(FindConVar("hostip")); 

	FormatEx(ServerIp, sizeof(ServerIp), "%u.%u.%u.%u", (hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF);
	FormatEx(sQuery, sizeof(sQuery), "SELECT `sid` FROM `%s_servers` WHERE `ip` = '%s' AND `port` = '%d';", DatabasePrefix, ServerIp, ServerPort);
	SQL_TQuery(g_hDatabase, ServerInfo_Callback, sQuery);
}

public ServerInfo_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading server (%s)", error);
	else
	{
		if(SQL_FetchRow(hndl)) serverID = SQL_FetchInt(hndl, 0);
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == hTopMenu) return;
	hTopMenu = topmenu;

	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT) AddToTopMenu(hTopMenu, "sm_unban", TopMenuObject_Item, AdminMenu_UnBan, player_commands, "sm_unban", ADMFLAG_UNBAN);
}

public AdminMenu_UnBan(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption) Format(buffer, maxlength, "Разбанить игрока", param);
	else if (action == TopMenuAction_SelectOption)
	{
		decl String:sQuery[QUERY_SIZE], String:sAuth[32];
		GetClientAuthString(param, sAuth, sizeof(sAuth));
		FormatEx(sQuery, sizeof(sQuery), "SELECT `aid`, `gid` FROM `%s_admins` WHERE `authid` = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$';", DatabasePrefix, sAuth, sAuth[8]);
		SQL_TQuery(g_hDatabase, SelectAdminCallback, sQuery, param, DBPrio_High);
	}
}

public SelectAdminCallback(Handle:owner, Handle:hndl, const String:error[], any:iClient)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading admin (%s)", error);
	else
	{
		if(SQL_FetchRow(hndl) && IsClientInGame(iClient))
		{
			g_iAdminID[iClient] = SQL_FetchInt(hndl, 0);
			decl String:sQuery[QUERY_SIZE];
			FormatEx(sQuery, sizeof(sQuery), "SELECT `flags` FROM `%s_groups` WHERE `gid` = '%i';", DatabasePrefix, g_iAdminID[iClient]);
			SQL_TQuery(g_hDatabase, SendQueryCallback, sQuery, iClient, DBPrio_High);
		}
	}
}

public SendQueryCallback(Handle:owner, Handle:hndl, const String:error[], any:iClient)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading flags admin (%s)", error);
	else
	{
		if(SQL_FetchRow(hndl))
		{
			new iFlags = SQL_FetchInt(hndl, 0);

			if(iFlags & (1<<26)) FormatEx(g_sQuery[iClient], sizeof(g_sQuery[]), "SELECT `bid`, `name`, `created` FROM `%s_bans` WHERE `sid` = '%i' AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL ORDER BY `created` DESC LIMIT %d;", DatabasePrefix, serverID, g_iLimit);
			else if(iFlags & (1<<30)) FormatEx(g_sQuery[iClient], sizeof(g_sQuery[]), "SELECT `bid`, `name`, `created` FROM `%s_bans` WHERE `aid` = '%i' AND `sid` = '%i' AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL ORDER BY `created` DESC LIMIT %d;", DatabasePrefix, g_iAdminID[iClient], serverID, g_iLimit);
			SendQuery(iClient);
		}
	}
}

stock SendQuery(iClient) SQL_TQuery(g_hDatabase, SendMenuCallback, g_sQuery[iClient], iClient, DBPrio_High);

public SendMenuCallback(Handle:owner, Handle:hndl, const String:error[], any:iClient)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading bans (%s)", error);
	else
	{
		if(IsClientInGame(iClient))
		{
			new Handle:hMenu = CreateMenu(MenuHandler_UnBanList);
			SetMenuTitle(hMenu, "Управление банами:");
			SetMenuExitBackButton(hMenu, true);
			decl String:sItem[150], String:sBid[15], String:sCreated[150];
			while(SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sBid, sizeof(sBid));
				SQL_FetchString(hndl, 1, sItem, sizeof(sItem));
				FormatTime(sCreated, sizeof(sCreated), "Забанен: %H:%M %d/%m/%Y", SQL_FetchInt(hndl, 2));
				Format(sItem, sizeof(sItem), "%s\n(%s)", sItem, sCreated);
				AddMenuItem(hMenu, sBid, sItem);
			}
			DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
		}
	}
}

public MenuHandler_UnBanList(Handle:hMenu, MenuAction:action, iClient, param)
{
	if (action == MenuAction_Select)
	{
		decl String:sBid[32], String:sQuery[QUERY_SIZE];
		GetMenuItem(hMenu, param, sBid, sizeof(sBid));
		FormatEx(sQuery, sizeof(sQuery), "SELECT `ip`, `authid`, `name`, `created`, `ends`, `length`, `reason`, (SELECT `user` FROM %s_admins WHERE `aid` = '%i') FROM `%s_bans` WHERE `bid` = '%i';", DatabasePrefix, g_iAdminID[iClient], DatabasePrefix, StringToInt(sBid));
		SQL_TQuery(g_hDatabase, SendBanInfoCallback, sQuery, iClient, DBPrio_High);
	} else if (action == MenuAction_End) CloseHandle(hMenu);
	else if (action == MenuAction_Cancel)
	{
		if (param == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE) DisplayTopMenu(hTopMenu, iClient, TopMenuPosition_LastCategory);
	}
}

public SendBanInfoCallback(Handle:owner, Handle:hndl, const String:error[], any:iClient)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading info ban (%s)", error);
	else
	{
		if(SQL_FetchRow(hndl) && IsClientInGame(iClient))
		{
			decl String:sItem[200];
			new Handle:hMenu = CreateMenu(MenuHandler_BanInfo);
			SetMenuTitle(hMenu, "Информация о бане:");
			SetMenuExitBackButton(hMenu, true);
			
			SQL_FetchString(hndl, 2, sItem, sizeof(sItem));
			Format(sItem, sizeof(sItem), "Ник: %s", sItem);
			AddMenuItem(hMenu, sItem, sItem, ITEMDRAW_DISABLED);
			
			SQL_FetchString(hndl, 0, sItem, sizeof(sItem));
			Format(sItem, sizeof(sItem), "IP: %s", sItem);
			AddMenuItem(hMenu, "", sItem, ITEMDRAW_DISABLED);
			
			SQL_FetchString(hndl, 1, sItem, sizeof(sItem));
			AddMenuItem(hMenu, sItem, sItem, ITEMDRAW_DISABLED);
			
			SQL_FetchString(hndl, 7, sItem, sizeof(sItem));
			Format(sItem, sizeof(sItem), "Админ: %s", sItem);
			AddMenuItem(hMenu, "", sItem, ITEMDRAW_DISABLED);
			
			FormatTime(sItem, sizeof(sItem), "Забанен: %H:%M %d/%m/%Y", SQL_FetchInt(hndl, 3));
			AddMenuItem(hMenu, "", sItem, ITEMDRAW_DISABLED);
			
			if(SQL_FetchInt(hndl, 5) == 0) strcopy(sItem, sizeof(sItem), "Разбан: Никогда");
			else FormatTime(sItem, sizeof(sItem), "Разбан: %H:%M %d/%m/%Y", SQL_FetchInt(hndl, 4));
			AddMenuItem(hMenu, "", sItem, ITEMDRAW_DISABLED);
			
			SQL_FetchString(hndl, 6, sItem, sizeof(sItem));
			Format(sItem, sizeof(sItem), "Причина: %s\n \n", sItem);
			AddMenuItem(hMenu, "", sItem, ITEMDRAW_DISABLED);
			
			AddMenuItem(hMenu, "", "Разбанить");
			
			DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
		}
	}
}

public MenuHandler_BanInfo(Handle:hMenu, MenuAction:action, iClient, param)
{
	if (action == MenuAction_Select)
	{
		decl String:sAuth[32], String:sName[32];
		GetMenuItem(hMenu, 2, sAuth, sizeof(sAuth));
		GetMenuItem(hMenu, 0, sName, sizeof(sName));
		PrintToChat(iClient, "[SourceBans] Вы разбанили %s", sName[5]);
		ClientCommand(iClient, "sm_unban %s", sAuth);
	} else if (action == MenuAction_End) CloseHandle(hMenu);
	else if (action == MenuAction_Cancel)
	{
		if (param == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE) SendQuery(iClient);
	}
}
/*
public SendQueryCallback(Handle:owner, Handle:hndl, const String:error[], any:hPack)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading flags admin (%s)", error);
	else
	{
		if(SQL_FetchRow(hndl))
		{
			ResetPack(hPack);
			new iFlags = SQL_FetchInt(hndl, 0),
				iClient = ReadPackCell(hPack),
				iAid = ReadPackCell(hPack);

			CloseHandle(hPack);

			decl String:sQuery[QUERY_SIZE];
			if(iFlags & (1<<26)) FormatEx(sQuery, sizeof(sQuery), "SELECT `bid`, `ip`, `authid`, `name`, `created`, `ends`, `length`, `reason`, `aid`  FROM `%s_bans` WHERE `sid` = '%i' AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL ORDER BY `created` ASC LIMIT %d;", DatabasePrefix, serverID, g_iLimit);
			else if(iFlags & (1<<30)) FormatEx(sQuery, sizeof(sQuery), "SELECT `bid`, `ip`, `authid`, `name`, `created`, `ends`, `length`, `reason`, `aid` FROM `%s_bans` WHERE `aid` = '%i' AND `sid` = '%i' AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL ORDER BY `created` ASC LIMIT %d;", DatabasePrefix, iAid, serverID, g_iLimit);
			SQL_TQuery(g_hDatabase, SendMenuCallback, sQuery, iClient, DBPrio_High);
		}
	}
}

public SendMenuCallback(Handle:owner, Handle:hndl, const String:error[], any:iClient)
{
	if(hndl == INVALID_HANDLE) LogError("[Unban Sourcebans] Error loading bans (%s)", error);
	else
	{
		if(IsClientInGame(iClient))
		{
//	0	1				2						3					4			5			6		7			8		9				10		11			12			13			14			15		16
//	bid	ip				authid					name				created 	ends		length 	reason 		aid 	adminIp 		sid 	country 	RemovedBy 	RemoveType 	RemovedOn 	type 	ureason 
//	220	178.95.145.150	STEAM_0:0:1054685506	๖ۣۣۜWCG™ by Sense	1379521474	1379521474	0		Чит: Аим	1		91.219.83.173	1		UA			NULL		NULL		NULL		0		NULL
			
			new Handle:hMenu = CreateMenu(MenuHandler_UnBanList);
			SetMenuTitle(hMenu, "Кого разбанить:");
			SetMenuExitBackButton(hMenu, true);
			decl String:sItem[PLATFORM_MAX_PATH],
					String:sName[MAX_NAME_LENGTH],
					String:sAuth[40],
					String:sExpired[150],
					g_iBid;
			while(SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, sName, sizeof(sName));
				SQL_FetchString(hndl, (SQL_FetchInt(hndl, 2) > 0) ? 3:4, sAuth, sizeof(sAuth));
				SQL_FetchInt(hndl, 1)
				FormatTime(sExpired, sizeof(sExpired), "Истекает: %H:%M %d/%m/%Y", );
				FormatEx(sItem, sizeof(sItem), "%s\n(%s)", sName, sExpired);
				AddMenuItem(hMenu, sAuth,sItem);
			}
			DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
		}
	}
}

public MenuHandler_UnBanList(Handle:hMenu, MenuAction:action, iClient, param)
{
	if (action == MenuAction_Select)
	{
		decl String:sAuth[32], String:sName[MAX_NAME_LENGTH];
		GetMenuItem(hMenu, param, sAuth, sizeof(sAuth), _, sName, sizeof(sName));
		PrintToChat(iClient, "[SourceBans] Вы разбанили %s", sName);
		ClientCommand(iClient, "sm_unban %s", sAuth);
	} else if (action == MenuAction_End) CloseHandle(hMenu);
	else if (action == MenuAction_Cancel)
	{
		if (param == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE) DisplayTopMenu(hTopMenu, iClient, TopMenuPosition_LastCategory);
	}
}
*/
	
