local gui = require("__flib__.gui")
local table = require("__flib__.table")

local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local at_gui = require("scripts.gui")

local mod_gui = require ("__core__.lualib.mod-gui")
local lib_control = require '__AutoTrash__/lib_control'
local set_requests = lib_control.set_requests
local remove_invalid_items = lib_control.remove_invalid_items

local migrations = {
    ["4.1.2"] = function()
        log("Resetting all AutoTrash settings")
        global = {}
        global_data.init()
        for player_index in pairs(game.players) do
            player_data.init(player_index)
        end
    end,
    ["5.1.0"] = function()
        for _, pdata in pairs(global._pdata) do
            pdata.infinite = nil
        end
    end,
    ["5.2.2"] = function()
        global.unlocked_by_force = {}
    end,
    ["5.2.3"] = function()
        for player_index, player in pairs(game.players) do
            local pdata = global._pdata[player_index]
            if pdata then
                local psettings = pdata.settings
                pdata.flags = {
                    can_open_gui = player.force.character_logistic_requests,
                    gui_open = false,
                    status_display_open = false,
                    trash_above_requested = psettings.trash_above_requested or false,
                    trash_unrequested = psettings.trash_unrequested or false,
                    trash_network = psettings.trash_network or false,
                    pause_trash = psettings.pause_trash or false,
                    pause_requests = psettings.pause_requests or false,
                }
                pdata.gui = {
                    mod_gui = {},
                    import = {},
                    main = {}
                }
                pdata.presets = pdata.storage_new
                if pdata.presets then
                    for _, stored in pairs(pdata.presets) do
                        remove_invalid_items(pdata, stored)
                    end
                else
                    pdata.presets = {}
                end
                pdata.storage_new = nil
                pdata.gui_actions = nil
                pdata.gui_elements = nil
                pdata.gui_location = nil

                player_data.update_settings(player, pdata)
            else
                pdata = player_data.init(player_index)
            end
            --keep the status flow in gui.left, everything else goes boom (from AutoTrash)
            local mod_gui_flow = mod_gui.get_frame_flow(player)
            if mod_gui_flow and mod_gui_flow.valid then
                for _, egui in pairs(player.gui.left.mod_gui_frame_flow.children) do
                    if egui.get_mod() == "AutoTrash" then
                        if egui.name == "autotrash_status_flow" then
                            pdata.gui.status_flow = egui
                            egui.clear()
                        else
                            egui.destroy()
                        end
                    end
                end
            end
            local button_flow = mod_gui.get_button_flow(player).autotrash_main_flow
            if button_flow and button_flow.valid then
                pdata.gui.mod_gui.flow = button_flow
                button_flow.clear()
            end
            for _, egui in pairs(player.gui.screen.children) do
                if egui.get_mod() == "AutoTrash" then
                    egui.destroy()
                end
            end
        end

        gui.init()
        gui.build_lookup_tables()
        for pi, player in pairs(game.players) do
            local pdata = global._pdata[pi]
            at_gui.init(player, pdata)
            player_data.refresh(player, pdata)
            if pdata.flags.can_open_gui and not (pdata.gui.main.window and pdata.gui.main.window.valid) then
                at_gui.create_main_window(player, pdata)
            end
        end

        --TODO: remove
        global._pdata[1].config_tmp = table.deep_copy(global._pdata[1].config_new)
        set_requests(game.players[1], global._pdata[1])
        at_gui.open(game.players[1], global._pdata[1])
        -- global._pdata[1].presets["preset2"]["config"][14] = global._pdata[1].presets["preset2"]["config"][7]
        -- global._pdata[1].presets["preset2"]["config"][7] = nil
        -- global._pdata[1].presets["preset2"].max_slot = 14
        -- for i = 1, 13 do
        --     global._pdata[1].presets["fpp" .. i] = table.deep_copy(global._pdata[1].presets["preset1"])
        -- end



    end,
    ["5.2.4"] = function()
        for player_index, player in pairs(game.players) do
            local pdata = global._pdata[player_index]
            pdata.flags.dirty = false
            pdata.dirty = nil
            at_gui.init_status_display(player, pdata)
            at_gui.open_status_display(player, pdata)
        end
    end
}

return migrations