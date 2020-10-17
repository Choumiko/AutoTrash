local table = require("__flib__.table")

local player_data = {}

local default_settings = {
    trash_above_requested = false,
    trash_unrequested = false,
    trash_network = false,
    pause_trash = false,
    pause_requests = false,
}

function player_data.init(player_index)
    global._pdata[player_index] = {
        config_new = {config = {}, c_requests = 0, max_slot = 0},
        config_tmp = {config = {}, c_requests = 0, max_slot = 0},
        selected = false,

        main_network = false,
        current_network = nil,
        storage_new = {},
        temporary_requests = {},
        temporary_trash = {},
        settings = table.shallow_copy(default_settings),
        dirty = false,
        selected_presets = {},
        death_presets = {},

        gui_actions = {},
        gui_elements = {},
    }
    --player_data.update_settings(game.get_player(player_index), global._pdata[player_index])
end

function player_data.update_settings(player, pdata)
    --local player_settings = player.mod_settings
    local settings = {}
    pdata.settings = settings
end

return player_data