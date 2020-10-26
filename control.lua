require "__core__/lualib/util"
--TODO: check every GUI/at_gui call
local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local table = require("__flib__.table")
local mod_gui = require ("__core__.lualib.mod-gui")


local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local migrations = require("scripts.migrations")
local at_gui = require("scripts.gui")

local lib_control = require '__AutoTrash__/lib_control'
local presets = require "__AutoTrash__/presets"

local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local set_requests = lib_control.set_requests
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
    for c = player.character_logistic_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = t.count
        end
    end
    return requests
end

local function on_nth_tick()
    local pdata
    for i, p in pairs(game.players) do
        if p.character then
            --TODO: remove
            if __Profiler then
                p.character_personal_logistic_requests_enabled = true
            end
            pdata = global._pdata[i]
            local cache
            if pdata.flags.gui_open then
                cache = at_gui.update_button_styles(p, pdata)
            end
            if pdata.flags.status_display_open then
                at_gui.update_status_display(p, pdata, cache)
            end
        end
    end
end

local function check_temporary_trash()
    for _, pdata in pairs(global._pdata) do
        if next(pdata.temporary_trash) then
            return true
        end
    end
end

local function on_player_trash_inventory_changed(event)
    local player = game.get_player(event.player_index)
    if not (player.character and player.get_inventory(defines.inventory.character_trash).is_empty()) then return end
    local main_inventory_count = player.get_main_inventory().get_item_count
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local desired, changed
    local temporary_trash = global._pdata[event.player_index].temporary_trash
    for name, saved_count in pairs(temporary_trash) do
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
            event.on_player_trash_inventory_changed(nil)
        end
    end
end

local function register_conditional_events()
    if check_temporary_trash() then
        event.on_player_trash_inventory_changed(on_player_trash_inventory_changed)
    else
        event.on_player_trash_inventory_changed(nil)
    end
    event.on_nth_tick(nil)
    event.on_nth_tick(settings.global["autotrash_update_rate"].value + 1, on_nth_tick)
end

local function on_load()
    register_conditional_events()
    gui.build_lookup_tables()
end

local function on_init()
    gui.init()

    global_data.init()
    for i in pairs(game.players) do
        player_data.init(i)
    end
    register_conditional_events()
    gui.build_lookup_tables()
end

local function on_player_removed(event)
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

