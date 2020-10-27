local player_data = {}

function player_data.init(player_index)
    local player = game.get_player(player_index)
    global._pdata[player_index] = {
        flags = {
            can_open_gui = player.character and player.force.character_logistic_requests,
            gui_open = false,
            dirty = false,
            status_display_open = false,
            trash_above_requested = false,
            trash_unrequested = false,
            trash_network = false,
            pause_trash = false,
            pause_requests = false,
        },
        gui = {
            mod_gui = {},
            import = {},
            main = {}
        },
        config_new = {config = {}, c_requests = 0, max_slot = 0},
        config_tmp = {config = {}, c_requests = 0, max_slot = 0},
        selected = false,

        main_network = false,
        current_network = nil,
        presets = {},
        temporary_requests = {},
        temporary_trash = {},
        settings = {},
        selected_presets = {},
        death_presets = {},


    }
    player_data.update_settings(game.get_player(player_index), global._pdata[player_index])
    return global._pdata[player_index]
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

function player_data.refresh(player, pdata)
    pdata.flags.can_open_gui = player.character and player.force.character_logistic_requests
    player_data.update_settings(player, pdata)
end

return player_data