require "__core__/lualib/util"
local mod_gui = require '__core__/lualib/mod-gui'

local v = require '__AutoTrash__/semver'
local lib_control = require '__AutoTrash__/lib_control'
local GUI = require "__AutoTrash__/gui"
local presets = require "__AutoTrash__/presets"

local saveVar = lib_control.saveVar
local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local get_requests = lib_control.get_requests
local pause_requests = lib_control.pause_requests
local set_trash = lib_control.set_trash
local pause_trash = lib_control.pause_trash
local unpause_trash = lib_control.unpause_trash
local unpause_requests = lib_control.unpause_requests
local in_network = lib_control.in_network
local item_prototype = lib_control.item_prototype

local function cleanup_table(tbl, tbl_name)
    if tbl then
        log("Cleaning " .. tostring(tbl_name) or "table")
        local r = 0
        for i, p in pairs(tbl) do
            if p and not p.name or (p.name and p.name == "") then
                tbl[i] = nil
                r = r + 1
            end
        end
        if r > 0 then
            log("Removed " .. r .. " invalied entries")
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
            if p.name and item_prototype(p.name) then
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
    log("Merging Request and Trash slots")
    local config, no_slot

    log("Processing requests")
    local tmp, max_slot, by_name = update_item_config(stored, player)

    no_slot = {}
    log("Merging trash")
    for i, trash in pairs(stored_trash) do
        config = by_name[trash.name]
        if config then
            if config.request > trash.count then
                log("Adjusting trash amount for " .. trash.name .. " from " .. trash.count .. " to " .. config.request)
            end
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
                log("Assigning slot " .. serpent.line(s))
                tmp.max_slot = tmp.max_slot > i and tmp.max_slot or i
                break
            end
        end
    end
    return tmp
end

local function convert_storage(storage, player)
    if not storage or not storage.store then
        return {}
    end

    local tmp = {}
    for name, stored in pairs(storage.store) do
        log("Converting: " .. name)
        tmp[name] = update_item_config(stored, player)
    end
    return tmp
end

local function requested_items(player)
    if not player.character then
        return {}
    end
    local requests = {}
    local get_request_slot = player.character.get_request_slot
    local t, max_slot
    for c = player.character.request_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = t.count
        end
    end
    return requests
end

local default_settings = {
    trash_above_requested = false,
    trash_unrequested = false,
    trash_network = false,
    pause_trash = false,
    pause_requests = false,
    clear_option = 1,
}

local function init_global()
    global = global or {}
    global["config"] = global["config"] or {}
    global["config_new"] = global["config_new"] or {}
    global["config_tmp"] =  global["config_tmp"] or {}
    global.selected = global.selected or {}
    global["storage"] = global["storage"] or {}
    global["storage_new"] = global["storage_new"] or {}

    global.mainNetwork = global.mainNetwork or {}
    global.temporaryTrash = global.temporaryTrash or {}
    global.temporaryRequests = global.temporaryRequests or {}
    global.settings = global.settings or {}
    global.dirty = global.dirty or {}
    global.selected_presets = global.selected_presets or {}
    global.death_presets = global.death_presets or {}

    global.gui_actions = global.gui_actions or {}
    global.gui_elements = global.gui_elements or {}
end

local function init_player(player)
    local index = player.index
    global.config[index] = global.config[index] or {}
    global.config_new[index] = global.config_new[index] or {config = {}, c_requests = 0, max_slot = 0}
    global.config_tmp[index] = global.config_tmp[index] or {config = {}, c_requests = 0, max_slot = 0}
    global.selected[index] = global.selected[index] or false

    global.mainNetwork[index] = false
    global.storage[index] = global.storage[index] or {}
    global.storage_new[index] = global.storage_new[index] or {}
    global.temporaryRequests[index] = global.temporaryRequests[index] or {}
    global.temporaryTrash[index] = global.temporaryTrash[index] or {}
    global.settings[index] = global.settings[index] or util.table.deepcopy(default_settings)
    global.dirty[index] = global.dirty[index] or false
    global.selected_presets[index] = global.selected_presets[index] or {}
    global.death_presets[index] = global.death_presets[index] or {}

    global.gui_actions[index] = global.gui_actions[index] or {}
    global.gui_elements[index] = global.gui_elements[index] or {}
    GUI.init(player)
