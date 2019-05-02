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

local GUI = {--luacheck: allow defined top
    defines = {
        --DONT RENAME, ELSE GUI WONT CLOSE
        mainButton = "at-config-button",
        config_frame = "at-config-frame",
        config_flow_v = "at_config_flow_v",
        config_flow_h = "at_config_flow_h",

        storage_frame = "at-logistics-storage-frame",
        storage_scroll = "at_storage_scroll",
        storage_grid = "at_storage_grid",

        trash_above_requested = "autotrash_above_requested",
        trash_unrequested = "autotrash_unrequested",
        trash_in_main_network = "autotrash_in_main_network",

        button_flow = "autotrash_button_flow",
        save_button = "autotrash_logistics_apply",
        reset_button = "auotrash_logistics_reset",

        clear_button = "autotrash_clear",
        clear_option = "autotrash_clear_option",
        set_main_network = "autotrash_set_main_network",
        trash_options = "autotrash_trash_options",
        pause_trash = "autotrash_pause_trash",
        pause_requests = "autotrash_pause_requests",
        store_button = "autotrash_preset_save",
        config_request = "at_config_request",
        config_trash = "at_config_trash",
        config_slider = "at_config_slider",
        config_slider_text = "at_config_slider_text",

        choose_button = "autotrash_item_",
        load_preset = "autotrash_preset_load_",
        delete_preset = "autotrash_preset_delete_"
    },
}

local def = GUI.defines

function GUI.get_ruleset_grid(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    return frame[def.config_flow_h] and frame[def.config_flow_h]["at_config_scroll"] and frame[def.config_flow_h]["at_config_scroll"]["at_ruleset_grid"]
end

function GUI.get_button_flow(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    return frame[def.config_flow_h] and frame[def.config_flow_h][def.button_flow]
end

function GUI.get_storage_grid(player)
local frame = mod_gui.get_frame_flow(player)[GUI.defines.storage_frame]
    if not frame or not frame.valid then
        return
    end
    return frame[def.storage_scroll] and frame[def.storage_scroll][GUI.defines.storage_grid]
end

function GUI.index_from_name(name)
    return tonumber(string.match(name, GUI.defines.choose_button .. "(%d+)"))
end

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow[GUI.defines.mainButton] then
        return
    end
    if player.force.technologies["character-logistic-slots-1"].researched
    or player.force.technologies["character-logistic-trash-slots-1"].researched then
        local button = button_flow.add{
            type = "sprite-button",
            name = GUI.defines.mainButton,
            style = "at_sprite_button"
        }
        button.sprite = "autotrash_trash"
    end
end

function GUI.update(player)
    local mainButton = mod_gui.get_button_flow(player)[GUI.defines.mainButton]
    if not mainButton then
        return
    end
    --TODO come up with a graphic that represents trash AND requests being paused
    --mainButton.sprite = "autotrash_logistics_paused"
    if global.settings[player.index].pause_trash then
        mainButton.sprite = "autotrash_trash_paused"
    else
        mainButton.sprite = "autotrash_trash"
    end
    GUI.update_settings(player)
end

function GUI.update_settings(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    frame = frame[GUI.defines.trash_options]
    if not frame or not frame.valid then return end
    local index = player.index
    frame[GUI.defines.trash_unrequested].state = global.settings[index].auto_trash_unrequested
    frame[GUI.defines.trash_above_requested].state = global.settings[index].auto_trash_above_requested
    frame[GUI.defines.trash_in_main_network].state = global.settings[index].auto_trash_in_main_network
    frame[GUI.defines.pause_trash].state = global.settings[index].pause_trash
    frame[GUI.defines.pause_requests].state = global.settings[index].pause_requests
end

function GUI.destroy(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow[GUI.defines.mainButton] then
        button_flow[GUI.defines.mainButton].destroy()
    end
end

function GUI.update_sliders(player)
    local left = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    local slider_flow = left and left.valid and left["at_slider_flow_vertical"]
    if not slider_flow or not slider_flow.valid then
        return
    end
    local player_index = player.index
    local visible = global.selected[player_index] or false
    for _, child in pairs(slider_flow.children) do
        child.visible = visible
    end
    if visible then
        local req = global.config_tmp[player_index].config[visible]
        slider_flow[def.config_request][def.config_slider].slider_value = convert_to_slider(req.request)
        slider_flow[def.config_request][def.config_slider_text].text = format_request(req) or 0
        slider_flow[def.config_trash][def.config_slider].slider_value = req.trash and convert_to_slider(req.trash) or 42
        slider_flow[def.config_trash][def.config_slider_text].text = format_trash(req) or "∞"
    end
    local buttons = left[def.config_flow_h] and left[def.config_flow_h][def.button_flow]
    if not buttons or not buttons.valid then
        return
    end
    buttons[def.reset_button].enabled = global.dirty[player_index]
end

--creates/updates the choose-elem-buttons (update because i do something wierd with locked = true)
function GUI.create_buttons(player)
    local left = mod_gui.get_frame_flow(player)
    local frame = (left and left.valid) and left[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    frame = frame[GUI.defines.config_flow_h]

    local scroll_pane = frame["at_config_scroll"]
    scroll_pane = scroll_pane or frame.add{
        type = "scroll-pane",
        name = "at_config_scroll",
    }
    local mod_settings = player.mod_settings
    local display_rows = mod_settings["autotrash_gui_max_rows"].value
    scroll_pane.style.maximal_height = 38 * display_rows + 6

    local ruleset_grid = scroll_pane["at_ruleset_grid"]
    if ruleset_grid and ruleset_grid.valid then
        ruleset_grid.destroy()
    end

    ruleset_grid = scroll_pane.add{
        type = "table",
        column_count = mod_settings["autotrash_gui_columns"].value,
        name = "at_ruleset_grid",
        style = "slot_table"
    }

    local player_index = player.index
    local slots = mod_settings["autotrash_slots"].value or player.character.request_slot_count
    for i = 1, slots-1 do
        local req = global["config_tmp"][player_index].config[i]
        local elem_value = req and req.name or nil
        local button_name = GUI.defines.choose_button .. i
        local choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = button_name,
            elem_type = "item"
        }
        choose_button.elem_value = elem_value
        choose_button.style = global.selected[player_index] == i and "at_button_slot_selected" or "at_button_slot"

        local lbl_top = choose_button.add{
            type = "label",
            style = "at_request_label_top",
            ignored_by_interaction = true,
            caption = " "
        }

        local lbl_bottom = choose_button.add{
            type = "label",
            style = "at_request_label_bottom",
            ignored_by_interaction = true,
            caption = " "
        }

        if elem_value then
            lbl_top.caption = format_number(format_request(req), true)
            lbl_bottom.caption = format_number(format_trash(req), true)
            --disable popup gui, keeps on_click active
            choose_button.locked = choose_button.name ~=  GUI.defines.choose_button .. tostring(global.selected[player_index])
        end
    end

    local extend_button_flow = ruleset_grid.add{
        type = "flow",
        name = "autotrash-extend-flow",
        direction = "vertical",
        style = "at_extend_flow"
    }

    local minus = extend_button_flow.add{
        type = "button",
        name = "autotrash-extend-less",
        caption = "-",
        style = "at_sprite_button"
    }
    local plus = extend_button_flow.add{
        type = "sprite-button",
        name = "autotrash-extend-more",
        caption = "+",
        style = "at_sprite_button"
    }
    minus.style.maximal_height = 16
    minus.style.minimal_width = 16
    minus.style.font = "default-bold"
    plus.style.maximal_height = 16
    plus.style.minimal_width = 16
    plus.style.font = "default-bold"
end

function GUI.open_logistics_frame(player)
    local player_index = player.index
    assert(not global.selected[player.index], "selected should be false")
    log("Selected: " .. serpent.line(global.selected[player_index]))
    hide_yarm(player_index)
    local left = mod_gui.get_frame_flow(player)
    local frame = left.add{
        type = "frame",
        caption = {"gui-logistic.title"},
        name = GUI.defines.config_frame,
        direction = "vertical"
    }

    --global.config_tmp[player_index] = util.table.deepcopy(global.config_new[player_index])

    -- local config_flow_h = frame.add{
    --     type = "flow",
    --     name = GUI.defines.config_flow_h,
    --     direction = "horizontal"
    -- }
    --config_flow_h.style.horizontally_stretchable = true

    local config_flow_h = frame.add{
        type = "flow",
        name = GUI.defines.config_flow_h,
        direction = "horizontal"
    }
    --config_flow_v.style.horizontally_stretchable = true
    GUI.create_buttons(player)

    local button_flow = config_flow_h.add{
        type = "flow",
        name = def.button_flow,
        direction = "vertical",
        style = "shortcut_bar_column"
    }
    local checkmark = button_flow.add{
        type = "sprite-button",
        name = GUI.defines.save_button,
        style = "shortcut_bar_button_green",
        sprite = "utility/check_mark_white"
    }
    checkmark.style.top_padding = 4
    checkmark.style.right_padding = 4
    checkmark.style.bottom_padding = 4
    checkmark.style.left_padding = 4

    local reset_button = button_flow.add{
        type = "sprite-button",
        name = GUI.defines.reset_button,
        style = "shortcut_bar_button_red",
        sprite = "utility/reset_white"
    }
    reset_button.enabled = global.dirty[player_index]

    button_flow.add{
        type = "sprite-button",
        style = "shortcut_bar_button_blue",
        sprite = "utility/remove"
    }

    local slider_vertical_flow = frame.add{
        type = "table",
        name = "at_slider_flow_vertical",
        column_count = 2
    }
    slider_vertical_flow.style.minimal_height = 60
    slider_vertical_flow.add{
        type = "label",
        caption = {"gui-logistic.title-request-short"}
    }
    local slider_flow_request = slider_vertical_flow.add{
        type = "flow",
        name = GUI.defines.config_request,
        direction = "horizontal",
    }
    slider_flow_request.style.vertical_align = "center"

    slider_flow_request.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 41,
    }
    slider_flow_request.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }

    slider_vertical_flow.add{
        type = "label",
        caption = {"auto-trash-trash"}
    }
    local slider_flow_trash = slider_vertical_flow.add{
        type = "flow",
        name = GUI.defines.config_trash,
        direction = "horizontal",
    }
    slider_flow_trash.style.vertical_align = "center"

    slider_flow_trash.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 42,
    }
    slider_flow_trash.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }

    GUI.update_sliders(player)

    --TODO add a dropdown for quick actions, that apply to each item e.g.
    --Set trash to requested amount
    --Set trash to stack size
    --Set requests to stack size
    --in/decrease by 1 stack size

    local trash_options = frame.add{
        type = "frame",
        name = GUI.defines.trash_options,
        style = "bordered_frame",
        direction = "vertical",
    }
    trash_options.style.use_header_filler = false
    trash_options.style.horizontally_stretchable = true
    trash_options.style.font = "default-bold"

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_above_requested,
        caption = {"auto-trash-above-requested"},
        state = global.settings[player_index].auto_trash_above_requested
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_unrequested,
        caption = {"auto-trash-unrequested"},
        state = global.settings[player_index].auto_trash_unrequested,
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_in_main_network,
        caption = {"auto-trash-in-main-network"},
        state = global.settings[player_index].auto_trash_in_main_network,
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.pause_trash,
        caption = {"auto-trash-config-button-pause"},
        tooltip = {"auto-trash-tooltip-pause"},
        state = global.settings[player_index].pause_trash
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.pause_requests,
        caption = {"auto-trash-config-button-pause-requests"},
        tooltip = {"auto-trash-tooltip-pause-requests"},
        state = global.settings[player_index].pause_requests
    }

    trash_options.add{
        type = "button",
        name = GUI.defines.set_main_network,
        caption = global.mainNetwork[player_index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
    }

    local button_grid = frame.add{
        type = "table",
        column_count = 2,
        name = "auto-trash-button-grid"
    }

    button_grid.add{
        type = "button",
        name = GUI.defines.clear_button,
        caption = {"gui.clear"}
    }
    button_grid.add{
        type = "drop-down",
        name = GUI.defines.clear_option,
        items = {
            [1] = "Both",
            [2] = "Requests",
            [3] = "Trash"
        },
        selected_index = 1
    }

    local storage_frame = left.add{
        type = "frame",
        name = GUI.defines.storage_frame,
        caption = {"auto-trash-storage-frame-title"},
        direction = "vertical"
    }
    storage_frame.style.minimal_width = 200

    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 2,
        name = "auto-trash-logistics-storage-buttons"
    }
    storage_frame_buttons.add{
        type = "textfield",
        text = "",
        name = "auto-trash-logistics-storage-name"
    }
    storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save-as"},
        name = GUI.defines.store_button,
        style = "at_small_button"
    }
    local storage_scroll = storage_frame.add{
        type = "scroll-pane",
        name = GUI.defines.storage_scroll
    }

    storage_scroll.style.maximal_height = math.ceil(38*10+4)
    local storage_grid = storage_scroll.add{
        type = "table",
        name = GUI.defines.storage_grid,
        column_count = 2,
    }

    local i = 1
    for key, _ in pairs(global.storage_new[player_index]) do
        GUI.add_preset(player, key, i, storage_grid)
        i = i + 1
    end
