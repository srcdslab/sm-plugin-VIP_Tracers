#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <vip_core>

public Plugin:myinfo = 
{
	name = "[VIP] Tracers",
	author = "R1KO & inGame & maxime1907",
	description = "Display the trajectory of bullets when firing with a weapon",
	version = "1.1",
	url = ""
};

new bool:g_bHasAccess[MAXPLAYERS+1];
new bool:g_bEnabled[MAXPLAYERS+1];

new bool:g_bVisible[MAXPLAYERS+1];
new Handle:g_hCookie_VIPTracers_Visible;

new g_iClientColor[MAXPLAYERS+1][4];
new g_iClientItem[MAXPLAYERS+1];
new Float:g_fClientAmplitude[MAXPLAYERS+1];

new g_iBeamSprite,
	Float:g_fLife,
	Float:g_fStartWidth,
	Float:g_fEndWidth,
	Float:g_fAmplitudeMin,
	Float:g_fAmplitudeMax,
	bool:g_bHide;

new Handle:g_hMainMenu,
	Handle:g_hColorsMenu,
	Handle:g_hCookie[3];

public OnPluginStart() 
{
	LoadTranslations("vip_tracers.phrases");
	
	HookEvent("bullet_impact",	Event_BulletImpact);

	g_hCookie[0] = RegClientCookie("Tracers_Enable", "Tracers_Enable", CookieAccess_Private);
	g_hCookie[1] = RegClientCookie("Tracers_Color", "Tracers_Color", CookieAccess_Private);
	g_hCookie[2] = RegClientCookie("Tracers_Amplitude", "Tracers_Amplitude", CookieAccess_Private);

	g_hCookie_VIPTracers_Visible  = RegClientCookie("Tracers_Visible",  "Tracers_Visible", CookieAccess_Private);
	
	g_hMainMenu = CreateMenu(Handler_MainMenu, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem);
	SetMenuExitBackButton(g_hMainMenu, false);
	SetMenuExitButton(g_hMainMenu, true);
	SetMenuTitle(g_hMainMenu, "VIP Tracers settings:\n \n");
	AddMenuItem(g_hMainMenu, "", "on/off");
	AddMenuItem(g_hMainMenu, "", "Choose Color");
	AddMenuItem(g_hMainMenu, "", "Amplitude", ITEMDRAW_DISABLED);  
	AddMenuItem(g_hMainMenu, "", "a+");
	AddMenuItem(g_hMainMenu, "", "a-");
	

	g_hColorsMenu = CreateMenu(Handler_ColorsMenu, MenuAction_Select|MenuAction_Cancel|MenuAction_DisplayItem);
	SetMenuExitBackButton(g_hColorsMenu, true);
	SetMenuExitButton(g_hColorsMenu, true);
	SetMenuTitle(g_hColorsMenu, "Tracers colors:\n \n");
	
	RegConsoleCmd("tracers", Command_Tracers);
	RegConsoleCmd("tracer", Command_Tracers);
	RegConsoleCmd("tracersoff", Command_TracersVisibility);
	RegConsoleCmd("traceroff", Command_TracersVisibility);

	SetCookieMenuItem(MenuHandler_CookieMenu, 0, "VIP Tracers");
}

public Action Command_Tracers(iClient, iArgs)
{
	if(iClient)
	{
		if(g_bHasAccess[iClient])
		{
			DisplayMenu(g_hMainMenu, iClient, MENU_TIME_FOREVER);
		}
		else
		{
			CPrintToChat(iClient, "%T", "no_access", iClient);
		}
	}
	return Plugin_Handled;
}

public Action Command_TracersVisibility(client, args)
{
	if(client)
	{
		g_bVisible[client] = !g_bVisible[client];
		SetClientCookie(client, g_hCookie_VIPTracers_Visible, g_bVisible[client] ? "1" : "0");
		PrintToChat(client, "\x0799CCFF[VIP Tracers] \x01VIP Tracers %s\x01.", g_bVisible[client] ? "\x04enabled":"\x07FF4040disabled");
	}
	return Plugin_Handled;
}

public Action TracersVisibility(client)
{
	if(client)
	{
		g_bVisible[client] = !g_bVisible[client];
		SetClientCookie(client, g_hCookie_VIPTracers_Visible, g_bVisible[client] ? "1" : "0");
		PrintToChat(client, "\x0799CCFF[VIP Tracers] \x01VIP Tracers %s\x01.", g_bVisible[client] ? "\x04enabled":"\x07FF4040disabled");
	}
	return Plugin_Handled;
}

void AddMenuItemTranslated(Menu menu, const char[] info, const char[] display, any ...)
{
	char buffer[128];
	VFormat(buffer, sizeof(buffer), display, 4);

	menu.AddItem(info, buffer);
}

public void ShowSettingsMenu(int client)
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

public OnMapStart()
{
	RemoveAllMenuItems(g_hColorsMenu);

	decl String:sBuffer[256], Handle:hKeyValues;

	hKeyValues = CreateKeyValues("Tracers");
	BuildPath(Path_SM, sBuffer, 256, "configs/tracers.cfg");

	if (FileToKeyValues(hKeyValues, sBuffer) == false)
	{
		CloseHandle(hKeyValues);
		SetFailState("Не удалось открыть файл \"%s\"", sBuffer);
	}

	g_bHide			= bool:KvGetNum(hKeyValues, "Hide_Opposite_Team");
	g_fLife			= KvGetFloat(hKeyValues, "Life", 0.2);
	g_fStartWidth	= KvGetFloat(hKeyValues, "StartWidth", 2.0);
	g_fEndWidth		= KvGetFloat(hKeyValues, "EndWidth", 2.0);
	g_fAmplitudeMax		= KvGetFloat(hKeyValues, "AmplitudeMax", 1.0);
	g_fAmplitudeMin		= KvGetFloat(hKeyValues, "AmplitudeMin", 0.1);

	KvGetString(hKeyValues, "Material", sBuffer, sizeof(sBuffer), "materials/sprites/laserbeam.vmt");
	g_iBeamSprite = PrecacheModel(sBuffer);

	KvRewind(hKeyValues);

	sBuffer[0] = 0;
	
	if(KvJumpToKey(hKeyValues, "Colors", true) && KvGotoFirstSubKey(hKeyValues, false))
	{
		decl String:sColor[64];
		do
		{
			KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
			KvGetString(hKeyValues, NULL_STRING, sColor, sizeof(sColor));
			AddMenuItem(g_hColorsMenu, sColor, sBuffer);
		}
		while (KvGotoNextKey(hKeyValues, false));
	}

	if(sBuffer[0] == 0)
    {  
		//  FormatEx(sName, sizeof(sName), "%T", "NO_COLORS_AVAILABLE", iClient);  
		AddMenuItem(g_hColorsMenu, "", "No Colors", ITEMDRAW_DISABLED);  
    }
	
	CloseHandle(hKeyValues);
}

