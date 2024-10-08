local at_util = require("scripts.util")
local gui_util = require("scripts.gui-util")
local gui = require("__flib__.gui-beta")
local table = require("__flib__.table")

local player_data = {}

function player_data.init(player_index)
    local player = game.get_player(player_index)
    global._pdata[player_index] = {
        flags = {
            can_open_gui = player.force.character_logistic_requests,
            gui_open = false,
            dirty = false,
            pinned = true,
            status_display_open = false,
            trash_above_requested = false,
            trash_unrequested = false,
            trash_network = false,
            pause_trash = false,
            pause_requests = false,
            autotoggle_unrequested = false,
            has_temporary_requests = false,
        },
        gui = {
            import = {},
            main = {},
            sliders = {},
            options = {},
            presets = {},
            networks = {},
            spider = {},
        },
        config_new = {config = {}, by_name = {}, c_requests = 0, max_slot = 0},
        config_tmp = {config = {}, by_name = {}, c_requests = 0, max_slot = 0},
        selected = false,

        current_network = nil,
        presets = {},
        temporary_requests = {},
        settings = {},
        selected_presets = {},
        death_presets = {},
        networks = {}
    }
    player.set_shortcut_available("autotrash-toggle-gui", player.force.character_logistic_requests)
    player_data.update_settings(game.get_player(player_index), global._pdata[player_index])

    global._pdata[player_index].config_tmp = player_data.combine_from_vanilla(player)
    global._pdata[player_index].config_new = at_util.copy_preset(global._pdata[player_index].config_tmp)

    return global._pdata[player_index]
end

function player_data.update_settings(player, pdata)
    local player_settings = player.mod_settings
    local settings = {
        status_count = player_settings["autotrash_status_count"].value,
        status_columns = player_settings["autotrash_status_columns"].value,
        display_messages = player_settings["autotrash_display_messages"].value,
        close_on_apply = player_settings["autotrash_close_on_apply"].value,
        reset_on_close = player_settings["autotrash_reset_on_close"].value,
        overwrite = player_settings["autotrash_overwrite"].value,
        trash_equals_requests = player_settings["autotrash_trash_equals_requests"].value,
        columns = player_settings["autotrash_gui_displayed_columns"].value,
        rows = player_settings["autotrash_gui_rows_before_scroll"].value,
        show_button = player_settings["autotrash_show_button"].value,
    }
    pdata.settings = settings
end

function player_data.refresh(player, pdata)
    pdata.flags.can_open_gui = player.force.character_logistic_requests
    player.set_shortcut_available("autotrash-toggle-gui", player.force.character_logistic_requests)
    player_data.update_settings(player, pdata)
end

function player_data.swap_configs(pdata, origin, destination)
    local config_tmp = pdata.config_tmp
    local old_config = config_tmp.config[origin]
    local tmp = table.deep_copy(config_tmp.config[destination])
    config_tmp.config[destination] = table.deep_copy(old_config)
    config_tmp.config[destination].slot = destination
    config_tmp.by_name[old_config.name] = config_tmp.config[destination]
    if tmp then
        config_tmp.config[origin] = tmp
        config_tmp.by_name[tmp.name] = tmp
        tmp.slot = origin
    else
        config_tmp.config[origin] = nil
    end
    config_tmp.max_slot = destination > config_tmp.max_slot and destination or config_tmp.max_slot
end

function player_data.add_config(pdata, name, min, max, index)
    local config_tmp = pdata.config_tmp
    config_tmp.config[index] = {
        name = name, min = min,
        max = max, slot = index
    }
    config_tmp.by_name[name] = config_tmp.config[index]

    config_tmp.max_slot = index > config_tmp.max_slot and index or config_tmp.max_slot
    if config_tmp.config[index].min > 0 then
        config_tmp.c_requests = config_tmp.c_requests + 1
    end
end

function player_data.clear_config(pdata, index)
    local config_tmp = pdata.config_tmp
    local config = config_tmp.config[index]
    if config then
        if config.min > 0 then
            config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
        end
        if pdata.selected == index then pdata.selected = false end
        config_tmp.by_name[config.name] = nil
        config_tmp.config[index] = nil
        if index == config_tmp.max_slot then
            config_tmp.max_slot = 0
            for i = index-1, 1, -1 do
                if config_tmp.config[i] then
                    config_tmp.max_slot = i
                    break
                end
            end
        end
    end
end

function player_data.check_config(player, pdata)
    local adjusted
    for _, config in pairs(pdata.config_tmp.config) do
        if config.max < config.min then
            adjusted = true
            config.max = config.min
            player.print{"at-message.adjusted-trash-amount", at_util.item_prototype(config.name).localised_name, config.max}
        end
    end
    return adjusted
end

function player_data.combine_from_vanilla(player, pdata, name)
    if not player.character then
        return {config = {}, by_name = {}, c_requests = 0, max_slot = 0}
    end
    local result = at_util.get_requests(player.get_personal_logistic_slot, player.character.request_slot_count)
    if name and next(result.config) then
        pdata.presets[name] = at_util.copy_preset(result)
    end
    return result
end

function player_data.import_when_empty(player, pdata)
    if not next(pdata.config_new.config) then
        player.print{"at-message.empty-config"}
        player.print{"at-message.auto-import"}
        pdata.config_tmp = player_data.combine_from_vanilla(player, "at_imported")
        pdata.config_new = at_util.copy_preset(pdata.config_tmp)
        pdata.selected = false
        return true
    end
end

--mostly taken from https://github.com/raiguard/Factorio-QuickItemSearch/blob/master/src/scripts/player-data.lua
function player_data.find_request(player, item)
    local character = player.character
    local get_slot = character.get_personal_logistic_slot
    local result
    local max = character.request_slot_count
    for i=1, max do
        local slot = get_slot(i)
        if tostring(slot.name) == item then
            slot.index = i
            result = slot
            break
        end
    end
    --extend slots if no empty one was found
    if not result and item == "nil" then
        max = max + 1
        result = get_slot(max)
        result.index = max
    end
    return result
end

function player_data.set_request(player, pdata, request, temporary)
    local existing_request
    local character = player.character
    if request.index then
        existing_request = character.get_personal_logistic_slot(request.index)
        if tostring(existing_request.name) ~= request.name then
            existing_request = player_data.find_request(player, request.name)
            if existing_request then
                request.index = existing_request.index
            else
                existing_request = player_data.find_request(player, "nil")
                if existing_request then
                    request.index = existing_request.index
                else
                    player.print("No empty slot found")
                    return false
                end
            end
        else
            existing_request.index = request.index
        end
    else
        existing_request = player_data.find_request(player, "nil")
        if existing_request then
            request.index = existing_request.index
        else
            player.print("No empty slot found")
            return false
        end
    end
    character.set_personal_logistic_slot(request.index, request)
    if temporary then
        pdata.temporary_requests[request.name] = {temporary = request, previous = existing_request}
        pdata.flags.has_temporary_requests = true
    end
    return true
end

function player_data.check_temporary_requests(player, pdata)
    local contents = player.get_main_inventory().get_contents()
    local cursor_stack = player.cursor_stack
    if cursor_stack and cursor_stack.valid_for_read then
        contents[cursor_stack.name] = cursor_stack.count + (contents[cursor_stack.name] or 0)
    end

    local temporary_requests = pdata.temporary_requests
    local character = player.character
    local set_request = character.set_personal_logistic_slot
    local get_request = character.get_personal_logistic_slot
    local clear_request = character.clear_personal_logistic_slot
    for name, next_request in pairs(temporary_requests) do
        local temporary_request = next_request.temporary
        local item_count = contents[name] or 0

        local remove_request = false
        local current_request = get_request(temporary_request.index)
        if tostring(current_request.name) == temporary_request.name then
            if current_request.min ~= temporary_request.min or current_request.max ~= temporary_request.max then
                remove_request = true
            else
                if item_count >= temporary_request.min and item_count <= temporary_request.max then
                    clear_request(temporary_request.index)
                    set_request(temporary_request.index, next_request.previous)
                    remove_request = true
                    player.print({"at-message.removed-from-temporary-requests", at_util.item_prototype(name).localised_name})
                end
            end
        else
            remove_request = true
        end
        if remove_request then
            temporary_requests[name] = nil
        end
    end
    if not next(temporary_requests) then
        pdata.flags.has_temporary_requests = false
    end
end

function player_data.add_preset(player, pdata, name, config)
    config = config or pdata.config_tmp
    if name == "" then
        player.print({"at-message.name-not-set"})
        return
    end
    if pdata.presets[name] then
        if not pdata.settings.overwrite then
            player.print({"at-message.name-in-use"})
            return
        end
        pdata.presets[name] = at_util.copy_preset(config)
        player.print({"at-message.preset-updated", name})
    else
        pdata.presets[name] = at_util.copy_preset(config)
        if (player.controller_type ~= defines.controllers.editor) then
            gui.build(pdata.gui.presets.scroll, {gui_util.preset(name, pdata)})
        end
    end
    return true

end

return player_data