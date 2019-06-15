local lib_control = require '__AutoTrash__/lib_control'

local debugDump = lib_control.debugDump

local function cleanup_table(tbl, tbl_name)--luacheck: ignore
    if tbl then
--        log("Cleaning " .. tostring(tbl_name) or "table")
        local r = 0
        for i, p in pairs(tbl) do
            if p and not p.name or (p.name and p.name == "") then
                tbl[i] = nil
                r = r + 1
            end
        end
    end
end

local function update_item_config(stored, player)
    local tmp = {config = {}, c_requests = 0}
    local by_name = {}
    local max_slot = 0
    local c = 0
    local status, err = pcall(function()
        for i, p in pairs(stored) do
            if p.name and lib_control.item_prototype(p.name) then
                tmp.config[i] = {
                    name = p.name,
                    request = p.count and p.count or 0,
                    trash = false,
                    slot = i
                }
                by_name[p.name] = tmp.config[i]
                max_slot = max_slot < i and i or max_slot
                if tmp.config[i].request > 0 then
                    c = c + 1
                end
            else
                debugDump("Removing unknown item: " .. tostring(p.name) .. "(slot: " .. i ..")", player, true)
            end
        end
    end)
    if not status then
        debugDump("Error updating item configuration:", player, true)
        debugDump(err, player, true)
        tmp = {config = {}, c_requests = 0}
        by_name = {}
        max_slot = 0
        c = 0
    end
    tmp.c_requests = c
    tmp.max_slot = max_slot
    return tmp, max_slot, by_name
end

local function convert_logistics(stored, stored_trash, player)
    --log("Merging Request and Trash slots")
    local config, no_slot

    --log("Processing requests")
    local tmp, max_slot, by_name = update_item_config(stored, player)

    no_slot = {}
    --log("Merging trash")
    for i, trash in pairs(stored_trash) do
        config = by_name[trash.name]
        if config then
            -- if config.request > trash.count then
            --     log("Adjusting trash amount for " .. trash.name .. " from " .. trash.count .. " to " .. config.request)
            -- end
            config.trash = (config.request > trash.count) and config.request or trash.count
            tmp.config[config.slot] = config
        else
            no_slot[#no_slot+1] = {
                name = trash.name,
                request = 0,
                trash = trash.count,
                slot = false
            }
        end
    end
    local start = 1
    for _, s in pairs(no_slot) do
        for i = start, max_slot + #no_slot do
            if not tmp.config[i] then
                s.slot = i
                tmp.config[i] = s
                start = i + 1
                --log("Assigning slot " .. serpent.line(s))
                tmp.max_slot = tmp.max_slot > i and tmp.max_slot or i
                break
            end
        end
    end
    return tmp
end

local convert = {}

convert.to_4_1_2 = function(GUI, init_global, init_player, register_conditional_events)
    global.temporaryRequests = nil
    global.temporaryTrash = nil
    global.defines_player_trash = nil
    init_global()
    local status_main, err_main = pcall(function()
    lib_control.saveVar(global, "storage_pre")
    local settings, paused_requests, status_i, err_i
    local status, err, pdata
    for pi, player in pairs(game.players) do
        status_i, err_i = pcall(function()
            log("Updating data for player " .. player.name .. ", index: " .. pi)
            init_player(player)
            pdata = global._pdata[pi]
            settings = global.settings[pi]
            settings.pause_trash = not global.active[pi]
            settings.pause_requests = not global["logistics-active"][pi]
            if remote.interfaces.YARM then
                settings.YARM_active_filter = remote.call("YARM", "get_current_filter", pi)
            end
            settings.trash_above_requested = settings.auto_trash_above_requested or false
            settings.trash_unrequested = settings.auto_trash_unrequested or false
            settings.trash_network = settings.auto_trash_in_main_network or false

            settings.auto_trash_above_requested = nil
            settings.auto_trash_unrequested = nil
            settings.auto_trash_in_main_network = nil
            settings.YARM_old_expando = nil
            settings.options_extended = nil

            pdata.settings = settings
            pdata.main_network = global.mainNetwork[pi] or false
            pdata.current_network = lib_control.get_network_entity(player)

            status, err = pcall(function()
                cleanup_table(global.config[pi], "trash table")
                cleanup_table(global["logistics-config"][pi], "requests table")
            end)
            if not status then
                debugDump("Error cleaning config tables:", player, true)
                debugDump(err, player, true)
            end

            status, err = pcall(function()
                if global.storage[pi].store then
                    for name, stored in pairs(global.storage[pi].store) do
                        cleanup_table(stored, name)
                    end
                end
                if settings.pause_requests and global.storage[pi].requests and #global.storage[pi].requests > 0 then
                    cleanup_table(global.storage[pi].requests, "paused requests")
                    paused_requests = global.storage[pi].requests
                else
                    paused_requests = global["logistics-config"][pi]
                end
            end)
            if not status then
                debugDump("Error cleaning storage tables:", player, true)
                debugDump(err, player, true)
            end

            status, err = pcall(function()
                pdata.config_new = convert_logistics(paused_requests, global.config[pi], player)
                pdata.config_tmp = util.table.deepcopy(pdata.config_new)
            end)
            if not status then
                debugDump("Error converting configuration:", player, true)
                debugDump(err, player, true)
                pdata.config_new = nil
                pdata.config_tmp = nil
                init_player(player)
            end
            pdata.temporary_requests = {}
            pdata.temporary_trash = {}

            if not global.storage[pi] or not global.storage[pi].store then
                pdata.storage_new = {}
            else
                local tmp = {}
                for name, stored in pairs(global.storage[pi].store) do
                    --log("Converting: " .. name)
                    tmp[name] = update_item_config(stored, player)
                end
                pdata.storage_new = tmp
            end
            GUI.update_main_button(pdata)
        end)
        if not status_i then
            debugDump("Error updating:", false, true)
            debugDump(err_i, false, true)
            debugDump("Resetting AutoTrash configuration for player " .. player.name, false, true)
            local keep = {gui_actions = true, gui_elements = true}
            for name, _ in pairs(pdata) do
                if not keep[name] then
                    pdata[name] = nil
                end
            end
            init_player(player)
            register_conditional_events()
            GUI.update_main_button(pdata)
            GUI.close(player, pdata)
        end
        if pdata.gui_elements.main_button then
            GUI.open_config_frame(player, pdata)
        end
    end

    global.config = nil
    global["logistics-active"] = nil
    global["config-tmp"] = nil
    global["logistics-config-tmp"] = nil
    global["logistics-config"] = nil
    global.storage = nil
    global.mainNetwork = nil
    global.guiData = nil
    global.active = nil
    global.configSize = nil
    global.settings = nil
    end)
    if not status_main then
        debugDump("Error updating:", false, true)
        debugDump(err_main, false, true)
        debugDump("Resetting AutoTrash configuration for all players", false, true)
        local keep = {version = true, gui_actions = true, gui_elements = true}
        for name, _ in pairs(global) do
            if not keep[name] then
                global[name] = nil
            end
        end
        init_global()
        for pi, player in pairs(game.players) do
            init_player(player)
            GUI.update_main_button(global._pdata[pi])
            GUI.close(player, global._pdata[pi])
        end
        register_conditional_events()
    end
end

return convert