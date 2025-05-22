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
		1.0.0 -	Релиз
		1.0.1 -	Исправлена кодировка
				Совместимость с версией ядра 1.1.2 R
				Добавлен лог получения тестового VIP-статуса.
				Добавлен финский перевод.
		1.0.2 -	Исправлена ошибка когда невозможно взять VIP-статус повторно.
		1.0.3 -	При попытке взять VIP-статус повторно будет показано сколько времени осталось.
				Добавлена поддержка MySQL.
				Изменено сообщение в лог.
		1.0.4 - Update syntax to SM 1.11
		1.0.5 - Check if SteamID is valid to give VIP Test.
				Translations from CRLF to LF.
				French translate
		1.0.6 - Prevent attempt to give VIP Test to a player who already has VIP status.
				Fix FI translation.
		1.0.7 - Upgrade to utf8mb4
		1.0.8 - No need to lock/unlock database - All queries are asynchronous.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip_core>

#define DB_CHARSET "utf8mb4"
#define DB_COLLATION "utf8mb4_unicode_ci"

public Plugin myinfo =
{
	name = "[VIP] Test",
	author = "Loneypro",
	description = "Players can test vip features for a set of time",
	version = "1.0.8",
	url = ""
};

Handle g_hDatabase;
bool g_bDBMySQL;
int g_iTestTime;
int g_iTestInterval;
char g_sTestGroup[64];

public void OnPluginStart()
{
	ConVar hCvar = CreateConVar("sm_vip_test_group", "Test VIP", "Группа для тестового VIP-статуса / Test VIP group");
	hCvar.AddChangeHook(OnTestGroupChange);
	GetConVarString(hCvar, g_sTestGroup, sizeof(g_sTestGroup));
	
	ConVar hCvar1 = CreateConVar("sm_vip_test_time", "120", "На сколько времени выдавать тестовый VIP-статус (значение зависит от sm_vip_time_mode) / VIP-Test duration (value depends on sm_vip_time_mode)", 0, true, 0.0);
	hCvar1.AddChangeHook(OnTestTimeChange);
	g_iTestTime = hCvar1.IntValue;
	
	ConVar hCvar2 = CreateConVar("sm_vip_test_interval", "3600", "Через сколько времени можно повторно брать тестовый VIP-статус (значение зависит от sm_vip_time_mode) (0 - Запретить брать повторно) / How often player can request test VIP status (value depends on sm_vip_time_mode) (0 - deny new requests)");
	hCvar2.AddChangeHook(OnTestIntervalChange);
	g_iTestInterval = hCvar2.IntValue;

	AutoExecConfig(true, "vip_test", "vip");
	
	RegConsoleCmd("sm_testvip", TestVIP_CMD);
	RegConsoleCmd("sm_viptest", TestVIP_CMD);

	RegAdminCmd("sm_clear_viptest", ClearTestVIP_CMD, ADMFLAG_ROOT);

	Connect_DB();

	LoadTranslations("vip_test.phrases");
	LoadTranslations("vip_core.phrases");
}

public void OnTestTimeChange(ConVar hCvar, const char[] oldVal, const char[] newVal)
{
	g_iTestTime = GetConVarInt(hCvar);
}
public void OnTestIntervalChange(ConVar hCvar, const char[] oldVal, const char[] newVal)
{
	g_iTestInterval = GetConVarInt(hCvar);
}
public void OnTestGroupChange(ConVar hCvar, const char[] oldVal, const char[] newVal)
{
	strcopy(g_sTestGroup, sizeof(g_sTestGroup), newVal);
}

stock void Connect_DB()
{
	if (SQL_CheckConfig("vip_test"))
	{
		SQL_TConnect(DB_OnConnect, "vip_test", 1);
	}
	else
	{
		char sError[256];
		sError[0] = '\0';
		g_hDatabase = SQLite_UseDatabase("vip_test", sError, sizeof(sError));
		DB_OnConnect(g_hDatabase, g_hDatabase, sError, 2);
	}
}

stock void DB_OnConnect(Handle owner, Handle hndl, const char[] sError, any data)
{
	g_hDatabase = hndl;
	
	if (g_hDatabase == INVALID_HANDLE || sError[0])
	{
		SetFailState("DB Connect %s", sError);
		return;
	}

	char sDriver[16];
	switch (data)
	{
		case 1 :
		{
			SQL_GetDriverIdent(owner, sDriver, sizeof(sDriver));
		}
		default :
		{
			SQL_ReadDriver(owner, sDriver, sizeof(sDriver));
		}
	}

	g_bDBMySQL = (strcmp(sDriver, "mysql", false) == 0);

	if (g_bDBMySQL)
	{
		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "SET NAMES \"%s\"", DB_CHARSET);
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);

		Format(sQuery, sizeof(sQuery), "SET CHARSET \"%s\"", DB_CHARSET);
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
	}
	
	CreateTables();
}

public void SQL_Callback_ErrorCheck(Handle owner, Handle hndl, const char[] sError, any data)
{
	if (sError[0])
	{
		LogError("SQL_Callback_ErrorCheck: %s", sError);
	}
}

stock void CreateTables()
{
	if (g_bDBMySQL)
	{
		char sQuery[512];
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `vip_test` (\
										`auth` VARCHAR(24) NOT NULL, \
										`end` INT(10) UNSIGNED NOT NULL, \
										PRIMARY KEY(`auth`)) \
										DEFAULT CHARSET=%s COLLATE=%s;", DB_CHARSET, DB_COLLATION);
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck, sQuery);
	}
	else
	{
		SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck,	"CREATE TABLE IF NOT EXISTS `vip_test` (\
																		`auth` VARCHAR(24) NOT NULL PRIMARY KEY, \
																		`end` INTEGER UNSIGNED NOT NULL);");
	}
}

