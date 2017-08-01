#pragma tabsize 0
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <chatprint>
#include <unixtime>
#include <sqlx>

#include <myLibrary>

#define PLUGIN 	"[AMX] Hook"
#define VERSION	"02.10.2015"
#define AUTHOR	"Forze"


new Handle:g_SQL_Connection, Handle:g_SQL_Tuple

/** FUNCTION NAME, pId */
#define _MENU_CALLBACK_SPRITE(%0,%1) ShowMenu_Sprite_%0(%1, g_iMenu_Page[%1])

/** FUNCTION NAME, pId */
#define _MENU_CALLBACK_COLOR(%0,%1) ShowMenu_Color_%0(%1, g_iMenu_Page[%1])

#define TASK_HOOK_THINK 865367

#define PREFIX	"[Forze_hook]"

new Float:g_vecHookOrigin[33][3];

enum _:TOTAL_HOOKS
{
	HOOK_INDEX,
	HOOK_INDEX2
};
new g_iHook[33][TOTAL_HOOKS];
	
	/** pId, iIndex */
	#define IsHook_Index(%1,%2) (bool:(g_iHook[%1][HOOK_INDEX] == %2))
	
	/** pId, iIndex */
	#define IsHook_Index2(%1,%2) (bool:(g_iHook[%1][HOOK_INDEX2] == %2))

enum _:TOTAL_ADMIN_TYPES
{
	ADMIN_TYPE_NULL,
	ADMIN_TYPE_IP,
	ADMIN_TYPE_ID,
	ADMIN_TYPE_NAME
};
new g_iAdmin_Type[33];

new plSprite[33], plEnable[33];

	/** pId, ADMIN_TYPE_ */
	#define IsAdmin_Type(%1,%2) (bool:(g_iAdmin_Type[%1] == %2))
	
new Trie:g_tHook;

enum _:TOTAL_HOOK_ARRAYS
{
	AI_HOOK_NAME[32],
	AI_HOOK_SOUND[64],
	AI_HOOK_SPRITE[64],
	AI_HOOK_SPRITE2[64],
	
	AI_HOOK_SPRITE_SIZE,
	AI_HOOK_SPRITE_WIDTH,
	AI_HOOK_SPRITE_INDEX,
	AI_HOOK_SPRITE_INDEX2,
	AI_HOOK_SPRITE_BRIGHTNESS
};
new Array:g_aHook, g_iHook_ItemsNum;

new model_gibs, model_gibs2, model_gibs3, model_gibs4;

enum _:TOTAL_COLOR_ARRAYS
{
	AI_COLOR_NAME[32],
	AI_COLOR_RGB[3]
};
new Array:g_aColor, g_iColor_ItemsNum;

enum _:TOTAL_USERS_INFO
{
	USER_INFO_IP,
	USER_INFO_ID,
	USER_INFO_NAME
};
new g_szUserInfo[33][TOTAL_USERS_INFO][32];

new g_iMenu_Page[33], g_iMenu_Target[33][32];

new g_CvarHost, g_CvarUser, g_CvarPassword, g_CvarDB;

	/** pId, iKey, iRatio */
	#define Player_GetMenuItemTarget(%1,%2,%3) (g_iMenu_Target[%1][(g_iMenu_Page[%1] * %3) + %2])

enum _:TOTAL_SPEED_ARRAYS
{
	AI_SPEED_NAME[32],
	AI_SPEED_USED,
	Float:AI_SPEED_VALUE
};
new g_iType_Speed[33];

new const g_aItemSpeed[][TOTAL_SPEED_ARRAYS] =
{
	{ "Мелкая", 0, 300.0 },
	{ "Средняя", 1, 500.0 },
	{ "Большая", 2, 700.0 }
};
	
#define CVAR_PREFIX 		"\g[Jumping-DeathRun]\n"
#define CVAR_COLOR_ITEMS 	7
#define CVAR_SPRITE_ITEMS 	7

#define MenuId_Hook 		"MENU HOOK"
#define MenuId_Color 		"MENU COLOR"
#define MenuId_Speed 		"MENU SPEED"
#define MenuId_Sprite 		"MENU SPRITE"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterMenu(MenuId_Hook, "ShowMenu_Hook_Handler");
	RegisterMenu(MenuId_Color, "ShowMenu_Color_Handler");
	RegisterMenu(MenuId_Speed, "ShowMenu_Speed_Handler");
	RegisterMenu(MenuId_Sprite, "ShowMenu_Sprite_Handler");
	
	register_forward(FM_ClientUserInfoChanged, "FmHook_ClientUserInfoChanged", false);
	
	register_clcmd("+hook", "ClCmd_HookOn");
	register_clcmd("-hook", "ClCmd_HookOff");
	
	g_CvarHost 			= register_cvar("mysql_savemoney_host", "cs1.csserv.ru")
	g_CvarDB 			= register_cvar("mysql_savemoney_db", "27097")
	g_CvarUser 			= register_cvar("mysql_savemoney_user", "27097")
	g_CvarPassword 		= register_cvar("mysql_savemoney_password", "Ep9JjfcakFP")
	
	register_clcmd("say /hook", "ClCmd_ShowMenu_Hook");
}

