local floor = math.floor
local constants = require("constants")

local M = {}

local item_prototypes = {}
M.item_prototype = function(name)
    if item_prototypes[name] then
        return item_prototypes[name]
    end
    item_prototypes[name] = game.item_prototypes[name]
    return item_prototypes[name]
end

M.set_requests = function(player, pdata)
    local character = player.character
    if not character then return end
    local flags = pdata.flags
    local config_new = pdata.config_new
    local storage = config_new.config
    local slot_count = player.character_logistic_slot_count
    local set_request_slot = character.set_personal_logistic_slot
    local clear_request_slot = character.clear_personal_logistic_slot
    local trash_paused = flags.pause_trash
    local trash_above_requested = flags.trash_above_requested
    local requests_paused = flags.pause_requests
    local contents = flags.trash_unrequested and player.get_main_inventory().get_contents()
    local temporary_requests = pdata.temporary_requests
    local handled_temporary = {}

    if config_new.max_slot > slot_count then
        player.character_logistic_slot_count = config_new.max_slot
        slot_count = config_new.max_slot
    end

    local max_request = constants.max_request
    local min, max = 0, max_request
    for c = 1, slot_count do
        --TODO: move in else block for 1.1
        clear_request_slot(c)
        local req = storage[c]
        if req then
            local name = req.name
            if temporary_requests[name] then
                req =temporary_requests[name].temporary
                handled_temporary[name] = true
            end
            local request = req.min
            if not requests_paused then
                min = request
            end
            if not trash_paused then
                max = (trash_above_requested and request > 0) and request or req.max
                if contents and contents[name] then
                    contents[name] = nil
                end
            end
            set_request_slot(c, {name = name, min = min, max = max})
            min, max = 0, max_request
        end
    end

    --handle remaining temporary requests
    for name, request_data in pairs(temporary_requests) do
        local temp_request = request_data.temporary
        if not handled_temporary[name] then
            set_request_slot(temp_request.index, temp_request)
            if contents and contents[name] then
                contents[name] = nil
            end
        end
    end

    --trash unrequested items
    if contents and not trash_paused then
        local c_contents = table_size(contents)
        if c_contents == 0 then return end
        for name, _ in pairs(contents) do
            if constants.trash_blacklist[M.item_prototype(name).type] then
                contents[name] = nil
            end
        end

        if slot_count < config_new.max_slot + c_contents then
            player.character_logistic_slot_count = slot_count + c_contents
        end

        local i = config_new.max_slot + 1
        for name, _ in pairs(contents) do
            set_request_slot(i, {name = name, max = 0})
            i = i + 1
        end
    end
end

M.pause_requests = function(player, pdata)
    pdata.flags.pause_requests = true
    M.set_requests(player, pdata)
end

M.unpause_requests = function(player, pdata)
    pdata.flags.pause_requests = false
    M.set_requests(player, pdata)
end

M.pause_trash = function(player, pdata)
    pdata.flags.pause_trash = true
    M.set_requests(player, pdata)
end

M.unpause_trash = function(player, pdata)
    pdata.flags.pause_trash = false
    M.set_requests(player, pdata)
end

M.get_non_equipment_network = function(character)
    if not character then return end
    --trash slots researched
    local logi_point = character.get_logistic_point(defines.logistic_member_index.character_provider)
    if not logi_point then
        --requests researched
        logi_point = character.get_logistic_point(defines.logistic_member_index.character_requester)
    end
    return logi_point and logi_point.logistic_network
end

M.get_network_entity = function(player)
    local network = M.get_non_equipment_network(player.character)
    if network and network.valid then
        local cell = network.find_cell_closest_to(player.position)
        return cell and cell.owner
    end
    return false
end

M.in_network = function(player, pdata)
    if not pdata.flags.trash_network then
        return true
    end
    local currentNetwork = M.get_non_equipment_network(player.character)
    if pdata.main_network and not pdata.main_network.valid then
        --ended up with an invalid entity, not much i can do to recover
        player.print({"at-message.network-lost"})
        pdata.main_network = false
        return false, true
    end
    local entity = (pdata.main_network and pdata.main_network.valid) and pdata.main_network
    if currentNetwork and entity and currentNetwork.valid and currentNetwork == entity.logistic_network then
        return true
    end
    return false
end

M.combine_from_vanilla = function(player)
    if not player.character then
        return {config = {}, c_requests = 0, max_slot = 0}
    end
    local requests = {}
    local count = 0
    local get_request_slot = player.get_personal_logistic_slot
    local max_slot = 0
    for c = 1, player.character_logistic_slot_count do
        local t = get_request_slot(c)
        if t.name then
            max_slot = c > max_slot and c or max_slot
            requests[c] = {name = t.name, min = t.min, max = t.max, slot = c}
            count = t.min > 0 and count + 1 or count
        end
    end
    return {config = requests, max_slot = max_slot, c_requests = count}
end

M.format_number = function(n, append_suffix)
    local amount = tonumber(n)
    if not amount then
    return n
    end
    local suffix = ""
    if append_suffix then
        local suffix_list = {
            ["T"] = 1000000000000,
            ["B"] = 1000000000,
            ["M"] = 1000000,
            ["k"] = 1000
        }
        for letter, limit in pairs (suffix_list) do
            if math.abs(amount) >= limit then
                amount = floor(amount/(limit/10))/10
                suffix = letter
                break
            end
        end
    end
    local formatted, k = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted..suffix
end

M.format_request = function(item_config)
    return (item_config.min and item_config.min >= 0) and item_config.min or (item_config.max and 0)
end

M.format_trash = function(item_config)
    return (item_config.max < constants.max_request) and item_config.max or "∞"
end

M.convert_from_slider = function(n)
    if not n then
        return -1
    end
    n = floor(n)
    if n <= 10 then
        return n
    elseif n <= 19 then
        return (n-9)*10
    elseif n <= 28 then
        return (n-18)*100
    elseif n <= 37 then
        return (n-27)*1000
    else
        return (n-36)*10000
    end
end

local huge = math.huge
M.convert_to_slider = function(n)
    if n <= 10 then
        return n
    elseif n <= 100 then
        return n/10+9
    elseif n <= 1000 then
        return n/100+18
    elseif n <= 10000 then
        return n/1000+27
    elseif n < huge then
        return n/10000+36
    else
        return 42
    end
end

M.remove_invalid_items = function()
    local function _remove(tbl)
        for i = tbl.max_slot, 1, -1 do
            local item_config = tbl.config[i]
            if item_config then
                if not M.item_prototype(item_config.name) then
                    if tbl.config[i].min > 0 then
                        tbl.c_requests = tbl.c_requests - 1
                    end
                    tbl.config[i] = nil
                    if tbl.max_slot == i then
                        tbl.max_slot = false
                    end
                else
                    tbl.max_slot = tbl.max_slot or i
                end
            end
        end
    end
    for _, pdata in pairs(global._pdata) do
        if pdata.config_new and pdata.config_tmp then
            _remove(pdata.config_new)
            _remove(pdata.config_tmp)
        end
        if pdata.presets then
            for _, stored in pairs(pdata.presets) do
                _remove(stored)
            end
        end
    end
end

return M