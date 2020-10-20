local table = require("__flib__.table")

local player_data = {}

function player_data.init(player_index)
    global._pdata[player_index] = {
        flags = {
            gui_open = false,
            trash_above_requested = false,
            trash_unrequested = false,
            trash_network = false,
            pause_trash = false,
            pause_requests = false,
        },
        gui = {},
        config_new = {config = {}, c_requests = 0, max_slot = 0},
        config_tmp = {config = {}, c_requests = 0, max_slot = 0},
        selected = false,

        main_network = false,
        current_network = nil,
        storage_new = {},
        temporary_requests = {},
        temporary_trash = {},
        settings = {},
        dirty = false,
        selected_presets = {},
        death_presets = {},


    }
    player_data.update_settings(game.get_player(player_index), global._pdata[player_index])
end

function player_data.update_settings(player, pdata)
    local player_settings = player.mod_settings
    local settings = {
        status_count = player_settings["autotrash_status_count"].value,
        status_columns = player_settings["autotrash_status_columns"].value,
        display_messages = player_settings["autotrash_display_messages"].value,
        close_on_apply = player_settings["autotrash_close_on_apply"].value,
        reset_on_close = player_settings["autotrash_reset_on_close"].value,
        overwrite = player_settings["autotrash_overwrite"].value,
        trash_equals_requests = player_settings["autotrash_trash_equals_requests"].value,
    }
    pdata.settings = settings
end

return player_data