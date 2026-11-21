/*
*
*	Bomb Site by RedSMURF
*
*
*	Description:
*       This plugin gives full control over bomb sites, you can create, remove and toggle their status during game play.
*       It saves your custom bomb site setups/locations and automatically loads them every map start.
*       The plugin comes with a config file "configs/BombSite.ini" to control some main settings
*       like placing Bomb Sites in all maps, instead of bomb maps only or showing Bomb Sites on the radar.
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
*             Bomb sites can be used with plantable C4 on every map/mode.
*       v1.2: Sprite color changes based on State,
*             Radar visibility can be configured for Terrorists, CTs, both teams or disabled.
*       v1.3: Added independent axis scaling, mode toggle (Add/Remove), and factor control for precise box resizing,
*             Added noclip for players placing Bomb Sites for easier positioning
*       v1.4: Bug fixes and config improvements.
*       v1.5: Added per-Bomb Site configuration.
*       v1.6: added FLAG_ACTIVE_DURATION, improved round-start logic.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
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

#define MAX_ENT                     32
#define ADMIN_ACCESS                ADMIN_RCON
#define BOMB_KEY                    988822
#define BOMB_ARRAY_ITEM             pev_iuser1
#define PDATA_NEXT_ATTACK           83
#define XO_CBASEPLAYER              5
#define XO_CBASEPLAYERWEAPON        4
#define BOMB_CHECK                  10.0
#define BOMB_OFFSET_BASE            90.0
#define BOMB_OFFSET_MIN             42.0
#define BOMB_OFFSET_MAX             900.0
#define BOMB_OFFSET_STEP            10.0
#define SIZE_BASE                   32.0
#define SIZE_HEIGHT_MIN             5.0
#define SIZE_HEIGHT_MAX             1500.0
#define SIZE_WIDTH_MIN              5.0
#define SIZE_WIDTH_MAX              1500.0
#define SIZE_DEPTH_MIN              5.0
#define SIZE_DEPTH_MAX              1500.0
#define PDATA_NEXT_ATTACK           83
#define XO_CBASEPLAYER              5
#define XO_CBASEPLAYERWEAPON        4
#define SOUND_NAV                   "buttons/blip1.wav"
#define SOUND_REMOVE                "buttons/button10.wav"
#define SOUND_ALERT                 "buttons/bell1.wav"
#define BEAM_WIDTH                  5
#define BEAM_ALPHA                  255
#define BEAM_SPRITE                 "sprites/white.spr"

new const PLUGIN_VERSION[]       = "1.7"
new const Float:DELAY_ON_LOAD    = 2.0
new const ERROR_FILE[]           = "BombSite_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_BOMB
}

enum
{
    DTYPE_INT,
    DTYPE_FLOAT,
    DTYPE_FLAGS,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_ARRAY_MESSAGE,
    DTYPE_ARRAY_MODEL,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL_ID,
    DTYPE_ARRAY_MODEL_ID
}

enum
{
    FLAG_ICON               = (1 << 0),

    FLAG_SELECT             = (1 << 1),
    FLAG_ACTIVE             = (1 << 2)
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    ICON_HIDE,
    ICON_DRAW,
    ICON_FLASH
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_SPRITE_ICON[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_RADAR,
    Float:SETTING_DEFAULT_ICON_SCALE,
    Float:SETTING_DEFAULT_ICON_ALPHA,
    bool:SETTING_BOMB_LOAD,
    Float:SETTING_BOMB_TASK,
    bool:SETTING_BOMB_DEFAULT,
    bool:SETTING_BOMB_ANYWHERE
}

enum _:BOMB
{
    BOMB_ID,
    BOMB_ITEM,
    BOMB_FLAGS,
    BOMB_RADAR,
    BOMB_ICON,
    BOMB_NAME[MAX_VALUE_LENGTH],

    Float:BOMB_SCALE[3],
    Float:BOMB_ORIGIN[3],
    Float:BOMB_CORNERS[24],
    Float:BOMB_MINS[3],
    Float:BOMB_MAXS[3],
    Float:BOMB_NEXT_RADAR
}

enum _:PLAYER_DATA
{
    PDATA_BOMB_GHOST,
    PDATA_BOMB_MENU,
    bool:PDATA_BOMB_ACTION,
    bool:PDATA_SCALE_UP,
    PDATA_SCALE_FACTOR,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_STATUS,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SCALE_HEIGHT,
    SCALE_WIDTH,
    SCALE_DEPTH,

    SCALE_FACTOR = 4,
    SCALE_MODE,
    SCALE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerStatus",
    "menuHandlerScale"
}

new Float:g_fScaleFactor[] = {5.0, 10.0, 20.0, 30.0, 45.0, 60.0}
new g_szCN[] = "bombsite"

new Array:g_aBomb,
    Array:g_aBombConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false, g_iActivePlayers, bool:g_bBombMap,
    HamHook:g_iFwdPreThink, HamHook:g_iFwdKilled,
    g_iBomb, g_iBombConfig, g_iBeam,
    g_iBombDrop, g_iHostagePos, g_iHostageK, g_iStatusIcon, g_iPlayerBomb,
    g_iMaxPlayers

public plugin_init()
{
    register_plugin("Bomb Site", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_BombSite", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("say /bs",            "cmdMenu", ADMIN_RCON, "-- Opens the Bomb Site menu.")
    register_clcmd("say_team /bs",       "cmdMenu", ADMIN_RCON, "-- Opens the Bomb Site menu.")
    register_clcmd("say /bombsite",      "cmdMenu", ADMIN_RCON, "-- Opens the Bomb Site menu.")
    register_clcmd("say_team /bombsite", "cmdMenu", ADMIN_RCON, "-- Opens the Bomb Site menu.")
    register_concmd("bs_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")
    register_concmd("bombsite_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("BombSite.txt")

    register_forward(FM_SetModel, "fwdSetModel", 1)
    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iFwdKilled = RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    RegisterHam(Ham_Item_AddToPlayer, "weapon_c4", "fwdAddC4")
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_c4", "fwdPlantC4")
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    register_event("StatusIcon", "eventStatusIcon", "bef", "1=2", "2=c4")
    g_iBombDrop = get_user_msgid("BombDrop")
    g_iHostagePos = get_user_msgid("HostagePos")
    g_iHostageK = get_user_msgid("HostageK")
    g_iStatusIcon = get_user_msgid("StatusIcon")
    DisableForward()

    bombInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aBomb = ArrayCreate(BOMB)
    g_aBombConfig = ArrayCreate(BOMB)
    g_iBeam = precache_model(BEAM_SPRITE)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBomb)
    ArrayDestroy(g_aBombConfig)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    bombSound(id, SOUND_MENU_NAV)
    bombMenu(id, MENU_ROOT)

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

public eventRoundStart()
{
    bombReset()
}

public eventStatusIcon(id)
{
    new eBomb[BOMB]
    if ( isBombActive(eBomb, id) )
        iconDraw(id, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? ICON_FLASH : ICON_DRAW)
    else
        iconDraw(id, g_eSettings[SETTING_BOMB_DEFAULT] ? ICON_FLASH : ICON_DRAW)

    return PLUGIN_CONTINUE
}

stock ReadFile()
{
    if ( g_bFileWasRead )
    {
        ArrayClear(g_aBombConfig)
        g_iBombConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
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
        eBomb[BOMB], iSection = SECTION_NONE, iLine, iEnt, iPos

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
                    else
                    {
                        if ( g_iBombConfig )
                            ArrayPushArray(g_aBombConfig, eBomb)

                        copy(eBomb[BOMB_NAME], charsmax(eBomb[BOMB_NAME]), szData)
                        eBomb[BOMB_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eBomb[BOMB_RADAR]               = g_eSettings[SETTING_DEFAULT_RADAR]

                        iSection = SECTION_BOMB
                        g_iBombConfig ++
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
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_SPRITE_ICON") )
                            parseSetting(DTYPE_STRING_MODEL, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPRITE_ICON], charsmax(g_eSettings[SETTING_DEFAULT_SPRITE_ICON]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_RADAR") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_RADAR], charsmax(g_eSettings[SETTING_DEFAULT_RADAR]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_SCALE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ICON_SCALE], charsmax(g_eSettings[SETTING_DEFAULT_ICON_SCALE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_ALPHA") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ICON_ALPHA], charsmax(g_eSettings[SETTING_DEFAULT_ICON_ALPHA]))
                        else if ( equali(szKey, "SETTING_BOMB_LOAD") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BOMB_LOAD], charsmax(g_eSettings[SETTING_BOMB_LOAD]))
                        else if ( equali(szKey, "SETTING_BOMB_TASK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_BOMB_TASK], charsmax(g_eSettings[SETTING_BOMB_TASK]))
                        else if ( equali(szKey, "SETTING_BOMB_DEFAULT") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BOMB_DEFAULT], charsmax(g_eSettings[SETTING_BOMB_DEFAULT]))
                        else if ( equali(szKey, "SETTING_BOMB_ANYWHERE") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BOMB_ANYWHERE], charsmax(g_eSettings[SETTING_BOMB_ANYWHERE]))
                    }
                    case SECTION_BOMB:
                    {
                        if ( equali(szKey, "BOMB_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), eBomb[BOMB_FLAGS], charsmax(eBomb[BOMB_FLAGS]))
                        else if ( equali(szKey, "BOMB_RADAR") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eBomb[BOMB_RADAR], charsmax(eBomb[BOMB_RADAR]))
                    }
                }
            }
        }
    }

    if ( g_iBombConfig )
        ArrayPushArray(g_aBombConfig, eBomb)
    else
        set_fail_state("No Bomb Sites were found in the configuration file.")

    if ( !g_bFileWasRead )
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

public client_disconnected(id)
{
    new eBomb[BOMB], iItem
    if ( g_ePlayerData[id][PDATA_BOMB_GHOST]
    && (iItem = bombGet(eBomb, g_ePlayerData[id][PDATA_BOMB_GHOST])) != -1 )
    {
        bombKill(eBomb[BOMB_ID])
        bombRemove(iItem)
    }

    DisableAction(id)
    g_ePlayerData[id][PDATA_BOMB_GHOST]  = 0
    g_ePlayerData[id][PDATA_BOMB_MENU]   = 0
}

public bombInit()
{
    g_bBombMap = isBombMap()

    if ( g_eSettings[SETTING_BOMB_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

stock bombTerminate()
{
    new eBomb[BOMB]
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aBomb, i, eBomb)
    }
}

stock bombMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[256], iMenu
    formatex(szData, charsmax(szData), "%L", id, "BOMB_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:         { menuRoot(id, iMenu); }
        case MENU_CREATE:       { menuCreate(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_ROOT_CREATE"); }
        case MENU_EDIT:         { menuEdit(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_ROOT_EDIT"); }
        case MENU_REMOVE:       { menuRemove(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_ROOT_REMOVE"); }
        case MENU_STATUS:       { menuStatus(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_ROOT_STATUS"); }
        case MENU_SCALE:        { menuScale(id, iMenu);         format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_ROOT_SCALE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "BOMB_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_NOCLIP", id, (pev(id, pev_movetype) == MOVETYPE_NOCLIP) ? "BOMB_ON" : "BOMB_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_ROOT_GODMODE", id, (pev(id, pev_takedamage) == DAMAGE_NO) ? "BOMB_ON" : "BOMB_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iBomb >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_LIMIT", MAX_ENT)

                bombSound(id, SOUND_MENU_REMOVE)
                bombMenu(id, MENU_ROOT)
            }
            else
            {
                bombSound(id, SOUND_MENU_NAV)
                bombMenu(id, MENU_CREATE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iBomb )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_NO_BOMB")

                bombSound(id, SOUND_MENU_REMOVE)
                bombMenu(id, MENU_ROOT)
            }
            else
            {
                bombSound(id, SOUND_MENU_NAV)
                bombMenu(id, MENU_EDIT)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBomb )
            {
                client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_NO_BOMB")

                bombSound(id, SOUND_MENU_REMOVE)
                bombMenu(id, MENU_ROOT)
            }
            else
            {
                bombSound(id, SOUND_MENU_REMOVE)
                bombMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            bombNoClip(id)
        }
        case ROOT_GODMODE:
        {
            bombGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(id, iMenu)
{
    new eBomb[BOMB], szItem[64]

    for ( new i = 0; i < g_iBombConfig; i ++ )
    {
        ArrayGetArray(g_aBombConfig, i, eBomb)

        copy(szItem, charsmax(szItem), eBomb[BOMB_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    else if ( item == MENU_EXIT )
    {
        bombSound(id, SOUND_MENU_NAV)
        bombMenu(id, MENU_ROOT)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    bombCreate(id, item)
    bombSound(id, SOUND_MENU_NAV)
    bombMenu(id, MENU_SCALE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_STATUS:
        {
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eBomb[BOMB]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_REMOVE_CURRENT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    bombSelect(eBomb, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
}

public menuHandlerRemove(id, menu, item)
{
    new eBomb[BOMB]
    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        bombSelect(eBomb, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? TARGET_HIDE : TARGET_GHOST)
        ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    }

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] >= g_iBomb - 1 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] ++

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = g_iBomb - 1
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] --

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            eBomb[BOMB_FLAGS] &= ~FLAG_ACTIVE
            bombKill(eBomb[BOMB_ID])
            bombRemove(g_ePlayerData[id][PDATA_BOMB_MENU])

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_REMOVE_CURRENT")
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0

            bombSound(id, g_iBomb > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            bombMenu(id, g_iBomb > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iBomb )
            {
                ArrayGetArray(g_aBomb, 0, eBomb)
                eBomb[BOMB_FLAGS] &= ~FLAG_ACTIVE

                bombKill(eBomb[BOMB_ID])
                bombRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0

            bombSound(id, SOUND_MENU_ALERT)
            bombMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                bombSound(id, SOUND_MENU_NAV)
                bombMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eBomb[BOMB]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_STATUS_CURRENT", id, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? "BOMB_ENABLED" : "BOMB_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    bombSelect(eBomb, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
}

public menuHandlerStatus(id, menu, item)
{
    new eBomb[BOMB]
    ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        bombSelect(eBomb, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? TARGET_HIDE : TARGET_GHOST)
        ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
    }

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] >= g_iBomb - 1 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] ++

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BOMB_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BOMB_MENU] = g_iBomb - 1
            else
                g_ePlayerData[id][PDATA_BOMB_MENU] --

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            eBomb[BOMB_FLAGS] ^= FLAG_ACTIVE
            iconColor(eBomb)

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_STATUS_CURRENT",
            id, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? "BOMB_CHAT_ENABLED" : "BOMB_CHAT_DISABLED")
            ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iBomb; i ++ )
            {
                ArrayGetArray(g_aBomb, i, eBomb)
                eBomb[BOMB_FLAGS] |= FLAG_ACTIVE
                iconColor(eBomb)

                ArraySetArray(g_aBomb, i, eBomb)
            }

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_STATUS_ALL_ENABLED")
            bombSound(id, SOUND_MENU_ALERT)
            bombMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iBomb; i ++ )
            {
                ArrayGetArray(g_aBomb, i, eBomb)
                eBomb[BOMB_FLAGS] &= ~FLAG_ACTIVE
                iconColor(eBomb)

                ArraySetArray(g_aBomb, i, eBomb)
            }

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_STATUS_ALL_DISABLED")
            bombSound(id, SOUND_MENU_ALERT)
            bombMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                bombSound(id, SOUND_MENU_NAV)
                bombMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BOMB_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BOMB_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuScale(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_HEIGHT", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BOMB_ADD" : "BOMB_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_WIDTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BOMB_ADD" : "BOMB_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_DEPTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BOMB_ADD" : "BOMB_REMOVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_FACTOR", g_ePlayerData[id][PDATA_SCALE_UP] ? "\y" : "\r", g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_MODE", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BOMB_INCREASE" : "BOMB_DECREASE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BOMB_SCALE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerScale(id, menu, item)
{
    new eBomb[BOMB], iItem
    if ( (iItem = bombGet(eBomb, g_ePlayerData[id][PDATA_BOMB_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case SCALE_HEIGHT:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBomb[BOMB_SCALE][2] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][2] > SIZE_HEIGHT_MAX )
                        eBomb[BOMB_SCALE][2] = SIZE_HEIGHT_MAX
                }
            else
            {
                eBomb[BOMB_SCALE][2] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][2] < SIZE_HEIGHT_MIN )
                    eBomb[BOMB_SCALE][2] = SIZE_HEIGHT_MIN
            }

            ArraySetArray(g_aBomb, iItem, eBomb)
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_SCALE)
        }
        case SCALE_WIDTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBomb[BOMB_SCALE][0] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][0] > SIZE_WIDTH_MAX )
                    eBomb[BOMB_SCALE][0] = SIZE_WIDTH_MAX
            }
            else
            {
                eBomb[BOMB_SCALE][0] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][0] < SIZE_WIDTH_MIN )
                    eBomb[BOMB_SCALE][0] = SIZE_WIDTH_MIN
            }

            ArraySetArray(g_aBomb, iItem, eBomb)
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_SCALE)
        }
        case SCALE_DEPTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBomb[BOMB_SCALE][1] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][1] > SIZE_DEPTH_MAX )
                    eBomb[BOMB_SCALE][1] = SIZE_DEPTH_MAX
            }
            else
            {
                eBomb[BOMB_SCALE][1] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBomb[BOMB_SCALE][1] < SIZE_DEPTH_MIN )
                    eBomb[BOMB_SCALE][1] = SIZE_DEPTH_MIN
            }

            ArraySetArray(g_aBomb, iItem, eBomb)
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_SCALE)
        }
        case SCALE_FACTOR:
        {
            g_ePlayerData[id][PDATA_SCALE_FACTOR] += 1
            if ( g_ePlayerData[id][PDATA_SCALE_FACTOR] >= sizeof(g_fScaleFactor) )
                g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_SCALE)
        }
        case SCALE_MODE:
        {
            g_ePlayerData[id][PDATA_SCALE_UP] = !g_ePlayerData[id][PDATA_SCALE_UP]

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_SCALE)
        }
        case SCALE_PLACE:
        {
            bombTrace(eBomb, id)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0

            eBomb[BOMB_FLAGS] |= FLAG_ACTIVE
            bombSetSize(eBomb)
            ArraySetArray(g_aBomb, iItem, eBomb)

            client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_CREATE_NEW")
            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            bombKill(eBomb[BOMB_ID])
            bombRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0

            bombSound(id, SOUND_MENU_NAV)
            bombMenu(id, MENU_ROOT)
        }
        default:
        {
            bombKill(eBomb[BOMB_ID])
            bombRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public bombTask()
{
    new eBomb[BOMB]
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_BOMB_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_BOMB_ACTION] )
                bombCheck(id)
        }
        else if ( bombGet(eBomb, g_ePlayerData[id][PDATA_BOMB_GHOST]) != -1 )
        {
            bombTrace(eBomb, id)
        }
    }

    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        if ( eBomb[BOMB_FLAGS] & FLAG_SELECT )
            bombBeam(eBomb)
    }
}

public bombCreate(id, iItem)
{
    new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_bomb_target"))
    if ( !pev_valid(iEnt) )
        return

    new eBomb[BOMB]
    ArrayGetArray(g_aBombConfig, iItem, eBomb)

    eBomb[BOMB_ID] = iEnt
    eBomb[BOMB_ITEM] = iItem
    eBomb[BOMB_SCALE][0] = eBomb[BOMB_SCALE][1] = eBomb[BOMB_SCALE][2] = SIZE_BASE
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_BOMB_GHOST] = iEnt
        g_ePlayerData[id][PDATA_BOMB_ACTION] = true
        g_ePlayerData[id][PDATA_SCALE_UP] = true
        g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0
        g_ePlayerData[id][PDATA_OFFSET] = BOMB_OFFSET_BASE
    }

    bombSelect(eBomb, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, BOMB_KEY)
    set_pev(iEnt, BOMB_ARRAY_ITEM, g_iBomb)
    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)

    ArrayPushArray(g_aBomb, eBomb)
    if ( ++ g_iBomb == 1 )
        set_task(g_eSettings[SETTING_BOMB_TASK], "bombTask", BOMB_KEY, .flags = "b")
}

stock iconCreate(eBomb[BOMB], Float:fOrigin[3])
{
    new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
    if ( !pev_valid(iEnt) )
        return 0

    eBomb[BOMB_ICON] = iEnt
    set_pev(iEnt, pev_impulse, BOMB_KEY)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_origin, fOrigin)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_SPRITE_ICON])
    dllfunc(DLLFunc_Spawn, iEnt)

    iconColor(eBomb)
    set_pev(iEnt, pev_renderfx, kRenderFxNone)
    set_pev(iEnt, pev_rendermode, kRenderTransAdd)
    set_pev(iEnt, pev_renderamt, eBomb[BOMB_FLAGS] & FLAG_ICON ? g_eSettings[SETTING_DEFAULT_ICON_ALPHA] : 0.0)
    set_pev(iEnt, pev_scale, g_eSettings[SETTING_DEFAULT_ICON_SCALE])

    return iEnt
}

stock bombRemove(iItem)
{
    new eBomb[BOMB]
    ArrayDeleteItem(g_aBomb, iItem)

    if ( -- g_iBomb == 0 )
        remove_task(BOMB_KEY)

    for ( new i = iItem; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        set_pev(eBomb[BOMB_ID], BOMB_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eBomb[BOMB],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BombSite.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    bombTerminate()
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eBomb[BOMB_ITEM])
        fputs(iFile, szData)

        eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
        formatex(szData, charsmax(szData), "flags = %d^n", eBomb[BOMB_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "scale = %.2f %.2f %.2f^n",
        eBomb[BOMB_SCALE][0], eBomb[BOMB_SCALE][1], eBomb[BOMB_SCALE][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eBomb[BOMB_ORIGIN][0], eBomb[BOMB_ORIGIN][1], eBomb[BOMB_ORIGIN][2])
        fputs(iFile, szData)

        for ( new j = 0; j < 8; j ++ )
        {
            formatex(szData, charsmax(szData), "corner_%d = %.2f %.2f %.2f^n",
            j + 1, eBomb[BOMB_CORNERS][j * 3], eBomb[BOMB_CORNERS][(j * 3) + 1], eBomb[BOMB_CORNERS][(j * 3) + 2])
            fputs(iFile, szData)
        }
    }

    client_print_color(id, id, "%L %L", id, "BOMB_CHAT_TAG", id, "BOMB_CHAT_SAVE", szFile)
    fclose(iFile)

    bombSound(id, SOUND_MENU_NAV)
    bombMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        iItem, iFlags, Float:fScale[3], Float:fOrigin[3], Float:fCorners[24],
        iCorner, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BombSite.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataBomb(fCorners, fScale, fOrigin, iItem, iFlags, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "scale") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[1] = str_to_float(szKey)
                fScale[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( contain(szKey, "corner") != -1 )
            {
                iCorner = str_to_num(szKey[7])

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3 + 1] = str_to_float(szKey)
                fCorners[(iCorner - 1) * 3 + 2] = str_to_float(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataBomb(fCorners, fScale, fOrigin, iItem, iFlags, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataBomb(Float:fCorners[24], Float:fScale[3], Float:fOrigin[3], iItem, iFlags, iCount)
{
    new eBomb[BOMB]
    bombCreate(0, iItem)
    ArrayGetArray(g_aBomb, iCount, eBomb)

    eBomb[BOMB_FLAGS] = iFlags
    eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
    xs_vec_copy(fScale, eBomb[BOMB_SCALE])
    xs_vec_copy(fOrigin, eBomb[BOMB_ORIGIN])
    for ( new i = 0; i < 24; i ++ )
        eBomb[BOMB_CORNERS][i] = fCorners[i]

    set_pev(eBomb[BOMB_ID], pev_origin, fOrigin)
    bombSetBox(eBomb)
    bombSetSize(eBomb)
    ArraySetArray(g_aBomb, iCount, eBomb)
}

public bombNoClip(id)
{
    set_pev(id, pev_movetype, pev(id, pev_movetype) == MOVETYPE_NOCLIP ? MOVETYPE_WALK : MOVETYPE_NOCLIP)

    bombSound(id, SOUND_MENU_NAV)
    bombMenu(id, MENU_ROOT)
}

public bombGodMode(id)
{
    set_pev(id, pev_takedamage, pev(id, pev_takedamage) == DAMAGE_NO ? DAMAGE_AIM : DAMAGE_NO)

    bombSound(id, SOUND_MENU_NAV)
    bombMenu(id, MENU_ROOT)
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

public fwdSetModel(iEnt, szModel[])
{
    if ( !equal(szModel, "models/w_backpack.mdl") )
        return HAM_IGNORED

    g_iPlayerBomb = 0
    return HAM_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isBomb(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    g_ePlayerData[id][PDATA_BOMB_ACTION] = false

    if ( g_ePlayerData[id][PDATA_BOMB_GHOST] )
    {
        new eBomb[BOMB], iItem

        if ( (iItem = bombGet(eBomb, g_ePlayerData[id][PDATA_BOMB_GHOST])) != -1 )
        {
            bombKill(eBomb[BOMB_ID])
            bombRemove(iItem)
            g_ePlayerData[id][PDATA_BOMB_GHOST] = 0
        }
    }

    return HAM_IGNORED
}

public fwdAddC4(iEnt, id)
{
    if ( !g_eSettings[SETTING_BOMB_ANYWHERE] && !g_bBombMap )
    {
        iconDraw(id, ICON_HIDE)
        return HAM_SUPERCEDE
    }

    g_iPlayerBomb = id
    return HAM_IGNORED
}

public fwdPlantC4(iEnt)
{
    new eBomb[BOMB], id
    id = pev(iEnt, pev_owner)

    if ( isBombActive(eBomb, id) )
        return eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? HAM_IGNORED : HAM_SUPERCEDE
    else
        return g_eSettings[SETTING_BOMB_DEFAULT] ? HAM_IGNORED : HAM_SUPERCEDE
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_BOMB_GHOST] )
    {
        if ( get_gametime() >= g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += BOMB_OFFSET_STEP
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], BOMB_OFFSET_MIN, BOMB_OFFSET_MAX)
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= BOMB_OFFSET_STEP
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], BOMB_OFFSET_MIN, BOMB_OFFSET_MAX)
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + 0.1
            }
        }

        set_pdata_float(id, PDATA_NEXT_ATTACK, fCurrentTime + 0.1, XO_CBASEPLAYER, XO_CBASEPLAYER)
        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    return HAM_IGNORED
}

public iconDraw(id, iState)
{
    message_begin(MSG_ONE_UNRELIABLE, g_iStatusIcon, .player = id)
    write_byte(iState)
    write_string("c4")
    write_byte(0)
    write_byte(165)
    write_byte(0)
    message_end()
}

public iconColor(eBomb[BOMB])
{
    new Float:fRenderColor[3]
    if ( eBomb[BOMB_FLAGS] & FLAG_ACTIVE )    { fRenderColor[0] = 0.0;      fRenderColor[1] = 255.0; fRenderColor[2] = 0.0; }
    else                                      { fRenderColor[0] = 255.0;    fRenderColor[1] = 0.0;   fRenderColor[2] = 0.0; }

    set_pev(eBomb[BOMB_ICON], pev_rendercolor, fRenderColor)
}

stock iconRefresh()
{
    if ( g_iPlayerBomb )
        eventStatusIcon(g_iPlayerBomb)
}

stock bombTrace(eBomb[BOMB], id)
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

    bombSetBox(eBomb, true)
    bombSetOffset(eBomb)
    bombSetBox(eBomb, true)
    bombBeam(eBomb)

    set_pev(eBomb[BOMB_ID], pev_origin, eBomb[BOMB_ORIGIN])
}

stock bombCheck(id)
{
    new eBomb[BOMB], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = BOMB_CHECK
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        xs_vec_sub(eBomb[BOMB_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(eBomb[BOMB_ID], pev_absmin, fMins)
        pev(eBomb[BOMB_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_BOMB_MENU] != iBest )
    {
        ArrayGetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)
        eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aBomb, g_ePlayerData[id][PDATA_BOMB_MENU], eBomb)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_BOMB_MENU] = iBest
        bombMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock bombSetBox(eBomb[BOMB], bool:bSetCorners = false)
{
    if ( bSetCorners )
        boxCorners(eBomb)

    xs_vec_copy(eBomb[BOMB_CORNERS][0], eBomb[BOMB_MINS])
    xs_vec_copy(eBomb[BOMB_CORNERS][0], eBomb[BOMB_MAXS])
    for ( new i = 1; i < 8; i ++ )
    {
        for ( new j = 0; j < 3; j ++ )
        {
            eBomb[BOMB_MINS][j] = floatmin(eBomb[BOMB_MINS][j], eBomb[BOMB_CORNERS][i * 3 + j])
            eBomb[BOMB_MAXS][j] = floatmax(eBomb[BOMB_MAXS][j], eBomb[BOMB_CORNERS][i * 3 + j])
        }
    }

    xs_vec_sub(eBomb[BOMB_MINS], eBomb[BOMB_ORIGIN], eBomb[BOMB_MINS])
    xs_vec_sub(eBomb[BOMB_MAXS], eBomb[BOMB_ORIGIN], eBomb[BOMB_MAXS])
}

stock boxCorners(eBomb[BOMB])
{
    eBomb[BOMB_CORNERS][0]  = eBomb[BOMB_ORIGIN][0] - eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][1]  = eBomb[BOMB_ORIGIN][1] - eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][2]  = eBomb[BOMB_ORIGIN][2] - eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][3]  = eBomb[BOMB_ORIGIN][0] + eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][4]  = eBomb[BOMB_ORIGIN][1] - eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][5]  = eBomb[BOMB_ORIGIN][2] - eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][6]  = eBomb[BOMB_ORIGIN][0] - eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][7]  = eBomb[BOMB_ORIGIN][1] + eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][8]  = eBomb[BOMB_ORIGIN][2] - eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][9]  = eBomb[BOMB_ORIGIN][0] + eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][10] = eBomb[BOMB_ORIGIN][1] + eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][11] = eBomb[BOMB_ORIGIN][2] - eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][12] = eBomb[BOMB_ORIGIN][0] - eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][13] = eBomb[BOMB_ORIGIN][1] - eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][14] = eBomb[BOMB_ORIGIN][2] + eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][15] = eBomb[BOMB_ORIGIN][0] + eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][16] = eBomb[BOMB_ORIGIN][1] - eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][17] = eBomb[BOMB_ORIGIN][2] + eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][18] = eBomb[BOMB_ORIGIN][0] - eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][19] = eBomb[BOMB_ORIGIN][1] + eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][20] = eBomb[BOMB_ORIGIN][2] + eBomb[BOMB_SCALE][2]

    eBomb[BOMB_CORNERS][21] = eBomb[BOMB_ORIGIN][0] + eBomb[BOMB_SCALE][0]
    eBomb[BOMB_CORNERS][22] = eBomb[BOMB_ORIGIN][1] + eBomb[BOMB_SCALE][1]
    eBomb[BOMB_CORNERS][23] = eBomb[BOMB_ORIGIN][2] + eBomb[BOMB_SCALE][2]
}

stock bombSetOffset(eBomb[BOMB])
{
    new Float:fGaps[6], Float:fVec1[3], Float:fCurrentGap
    fGaps[0] = -eBomb[BOMB_MINS][0]
    fGaps[1] = eBomb[BOMB_MAXS][0]
    fGaps[2] = -eBomb[BOMB_MINS][1]
    fGaps[3] = eBomb[BOMB_MAXS][1]
    fGaps[4] = -eBomb[BOMB_MINS][2]
    fGaps[5] = eBomb[BOMB_MAXS][2]

    for ( new i = 5; i >= 0; i -- )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eBomb[BOMB_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eBomb[BOMB_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eBomb[BOMB_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eBomb[BOMB_ORIGIN], fVec1)

        if ( fCurrentGap < (fGaps[i] + 1.0) )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, (fGaps[i] + 1.0) - fCurrentGap, fVec1)
            xs_vec_add(eBomb[BOMB_ORIGIN], fVec1, eBomb[BOMB_ORIGIN])
        }
    }
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

    beamDraw(fCorners[0], fCorners[1], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[3], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[2], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[0], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[0], fCorners[4], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[5], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[6], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[7], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[4], fCorners[5], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[5], fCorners[7], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[7], fCorners[6], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[6], fCorners[4], eBomb[BOMB_FLAGS] & FLAG_ACTIVE != 0)
}

stock beamDraw(Float:fStart[3], Float:fEnd[3], bool:bActive)
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fStart)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(fStart[0])
    write_coord_f(fStart[1])
    write_coord_f(fStart[2])
    write_coord_f(fEnd[0])
    write_coord_f(fEnd[1])
    write_coord_f(fEnd[2])
    write_short(g_iBeam)
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(BEAM_WIDTH)
    write_byte(0)
    if ( bActive )
    {
        write_byte(0)
        write_byte(255)
        write_byte(0)
    }
    else
    {
        write_byte(255)
        write_byte(0)
        write_byte(0)
    }
    write_byte(BEAM_ALPHA)
    write_byte(0)
    message_end()
}

stock bombRadar(eBomb[BOMB])
{
    if ( eBomb[BOMB_RADAR] == TEAM_T
    || eBomb[BOMB_RADAR] == TEAM_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iBombDrop)
        write_coord_f(eBomb[BOMB_ORIGIN][0])
        write_coord_f(eBomb[BOMB_ORIGIN][1])
        write_coord_f(eBomb[BOMB_ORIGIN][2])
        write_byte(0)
        message_end()
    }

    if ( eBomb[BOMB_RADAR] == TEAM_CT
    || eBomb[BOMB_RADAR] == TEAM_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iHostageK)
        write_byte(0)
        message_end()

        message_begin(MSG_BROADCAST, g_iHostagePos)
        write_byte(0)
        write_byte(0)
        write_coord_f(eBomb[BOMB_ORIGIN][0])
        write_coord_f(eBomb[BOMB_ORIGIN][1])
        write_coord_f(eBomb[BOMB_ORIGIN][2])
        message_end()
    }

    eBomb[BOMB_NEXT_RADAR] = get_gametime() + 2.0
}

stock bool:isBombMap()
{
    return engfunc(EngFunc_FindEntityByString, -1, "classname", "func_bomb_target") > 0
}

stock bombSetSize(eBomb[BOMB])
{
    bombSelect(eBomb, TARGET_HIDE)
    engfunc(EngFunc_SetOrigin, eBomb[BOMB_ID], eBomb[BOMB_ORIGIN])
    set_pev(eBomb[BOMB_ID], pev_solid, eBomb[BOMB_FLAGS] & FLAG_ACTIVE ? SOLID_TRIGGER : SOLID_NOT)
    set_pev(eBomb[BOMB_ID], pev_movetype, MOVETYPE_NONE)

    engfunc(EngFunc_SetSize, eBomb[BOMB_ID], eBomb[BOMB_MINS], eBomb[BOMB_MAXS])
    iconCreate(eBomb, eBomb[BOMB_ORIGIN])
}

stock bombSelect(eBomb[BOMB], iAction)
{
    new Float:fRenderAmt

    if ( iAction == TARGET_SELECT )
    {
        iconColor(eBomb)
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
        eBomb[BOMB_FLAGS] |= FLAG_SELECT
    }
    else if ( iAction == TARGET_GHOST )
    {
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
    }
    else if ( iAction == TARGET_HIDE )
    {
        fRenderAmt = eBomb[BOMB_FLAGS] & FLAG_ICON ? g_eSettings[SETTING_DEFAULT_ICON_ALPHA] : 0.0
        eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
    }
    else if ( iAction == TARGET_CLEAR )
    {
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
        eBomb[BOMB_FLAGS] &= ~FLAG_SELECT
    }

    set_pev(eBomb[BOMB_ICON], pev_renderamt, fRenderAmt)
}

stock bombSound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0, iPitch = PITCH_NORM)
{
    new szSample[MAX_RESOURCE_PATH_LENGTH]

    switch( iSound )
    {
        case SOUND_MENU_NAV:        copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE:     copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:      copy(szSample, charsmax(szSample), SOUND_ALERT)
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, iPitch)
}

stock bombReset()
{
    new eBomb[BOMB]
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        eBomb[BOMB_NEXT_RADAR] = 0.0
        ArraySetArray(g_aBomb, i, eBomb)
    }
}

stock bool:isBombActive(eBomb[BOMB], id)
{
    new Float:fOrigin[3], Float:fAbsMins[3], Float:fAbsMaxs[3]

    pev(id, pev_origin, fOrigin)
    for ( new i = 0; i < g_iBomb; i ++ )
    {
        ArrayGetArray(g_aBomb, i, eBomb)
        xs_vec_add(eBomb[BOMB_MINS], eBomb[BOMB_ORIGIN], fAbsMins)
        xs_vec_add(eBomb[BOMB_MAXS], eBomb[BOMB_ORIGIN], fAbsMaxs)

        if ( fOrigin[0] >= fAbsMins[0] - 25.0 && fOrigin[0] <= fAbsMaxs[0] + 25.0
        && fOrigin[1] >= fAbsMins[1] - 25.0 && fOrigin[1] <= fAbsMaxs[1] + 25.0
        && fOrigin[2] >= fAbsMins[2] - 25.0 && fOrigin[2] <= fAbsMaxs[2] + 25.0 )
            return true
    }

    return false
}

stock bombGet(eBomb[BOMB], iEnt)
{
    new iItem
    iItem = pev(iEnt, BOMB_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iBomb )
        return -1

    ArrayGetArray(g_aBomb, iItem, eBomb)
    return iItem
}

stock bool:isBomb(iEnt)
{
    return pev(iEnt, pev_impulse) == BOMB_KEY
}

stock bombKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_ARRAY_MESSAGE:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_MODEL:
        {
            if ( !g_bFileWasRead )
                precache_model(szValue)

            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
        case DTYPE_ARRAY_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                ArrayPushCell(aOutput[0], precache_model(szValue))
        }
    }
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_BOMB_ACTION] )
    {
        new eBomb[BOMB]
        for ( new i = 0; i < g_iBomb; i ++ )
        {
            ArrayGetArray(g_aBomb, i, eBomb)
            bombSelect(eBomb, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_BOMB_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_BOMB_ACTION] )
    {
        new eBomb[BOMB]
        for ( new i = 0; i < g_iBomb; i ++ )
        {
            ArrayGetArray(g_aBomb, i, eBomb)
            bombSelect(eBomb, TARGET_HIDE)
            ArraySetArray(g_aBomb, i, eBomb)
        }

        g_ePlayerData[id][PDATA_BOMB_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    EnableHamForward(g_iFwdPreThink)
    EnableHamForward(g_iFwdKilled)
}

stock DisableForward()
{
    DisableHamForward(g_iFwdPreThink)
    DisableHamForward(g_iFwdKilled)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}
