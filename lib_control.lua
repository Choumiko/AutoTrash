local floor = math.floor

local function set_trash(player)
    if not player.character then return end
    local trash_filters = {}
    local player_index = player.index
    if global.settings[player_index].trash_above_requested then
        local threshold = player.mod_settings["autotrash_threshold"].value
        local amount
        for i, item_config in pairs(global.config_new[player_index].config) do
            if item_config.trash or item_config.request > 0 then
                amount = item_config.request + threshold
                trash_filters[item_config.name] = (amount > (item_config.trash or 0)) and amount or item_config.trash
            end
        end
    else
        for _, item_config in pairs(global.config_new[player_index].config) do
            if item_config.trash then
                assert(item_config.trash >= item_config.request, serpent.line(item_config))--TODO: remove
                trash_filters[item_config.name] = (item_config.trash > item_config.request) and item_config.trash or item_config.request
            end
        end
    end

    player.auto_trash_filters = trash_filters
end

local function pause_trash(player)
    if not player.character then return end
    global.settings[player.index].pause_trash = true
    player.character.auto_trash_filters = {}
end

local function unpause_trash(player)
    if not player.character then return end
    global.settings[player.index].pause_trash = false
    set_trash(player)
end

local function set_requests(player)
    local character = player.character
    if not character then return end
    local config_new = global.config_new[player.index]
    local storage = config_new.config
    local slot_count = character.request_slot_count
    local set_request_slot = character.set_request_slot
    local clear_request_slot = character.clear_request_slot
    local req
    --kind of cheaty..
    if slot_count < config_new.max_slot then
        player.character_logistic_slot_count_bonus = player.character_logistic_slot_count_bonus + (config_new.max_slot - slot_count)
        slot_count = character.request_slot_count
    end
    if config_new.max_slot > slot_count then error("Should not happen") end
    for c = 1, slot_count do
        clear_request_slot(c)
        req = storage[c]
        if req then
            set_request_slot({name = req.name, count = req.request}, c)
        end
    end
end

local function get_requests(player)
    if not player.character then
        return {}
    end
    local requests = {}
    local count = 0
    local get_request_slot = player.character.get_request_slot
    local t, max_slot
    for c = player.character.request_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = {name = t.name, request = t.count, slot = c}
            count = t.count > 0 and count + 1 or count
        end
    end
    return requests, max_slot, count
end

local function pause_requests(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = true
    local character = player.character
    for c = 1, character.request_slot_count do
        character.clear_request_slot(c)
    end
end

local function unpause_requests(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = false
    set_requests(player)
end

local function in_network(player)
    if not global.settings[player.index].autotrash_network then
        return true
    end
    local currentNetwork = player.character.logistic_network
    local entity = global.mainNetwork[player.index]
    if currentNetwork and entity and entity.valid and currentNetwork == entity.logistic_network then
        return true
    end
    return false
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
    saveVar = saveVar,
    debugDump = debugDump,
    display_message = display_message,
    format_number = format_number,
    format_request = format_request,
    format_trash = format_trash,
    convert_to_slider = convert_to_slider,
    convert_from_slider = convert_from_slider,
    set_trash = set_trash,
    pause_trash = pause_trash,
    unpause_trash = unpause_trash,
    set_requests = set_requests,
    get_requests = get_requests,
    pause_requests = pause_requests,
    unpause_requests = unpause_requests,
    in_network = in_network
}

return M