/*================================================================================
	Подключение к БД
=================================================================================*/
public plugin_cfg()
{
	new host[32], db[32], user[32], password[32]
	get_pcvar_string(g_CvarHost, host, 31)
	get_pcvar_string(g_CvarDB, db, 31)
	get_pcvar_string(g_CvarUser, user, 31)
	get_pcvar_string(g_CvarPassword, password, 31)
	
	g_SQL_Tuple = SQL_MakeDbTuple(host,user,password,db)
	
	new err, error[256]
	g_SQL_Connection = SQL_Connect(g_SQL_Tuple, err, error, charsmax(error))
	
	if (g_SQL_Connection)
	{
		log_amx("%s Conected to DataBase: OK", PREFIX)
		SQL_QueryAndIgnore(g_SQL_Connection, "CREATE TABLE IF NOT EXISTS `amxx_forze_hook` (`id` int(11) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '0',`hook` int(11) NOT NULL DEFAULT '0',`hook2` int(11) NOT NULL DEFAULT '0',`speed` int(11) NOT NULL DEFAULT '0',`effect` int(11) NOT NULL DEFAULT '0',PRIMARY KEY (`id`), UNIQUE KEY `name` (`name`)) DEFAULT CHARSET=utf8")
	}
	else
		log_amx("%s Conected to DataBase: ERROR %d (%s)",PREFIX, err, error)

}


public MenuSpritess(id)
{
	new menu = menu_create("\rВыбор эффекта:","menu")
	
	if(plSprite[id] == 1)
		menu_additem(menu,"Шарики \r[Выбран]", "1", 0)
	else 
		menu_additem(menu,"Шарики", "1", 0)
	
	if(plSprite[id] == 2)
		menu_additem(menu,"Халф-Лайф \r[Выбран]", "2", 0)
	else 
		menu_additem(menu,"Халф-Лайф", "2", 0)
	
	if(plSprite[id] == 3)
		menu_additem(menu,"Звёзды \r[Выбран]", "3", 0)
	else 
		menu_additem(menu,"Звёзды", "3", 0)
	
	if(plSprite[id] == 4)
		menu_additem(menu,"Лёд \r[Выбран]^n", "4", 0)
	else 
		menu_additem(menu,"Лёд^n", "4", 0)
	
	if(plSprite[id] != 0)
		menu_additem(menu,"\yВыключить^n", "5", 0)
	else 
		menu_additem(menu,"\rОтключен^n", "5", 0)
	
	menu_additem(menu,"\rВыход", "0", 0)
	menu_setprop(menu, MPROP_PERPAGE, 0)
	menu_display(id, menu, 0)
}
public menu(id,menu,item)
{
    if(item==MENU_EXIT)
    {
		menu_destroy(menu)
		return PLUGIN_HANDLED
    }
    new data[6], iName[64]
    new access, callback
    menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);
    new key = str_to_num(data)

    switch(key)
    {
        case 1:
        {
			plSprite[id] = 1
			MenuSpritess(id)
    	}
		case 2:
		{
			plSprite[id] = 2
			MenuSpritess(id)
		}
		case 3:
		{
			plSprite[id] = 3
			MenuSpritess(id)
		}
		case 4:
		{
			plSprite[id] = 4
			MenuSpritess(id)
		}
		case 5:
		{
			plSprite[id] = 0
			MenuSpritess(id)
		}
	}
return PLUGIN_CONTINUE
}

