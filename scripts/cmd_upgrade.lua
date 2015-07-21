﻿--[[

    cmd_upgrade.lua by blastbeat

        - this script adds a command "upgrade" to set or change the level of an user by sid/nick/cid
        - usage: [+!#]upgrade sid|nick|cid <SID>|<NICK>|<CID> <LEVEL>
        
        v0.16: by pulsar
            - removed "cmd_upgrade_minlevel" import
                - using util.getlowestlevel( tbl ) instead of "cmd_upgrade_minlevel"
            
        v0.15: by pulsar
            - small fix
        
        v0.14: by pulsar
            - changed msg_out message
        
        v0.13: by pulsar
            - removed new method to save userdatabase
            - send report if a user without permission tries to upgrade
            - rewrite some parts of the code
        
        v0.12: by pulsar
            - improved method to save userdatabase
        
        v0.11: by pulsar
            - added new table lookup
            - add report feature
                - send report to hubbot (according llevel) and/or send report as feed to opchat
        
        v0.10: by pulsar
            - additional ct1 rightclick
            - possibility to toggle advanced ct2 rightclick (shows complete userlist)
                - export var to "cfg/cfg.tbl"
        
        v0.09: by Motnahp
            - small permission fix in CT2
        
        v0.08: by Motnahp
            - small fix in lang

        v0.07: by pulsar
            - possibility to upgrade offline users (CT1)
            - changed visual output style
            - table lookups
            - code cleaning

        v0.06: by pulsar
            - bugfix in "user:kill()" function
            - show sorted levelnames in rightclick (CT2)

        v0.05: by pulsar
            - export scriptsettings to "/cfg/cfg.tbl"
            - fix a permission bug

        v0.04: by blastbeat
            - updated script api
            - regged hubcommand

        v0.03: by blastbeat
            - some clean ups, added language file, ucmd

        v0.02: by blastbeat
            - added language files and ucmd

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "cmd_upgrade"
local scriptversion = "0.16"

local cmd = "upgrade"


----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// table lookups
local cfg_get = cfg.get
local cfg_loadlanguage = cfg.loadlanguage
local utf_match = utf.match
local utf_format = utf.format
local hub_getbot = hub.getbot()
local hub_getusers = hub.getusers
local hub_getregusers = hub.getregusers
local hub_reloadusers = hub.reloadusers
local hub_escapeto = hub.escapeto
local hub_import = hub.import
local hub_debug = hub.debug

local hub_issidonline = hub.issidonline
local hub_iscidonline = hub.iscidonline
local hub_isnickonline = hub.isnickonline

local util_loadtable = util.loadtable
local util_savearray = util.savearray
local util_getlowestlevel = util.getlowestlevel
local table_insert = table.insert
local table_sort = table.sort

--// imports
local help, ucmd, hubcmd
local permission = cfg_get( "cmd_upgrade_permission" )
local scriptlang = cfg_get( "language" )
local advanced_rc = cfg_get( "cmd_upgrade_advanced_rc" )

local opchat = hub_import( "bot_opchat" )
local opchat_activate = cfg_get( "bot_opchat_activate" )
local report = cfg_get( "cmd_upgrade_report" )
local llevel = cfg_get( "cmd_upgrade_llevel" )

local report_hubbot = cfg_get( "cmd_upgrade_report_hubbot" )
local report_opchat = cfg_get( "cmd_upgrade_report_opchat" )

local prefix_activate = cfg_get( "usr_nick_prefix_activate" )
local prefix_table = cfg_get( "usr_nick_prefix_prefix_table" )

--// msgs
local lang, err = cfg_loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub_debug( err )

local msg_denied = lang.msg_denied or "You are not allowed to use this command or the target user has a higher level than you!"
local msg_usage = lang.msg_usage or "Usage: [+!#]upgrade sid|nick|cid <sid>|<nick>|<cid> <level>"
local msg_off = lang.msg_off or "User not found."
local msg_reg = lang.msg_reg or "User is not regged or a bot."
local msg_out = lang.msg_out or "%s  changed  %s  from level: %s [ %s ]  to level:  %s [ %s ]"
local msg_out_2 = lang.msg_out_2 or "%s  with level:  %s [ %s ]  has tried to change  %s  to level:  %s [ %s ]"

local help_title = lang.help_title or "upgrade"
local help_usage = lang.help_usage or "[+!#]upgrade sid|nick|cid <sid>|<nick>|<cid> <level>"
local help_desc = lang.help_desc or "sets level of user"

local ucmd_menu = lang.ucmd_menu or "Upgrade"
local ucmd_level = lang.ucmd_level or "Level:"
local ucmd_popup = lang.ucmd_popup or "Nickname:"

local ucmd_menu_ct1_1 = lang.ucmd_menu_ct1_1 or "User"
local ucmd_menu_ct1_2 = lang.ucmd_menu_ct1_2 or "Control"
local ucmd_menu_ct1_3 = lang.ucmd_menu_ct1_3 or "Upgrade"
local ucmd_menu_ct1_4 = lang.ucmd_menu_ct1_4 or "by Nick from list"
local ucmd_menu_ct1_5 = lang.ucmd_menu_ct1_5 or "User"
local ucmd_menu_ct1_6 = lang.ucmd_menu_ct1_6 or "Control"
local ucmd_menu_ct1_7 = lang.ucmd_menu_ct1_7 or "Upgrade"
local ucmd_menu_ct1_8 = lang.ucmd_menu_ct1_8 or "by Nick"


----------
--[CODE]--
----------

local minlevel = util_getlowestlevel( permission )

local send_report = function( msg, lvl )
    if report then
        if report_hubbot then
            for sid, user in pairs( hub_getusers() ) do
                local user_level = user:level()
                if user_level >= lvl then
                    user:reply( msg, hub_getbot, hub_getbot )
                end
            end
        end
        if report_opchat then
            if opchat_activate then
                opchat.feed( msg )
            end
        end
    end
end

local onbmsg = function( user, command, parameters )
    local user_nick = user:nick()
    local user_level = user:level()
    local by, id, level = utf_match( parameters, "^(%S+) (%S+) (%d+)$" )
    
    if not ( by == "sid" or by == "nick" or by == "cid" ) then
        user:reply( msg_usage, hub_getbot )
        return PROCESSED
    end
    
    if ( by == "sid" or by == "cid" ) then
        local target = ( by == "sid" and hub_issidonline( id ) ) or ( by == "cid" and hub_iscidonline( id ) )
        if not target then
            user:reply( msg_off, hub_getbot )
            return PROCESSED
        end
        if not target:isregged() or target:isbot() then
            user:reply( msg_reg, hub_getbot )
            return PROCESSED
        end
        
        local userlevelname = cfg_get( "levels" )[ tonumber( user_level ) ] or "Unreg"
        local targetlevelname = cfg_get( "levels" )[ tonumber( level ) ] or "Unreg"
        local targetoldlevelname = cfg_get( "levels" )[ tonumber( target:level() ) ] or "Unreg"
        
        if ( ( permission[ user_level ] or 0 ) < target:level() ) then
            user:reply( msg_denied, hub_getbot )
            local msg = utf_format( msg_out_2, user_nick, user_level, userlevelname, target:nick(), level, targetlevelname )
            send_report( msg, llevel )
            return PROCESSED
        end
        
        local target_oldlevel = target:level()
        local ret, msg = target:setlevel( tonumber( level ) )
        if not ret then
            user:reply( msg, hub_getbot )
            return PROCESSED
        end
        local msg = utf_format( msg_out, user_nick, target:nick(), target_oldlevel, targetoldlevelname, level, targetlevelname )
        user:reply( msg, hub_getbot )
        send_report( msg, llevel )
        target:kill( "ISTA 230 " .. hub_escapeto( msg ) .. "\n" )
        hub_reloadusers()
        return PROCESSED
    end
    
    if by == "nick" then
        local user_db = "cfg/user.tbl"
        local user_tbl = util_loadtable( user_db )
        local target_isbot = true
        local target_isregged = false
        local msg, target, target_nick, target_firstnick, target_level, targetlevelname, userlevelname, targetoldlevelname
        for k, v in pairs( user_tbl ) do
            if not user_tbl[ k ].is_bot then
                if user_tbl[ k ].nick == id then
                    target_firstnick = user_tbl[ k ].nick
                    target_level = user_tbl[ k ].level
                    targetlevelname = cfg_get( "levels" )[ tonumber( level ) ] or "Unreg"
                    targetoldlevelname = cfg_get( "levels" )[ tonumber( target_level ) ] or "Unreg"
                    userlevelname = cfg_get( "levels" )[ tonumber( user_level ) ] or "Unreg"
                    if ( permission[ user_level ] or 0 ) < target_level then
                        user:reply( msg_denied, hub_getbot )
                        msg = utf_format( msg_out_2, user_nick, user_level, userlevelname, target_firstnick, level, targetlevelname )
                        send_report( msg, llevel )
                        return PROCESSED
                    end
                    if prefix_activate then
                        local prefix = prefix_table[ target_level ]
                        target_nick = prefix .. target_firstnick
                        target = hub_isnickonline( target_nick )
                        msg = utf_format( msg_out, user_nick, target_nick, target_level, targetoldlevelname, level, targetlevelname )
                        if target then
                            target:kill( "ISTA 230 " .. hub_escapeto( msg ) .. "\n" )
                        end
                    else
                        target = hub_isnickonline( target_firstnick )
                        msg = utf_format( msg_out, user_nick, target_firstnick, target_level, targetoldlevelname, level, targetlevelname )
                        if target then
                            target:kill( "ISTA 230 " .. hub_escapeto( msg ) .. "\n" )
                        end
                    end
                    user_tbl[ k ].level = tonumber( level )
                    util_savearray( user_tbl, user_db )
                    --cfg.saveusers( hub.getregusers() )
                    user:reply( msg, hub_getbot )
                    send_report( msg, llevel )
                    hub_reloadusers()
                    return PROCESSED
                else
                    target_isregged = false
                end
            else
                target_isbot = true
            end
        end
        if not target_isregged then
            user:reply( msg_reg, hub_getbot )
            return PROCESSED
        end
        if target_isbot then
            user:reply( msg_reg, hub_getbot )
            return PROCESSED
        end
    end
end

hub.setlistener( "onStart", { },
    function( )
        help = hub_import( "cmd_help" )
        if help then help.reg( help_title, help_usage, help_desc, minlevel ) end
        ucmd = hub_import( "etc_usercommands" )
        if ucmd then
            --// CT2
            local levels = cfg.get( "levels" ) or {}
            local lvltbl = {}
            for k, v in pairs( levels ) do
                if k > 0 then
                    lvltbl[ #lvltbl + 1 ] = k
                end
            end
            table_sort( lvltbl )
            for _, level in pairs( lvltbl ) do
                ucmd.add( { ucmd_menu, levels[ level ] }, cmd, { "sid", "%[userSID]", level }, { "CT2" }, minlevel )
            end
            --// CT1
            for _, level in pairs( lvltbl ) do
                ucmd.add( { ucmd_menu_ct1_5, ucmd_menu_ct1_6, ucmd_menu_ct1_7, ucmd_menu_ct1_8, levels[ level ] }, cmd, { "nick", "%[line:" .. ucmd_popup .. "]", level }, { "CT1" }, minlevel )
            end
            if advanced_rc then
                local regusers, reggednicks, reggedcids = hub_getregusers()
                local usertbl = {}
                for i, user in ipairs( regusers ) do
                    if ( user.is_bot ~= 1 ) and user.nick then
                      table_insert( usertbl, user.nick )
                    end
                end
                table_sort( usertbl )
                for _, nick in pairs( usertbl ) do
                    for _, level in pairs( lvltbl ) do
                        ucmd.add( { ucmd_menu_ct1_1, ucmd_menu_ct1_2, ucmd_menu_ct1_3, ucmd_menu_ct1_4, nick, levels[ level ] }, cmd, { "nick", nick, level }, { "CT1" }, minlevel )
                    end
                end
            end
        end
        hubcmd = hub_import( "etc_hubcommands" )
        assert( hubcmd )
        assert( hubcmd.add( cmd, onbmsg ) )
        return nil
    end
)

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )