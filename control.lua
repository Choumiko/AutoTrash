require "__core__/lualib/util"
local mod_gui = require '__core__/lualib/mod-gui'

local v = require '__AutoTrash__/semver'
local lib_control = require '__AutoTrash__/lib_control'
local GUI = require "__AutoTrash__/gui"
local presets = require "__AutoTrash__/presets"

local saveVar = lib_control.saveVar
local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_from_slider = lib_control.convert_from_slider
local set_trash = lib_control.set_trash
local set_requests = lib_control.set_requests
local get_requests = lib_control.get_requests

local gui_def = GUI.defines
local floor = math.floor

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

local function update_item_config(stored)
    local tmp = {config = {}}
    local by_name = {}
    local max_slot = 0
    for i, p in pairs(stored) do
        tmp.config[i] = {
            name = p.name,
            request = p.count and p.count or 0,
            trash = false,
            slot = i
        }
        by_name[p.name] = tmp.config[i]
        max_slot = max_slot < i and i or max_slot
        --log(serpent.line(tmp[name].config[i]))
    end
    return tmp, max_slot, by_name
end

local function convert_logistics(stored, stored_trash)
    log("Merging Request and Trash slots")
    local config, no_slot

    log("Processing requests")
    local tmp, max_slot, by_name = update_item_config(stored)

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
            --log(serpent.line(config))
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
                break
            end
        end
    end
    saveVar(tmp, "new_merge")
    return tmp
end

local function convert_storage(storage)
    if not storage or not storage.store then
        return {}
    end

    local tmp = {}
    for name, stored in pairs(storage.store) do
        log("Converting: " .. name)
        tmp[name] = update_item_config(stored)
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
    auto_trash_above_requested = false,
    auto_trash_unrequested = false,
    auto_trash_in_main_network = false,
    pause_trash = false,
    pause_requests = false,
    clear_option = 1
}

local gui_elements = {
    main_button = {},
    config_frame = {},
    config_scroll = {},
    slider_flow = {},
    trash_options = {},
    reset_button = {},
    clear_option = {},

    storage_frame = {},
    storage_textfield = {},
    storage_grid = {},
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
    global.selected_clear_option = global.selected_clear_option or {}

    global.gui_actions = global.gui_actions or {}
    global.gui_elements = global.gui_elements or gui_elements
end

--[[
config[player_index][slot] = {name = "item", min = 0, max = 100}
min: if > 0 set as request
max: if == 0 and trash unrequested
if min == max : set req = trash
if min and max : set req and trash, ensure max > min
if min and not max (== -1?) : set req, unset trash
if min == 0 and max : unset req, set trash
if min == 0 and max == 0: unset req, set trash to 0
]]

local function init_player(player)
    local index = player.index
    global.config[index] = global.config[index] or {}
    global.config_new[index] = global.config_new[index] or {config = {}}
    global["config_tmp"][index] = global["config_tmp"][index] or {config = {}}
    global.selected[index] = global.selected[index] or false

    global.mainNetwork[index] = false
    global.storage[index] = global.storage[index] or {}
    global.storage_new[index] = global.storage_new[index] or {}
    global.temporaryRequests[index] = global.temporaryRequests[index] or {}
    global.temporaryTrash[index] = global.temporaryTrash[index] or {}
    global.settings[index] = global.settings[index] or util.table.deepcopy(default_settings)
    global.dirty[index] = global.dirty[index] or false
    global.selected_presets[index] = global.selected_presets[index] or {}

    global.gui_actions[index] = global.gui_actions[index] or {}
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

local function on_init()
    log("on_init")
    init_global()
end

local function on_load()
    log("on_load")
end

local function on_pre_player_removed(event)
    log("Removing invalid player index " .. event.player_index)
    for name, _ in pairs(global) do
        if name ~= "version" then
            global[name][event.player_index] = nil
        end
    end
end

local function on_configuration_changed(data)
    --log(serpent.block(data))
    if not data then
        return
    end
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

            if oldVersion < v'4.0.6' then
                -- just in case someone removed offline players
                for pi, _ in pairs(global.config) do
                    if not game.get_player(pi) then
                        on_pre_player_removed{player_index = pi}
                    end
                end
                saveVar(global, "storage_pre")
                global.needs_import = {}
                local settings, paused_requests
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

                    settings.YARM_old_expando = nil
                    settings.options_extended = nil

                    log("Cleaning tables")
                    cleanup_table(global.config[pi], "trash table")
                    cleanup_table(global["logistics-config"][pi], "requests table")
                    log("Cleaning storage")
                    if global.storage[pi].store then
                        for _, stored in pairs(global.storage[pi].store) do
                            cleanup_table(stored, _)
                        end
                    end
                    if settings.pause_requests and global.storage[pi].requests and #global.storage[pi].requests > 0 then
                        log("paused")
                        cleanup_table(global.storage[pi].requests, "paused requests")
                        paused_requests = global.storage[pi].requests
                    else
                        log("unpaused")
                        paused_requests = global["logistics-config"][pi]
                    end

                    global.config_new[pi] = convert_logistics(paused_requests, global.config[pi])
                    global.config_tmp[pi] = util.table.deepcopy(global.config_new[pi])

                    log("Converting storage")
                    global.storage_new[pi] = convert_storage(global.storage[pi])

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
                --error("You did good")
            end
        end

        global.version = newVersion
    end

    init_global()
    init_players()
    local items = game.item_prototypes

    for _, p in pairs(global.config_new) do
        for i, item_config in pairs(p.config) do
            if item_config and not items[item_config.name] then
                    p.config[i] = nil
            end
        end
    end
    for pi, p in pairs(global.config_tmp) do
        for i, item_config in pairs(p.config) do
            if item_config and not items[item_config.name] then
                    p.config[i] = nil
                    if global.selected[pi] and global.selected[pi] == i then
                        global.selected[pi] = false
                    end
                    GUI.create_buttons(game.get_player(pi))
            end
        end
    end
end

local function on_player_created(event)
    init_player(game.get_player(event.player_index))
end

local function inMainNetwork(player)
    if not global.settings[player.index].auto_trash_in_main_network then
        return true
    end
    local currentNetwork = player.character.logistic_network
    local entity = global.mainNetwork[player.index]
    if currentNetwork and entity and entity.valid and currentNetwork == entity.logistic_network then
        return true
    end
    return false
end

local function pause_trash(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_trash = true
    --TODO backup current filters?
    player.character.auto_trash_filters = {}
    GUI.update_main_button(player.index)
end

local function unpause_trash(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_trash = false
    --TODO restore current filters?
    set_trash(player)
    GUI.update_main_button(player.index)
end

local function pause_requests(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = true
    --TODO backup current requests?
    local character = player.character
    for c = 1, character.request_slot_count do
        character.clear_request_slot(c)
    end
    GUI.update_main_button(player.index)
end

local function unpause_requests(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = false
    --TODO restore current requests?
    set_requests(player)
    GUI.update_main_button(player.index)
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
    --log("main inventory changed " .. serpent.block(event))
    -- if not trash_blacklist then
    --     trash_blacklist = {}
    --     for name, proto in pairs(game.item_prototypes) do
    --         if not proto.stackable then
    --         log(name .. " " .. proto.type)
    --         end
    --     end
    -- end
    if not global.settings[event.player_index].pause_trash and global.settings[event.player_index].auto_trash_unrequested then
        local player = game.get_player(event.player_index)
        if player.character then
            local trash_filters = player.auto_trash_filters
            local contents = player.get_main_inventory().get_contents()
            local requests = get_requests(player)
            local protos = game.item_prototypes
            for name, _ in pairs(contents) do
                if not requests[name] and not trash_filters[name]  and not trash_blacklist[protos[name].type] then
                    trash_filters[name] = 0
                end
            end
            player.auto_trash_filters = trash_filters
        end
    end
end

local function on_player_trash_inventory_changed(event)
    local player = game.get_player(event.player_index)
    local inventory = player.get_main_inventory()
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local desired, changed
    for name, saved_count in pairs(global.temporaryTrash[player.index]) do
        if trash_filters[name] then
             desired = requests[name] and requests[name] or 0
            if inventory.get_item_count(name) <= desired then
                player.print({"", "removed ", game.item_prototypes[name].localised_name, " from temporary trash"})
                log("Removed ".. name .. " " .. serpent.block(event))
                trash_filters[name] = tonumber(saved_count)
                global.temporaryTrash[player.index][name] = nil
                changed = true
            end
        end
    end
    if changed then
        player.auto_trash_filters = trash_filters
    end
end

local function add_to_trash(player, item)
    log("add to trash " .. game.tick)
    local player_index = player.index
    if trash_blacklist[item] then
        display_message(player, {"", game.item_prototypes[item].localised_name, " is on the blacklist for trashing"}, true)
        return
    end
    global.temporaryTrash[player_index][item] = player.auto_trash_filters[item] or true --true: wasn't set, remove when cleaning temporaryTrash
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    if not trash_filters[item] then
        trash_filters[item] = requests[item] or 0
        log(serpent.block(trash_filters))
        player.auto_trash_filters = trash_filters
    end
    player.print({"", "Added ", game.item_prototypes[item].localised_name, " to temporary trash"})
end

local function on_player_toggled_map_editor(event)
    log("toggled map editor " .. serpent.block(event))
end

local function on_pre_player_died(event)
    log("pre player died " .. serpent.block(event))
    local player = game.get_player(event.player_index)
    if player.mod_settings["autotrash_pause_on_death"].value then
        pause_requests(player)
    end
end

local function on_player_changed_position(event)
    if not global.settings[event.player_index].auto_trash_in_main_network then
        return
    end
    local player = game.get_player(event.player_index)
    if player.character then
        local in_network = inMainNetwork(player)
        local paused = global.settings[event.player_index].pause_trash
        if not in_network and not paused then
            pause_trash(player)
            if player.mod_settings["autotrash_display_messages"].value then
                display_message(player, "AutoTrash paused")
            end
            return
        elseif in_network and paused then
            unpause_trash(player)
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
script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)

script.on_event(defines.events.on_player_toggled_map_editor, on_player_toggled_map_editor)
script.on_event(defines.events.on_pre_player_removed, on_pre_player_removed)
script.on_event(defines.events.on_pre_player_died, on_pre_player_died)
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
                        --TODO update gui if opened
                        game.get_player(player_index).print("Autotrash main network has been unset")
                    end
                    global.mainNetwork[player_index] = newEntity
                end
            end
        end
    end)
    if not status then
        debugDump(err, true)
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
    GUI.close(player)
end

local function toggle_autotrash_pause_requests(player)
    if global.settings[player.index].pause_requests then
        unpause_requests(player)
    else
        pause_requests(player)
    end
    GUI.close(player)
end

local function on_gui_click(event)
    local status, err = pcall(function()
        local element = event.element
        if not (element and element.valid) or element.type == "checkbox" then
            return
        end
        local player_index = event.player_index

        GUI.generic_event(event)

        if not element.valid then return end

        --No gui, nothing to do anymore
        if not (global.gui_elements.config_frame[player_index] and global.gui_elements.config_frame[player_index]) then
            return
        end

        local type, index, _ = string.match(element.name, "autotrash_preset_(%a+)_(%d*)")
        if type and index then
            index = tonumber(index)
            log(serpent.line({t = type, i = index}))
            if type == "load" then
                if not event.shift and not event.control then
                    GUI.restore(player_index, element)
                else
                    local selected_presets = global.selected_presets[player_index]
                    if not selected_presets[element.caption] then
                        log("merging preset")
                        selected_presets[element.caption] = true
                    else
                        log("unmerging preset")
                        selected_presets[element.caption] = nil
                    end
                    global.config_tmp[player_index] = {config = {}}
                    for name, _ in pairs(selected_presets) do
                        global.config_tmp[player_index] = presets.merge(global.config_tmp[player_index], global.storage_new[player_index][name])
                    end
                    global.selected[player_index] = false
                    GUI.update_presets(player_index)
                    GUI.create_buttons(game.get_player(player_index))
                    GUI.update_sliders(player_index)
                end
            elseif type == "delete" then
                GUI.remove(player_index, element, index)
            else
                error("Unexpected type/index from " .. element.name)
            end
            log(serpent.block(global.selected_presets[player_index]))
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_checked_changed_state(event)
    local status, err = pcall(function()
        local element = event.element

        local player_index = event.player_index
        local player = game.get_player(player_index)

        if element.name == gui_def.trash_in_main_network then
            if element.state and not global.mainNetwork[player_index] then
                player.print("No main network set")
                element.state = false
            else
                global.settings[player_index].auto_trash_in_main_network = element.state
                if element.state and inMainNetwork(player) then
                    unpause_trash(player)
                end
            end
        elseif element.name == gui_def.trash_above_requested then
            global.settings[player_index].auto_trash_above_requested = element.state
            if global.settings[player_index].auto_trash_unrequested and not global.settings[player_index].auto_trash_above_requested then
                global.settings[player_index].auto_trash_above_requested = true
                element.state = true
                player.print({"", "'", {"auto-trash-above-requested"}, "' has to be active if '", {"auto-trash-unrequested"}, "' is active"})
            end
        elseif element.name == gui_def.trash_unrequested then
            global.settings[player_index].auto_trash_unrequested = element.state
            if global.settings[player_index].auto_trash_unrequested then
                global.settings[player_index].auto_trash_above_requested = true
                element.parent[gui_def.trash_above_requested].state = true
            end
        elseif element.name == gui_def.pause_trash then
            if element.state then
                pause_trash(player)
            else
                unpause_trash(player)
            end
        elseif element.name == gui_def.pause_requests then
            if element.state then
                pause_requests(player)
            else
                unpause_requests(player)
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_selection_state_changed(event)
    local status, err = pcall(function()
        if not (event.element and event.element.valid) then return end
        GUI.generic_event(event)
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_elem_changed(event)
    local status, err = pcall(function()
        GUI.generic_event(event)
    end)
    if not status then
        debugDump(err, true)
    end
end

local max = 2^32-1
local function update_selected_value(player_index, element, number, check)
    local n = floor(tonumber(number) or 0)
    n = n <= max and n or max
    local flow = element.parent
    local frame_new = global.gui_elements.config_scroll[player_index]
    if not (frame_new and frame_new.valid) then return end
    local grid = frame_new.children[1]
    local i = global.selected[player_index]

    local button = grid and grid.valid and grid.children[i]
    if not button or not button.valid or not i then
        GUI.update_sliders(player_index)
        return
    end
    assert(button.elem_value)--TODO remove
    global["config_tmp"][player_index].config[i] = global["config_tmp"][player_index].config[i] or {name = false, trash = 0, request = 0}
    local item_config = global["config_tmp"][player_index].config[i]
    item_config.name = button.elem_value

    if flow.name == gui_def.config_request then
        assert(n >= 0, "request has to be a positive number") --TODO remove
        item_config.request = n
        button.children[1].caption = format_number(format_request(item_config), true)
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and n > item_config.trash then
            item_config.trash = n
            button.children[2].caption = format_number(format_trash(item_config), true)
        end
    elseif flow.name == gui_def.config_trash then
        if element.type == "slider" and element.slider_value == 42 then
            n = false
        end
        item_config.trash = n
        button.children[2].caption = format_number(format_trash(item_config), true)

        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if check and n and item_config.request > n then
            item_config.request = n
            button.children[2].caption = format_number(format_request(item_config), true)
        end
    end
    global.dirty[player_index] = true
    GUI.update_sliders(player_index)
end

local function on_gui_value_changed(event)
    if event.element.name ~= gui_def.config_slider then
        return
    end
    if not global.selected[event.player_index] then
        GUI.update_sliders(event.player_index)
        return
    end
    if event.element.name == gui_def.config_slider then
        update_selected_value(event.player_index, event.element, convert_from_slider(event.element.slider_value), true)
    end
end

local function on_gui_text_changed(event)
    GUI.generic_event(event)
    if event.element.name ~= gui_def.config_slider_text then
        return
    end
end

local gui_settings = {
    ["autotrash_gui_columns"] = true,
    ["autotrash_gui_max_rows"] = true,
    ["autotrash_slots"] = true,
}
local function on_runtime_mod_setting_changed(event)
    if gui_settings[event.setting] then
        if event.player_index then
            GUI.create_buttons(game.get_player(event.player_index))
        else
            --update all guis, value was changed by script
            for _, player in pairs(game.players) do
                GUI.create_buttons(player)
            end
        end
    end
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_changed_state)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
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
end
}

commands.add_command("reload_mods", "", at_commands.reload)

--/c remote.call("at","saveVar")
remote.add_interface("at",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init_gui = function()
            GUI.init(game.player)
        end,

        hide = function()
            local button = mod_gui.get_button_flow(game.player)[gui_def.main_button]
            if button then
                button.visible = false
            end
        end,

        show = function()
            local button = mod_gui.get_button_flow(game.player)[gui_def.main_button]
            if button then
                button.visible = true
            end
        end
    })
