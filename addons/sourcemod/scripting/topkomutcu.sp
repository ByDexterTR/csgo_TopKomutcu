#include <sourcemod>
#include <warden>

#pragma semicolon 1
#pragma newdecls required

int g_iPlayTimeWeek[65] = 0, kaydet = 0;
bool g_bChecked[65], g_bIsMySQl;
char g_sSQLBuffer[3096];

Handle g_hDB = null;
int g_iHours, g_iMinutes, g_iSeconds;

public Plugin myinfo = 
{
	name = "Top komutçu", 
	author = "ByDexter - (quantum.)", 
	description = "", 
	version = "1.1", 
	url = "https://steamcommunity.com/id/ByDexterTR - ByDexter#5494"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_topkomutcu", Command_TopKomutcu);
	RegConsoleCmd("sm_topkom", Command_TopKomutcu);
	RegConsoleCmd("sm_komsurem", Command_Komsurem);
	RegAdminCmd("sm_topkompanel", Command_TopkomutcuReset, ADMFLAG_ROOT);
	SQL_TConnect(OnSQLConnect, "topkomutcu");
}

public void OnMapStart()
{
	char map[32];
	GetCurrentMap(map, sizeof(map));
	char Filename[256];
	GetPluginFilename(INVALID_HANDLE, Filename, 256);
	if (strncmp(map, "workshop/", 9, false) == 0)
	{
		if (StrContains(map, "/jb_", false) == -1 && StrContains(map, "/jail_", false) == -1 && StrContains(map, "/ba_jail", false) == -1)
			ServerCommand("sm plugins unload %s", Filename);
	}
	else if (strncmp(map, "jb_", 3, false) != 0 && strncmp(map, "jail_", 5, false) != 0 && strncmp(map, "ba_jail", 3, false) != 0)
		ServerCommand("sm plugins unload %s", Filename);
	
	CreateTimer(1.0, PlayTimeTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public int OnSQLConnect(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Database failure: %s", error);
		SetFailState("Databases dont work");
	}
	else
	{
		g_hDB = hndl;
		
		SQL_GetDriverIdent(SQL_ReadDriver(g_hDB), g_sSQLBuffer, sizeof(g_sSQLBuffer));
		g_bIsMySQl = StrEqual(g_sSQLBuffer, "mysql", false) ? true : false;
		
		if (g_bIsMySQl)
		{
			SQL_FastQuery(g_hDB, "SET NAMES UTF8");
			SQL_FastQuery(g_hDB, "SET CHARACTER SET utf8mb4_unicode_ci");
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `topkomutcu` (`playername` varchar(128) NOT NULL, `steamid` varchar(32) PRIMARY KEY NOT NULL, `weekly` INT(16))");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);
		}
		else
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS topkomutcu (playername varchar(128) NOT NULL, steamid varchar(32) PRIMARY KEY NOT NULL, weekly INTEGER)");
			
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);
		}
	}
}

public int OnSQLConnectCallback(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		if (StrContains(error, "Duplicate", false) != -1)
		{
			LogError("Query failure: %s", error);
			return;
		}
	}
	else
	{
		for (int client = 1; client <= MaxClients; client++)if (IsValidClient(client))
			OnClientPostAdminCheck(client);
	}
}

public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client) && g_bChecked[client])
		SaveSQLCookies(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
		CheckSQLSteamID(client);
}

public Action Command_TopKomutcu(int client, int args)
{
	ShowTotal(client);
	Command_Komsurem(client, 0);
	return Plugin_Handled;
}

public Action Command_Komsurem(int client, int args)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	char buffer[128];
	Format(buffer, sizeof(buffer), "SELECT weekly FROM topkomutcu WHERE steamid = '%s'", steamid);
	SQL_TQuery(g_hDB, SQLShowWasteTime, buffer, client);
	return Plugin_Handled;
}

