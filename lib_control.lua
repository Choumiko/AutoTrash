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

local function pause_requests(player)
    local player_index = player.index
    if not global.storage[player_index] then
        global.storage[player_index] = {requests={}}
    end
    global.storage[player_index].requests = global.storage[player_index].requests or {}

    local storage = global.storage[player_index].requests
    if player.character and player.force.character_logistic_slot_count > 0 then
        for c=1,player.force.character_logistic_slot_count do
            local request = player.character.get_request_slot(c)
            if request then
                storage[c] = {name = request.name, count = request.count}
                player.character.clear_request_slot(c)
                --requests[request.name] = request.count
            end
        end
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
    local item_to_slot = {}
    local item_config
    local max_slot
    global.config_free_slot = global.config_free_slot or {}
    for player_index, logistics_config in pairs(global["logistics-config"]) do
        tmp[player_index] = {}
        item_config = tmp[player_index]
        max_slot = 0
        for i, data in pairs(logistics_config) do
            if data.name then
                item_to_slot[data.name] = i
                item_config[i] = {name = data.name, request = data.count, trash = false}
                max_slot = i > max_slot and i or max_slot
            end
        end
        local slot
        max_slot = max_slot + 1
        --log(serpent.block(tmp[player_index]))
        --log(serpent.block(item_config))
        for _, trash_data in pairs(global.config[player_index]) do
            if trash_data.name then
                --log(serpent.line({_, trash_data.name, trash_data.count}))
                slot = item_to_slot[trash_data.name]
                if slot then
                    --log(serpent.line(item_config[slot]))
                    item_config[slot].trash = (item_config[slot].request > trash_data.count) and item_config[slot].request or trash_data.count
                else
                    item_config[max_slot] = {name = trash_data.name, trash = trash_data.count, request = false}
                    max_slot = max_slot + 1
                end
            end
        end
        global.config_free_slot[player_index] = max_slot
        item_to_slot = {}
    end
    log(serpent.block(tmp))
    global.config_new = tmp
    tmp = {}
    global.storage_free_slot = global.storage_free_slot or {}
    for player_index, storage_config in pairs(global.storage) do
        global.storage_free_slot[player_index] = {}
        tmp[player_index] = {}
        item_config = tmp[player_index]
        if storage_config.store then
            for name, stored in pairs(storage_config.store) do
                max_slot = 0
                item_config[name] = {}
                for i, data in pairs(stored) do
                    item_config[name][i] = {name = data.name, request = data.count, trash = false}
                    max_slot = i > max_slot and i or max_slot
                end
                global.storage_free_slot[player_index][name] = max_slot + 1
            end

        end
    end
    log(serpent.block(tmp))
    global.storage_new = tmp
    return tmp
end

local M = {
    saveVar = saveVar,
    debugDump = debugDump,
    pause_requests = pause_requests,
    convert = convert_to_combined_storage
}

return M