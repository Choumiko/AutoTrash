local floor = math.floor
local function saveVar(var, name)
    var = var or global
    local n = name or ""
    game.write_file("autotrash"..n..".lua", serpent.block(var, {name="global", comment=false}))
end

local function debugDump(var, force)
    if false or force then
        for _, player in pairs(game.players) do
            local msg
            if type(var) == "string" then
                msg = var
            else
                msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
            end
            player.print(msg)
        end
    end
end

local function display_message(player, message, sound)
    player.create_local_flying_text{position=player.position, text=message}
    if sound then
        player.play_sound{path = "utility/cannot_build", position = player.position}
    end
end

local function format_number(n, append_suffix)
  local amount = tonumber(n)
    if not amount then
    return n
  end
  local suffix = ""
  if append_suffix then
    local suffix_list =
      {
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
    if (k==0) then
      break
    end
  end
  return formatted..suffix
end

local function format_request(item_config)
    return (item_config.request and item_config.request > 0) and item_config.request or (item_config.trash and 0) or " "
end

local function format_trash(item_config)
    return item_config.trash and item_config.trash or (item_config.request > 0 and "∞") or " "
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

--config[player_index][slot] = {name = "item", min=0, max=100}
--min: if > 0 set as request
--max: if == 0 and trash unrequested
--if min == max : set req = trash
--if min and max : set req and trash, ensure max > min
--if min and not max (== -1?) : set req, unset trash
--if min == 0 and max : unset req, set trash
--if min == 0 and max == 0: unset req, set trash to 0
local function convert_to_combined_storage()
    local tmp = {}
    local item_to_slot
    local item_config
    local max_index
    global.selected = global.selected or {}
    global.config_tmp = {}
    for player_index, logistics_config in pairs(global["logistics-config"]) do
        if game.get_player(player_index) then
            global.config_tmp[player_index] = global.config_tmp[player_index] or {config = {}, settings = {}}
            item_to_slot = {}
            tmp[player_index] = {config = {}, settings = {}}
            item_config = tmp[player_index]
            max_index = 0
            for i, data in pairs(logistics_config) do
                if data.name then
                    item_to_slot[data.name] = i
                    item_config.config[i] = {name = data.name, request = data.count, trash = false}
                    max_index = i > max_index and i or max_index
                end
            end
            local slot
            max_index = max_index + 1

            for _, trash_data in pairs(global.config[player_index]) do
                if trash_data and trash_data.name then
                    slot = item_to_slot[trash_data.name]
                    if slot then
                        item_config.config[slot].trash = (item_config.config[slot].request > trash_data.count) and item_config.config[slot].request or trash_data.count
                    else
                        item_config.config[max_index] = {name = trash_data.name, trash = trash_data.count, request = false}
                        max_index = max_index + 1
                    end
                end
            end
        end
    end
    log(serpent.block(tmp))
    global.config_new = tmp
    global.config_tmp = util.table.deepcopy(tmp)

    tmp = {}
    for player_index, storage_config in pairs(global.storage) do
        if game.get_player(player_index) then
            tmp[player_index] = {}
            item_config = tmp[player_index]
            if storage_config and storage_config.store then
                for name, stored in pairs(storage_config.store) do
                    max_index = 0
                    item_config[name] = {config = {}, settings = {}}
                    for i, data in pairs(stored) do
                        item_config[name].config[i] = {name = data.name, request = data.count, trash = false}
                        max_index = i > max_index and i or max_index
                    end
                end
            end
        end
    end
    log(serpent.block(tmp))
    global.storage_new = tmp
    global["logistics-config-tmp"] = nil
    global["logistics-config"] = nil
    return tmp
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
    convert = convert_to_combined_storage
}

return M