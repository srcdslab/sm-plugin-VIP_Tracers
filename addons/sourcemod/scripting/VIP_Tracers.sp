#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <vip_core>

#pragma newdecls required

public Plugin myinfo =
{
	name = "[VIP] Tracers",
	author = "R1KO & inGame & maxime1907",
	description = "Display the trajectory of bullets when firing with a weapon",
	version = "1.2.0",
	url = ""
};

bool g_bHasAccess[MAXPLAYERS+1];
bool g_bEnabled[MAXPLAYERS+1];

bool g_bVisible[MAXPLAYERS+1];
Cookie g_hCookie_VIPTracers_Visible;

int g_iClientColor[MAXPLAYERS+1][4];
int g_iClientItem[MAXPLAYERS+1];
float g_fClientAmplitude[MAXPLAYERS+1];

int g_iBeamSprite;
float g_fLife,
	g_fStartWidth,
	g_fEndWidth,
	g_fAmplitudeMin,
	g_fAmplitudeMax;
bool g_bHide;

Menu g_hMainMenu,
	g_hColorsMenu;
Cookie g_hCookie[3];

public void OnPluginStart()
{
	LoadTranslations("vip_tracers.phrases");

	HookEvent("bullet_impact",	Event_BulletImpact);

	g_hCookie[0] = new Cookie("Tracers_Enable", "Tracers_Enable", CookieAccess_Private);
	g_hCookie[1] = new Cookie("Tracers_Color", "Tracers_Color", CookieAccess_Private);
	g_hCookie[2] = new Cookie("Tracers_Amplitude", "Tracers_Amplitude", CookieAccess_Private);

	g_hCookie_VIPTracers_Visible  = new Cookie("Tracers_Visible",  "Tracers_Visible", CookieAccess_Private);

	g_hMainMenu = new Menu(Handler_MainMenu, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem);
	g_hMainMenu.ExitBackButton = false;
	g_hMainMenu.ExitButton = true;
	g_hMainMenu.SetTitle("VIP Tracers settings:\n \n");
	g_hMainMenu.AddItem("", "on/off");
	g_hMainMenu.AddItem("", "Choose Color");
	g_hMainMenu.AddItem("", "Amplitude", ITEMDRAW_DISABLED);
	g_hMainMenu.AddItem("", "a+");
	g_hMainMenu.AddItem("", "a-");


	g_hColorsMenu = new Menu(Handler_ColorsMenu, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem);
	g_hColorsMenu.ExitBackButton = true;
	g_hColorsMenu.ExitButton = true;
	g_hColorsMenu.SetTitle("Tracers colors:\n \n");

	RegConsoleCmd("tracers", Command_Tracers);
	RegConsoleCmd("tracer", Command_Tracers);
	RegConsoleCmd("tracersoff", Command_TracersVisibility);
	RegConsoleCmd("traceroff", Command_TracersVisibility);

	SetCookieMenuItem(MenuHandler_CookieMenu, 0, "VIP Tracers");
}

public Action Command_Tracers(int iClient, int iArgs)
{
	if(iClient)
	{
		if(g_bHasAccess[iClient])
		{
			g_hMainMenu.Display(iClient, MENU_TIME_FOREVER);
		}
		else
		{
			CPrintToChat(iClient, "%T", "no_access", iClient);
		}
	}
	return Plugin_Handled;
}

public Action Command_TracersVisibility(int client, int args)
{
	if(client)
	{
		TracersVisibility(client);
	}
	return Plugin_Handled;
}

void TracersVisibility(int client)
{
	g_bVisible[client] = !g_bVisible[client];
	g_hCookie_VIPTracers_Visible.Set(client, g_bVisible[client] ? "1" : "0");
	PrintToChat(client, "\x0799CCFF[VIP Tracers] \x01VIP Tracers %s\x01.", g_bVisible[client] ? "\x04enabled":"\x07FF4040disabled");
}

void AddMenuItemTranslated(Menu menu, const char[] info, const char[] display, any ...)
{
	char buffer[128];
	VFormat(buffer, sizeof(buffer), display, 4);

	menu.AddItem(info, buffer);
}

void ShowSettingsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_SettingsMenu);

	menu.SetTitle("%T", "Cookie Menu Title", client);

	AddMenuItemTranslated(menu, "0", "%t: %t", "Tracers",    g_bVisible[client]  ? "Visible" : "Hidden");

	menu.ExitBackButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public void MenuHandler_CookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch(action)
	{
		case(CookieMenuAction_DisplayOption):
		{
			Format(buffer, maxlen, "%T", "Cookie Menu", client);
		}
		case(CookieMenuAction_SelectOption):
		{
			ShowSettingsMenu(client);
		}
	}
}

public int MenuHandler_SettingsMenu(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case(MenuAction_Select):
		{
			switch(selection)
			{
				case(0): TracersVisibility(client);
			}

			ShowSettingsMenu(client);
		}
		case(MenuAction_Cancel):
		{
			ShowCookieMenu(client);
		}
		case(MenuAction_End):
		{
			delete menu;
		}
	}
	return 0;
}

public void OnMapStart()
{
	g_hColorsMenu.RemoveAllItems();

	char sBuffer[256];

	KeyValues hKeyValues = new KeyValues("Tracers");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/tracers.cfg");

	if (!hKeyValues.ImportFromFile(sBuffer))
	{
		delete hKeyValues;
		SetFailState("Не удалось открыть файл \"%s\"", sBuffer);
	}

	g_bHide			= hKeyValues.GetNum("Hide_Opposite_Team") != 0;
	g_fLife			= hKeyValues.GetFloat("Life", 0.2);
	g_fStartWidth	= hKeyValues.GetFloat("StartWidth", 2.0);
	g_fEndWidth		= hKeyValues.GetFloat("EndWidth", 2.0);
	g_fAmplitudeMax		= hKeyValues.GetFloat("AmplitudeMax", 1.0);
	g_fAmplitudeMin		= hKeyValues.GetFloat("AmplitudeMin", 0.1);

	hKeyValues.GetString("Material", sBuffer, sizeof(sBuffer), "materials/sprites/laserbeam.vmt");
	g_iBeamSprite = PrecacheModel(sBuffer);

	hKeyValues.Rewind();

	sBuffer[0] = 0;

	if(hKeyValues.JumpToKey("Colors", true) && hKeyValues.GotoFirstSubKey(false))
	{
		char sColor[64];
		do
		{
			hKeyValues.GetSectionName(sBuffer, sizeof(sBuffer));
			hKeyValues.GetString(NULL_STRING, sColor, sizeof(sColor));
			g_hColorsMenu.AddItem(sColor, sBuffer);
		}
		while (hKeyValues.GotoNextKey(false));
	}

	if(sBuffer[0] == 0)
	{
		g_hColorsMenu.AddItem("", "No Colors", ITEMDRAW_DISABLED);
	}

	delete hKeyValues;
}

public int Handler_MainMenu(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(Item)
			{
				case 0:
				{
					g_bEnabled[iClient] = !g_bEnabled[iClient];
					g_hCookie[0].Set(iClient, g_bEnabled[iClient] ? "1" : "0");
				}
				case 1:
				{
					g_hColorsMenu.Display(iClient, MENU_TIME_FOREVER);
					return 0;
				}
				case 3:
				{
					if(g_fClientAmplitude[iClient] < g_fAmplitudeMax)
					{
						g_fClientAmplitude[iClient] += 0.1;
						char sInfo[8];
						FloatToString(g_fClientAmplitude[iClient], sInfo, sizeof(sInfo));
						g_hCookie[2].Set(iClient, sInfo);
					}
				}
				case 4:
				{
					if(g_fClientAmplitude[iClient] > g_fAmplitudeMin)
					{
						g_fClientAmplitude[iClient] -= 0.1;
						char sInfo[8];
						FloatToString(g_fClientAmplitude[iClient], sInfo, sizeof(sInfo));
						g_hCookie[2].Set(iClient, sInfo);
					}
				}
			}
			g_hMainMenu.Display(iClient, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			char sBuffer[128];
			switch(Item)
			{
				case 0:
				{
					strcopy(sBuffer, sizeof(sBuffer), g_bEnabled[iClient] ? "Disable tracers":"Enable tracers");
				}
				case 1:
				{
					char sInfo[64], sColorName[64];
					g_hColorsMenu.GetItem(g_iClientItem[iClient], sInfo, sizeof(sInfo), _, sColorName, sizeof(sColorName));
					FormatEx(sBuffer, sizeof(sBuffer), "Color [%s]", sColorName);
				}
				case 2:
				{
					FormatEx(sBuffer, sizeof(sBuffer), "Amplitude [%.1f]", g_fClientAmplitude[iClient]);
				}
				case 3:
				{
					FormatEx(sBuffer, sizeof(sBuffer), "Amplitude +0.1");
				}
				case 4:
				{
					FormatEx(sBuffer, sizeof(sBuffer), "Amplitude -0.1");
				}
			}

			return RedrawMenuItem(sBuffer);
		}
	}

	return 0;
}

public int Handler_ColorsMenu(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack)
			{
				g_hMainMenu.Display(iClient, MENU_TIME_FOREVER);
			}
		}
		case MenuAction_Select:
		{
			char sInfo[64], sColorName[128];
			hMenu.GetItem(Item, sInfo, sizeof(sInfo), _, sColorName, sizeof(sColorName));

			UTIL_LoadColor(iClient, sInfo);
			g_hCookie[1].Set(iClient, sInfo);
			g_iClientItem[iClient] = Item;

			PrintToChat(iClient, "\x0799CCFF[VIP Tracers] \x07FFFF00You changed your tracers color to \x04%s", sColorName);

			g_hColorsMenu.DisplayAt(iClient, hMenu.Selection, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			if(g_iClientItem[iClient] == Item)
			{
				char sInfo[64], sColorName[128];
				hMenu.GetItem(Item, sInfo, sizeof(sInfo), _, sColorName, sizeof(sColorName));

				Format(sColorName, sizeof(sColorName), "%s [X]", sColorName);

				return RedrawMenuItem(sColorName);
			}
		}
	}

	return 0;
}

public void OnClientDisconnect(int iClient)
{
	g_bHasAccess[iClient] = false;
	g_bEnabled[iClient] = false;
	g_bVisible[iClient] = false;

	g_iClientColor[iClient][0] =
	g_iClientColor[iClient][1] =
	g_iClientColor[iClient][2] =
	g_iClientColor[iClient][3] =
	g_iClientItem[iClient] = 0;
	g_fClientAmplitude[iClient] = 0.0;
}

public void VIP_OnVIPClientLoaded(int client)
{
	CreateTimer(0.2, Timer_LoadDelay, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_LoadDelay(Handle hTimer, any userID)
{
	int iClient = GetClientOfUserId(userID);
	if (iClient)
		g_bHasAccess[iClient] = true;
	return Plugin_Continue;
}

public void OnClientCookiesCached(int iClient)
{
	char sInfo[64];
	g_hCookie[0].Get(iClient, sInfo, 4);
	if(!sInfo[0])
	{
		g_bEnabled[iClient] = true;
		g_hCookie[0].Set(iClient, "1");
	}
	else
	{
		g_bEnabled[iClient] = StringToInt(sInfo) != 0;
	}

	g_hCookie[2].Get(iClient, sInfo, 8);
	if(!sInfo[0])
	{
		g_fClientAmplitude[iClient] = 0.1;
		g_hCookie[2].Set(iClient, "0.1");
	}
	else
	{
		g_fClientAmplitude[iClient] = StringToFloat(sInfo);
	}

	g_hCookie[1].Get(iClient, sInfo, sizeof(sInfo));
	if(!sInfo[0])
	{
		g_iClientItem[iClient] = 0;
	}
	else if((g_iClientItem[iClient] = UTIL_GetItemIndex(sInfo)) == -1)
	{
		g_iClientItem[iClient] = 0;
	}

	g_hColorsMenu.GetItem(g_iClientItem[iClient], sInfo, sizeof(sInfo));
	g_hCookie[1].Set(iClient, sInfo);

	UTIL_LoadColor(iClient, sInfo);

	g_hCookie_VIPTracers_Visible.Get(iClient, sInfo, sizeof(sInfo));
	if (!sInfo[0])
	{
		g_bVisible[iClient] = true;
		g_hCookie_VIPTracers_Visible.Set(iClient, "1");
	}
	else
		g_bVisible[iClient] = StringToInt(sInfo) != 0;
}

void UTIL_LoadColor(int iClient, const char[] sInfo)
{
	if(StrEqual(sInfo, "randomcolor"))
	{
		for(int i = 0; i < 4; ++i)
		{
			g_iClientColor[iClient][i] = -1;
		}
		return;
	}
	if(StrEqual(sInfo, "teamcolor"))
	{
		for(int i = 0; i < 4; ++i)
		{
			g_iClientColor[iClient][i] = -2;
		}
		return;
	}

	UTIL_GetRGBAFromString(sInfo, g_iClientColor[iClient]);
}

void UTIL_GetRGBAFromString(const char[] sBuffer, int iColor[4])
{
	char sBuffers[4][4];
	ExplodeString(sBuffer, " ", sBuffers, sizeof(sBuffers), sizeof(sBuffers[]));
	for(int i = 0; i < 4; ++i)
	{
		StringToIntEx(sBuffers[i], iColor[i]);
	}
}

int UTIL_GetItemIndex(const char[] sItemInfo)
{
	char sInfo[64];
	int iSize = g_hColorsMenu.ItemCount;
	for(int i = 0; i < iSize; ++i)
	{
		g_hColorsMenu.GetItem(i, sInfo, sizeof(sInfo));
		if(strcmp(sInfo, sItemInfo) == 0)
		{
			return i;
		}
	}

	return -1;
}

public void Event_BulletImpact(Event hEvent, const char[] sEvName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if(iClient && g_bHasAccess[iClient] && g_bEnabled[iClient])
	{
		int[] iClients = new int[MaxClients];
		float fClientOrigin[3], fEndPos[3], fStartPos[3], fPercentage;
		int i, iTotalClients, iTeam, iColor[4];
		GetClientEyePosition(iClient, fClientOrigin);

		fEndPos[0] = hEvent.GetFloat("x");
		fEndPos[1] = hEvent.GetFloat("y");
		fEndPos[2] = hEvent.GetFloat("z");

		fPercentage = 0.4/(GetVectorDistance(fClientOrigin, fEndPos)/100.0);

		fStartPos[0] = fClientOrigin[0] + ((fEndPos[0]-fClientOrigin[0]) * fPercentage);
		fStartPos[1] = fClientOrigin[1] + ((fEndPos[1]-fClientOrigin[1]) * fPercentage)-0.08;
		fStartPos[2] = fClientOrigin[2] + ((fEndPos[2]-fClientOrigin[2]) * fPercentage);

		iTeam = GetClientTeam(iClient);

		if(g_iClientColor[iClient][0] == -1)
		{
			for(i = 0; i < 3; ++i)
			{
				iColor[i] = GetRandomInt(0, 255);
			}

			iColor[3] = GetRandomInt(120, 200);
		}
		else if(g_iClientColor[iClient][0] == -2)
		{
			iColor[1] = 25;
			iColor[3] = 150;

			switch (iTeam)
			{
				case 2 :
				{
					iColor[0] = 200;
					iColor[2] = 25;
				}
				case 3 :
				{
					iColor[0] = 25;
					iColor[2] = 200;
				}
			}
		}
		else
		{
			for(i = 0; i < 4; ++i)
			{
				iColor[i] = g_iClientColor[iClient][i];
			}
		}

		TE_SetupBeamPoints(fStartPos, fEndPos, g_iBeamSprite, 0, 0, 0, g_fLife, g_fStartWidth, g_fEndWidth, 1, g_fClientAmplitude[iClient], iColor, 0);

		i = 1;
		iTotalClients = 0;

		if(g_bHide)
		{
			while(i <= MaxClients)
			{
				if(g_bVisible[i] && IsClientInGame(i) && IsFakeClient(i) == false && GetClientTeam(i) == iTeam)
				{
					iClients[iTotalClients++] = i;
				}
				++i;
			}
		}
		else while(i <= MaxClients)
		{
			if(g_bVisible[i] && IsClientInGame(i) && IsFakeClient(i) == false)
			{
				iClients[iTotalClients++] = i;
			}
			++i;
		}

		TE_Send(iClients, iTotalClients);
	}
}