public Action ClearTestVIP_CMD(int iClient, int args)
{
	if (iClient)
	{
		SQL_TQuery(g_hDatabase, SQL_Callback_DropTable, "DROP TABLE `vip_test`;");
	}
	return Plugin_Handled;
}

public void SQL_Callback_DropTable(Handle hOwner, Handle hQuery, const char[] sError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		LogError("SQL_Callback_DropTable: %s", sError);
		return;
	}

	CreateTables();
}

public Action TestVIP_CMD(int iClient, int args)
{
	if (iClient)
	{
		if(VIP_IsClientVIP(iClient))
		{
			VIP_PrintToChatClient(iClient, "%t", "VIP_ALREADY");
			return Plugin_Handled;
		}

		char sQuery[256], sAuth[32];
		//	GetClientAuthString(iClient, sAuth, sizeof(sAuth));
		//	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
		if (!GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth), true))
		{
			VIP_PrintToChatClient(iClient, "%t", "VIP_AUTH_FAILED");
			return Plugin_Handled;
		}
		else
		{
			FormatEx(sQuery, sizeof(sQuery), "SELECT `end` FROM `vip_test` WHERE `auth` = '%s' LIMIT 1;", sAuth);
			SQL_TQuery(g_hDatabase, SQL_Callback_SelectClient, sQuery, GetClientUserId(iClient));
		}
	}
	return Plugin_Handled;
}

public void SQL_Callback_SelectClient(Handle hOwner, Handle hQuery, const char[] sError, any UserID)
{
	int iClient = GetClientOfUserId(UserID);
	if (iClient)
	{
		if (hQuery == INVALID_HANDLE)
		{
			LogError("SQL_Callback_SelectClient: %s", sError);
			return;
		}
		
		if(SQL_FetchRow(hQuery))
		{
			if(g_iTestInterval > 0)
			{
				int iIntervalSeconds = SQL_FetchInt(hQuery, 0)+VIP_TimeToSeconds(g_iTestInterval),
				iTime = GetTime();
				if(iTime > iIntervalSeconds)
				{
					GiveVIPToClient(iClient, true);
				}
				else
				{
					char sTime[64];
					if(VIP_GetTimeFromStamp(sTime, sizeof(sTime), iIntervalSeconds-iTime, iClient))
					{
						VIP_PrintToChatClient(iClient, "%t", "VIP_RENEWAL_IS_NOT_AVAILABLE_YET", sTime);
					}
				}
			}
			else
			{
				VIP_PrintToChatClient(iClient, "%t", "VIP_RENEWAL_IS_DISABLED");
			}
		}
		else
		{
			GiveVIPToClient(iClient);
		}
	}
}

public void SQL_Callback_InsertClient(Handle hOwner, Handle hQuery, const char[] sError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		LogError("SQL_Callback_InsertClient: %s", sError);
		return;
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if(IsFakeClient(iClient) == false)
	{
		char sQuery[256], sAuth[32];
		GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
		FormatEx(sQuery, sizeof(sQuery), "SELECT `end` FROM `vip_test` WHERE `auth` = '%s' LIMIT 1;", sAuth);
		SQL_TQuery(g_hDatabase, SQL_Callback_SelectClientAuthorized, sQuery, GetClientUserId(iClient));
	}
}

public void SQL_Callback_SelectClientAuthorized(Handle hOwner, Handle hQuery, const char[] sError, any UserID)
{
	int iClient = GetClientOfUserId(UserID);
	if (iClient)
	{
		if (hQuery == INVALID_HANDLE)
		{
			LogError("SQL_Callback_SelectClientAuthorized: %s", sError);
			return;
		}
		
		if(SQL_FetchRow(hQuery))
		{
			int iEnd, iTime;
			if((iEnd = SQL_FetchInt(hQuery, 0)) > (iTime = GetTime()) && !VIP_IsClientVIP(iClient))
			{
				VIP_GiveClientVIP(_, iClient, iEnd - iTime, g_sTestGroup, false);
			}
		}
	}
}

stock void GiveVIPToClient(int iClient, bool bUpdate = false)
{
	if (VIP_IsClientVIP(iClient))
	{
		VIP_PrintToChatClient(iClient, "%t", "VIP_ALREADY");
		return;
	}

	int iSeconds;
	char sQuery[256], sAuth[32];
	iSeconds = VIP_TimeToSeconds(g_iTestTime);
	VIP_GiveClientVIP(_, iClient, iSeconds, g_sTestGroup, false);
	VIP_GetTimeFromStamp(sQuery, sizeof(sQuery), iSeconds, LANG_SERVER);

	GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	
	VIP_LogMessage("Player %N (%s) received a VIP-Test status (Group: %s, Duration: %s)", iClient, sAuth, g_sTestGroup, sQuery);

	if(bUpdate)
	{
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `vip_test` SET `end` = '%i' WHERE `auth` = '%s';", GetTime()+iSeconds, sAuth);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `vip_test` (`auth`, `end`) VALUES ('%s', '%i');", sAuth, GetTime()+iSeconds);
	}

	SQL_TQuery(g_hDatabase, SQL_Callback_InsertClient, sQuery);
}