public Handler_MainMenu(Handle:hMenu, MenuAction:action, iClient, Item)
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
					decl String:sInfo[8];
					IntToString(g_bEnabled[iClient], sInfo, sizeof(sInfo));
					SetClientCookie(iClient, g_hCookie[0], sInfo);
				}
				case 1:
				{
					DisplayMenu(g_hColorsMenu, iClient, MENU_TIME_FOREVER);
					return 0;
				}
				case 3:
				{
					if(g_fClientAmplitude[iClient] < g_fAmplitudeMax)
					{
						g_fClientAmplitude[iClient] += 0.1;
						decl String:sInfo[8];
						FloatToString(g_fClientAmplitude[iClient], sInfo, sizeof(sInfo));
						SetClientCookie(iClient, g_hCookie[2], sInfo);
					}
				}
				case 4:
				{
					if(g_fClientAmplitude[iClient] > g_fAmplitudeMin)
					{
						g_fClientAmplitude[iClient] -= 0.1;
						decl String:sInfo[8];
						FloatToString(g_fClientAmplitude[iClient], sInfo, sizeof(sInfo));
						SetClientCookie(iClient, g_hCookie[2], sInfo);
					}
				}
			}
			DisplayMenu(g_hMainMenu, iClient, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			decl String:sBuffer[128];
			switch(Item)
			{
				case 0:
				{
					strcopy(sBuffer, sizeof(sBuffer), g_bEnabled[iClient] ? "Disable tracers":"Enable tracers");
				}
				case 1:
				{
					decl String:sColorName[64];
					GetMenuItem(g_hColorsMenu, g_iClientItem[iClient], "", 0, _, sColorName, sizeof(sColorName));
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

public Handler_ColorsMenu(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack)
			{
				DisplayMenu(g_hMainMenu, iClient, MENU_TIME_FOREVER);
			}
		}
		case MenuAction_Select:
		{
			decl String:sInfo[64], String:sColorName[128];
			GetMenuItem(hMenu, Item, sInfo, sizeof(sInfo), _, sColorName, sizeof(sColorName));
			
			UTIL_LoadColor(iClient, sInfo);
			SetClientCookie(iClient, g_hCookie[1], sInfo);
	//		LogMessage("SaveColor: %N (%i): %s (%i)", iClient, iClient, sInfo, Item);
			g_iClientItem[iClient] = Item;

			PrintToChat(iClient, "\x0799CCFF[VIP Tracers] \x07FFFF00You changed your tracers color to \x04%s", sColorName);
			
			DisplayMenuAtItem(g_hColorsMenu, iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			if(g_iClientItem[iClient] == Item)
			{
				decl String:sColorName[128];
				GetMenuItem(hMenu, Item, "", 0, _, sColorName, sizeof(sColorName));
				
				Format(sColorName, sizeof(sColorName), "%s [X]", sColorName);

				return RedrawMenuItem(sColorName);
			}
		}
	}

	return 0;
}

public OnClientDisconnect(iClient)
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

public OnClientCookiesCached(iClient)
{
	decl String:sInfo[64];
	GetClientCookie(iClient, g_hCookie[0], sInfo, 4);
	if(!sInfo[0])
	{
		g_bEnabled[iClient] = true;
		SetClientCookie(iClient, g_hCookie[0], "1");
	}
	else
	{
		g_bEnabled[iClient] = bool:StringToInt(sInfo);
	}

	GetClientCookie(iClient, g_hCookie[2], sInfo, 8);
	if(!sInfo[0])
	{
		g_fClientAmplitude[iClient] = 0.1;
		SetClientCookie(iClient, g_hCookie[2], "0.1");
	}
	else
	{
		g_fClientAmplitude[iClient] = Float:StringToFloat(sInfo);
	}

	GetClientCookie(iClient, g_hCookie[1], sInfo, sizeof(sInfo));
	if(!sInfo[0])
	{
		g_iClientItem[iClient] = 0;
	}
	else if((g_iClientItem[iClient] = UTIL_GetItemIndex(sInfo)) == -1)
	{
		g_iClientItem[iClient] = 0;
	}

	GetMenuItem(g_hColorsMenu, g_iClientItem[iClient], sInfo, sizeof(sInfo));
	SetClientCookie(iClient, g_hCookie[1], sInfo);

	UTIL_LoadColor(iClient, sInfo);

	GetClientCookie(iClient, g_hCookie_VIPTracers_Visible, sInfo, sizeof(sInfo));
	if (!sInfo[0])
	{
		g_bVisible[iClient] = true;
		SetClientCookie(iClient, g_hCookie_VIPTracers_Visible, "1");
	}
	else
		g_bVisible[iClient] = bool:StringToInt(sInfo);
}

UTIL_LoadColor(iClient, const String:sInfo[])
{
	if(StrEqual(sInfo, "randomcolor"))
	{
		for(new i=0; i < 4; ++i)
		{
			g_iClientColor[iClient][i] = -1;
		}
		return;
	}
	if(StrEqual(sInfo, "teamcolor"))
	{
		for(new i=0; i < 4; ++i)
		{
			g_iClientColor[iClient][i] = -2;
		}
		return;
	}
	
	UTIL_GetRGBAFromString(sInfo, g_iClientColor[iClient]);
}

UTIL_GetRGBAFromString(const String:sBuffer[], iColor[4])
{
	decl String:sBuffers[4][4], i;
	ExplodeString(sBuffer, " ", sBuffers, sizeof(sBuffers), sizeof(sBuffers[]));
	for(i=0; i < 4; ++i)
	{
		StringToIntEx(sBuffers[i], iColor[i]);
	}
}

UTIL_GetItemIndex(const String:sItemInfo[])
{
//	LogMessage("UTIL_GetItemIndex: ClientItem: %s", sItemInfo);
	decl String:sInfo[64], i, iSize;
	iSize = GetMenuItemCount(g_hColorsMenu);
	for(i = 0; i < iSize; ++i)
	{
		GetMenuItem(g_hColorsMenu, i, sInfo, sizeof(sInfo));
//		LogMessage("UTIL_GetItemIndex: %i. MenuItem: %s", i, sInfo);
		if(strcmp(sInfo, sItemInfo) == 0)
		{
			return i;
		}
	}

	return -1;
}

public Event_BulletImpact(Handle:hEvent, const String:sEvName[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(iClient && g_bHasAccess[iClient] && g_bEnabled[iClient])
	{
		decl iClients[MaxClients], Float:fClientOrigin[3], Float:fEndPos[3], Float:fStartPos[3], Float:fPercentage, i, iTotalClients, iTeam, iColor[4]; 
		GetClientEyePosition(iClient, fClientOrigin);
		
		fEndPos[0] = GetEventFloat(hEvent, "x");
		fEndPos[1] = GetEventFloat(hEvent, "y");
		fEndPos[2] = GetEventFloat(hEvent, "z");
		
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