public plugin_precache()
{
	g_tHook 	= TrieCreate();
	
	g_aHook 	= ArrayCreate(TOTAL_HOOK_ARRAYS);
	g_aColor	= ArrayCreate(TOTAL_COLOR_ARRAYS);
	
	new szFile[64], szDir[64], iFile, iSysTime = get_systime(); GET_DIR(szDir); 
	new szBuffer[128], szName[32], szDate[16], szData[1], szTime[3][8], iLine, iLen;
	
	formatex(szFile, charsmax(szFile), "%s/jb_hook/admins.ini", szDir); iFile = fopen(szFile, "rt");
	if(iFile)
	{
		read_file(szFile, iLine, szBuffer, charsmax(szBuffer), iLen);
		
		while(!feof(iFile))
		{
			iLine++; iLen = fgets(iFile, szBuffer, charsmax(szBuffer));
			
			parse(szBuffer, szName, charsmax(szName), szDate, charsmax(szDate));
			
			UTIL_Explode(szDate, '/', szTime, charsmax(szTime), charsmax(szTime[]));
			
			if(iSysTime >= UTIL_TimeToUnix(str_to_num(szTime[2]), str_to_num(szTime[1]), str_to_num(szTime[0])))
			{
				formatex
				(
					szBuffer, charsmax(szBuffer), ";^"%s^" ^"%s^"^t; Срок истек", szName, szDate
				);
				write_file(szFile, szBuffer, iLine - 1);
			}
			else TrieSetString(g_tHook, szName, szDate);
		}

		fclose(iFile);
	}
	else
	{
		if(!dir_exists(DIR_ERROR))
		{
			mkdir(DIR_ERROR);
		}
		new szCurrentTime[16]; GET_TIME(szCurrentTime);
		
		while(replace(szCurrentTime, charsmax(szCurrentTime), "/", "-")) {}
		
		formatex
		(
			szDir, charsmax(szDir), "%s/Hook_%s.txt", DIR_ERROR, szCurrentTime
		);
		
		log_to_file(szDir, "Файл ^"%s^" не найден !", szFile);
	}
	
	formatex(szFile, charsmax(szFile), "%s/jb_hook/hook.ini", szDir); iFile = fopen(szFile, "rt");
	if(iFile)
	{
		new aHook[TOTAL_HOOK_ARRAYS], szWidth[4], szBrightness[4], szSize[4];
		while(!feof(iFile))
		{
			iLen = fgets(iFile, szBuffer, charsmax(szBuffer));
			
			if(!iLen || szBuffer[0] != '"') continue;
			
			strtok(szBuffer, szBuffer, charsmax(szBuffer), szData, charsmax(szData), ';'); trim(szBuffer);
			
			parse
			(
				szBuffer, 
				
				aHook[AI_HOOK_NAME], charsmax(aHook[AI_HOOK_NAME]),
				aHook[AI_HOOK_SOUND], charsmax(aHook[AI_HOOK_SOUND]),
				aHook[AI_HOOK_SPRITE], charsmax(aHook[AI_HOOK_SPRITE]),
				aHook[AI_HOOK_SPRITE2], charsmax(aHook[AI_HOOK_SPRITE2]),
				
				szSize, charsmax(szSize),
				szWidth, charsmax(szWidth),
				szBrightness, charsmax(szBrightness)
			);
			
			aHook[AI_HOOK_SPRITE_SIZE] = str_to_num(szSize);
			aHook[AI_HOOK_SPRITE_WIDTH] = str_to_num(szWidth);
			aHook[AI_HOOK_SPRITE_BRIGHTNESS] = str_to_num(szBrightness);
			
			if(!equal(aHook[AI_HOOK_SOUND], ""))
			{
				PRECACHE_SOUND(aHook[AI_HOOK_SOUND]);
			}
			aHook[AI_HOOK_SPRITE_INDEX] = PRECACHE_MODEL(aHook[AI_HOOK_SPRITE]);
			aHook[AI_HOOK_SPRITE_INDEX2] = PRECACHE_MODEL(aHook[AI_HOOK_SPRITE2]);
			
			ArrayPushArray(g_aHook, aHook);
		}
		g_iHook_ItemsNum = ArraySize(g_aHook);

		fclose(iFile);
	}
	else
	{
		if(!dir_exists(DIR_ERROR))
		{
			mkdir(DIR_ERROR);
		}
		new szCurrentTime[16]; GET_TIME(szCurrentTime);
		
		while(replace(szCurrentTime, charsmax(szCurrentTime), "/", "-")) {}
		
		formatex
		(
			szDir, charsmax(szDir), "%s/Hook_%s.txt", DIR_ERROR, szCurrentTime
		);
		
		log_to_file(szDir, "Файл ^"%s^" не найден !", szFile);
	}
	
	formatex(szFile, charsmax(szFile), "%s/jb_hook/color.ini", szDir); iFile = fopen(szFile, "rt");
	if(iFile)
	{
		new aColor[TOTAL_COLOR_ARRAYS], szColor[12], szRgb[3][4];
		while(!feof(iFile))
		{
			iLen = fgets(iFile, szBuffer, charsmax(szBuffer));
			
			if(!iLen || szBuffer[0] != '"') continue;
			
			strtok(szBuffer, szBuffer, charsmax(szBuffer), szData, charsmax(szData), ';'); trim(szBuffer);
			
			parse(szBuffer, aColor[AI_COLOR_NAME], charsmax(aColor[AI_HOOK_NAME]), szColor, charsmax(szColor));
			
			UTIL_Explode(szColor, ' ', szRgb, charsmax(szRgb), charsmax(szRgb[]));
			
			aColor[AI_COLOR_RGB][0] = str_to_num(szRgb[0]);
			aColor[AI_COLOR_RGB][1] = str_to_num(szRgb[1]);
			aColor[AI_COLOR_RGB][2] = str_to_num(szRgb[2]);
			
			ArrayPushArray(g_aColor, aColor);
		}
		g_iColor_ItemsNum = ArraySize(g_aColor);

		fclose(iFile);
	}
	else
	{
		if(!dir_exists(DIR_ERROR))
		{
			mkdir(DIR_ERROR);
		}
		new szCurrentTime[16]; GET_TIME(szCurrentTime);
		
		while(replace(szCurrentTime, charsmax(szCurrentTime), "/", "-")) {}
		
		formatex
		(
			szDir, charsmax(szDir), "%s/Hook_%s.txt", DIR_ERROR, szCurrentTime
		);
		
		log_to_file(szDir, "Файл ^"%s^" не найден !", szFile);
	}
	
	model_gibs = precache_model("sprites/by_forze/gibs.spr")
	model_gibs2 = precache_model("sprites/by_forze/gibs2.spr") 
	model_gibs3 = precache_model("sprites/by_forze/gibs3.spr") 
	model_gibs4 = precache_model("sprites/by_forze/gibs4.spr")
}

