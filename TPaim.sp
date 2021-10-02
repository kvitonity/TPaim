#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <adminmenu>

char TargetName[MAX_NAME_LENGTH];

TopMenu AdminMenu = null;
TopMenuObject AdminMenuItem = INVALID_TOPMENUOBJECT;

public void OnPluginStart()
{
	RegAdminCmd("sm_tmenu", Command_TMenu, ADMFLAG_ROOT);
	RegAdminCmd("sm_teleport", Command_Teleport, ADMFLAG_ROOT);
	RegAdminCmd("sm_teleport_to", Command_Teleport_To, ADMFLAG_ROOT);
	
	if(LibraryExists("adminmenu") && ((AdminMenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(AdminMenu);
	}
	
	LoadTranslations("teleport.phrases");
}

public void OnAdminMenuCreated(Handle topmenu)
{
	if(AdminMenu == null || (topmenu == AdminMenu && AdminMenuItem != INVALID_TOPMENUOBJECT))
	{
		return;
	}

	AdminMenuItem = AdminMenu.AddCategory("AdminTeleport", CategoryHandler, "teleport_admin", ADMFLAG_ROOT);
}

public void CategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "AdminMenuMsg", param);
	}
	else if(action == TopMenuAction_DisplayTitle)
	{
		FormatEx(buffer, maxlength, "%T\n ", "AdminMenuMsg", param);
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if((AdminMenu = GetAdminTopMenu()) != null)
	{
		if(AdminMenuItem == INVALID_TOPMENUOBJECT)
		{
			AdminMenuItem = AdminMenu.FindCategory("AdminTeleport");
			
			if(AdminMenuItem == INVALID_TOPMENUOBJECT)
			{
				OnAdminMenuCreated(topmenu);
			}
		}
		
		AdminMenu.AddItem("sm_tmenu", AdminMenu_Teleport, AdminMenuItem, "teleport_admin_tmenu", ADMFLAG_ROOT);
	}
}

public void AdminMenu_Teleport(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "AdminMenuMsg", param);
	}
	else if(action == TopMenuAction_SelectOption)
	{
		 Command_TMenu(param, 0);
	}
}

public Action Command_TMenu(int client, int args)
{
	char name[64], id[64];
	
	Menu menu = new Menu(Menu_ClientsArray);
	
	char title[32];
	FormatEx(title, 32, "%T", "Selection", client);
	
	menu.SetTitle(title);
	
	for(int player = 1; player <= MaxClients; player++)
	{
		if(IsClientInGame(player))
		{
			GetClientName(player, name, sizeof(name));
			IntToString(player, id, sizeof(id));
			
			menu.AddItem(id, name);
		}
	}
	
	if(!menu.ItemCount)
	{
		char Info[64];
		FormatEx(Info, 64, "%T", "EmptyArrayOfPlayers", client);
		
		menu.AddItem("%s", Info, ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 60);
	
	return Plugin_Handled;
}

public int Menu_ClientsArray(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(item, info, sizeof(info));
			
			int target = StringToInt(info);
			GetClientName(target, TargetName, sizeof(TargetName));
			SelectMenu(client);
		}
	}
}

void SelectMenu(int client)
{
	Menu menu = new Menu(Menu_SelectMenu);
	
	char main[32], name[MAX_NAME_LENGTH], title[128];
	FormatEx(main, 32, "%T", "MainTitle", client);
	FormatEx(name, MAX_NAME_LENGTH, "%T", "PlayerName", client, TargetName);
	FormatEx(title, 128, "%s\n%s\n ", main, name);
	
	menu.SetTitle(title);
	
	char item1[64], item2[64];
	FormatEx(item1, 64, "%T", "TeleportToTheTargert", client);
	FormatEx(item2, 64, "%T", "Selection", client);
	
	menu.AddItem("item1", item1);
	menu.AddItem("item2", item2);
	
	menu.ExitButton = true;
	menu.Display(client, 60);
}

public int Menu_SelectMenu(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(item, info, sizeof(info));
			
			if(StrEqual(info, "item1"))
			{
				FakeClientCommand(client, "sm_teleport \"%s\"", TargetName);
				SelectMenu(client);
			}
			else if(StrEqual(info, "item2"))
			{
				FakeClientCommand(client, "sm_tmenu");
			}
		}
	}
}

public Action Command_Teleport_To(int client, int args)
{
	if(args != 2)
	{
		PrintToChat(client, "[SM] Usage: sm_teleport_to <name> [target]");
		return Plugin_Handled;
	}
	
	char name[MAX_NAME_LENGTH], target[MAX_NAME_LENGTH];
							
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, target, sizeof(target));
	
	int id = FindTarget(client, target);
	int tp = FindTarget(client, name);
	
	float origin[3];
	GetClientAbsOrigin(id, origin);
	
	TeleportEntity(tp, origin, NULL_VECTOR, NULL_VECTOR);
	
	return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
	if(args <= 0)
	{
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	float destination[3];
	int target = FindTarget(client, arg);
	
	if(target == -1 || GetAimDestination(client, destination) == false)
	{
		return Plugin_Handled;
	}
	
	TeleportEntity(target, destination, NULL_VECTOR, NULL_VECTOR);
	
	return Plugin_Handled;
}

public bool GetAimDestination(int client, float destination[3])
{
	float origin[3], angles[3];
	GetClientEyeAngles(client, angles);
	GetClientEyePosition(client, origin);
	
	Handle TraceRay = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceRayFilter);
	
	if(TR_DidHit(TraceRay)) 
	{
		TR_GetEndPosition(destination, TraceRay);
		destination[2] += 16;
		return true;
	}
	
	CloseHandle(TraceRay);
	return false;
}

public bool TraceRayFilter(int entity, int contentsMask)
{
	return entity > MaxClients; 
}