end

local function init_players(resetGui)
    for _, player in pairs(game.players) do
        if resetGui then
            GUI.delete(player.index)
        end
        init_player(player)
    end
end

local function on_player_trash_inventory_changed(event)
    local player = game.get_player(event.player_index)
    if not (player.character and player.get_inventory(defines.inventory.character_trash).is_empty()) then return end
    local main_inventory_count = player.get_main_inventory().get_item_count
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local desired, changed
    for name, saved_count in pairs(global.temporaryTrash[player.index]) do
        if trash_filters[name] then
             desired = requests[name] and requests[name] or 0
            if main_inventory_count(name) <= desired then
                player.print({"", "Removed ", item_prototype(name).localised_name, " from temporary trash"})
                trash_filters[name] = saved_count >= 0 and saved_count or nil
                global.temporaryTrash[player.index][name] = nil
                changed = true
            end
        end
    end
    if changed then
        player.auto_trash_filters = trash_filters
        for _, trash in pairs(global.temporaryTrash) do
            if next(trash) then
                --some player has stuff in temporaryTrash, don't unregister the event
                return
            end
        end
        log("unregistering on_player_trash_inventory_changed")
        script.on_event(defines.events.on_player_trash_inventory_changed, nil)
    end
end

local function register_conditional_events()
    local handler
    for _, trash in pairs(global.temporaryTrash) do
        if next(trash) then
            --some player has stuff in temporaryTrash, register the event
            handler = on_player_trash_inventory_changed
            break
        end
    end
    if handler then
        log("registering on_player_trash_inventory_changed")
    else
        log("not registering on_player_trash_inventory_changed")
    end
    script.on_event(defines.events.on_player_trash_inventory_changed, handler)
end

local function on_load()
    register_conditional_events()
end

local function on_init()
    init_global()
    on_load()
end

local function on_pre_player_removed(event)
    local player_index = event.player_index
    log("Removing invalid player index " .. player_index)
    for name, _ in pairs(global) do
        if name ~= "version" then
            global[name][player_index] = nil
        end
    end
    register_conditional_events()
end

local function remove_invalid_items(tbl, unselect)
    local item_config
    for pi, p in pairs(tbl) do
        for i = p.max_slot, 1, -1 do
            item_config = p.config[i]
            if item_config then
                if not item_prototype(item_config.name) then
                    if p.config[i].request > 0 then
                        p.c_requests = p.c_requests - 1
                    end
                    p.config[i] = nil
                    if p.max_slot == i then
                        p.max_slot = false
                    end
                    if unselect and global.selected[pi] and global.selected[pi] == i then
                        global.selected[pi] = false
                    end
                else
                    p.max_slot = p.max_slot or i
                end
            end
        end
    end
end

local function on_configuration_changed(data)
    --log(serpent.block(data))
    if not data then return end
    if data.mod_changes and data.mod_changes.AutoTrash then
        local newVersion = data.mod_changes.AutoTrash.new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes.AutoTrash.old_version
        oldVersion = oldVersion and v(oldVersion)
        log("Updating AutoTrash from " .. tostring(oldVersion) .. " to " .. tostring(newVersion))
        if oldVersion then
            if oldVersion < v'0.0.55' then
                global = nil
            end
            init_global()
            init_players()

            if oldVersion < v'4.1.0' then
                -- just in case someone removed offline players
                for pi, _ in pairs(global.config) do
                    if not game.get_player(pi) then
                        on_pre_player_removed{player_index = pi}
                    end
                end
                saveVar(global, "storage_pre")
                global.needs_import = {}
                local settings, paused_requests
                local status, err
                for pi, player in pairs(game.players) do
                    log("Updating data for player " .. player.name .. ", index: " .. pi)
                    GUI.close(player)
                    global.needs_import[pi] = true
                    settings = global.settings[pi]
                    settings.pause_trash = not global.active[pi]
                    settings.pause_requests = not global["logistics-active"][pi]
                    if remote.interfaces.YARM then
                        settings.YARM_active_filter = remote.call("YARM", "get_current_filter", pi)
                    end
                    settings.clear_option = settings.clear_option or 1
                    settings.trash_above_requested = settings.auto_trash_above_requested or false
                    settings.trash_unrequested = settings.auto_trash_unrequested or false
                    settings.trash_network = settings.auto_trash_in_main_network or false

                    settings.YARM_old_expando = nil
                    settings.options_extended = nil

                    settings.auto_trash_above_requested = nil
                    settings.auto_trash_unrequested = nil
                    settings.auto_trash_in_main_network = nil

                    status, err = pcall(function()
                        cleanup_table(global.config[pi], "trash table")
                        cleanup_table(global["logistics-config"][pi], "requests table")
                    end)
                    if not status then
                        debugDump("Error cleaning config tables:", player, true)
                        debugDump(err, player, true)
                    end

                    log("Cleaning storage")
                    status, err = pcall(function()
                        if global.storage[pi].store then
                            for _, stored in pairs(global.storage[pi].store) do
                                cleanup_table(stored, _)
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
                        global.config_new[pi] = convert_logistics(paused_requests, global.config[pi], player)
                        global.config_tmp[pi] = util.table.deepcopy(global.config_new[pi])
                    end)
                    if not status then
                        debugDump("Error converting configuration:", player, true)
                        debugDump(err, player, true)
                        global.config_new[pi] = nil
                        global.config_tmp[pi] = nil
                        init_player(player)
                    end
                    global.temporaryRequests[pi] = {}
                    global.temporaryTrash[pi] = {}

                    log("Converting storage")
                    global.storage_new[pi] = convert_storage(global.storage[pi], player)
                    GUI.update_main_button(pi)
                    GUI.open_logistics_frame(player)
                end

                global.config = nil
                global["logistics-config"] = nil
                global["storage"] = nil

                global.guiData = nil
                global.active = nil
                global.configSize = nil
                global["logistics-active"] = nil
                global["config-tmp"] = nil
                global["logistics-config-tmp"] = nil
                saveVar(global, "storage_post")
            end
        end

        global.version = newVersion
    end

    init_global()
    init_players()
    on_load()
    remove_invalid_items(global.config_new)
    remove_invalid_items(global.config_tmp, true)
    for _, stored in pairs(global.storage_new) do
        remove_invalid_items(stored)
    end
end

local function on_player_created(event)
    init_player(game.get_player(event.player_index))
end

local trash_blacklist = {
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-item"] = true,
    ["upgrade-item"] = true,
    ["copy-paste-tool"] = true,
    ["selection-tool"] = true,
}

local function on_player_main_inventory_changed(event)
    local settings = global.settings[event.player_index]
    if settings.pause_trash or not settings.trash_unrequested then return end
    local player = game.get_player(event.player_index)
    if not (player.character) then return end
    --that's a bad event to handle unrequested, since adding stuff to the trash filters immediately triggers the next on_main_inventory_changed event
    -- on_nth_tick might work better or only registering when some player has trash_unrequested set to true
    local trash_filters = player.auto_trash_filters
    local contents = player.get_main_inventory().get_contents()
    local requests = get_requests(player)
    for name, _ in pairs(contents) do
        if not requests[name] and not trash_filters[name] and not trash_blacklist[item_prototype(name).type] then
            trash_filters[name] = 0
        end
    end
    player.auto_trash_filters = trash_filters
end

local function add_to_trash(player, item)
    local player_index = player.index
    if trash_blacklist[item] then
        display_message(player, {"", item_prototype(item).localised_name, " is on the blacklist for trashing"}, true)
        return
    end
    local trash_filters = player.auto_trash_filters
    global.temporaryTrash[player_index][item] = trash_filters[item] or -1 ---1: wasn't set, remove when cleaning temporaryTrash
    if not trash_filters[item] then
        local requests = requested_items(player)
        trash_filters[item] = requests[item] or 0
        log(serpent.block(trash_filters))
        player.auto_trash_filters = trash_filters
    end
    log("registering trash inventory changed")
    script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)
    player.print({"", "Added ", item_prototype(item).localised_name, " to temporary trash"})
end

local function on_player_toggled_map_editor(event)
    local player = game.get_player(event.player_index)
    if not player.character then
        GUI.close(player, true)
    end
end

local function on_pre_player_died(event)
    local player = game.get_player(event.player_index)
    if player.mod_settings["autotrash_pause_on_death"].value then
        pause_requests(player)
        GUI.update_main_button(player.index)
        GUI.close(player, true)
    end
end

local function on_player_respawned(event)
    local player_index = event.player_index
    local selected_presets = global.death_presets[player_index]
    if table_size(selected_presets) > 0 then
        local player = game.get_player(player_index)
        local tmp = {config = {}, max_slot = 0}
        for key, _ in pairs(selected_presets) do
            presets.merge(tmp, global.storage_new[player_index][key])
        end
        GUI.close(player)
        global.config_tmp[player_index] = tmp
        global.config_new[player_index] = util.table.deepcopy(tmp)

        unpause_requests(player)
        unpause_trash(player)
        GUI.update_main_button(player_index)
    end
end

local function on_player_changed_position(event)
    if not global.settings[event.player_index].autotrash_network then
        return
    end
    local player = game.get_player(event.player_index)
    if player.character then
        local is_in_network = in_network(player)
        local paused = global.settings[event.player_index].pause_trash
        if not is_in_network and not paused then
            pause_trash(player)
            GUI.update_main_button(player.index)
            if player.mod_settings["autotrash_display_messages"].value then
                display_message(player, "AutoTrash paused")
            end
            return
        elseif is_in_network and paused then
            unpause_trash(player)
            GUI.update_main_button(player.index)
            if player.mod_settings["autotrash_display_messages"].value then
                display_message(player, "AutoTrash unpaused")
            end
        end
    end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_player_main_inventory_changed, on_player_main_inventory_changed)

script.on_event(defines.events.on_player_toggled_map_editor, on_player_toggled_map_editor)
script.on_event(defines.events.on_pre_player_removed, on_pre_player_removed)
script.on_event(defines.events.on_pre_player_died, on_pre_player_died)
script.on_event(defines.events.on_player_respawned, on_player_respawned)
script.on_event(defines.events.on_player_changed_position, on_player_changed_position)

local function on_pre_mined_item(event)
    local status, err = pcall(function()
        if event.entity.type == "roboport" then
            for player_index, entity in pairs(global.mainNetwork) do
                if entity == event.entity then
                    --get another roboport from the network
                    local newEntity = false
                    if entity.logistic_network and entity.logistic_network.valid then
                        for _, cell in pairs(entity.logistic_network.cells) do
                            if cell.owner ~= entity and cell.owner.valid then
                                newEntity = cell.owner
                                break
                            end
                        end
                    end
                    if not newEntity and global.mainNetwork[player_index] then
                        game.get_player(player_index).print("Autotrash main network has been unset")
                    end
                    global.mainNetwork[player_index] = newEntity
                    GUI.update_settings(player_index)
                end
            end
        end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

script.on_event(defines.events.on_pre_player_mined_item, on_pre_mined_item)
script.on_event(defines.events.on_robot_pre_mined, on_pre_mined_item)
script.on_event(defines.events.on_entity_died, on_pre_mined_item)

local function add_order(player)--luacheck: ignore
    local entities = player.cursor_stack.get_blueprint_entities()
    local orders = {}
    for _, ent in pairs(entities) do
        if not orders[ent.name] then
            orders[ent.name] = 0
        end
        orders[ent.name] = orders[ent.name] + 1
    end
end

function add_to_requests(player, item, count)--luacheck: ignore

end

local function toggle_autotrash_pause(player)
    if global.settings[player.index].pause_trash then
        unpause_trash(player)
    else
        pause_trash(player)
    end
    GUI.update_main_button(player.index)
    GUI.close(player)
end

local function toggle_autotrash_pause_requests(player)
    if global.settings[player.index].pause_requests then
        unpause_requests(player)
    else
        pause_requests(player)
    end
    GUI.update_main_button(player.index)
    GUI.close(player)
end

local gui_settings = {
    ["autotrash_gui_columns"] = true,
    ["autotrash_gui_max_rows"] = true,
}
local function on_runtime_mod_setting_changed(event)
    local player_index = event.player_index
    local player = game.get_player(event.player_index)
    if gui_settings[event.setting] then
        if player_index then
            GUI.create_buttons(player)
        else
            --update all guis, value was changed by script
            for _, p in pairs(game.players) do
                GUI.create_buttons(p)
            end
        end
    end
    if event.setting == "autotrash_threshold" then
        if player_index then
            local settings = global.settings[player_index]
            if not settings.pause_trash and settings.trash_above_requested then
                set_trash(player)
            end
        else
            local settings = global.settings
            for pi, p in pairs(game.players) do
                if not settings[pi].pause_trash and settings[pi].trash_above_requested then
                    set_trash(p)
                end
            end
        end

    end
end

script.on_event(defines.events.on_gui_click, GUI.generic_event)
script.on_event(defines.events.on_gui_checked_state_changed, GUI.generic_event)
script.on_event(defines.events.on_gui_elem_changed, GUI.generic_event)
script.on_event(defines.events.on_gui_value_changed, GUI.generic_event)
script.on_event(defines.events.on_gui_text_changed, GUI.generic_event)
script.on_event(defines.events.on_gui_selection_state_changed, GUI.generic_event)

script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

local function on_research_finished(event)
    if event.research.name == "character-logistic-trash-slots-1" or
        event.research.name == "character-logistic-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player)
        end
        return
    end
end
script.on_event(defines.events.on_research_finished, on_research_finished)

script.on_event("autotrash_pause", function(e)
    toggle_autotrash_pause(game.get_player(e.player_index))
end)

script.on_event("autotrash_pause_requests", function(e)
    toggle_autotrash_pause_requests(game.get_player(e.player_index))
end)

local function autotrash_trash_cursor(event)
    local player = game.get_player(event.player_index)
    if player.force.technologies["character-logistic-trash-slots-1"].researched then
        local cursorStack = player.cursor_stack
        if cursorStack.valid_for_read then
            add_to_trash(player, cursorStack.name)
        else
            toggle_autotrash_pause(player)
        end
    end
end
script.on_event("autotrash_trash_cursor", autotrash_trash_cursor)

local at_commands = {
    reload = function()
        game.reload_mods()

        local button_flow = mod_gui.get_button_flow(game.player)[GUI.defines.main_button]
        if button_flow and button_flow.valid then
            GUI.deregister_action(button_flow)
            button_flow.destroy()
        end

        init_global()
        init_players()
        game.player.print("Mods reloaded")
    end,

    hide = function(args)
        local button = global.gui_elements[args.player_index].main_button
        if button and button.valid then
            button.visible = false
        end
    end,

    show = function(args)
        local button = global.gui_elements[args.player_index].main_button
        if button and button.valid then
            button.visible = true
        end
    end,
}

commands.add_command("reload_mods", "", at_commands.reload)
commands.add_command("at_hide", "Hide the AutoTrash button", at_commands.hide)
commands.add_command("at_show", "Show the AutoTrash button", at_commands.show)

remote.add_interface("at",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init_gui = function()
            GUI.init(game.player)
        end,

        logistic = function()
            -- local function get_name(m)
            --     for k, value in pairs(defines.logistic_mode) do
            --         if m == value then
            --             return k
            --         end
            --     end

            -- end
            local req = game.player.character.get_logistic_point(defines.logistic_member_index.character_requester) --requests of the player
            log(serpent.block(req.targeted_items_deliver))-- items on the way
            log(serpent.block(game.player.character.logistic_network.get_contents())) --network the player is in
            --log(serpent.block(req.filters))

        end,

        test = function(max)
            GUI.close(game.player)
            for j = 1, max or 1 do
                local p = game.create_profiler()
                for i = 1, 100 do
                    if not game.player.get_inventory(defines.inventory.character_trash).is_empty() then--luacheck:ignore

                    end
                    -- GUI.open_logistics_frame(game.player)
                    -- GUI.close(game.player)
                end
                p.stop()
                log{"", p}
            end
        end
    })
