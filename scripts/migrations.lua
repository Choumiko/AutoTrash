local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local at_gui = require("scripts.gui")
local spider_gui = require("scripts.spidertron")
local constants = require("constants")

local mod_gui = require ("__core__.lualib.mod-gui")
local item_prototype = require("scripts.util").item_prototype

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
                    import = {},
                    main = {}
                }
                pdata.presets = pdata.storage_new
                if pdata.presets then
                    for _, stored in pairs(pdata.presets) do
                        --remove invalid items
                        for i = stored.max_slot, 1, -1 do
                            local item_config = stored.config[i]
                            if item_config then
                                if not item_prototype(item_config.name) then
                                    if stored.config[i].request > 0 then
                                        stored.c_requests = stored.c_requests - 1
                                    end
                                    stored.config[i] = nil
                                    if stored.max_slot == i then
                                        stored.max_slot = false
                                    end
                                else
                                    stored.max_slot = stored.max_slot or i
                                end
                            end
                        end
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
                for _, egui in pairs(mod_gui_flow.children) do
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
                button_flow.destroy()
            end
            for _, egui in pairs(player.gui.screen.children) do
                if egui.get_mod() == "AutoTrash" then
                    egui.destroy()
                end
            end
        end

        for pi, player in pairs(game.players) do
            local pdata = global._pdata[pi]
            player_data.refresh(player, pdata)
            at_gui.init(player, pdata)
        end
    end,
    ["5.2.4"] = function()
        for player_index, player in pairs(game.players) do
            local pdata = global._pdata[player_index]
            pdata.flags.dirty = false
            pdata.dirty = nil
            at_gui.init_status_display(player, pdata)
            at_gui.open_status_display(player, pdata)
        end
    end,
    ["5.2.9"] = function()
        for player_index, _ in pairs(game.players) do
            local pdata = global._pdata[player_index]
            pdata.flags.pinned = true
        end
    end,
    ["5.2.11"] = function()
        local set_trash = function(data)
            for _, config in pairs(data.config) do
                if not config.trash then
                    config.trash = constants.max_request
                end
                config.max = config.trash or constants.max_request
                config.min = config.request or 0
                config.trash = nil
                config.request = nil
            end
        end

        for _, pdata in pairs(global._pdata) do
            set_trash(pdata.config_tmp)
            set_trash(pdata.config_new)
            for _, preset in pairs(pdata.presets) do
                set_trash(preset)
            end
            pdata.temporary_trash = nil
            pdata.temporary_requests = {}
            pdata.flags.has_temporary_requests = false
        end
        script.on_event(defines.events.on_player_trash_inventory_changed, nil)
    end,
    ["5.2.13"] = function()
        for _, pdata in pairs(global._pdata) do
            pdata.next_check = nil
        end
    end,
    ["5.2.14"] = function()
        for _, pdata in pairs(global._pdata) do
            pdata.networks = {}
            if pdata.main_network and pdata.main_network.valid then
                pdata.networks[pdata.main_network.unit_number] = pdata.main_network
            end
            pdata.main_network = nil
        end
    end,
    ["5.2.15"] = function()
        for pi, player in pairs(game.players) do
            local pdata = global._pdata[pi]
            player_data.refresh(player, pdata)
            at_gui.init(player, pdata)
        end
        for _, force in pairs(game.forces) do
            if force.character_logistic_requests then
                global.unlocked_by_force[force.name] = true
            end
        end
        for _, pdata in pairs(global._pdata) do
            pdata.config_tmp.by_name = {}
            for _, item_config in pairs(pdata.config_tmp.config) do
                pdata.config_tmp.by_name[item_config.name] = item_config
            end
            pdata.config_new.by_name = {}
            for _, item_config in pairs(pdata.config_new.config) do
                pdata.config_new.by_name[item_config.name] = item_config
            end
            for _, preset in pairs(pdata.presets) do
                preset.by_name = {}
                for _, item_config in pairs(preset.config) do
                    preset.by_name[item_config.name] = item_config
                end
            end
        end
    end,
    ["5.2.16"] = function()
        for pi, pdata in pairs(global._pdata) do
            local player = game.get_player(pi)
            player_data.refresh(player, pdata)
            if pdata.gui.mod_gui and pdata.gui.mod_gui.flow and pdata.gui.mod_gui.flow.valid then
                pdata.gui.mod_gui.flow.destroy()
                pdata.gui.mod_gui = {}
            end
        end
    end,
    ["5.3.1"] = function()
        for pi, pdata in pairs(global._pdata) do
            if pdata.gui.mod_gui and pdata.gui.mod_gui.flow and pdata.gui.mod_gui.flow.valid then
                local player = game.get_player(pi)
                pdata.main_button_index = pdata.gui.mod_gui.flow.get_index_in_parent()
                player_data.refresh(player, pdata)
                pdata.gui.mod_gui.flow.destroy()
                at_gui.update_main_button(player, pdata)
                pdata.gui.mod_gui = {}
            end
        end
    end,
    ["5.3.2"] = function ()
        for pi, pdata in pairs(global._pdata) do
            local player = game.get_player(pi)
            local button_flow = mod_gui.get_button_flow(player)
            local at_flow = button_flow.autotrash_main_flow
            if at_flow then
                at_flow.destroy()
            end
            pdata.gui.mod_gui = nil
            at_gui.update_main_button(player, pdata)
            spider_gui.init(player, pdata)
        end
    end,
}

return migrations