public client_putinserver(pId)
{
	g_iType_Speed[pId] = g_aItemSpeed[1][AI_SPEED_USED];
	
	get_user_ip(pId, g_szUserInfo[pId][USER_INFO_IP], charsmax(g_szUserInfo[][]), 1);
	get_user_name(pId, g_szUserInfo[pId][USER_INFO_NAME], charsmax(g_szUserInfo[][]));
	get_user_authid(pId, g_szUserInfo[pId][USER_INFO_ID], charsmax(g_szUserInfo[][]));
	
	UTIL_FixAdminType(pId);
	plSprite[pId] = 0;
	plEnable[pId] = 0;
	set_task(3.0, "GoHook", pId);
}

public GoHook(id)
{
	if(IsAdmin_Type(id, ADMIN_TYPE_NULL))
		return PLUGIN_HANDLED;
	
	new data[2];
	data[0] = id;
	data[1] = get_user_userid(id);

	new query[512];
	new authid[32];
	new quotedSteamID[32];
	get_user_name(id, authid, 31);
	SQL_QuoteString(g_SQL_Connection, quotedSteamID, 31, authid);
	//client_print(id,print_chat, "1");

	formatex(query, charsmax(query), "SELECT `hook`, `hook2`, `speed`, `effect` FROM `amxx_forze_hook` WHERE `name` = '%s'", quotedSteamID);
	SQL_ThreadQuery(g_SQL_Tuple, "playerLoginHandler", query, data, 2);
	//client_print(id,print_chat, "2");
	return PLUGIN_HANDLED;
}

public client_disconnect(pId)
{
	Save_pl(pId);
	g_iHook[pId][HOOK_INDEX] = NULL;
	g_iHook[pId][HOOK_INDEX2] = NULL;
}

public ClCmd_ShowMenu_Hook(pId)
{
	if(IsAdmin_Type(pId, ADMIN_TYPE_NULL))
	{
		ChatPrint(pId, "%s \rУ тебя нет прав !", CVAR_PREFIX); return PLUGIN_HANDLED;
	}
	ShowMenu_Hook(pId);
	
	return PLUGIN_HANDLED;
}

ShowMenu_Hook(pId)
{
	new szDate[16];
	switch(g_iAdmin_Type[pId])
	{
		case ADMIN_TYPE_IP: 	TrieGetString(g_tHook, g_szUserInfo[pId][USER_INFO_IP], szDate, charsmax(szDate));
		case ADMIN_TYPE_ID:		TrieGetString(g_tHook, g_szUserInfo[pId][USER_INFO_ID], szDate, charsmax(szDate));
		case ADMIN_TYPE_NAME:	TrieGetString(g_tHook, g_szUserInfo[pId][USER_INFO_NAME], szDate, charsmax(szDate));
	}
	
	new szMenu[256], iLen, bitsKeys = KEY(0)|KEY(1)|KEY(2)|KEY(3)|KEY(4)|KEY(5);
	
	MENU_TITLE(szMenu, iLen, "\r[Hook]\y Меню хука:^n");
	MENU_ITEM(szMenu, iLen, "\r- \wХук доступен до: \y%s^n", szDate);
	
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wСменить хук", 1);
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wСменить цвет", 2);
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wСменить скорость", 3);
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wСменить эффект", 4);
	
	if(get_user_flags(pId) & ADMIN_RCON)
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \wВкл/Выкл игроку", 5);
	else
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \dВкл/Выкл игроку", 5);
	
	MENU_ITEM(szMenu, iLen, "^n^n\y[%d] \wВыход", 0);
	
	SHOW_MENU(pId, bitsKeys, szMenu, MenuId_Hook);
}

public ShowMenu_Hook_Handler(pId, iKey)
{
	switch(KEY_HANDLER(iKey))
	{
		case 1: _MENU_CALLBACK_SPRITE(New, pId);
		case 2: _MENU_CALLBACK_COLOR(New, pId);
		case 3: ShowMenu_Speed(pId);
		case 4: MenuSpritess(pId);
		case 5: 
		{
			if(get_user_flags(pId) & ADMIN_RCON)
				RemoveHookMenu(pId)
			else
				ChatPrint(pId, "%s \rУ тебя нет прав !", CVAR_PREFIX);
		}
	}
}

public ShowMenu_Speed(pId)
{
	new szMenu[512], bitsKeys = KEY(0), iLen;
	MENU_TITLE(szMenu, iLen, "\r[Hook]\y Выбор скорости:^n");

	for(new iItem = 0; iItem < sizeof g_aItemSpeed; iItem++)
	{
		if(g_iType_Speed[pId] != g_aItemSpeed[iItem][AI_SPEED_USED])
		{			
			bitsKeys |= KEY(iItem+1);
			
			MENU_ITEM(szMenu, iLen, "^n\y[%d] \w%s", iItem+1, g_aItemSpeed[iItem][AI_SPEED_NAME]);
		}
		else MENU_ITEM(szMenu, iLen, "^n\y[%d] \d%s \y[\r+\y]", iItem+1, g_aItemSpeed[iItem][AI_SPEED_NAME]);
	}
	
	MENU_ITEM(szMenu, iLen, "^n^n\y[%d] \wВыход", 0);
	
	SHOW_MENU(pId, bitsKeys, szMenu, MenuId_Speed);
}

public ShowMenu_Speed_Handler(pId, iKey)
{
	switch(KEY_HANDLER(iKey))
	{
		case 0: return;
		default:
		{
			g_iType_Speed[pId] = iKey;
		}
	}
	
	ShowMenu_Speed(pId);
}

ShowMenu_Sprite_Next(pId, &iPage)
{
	ShowMenu_Sprite(pId, ++iPage);
}

ShowMenu_Sprite_Back(pId, &iPage)
{
	ShowMenu_Sprite(pId, --iPage);
}

ShowMenu_Sprite_Saved(pId, iPage)
{
	ShowMenu_Sprite(pId, iPage);
}

ShowMenu_Sprite_New(pId, &iPage)
{
	ShowMenu_Sprite(pId, iPage = 0);
}

ShowMenu_Sprite(pId, iPage)
{
	if(!IsConnected(pId)) return;
	
	//jbe_informer_offset_up(pId);
	
	new iItemsNum = g_iHook_ItemsNum;
	for(new i = 0; i < iItemsNum; i++)
	{
		g_iMenu_Target[pId][i] = i;
	}
	
	new iStart = min(iPage * CVAR_SPRITE_ITEMS, iItemsNum); 
	iStart -= (iStart % CVAR_SPRITE_ITEMS);
	
	g_iMenu_Page[pId] = iStart / CVAR_SPRITE_ITEMS;
	
	new iEnd = min(iStart + CVAR_SPRITE_ITEMS, iItemsNum);
	
	new szMenu[512], iLen, iPages = (iItemsNum / CVAR_SPRITE_ITEMS + ((iItemsNum % CVAR_SPRITE_ITEMS) ? 1 : 0));
	switch(iPages)
	{
		case 0:
		{
			//jbe_informer_offset_down(pId); return;
		}
		case 1:
		{
			MENU_TITLE(szMenu, iLen, "\r[Hook]\y Выбор хука:^n");
		}
		default:
		{
			MENU_TITLE(szMenu, iLen, "\r[Hook]\y Выбор хука: [%d\w|\y]^n", iPage + 1, iPages);
		}
	}
	
	new bitsKeys = KEY(0);
	for(new i = iStart, iItem = 1, aHook[TOTAL_HOOK_ARRAYS]; i < iEnd; i++, iItem++)
	{
		ArrayGetArray(g_aHook, g_iMenu_Target[pId][i], aHook);
		
		if(!IsHook_Index(pId, iItem - 1))
		{
			bitsKeys |= KEY(iItem);

			MENU_ITEM(szMenu, iLen, "^n\y[%d] \w%s", iItem, aHook[AI_HOOK_NAME]);
		}
		else MENU_ITEM(szMenu, iLen, "^n\y[%d] \d%s \y[\r+\y]", iItem, aHook[AI_HOOK_NAME]);
	}
	MENU_ITEM(szMenu, iLen, "^n");
	
	if(iPage)
	{
		bitsKeys |= KEY(8);
	
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \wНазад", 8);
	}
	
	if(iPages > 1 && iPage + 1 < iPages)
	{
		bitsKeys |= KEY(9);
		
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \wДалее", 9);
	}
	
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wВыход", 0);
	
	SHOW_MENU(pId, bitsKeys, szMenu, MenuId_Sprite);
}

public ShowMenu_Sprite_Handler(pId, iKey)
{
	switch(KEY_HANDLER(iKey))
	{
		case 0: return;
		case 8: _MENU_CALLBACK_SPRITE(Back, pId);
		case 9: _MENU_CALLBACK_SPRITE(Next, pId);
		default:
		{
			g_iHook[pId][HOOK_INDEX] = Player_GetMenuItemTarget(pId, iKey, CVAR_SPRITE_ITEMS);
			
			_MENU_CALLBACK_SPRITE(Saved, pId);
		}
	}
}

ShowMenu_Color_Next(pId, &iPage)
{
	ShowMenu_Color(pId, ++iPage);
}

ShowMenu_Color_Back(pId, &iPage)
{
	ShowMenu_Color(pId, --iPage);
}

ShowMenu_Color_Saved(pId, iPage)
{
	ShowMenu_Color(pId, iPage);
}

ShowMenu_Color_New(pId, &iPage)
{
	ShowMenu_Color(pId, iPage = 0);
}

ShowMenu_Color(pId, iPage)
{
	if(!IsConnected(pId)) return;
	
	//jbe_informer_offset_up(pId);
	
	new iItemsNum = g_iColor_ItemsNum;
	for(new i = 0; i < iItemsNum; i++)
	{
		g_iMenu_Target[pId][i] = i;
	}
	
	new iStart = min(iPage * CVAR_COLOR_ITEMS, iItemsNum); 
	iStart -= (iStart % CVAR_COLOR_ITEMS);
	
	g_iMenu_Page[pId] = iStart / CVAR_COLOR_ITEMS;
	
	new iEnd = min(iStart + CVAR_COLOR_ITEMS, iItemsNum);
	
	new szMenu[512], iLen, iPages = (iItemsNum / CVAR_COLOR_ITEMS + ((iItemsNum % CVAR_COLOR_ITEMS) ? 1 : 0));
	switch(iPages)
	{
		case 0:
		{
			//jbe_informer_offset_down(pId); return;
		}
		case 1:
		{
			MENU_TITLE(szMenu, iLen, "\r[Hook]\y Выбор цвета:^n");
		}
		default:
		{
			MENU_TITLE(szMenu, iLen, "\r[Hook]\y Выбор цвета: [%d\w|\y]^n", iPage + 1, iPages);
		}
	}
	
	new bitsKeys = KEY(0);
	for(new i = iStart, iItem = 1, aColor[TOTAL_COLOR_ARRAYS]; i < iEnd; i++, iItem++)
	{
		ArrayGetArray(g_aColor, g_iMenu_Target[pId][i], aColor);
		
		if(!IsHook_Index2(pId, iItem - 1))
		{
			bitsKeys |= KEY(iItem);

			MENU_ITEM(szMenu, iLen, "^n\y[%d] \w%s", iItem, aColor[AI_COLOR_NAME]);
		}
		else MENU_ITEM(szMenu, iLen, "^n\y[%d] \d%s \y[\r+\y]", iItem, aColor[AI_COLOR_NAME]);
	}
	MENU_ITEM(szMenu, iLen, "^n");
	
	if(iPage)
	{
		bitsKeys |= KEY(8);
	
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \wНазад", 8);
	}
	
	if(iPages > 1 && iPage + 1 < iPages)
	{
		bitsKeys |= KEY(9);
		
		MENU_ITEM(szMenu, iLen, "^n\y[%d] \wДалее", 9);
	}
	
	MENU_ITEM(szMenu, iLen, "^n\y[%d] \wВыход", 0);
	
	SHOW_MENU(pId, bitsKeys, szMenu, MenuId_Color);
}

public ShowMenu_Color_Handler(pId, iKey)
{
	switch(KEY_HANDLER(iKey))
	{
		case 0: return;
		case 8: _MENU_CALLBACK_COLOR(Back, pId);
		case 9: _MENU_CALLBACK_COLOR(Next, pId);
		default:
		{
			g_iHook[pId][HOOK_INDEX2] = Player_GetMenuItemTarget(pId, iKey, CVAR_COLOR_ITEMS);
			
			_MENU_CALLBACK_COLOR(Saved, pId);
		}
	}
}

public FmHook_ClientUserInfoChanged(pId, iBuffer)
{
	if(!IsAlive(pId)) return;
	
	static szName[32];
	engfunc(EngFunc_InfoKeyValue, iBuffer, "name", szName, charsmax(szName));
	
	if(equal(szName, g_szUserInfo[pId][USER_INFO_NAME]))
		return;
	
	g_szUserInfo[pId][USER_INFO_NAME] = szName;
	
	UTIL_FixAdminType(pId);
}

public ClCmd_HookOn(pId)
{
	if(IsAdmin_Type(pId, ADMIN_TYPE_NULL) || task_exists(pId + TASK_HOOK_THINK))
		return PLUGIN_HANDLED;
	
	if(plEnable[pId] == 1)
	{
		MSG(pId)
		return PLUGIN_HANDLED;
	}
	
	
	if(IsAlive(pId))
	{
		new vecOrigin[3]; get_user_origin(pId, vecOrigin, charsmax(vecOrigin));
		
		g_vecHookOrigin[pId][0] = float(vecOrigin[0]);
		g_vecHookOrigin[pId][1] = float(vecOrigin[1]);
		g_vecHookOrigin[pId][2] = float(vecOrigin[2]);
		
		new aHook[TOTAL_HOOK_ARRAYS];
		ArrayGetArray(g_aHook, g_iHook[pId][HOOK_INDEX], aHook);
		
		//UTIL_Sprite(g_vecHookOrigin[pId], aHook[AI_HOOK_SPRITE_INDEX2], 10, 255);
		
		if(!equal(aHook[AI_HOOK_SOUND], ""))
		{
			emit_sound(pId, CHAN_STATIC, aHook[AI_HOOK_SOUND], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		}
		
		Task_HookThink(pId + TASK_HOOK_THINK);
		
		set_task(0.1, "Task_HookThink", pId + TASK_HOOK_THINK, .flags = "b");
	}
	return PLUGIN_HANDLED;
}

public plugin_end()
{
	if (g_SQL_Tuple)
		SQL_FreeHandle(g_SQL_Tuple)
	if (g_SQL_Connection)
		SQL_FreeHandle(g_SQL_Connection)
}

public ClCmd_HookOff(pId)
{
	if(IsAdmin_Type(pId, ADMIN_TYPE_NULL)) return PLUGIN_HANDLED;
	
	if(task_exists(pId + TASK_HOOK_THINK))
	{
		remove_task(pId + TASK_HOOK_THINK);
		
		new aHook[TOTAL_HOOK_ARRAYS];
		ArrayGetArray(g_aHook, g_iHook[pId][HOOK_INDEX], aHook);
		
		if(!equal(aHook[AI_HOOK_SOUND], ""))
		{
			emit_sound(pId, CHAN_STATIC, aHook[AI_HOOK_SOUND], VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM);
		}
		func_break(pId, plSprite[pId]);
	}
	return PLUGIN_HANDLED;
}

public Save_pl(id)
{
	if(IsAdmin_Type(id, ADMIN_TYPE_NULL))
		return PLUGIN_HANDLED;

	static query[512]
	static authid[32]
	static quotedSteamId[32]
	
	get_user_name(id, authid, 31);
	SQL_QuoteString(g_SQL_Connection, quotedSteamId, 31, authid);
		
	formatex(query, charsmax(query), "INSERT INTO `amxx_forze_hook` (`name`, `hook`, `hook2`, `speed`, `effect`) VALUES('%s', %d, %d, %d, %d) ON DUPLICATE KEY UPDATE `hook` = VALUES(`hook`), `hook2` = VALUES(`hook2`), `speed` = VALUES(`speed`), `effect` = VALUES(`effect`)", quotedSteamId, g_iHook[id][HOOK_INDEX], g_iHook[id][HOOK_INDEX2], g_iType_Speed[id], plSprite[id])
	SQL_QueryAndIgnore(g_SQL_Connection, query)
	return PLUGIN_HANDLED;
}

public playerLoginHandler(failState, Handle:query, error[], err, data[], size, Float:queryTime)
{
	if(failState != TQUERY_SUCCESS)
	{
		log_amx("%s Query error %d, %s", PREFIX, err, error)
		return
	}
	
	
	new id = data[0]
	if (get_user_userid(id) != data[1])
		return
		
	if(SQL_NumResults(query))
	{		
		g_iHook[id][HOOK_INDEX] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hook"))
		g_iHook[id][HOOK_INDEX2] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hook2"))
		g_iType_Speed[id] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "speed"))
		plSprite[id] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "effect"))
		client_print(id, print_chat, "%s Данные о паутине успешно загружены.", PREFIX);
	}
}

public MSG(id) client_print(id, print_chat, "Твоя паутина заблокирована гл. Админом.");
public MSGON(id) client_print(id, print_chat, "Твоя паутина разблокирована гл. Админом.");

/*================================================================================
	Меню для игроков онлайн
=================================================================================*/
public RemoveHookMenu(id)
{   
	if(get_user_flags(id) & ADMIN_RCON)
    { 
		new menu = menu_create("\rУправление хуком", "menu_offhook" )
		
		new players[32], pnum, tempid, msg[256]
		new szName[32], szTempid[10]

		get_players(players, pnum)

		for(new i; i<pnum; i++)
		{
			tempid = players[i]

			if(!is_user_connected(tempid))
			{
			}
			
			if(plEnable[tempid] == 0)
			{
				get_user_name(tempid, szName, 31)
				num_to_str(tempid, szTempid, 9)
				formatex(msg, charsmax(msg), "%s \r[Отключить]", szName)
				menu_additem(menu, msg, szTempid)
			}else if(plEnable[tempid] == 1){
				get_user_name(tempid, szName, 31)
				num_to_str(tempid, szTempid, 9)
				formatex(msg, charsmax(msg), "%s \y[Включить]", szName)
				menu_additem(menu, msg, szTempid)
			}
		}
		menu_setprop(menu , MPROP_NEXTNAME, "Далее")
		menu_setprop(menu , MPROP_BACKNAME, "Назад")
		menu_setprop(menu , MPROP_EXITNAME, "Выход")
		menu_setprop(menu , MPROP_EXIT, MEXIT_ALL)
		menu_display(id, menu, 0)
	}
}

public menu_offhook(id, menu, item)
{    
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new data[6], iName[64]
	new access, callback
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)

	new tempid = str_to_num(data)
	
	if(plEnable[tempid] == 0)
	{
		plEnable[tempid] = 1;
		MSG(tempid)
	}else if(plEnable[tempid] == 1){
		plEnable[tempid] = 0;
		MSGON(tempid)
	}
	RemoveHookMenu(id)
	return PLUGIN_HANDLED
}


	

public Task_HookThink(pId)
{
	if(pId > TASK_HOOK_THINK) pId -= TASK_HOOK_THINK;
	
	if(!IsAlive(pId)) return;
	
	new Float:vecVelocity[3], Float:vecOrigin[3]; pev(pId, pev_origin, vecOrigin);
	
	vecVelocity[0] = (g_vecHookOrigin[pId][0] - vecOrigin[0]) * 3.0;
	vecVelocity[1] = (g_vecHookOrigin[pId][1] - vecOrigin[1]) * 3.0;
	vecVelocity[2] = (g_vecHookOrigin[pId][2] - vecOrigin[2]) * 3.0;
	
	new Float:flY = vecVelocity[0] * vecVelocity[0] + vecVelocity[1] * vecVelocity[1] + vecVelocity[2] * vecVelocity[2];
	// new Float:flX = (5 * 120.0) / floatsqroot(flY);
	new Float:flX = (g_aItemSpeed[g_iType_Speed[pId]][AI_SPEED_VALUE]) / floatsqroot(flY);
	
	vecVelocity[0] *= flX;
	vecVelocity[1] *= flX;
	vecVelocity[2] *= flX;
	
	set_pev(pId, pev_velocity, vecVelocity);
	
	new aHook[TOTAL_HOOK_ARRAYS];
	ArrayGetArray(g_aHook, g_iHook[pId][HOOK_INDEX], aHook);
	
	new aColor[TOTAL_COLOR_ARRAYS];
	ArrayGetArray(g_aColor, g_iHook[pId][HOOK_INDEX2], aColor);
	
	UTIL_BeamEntPoint(pId, g_vecHookOrigin[pId], aHook[AI_HOOK_SPRITE_INDEX], 0, 1, 1, aHook[AI_HOOK_SPRITE_SIZE], aHook[AI_HOOK_SPRITE_WIDTH], aColor[AI_COLOR_RGB][0], aColor[AI_COLOR_RGB][1], aColor[AI_COLOR_RGB][2], aHook[AI_HOOK_SPRITE_BRIGHTNESS]);
}

UTIL_BeamEntPoint(pEntity, Float:vecOrigin[3], pSprite, iStartFrame = 0, iFrameRate = 0, iLife, iWidth, iAmplitude = 0, iRed, iGreen, iBlue, iBrightness, iScrollSpeed = 0)
{
	if(!IsAlive(pEntity)) return;
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMENTPOINT);
	write_short(pEntity);
	engfunc(EngFunc_WriteCoord, vecOrigin[0]);
	engfunc(EngFunc_WriteCoord, vecOrigin[1]);
	engfunc(EngFunc_WriteCoord, vecOrigin[2]);
	write_short(pSprite);
	write_byte(iStartFrame);
	write_byte(iFrameRate); // 0.1's
	write_byte(iLife); // 0.1's
	write_byte(iWidth); //Искажение
	write_byte(iAmplitude); // 0.01's
	write_byte(iRed);
	write_byte(iGreen);
	write_byte(iBlue);
	write_byte(iBrightness);
	write_byte(iScrollSpeed); // 0.1's
	message_end();
} 

UTIL_FixAdminType(pId)
{
	if(TrieKeyExists(g_tHook, g_szUserInfo[pId][USER_INFO_NAME]))
	{
		g_iAdmin_Type[pId] = ADMIN_TYPE_NAME;
	}
	else if(TrieKeyExists(g_tHook, g_szUserInfo[pId][USER_INFO_ID]))
	{
		g_iAdmin_Type[pId] = ADMIN_TYPE_ID;
	}
	else if(TrieKeyExists(g_tHook, g_szUserInfo[pId][USER_INFO_IP]))
	{
		g_iAdmin_Type[pId] = ADMIN_TYPE_IP;
	}
	else
	{
		g_iAdmin_Type[pId] = ADMIN_TYPE_NULL;
	}
}

public func_break(pId, num)
{
	new origin[3]
    get_user_origin(pId, origin, 3)
	
	switch(num)
	{	
		case 0: return PLUGIN_CONTINUE;
		case 1:
		{
			message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
			write_byte(TE_SPRITETRAIL) //Спрайт захвата
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+10)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+30)
			write_short(model_gibs)
			write_byte(10)
			write_byte(10)
			write_byte(2)
			write_byte(10)
			write_byte(5)
			message_end()
		}
		case 2:
		{
			message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
			write_byte(TE_SPRITETRAIL) //Спрайт захвата
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+10)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+30)
			write_short(model_gibs2)
			write_byte(10)
			write_byte(10)
			write_byte(2)
			write_byte(10)
			write_byte(5)
			message_end()
		}
		case 3:
		{
			message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
			write_byte(TE_SPRITETRAIL) //Спрайт захвата
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+10)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+30)
			write_short(model_gibs3)
			write_byte(10)
			write_byte(10)
			write_byte(2)
			write_byte(10)
			write_byte(5)
			message_end()
		}
		case 4:
		{
			message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
			write_byte(TE_SPRITETRAIL) //Спрайт захвата
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+10)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+30)
			write_short(model_gibs4)
			write_byte(10)
			write_byte(10)
			write_byte(2)
			write_byte(10)
			write_byte(5)
			message_end()
		}
	}	
	return PLUGIN_CONTINUE;
}