public Action Command_TopkomutcuReset(int client, int args)
{
	Menu menu = new Menu(ConfirmHandle);
	menu.SetTitle("Top komutçu kaydedilip sıfırlansın mı?\n＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿");
	menu.AddItem("0", "Evet");
	menu.AddItem("1", "İptal Et\n＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿");
	menu.ExitBackButton = false;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ConfirmHandle(Menu menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char item[4];
		menu.GetItem(position, item, 4);
		if (StringToInt(item) == 0)
		{
			if (g_hDB != null)
			{
				PrintToChatAll("[SM] \x10%N \x0CTop komutçu \x01panele kaydedip \x0Fsıfırlıyor...", client);
				for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
				{
					OnClientDisconnect(i);
					OnClientPostAdminCheck(i);
				}
				char buffer[200];
				Format(buffer, sizeof(buffer), "SELECT playername, weekly, steamid FROM topkomutcu ORDER BY weekly DESC LIMIT 999");
				SQL_TQuery(g_hDB, SendLog, buffer);
				char g_LogPath[256], Formatlama[20];
				
				FormatTime(Formatlama, 20, "%d_%b_%Y", GetTime());
				BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/topkom_%s.txt", Formatlama);
				PrintToChat(client, "[SM] \x01Başarıyla \x0Ctop komutçu\x01 panele \x06kaydedildi!");
				PrintToChat(client, "[SM] Kayıt yeri: \x0E%s", g_LogPath);
			}
			else
			{
				LogError("Sifirlama islemi basarisiz database baglantisi yok!");
			}
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

public Action Delay(Handle timer, int client)
{
	char buffer[200];
	Format(buffer, sizeof(buffer), "DELETE FROM topkomutcu;");
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
	{
		OnClientDisconnect(i);
		OnClientPostAdminCheck(i);
	}
}

public int SaveSQLPlayerCallback(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		if (StrContains(error, "Duplicate", false) != -1)
		{
			LogError("Query failure: %s", error);
			return;
		}
	}
}

public void CheckSQLSteamID(int client)
{
	char query[255], steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	Format(query, sizeof(query), "SELECT weekly FROM topkomutcu WHERE steamid = '%s'", steamid);
	SQL_TQuery(g_hDB, CheckSQLSteamIDCallback, query, GetClientUserId(client));
}

public int CheckSQLSteamIDCallback(Handle owner, Handle hndl, char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
	{
		return;
	}
	
	if (hndl == null)
	{
		LogError("Query failure: %s", error);
		return;
	}
	if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl))
	{
		InsertSQLNewPlayer(client);
		return;
	}
	
	g_iPlayTimeWeek[client] = SQL_FetchInt(hndl, 0);
	g_bChecked[client] = true;
}

public void InsertSQLNewPlayer(int client)
{
	char query[255], steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	int userid = GetClientUserId(client);
	
	char Name[MAX_NAME_LENGTH + 1];
	char SafeName[(sizeof(Name) * 2) + 1];
	if (!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(g_hDB, Name, SafeName, sizeof(SafeName));
	}
	
	Format(query, sizeof(query), "INSERT INTO topkomutcu(playername, steamid, weekly) VALUES('%s', '%s', '0');", SafeName, steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, userid);
	g_iPlayTimeWeek[client] = 0;
	g_bChecked[client] = true;
}

public void SaveSQLCookies(int client)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	char Name[MAX_NAME_LENGTH + 1];
	char SafeName[(sizeof(Name) * 2) + 1];
	if (!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(g_hDB, Name, SafeName, sizeof(SafeName));
	}
	
	char buffer[3096];
	Format(buffer, sizeof(buffer), "UPDATE topkomutcu SET playername = '%s', weekly = '%i' WHERE steamid = '%s';", SafeName, g_iPlayTimeWeek[client], steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
	g_bChecked[client] = false;
}

public Action PlayTimeTimer(Handle timer)
{
	if (warden_exist())
	{
		for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i) && warden_iswarden(i))
		{
			g_iPlayTimeWeek[i]++;
			break;
		}
	}
	kaydet++;
	if (kaydet == 600)
	{
		for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
		{
			OnClientDisconnect(i);
			OnClientPostAdminCheck(i);
		}
		kaydet = 0;
	}
}

public int SendLog(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		LogError(error);
		PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	int order = 0;
	char name[64], textbuffer[128], steamid[128];
	int nazim = 999;
	
	char g_LogPath[256], Formatlama[20];
	
	FormatTime(Formatlama, 20, "%d_%b_%Y", GetTime());
	BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/topkom_%s.txt", Formatlama);
	
	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			if (order <= nazim--)
			{
				order++;
				SQL_FetchString(hndl, 0, name, sizeof(name));
				SQL_FetchString(hndl, 2, steamid, sizeof(steamid));
				g_iHours = 0;
				g_iMinutes = 0;
				g_iSeconds = 0;
				ShowTimer2(SQL_FetchInt(hndl, 1));
				
				Format(textbuffer, sizeof(textbuffer), "%i | %s - %d saat %d dakika %d saniye - steamid: %s", order, name, g_iHours, g_iMinutes, g_iSeconds, steamid);
				if (g_iHours == 0 && g_iMinutes == 0 && g_iSeconds == 0) { /* DO NOTHING */ }
				else
					LogToFileEx(g_LogPath, textbuffer);
			}
			else
				break;
		}
	}
	
	char buffer[200];
	Format(buffer, sizeof(buffer), "DELETE FROM topkomutcu;");
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
	{
		OnClientDisconnect(i);
		OnClientPostAdminCheck(i);
	}
	PrintToChatAll("[SM] \x0CTop komutçu \x0Fsıfırlandı!");
}

public void ShowTotal(int client)
{
	if (g_hDB != null)
	{
		char buffer[200];
		Format(buffer, sizeof(buffer), "SELECT playername, weekly, steamid FROM topkomutcu ORDER BY weekly DESC LIMIT 999");
		SQL_TQuery(g_hDB, ShowTotalCallback, buffer, client);
	}
	else
	{
		PrintToChat(client, "[SM] Veri tabanına bağlantı \x0Fsağlanamıyor...");
	}
}

public int ShowTotalCallback(Handle owner, Handle hndl, char[] error, any client)
{
	if (hndl == null)
	{
		LogError(error);
		PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	Menu menu2 = new Menu(DIDMenuHandler2);
	menu2.SetTitle("Top komutçu\n＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿\n ");
	
	int order = 0;
	char name[64];
	char textbuffer[128];
	char steamid[32];
	
	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			order++;
			SQL_FetchString(hndl, 0, name, sizeof(name));
			SQL_FetchString(hndl, 2, steamid, sizeof(steamid));
			g_iHours = 0;
			g_iMinutes = 0;
			g_iSeconds = 0;
			ShowTimer2(SQL_FetchInt(hndl, 1));
			Format(textbuffer, 128, "%i | %s - %d saat %d dakika %d saniye", order, name, g_iHours, g_iMinutes, g_iSeconds);
			if (g_iHours == 0 && g_iMinutes == 0 && g_iSeconds == 0) { /* DO NOTHING*/ }
			else
				menu2.AddItem(steamid, textbuffer, ITEMDRAW_DISABLED);
		}
	}
	if (order < 1)
		menu2.AddItem("empty", "Top komutçu boş!", ITEMDRAW_DISABLED);
	
	menu2.Display(client, MENU_TIME_FOREVER);
}

public int DIDMenuHandler2(Menu menu2, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_NoDisplay)
			PrintToChat(client, "[SM] \x01Top komutçu kayıtlarında bir karışıklık olmuş.");
	}
	else if (action == MenuAction_End)
		delete menu2;
}

int ShowTimer(int Time, char[] buffer, int sizef)
{
	g_iHours = 0;
	g_iMinutes = 0;
	g_iSeconds = Time;
	
	while (g_iSeconds > 3600)
	{
		g_iHours++;
		g_iSeconds -= 3600;
	}
	while (g_iSeconds > 60)
	{
		g_iMinutes++;
		g_iSeconds -= 60;
	}
	if (g_iHours >= 1)
	{
		Format(buffer, sizef, "%d saat %d dakika %d saniye", g_iHours, g_iMinutes, g_iSeconds);
	}
	else if (g_iMinutes >= 1)
	{
		Format(buffer, sizef, "%d dakika %d saniye", g_iMinutes, g_iSeconds);
	}
	else
	{
		Format(buffer, sizef, "%d saniye", g_iSeconds);
	}
}

void ShowTimer2(int Time)
{
	g_iHours = 0;
	g_iMinutes = 0;
	g_iSeconds = Time;
	
	while (g_iSeconds > 3600)
	{
		g_iHours++;
		g_iSeconds -= 3600;
	}
	while (g_iSeconds > 60)
	{
		g_iMinutes++;
		g_iSeconds -= 60;
	}
}

public int SQLShowWasteTime(Handle owner, Handle hndl, char[] error, int client)
{
	if (hndl == null)
	{
		if (StrContains(error, "Duplicate", false) != -1)
		{
			LogError("Query failure: %s", error);
			return;
		}
	}
	
	while (SQL_FetchRow(hndl))
	{
		char buffer[124];
		ShowTimer(SQL_FetchInt(hndl, 0), buffer, sizeof(buffer));
		if (IsValidClient(client))
			PrintToChat(client, "[SM] Toplam \x04%s \x01komut vermişsin!", buffer);
	}
	
	delete hndl;
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
		OnClientDisconnect(i);
} 