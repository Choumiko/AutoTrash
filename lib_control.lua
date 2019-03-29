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

local M = {
    saveVar = saveVar,
    debugDump = debugDump,
    pause_requests = pause_requests
}

return M