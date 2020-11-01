local floor = math.floor
local trash_blacklist = require("constants").trash_blacklist

local M = {}

local item_prototypes = {}
M.item_prototype = function(name)
    if item_prototypes[name] then
        return item_prototypes[name]
    end
    item_prototypes[name] = game.item_prototypes[name]
    return item_prototypes[name]
end

M.get_requests = function(player)
    local character = player.character
    if not character then
        return {}
    end
    local requests = {}
    local count = 0
    local get_request_slot = character.get_request_slot
    local max_slot
    for c = player.character_logistic_slot_count, 1, -1 do
        local t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = {name = t.name, request = t.count, slot = c}
            count = t.count > 0 and count + 1 or count
        end
    end
    return requests, max_slot, count
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

    if config_new.max_slot > slot_count then
        player.character_logistic_slot_count = config_new.max_slot
        slot_count = config_new.max_slot
    end

    local min, max
    for c = 1, slot_count do
        clear_request_slot(c)
        local req = storage[c]
        if req then
            local name = req.name
            local request = req.request
            if not requests_paused and request >= 0 then
                min = request
            end
            if not trash_paused then
                local trash = req.trash
                if trash then
                    max = trash
                    if trash_above_requested then
                        max = request
                        max = (max > trash) and max or trash
                    end
                end
                if contents and contents[name] then
                    contents[name] = nil
                end
            end
            set_request_slot(c, {name = name, min = min, max = max})
            min, max = nil, nil
        end
    end

    --trash unrequested items
    if contents and not trash_paused then
        for name, _ in pairs(contents) do
            if trash_blacklist[M.item_prototype(name).type] then
                contents[name] = nil
            end
        end

        local c_contents = table_size(contents)
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
    local character = player.character
    if not character then return end
    pdata.flags.pause_requests = true
    M.set_requests(player, pdata)
end

M.unpause_requests = function(player, pdata)
    if not player.character then return end
    pdata.flags.pause_requests = false
    M.set_requests(player, pdata)
end

M.pause_trash = function(player, pdata)
    if not player.character then return end
    pdata.flags.pause_trash = true
    M.set_requests(player, pdata)
end

M.unpause_trash = function(player, pdata)
    if not player.character then return end
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
        player.print("AutoTrash lost the main network. You will have to set it again.")
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
    if not player.character then return end
    local tmp = {config = {}, max_slot = 0, c_requests = 0}
    local requests, max_slot, c_requests = M.get_requests(player)
    local trash = player.auto_trash_filters

    for name, config in pairs(requests) do
        config.trash = false
        tmp.config[config.slot] = config
        if trash[name] then
            config.trash = trash[name] > config.request and trash[name] or config.request
            config.trash = config.trash < 4294967295 and config.trash or false
            trash[name] = nil
        end
    end
    local no_slot = {}
    for name, count in pairs(trash) do
        no_slot[#no_slot+1] = {
            name = name,
            request = 0,
            trash = count,
            slot = false
        }
    end
    local start = 1
    max_slot = max_slot or 0
    for _, s in pairs(no_slot) do
        for i = start, max_slot + #no_slot do
            if not tmp.config[i] then
                s.slot = i
                tmp.config[i] = s
                start = i + 1
                max_slot = max_slot > i and max_slot or i
                break
            end
        end
    end
    tmp.max_slot = max_slot
    tmp.c_requests = c_requests
    return tmp
end

M.saveVar = function(var, name)
    var = var or global
    local n = name and "autotrash_" .. name or "autotrash"
    game.write_file(n..".lua", serpent.block(var, {name = "global", comment = false}))
end

M.display_message = function(player, message, sound)
    player.print(message)
    if sound then
        if sound == "success" then
            player.play_sound{path = "utility/console_message", position = player.position}
        else
            player.play_sound{path = "utility/cannot_build", position = player.position}
        end
    end
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
    return (item_config.request and item_config.request >= 0) and item_config.request or (item_config.trash and 0)
end

M.format_trash = function(item_config)
    return item_config.trash and item_config.trash or "∞"
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

M.remove_invalid_items = function(pdata, tbl, unselect)
    for i = tbl.max_slot, 1, -1 do
        local item_config = tbl.config[i]
        if item_config then
            if not M.item_prototype(item_config.name) then
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

return M