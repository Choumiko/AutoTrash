local lib_control = require '__AutoTrash__.lib_control'
local saveVar = lib_control.saveVar --luacheck: ignore
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_to_slider = lib_control.convert_to_slider
local mod_gui = require '__core__/lualib/mod-gui'

local function show_yarm(index)
    if remote.interfaces.YARM and global.settings[index].YARM_old_expando then
        remote.call("YARM", "show_expando", index)
    end
end

local function hide_yarm(index)
    if remote.interfaces.YARM then
        global.settings[index].YARM_old_expando = remote.call("YARM", "hide_expando", index)
    end
end

local GUI = {
    mainButton = "auto-trash-config-button",
    storage_frame = "auto-trash-logistics-storage-frame",
    config_frame = "at-config-frame",
    trash_above_requested = "auto-trash-above-requested",
    trash_unrequested = "auto-trash-unrequested",
    trash_in_main_network = "auto-trash-in-main-network"
}

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow[GUI.mainButton] then
        return
    end
    if player.force.technologies["character-logistic-slots-1"].researched
    or player.force.technologies["character-logistic-trash-slots-1"].researched then
        local button = button_flow.add{
            type = "sprite-button",
            name = GUI.mainButton,
            style = "auto-trash-sprite-button"
        }
        button.sprite = "autotrash_trash"
    end
end

function GUI.update(player)
    local mainButton = mod_gui.get_button_flow(player)[GUI.mainButton]
    if not mainButton then
        return
    end
    if global.active[player.index] then
        mainButton.sprite = "autotrash_trash"
    else
        mainButton.sprite = "autotrash_trash_paused"
    end
end

function GUI.update_settings(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.config_frame]
    if not frame or not frame.valid then
        return
    end
    local index = player.index
    frame[GUI.trash_unrequested].state = global.settings[index].auto_trash_unrequested
    frame[GUI.trash_above_requested].state = global.settings[index].auto_trash_above_requested
    frame[GUI.trash_in_main_network].state = global.settings[index].auto_trash_in_main_network
end

function GUI.destroy(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow[GUI.mainButton] then
        button_flow[GUI.mainButton].destroy()
    end
end

function GUI.update_sliders(player_index)
    local left = mod_gui.get_frame_flow(game.get_player(player_index))[GUI.config_frame]
    local slider_flow = left and left["at-slider-flow-vertical"]
    if not slider_flow or not slider_flow.valid then
        return
    end
    local visible = global.selected[player_index] or false
    for _, child in pairs(slider_flow.children) do
        child.visible = visible
    end
    if global.selected[player_index] then
        local req = global.config_tmp[player_index].config[global.selected[player_index]]
        slider_flow["at-slider-flow-request"]["at-config-slider"].slider_value = convert_to_slider(tonumber((req.request) and req.request or (req.trash and 0) or -1) or 50)
        slider_flow["at-slider-flow-request"]["at-config-slider-text"].text = format_request(req)
        slider_flow["at-slider-flow-trash"]["at-config-slider"].slider_value = convert_to_slider(tonumber(req.trash and req.trash or -1) or -1)
        slider_flow["at-slider-flow-trash"]["at-config-slider-text"].text = format_trash(req)
    end
end

function GUI.create_buttons(player, slots)
    local left = mod_gui.get_frame_flow(player)
    local frame = (left and left.valid) and left[GUI.config_frame]
    if not frame or not frame.valid or not frame["at-config-scroll"] then
        return
    end
    local ruleset_grid = frame["at-config-scroll"]["at-ruleset-grid"]
    if ruleset_grid and ruleset_grid.valid then
        ruleset_grid.destroy()
    end

    local column_count = 6
    ruleset_grid = frame["at-config-scroll"].add{
        type = "table",
        column_count = column_count,
        name = "at-ruleset-grid",
        style = "slot_table"
    }

    local player_index = player.index
    slots = slots or player.force.character_logistic_slot_count
    for i = 1, slots do
        local req = global["config_tmp"][player_index].config[i]
        local elem_value = req and req.name or nil
        local button_name = "auto-trash-item-" .. i
        local choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = button_name,
            style = "logistic_button_slot",
            elem_type = "item"
        }
        choose_button.elem_value = elem_value
        if global.selected[player_index] == i then
            choose_button.style = "logistic_button_selected_slot"
        end

        local lbl_top = choose_button.add{
            type = "label",
            style = "auto-trash-request-label-top",
            ignored_by_interaction = true,
            caption = " "
        }

        local lbl_bottom = choose_button.add{
            type = "label",
            style = "auto-trash-request-label-bottom",
            ignored_by_interaction = true,
            caption = " "
        }

        if elem_value then
            lbl_top.caption = format_number(format_request(req), true)
            lbl_bottom.caption = format_number(format_trash(req), true)
            --disable popup gui, keeps on_click active
            choose_button.locked = choose_button.name ~=  "auto-trash-item-" .. tostring(global.selected[player_index])
        end
    end
