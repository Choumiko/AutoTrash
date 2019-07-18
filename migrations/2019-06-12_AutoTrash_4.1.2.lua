if not global._pdata then
    global._pdata = {}
    -- just enough to get on_load() to run
    for index, _ in pairs(game.players) do
        global._pdata[index] = {
            temporary_trash = {},
        }
    end
end