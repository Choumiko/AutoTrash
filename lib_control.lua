local floor = math.floor
local trash_blacklist = {
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-item"] = true,
    ["upgrade-item"] = true,
    ["copy-paste-tool"] = true,
    ["selection-tool"] = true,
}


local function get_requests(player)
    local character = player.character
    if not character then
        return {}
    end
    local requests = {}
    local count = 0
    local get_request_slot = character.get_request_slot
    local t, max_slot
    for c = player.character_logistic_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = {name = t.name, request = t.count, slot = c}
            count = t.count > 0 and count + 1 or count
        end
    end
    return requests, max_slot, count
end

local function set_requests(player, pdata)
    local character = player.character
    if not character then return end
    local settings = pdata.settings
    local config_new = pdata.config_new
    local storage = config_new.config
    local slot_count = player.character_logistic_slot_count
    local set_request_slot = character.set_personal_logistic_slot
    local clear_request_slot = character.clear_personal_logistic_slot
    local trash_paused = settings.pause_trash
    local trash_above_requested = settings.trash_above_requested
    local requests_paused = settings.pause_requests
    local contents = settings.trash_unrequested and player.get_main_inventory().get_contents()
    local req

    if config_new.max_slot > slot_count then
        player.character_logistic_slot_count = config_new.max_slot
        slot_count = config_new.max_slot
    end
    local min, max

    for c = 1, slot_count do
        clear_request_slot(c)
        req = storage[c]
        if req then
            if not requests_paused and req.request > 0 then
                min = req.request
            end
            if not trash_paused then
                if trash_above_requested then
                    max = req.request
                    max = (max > (req.trash or 0)) and max or req.trash
                else
                    if req.trash then
                        max = req.trash
                    end
                end
                if contents and contents[req.name] then
                    contents[req.name] = nil
                end
            end
            set_request_slot(c, {name = req.name, min = min, max = max})
            min, max = nil, nil
        end
    end

    if contents and not trash_paused then
        local item_protos = game.item_prototypes
        for name, _ in pairs(contents) do
            if trash_blacklist[item_protos[name].type] then
                contents[name] = nil
            end
        end

        local c_contents = table_size(contents)
        local n_slot_count = slot_count + c_contents
        if slot_count < config_new.max_slot + c_contents then
            player.character_logistic_slot_count = n_slot_count
        end

        local i = config_new.max_slot + 1
        for name, _ in pairs(contents) do
            set_request_slot(i, {name = name, max = 0})
            i = i + 1
        end
    end
end

local function pause_requests(player, pdata)
    local character = player.character
    if not character then return end
    pdata.settings.pause_requests = true
    set_requests(player, pdata)
end

local function unpause_requests(player, pdata)
    if not player.character then return end
    pdata.settings.pause_requests = false
    set_requests(player, pdata)
end

local function pause_trash(player, pdata)
    if not player.character then return end
    pdata.settings.pause_trash = true
    set_requests(player, pdata)
end

local function unpause_trash(player, pdata)
    if not player.character then return end
    pdata.settings.pause_trash = false
    set_requests(player, pdata)
end

local function get_non_equipment_network(player)
    if not player.character then return end
    --trash slots researched
    local logi_point = player.character.get_logistic_point(defines.logistic_member_index.character_provider)
    if not logi_point then
        --requests researched
        logi_point = player.character.get_logistic_point(defines.logistic_member_index.character_requester)
    end
    return logi_point and logi_point.logistic_network
end

local function get_network_entity(player)
    local network = get_non_equipment_network(player)
    if network and network.valid then
        local cell = network.find_cell_closest_to(player.position)
        return cell and cell.owner
    end
    return false
end

local function in_network(player, pdata)
    if not pdata.settings.trash_network then
        return true
    end
    local currentNetwork = get_non_equipment_network(player)
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

item_prototypes = {}--luacheck: allow defined top
local function item_prototype(name)
    if item_prototypes[name] then
        return item_prototypes[name]
    end
    item_prototypes[name] = game.item_prototypes[name]
    return item_prototypes[name]
end

local function combine_from_vanilla(player)
    if not player.character then return end
    local tmp = {config = {}, max_slot = 0, c_requests = 0}
    local requests, max_slot, c_requests = get_requests(player)
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

local function saveVar(var, name)
    var = var or global
    local n = name and "autotrash_" .. name or "autotrash"
    game.write_file(n..".lua", serpent.block(var, {name = "global", comment = false}))
end

local function debugDump(var, player, force)
    if false or force then
        local msg
        if type(var) == "string" then
            msg = var
        else
            msg = serpent.dump(var, {name = "var", comment = false, sparse = false, sortkeys = true})
        end
        if type(player) == "number" then
            player = game.get_player(player)
        end
        if player then
            player.print(msg)
        else
            for _, p in pairs(game.players) do
                p.print(msg)
            end
        end
        log(msg)
    end
end

local function display_message(player, message, sound)
    player.surface.create_entity{name = "flying-text", position = player.position, text = message, color = {r=1, g=1, b=1}}
    if sound then
        if sound == "success" then
            player.play_sound{path = "utility/console_message", position = player.position}
        else
            player.play_sound{path = "utility/cannot_build", position = player.position}
        end
    end
end

local function format_number(n, append_suffix)
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

local function format_request(item_config)
    return (item_config.request and item_config.request > 0) and item_config.request or (item_config.trash and 0) or ""
end

local function format_trash(item_config)
    return item_config.trash and item_config.trash or (item_config.request > 0 and "∞") or ""
end

local function convert_from_slider(n)
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
local function convert_to_slider(n)
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

local M = {
    item_prototype = item_prototype,
    saveVar = saveVar,
    debugDump = debugDump,
    display_message = display_message,
    format_number = format_number,
    format_request = format_request,
    format_trash = format_trash,
    convert_to_slider = convert_to_slider,
    convert_from_slider = convert_from_slider,
    pause_trash = pause_trash,
    unpause_trash = unpause_trash,
    set_requests = set_requests,
    get_requests = get_requests,
    pause_requests = pause_requests,
    unpause_requests = unpause_requests,
    get_non_equipment_network = get_non_equipment_network,
    get_network_entity = get_network_entity,
    in_network = in_network,
    combine_from_vanilla = combine_from_vanilla
}

return M