local migrations = {
    ["4.1.2"] = function()
        log("Resetting all AutoTrash settings")
        global = {}
        global_data.init()
        for player_index in pairs(game.players) do
            player_data.init(player_index)
        end
    end,
    ["5.1.0"] = function()
        for _, pdata in pairs(global._pdata) do
            pdata.infinite = nil
        end
    end,
    ["5.2.2"] = function()
        global.unlocked_by_force = {}
    end,
    ["5.2.3"] = function()
        for player_index, player in pairs(game.players) do
            local pdata = global._pdata[player_index]
            if pdata then
                local psettings = pdata.settings
                pdata.flags = {
                    can_open_gui = player.force.character_logistic_requests,
                    gui_open = false,
                    status_display_open = false,
                    trash_above_requested = psettings.trash_above_requested or false,
                    trash_unrequested = psettings.trash_unrequested or false,
                    trash_network = psettings.trash_network or false,
                    pause_trash = psettings.pause_trash or false,
                    pause_requests = psettings.pause_requests or false,
                }
                pdata.gui = {
                    mod_gui = {},
                    import = {},
                    main = {}
                }
                pdata.presets = pdata.storage_new
                if pdata.presets then
                    for _, stored in pairs(pdata.presets) do
                        remove_invalid_items(pdata, stored)
                    end
                else
                    pdata.presets = {}
                end
                pdata.storage_new = nil
                pdata.gui_actions = nil
                pdata.gui_elements = nil
                pdata.gui_location = nil

                player_data.update_settings(player, pdata)
            else
                pdata = player_data.init(player_index)
            end
            --keep the status flow in gui.left, everything else goes boom (from AutoTrash)
            local mod_gui_flow = mod_gui.get_frame_flow(player)
            if mod_gui_flow and mod_gui_flow.valid then
                for _, egui in pairs(player.gui.left.mod_gui_frame_flow.children) do
                    if egui.get_mod() == "AutoTrash" then
                        if egui.name == "autotrash_status_flow" then
                            pdata.gui.status_flow = egui
                            egui.clear()
                        else
                            egui.destroy()
                        end
                    end
                end
            end
            local button_flow = mod_gui.get_button_flow(player).autotrash_main_flow
            if button_flow and button_flow.valid then
                pdata.gui.mod_gui.flow = button_flow
                button_flow.clear()
            end
            for _, egui in pairs(player.gui.screen.children) do
                if egui.get_mod() == "AutoTrash" then
                    egui.destroy()
                end
            end
        end

        gui.init()
        gui.build_lookup_tables()
        for pi, player in pairs(game.players) do
            at_gui.init(player, global._pdata[pi])
        end

        --TODO: remove
        global._pdata[1].config_tmp = table.deep_copy(global._pdata[1].config_new)
        set_requests(game.players[1], global._pdata[1])
        at_gui.open(game.players[1], global._pdata[1])
        -- global._pdata[1].presets["preset2"]["config"][14] = global._pdata[1].presets["preset2"]["config"][7]
        -- global._pdata[1].presets["preset2"]["config"][7] = nil
        -- global._pdata[1].presets["preset2"].max_slot = 14
        -- for i = 1, 13 do
        --     global._pdata[1].presets["fpp" .. i] = table.deep_copy(global._pdata[1].presets["preset1"])
        -- end



    end,
    ["5.2.4"] = function()
        for player_index, player in pairs(game.players) do
            local pdata = global._pdata[player_index]
            pdata.flags.dirty = false
            pdata.dirty = nil
            at_gui.init_status_display(player, pdata)
            at_gui.open_status_display(player, pdata)
        end
    end
}

local function on_configuration_changed(data)
    for pi in pairs(game.players) do
        local pdata = global._pdata[pi]
        if pdata then
            if pdata.config_new and pdata.config_tmp then
                remove_invalid_items(pdata, pdata.config_new)
                remove_invalid_items(pdata, pdata.config_tmp, true)
            end
            if pdata.presets then
                for _, stored in pairs(pdata.presets) do
                    remove_invalid_items(pdata, stored)
                end
            end
        end
    end

    if migration.on_config_changed(data, migrations) then
        gui.check_filter_validity()
    else
        for player_index, player in pairs(game.players) do
            player_data.init(player_index)
            if player.character and player.force.technologies["logistic-robotics"].researched then
                local pdata = global._pdata[player_index]
                local status, err = pcall(function()
                    at_gui.close(pdata)
                    pdata.config_tmp = lib_control.combine_from_vanilla(player)
                    if next(pdata.config_tmp.config) then
                        pdata.presets["at_imported"] = table.deep_copy(pdata.config_tmp)
                        pdata.selected_presets = {at_imported = true}
                        at_gui.init(player, pdata)
                        at_gui.open(player, pdata)
                    end
                end)
                if not status then
                    at_gui.close(pdata)
                    pdata.config_tmp = nil
                    pdata.presets["at_imported"] = nil
                    pdata.selected_presets = {}
                    player_data.init(player_index)
                    debugDump(err, player_index, true)
                end
            end
        end
    end
    register_conditional_events()
    for pi, player in pairs(game.players) do
        local pdata = global._pdata[pi]
        if pdata.flags.gui_open then
            at_gui.update_buttons(pdata)
        end
        at_gui.update_status_display(player, pdata)
    end
end

local function on_player_created(event)
    local player = game.get_player(event.player_index)
    player_data.init(event.player_index)
    at_gui.init(player, global._pdata[event.player_index])
end

local trash_blacklist = {
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-item"] = true,
    ["upgrade-item"] = true,
    ["copy-paste-tool"] = true,
    ["selection-tool"] = true,
}

--that's a bad event to handle unrequested, since adding stuff to the trash filters immediately triggers the next on_main_inventory_changed event
-- on_nth_tick might work better or only registering when some player has trash_unrequested set to true
local function on_player_main_inventory_changed(event)
    local player = game.get_player(event.player_index)
    if not (player.character) then return end
    local pdata = global._pdata[event.player_index]
    local flags = pdata.flags
    if flags.pause_trash or not flags.trash_unrequested then return end
    set_requests(player, pdata)
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
        event.on_player_trash_inventory_changed(on_player_trash_inventory_changed)
    end
    player.print({"", "Added ", item_prototype(item).localised_name, " to temporary trash"})
end

local function on_player_toggled_map_editor(event)
    local status, err = pcall(function()
    local player = game.get_player(event.player_index)
    if not player.character then
        player.print{"autotrash_no_character"}
        at_gui.close(global._pdata[event.player_index], true)
    end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

--TODO Display paused icons/checkboxes without clearing the requests?
-- Vanilla now pauses logistic requests and trash when dying

local function on_player_respawned(event)
    local status, err = pcall(function()
    local pdata = global._pdata[event.player_index]
    local selected_presets = pdata.death_presets
    if table_size(selected_presets) > 0 then
        local player = game.get_player(event.player_index)
        local tmp = {config = {}, max_slot = 0, c_requests = 0}
        for key, _ in pairs(selected_presets) do
            presets.merge(tmp, pdata.presets[key])
        end
        at_gui.close(pdata)
        pdata.config_tmp = tmp
        pdata.config_new = table.deep_copy(tmp)

        set_requests(player, pdata)
        player.character_personal_logistic_requests_enabled = true
        at_gui.update_status_display(player, pdata)
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
    --Rocket rush scenario might teleport before AutoTrash gets a chance to init?!
    if not pdata then
        player_data.init(event.player_index)
    end
    local current = (pdata.current_network and pdata.current_network.valid) and pdata.current_network.logistic_network
    local maybe_new = get_network_entity(player)
    if maybe_new then
        maybe_new = maybe_new.logistic_network
    end
    if maybe_new ~= current then
        if pdata.flags.gui_open then
            at_gui.update_button_styles(player, pdata)
        end
        pdata.current_network = get_network_entity(player)
    end
    if not pdata.flags.trash_network then
        return
    end
    local is_in_network, invalid = in_network(player, pdata)
    if invalid then
        at_gui.update_settings(pdata)
    end
    local paused = pdata.flags.pause_trash
    if not is_in_network and not paused then
        pause_trash(player, pdata)
        at_gui.update_main_button(pdata)
        if pdata.settings.display_messages then
            display_message(player, "AutoTrash paused")
        end
        return
    elseif is_in_network and paused then
        unpause_trash(player, pdata)
        at_gui.update_main_button(pdata)
        if pdata.settings.display_messages then
            display_message(player, "AutoTrash unpaused")
        end
    end
end

event.on_init(on_init)
event.on_load(on_load)
event.on_configuration_changed(on_configuration_changed)
event.on_player_created(on_player_created)
event.on_player_main_inventory_changed(on_player_main_inventory_changed)

event.on_player_toggled_map_editor(on_player_toggled_map_editor)
event.on_player_removed(on_player_removed)
event.on_player_respawned(on_player_respawned)
event.on_player_changed_position(on_player_changed_position)

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
    at_gui.update_settings(pdata)
    return newEntity
end

local function on_pre_mined_item(event)
    local status, err = pcall(function()
        if event.entity and event.entity.type == "roboport" then
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

local function on_script_raised_destroy(event)
    local status, err = pcall(function()
        if event.entity and event.entity.type == "roboport" then
            on_pre_mined_item(event)
        end
    end)
    if not status then
        debugDump(err, event.player_index, true)
    end
end

local robofilter = {{filter = "type", type = "roboport"}}
event.on_pre_player_mined_item(on_pre_mined_item, robofilter)
event.on_robot_pre_mined(on_pre_mined_item, robofilter)
event.on_entity_died(on_pre_mined_item, robofilter)
event.script_raised_destroy(on_script_raised_destroy, robofilter)

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
    if pdata.flags.pause_trash then
        unpause_trash(player, pdata)
    else
        pause_trash(player, pdata)
    end
    at_gui.update_main_button(pdata)
    at_gui.close(pdata)
    end)
    if not status then
        debugDump(err, player.index, true)
    end
end

local function toggle_autotrash_pause_requests(player)
    local status, err = pcall(function()
    local pdata = global._pdata[player.index]
    if pdata.flags.pause_requests then
        lib_control.unpause_requests(player, pdata)
    else
        lib_control.pause_requests(player, pdata)
    end
    at_gui.update_status_display(player, pdata)
    at_gui.update_main_button(pdata)
    at_gui.close(pdata)
    end)
    if not status then
        debugDump(err, player.index, true)
    end
end

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
    player_data.update_settings(player, pdata)

    if event.setting == "autotrash_status_count" or event.setting == "autotrash_status_columns" then
        at_gui.init_status_display(player, pdata, true)
    end
    end)
    if not status then
        debugDump(err, false, true)
    end
end

at_gui.register_handlers()

event.on_runtime_mod_setting_changed(on_runtime_mod_setting_changed)

local function on_research_finished(event)
    local status, err = pcall(function()
        local force = event.research.force
        if not global.unlocked_by_force[force.name] and force.character_logistic_requests then
            for _, player in pairs(event.research.force.players) do
                local pdata = global._pdata[player.index]
                pdata.flags.can_open_gui = true
                pdata.gui.mod_gui.flow.visible = true
                if player.character then
                    at_gui.create_main_window(player, pdata)
                end
            end
            global.unlocked_by_force[force.name] = true
        end
    end)
    if not status then
        debugDump(err, false, true)
    end
end
event.on_research_finished(on_research_finished)

event.register("autotrash_pause", function(e)
    toggle_autotrash_pause(game.get_player(e.player_index))
end)

event.register("autotrash_pause_requests", function(e)
    toggle_autotrash_pause_requests(game.get_player(e.player_index))
end)

event.on_gui_location_changed(function(e)
    -- local pdata = global._pdata[e.player_index]
    -- if not (e.player_index and pdata) then return end
    -- if e.element == pdata.gui_elements.container then
    --     pdata.gui_location = e.element.location
    -- end
end)

local function autotrash_trash_cursor(event)
    local status, err = pcall(function()
    local player = game.get_player(event.player_index)
    if player.force.technologies["logistic-robotics"].researched then
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
event.register("autotrash_trash_cursor", autotrash_trash_cursor)

local at_commands = {
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

    import = function(args)
        local player_index = args.player_index
        local pdata = global._pdata[player_index]
        local player = game.get_player(player_index)
        local status, err = pcall(function()
            at_gui.close(pdata)
            pdata.config_tmp = lib_control.combine_from_vanilla(player)
            at_gui.open(player, pdata)
            at_gui.mark_dirty(pdata)
        end)
        if not status then
            at_gui.close(pdata)
            pdata.config_tmp = nil
            player_data.init(player_index)
            debugDump(err, player_index, true)
        end
    end
}

local comms = commands.commands

local command_prefix = "at_"
if comms.at_hide or comms.at_show then
    command_prefix = "autotrash_"
end
commands.add_command(command_prefix .. "hide", "Hide the AutoTrash button", at_commands.hide)
commands.add_command(command_prefix .. "show", "Show the AutoTrash button", at_commands.show)
commands.add_command(command_prefix .. "import", "Import from vanilla", at_commands.import)
