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

local M = {
    saveVar = saveVar,
    debugDump = debugDump
}

return M