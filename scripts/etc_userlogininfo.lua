﻿--[[

	etc_userlogininfo.lua by pulsar

        v0.13:
            - using new luadch date style
        
        v0.12:
            - improved get_lastlogout() function
            
        v0.11:
            - added info about CCPM permission
            - added lastlogout info
            - code cleaning and new table lookups

        v0.10:
            - changed visual output style

        v0.09:
            - changed visual output style
            - code cleaning
            - table lookups
            - removed "msg_user_on", "msg_user_max", "msg_slots_min", "msg_slots_max"

        v0.08
            - export scriptsettings to "/cfg/cfg.tbl"

        v0.07
            - Kleiner Bugfix

        v0.06
            - added: Hubname + Version (Toggle on/off)
            - added: Registriert von, Registriert am
            - added: Users Online, Users Max.
            - added: Min. Slots, Max. Slots

        v0.05
            - added: Hubname + Version

        v0.04
            - added: Client Mode
            - added: Client SSL Check

        v0.03
            - added: Levelnummer
            - added: Client Version

        v0.02
            - added Multilanguage Support

        v0.01
            - send a basic userinfo on login
]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_userlogininfo"
local scriptversion = "0.13"

--// table lookups
local cfg_get = cfg.get
local cfg_loadlanguage = cfg.loadlanguage
local hub_getbot = hub.getbot()
local hub_escapefrom = hub.escapefrom
local hub_getregusers = hub.getregusers
local hub_getusers = hub.getusers
local hub_debug = hub.debug
local util_loadtable = util.loadtable
local util_formatseconds = util.formatseconds
local utf_format = utf.format
local os_difftime = os.difftime
local os_time = os.time
local util_date = util.date
local util_difftime = util.difftime

--// imports
local scriptlang = cfg_get( "language" )
local lang, err = cfg_loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub_debug( err )
local permission = cfg_get( "etc_userlogininfo_permission" )
local show_hubversion = cfg_get( "etc_userlogininfo_show_hubversion" )
local block_level = cfg_get( "etc_ccpmblocker_block_level" )
local const_file = "core/const.lua"
local const_tbl = util_loadtable( const_file ) or {}
local const_PROGRAM = const_tbl[ "PROGRAM_NAME" ]
local const_VERSION = const_tbl[ "VERSION" ]
local PROGRAM_VERSION = const_PROGRAM .. " " .. const_VERSION

--// msgs
local client_mode_a = lang.client_mode_a or "M:A ( active )"
local client_mode_p = lang.client_mode_p or "M:P ( passive )"
local client_ssl_n = lang.client_ssl_n or "NO ( please activate it! )"
local client_ssl_y = lang.client_ssl_y or "YES"

local msg_ccpm_1 = lang.msg_ccpm_1 or "YES ( enabled for your level )"
local msg_ccpm_2 = lang.msg_ccpm_2 or "YES ( disabled for your level )"
local msg_ccpm_3 = lang.msg_ccpm_3 or "No"

local msg_years = lang.msg_years or " years, "
local msg_days = lang.msg_days or " days, "
local msg_hours = lang.msg_hours or " hours, "
local msg_minutes = lang.msg_minutes or " minutes, "
local msg_seconds = lang.msg_seconds or " seconds"

local msg_unknown = lang.msg_unknown or "<unknown>"

local msg_info_1 = lang.msg_info_1 or [[


=== USER LOGIN INFO ============================

        Your Nick:	%s
        Your IP:	%s
        Your Level:	%s  [ %s ]

        Client Version:	%s
        Client Mode:	%s
        Client SSL:	%s
        Client CCPM:   %s

        Regged by:	%s
        Regged on:	%s
        
        Last visit:  %s

============================ USER LOGIN INFO ===
   ]]

local msg_info_2 = lang.msg_info_2 or [[


=== USER LOGIN INFO ============================

        Your Nick:	%s
        Your IP:	%s
        Your Level:	%s  [ %s ]

        Client Version:	%s
        Client Mode:	%s
        Client SSL:	%s
        Client CCPM:   %s

        Regged by:	%s
        Regged on:	%s
        
        Last visit:  %s


        Hubversion:	%s

============================ USER LOGIN INFO ===
   ]]


----------
--[CODE]--
----------

local get_lastlogout = function( user )
    local lastlogout
    local profile = user:profile()
    local ll = profile.lastlogout or profile.lastconnect
    local ll_str = tostring( ll )
    if ll then
        if #ll_str == 14 then
            local sec, y, d, h, m, s = util_difftime( util_date(), ll )
            lastlogout = y .. msg_years .. d .. msg_days .. h .. msg_hours .. m .. msg_minutes .. s .. msg_seconds
        else
            local d, h, m, s = util_formatseconds( os_difftime( os_time(), ll ) )
            lastlogout = d .. msg_days .. h .. msg_hours .. m .. msg_minutes .. s .. msg_seconds
        end
    else
        lastlogout = msg_unknown      
    end
    return lastlogout
end

hub.setlistener( "onLogin", {},
    function( user )
        local user_nick = user:nick()
        local user_level = user:level()
        local user_firstnick = user:firstnick()
        local user_ip = user:ip()
        local user_version = user:version()

        if user:isregged() then
            --// client version, mode, ssl
            local level = cfg_get( "levels" )[ user_level ] or "Unreg"
            local levelnr = user:level()
            local clientv = hub_escapefrom( user_version ) or "<unknown>"
            local checkmode = function()
                local mode = client_mode_p
                if user:hasfeature( "TCP4" ) then mode = client_mode_a end
                return mode
            end
            local user_ssl = tostring( user:ssl() )
            local checkssl = function()
                local ssl = client_ssl_n
                if user_ssl then ssl = client_ssl_y end
                return ssl
            end
            
            --// registered by, date
            local by = user_nick
            local target
            local _, regnicks, regcids = hub_getregusers()
            local _, usersids = hub_getusers()
            if not ( ( by == "sid" or by == "nick" or by == "cid" ) and id ) then
                local usercid, usernick = user:cid(), user:firstnick()
                target = regnicks[ usernick ] or regcids.TIGR[ usercid ]
            else
                target = ( by == "nick" and regnicks[ id ] ) or ( by == "cid" and regcids.TIGR[ id ] ) or
                ( by == "sid" and ( usersids[ id ] and usersids[ id ].profile and usersids[ id ]:profile() ) )
            end
            local reg_by = target.by or "Luadch"
            local reg_date = target.date or "<unknown>"
            
            --// ccpm
            local ccpm_msg
            local ccpm = user:hasfeature( "CCPM" )
            if ccpm then
                if block_level[ user_level ] then ccpm_msg = msg_ccpm_2 else ccpm_msg = msg_ccpm_1 end
            else
                ccpm_msg = msg_ccpm_3
            end
            
            --// msg without hubversion
            local msg2 = utf_format( msg_info_1,
                                    user_firstnick,
                                    user_ip,
                                    levelnr, level,
                                    clientv,
                                    checkmode(),
                                    checkssl(),
                                    ccpm_msg,
                                    reg_by,
                                    reg_date,
                                    get_lastlogout( user ) )
                                        
            --// msg with hubversion
            local msg = utf_format( msg_info_2,
                                    user_firstnick,
                                    user_ip,
                                    levelnr, level,
                                    clientv,
                                    checkmode(),
                                    checkssl(),
                                    ccpm_msg,
                                    reg_by,
                                    reg_date,
                                    get_lastlogout( user ),
                                    PROGRAM_VERSION )

            if permission[ user_level ] then
                if show_hubversion then user:reply( msg, hub_getbot ) else user:reply( msg2, hub_getbot ) end
                return nil
            end
        else
            -- no infos for unregs
        end

    end
)

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )