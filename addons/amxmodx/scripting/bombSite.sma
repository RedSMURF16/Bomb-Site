/*
*
*	Bomb Site by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /bs                 "Opens the Bomb Site menu."
*       say_team /bs            "Opens the Bomb Site menu."
*       say /bombsite           "Opens the Bomb Site menu."
*       say_team /bombsite      "Opens the Bomb Site menu."
*       bs_reload               "Reloads the configuration file."
*       bomesite_reload         "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Optimized code,
*             Sites can be expanded without being blocked by other objects,
*             A C4 HUD sprite will be used to indicate the location of a bomb site instead of drawing a decal,
*             Bomb sites can be used with plantable C4 on every map/mode
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT         32
#define MENU_BLINK      0.1

new const PLUGIN_VERSION[]       = "1.1"
new const Float:DELAY_ON_CONNECT = 1.0
new const ERROR_FILE[]           = "BombSite_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS
}

enum
{
    STATE_ACTIVE,
    STATE_INACTIVE
}

enum
{
    FLAG_DEFAULT = (1 << 0),
    FLAG_SELECT  = (1 << 1)
}

enum _:MAIN_SETTINGS
{
    bool:SETTING_BOMB_LOAD,
    bool:SETTING_BOMB_RADAR,
    bool:SETTING_BOMB_ANYWHERE,
    bool:SETTING_BOMB_MAP,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,

    Float:SETTING_SIZE_BASE,
    Float:SETTING_SIZE_HEIGHT_MIN,
    Float:SETTING_SIZE_HEIGHT_MAX,
    Float:SETTING_SIZE_WIDTH_MIN,
    Float:SETTING_SIZE_WIDTH_MAX,

    SETTING_ICON[MAX_RESOURCE_PATH_LENGTH],
    bool:SETTING_ICON_SHOW,
    Float:SETTING_ICON_SCALE,
    SETTING_ICON_ALPHA,

    SETTING_BEAM,
    SETTING_BEAM_COLOR[3]
}

enum _:BOMB
{
    BOMB_ID,
    BOMB_STATE,
    BOMB_FLAGS,
    BOMB_TARGET,
    Float:BOMB_ORIGIN[3],
    Float:BOMB_CORNERS[24],
    Float:BOMB_MINS[3],
    Float:BOMB_MAXS[3],
    Float:BOMB_NEXT_RADAR
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_BOMB_GHOST,
    PDATA_BOMB_MENU,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,
    Float:PDATA_SIZE_X,
    Float:PDATA_SIZE_Y,
    Float:PDATA_SIZE_Z
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_TOGGLE,
    MENU_REMOVE,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_TOGGLE,
    ROOT_REMOVE,
    ROOT_SAVE
}

enum
{
    CREATE_NEW,
    CREATE_RESTORE
}

enum
{
    TOGGLE_NEXT,
    TOGGLE_BACK,
    TOGGLE_CURRENT,
    TOGGLE_ALL_ON,
    TOGGLE_ALL_OFF
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,
    REMOVE_CURRENT,
    REMOVE_ALL
}

enum
{
    SCALE_HEIGHT_ADD,
    SCALE_HEIGHT_SUB,
    SCALE_WIDTH_ADD,
    SCALE_WIDTH_SUB,
    SCALE_PLACE
}

enum _:TASK_MENU
{
    TASK_ID,
    TASK_TYPE
}

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerToggle",
    "menuHandlerRemove",
    "menuHandlerScale"
}

new g_szCN[] = "BombSite"

new Array:g_aBomb,
    Array:g_aBombDefault,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iBomb,
    g_iBombDefault,
    g_iBombDrop,
    g_iStatusIcon

public plugin_init()
{
    register_plugin("Bomb Site", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /bs",            "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /bs",       "cmdMenu", ADMIN_RCON)
    register_clcmd("say /bombsite",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /bombsite", "cmdMenu", ADMIN_RCON)
    register_concmd("bs_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")
    register_concmd("bombsite_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("BombSite.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    RegisterHam(Ham_Spawn, "func_bomb_target", "fwdSpawn", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdTargetSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    RegisterHam(Ham_Item_AddToPlayer, "weapon_c4", "fwdC4Add", 0)
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "fwdC4Plant", 0)

    ReadDefault()
    g_iBombDrop = get_user_msgid("BombDrop")
    g_iStatusIcon = get_user_msgid("StatusIcon")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "bombTask", .flags = "b")

    if ( g_eSettings[SETTING_BOMB_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aBomb = ArrayCreate(BOMB)
    g_aBombDefault = ArrayCreate(BOMB)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBomb)
    ArrayDestroy(g_aBombDefault)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id
    iArg[TASK_TYPE] = MENU_ROOT

    set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_BOMB_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1 ||
    equal(szCmd, "invnext") ||
    equal(szCmd, "invprev") ||
    equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

ReadFile()
{
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/BombSite.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        iSection = SECTION_NONE, iLine, iEnt

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax( szData ), "[", "")
                    replace(szData, charsmax( szData ), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_BOMB_LOAD") )
                        {
                            g_eSettings[SETTING_BOMB_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BOMB_RADAR") )
                        {
                            g_eSettings[SETTING_BOMB_RADAR] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BOMB_ANYWHERE") )
                        {
                            g_eSettings[SETTING_BOMB_ANYWHERE] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_BASE") )
                        {
                            g_eSettings[SETTING_SIZE_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT_MIN") )
                        {
                            g_eSettings[SETTING_SIZE_HEIGHT_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT_MAX") )
                        {
                            g_eSettings[SETTING_SIZE_HEIGHT_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH_MIN") )
                        {
                            g_eSettings[SETTING_SIZE_WIDTH_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH_MAX") )
                        {
                            g_eSettings[SETTING_SIZE_WIDTH_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON") )
                        {
                            copy(g_eSettings[SETTING_ICON], charsmax(g_eSettings[SETTING_ICON]), szValue)
                            if ( !g_bFileWasRead ) precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_SHOW") )
                        {
                            g_eSettings[SETTING_ICON_SHOW] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_SCALE") )
                        {
                            g_eSettings[SETTING_ICON_SCALE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_ALPHA") )
                        {
                            g_eSettings[SETTING_ICON_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM") )
                        {
                            if ( !g_bFileWasRead ) g_eSettings[SETTING_BEAM] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM_COLOR") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BEAM_COLOR][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BEAM_COLOR][1] = str_to_num(szKey)
                            g_eSettings[SETTING_BEAM_COLOR][2] = str_to_num(szValue)
                        }
                    }
                }
            }
        }
    }

    if ( !g_bFileWasRead
    && !(g_eSettings[SETTING_BOMB_MAP] = isBombMap()) )
    {
        iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_bomb_target"))

        if ( pev_valid(iEnt) )
        {
            set_pev(iEnt, pev_origin, Float:{0.0, 0.0, -9999.9})
            dllfunc(DLLFunc_Spawn, iEnt)
        }
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public ReadDefault()
{
    new Float:fOrigin[3],
        Float:fMins[3], Float:fMaxs[3], Float:fCorners[8][3],
        eBomb[BOMB], iEnt = -1

    while ( (iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "func_bomb_target")) )
    {
        if ( !pev_valid(iEnt) )
            continue

        pev(iEnt, pev_absmin, fMins)
        pev(iEnt, pev_absmax, fMaxs)
        xs_vec_add(fMins, fMaxs, fOrigin)
        xs_vec_mul_scalar(fOrigin, 0.5, fOrigin)

        for ( new i = 0; i < 8; i ++ )
        {
            fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
            fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
            fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]
        }

        eBomb[BOMB_ID] = iEnt
        eBomb[BOMB_STATE] = STATE_ACTIVE
        eBomb[BOMB_FLAGS] |= FLAG_DEFAULT
        xs_vec_copy(fOrigin, eBomb[BOMB_ORIGIN])
        xs_vec_copy(fMins, eBomb[BOMB_MINS])
        xs_vec_copy(fMaxs, eBomb[BOMB_MAXS])

        for ( new i = 0; i < 8; i ++ )
            xs_vec_copy(fCorners[i], eBomb[BOMB_CORNERS][i * 3])

        ArrayPushArray(g_aBomb, eBomb)
        ArrayPushArray(g_aBombDefault, eBomb)
        g_iBomb ++
        g_iBombDefault ++
    }
}

public client_authorized(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public bombMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex(szTitle,charsmax(szTitle), "%L", id, "BOMB_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   menuRoot(id, iMenu)
        case MENU_CREATE: menuCreate(id, iMenu)
        case MENU_TOGGLE: menuToggle(id, iMenu)
        case MENU_REMOVE: menuRemove(id, iMenu)
        case MENU_SCALE:  menuScale(id, iMenu)
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_TOGGLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_SAVE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iBomb >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_LIMIT")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_CREATE
                set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_TOGGLE:
        {
            if ( !g_iBomb )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_NO_BOMB")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_TOGGLE
                set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBomb )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_NO_BOMB")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_REMOVE
                set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_CREATE_NEW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_CREATE_RESTORE")
    menu_additem(iMenu, szItem)
}

public menuHandlerCreate(id, menu, item)
{
    new iArg[TASK_MENU],
        eBomb[BOMB]

    iArg[TASK_ID] = id
    switch( item )
    {
        case CREATE_NEW:
        {
            bombCreate(id)

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case CREATE_RESTORE:
        {
            if ( !g_iBombDefault )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_NO_DEFAULT")
            }
            else
            {
                for ( new i = 0; i < g_iBombDefault; i ++ )
                {
                    ArrayGetArray(g_aBombDefault, i, eBomb)

                    if ( !isBombExist(eBomb) )
                        bombCreate(0, i)
                }
            }
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuToggle(id, iMenu)
{
    new szItem[64],
        eBomb[BOMB]

    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_NEXT", g_ePlayerData[id][PDATA_BOMB_MENU] == g_iBomb - 1 ? 1 : g_ePlayerData[id][PDATA_BOMB_MENU] + 2)
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_BACK", g_ePlayerData[id][PDATA_BOMB_MENU] == 0 ? g_iBomb : g_ePlayerData[id][PDATA_BOMB_MENU])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L %L", id, "BOMB_TOGGLE_CURRENT", id, eBomb[BOMB_STATE] == STATE_ACTIVE ? "BOMB_ON" : "BOMB_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_TOGGLE_ALL_ON")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_TOGGLE_ALL_OFF")
    menu_additem(iMenu, szItem)

    eBomb[BOMB_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
}

public menuHandlerToggle(id, menu, item)
{
    new iArg[TASK_MENU],
        eBomb[BOMB]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

    switch( item )
    {
        case TOGGLE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] >= g_iBomb - 1 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] ++

            iArg[TASK_TYPE] = MENU_TOGGLE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = g_iBomb - 1
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] --

            iArg[TASK_TYPE] = MENU_TOGGLE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_CURRENT:
        {
            eBomb[BOMB_STATE] = eBomb[BOMB_STATE] == STATE_ACTIVE ? STATE_INACTIVE : STATE_ACTIVE
            ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_ALL_ON:
        {
            for ( new i = 0; i < g_iBomb; i ++ )
            {
                ArrayGetArray(g_aBomb, i, eBomb)
                eBomb[BOMB_STATE] = STATE_ACTIVE

                ArraySetArray(g_aBomb, i, eBomb)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_ALL_OFF:
        {
            for ( new i = 0; i < g_iBomb; i ++ )
            {
                ArrayGetArray(g_aBomb, i, eBomb)
                eBomb[BOMB_STATE] = STATE_INACTIVE

                ArraySetArray(g_aBomb, i, eBomb)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eBomb[BOMB]

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_NEXT", g_ePlayerData[id][PDATA_BOMB_MENU] == g_iBomb - 1 ? 1 : g_ePlayerData[id][PDATA_BOMB_MENU] + 2)
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_BACK", g_ePlayerData[id][PDATA_BOMB_MENU] == 0 ? g_iBomb : g_ePlayerData[id][PDATA_BOMB_MENU])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_REMOVE_CURRENT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    eBomb[BOMB_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eBomb[BOMB]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] >= g_iBomb - 1 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] ++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = g_iBomb - 1
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] --

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_CURRENT:
        {
            bombKill(eBomb[BOMB_TARGET])
            bombKill(eBomb[BOMB_ID])
            bombRemove(g_ePlayerData[id][PDATA_BOMB_MENU])
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_ALL:
        {
            while ( g_iBomb )
            {
                ArrayGetArray(g_aBomb, 0, eBomb)

                bombKill(eBomb[BOMB_TARGET])
                bombKill(eBomb[BOMB_ID])
                bombRemove(0)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuScale(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_HEIGHT_ADD")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_HEIGHT_SUB")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_WIDTH_ADD")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_WIDTH_SUB")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerScale(id, menu, item)
{
    new eBomb[BOMB], iItem,
        iArg[TASK_MENU]

    iItem = bombFind(g_ePlayerData[id][PDATA_BOMB_GHOST], eBomb)
    iArg[TASK_ID] = id

    switch( item )
    {
        case SCALE_HEIGHT_ADD:
        {
            g_ePlayerData[id][PDATA_SIZE_Z] += 5.0

            if (g_ePlayerData[id][PDATA_SIZE_Z] > g_eSettings[SETTING_SIZE_HEIGHT_MAX])
                g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_HEIGHT_MAX]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_HEIGHT_SUB:
        {
            g_ePlayerData[id][PDATA_SIZE_Z] -= 5.0

            if (g_ePlayerData[id][PDATA_SIZE_Z] < g_eSettings[SETTING_SIZE_HEIGHT_MIN])
                g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_HEIGHT_MIN]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_WIDTH_ADD:
        {
            g_ePlayerData[id][PDATA_SIZE_X] += 5.0

            if (g_ePlayerData[id][PDATA_SIZE_X] > g_eSettings[SETTING_SIZE_WIDTH_MAX])
                g_ePlayerData[id][PDATA_SIZE_X] = g_eSettings[SETTING_SIZE_WIDTH_MAX]

            g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_X]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_WIDTH_SUB:
        {
            g_ePlayerData[id][PDATA_SIZE_X] -= 5.0

            if (g_ePlayerData[id][PDATA_SIZE_X] < g_eSettings[SETTING_SIZE_WIDTH_MIN])
                g_ePlayerData[id][PDATA_SIZE_X] = g_eSettings[SETTING_SIZE_WIDTH_MIN]

            g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_X]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_PLACE:
        {
            if ( iItem != -1 )
            {
                bombTrace(eBomb, id)

                g_ePlayerData[id][PDATA_BOMB_GHOST] = 0
                pev(eBomb[BOMB_ID], pev_origin, eBomb[BOMB_ORIGIN])

                eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
                bombSetActive(eBomb)
                ArraySetArray(g_aBomb, iItem, eBomb)

                iArg[TASK_TYPE] = MENU_ROOT
                set_task(MENU_BLINK, "bombMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        default:
        {
            bombKill(eBomb[BOMB_ID])
            bombRemove(iItem)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public bombTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eBomb[BOMB], iEnt

    get_players(iPlayers, iNum, "ach")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iEnt = g_ePlayerData[id][PDATA_BOMB_GHOST]

        if ( !iEnt || bombFind(iEnt, eBomb) == -1 )
            continue

        bombTrace(eBomb, id)
    }

    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)

        if ( eBomb[BOMB_STATE] == STATE_ACTIVE
        && g_eSettings[SETTING_BOMB_RADAR]
        && get_gametime() >= eBomb[BOMB_NEXT_RADAR] )
            bombRadar(eBomb)

        if ( eBomb[BOMB_FLAGS] & FLAG_SELECT )
            bombBeam(eBomb)

        ArraySetArray(g_aBomb, i, eBomb)
    }
}

stock targetCreate(Float:fOrigin[3])
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return 0

    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_origin, fOrigin)

    if ( g_eSettings[SETTING_ICON_SHOW] )
        engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_ICON])

    dllfunc(DLLFunc_Spawn, iEnt)
    return iEnt
}

stock bombCreate(id, iItem = -1)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_bomb_target"))

    if ( !pev_valid(iEnt) )
        return

    new eBomb[BOMB]
    set_pev(iEnt, pev_classname, g_szCN)

    if ( iItem != -1 )
    {
        ArrayGetArray(g_aBombDefault, iItem, eBomb)

        eBomb[BOMB_ID] = iEnt
        eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
        set_pev(iEnt, pev_origin, eBomb[BOMB_ORIGIN])
        dllfunc(DLLFunc_Spawn, iEnt)

        bombSetActive(eBomb)
    }
    else
    {
        if ( id )
        {
            g_ePlayerData[id][PDATA_BOMB_GHOST] = iEnt
            g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
            g_ePlayerData[id][PDATA_SIZE_X] = g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_BASE]
        }

        eBomb[BOMB_ID] = iEnt
        eBomb[BOMB_STATE] = STATE_INACTIVE
        dllfunc(DLLFunc_Spawn, iEnt)
    }

    ArrayPushArray(g_aBomb, eBomb)
    g_iBomb ++
}

public bombRemove(iItem)
{
    ArrayDeleteItem(g_aBomb, iItem)
    g_iBomb --
}

public iconRemove(id)
{
    message_begin(MSG_ONE_UNRELIABLE, g_iStatusIcon, .player = id)
    write_byte(0)
    write_string("c4")
    write_byte(0)
    write_byte(0)
    write_byte(0)
    message_end()
}

public saveData(id)
{
    new eBomb[BOMB],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BombSite.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eBomb[BOMB_ORIGIN][0], eBomb[BOMB_ORIGIN][1], eBomb[BOMB_ORIGIN][2])
        fputs(iFile, szData)

        for ( new j = 0; j < 8; j ++ )
        {
            formatex(szData, charsmax(szData), "corner_%d = %.2f %.2f %.2f^n",
            j + 1, eBomb[BOMB_CORNERS][j * 3], eBomb[BOMB_CORNERS][j * 3 + 1], eBomb[BOMB_CORNERS][j * 3 + 2])
            fputs(iFile, szData)
        }
    }

    client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_SAVED")
    fclose(iFile)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fCorners[8][3],
        eBomb[BOMB], iCorner, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BombSite.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "BOMB_CHAT_TAG", 0, "BOMB_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                bombCreate(0)
                ArrayGetArray(g_aBomb, iCount, eBomb)

                eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
                xs_vec_copy(fOrigin, eBomb[BOMB_ORIGIN])
                for ( new i = 0; i < 8; i ++ )
                    xs_vec_copy(fCorners[i], eBomb[BOMB_CORNERS][i * 3])

                set_pev(eBomb[BOMB_ID], pev_origin, fOrigin)
                bombSetBox(eBomb, 0)
                bombSetActive(eBomb)
                ArraySetArray(g_aBomb, iCount, eBomb)
            }

            iCount++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'c':
                {
                    iCorner = str_to_num(szKey[strlen(szKey) - 1])

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fCorners[iCorner - 1][0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fCorners[iCorner - 1][1] = str_to_float(szKey)
                    fCorners[iCorner - 1][2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        bombCreate(0)
        ArrayGetArray(g_aBomb, iCount, eBomb)

        eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
        xs_vec_copy(fOrigin, eBomb[BOMB_ORIGIN])
        for ( new i = 0; i < 8; i ++ )
            xs_vec_copy(fCorners[i], eBomb[BOMB_CORNERS][i * 3])

        set_pev(eBomb[BOMB_ID], pev_origin, fOrigin)
        bombSetBox(eBomb, 0)
        bombSetActive(eBomb)
        ArraySetArray(g_aBomb, iCount, eBomb)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_BOMB_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isBombSite(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)

    return HAM_IGNORED
}

public fwdTargetSpawn(iEnt)
{
    if ( !isBombSite(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
    set_pev(iEnt, pev_scale, g_eSettings[SETTING_ICON_SCALE])
    set_rendering(iEnt, kRenderNormal, 255, 255, 255, kRenderTransAdd, g_eSettings[SETTING_ICON_ALPHA])

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_BOMB_GHOST] )
    {
        new eBomb[BOMB], iItem

        if ( (iItem = bombFind(g_ePlayerData[id][PDATA_BOMB_GHOST], eBomb)) != -1 )
        {
            bombKill(eBomb[BOMB_ID])
            bombRemove(iItem)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0
        }
    }

    return HAM_IGNORED
}

public fwdC4Add(iEnt, id)
{
    if ( !g_eSettings[SETTING_BOMB_MAP]
    && !g_eSettings[SETTING_BOMB_ANYWHERE] )
    {
        iconRemove(id)
        return HAM_SUPERCEDE
    }

    return HAM_IGNORED
}

public fwdC4Plant(iEnt)
{
    new id
    id = pev(iEnt, pev_owner)

    return isBombActive(id)
    && (g_eSettings[SETTING_BOMB_MAP] || g_eSettings[SETTING_BOMB_ANYWHERE]) ? HAM_IGNORED : HAM_SUPERCEDE
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton
    iButton = pev(id, pev_button)

    if ( g_ePlayerData[id][PDATA_BOMB_GHOST] )
    {
        if ( get_gametime() >= g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    return HAM_IGNORED
}

public bombTrace(eBomb[BOMB], id)
{
    new Float:fVec1[3]

    pev(id, pev_origin, eBomb[BOMB_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eBomb[BOMB_ORIGIN], fVec1, eBomb[BOMB_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eBomb[BOMB_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eBomb[BOMB_ORIGIN], fVec1, IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eBomb[BOMB_ORIGIN])

    bombSetBox(eBomb, id)
    bombSetOffset(eBomb)
    bombSetBox(eBomb, id)
    bombBeam(eBomb)

    set_pev(eBomb[BOMB_ID], pev_origin, eBomb[BOMB_ORIGIN])
}

stock bombSetBox(eBomb[BOMB], id)
{
    if ( id )
        boxCorners(eBomb, id)

    for ( new i = 0; i < 3; i ++ )
    {
        eBomb[BOMB_MINS][i] = eBomb[BOMB_CORNERS][i]
        eBomb[BOMB_MAXS][i] = eBomb[BOMB_CORNERS][i]
    }

    for ( new i = 1; i < 8; i ++ )
    {
        for ( new j = 0; j < 3; j ++ )
        {
            eBomb[BOMB_MINS][j] = floatmin(eBomb[BOMB_MINS][j], eBomb[BOMB_CORNERS][i * 3 + j])
            eBomb[BOMB_MAXS][j] = floatmax(eBomb[BOMB_MAXS][j], eBomb[BOMB_CORNERS][i * 3 + j])
        }
    }
}

public boxCorners(eBomb[BOMB], id)
{
    eBomb[BOMB_CORNERS][0]  = eBomb[BOMB_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][1]  = eBomb[BOMB_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][2]  = eBomb[BOMB_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][3]  = eBomb[BOMB_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][4]  = eBomb[BOMB_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][5]  = eBomb[BOMB_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][6]  = eBomb[BOMB_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][7]  = eBomb[BOMB_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][8]  = eBomb[BOMB_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][9]  = eBomb[BOMB_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][10] = eBomb[BOMB_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][11] = eBomb[BOMB_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][12] = eBomb[BOMB_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][13] = eBomb[BOMB_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][14] = eBomb[BOMB_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][15] = eBomb[BOMB_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][16] = eBomb[BOMB_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][17] = eBomb[BOMB_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][18] = eBomb[BOMB_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][19] = eBomb[BOMB_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][20] = eBomb[BOMB_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBomb[BOMB_CORNERS][21] = eBomb[BOMB_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBomb[BOMB_CORNERS][22] = eBomb[BOMB_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBomb[BOMB_CORNERS][23] = eBomb[BOMB_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]
}

stock bombSetOffset(eBomb[BOMB])
{
    new Float:fVec1[3],
        Float:fGap, Float:fDist

    xs_vec_sub(eBomb[BOMB_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
    engfunc(EngFunc_TraceLine, eBomb[BOMB_ORIGIN], fVec1, IGNORE_MONSTERS, eBomb[BOMB_ID], 0)
    get_tr2(0, TR_vecEndPos, fVec1)
    fDist = xs_vec_distance(eBomb[BOMB_ORIGIN], fVec1)
    fGap = eBomb[BOMB_ORIGIN][2] - eBomb[BOMB_MINS][2]

    if ( fDist < (fGap + 1.0) )
    {
        get_tr2(0, TR_vecPlaneNormal, fVec1)
        xs_vec_mul_scalar(fVec1, (fGap + 1.0) - fDist, fVec1)
        xs_vec_add(eBomb[BOMB_ORIGIN], fVec1, eBomb[BOMB_ORIGIN])
    }
}

stock bombSetActive(eBomb[BOMB])
{
    new Float:fVec1[3],
        Float:fMins[3], Float:fMaxs[3]

    set_pev(eBomb[BOMB_ID], pev_solid, SOLID_TRIGGER)
    set_pev(eBomb[BOMB_ID], pev_movetype, MOVETYPE_NONE)
    xs_vec_sub(eBomb[BOMB_MINS], eBomb[BOMB_ORIGIN], fMins)
    xs_vec_sub(eBomb[BOMB_MAXS], eBomb[BOMB_ORIGIN], fMaxs)

    xs_vec_copy(eBomb[BOMB_ORIGIN], fVec1)
    eBomb[BOMB_TARGET] = targetCreate(fVec1)
    eBomb[BOMB_STATE] = STATE_ACTIVE

    engfunc(EngFunc_SetSize, eBomb[BOMB_ID], fMins, fMaxs)
}

stock bombBeam(eBomb[BOMB])
{
    new Float:fCorners[8][3]

    xs_vec_copy(eBomb[BOMB_CORNERS][0],  fCorners[0])
    xs_vec_copy(eBomb[BOMB_CORNERS][3],  fCorners[1])
    xs_vec_copy(eBomb[BOMB_CORNERS][6],  fCorners[2])
    xs_vec_copy(eBomb[BOMB_CORNERS][9],  fCorners[3])
    xs_vec_copy(eBomb[BOMB_CORNERS][12], fCorners[4])
    xs_vec_copy(eBomb[BOMB_CORNERS][15], fCorners[5])
    xs_vec_copy(eBomb[BOMB_CORNERS][18], fCorners[6])
    xs_vec_copy(eBomb[BOMB_CORNERS][21], fCorners[7])

    beamDraw(fCorners[0], fCorners[1])
    beamDraw(fCorners[1], fCorners[3])
    beamDraw(fCorners[3], fCorners[2])
    beamDraw(fCorners[2], fCorners[0])

    beamDraw(fCorners[0], fCorners[4])
    beamDraw(fCorners[1], fCorners[5])
    beamDraw(fCorners[2], fCorners[6])
    beamDraw(fCorners[3], fCorners[7])

    beamDraw(fCorners[4], fCorners[5])
    beamDraw(fCorners[5], fCorners[7])
    beamDraw(fCorners[7], fCorners[6])
    beamDraw(fCorners[6], fCorners[4])
}

stock beamDraw(Float:fStart[3], Float:fEnd[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fStart)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(fStart[0])
    write_coord_f(fStart[1])
    write_coord_f(fStart[2])
    write_coord_f(fEnd[0])
    write_coord_f(fEnd[1])
    write_coord_f(fEnd[2])
    write_short(g_eSettings[SETTING_BEAM])
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(5)
    write_byte(0)
    write_byte(g_eSettings[SETTING_BEAM_COLOR][0])
    write_byte(g_eSettings[SETTING_BEAM_COLOR][1])
    write_byte(g_eSettings[SETTING_BEAM_COLOR][2])
    write_byte(255)
    write_byte(0)
    message_end()
}

stock bombRadar(eBomb[BOMB])
{
    message_begin(MSG_BROADCAST, g_iBombDrop)
    write_coord_f(eBomb[BOMB_ORIGIN][0])
    write_coord_f(eBomb[BOMB_ORIGIN][1])
    write_coord_f(eBomb[BOMB_ORIGIN][2])
    write_byte(0)
    message_end()

    eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
}

stock bool:isBombSite(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    return bool:equali(szEnt, g_szCN)
}

stock bool:isBombMap()
{
    new iEnt = -1

    iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "info_bomb_target")
    return iEnt > 0
}

stock bool:isBombExist(eBombDefault[BOMB])
{
    new eBomb[BOMB],
        Float:fDiff[3]

    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)

        xs_vec_sub(eBombDefault[BOMB_ORIGIN], eBomb[BOMB_ORIGIN], fDiff)
        if ( floatabs(fDiff[0]) < 1.0
        && floatabs(fDiff[1]) < 1.0
        && floatabs(fDiff[2]) < 1.0 )
            return true
    }

    return false
}

stock bool:isBombActive(id)
{
    new eBomb[BOMB],
        Float:fOrigin[3]

    pev(id, pev_origin, fOrigin)
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)

        if ( eBomb[BOMB_STATE] != STATE_ACTIVE )
            continue

        if ( fOrigin[0] >= eBomb[BOMB_MINS][0] - 25.0 && fOrigin[0] <= eBomb[BOMB_MAXS][0] + 25.0
        && fOrigin[1] >= eBomb[BOMB_MINS][1] - 25.0 && fOrigin[1] <= eBomb[BOMB_MAXS][1] + 25.0
        && fOrigin[2] >= eBomb[BOMB_MINS][2] - 25.0 && fOrigin[2] <= eBomb[BOMB_MAXS][2] + 25.0 )
            return true
    }

    return false
}

stock bombKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

public bombFind(iEnt, eBomb[BOMB])
{
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        if ( eBomb[BOMB_ID] == iEnt )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}