end

function GUI.close(player, frame_flow)
    local left = frame_flow or mod_gui.get_frame_flow(player)
    local storage_frame = left[GUI.defines.storage_frame]
    local frame = left[GUI.defines.config_frame]
    if storage_frame and storage_frame.valid then
        storage_frame.destroy()
    end
    if frame and frame.valid then
        frame.destroy()
    end
    if player.mod_settings["autotrash_reset_on_close"].value then
        global.config_tmp[player.index] = util.table.deepcopy(global.config_new[player.index])
        global.dirty[player.index] = false
    end
    global.selected[player.index] = false
    show_yarm(player.index)
end

function GUI.apply_changes(player, element)
    local player_index = player.index
    global.config_new[player_index] = util.table.deepcopy(global.config_tmp[player_index])
    global.dirty[player_index] = false
    element.parent[def.reset_button].enabled = false
    if player.mod_settings["autotrash_close_on_apply"].value then
        GUI.close(player)
    end
end

function GUI.reset_changes(player, element)
    if global.dirty[player.index] then
        global.config_tmp[player.index] = util.table.deepcopy(global.config_new[player.index])
        element.enabled = false
        global.selected[player.index] = false
        global.dirty[player.index] = false
        GUI.create_buttons(player)
        GUI.update_sliders(player)
    end
end

function GUI.clear_all(player, element)
    local player_index = player.index
    local mode = element.parent[GUI.defines.clear_option].selected_index
    local config_tmp = global.config_tmp[player_index]
    if mode == 1 then
        config_tmp.config = {}
        config_tmp.config_by_name = {}
        global.selected[player_index] = false
    elseif mode == 2 then
        for _, config in pairs(config_tmp.config_by_name) do
            config.request = 0
        end
    elseif mode == 3 then
        for _, config in pairs(config_tmp.config_by_name) do
            config.trash = false
        end
    end
    --TODO save selected_index somewhere
    GUI.create_buttons(player)
end

function GUI.set_item(player, index, element)
    local player_index = player.index
    if not index then
        return
    end

    local elem_value = element.elem_value
    if elem_value then
        local config_tmp = global.config_tmp[player_index]
        if config_tmp.config_by_name[elem_value] then
            display_message(player, {"", {"cant-set-duplicate-request", game.item_prototypes[elem_value].localised_name}}, true)
            element.elem_value = nil
            return config_tmp.config_by_name[elem_value].slot
        end
        config_tmp.config[index] = {name = elem_value, request = game.item_prototypes[elem_value].default_request_amount, trash = false, slot = index}
        config_tmp.config_by_name[elem_value] = config_tmp.config[index]
    end
    return true
end

function GUI.add_preset(player, preset_name, index, storage_grid)
    storage_grid = storage_grid or GUI.get_storage_grid(player)
    assert(not storage_grid.children[index*2-1] and not storage_grid.children[index*2])--TODO remove

    storage_grid.add{
        type = "button",
        caption = preset_name,
        name = GUI.defines.load_preset .. index,
    }
    local remove = storage_grid.add{
        type = "sprite-button",
        name = GUI.defines.delete_preset .. index,
        style = "red_icon_button",
        sprite = "utility/remove"
    }
    remove.style.left_padding = 0
    remove.style.right_padding = 0
    remove.style.top_padding = 0
    remove.style.bottom_padding = 0
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
    GUI.add_preset(player, name, table_size(global.storage_new[player_index]))
    textfield.text = ""
end

function GUI.restore(player, element)
    local player_index = player.index
    local name = element.caption
    element.style = "at_preset_button_selected"
    assert(global.storage_new[player_index] and global.storage_new[player_index][name]) --TODO remove

    global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
    global.selected[player_index] = false
    global.dirty[player_index] = false
    GUI.create_buttons(player)
    GUI.update_sliders(player)
end

function GUI.remove(player, element, index)
    local storage_grid = element.parent
    local btn1 = storage_grid[GUI.defines.load_preset .. index]
    local btn2 = storage_grid[GUI.defines.delete_preset .. index]
    assert(global.storage_new[player.index] and global.storage_new[player.index][btn1.caption]) --TODO remove
    global["storage_new"][player.index][btn1.caption] = nil
    btn1.destroy()
    btn2.destroy()
end

return GUI
