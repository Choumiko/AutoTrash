local at_util = require("scripts.util")
local table = require("__flib__.table")

local player_data = {}

function player_data.init(player_index)
    local player = game.get_player(player_index)
    global._pdata[player_index] = {
        flags = {
            can_open_gui = player.character and player.force.character_logistic_requests,
            gui_open = false,
            dirty = false,
            pinned = true,
            status_display_open = false,
            trash_above_requested = false,
            trash_unrequested = false,
            trash_network = false,
            pause_trash = false,
            pause_requests = false,
            has_temporary_requests = false,
        },
        gui = {
            mod_gui = {},
            import = {},
            main = {}
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
    player_data.update_settings(game.get_player(player_index), global._pdata[player_index])

    global._pdata[player_index].config_tmp = player_data.combine_from_vanilla(player)
    global._pdata[player_index].config_new = table.deep_copy(global._pdata[player_index].config_tmp)

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
    }
    pdata.settings = settings
end

function player_data.refresh(player, pdata)
    pdata.flags.can_open_gui = player.character and player.force.character_logistic_requests
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
    local by_name = {}
    local requests = {}
    local count = 0
    local get_request_slot = player.get_personal_logistic_slot
    local max_slot = 0
    for c = 1, player.character_logistic_slot_count do
        local t = get_request_slot(c)
        if t.name then
            max_slot = c > max_slot and c or max_slot
            requests[c] = {name = t.name, min = t.min, max = t.max, slot = c}
            by_name[t.name] = requests[c]
            count = t.min > 0 and count + 1 or count
        end
    end
    local result = {config = requests, by_name = by_name, max_slot = max_slot, c_requests = count}
    if name and next(result.config) then
        pdata.presets[name] = table.deep_copy(result)
    end
    return result
end

function player_data.import_when_empty(player, pdata)
    if not next(pdata.config_new.config) then
        player.print{"at-message.empty-config"}
        player.print{"at-message.auto-import"}
        pdata.config_tmp = player_data.combine_from_vanilla(player, "at_imported")
        pdata.config_new = table.deep_copy(pdata.config_tmp)
        return true
    end
end

--mostly taken from https://github.com/raiguard/Factorio-QuickItemSearch/blob/master/src/scripts/player-data.lua
function player_data.find_request(player, item)
    local character = player.character
    local get_slot = character.get_personal_logistic_slot
    local result
    local max = character.character_logistic_slot_count
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
        player.character_logistic_slot_count = player.character_logistic_slot_count + 10
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
    if request.index > player.character_logistic_slot_count then
        player.character_logistic_slot_count = request.index
    end
    character.clear_personal_logistic_slot(request.index)
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

return player_data