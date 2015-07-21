﻿--[[

    etc_msgmanager.lua by pulsar

        description: this script blocks chats (main/pm) for predefined levels (check cfg/cfg.tbl)

        usage:
        
        [+!#]msgmanager blockmain <NICK>  -- blocks users main messages
        [+!#]msgmanager blockpm <NICK>  -- blocks users pm messages
        [+!#]msgmanager blockboth <NICK>  -- blocks users main + pm messages
        [+!#]msgmanager unblock <NICK>  -- unblock user
        [+!#]msgmanager showusers  -- show all blocked users
        [+!#]msgmanager showsettings  -- show settings from 'cfg.tbl'

        v0.3:
            - check if target is a bot  / thx Kaas
            - fixed "msg_report_block"
            - fixed "msg_report_unblock"
            - fixed "msg_notonline"  / thx Sopor
        
        v0.2:
            - possibility to block/unblock single users from userlist  / requested by DarkDragon
            - show list of all blocked users
            - show settings
            - add new table lookups, imports, msgs
            - rewrite some parts of code
        
        v0.1:
            - possibility to block main chat for predefined levels
            - possibility to block pm chat for predefined levels

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_msgmanager"
local scriptversion = "0.3"

local cmd = "msgmanager"
local cmd_b1 = "blockmain"
local cmd_b2 = "blockpm"
local cmd_b3 = "blockboth"
local cmd_u = "unblock"
local cmd_su = "showusers"
local cmd_ss = "showsettings"

local block_file = "scripts/data/etc_msgmanager.tbl"


----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// table lookups
local cfg_get = cfg.get
local cfg_loadlanguage = cfg.loadlanguage
local hub_import = hub.import
local hub_debug = hub.debug
local hub_getbot = hub.getbot()
local hub_isnickonline = hub.isnickonline
local hub_getusers = hub.getusers
local utf_match = utf.match
local utf_format = utf.format
local util_loadtable = util.loadtable
local util_savetable = util.savetable
local util_getlowestlevel = util.getlowestlevel
local table_sort = table.sort

--// imports
local activate = cfg_get( "etc_msgmanager_activate" )
local scriptlang = cfg_get( "language" )
local permission_pm = cfg_get( "etc_msgmanager_permission_pm" )
local permission_main = cfg_get( "etc_msgmanager_permission_main" )
local report = cfg_get( "etc_msgmanager_report" )
local report_hubbot = cfg_get( "etc_msgmanager_report_hubbot" )
local report_opchat = cfg_get( "etc_msgmanager_report_opchat" )
local llevel = cfg_get( "etc_msgmanager_llevel" )
local permission = cfg_get( "etc_msgmanager_permission" )
local opchat = hub_import( "bot_opchat" )
local opchat_activate = cfg_get( "bot_opchat_activate" )

--// functions
local block_tbl
local get_blocklevels
local get_bool
local onbmsg
local is_online
local is_blocked
local send_report

--// msgs
local lang, err = cfg_loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub_debug( err )

local help_title = lang.help_title or "etc_msgmanager.lua"
local help_usage = lang.help_usage or "[+!#]msgmanager showusers|showsettings|blockmain <NICK>|blockpm <NICK>|blockboth <NICK>|unblock <NICK>"
local help_desc = lang.help_desc or "Shows blocked users | show settings | block main chats | block pm chats | block both | unblock user"

local msg_denied_main = lang.msg_denied_main or "You are not allowed to write messages in main chat."
local msg_denied_pm = lang.msg_denied_pm or "You are not allowed to write private messages."
local msg_denied = lang.msg_denied or "You are not allowed to use this command."
local msg_god = lang.msg_god or "You are not allowed to block this user."
local msg_stillblocked = lang.msg_stillblocked or "This user is already blocked."
local msg_notonline = lang.msg_notonline or "User is offline."
local msg_notfound = lang.msg_notfound or "User not found."
local msg_isbot = lang.msg_isbot or "User is a bot."
local msg_block = lang.msg_block or "Message Manager: Block user: %s  |  Mode: %s"
local msg_unblock = lang.msg_unblock or "Message Manager: Unblock user: %s"
local msg_report_block = lang.msg_report_block or "Message Manager:  %s  has blocked user: %s  |  Mode: %s"
local msg_report_unblock = lang.msg_report_unblock or "Message Manager:  %s  has unblocked user: %s"

local ucmd_menu_ct1_1 = lang.ucmd_menu_ct1_1 or { "Hub", "etc", "Message Manager", "show settings" }
local ucmd_menu_ct1_2 = lang.ucmd_menu_ct1_2 or { "Hub", "etc", "Message Manager", "show blocked users" }
local ucmd_menu_ct2_1 = lang.ucmd_menu_ct2_1 or { "Message Manager", "block", "main" }
local ucmd_menu_ct2_2 = lang.ucmd_menu_ct2_2 or { "Message Manager", "block", "pm" }
local ucmd_menu_ct2_3 = lang.ucmd_menu_ct2_3 or { "Message Manager", "block", "both" }
local ucmd_menu_ct2_4 = lang.ucmd_menu_ct2_4 or { "Message Manager", "unblock" }

local msg_usage = lang.msg_usage or [[


=== MESSAGE MANAGER ===========================================================

Usage:

    [+!#]msgmanager blockmain <NICK>  -- blocks users main messages
    [+!#]msgmanager blockpm <NICK>  -- blocks users pm messages
    [+!#]msgmanager blockboth <NICK>  -- blocks users main + pm messages
    [+!#]msgmanager unblock <NICK>  -- unblock user
    [+!#]msgmanager showusers  -- show all blocked users
    [+!#]msgmanager showsettings  -- show settings from 'cfg.tbl'
   
=========================================================== MESSAGE MANAGER ===
  ]]
  
local msg_users = lang.msg_users or [[


=== MESSAGE MANAGER ================================

               Blockmode              Username
  -------------------------------------------------------------------------------------

%s
  -------------------------------------------------------------------------------------
               m = main   |   p = pm   |   b = both

================================ MESSAGE MANAGER ===
  ]]
  
local msg_settings = lang.msg_settings or [[


=== MESSAGE MANAGER =====================================

   Script is active:  %s

   Blocked MAIN levels:

%s
   Blocked PM levels:

%s
===================================== MESSAGE MANAGER ===
  ]]
  

----------
--[CODE]--
----------

local oplevel = util_getlowestlevel( permission )

--// get all levelnames from blocked table in sorted order
get_blocklevels = function()
    local levels = cfg_get( "levels" ) or {}
    local msg1, msg2 = "", ""
    local tbl = {}
    local i = 1
    for k, v in pairs( permission_main ) do
        if k >= 0 then
            if not v then
                tbl[ i ] = k
                i = i + 1
            end
        end
    end
    table_sort( tbl )
    for _, level in pairs( tbl ) do
        msg1 = msg1 .. "\t" .. levels[ level ] .. "\n"
    end
    tbl = {}
    local i = 1
    for k, v in pairs( permission_pm ) do
        if k >= 0 then
            if not v then
                tbl[ i ] = k
                i = i + 1
            end
        end
    end
    table_sort( tbl )
    for _, level in pairs( tbl ) do
        msg2 = msg2 .. "\t" .. levels[ level ] .. "\n"
    end
    return msg1, msg2
end

--// returns value of a bool as string
get_bool = function( var )
    local msg = "false"
    if var then msg = "true" end
    return msg
end

--// check if target user is online
is_online = function( user, target )
    local target = hub_isnickonline( target )
    if target then
        if target:isbot() then
            return "bot"
        else
            return target:firstnick(), target:nick(), target:level()
        end
    end
    return nil
end

--// check if target user is already blocked
is_blocked = function( nick, level )
    if not permission_pm[ level ] then
        return true, "p"
    end
    if not permission_main[ level ] then
        return true, "m"
    end
    for k, v in pairs( block_tbl ) do
        if k == nick then return true, v end
    end
    return false, nil
end

--// report
send_report = function( msg, minlevel )
    if report then
        if report_hubbot then
            for sid, user in pairs( hub_getusers() ) do
                local user_level = user:level()
                if user_level >= minlevel then
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

if activate then
    onbmsg = function( user, command, parameters )
        local user_nick = user:nick()
        local user_level = user:level()
        local target_firstnick, target_nick, target_level
        local p1 = utf_match( parameters, "^(%S+)" )
        local p2, p3 = utf_match( parameters, "^(%S+) (%S+)" )
        --// [+!#]msgmanager showusers
        if ( p1 == cmd_ss ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local levels_main, levels_pm = get_blocklevels()
            local msg = utf_format( msg_settings, get_bool( activate), levels_main, levels_pm )
            user:reply( msg, hub_getbot )
            return PROCESSED
        end
        --// [+!#]msgmanager showusers
        if ( p1 == cmd_su ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local msg = ""
            for k, v in pairs( block_tbl ) do
                msg = msg .. "\t" .. v .. "\t\t" .. k .. "\n"
            end
            local msg_out = utf_format( msg_users, msg )
            user:reply( msg_out, hub_getbot )
            return PROCESSED
        end
        --// [+!#]msgmanager blockmain <NICK>
        if ( ( p2 == cmd_b1 ) and p3 ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local target_firstnick, target_nick, target_level = is_online( user, p3 )
            if target_firstnick then
                if target_firstnick ~= "bot" then
                    if ( ( permission[ user_level ] or 0 ) < target_level ) then
                        user:reply( msg_god, hub_getbot )
                        return PROCESSED
                    end
                    if not is_blocked( target_firstnick, target_level ) then
                        block_tbl[ target_firstnick ] = "m"
                        util_savetable( block_tbl, "block_tbl", block_file )
                        local msg = utf_format( msg_block, target_nick, "main" )
                        user:reply( msg, hub_getbot )
                        msg = utf_format( msg_report_block, user_nick, target_nick, "main" )
                        send_report( msg, llevel )
                        return PROCESSED
                    else
                        user:reply( msg_stillblocked, hub_getbot )
                        return PROCESSED
                    end
                else
                    user:reply( msg_isbot, hub_getbot )
                    return PROCESSED
                end
            else
                user:reply( msg_notonline, hub_getbot )
                return PROCESSED
            end
        end
        --// [+!#]msgmanager blockpm <NICK>
        if ( ( p2 == cmd_b2 ) and p3 ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local target_firstnick, target_nick, target_level = is_online( user, p3 )
            if target_firstnick then
                if target_firstnick ~= "bot" then
                    if ( ( permission[ user_level ] or 0 ) < target_level ) then
                        user:reply( msg_god, hub_getbot )
                        return PROCESSED
                    end
                    if not is_blocked( target_firstnick, target_level ) then
                        block_tbl[ target_firstnick ] = "p"
                        util_savetable( block_tbl, "block_tbl", block_file )
                        local msg = utf_format( msg_block, target_nick, "pm" )
                        user:reply( msg, hub_getbot )
                        msg = utf_format( msg_report_block, user_nick, target_nick, "pm" )
                        send_report( msg, llevel )
                        return PROCESSED
                    else
                        user:reply( msg_stillblocked, hub_getbot )
                        return PROCESSED
                    end
                else
                    user:reply( msg_isbot, hub_getbot )
                    return PROCESSED
                end
            else
                user:reply( msg_notonline, hub_getbot )
                return PROCESSED
            end
        end
        --// [+!#]msgmanager blockboth <NICK>
        if ( ( p2 == cmd_b3 ) and p3 ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local target_firstnick, target_nick, target_level = is_online( user, p3 )
            if target_firstnick then
                if target_firstnick ~= "bot" then
                    if ( ( permission[ user_level ] or 0 ) < target_level ) then
                        user:reply( msg_god, hub_getbot )
                        return PROCESSED
                    end
                    if not is_blocked( target_firstnick, target_level ) then
                        block_tbl[ target_firstnick ] = "b"
                        util_savetable( block_tbl, "block_tbl", block_file )
                        local msg = utf_format( msg_block, target_nick, "main + pm" )
                        user:reply( msg, hub_getbot )
                        msg = utf_format( msg_report_block, user_nick, target_nick, "main + pm" )
                        send_report( msg, llevel )
                        return PROCESSED
                    else
                        user:reply( msg_stillblocked, hub_getbot )
                        return PROCESSED
                    end
                else
                    user:reply( msg_isbot, hub_getbot )
                    return PROCESSED
                end
            else
                user:reply( msg_notonline, hub_getbot )
                return PROCESSED
            end
        end
        --// [+!#]msgmanager unblock <NICK>
        if ( ( p2 == cmd_u ) and p3 ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local target_firstnick, target_nick, target_level = is_online( user, p3 )
            if target_firstnick then
                local found = false
                for k, v in pairs( block_tbl ) do
                    if k == target_firstnick then
                        block_tbl[ k ] = nil
                        found = true
                        break
                    end
                end
                if found then
                    util_savetable( block_tbl, "block_tbl", block_file )
                    local msg = utf_format( msg_unblock, target_nick )
                    user:reply( msg, hub_getbot )
                    msg = utf_format( msg_report_unblock, user_nick, target_nick )
                    send_report( msg, llevel )
                    return PROCESSED
                else
                    user:reply( msg_notfound, hub_getbot )
                    return PROCESSED
                end
            else
                user:reply( msg_notonline, hub_getbot )
                return PROCESSED
            end
        end
        user:reply( msg_usage, hub_getbot )
        return PROCESSED
    end
    --// main
    hub.setlistener( "onBroadcast", { },
        function( user, adccmd, msg )
            local user_firstnick, user_level = user:firstnick(), user:level()
            local block, mode = is_blocked( user_firstnick, user_level )
            if block then
                if ( ( mode == "m" ) or ( mode == "b" ) ) then
                    user:reply( msg_denied_main, hub_getbot )
                    return PROCESSED
                end
            end
        end
    )
    --// pm
    hub.setlistener( "onPrivateMessage", {},
        function( user, targetuser, adccmd, msg )
            local user_firstnick, user_level = user:firstnick(), user:level()
            local block, mode = is_blocked( user_firstnick, user_level )
            if block then
                if ( ( mode == "p" ) or ( mode == "b" ) ) then
                    user:reply( msg_denied_pm, hub_getbot, targetuser )
                    return PROCESSED
                end
            end
        end
    )
    --// script start
    hub.setlistener( "onStart", {},
        function()
            block_tbl = util_loadtable( block_file )
            --// help, ucmd, hucmd
            local help = hub_import( "cmd_help" )
            if help then
                help.reg( help_title, help_usage, help_desc, oplevel )
            end
            local ucmd = hub_import( "etc_usercommands" )
            if ucmd then
                ucmd.add( ucmd_menu_ct1_1, cmd, { cmd_ss }, { "CT1" }, oplevel )
                ucmd.add( ucmd_menu_ct1_2, cmd, { cmd_su }, { "CT1" }, oplevel )
                ucmd.add( ucmd_menu_ct2_1, cmd, { cmd_b1, "%[userNI]" }, { "CT2" }, oplevel )
                ucmd.add( ucmd_menu_ct2_2, cmd, { cmd_b2, "%[userNI]" }, { "CT2" }, oplevel )
                ucmd.add( ucmd_menu_ct2_3, cmd, { cmd_b3, "%[userNI]" }, { "CT2" }, oplevel )
                ucmd.add( ucmd_menu_ct2_4, cmd, { cmd_u,  "%[userNI]" }, { "CT2" }, oplevel )
            end
            local hubcmd = hub_import( "etc_hubcommands" )
            assert( hubcmd )
            assert( hubcmd.add( cmd, onbmsg ) )
            return nil
        end
    )
end

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )