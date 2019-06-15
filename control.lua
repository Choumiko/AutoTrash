require "__core__/lualib/util"
local mod_gui = require '__core__/lualib/mod-gui'

local v = require '__AutoTrash__/semver'
local conversion = require "__AutoTrash__/migration"

local lib_control = require '__AutoTrash__/lib_control'
local GUI = require "__AutoTrash__/gui"
local presets = require "__AutoTrash__/presets"

local saveVar = lib_control.saveVar
local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local get_requests = lib_control.get_requests
local pause_trash = lib_control.pause_trash
local unpause_trash = lib_control.unpause_trash
local get_network_entity = lib_control.get_network_entity
local in_network = lib_control.in_network
local item_prototype = lib_control.item_prototype

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
}

local function init_global()
    global = global or {}
    global._pdata = global._pdata or {}
end

local function on_nth_tick(event)--luacheck: ignore
    local pdata, foo
    for i, p in pairs(game.players) do
        if p.character then
            pdata = global._pdata[i]
            local inner = game.create_profiler()
            inner.reset()
            inner.stop()
            local pr = game.create_profiler()
            for _ = 1, 100 do
                foo = GUI.update_button_styles(p, pdata)
            end
            pr.stop()
            pr.divide(100)
            if foo then
                log{"", " button avg: ", pr}
            end
            pr.reset()
            for _ = 1, 100 do
                foo = GUI.update_status_display(p, pdata)
            end
            pr.stop()
            pr.divide(100)
            if foo then
                log{"", " flow avg: ", pr}
            end
            inner.divide(100)
            --log{"", " inner avg: ", inner}
        end
    end
end

local function check_temporary_trash()
    for _, pdata in pairs(global._pdata) do
        if next(pdata.temporary_trash) then
            log("temp trash set")
            --some player has stuff in temporary_trash, don't unregister the event
            return true
        end
    end
    log("temp trash not set")
end

local function on_player_trash_inventory_changed(event)
    local player = game.get_player(event.player_index)
    if not (player.character and player.get_inventory(defines.inventory.character_trash).is_empty()) then return end
    local main_inventory_count = player.get_main_inventory().get_item_count
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local desired, changed
    local temporary_trash = global._pdata[event.player_index].temporary_trash
    for name, saved_count in pairs() do
        if trash_filters[name] then
             desired = requests[name] and requests[name] or 0
            if main_inventory_count(name) <= desired then
                player.print({"", "Removed ", item_prototype(name).localised_name, " from temporary trash"})
                trash_filters[name] = saved_count >= 0 and saved_count or nil
                temporary_trash[name] = nil
                changed = true
            end
        end
    end
    if changed then
        player.auto_trash_filters = trash_filters
        if not check_temporary_trash() then
            script.on_event(defines.events.on_player_trash_inventory_changed, nil)
        end
    end
end

local function register_conditional_events()
    if check_temporary_trash() then
       script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)
    else
        script.on_event(defines.events.on_player_trash_inventory_changed, nil)
    end
    script.on_nth_tick(nil)
    script.on_nth_tick(settings.global["autotrash_update_rate"].value + 1, on_nth_tick)
end

local function init_player(player)
    local pdata = global._pdata[player.index] or {}
    global._pdata[player.index] = {
            config_new = pdata.config_new or {config = {}, c_requests = 0, max_slot = 0},
            config_tmp = pdata.config_tmp or {config = {}, c_requests = 0, max_slot = 0},
            selected = pdata.selected or false,

            main_network = pdata.main_network or false,
            current_network = pdata.current_network or nil,
            storage_new = pdata.storage_new or {},
            temporary_requests = pdata.temporary_requests or {},
            temporary_trash = pdata.temporary_trash or {},
            settings = pdata.settings or util.table.deepcopy(default_settings),
            dirty = pdata.dirty or false,
            selected_presets = pdata.selected_presets or {},
            death_presets = pdata.death_presets or {},

            gui_actions = pdata.gui_actions or {},
            gui_elements = pdata.gui_elements or {},
        }
    GUI.init(player)
    register_conditional_events()
    saveVar(global, "post_init")
end

local function init_players(resetGui)
    for i, player in pairs(game.players) do
        if resetGui then
            GUI.delete(global._pdata[i])
        end
        init_player(player)
    end
end

local function on_load()
    register_conditional_events()
end

local function on_init()
    init_global()
    on_load()
end

local function on_pre_player_removed(event)
    GUI.delete(global._pdata[event.player_index])
    global._pdata[event.player_index] = nil
    register_conditional_events()
end

local function remove_invalid_items(pdata, tbl, unselect)
    local item_config
    for i = tbl.max_slot, 1, -1 do
        item_config = tbl.config[i]
        if item_config then
            if not item_prototype(item_config.name) then
                if tbl.config[i].request > 0 then
                    tbl.c_requests = tbl.c_requests - 1
                end
                tbl.config[i] = nil
                if tbl.max_slot == i then
                    tbl.max_slot = false
                end
                if unselect and pdata.selected and pdata.selected == i then
                    pdata.selected = false
                end
            else
                tbl.max_slot = tbl.max_slot or i
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
            if oldVersion < v'2.0.3' then
                global = nil
                init_global()
                init_players()
            end

            if oldVersion < v'4.1.0' then
                conversion.to_4_1_2(GUI, init_global, init_player, register_conditional_events)
                saveVar(global, "storage_post")
            end
        end
    end

    init_global()
    init_players()
    on_load()
    local pdata
    for pi, player in pairs(game.players) do
        pdata = global._pdata[pi]
        remove_invalid_items(pdata, pdata.config_new)
        remove_invalid_items(pdata, pdata.config_tmp, true)
        for _, stored in pairs(pdata.storage_new) do
            remove_invalid_items(pdata, stored)
        end
        GUI.update_buttons(player, pdata)
        GUI.update_status_display(player, pdata)
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
    local settings = global._pdata[event.player_index].settings
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
    if not player.character then return end
    if trash_blacklist[item] then
        display_message(player, {"", item_prototype(item).localised_name, " is on the blacklist for trashing"}, true)
        return
    end
    local trash_filters = player.auto_trash_filters
    global._pdata[player.index].temporary_trash[item] = trash_filters[item] or -1 -- -1: wasn't set, remove when cleaning temporary_trash
    if not trash_filters[item] then
        local requests = requested_items(player)
        trash_filters[item] = requests[item] or 0
        player.auto_trash_filters = trash_filters
    end
    if check_temporary_trash() then
        script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)
    end
    player.print({"", "Added ", item_prototype(item).localised_name, " to temporary trash"})
end

local function on_player_toggled_map_editor(event)
    local status, err = pcall(function()
    local player = game.get_player(event.player_index)
    if not player.character then
        GUI.close(player, global._pdata[event.player_index], true)
        GUI.close_quick_presets(global._pdata[event.player_index])
    end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

local function on_pre_player_died(event)
    local status, err = pcall(function()
    local player = game.get_player(event.player_index)
    if player.mod_settings["autotrash_pause_on_death"].value then
        local pdata = global._pdata[event.player_index]
        lib_control.pause_requests(player, pdata)
        GUI.update_status_display(player, pdata)
        GUI.update_main_button(pdata)
        GUI.close(player, pdata, true)
        GUI.close_quick_presets(pdata)
    end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

local function on_player_respawned(event)
    local status, err = pcall(function()
    local pdata = global._pdata[event.player_index]
    local selected_presets = pdata.death_presets
    if table_size(selected_presets) > 0 then
        local player = game.get_player(event.player_index)
        local tmp = {config = {}, max_slot = 0, c_requests = 0}
        for key, _ in pairs(selected_presets) do
            presets.merge(tmp, pdata.storage_new[key])
        end
        GUI.close(player, pdata)
        pdata.config_tmp = tmp
        pdata.config_new = util.table.deepcopy(tmp)

        lib_control.unpause_requests(player, pdata)
        GUI.update_status_display(player, pdata)
        unpause_trash(player, pdata)
        GUI.update_main_button(pdata)
    end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

local function on_player_changed_position(event)
    local player = game.get_player(event.player_index)
    if not player.character then return end
    local pdata = global._pdata[event.player_index]
    local current = pdata.current_network and pdata.current_network.logistic_network
    if player.character.logistic_network ~= current then
        log("Network changed")
        GUI.update_button_styles(player, pdata)
        pdata.current_network = get_network_entity(player)
    end
    if not pdata.settings.trash_network then
        return
    end
    local is_in_network = in_network(player, pdata)
    local paused = pdata.settings.pause_trash
    if not is_in_network and not paused then
        pause_trash(player, pdata)
        GUI.update_main_button(pdata)
        if player.mod_settings["autotrash_display_messages"].value then
            display_message(player, "AutoTrash paused")
        end
        return
    elseif is_in_network and paused then
        unpause_trash(player, pdata)
        GUI.update_main_button(pdata)
        if player.mod_settings["autotrash_display_messages"].value then
            display_message(player, "AutoTrash unpaused")
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

local function update_network(entity, player_index, pdata, main)
    local newEntity = false
    --get another roboport from the network
    if newEntity == false and entity.logistic_network and entity.logistic_network.valid then
        for _, cell in pairs(entity.logistic_network.cells) do
            newEntity = nil
            if cell.owner ~= entity and cell.owner.valid then
                newEntity = cell.owner
                break
            end
        end
    end
    if main and not newEntity and entity then
        local player = game.get_player(player_index)
        player.print("Autotrash main network has been unset")
    end
    GUI.update_settings(pdata)
    return newEntity
end

local function on_pre_mined_item(event)
    local status, err = pcall(function()
        if event.entity.type == "roboport" then
            local entity = event.entity
            for pi, pdata in pairs(global._pdata) do
                if entity == pdata.main_network then
                    pdata.main_network = update_network(entity, pi, pdata, true)
                end
                if entity == pdata.current_network then
                    pdata.current_network = update_network(entity, pi, pdata)
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

--[[
Temporary requests:
- after the request is added: (.request and .trash increased accordingly)
    - keep track of the item counts in the inventory + cursor (on_put_item event? cursor_stack may be put back into inventory resulting in a false increase otherwise)
    - if count decreases: reduce request/trash amount by the diff (we assume the item is used to build the ordered blueprint)
    - if count increases:
]]--

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
    local status, err = pcall(function()
    local pdata = global._pdata[player.index]
    if pdata.settings.pause_trash then
        unpause_trash(player, pdata)
    else
        pause_trash(player, pdata)
    end
    GUI.update_main_button(pdata)
    GUI.close(player, pdata)
    end)
    if not status then
        debugDump(err, player.index, true)
    end
end

local function toggle_autotrash_pause_requests(player)
    local status, err = pcall(function()
    local pdata = global._pdata[player.index]
    if pdata.settings.pause_requests then
        lib_control.unpause_requests(player, pdata)
    else
        lib_control.pause_requests(player, pdata)
    end
    GUI.update_status_display(player, pdata)
    GUI.update_main_button(pdata)
    GUI.close(player, pdata)
    end)
    if not status then
        debugDump(err, player.index, true)
    end
end

local gui_settings = {
    ["autotrash_gui_columns"] = true,
    ["autotrash_gui_max_rows"] = true,
}
local function on_runtime_mod_setting_changed(event)
    local status, err = pcall(function()
    if event.setting == "autotrash_update_rate" then
        register_conditional_events()
        return
    end
    local player_index = event.player_index
    local player = game.get_player(player_index)
    local pdata = global._pdata[player_index]
    if not (player_index and pdata) then return end
    if gui_settings[event.setting] then
        if player.character then
            GUI.create_buttons(player, pdata)
        else
            GUI.close(player, pdata, true)
            GUI.close_quick_presets(pdata)
        end
    end
    if event.setting == "autotrash_threshold" then
        local settings = pdata.settings
        if not settings.pause_trash and settings.trash_above_requested then
            lib_control.set_trash(player, pdata)
        end
    end
    if event.setting == "autotrash_status_count" then
        GUI.update_status_display(player, pdata)
    end
    if event.setting == "autotrash_status_columns" then
        local status_table = pdata.gui_elements.status_table
        if status_table and status_table.valid then
            GUI.open_status_display(player, pdata)
        end
    end
    end)
    if not status then
        debugDump(err, false, true)
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
    local status, err = pcall(function()
    if event.research.name == "character-logistic-trash-slots-1" or
        event.research.name == "character-logistic-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player)
        end
    end
    end)
    if not status then
        debugDump(err, false, true)
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
    local status, err = pcall(function()
    local player = game.get_player(event.player_index)
    if player.force.technologies["character-logistic-trash-slots-1"].researched then
        local cursorStack = player.cursor_stack
        if cursorStack.valid_for_read then
            add_to_trash(player, cursorStack.name)
        else
            toggle_autotrash_pause(player)
        end
    end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end
script.on_event("autotrash_trash_cursor", autotrash_trash_cursor)

local at_commands = {
    reload = function()
        game.reload_mods()

        local button_flow = mod_gui.get_button_flow(game.player)[GUI.defines.main_button]
        if button_flow and button_flow.valid then
            GUI.deregister_action(button_flow, global._pdata[game.player.index], true)
        end

        init_global()
        init_players()
        game.player.print("Mods reloaded")
    end,

    hide = function(args)
        local button = global._pdata[args.player_index].gui_elements.main_button
        if button and button.valid then
            button.visible = false
        end
    end,

    show = function(args)
        local button = global._pdata[args.player_index].gui_elements.main_button
        if button and button.valid then
            button.visible = true
        end
    end,
}

local comms = commands.commands

if not comms.reload_mods then
    commands.add_command("reload_mods", "", at_commands.reload)
else
    commands.add_command("autotrash_reload_mods", "", at_commands.reload)
end
local command_prefix = "at_"
if comms.at_hide or comms.at_show then
    command_prefix = "autotrash_"
end
commands.add_command(command_prefix .. "hide", "Hide the AutoTrash button", at_commands.hide)
commands.add_command(command_prefix .. "show", "Show the AutoTrash button", at_commands.show)

remote.add_interface("at",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init_gui = function()
            GUI.init(game.player)
        end,
    })
