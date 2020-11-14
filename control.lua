local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local table = require("__flib__.table")

local trash_blacklist = require("constants").trash_blacklist
local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local migrations = require("scripts.migrations")
local at_gui = require("scripts.gui")

local at_util = require("scripts.util")
local presets = require("scripts.presets")

local set_requests = at_util.set_requests
local pause_trash = at_util.pause_trash
local unpause_trash = at_util.unpause_trash
local get_network_entity = at_util.get_network_entity
local in_network = at_util.in_network

--TODO: "import" items from quickbars (automatically or by button?), add full rows and preserve quickbar layout


local function on_nth_tick()
    for _, p in pairs(game.connected_players) do
        if p.character then
            local pdata = global._pdata[p.index]
            if pdata.flags.gui_open then
                at_gui.update_button_styles(p, pdata)
            end
            if pdata.flags.status_display_open then
                at_gui.update_status_display(p, pdata)
            end
        end
    end
end

local function register_conditional_events()
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
    local removed
    if migration.on_config_changed(data, migrations) then
        gui.check_filter_validity()
        at_util.remove_invalid_items()
        removed = true
        for index, pdata in pairs(global._pdata) do
            local player = game.get_player(index)
            player_data.refresh(player, pdata)
            at_gui.recreate(player, pdata)
            --TODO: remove
            if __DebugAdapter then
                at_gui.open(player, pdata)
            end
        end
    end
    if not removed then
        at_util.remove_invalid_items()
    end
    register_conditional_events()
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
    if flags.has_temporary_requests then
        player_data.check_temporary_requests(player, pdata)
    end
    if not flags.pause_trash and flags.trash_unrequested then
        set_requests(player, pdata)
    end
end
event.on_player_main_inventory_changed(on_player_main_inventory_changed)

-- Set trash to 0 if the item isn't set and set it to request if it is
local function add_to_trash(player, item)
    if trash_blacklist[item] then
        player.print({"", at_util.item_prototype(item).localised_name, " is on the blacklist for trashing"})
        return
    end
    local request = player_data.find_request(player, item)
    if request then
        request.max = request.min
    else
        request = {name = item, min = 0, max = 0}
    end
    if player_data.set_request(player, global._pdata[player.index], request, true) then
        player.print({"at-message.added-to-temporary-trash", at_util.item_prototype(item).localised_name})
    end
end

local function on_player_toggled_map_editor(e)
    local player = game.get_player(e.player_index)
    if not player.character then
        player.print{"at-message.no-character"}
        at_gui.close(player, global._pdata[e.player_index], true)
    end
end
event.on_player_toggled_map_editor(on_player_toggled_map_editor)

event.on_player_selected_area(function(e)
    if e.item ~= "autotrash-network-selection" then return end
    local player = game.get_player(e.player_index)
    local pdata = global._pdata[e.player_index]
    for _, roboport in pairs(e.entities) do
        local robo_id = roboport.unit_number
        if not pdata.networks[robo_id] then
            local network = roboport.logistic_network
            for id, main_net in pairs(pdata.networks) do
                if main_net and main_net.valid and main_net.logistic_network == network then
                    player.print{"at-message.network-exists", id}
                    goto continue
                end
            end
            pdata.networks[robo_id] = roboport
            player.print{"at-message.added-network", robo_id}
        else
            player.print{"at-message.network-exists", robo_id}
        end
        ::continue::
    end
    at_gui.update_networks(player, pdata)
end)

event.on_player_alt_selected_area(function(e)
    if e.item ~= "autotrash-network-selection" then return end
    local player = game.get_player(e.player_index)
    local pdata = global._pdata[e.player_index]
    for _, roboport in pairs(e.entities) do
        if pdata.networks[roboport.unit_number] then
            pdata.networks[roboport.unit_number] = nil
            player.print{"at-message.removed-network", roboport.unit_number}
        else
            local network = roboport.logistic_network
            for id, main_net in pairs(pdata.networks) do
                if main_net and main_net.valid and main_net.logistic_network == network then
                    pdata.networks[id] = nil
                    player.print{"at-message.removed-network", id}
                    goto continue
                end
            end
        end
        ::continue::
    end
    at_gui.update_networks(player, pdata)
end)


--TODO Display paused icons/checkboxes without clearing the requests?
-- Vanilla now pauses logistic requests and trash when dying

local function on_player_respawned(e)
    local player = game.get_player(e.player_index)
    if not player.character then return end
    local pdata = global._pdata[e.player_index]
    local selected_presets = pdata.death_presets
    if table_size(selected_presets) > 0 then
        local tmp = {config = {}, by_name = {}, max_slot = 0, c_requests = 0}
        for key, _ in pairs(selected_presets) do
            presets.merge(tmp, pdata.presets[key])
        end
        at_gui.close(player, pdata)
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
        pdata = player_data.init(e.player_index)
    end
    local current = (pdata.current_network and pdata.current_network.valid) and pdata.current_network
    local current_net = current and current.logistic_network
    local maybe_new = get_network_entity(player)
    local maybe_new_net = maybe_new and maybe_new.logistic_network
    if maybe_new_net ~= current_net then
        if pdata.flags.gui_open then
            at_gui.update_button_styles(player, pdata)
        end
        pdata.current_network = maybe_new
    end
    if not pdata.flags.trash_network then
        return
    end
    local is_in_network = in_network(player, pdata)
    local paused = pdata.flags.pause_trash
    if not is_in_network and not paused then
        pause_trash(player, pdata)
        at_gui.update_main_button(pdata)
        if pdata.settings.display_messages then
            player.print({"at-message.trash-paused"})
        end
        return
    elseif is_in_network and paused then
        unpause_trash(player, pdata)
        at_gui.update_main_button(pdata)
        if pdata.settings.display_messages then
            player.print({"at-message.trash-unpaused"})
        end
    end
end
event.on_player_changed_position(on_player_changed_position)

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
    if not (entity.logistic_network and entity.logistic_network.valid) then return end
    local cells
    for pi, pdata in pairs(global._pdata) do
        local player = game.get_player(pi)
        local main = pdata.networks[entity.unit_number]
        local current = pdata.current_network
        if main and main.valid then
            cells = cells or entity.logistic_network.cells
            local found
            for _, cell in pairs(cells) do
                local owner = cell.owner
                if owner.valid and not owner.to_be_deconstructed() and owner ~= entity then
                    pdata.networks[owner.unit_number] = owner
                    found = true
                    break
                end
            end
            pdata.networks[entity.unit_number] = nil
            if not found then
                player.print{"at-message.network-unset", entity.unit_number}
            end
        end
        if current and current.valid and entity == current then
            pdata.current_network = false
            cells = cells or entity.logistic_network.cells
            for _, cell in pairs(cells) do
                local owner = cell.owner
                if owner.valid and not owner.to_be_deconstructed() and owner ~= entity then
                    pdata.current_network = owner
                    break
                end
            end
        end
        at_gui.update_networks(player, pdata)
    end
end
local robofilter = {{filter = "type", type = "roboport"}}
event.on_player_mined_entity(on_pre_mined_item, robofilter)
event.on_robot_mined_entity(on_pre_mined_item, robofilter)
event.on_entity_died(on_pre_mined_item, robofilter)
event.script_raised_destroy(on_pre_mined_item, robofilter)

local function on_built_entity(e)
    local entity = e.entity or e.created_entity
    local network = entity.logistic_network
    local exists
    if not (network and network.valid) then return end
    for pi, pdata in pairs(global._pdata) do
        local player = game.get_player(pi)
        for id, roboport in pairs(pdata.networks) do
            if roboport and roboport.valid and network == roboport.logistic_network then
                if not exists then
                    exists = id
                end
                if exists and exists ~= id then
                    pdata.networks[id] = nil
                    player.print{"at-message.merged-networks", exists, id}
                end
            end
        end
        at_gui.update_networks(player, pdata)
        exists = nil
    end
end

event.on_built_entity(on_built_entity, robofilter)
event.on_robot_built_entity(on_built_entity, robofilter)
event.script_raised_built(on_built_entity, robofilter)
event.script_raised_revive(on_built_entity, robofilter)


local function toggle_autotrash_pause(player)
    if not player.character then return end
    local pdata = global._pdata[player.index]
    player_data.import_when_empty(player, pdata)
    if pdata.flags.pause_trash then
        unpause_trash(player, pdata)
    else
        pause_trash(player, pdata)
    end
    at_gui.update_main_button(pdata)
    at_gui.close(player, pdata)
end
event.register("autotrash_pause", function(e)
    toggle_autotrash_pause(game.get_player(e.player_index))
end)

local function toggle_autotrash_pause_requests(player)
    if not player.character then return end
    local pdata = global._pdata[player.index]
    player_data.import_when_empty(player, pdata)
    if pdata.flags.pause_requests then
        at_util.unpause_requests(player, pdata)
    else
        at_util.pause_requests(player, pdata)
    end
    at_gui.update_status_display(player, pdata)
    at_gui.update_main_button(pdata)
    at_gui.close(player, pdata)
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
    if player.character then
        at_gui.recreate(player, pdata)
    else
        at_gui.close(player, pdata, true)
    end
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
                at_gui.open_status_display(player, pdata)
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
            if player.character then
                add_to_trash(player, cursorStack.name)
            else
                player.print({"at-message.character-needed"})
            end
        else
            toggle_autotrash_pause(player)
        end
    end
end
event.register("autotrash_trash_cursor", autotrash_trash_cursor)

local at_commands = {
    hide = function(args)
        local player = game.get_player(args.player_index)
        local pdata = global._pdata[args.player_index]
        if not pdata then
            player_data.init(args.player_index)
        end
        player_data.refresh(player, pdata)
        local button = pdata.gui and pdata.gui.mod_gui and pdata.gui.mod_gui.flow
        if button and button.valid then
            button.visible = false
        else
            at_gui.init(player, pdata)
        end
        at_gui.update_main_button(pdata)
    end,

    show = function(args)
        local player = game.get_player(args.player_index)
        local pdata = global._pdata[args.player_index]
        if not pdata then
            player_data.init(args.player_index)
        end
        player_data.refresh(player, pdata)
        local button = pdata.gui and pdata.gui.mod_gui and pdata.gui.mod_gui.flow
        if button and button.valid then
            button.visible = true
        else
            at_gui.init(player, pdata)
        end
        at_gui.update_main_button(pdata)
    end,

    import = function(args)
        local player_index = args.player_index
        local pdata = global._pdata[player_index]
        if not pdata then
            pdata = player_data.init(player_index)
        end
        local player = game.get_player(player_index)
        at_gui.close(player, pdata)
        if not player.character then return end
        pdata.config_tmp = player_data.combine_from_vanilla(player, pdata)
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