end

function GUI.open_logistics_frame(player, redraw)
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.config_frame]
    local player_index = player.index
    local storage_frame = left[GUI.storage_frame]

    if frame then
        frame.destroy()
        if storage_frame then
            storage_frame.destroy()
        end
        if not redraw then
            global.selected[player_index] = false
            show_yarm(player_index)
            return
        end
    end

    hide_yarm(player_index)

    log("Selected: " .. serpent.line(global.selected[player_index]))
    frame = left.add{
        type = "frame",
        caption = {"auto-trash-logistics-config-frame-title"},
        name = GUI.config_frame,
        direction = "vertical"
    }

    local scroll_pane = frame.add{
        type = "scroll-pane",
        name = "at-config-scroll",
    }

    local display_rows = 6
    scroll_pane.style.maximal_height = math.ceil(38*display_rows+6)

    GUI.create_buttons(player,60)

    local slider_vertical_flow = frame.add{
        type = "table",
        name = "at-slider-flow-vertical",
        column_count = 2
    }
    slider_vertical_flow.style.minimal_height = 60
    slider_vertical_flow.add{
        type = "label",
        caption = "Request"
    }
    local slider_flow_request = slider_vertical_flow.add{
        type = "flow",
        name = "at-slider-flow-request",
        direction = "horizontal",
    }
    slider_flow_request.style.vertical_align = "center"

    slider_flow_request.add{
        type = "slider",
        name = "at-config-slider",
        minimum_value = -1,
        maximum_value = 41,
    }
    slider_flow_request.add{
        type = "textfield",
        name = "at-config-slider-text",
        style = "slider_value_textfield",
    }

    slider_vertical_flow.add{
        type = "label",
        caption = "Trash"
    }
    local slider_flow_trash = slider_vertical_flow.add{
        type = "flow",
        name = "at-slider-flow-trash",
        direction = "horizontal",
    }
    slider_flow_trash.style.vertical_align = "center"

    slider_flow_trash.add{
        type = "slider",
        name = "at-config-slider",
        minimum_value = -1,
        maximum_value = 41,
    }
    slider_flow_trash.add{
        type = "textfield",
        name = "at-config-slider-text",
        style = "slider_value_textfield",
    }

    GUI.update_sliders(player_index)

    frame.add{
        type = "checkbox",
        name = GUI.trash_above_requested,
        caption = {"auto-trash-above-requested"},
        state = global.settings[player.index].auto_trash_above_requested
    }

    frame.add{
        type = "checkbox",
        name = GUI.trash_unrequested,
        caption = {"auto-trash-unrequested"},
        state = global.settings[player.index].auto_trash_unrequested,
    }

    frame.add{
        type = "checkbox",
        name = GUI.trash_in_main_network,
        caption = {"auto-trash-in-main-network"},
        state = global.settings[player.index].auto_trash_in_main_network,
    }

    local caption = global.mainNetwork[player.index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
    frame.add{
        type = "button",
        name = "auto-trash-set-main-network",
        caption = caption
    }


    local button_grid = frame.add{
        type = "table",
        column_count = 3,
        name = "auto-trash-button-grid"
    }
    button_grid.add{
        type = "button",
        name = "auto-trash-logistics-apply",
        caption = {"auto-trash-config-button-apply"}
    }
    button_grid.add{
        type = "button",
        name = "auto-trash-logistics-clear-all",
        caption = {"auto-trash-config-button-clear-all"}
    }
    caption = global["logistics-active"][player_index] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"}
    button_grid.add{
        type = "button",
        name = "auto-trash-logistics-pause",
        caption = caption,
        tooltip = {"auto-trash-tooltip-pause-requests"}
    }

    storage_frame = left.add{
        type = "frame",
        name = GUI.storage_frame,
        caption = {"auto-trash-storage-frame-title"},
        direction = "vertical"
    }
    storage_frame.style.minimal_width = 200

    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 3,
        name = "auto-trash-logistics-storage-buttons"
    }
    storage_frame_buttons.add{
        type = "label",
        caption = {"auto-trash-storage-name-label"},
        name = "auto-trash-logistics-storage-name-label"
    }
    storage_frame_buttons.add{
        type = "textfield",
        text = "",
        name = "auto-trash-logistics-storage-name"
    }
    storage_frame_buttons.add{
        type = "button",
        caption = {"auto-trash-storage-store"},
        name = "auto-trash-logistics-storage-store",
        style = "auto-trash-small-button"
    }
    local storage_scroll = storage_frame.add{
        type = "scroll-pane",
        name = "at-storage-scroll",
    }

    storage_scroll.style.maximal_height = math.ceil(38*10+4)
    local storage_grid = storage_scroll.add{
        type = "table",
        column_count = 2,
        name = "auto-trash-logistics-storage-grid"
    }

    if global.storage_new[player_index] then
        local i = 1
        for key, _ in pairs(global.storage_new[player_index]) do
            storage_grid.add{
                type = "button",
                caption = key,
                name = "auto-trash-logistics-restore-" .. i,
            }
            local remove = storage_grid.add{
                type = "sprite-button",
                name = "auto-trash-logistics-remove-" .. i,
                style = "red_icon_button",
                sprite = "utility/remove"
            }
            remove.style.left_padding = 0
            remove.style.right_padding = 0
            remove.style.top_padding = 0
            remove.style.bottom_padding = 0
            i = i + 1
        end
    end
end

function GUI.close(player)
    local left = mod_gui.get_frame_flow(player)
    local storage_frame = left[GUI.storage_frame]
    local frame = left[GUI.config_frame]

    if storage_frame then
        storage_frame.destroy()
    end
    if frame then
        frame.destroy()
    end
end

function GUI.save_changes(player)
    local player_index = player.index
    global.config_new[player_index] = util.table.deepcopy(global.config_tmp[player_index])

    show_yarm(player_index)
    GUI.close(player)
end

function GUI.clear_all(player)
    local player_index = player.index
    global.config_tmp[player_index].config = {}
    global.config_tmp[player_index].config_by_name = {}
    global.selected[player_index] = false
    GUI.open_logistics_frame(player, true)
end

function GUI.set_item(player, index, element)
    local player_index = player.index
    if not index then
        return
    end

    local elem_value = element.elem_value
    if elem_value then
        if global.config_tmp[player_index].config_by_name[elem_value] then
            display_message(player, {"", {"cant-set-duplicate-request", game.item_prototypes[elem_value].localised_name}}, true)
            element.elem_value = nil
            return global.config_tmp[player_index].config_by_name[elem_value].slot
        end
        global.config_tmp[player_index].config[index] = {name = elem_value, request = game.item_prototypes[elem_value].default_request_amount, trash = false, slot = index}
        global.config_tmp[player_index].config_by_name[elem_value] = global.config_tmp[player_index].config[index]
    end
    return true
end

function GUI.store(player, element)
    local player_index = player.index

    local textfield = element.parent["auto-trash-logistics-storage-name"]
    local name = textfield.text
    name = string.match(name, "^%s*(.-)%s*$")

    if not name or name == "" then
        display_message(player, {"auto-trash-storage-name-not-set"}, true)
        return
    end
    if global.storage_new[player_index][name] then
        display_message(player, {"auto-trash-storage-name-in-use"}, true)
        return
    end

    global.storage_new[player_index][name] = util.table.deepcopy(global.config_tmp[player_index])
    GUI.open_logistics_frame(player,true)
end

function GUI.restore(player, name)
    local player_index = player.index
    assert(global.storage_new[player_index]) --TODO remove
    assert(global.storage_new[player_index][name]) --TODO remove

    global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
    global.selected[player_index] = false
    GUI.open_logistics_frame(player, true)
end

function GUI.remove(player, element, index)
    local storage_grid = element.parent
    assert(storage_grid and storage_grid.valid) --TODO remove
    local btn1 = storage_grid["auto-trash-logistics-restore-" .. index]
    local btn2 = storage_grid["auto-trash-logistics-remove-" .. index]

    if not btn1 or not btn2 then return end
    assert(global.storage_new[player.index]) --TODO remove
    assert(global.storage_new[player.index][btn1.caption]) --TODO remove
    global["storage_new"][player.index][btn1.caption] = nil
    btn1.destroy()
    btn2.destroy()
end

return GUI
