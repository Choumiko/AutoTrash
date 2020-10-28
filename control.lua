require "__core__/lualib/util"
local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local table = require("__flib__.table")

local trash_blacklist = require("constants").trash_blacklist
local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local migrations = require("scripts.migrations")
local at_gui = require("scripts.gui")

local lib_control = require '__AutoTrash__/lib_control'
local presets = require "__AutoTrash__/presets"

local display_message = lib_control.display_message
local set_requests = lib_control.set_requests
local pause_trash = lib_control.pause_trash
local unpause_trash = lib_control.unpause_trash
local get_network_entity = lib_control.get_network_entity
local in_network = lib_control.in_network
local item_prototype = lib_control.item_prototype
local remove_invalid_items = lib_control.remove_invalid_items

local function requested_items(player)
    if not player.character then
        return {}
    end
    local requests = {}
    local get_request_slot = player.character.get_request_slot
    for c = player.character_logistic_slot_count, 1, -1 do
        local t = get_request_slot(c)
        if t then
            requests[t.name] = t.count
        end
    end
    return requests
end

local function on_nth_tick()
    for i, p in pairs(game.players) do
        if p.character then
            local pdata = global._pdata[i]
            if pdata.flags.gui_open then
                at_gui.update_button_styles(p, pdata)
            end
            if pdata.flags.status_display_open then
                at_gui.update_status_display(p, pdata)
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

local function on_player_trash_inventory_changed(e)
    local player = game.get_player(e.player_index)
    if not (player.character and player.get_inventory(defines.inventory.character_trash).is_empty()) then return end
    local main_inventory_count = player.get_main_inventory().get_item_count
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local changed
    local temporary_trash = global._pdata[e.player_index].temporary_trash
    for name, saved_count in pairs(temporary_trash) do
        if trash_filters[name] then
            local desired = requests[name] and requests[name] or 0
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

local function on_init()
    gui.init()
    gui.build_lookup_tables()

    global_data.init()

    for _, force in pairs(game.forces) do
        if force.character_logistic_requests then
            global.unlocked_by_force[force.name] = true
        end
        for player_index, player in pairs(force.players) do
            local pdata = player_data.init(player_index)
            at_gui.init(player, pdata)
            if player.character and force.character_logistic_requests then
                pdata.config_tmp = lib_control.combine_from_vanilla(player)
                if next(pdata.config_tmp.config) then
                    pdata.presets["at_imported"] = table.deep_copy(pdata.config_tmp)
                    pdata.selected_presets = {at_imported = true}
                end
                at_gui.create_main_window(player, pdata)
                at_gui.open(player, pdata)
            end
        end
    end
    register_conditional_events()
end
event.on_init(on_init)

local function on_load()
    register_conditional_events()
    gui.build_lookup_tables()
end
event.on_load(on_load)

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
        --only run when mod was changed
        gui.check_filter_validity()

        for i, player in pairs(game.players) do
            local pdata = global._pdata[i]
            player_data.refresh(player, pdata)
            at_gui.recreate(player, pdata)
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
event.on_configuration_changed(on_configuration_changed)

at_gui.register_handlers()

--that's a bad event to handle unrequested, since adding stuff to the trash filters immediately triggers the next on_main_inventory_changed event
-- on_nth_tick might work better or only registering when some player has trash_unrequested set to true
local function on_player_main_inventory_changed(e)
    local player = game.get_player(e.player_index)
    if not (player.character) then return end
    local pdata = global._pdata[e.player_index]
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

local function on_player_toggled_map_editor(e)
    local player = game.get_player(e.player_index)
    if not player.character then
        player.print{"autotrash_no_character"}
        at_gui.close(global._pdata[e.player_index], true)
    end
end
event.on_player_toggled_map_editor(on_player_toggled_map_editor)

--TODO Display paused icons/checkboxes without clearing the requests?
-- Vanilla now pauses logistic requests and trash when dying

local function on_player_respawned(e)
    local player = game.get_player(e.player_index)
    if not player.character then return end
    local pdata = global._pdata[e.player_index]
    local selected_presets = pdata.death_presets
    if table_size(selected_presets) > 0 then
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
end
event.on_player_respawned(on_player_respawned)

local function on_player_changed_position(e)
    local player = game.get_player(e.player_index)
    if not player.character then return end
    local pdata = global._pdata[e.player_index]
    --Rocket rush scenario might teleport before AutoTrash gets a chance to init?!
    if not pdata then
        player_data.init(e.player_index)
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
event.on_player_changed_position(on_player_changed_position)

event.on_player_main_inventory_changed(on_player_main_inventory_changed)

local function on_cutscene_cancelled(e)
    local player = game.get_player(e.player_index)
    local pdata = global._pdata[e.player_index]
    if not pdata then
        pdata = player_data.init(e.player_index)
    else
        player_data.refresh(player, pdata)
    end
    at_gui.init(player, pdata)
end
event.on_cutscene_cancelled(on_cutscene_cancelled)

local function on_player_created(e)
    local player = game.get_player(e.player_index)
    player_data.init(e.player_index)
    at_gui.init(player, global._pdata[e.player_index])
end
event.on_player_created(on_player_created)

local function on_player_removed(e)
    global._pdata[e.player_index] = nil
    register_conditional_events()
end
event.on_player_removed(on_player_removed)

local function on_pre_mined_item(e)
    local entity = e.entity
    for pi, pdata in pairs(global._pdata) do
        local main = pdata.main_network
        local current = pdata.current_network
        --TODO: should always be valid?
        if entity.logistic_network and entity.logistic_network.valid then
            local cells = entity.logistic_network.cells
            if main and main.valid and entity == main then
                pdata.main_network = false
                for _, cell in pairs(cells) do
                    if cell.owner.valid and cell.owner ~= entity then
                        pdata.main_network = cell.owner
                        break
                    end
                end
                if not pdata.main_network then
                    local player = game.get_player(pi)
                    player.print("Autotrash main network has been unset")
                end
            end
            if current and current.valid and entity == current then
                pdata.current_network = false
                for _, cell in pairs(cells) do
                    if cell.owner.valid and cell.owner ~= entity then
                        pdata.current_network = cell.owner
                        break
                    end
                end
            end
            at_gui.update_settings(pdata)
        end
    end
end
local robofilter = {{filter = "type", type = "roboport"}}
event.on_pre_player_mined_item(on_pre_mined_item, robofilter)
event.on_robot_pre_mined(on_pre_mined_item, robofilter)
event.on_entity_died(on_pre_mined_item, robofilter)
event.script_raised_destroy(on_pre_mined_item, robofilter)

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
    local pdata = global._pdata[player.index]
    if pdata.flags.pause_trash then
        unpause_trash(player, pdata)
    else
        pause_trash(player, pdata)
    end
    at_gui.update_main_button(pdata)
    at_gui.close(pdata)
end
event.register("autotrash_pause", function(e)
    toggle_autotrash_pause(game.get_player(e.player_index))
end)

local function toggle_autotrash_pause_requests(player)
    local pdata = global._pdata[player.index]
    if pdata.flags.pause_requests then
        lib_control.unpause_requests(player, pdata)
    else
        lib_control.pause_requests(player, pdata)
    end
    at_gui.update_status_display(player, pdata)
    at_gui.update_main_button(pdata)
    at_gui.close(pdata)
end
event.register("autotrash_pause_requests", function(e)
    toggle_autotrash_pause_requests(game.get_player(e.player_index))
end)

local function on_runtime_mod_setting_changed(e)
    if e.setting == "autotrash_update_rate" then
        register_conditional_events()
        return
    end

    local player_index = e.player_index
    local player = game.get_player(player_index)
    local pdata = global._pdata[player_index]
    if not (player_index and pdata) then return end
    player_data.update_settings(player, pdata)
    if e.setting == "autotrash_gui_displayed_columns" or e.setting == "autotrash_gui_rows_before_scroll" then
        at_gui.recreate(player, pdata)
    end
    if e.setting == "autotrash_status_count" or e.setting == "autotrash_status_columns" then
        at_gui.init_status_display(player, pdata, true)
    end
end
event.on_runtime_mod_setting_changed(on_runtime_mod_setting_changed)

local function on_player_display_resolution_changed(e)
    local pdata = global._pdata[e.player_index]
    local player = game.get_player(e.player_index)
    player_data.refresh(player, pdata)
    at_gui.recreate(player, pdata)
end
event.on_player_display_resolution_changed(on_player_display_resolution_changed)
event.on_player_display_scale_changed(on_player_display_resolution_changed)

local function on_research_finished(e)
    local force = e.research.force
    if not global.unlocked_by_force[force.name] and force.character_logistic_requests then
        for _, player in pairs(force.players) do
            local pdata = global._pdata[player.index]
            if not pdata then
                pdata = player_data.init(player.index)
            end
            pdata.flags.can_open_gui = true
            pdata.gui.mod_gui.flow.visible = true
            if player.character then
                at_gui.create_main_window(player, pdata)
            end
        end
        global.unlocked_by_force[force.name] = true
    end
end
event.on_research_finished(on_research_finished)

local function autotrash_trash_cursor(e)
    local player = game.get_player(e.player_index)
    if player.force.character_trash_slot_count > 0 then
        local cursorStack = player.cursor_stack
        if cursorStack.valid_for_read then
            add_to_trash(player, cursorStack.name)
        else
            toggle_autotrash_pause(player)
        end
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
        at_gui.close(pdata)
        pdata.config_tmp = lib_control.combine_from_vanilla(player)
        at_gui.open(player, pdata)
        at_gui.mark_dirty(pdata)
    end,

    reset = function(args)
        local pdata = global._pdata[args.player_index]
        local player = game.get_player(args.player_index)
        player.character_logistic_slot_count = pdata.settings.columns * pdata.settings.rows - 1
        at_gui.destroy(player, pdata)
        at_gui.open(player, pdata)
    end,
}

local comms = commands.commands

local command_prefix = "at_"
if comms.at_hide or comms.at_show then
    command_prefix = "autotrash_"
end
commands.add_command(command_prefix .. "hide", "Hide the AutoTrash button", at_commands.hide)
commands.add_command(command_prefix .. "show", "Show the AutoTrash button", at_commands.show)
commands.add_command(command_prefix .. "import", "Import from vanilla", at_commands.import)
commands.add_command(command_prefix .. "reset", "Reset gui", at_commands.reset)
