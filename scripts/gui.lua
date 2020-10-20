local gui = require("__flib__.gui")
local table =require("__flib__.table")
local constants = require("constants")

local lib_control = require '__AutoTrash__.lib_control'
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_to_slider = lib_control.convert_to_slider
local convert_from_slider = lib_control.convert_from_slider
local display_message = lib_control.display_message
local item_prototype = lib_control.item_prototype
local presets = require("presets")

local at_gui = {}

at_gui.templates = {
    slot_table = {
        main = function(btns, pdata)
            local ret = {type = "table", column_count = constants.slot_columns, style = "at_filter_group_table", save_as = "slot_table",
                style_mods = {minimal_height = constants.slot_table_height}, children = {}}
            for i=1, btns do
                ret.children[i] = gui.templates.slot_table.button(i, pdata)
            end
            ret.children[btns+1] = {type = "flow", name = "count_change", direction="vertical", style_mods = {vertical_spacing=0}, children={
                {type = "button", caption="-", handlers="slots.decrease", style = "slot_count_change_button"},
                {type = "button", caption="+", handlers = "slots.increase", style = "slot_count_change_button"}
            }}
            return ret
        end,
        button = function(i, pdata)
            local style = (i == pdata.selected) and "at_button_slot_selected" or "at_button_slot"
            local config = pdata.config_tmp.config[i]
            local req = config and config.request or "0"
            local trash = config and config.trash or "∞"
            return {type = "choose-elem-button", name = i, elem_mods = {elem_value = config and config.name, locked = config and i ~= pdata.selected}, handlers = "slots.item_button", elem_type = "item", style = style, children = {
                {type = "label", style = "at_request_label_top", ignored_by_interaction = true, caption = config and req or ""},
                {type = "label", style = "at_request_label_bottom", ignored_by_interaction = true, caption = config and trash or ""}
            }}
        end,
        count_change = function()
            return {type = "flow", name = "count_change", direction="vertical", style_mods = {vertical_spacing=0}, children={
                {type = "button", caption="-", handlers="slots.decrease", style = "slot_count_change_button"},
                {type = "button", caption="+", handlers = "slots.increase", style = "slot_count_change_button"}
            }}
        end,
    },
    frame_action_button = {type = "sprite-button", style = "frame_action_button", mouse_button_filter={"left"}},
    pushers = {
        horizontal = {type = "empty-widget", style_mods = {horizontally_stretchable = true}},
        vertical = {type = "empty-widget", style_mods = {vertically_stretchable = true}}
    },

    settings = function(flags, pdata)
        return {type = "frame", style = "bordered_frame", style_mods = {right_padding = 8, horizontally_stretchable = "on"}, children = {
            {type = "flow", direction = "vertical", children = {
                {
                    type = "checkbox",
                    --name = gui_defines.trash_above_requested,
                    caption = {"auto-trash-above-requested"},
                    state = flags.trash_above_requested
                },
                {
                    type = "checkbox",
                    --name = gui_defines.trash_unrequested,
                    caption = {"auto-trash-unrequested"},
                    state = flags.trash_unrequested
                },
                {
                    type = "checkbox",
                    --name = gui_defines.trash_network,
                    caption = {"auto-trash-in-main-network"},
                    state = flags.trash_network
                },
                {
                    type = "checkbox",
                    --name = gui_defines.pause_trash,
                    caption = {"auto-trash-config-button-pause"},
                    tooltip = {"auto-trash-tooltip-pause"},
                    state = flags.pause_trash
                },
                {
                    type = "checkbox",
                    --name = gui_defines.pause_requests,
                    caption = {"auto-trash-config-button-pause-requests"},
                    tooltip = {"auto-trash-tooltip-pause-requests"},
                    state = flags.pause_requests
                },
                {
                    type = "button",
                    --name = gui_defines.network_button,
                    caption = pdata.main_network and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
                },
                {template = "pushers.horizontal"}
            }},
            -- {template = "pushers.vertical"},
        }}
    end,

    preset = function(preset_name, pdata)
        local style = pdata.selected_presets[preset_name] and "at_preset_button_selected" or "at_preset_button"
        local rip_style = pdata.death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
        return {type = "flow", direction = "horizontal", name = preset_name, children = {
            {type = "button", style = style, caption = preset_name, name = preset_name, handlers = "presets.load"},
            {type = "sprite-button", style = rip_style, sprite = "autotrash_rip", tooltip = {"autotrash_tooltip_rip"}},
            {type = "sprite-button", style = "at_delete_preset", sprite = "utility/trash"},
        }}
    end,

    presets = function(pdata)
        local ret = {}
        local i = 1
        for name in pairs(pdata.presets) do
            ret[i] = gui.templates.preset(name, pdata)
            i = i + 1
        end
        ret[#ret+1] = {template = "pushers.horizontal"}
        ret[#ret+1] = {template = "pushers.vertical"}
        return ret
    end,
}
gui.add_templates(at_gui.templates)

at_gui.handlers = {
    mod_gui_button = {
        on_gui_click = function(e)
            local pdata = global._pdata[e.player_index]
            at_gui.toggle(game.get_player(e.player_index), pdata)
        end,
    },
    main = {
        close_button = {
            on_gui_click = function(e)
                at_gui.close(game.get_player(e.player_index), global._pdata[e.player_index])
            end
        },
        window = {
            on_gui_closed = function(e)
                at_gui.close(game.get_player(e.player_index), global._pdata[e.player_index])
            end
        }
    },
    slots = {
        item_button = {
            on_gui_click = function(e)
                local player = game.get_player(e.player_index)
                local pdata = global._pdata[e.player_index]
                local elem_value = e.element.elem_value
                local old_selected = pdata.selected
                local index = tonumber(e.element.name)
                if e.button == defines.mouse_button_type.right then
                    if not elem_value then
                        pdata.selected = false
                        pdata.gui.slot_table.children[old_selected].style = "at_button_slot"
                        at_gui.toggle_sliders(pdata, false)
                        return
                    end
                elseif e.button == defines.mouse_button_type.left then
                    if not elem_value or old_selected == index then return end
                    pdata.selected = index
                    if old_selected then
                        local old = pdata.gui.slot_table.children[old_selected]
                        old.style = "at_button_slot"
                        old.locked = old.elem_value and true or false
                    end
                    e.element.style = "at_button_slot_selected"
                    e.element.locked = false
                    at_gui.toggle_sliders(pdata, (elem_value and true or false))
                end
            end,
            on_gui_elem_changed = function(e)
                local player = game.get_player(e.player_index)
                local pdata = global._pdata[e.player_index]
                local elem_value = e.element.elem_value
                local old_selected = pdata.selected
                local index = tonumber(e.element.name)
                if elem_value then
                    local item_config = pdata.config_tmp.config[index]
                    if item_config and elem_value == item_config.name then return end
                    for i, v in pairs(pdata.config_tmp.config) do
                        if i ~= index and elem_value == v.name then
                            display_message(player, {"", {"cant-set-duplicate-request", item_prototype(elem_value).localised_name}}, true)
                            pdata.selected = i
                            pdata.gui.slot_table.children[i].style = "at_button_slot_selected"
                            pdata.gui.main.config_rows.scroll_to_element(pdata.gui.slot_table.children[i], "top-third")
                            if item_config then
                                e.element.elem_value = item_config.name
                            end
                            at_gui.toggle_sliders(pdata, true)
                            return
                        end
                    end
                    pdata.selected = index
                    local request_amount = item_prototype(elem_value).default_request_amount
                    local trash_amount = pdata.settings.trash_equals_requests and request_amount or false
                    local config_tmp = pdata.config_tmp
                    config_tmp.config[index] = {
                        name = elem_value, request = request_amount,
                        trash = trash_amount, slot = index
                    }
                    config_tmp.max_slot = index > config_tmp.max_slot and index or config_tmp.max_slot
                    if config_tmp.config[index].request > 0 then
                        config_tmp.c_requests = config_tmp.c_requests + 1
                    end
                    e.element.style = "at_button_slot_selected"
                    at_gui.toggle_sliders(pdata, true)
                else
                    local config_tmp = pdata.config_tmp
                    config_tmp.config[index] = nil
                    if index == config_tmp.max_slot then
                        config_tmp.max_slot = 0
                        for i = index-1, 1, -1 do
                            if config_tmp.config[i] then
                                config_tmp.max_slot = i
                                break
                            end
                        end
                    end
                    at_gui.toggle_sliders(pdata, false)
                end
            end
        },
        decrease = {
            on_gui_click = function (e)
                local player = game.get_player(e.player_index)
                local old_slots = player.character_logistic_slot_count
                local slots = old_slots > 9 and old_slots - 10 or old_slots
                at_gui.decrease_slots(player, global._pdata[e.player_index], slots, old_slots)
            end,
        },
        increase = {
            on_gui_click = function(e)
                local player = game.get_player(e.player_index)
                local old_slots = player.character_logistic_slot_count
                at_gui.increase_slots(player, global._pdata[e.player_index], old_slots + 10, old_slots)
            end,
        },
    },
    presets = {
        load = {
            on_gui_click = function(e)
                local player = game.get_player(e.player_index)
                local pdata = global._pdata[e.player_index]
                local name = e.element.caption
                if not e.shift and not e.control then
                    pdata.selected_presets = {[name] = true}
                    pdata.config_tmp = table.deep_copy(pdata.presets[name])
                    pdata.selected = false
                    pdata.gui.preset_textfield.text = name
                    local slots = player.character_logistic_slot_count
                    local diff = pdata.config_tmp.max_slot - slots
                    if diff > 0 then
                        local inc = math.ceil(diff / 10) * 10
                        at_gui.increase_slots(player, pdata, slots + inc, slots)
                    end
                else
                    local selected_presets = pdata.selected_presets
                    if not selected_presets[name] then
                        selected_presets[name] = true
                    else
                        selected_presets[name] = nil
                    end
                    local tmp = {config = {}, max_slot = 0, c_requests = 0}
                    for key, _ in pairs(selected_presets) do
                        presets.merge(tmp, pdata.presets[key])
                    end
                    pdata.config_tmp = tmp
                    pdata.selected = false
                end
                at_gui.update_buttons(pdata)
                at_gui.update_presets(pdata)
                at_gui.toggle_sliders(pdata, false)
            end
        },
    }
}
gui.add_handlers(at_gui.handlers)

at_gui.decrease_slots = function(player, pdata, slots, old_slots)
    if slots < pdata.config_tmp.max_slot then return end
    player.character_logistic_slot_count = slots
    local cols = constants.slot_columns
    local rows = constants.slot_rows
    local width = constants.slot_table_width
    width = (slots <= (rows*cols)) and width or (width + 12)
    local slot_table = pdata.gui.slot_table
    for i = old_slots, slots+1, -1 do
        local btn = slot_table.children[i]
        gui.update_filters("slots.item_button", player.index, {btn.index}, "remove")
        btn.destroy()
    end
    if slots == 9 then
        slot_table.count_change.children[1].enabled = false
    end
    pdata.gui.main.config_rows.style.width = width
    pdata.gui.main.config_rows.scroll_to_bottom()
end

at_gui.increase_slots = function(player, pdata, slots, old_slots)
    slots = slots <= 65529 and slots or 65529
    player.character_logistic_slot_count = slots
    local cols = constants.slot_columns
    local rows = constants.slot_rows
    local width = constants.slot_table_width
    width = (slots <= (rows*cols)) and width or (width + 12)


    local slot_table = pdata.gui.slot_table
    gui.update_filters("slots.decrease", player.index, nil, "remove")
    gui.update_filters("slots.increase", player.index, nil, "remove")
    slot_table.count_change.destroy()
    for i = old_slots+1, slots do
        gui.build(slot_table, {gui.templates.slot_table.button(i, pdata)})
    end
    gui.build(slot_table, {gui.templates.slot_table.count_change()})

    pdata.gui.main.config_rows.style.width = width
    pdata.gui.main.config_rows.scroll_to_bottom()
end

at_gui.update_buttons = function(pdata)
    local children = pdata.gui.slot_table.children
    for i=1, #children-1 do
        at_gui.update_button(pdata, i, children[i])
    end
end

at_gui.update_button = function(pdata, i, button)
    local req = pdata.config_tmp.config[i]
    if req then
        button.children[1].caption = format_number(format_request(req), true)
        button.children[2].caption = format_number(format_trash(req), true)
        button.elem_value = req.name
        button.locked = i ~= pdata.selected
    else
        button.children[1].caption = ""
        button.children[2].caption = ""
        button.elem_value = nil
        button.locked = false
    end
    button.style = (i == pdata.selected) and "at_button_slot_selected" or "at_button_slot"
end

at_gui.toggle_sliders = function(pdata, visible)
    if visible and pdata.selected then
        local sliders = pdata.gui.sliders
        local item_config = pdata.config_tmp.config[pdata.selected]
        if item_config then
            sliders.request.slider_value = convert_to_slider(item_config.request)
            sliders.request_text.text = format_request(item_config) or 0

            sliders.trash.slider_value = item_config.trash and convert_to_slider(item_config.trash) or 42
            sliders.trash_text.text = format_trash(item_config) or "∞"
        end
    end
    for _, child in pairs(pdata.gui.sliders.table.children) do
        child.visible = visible
    end
end

at_gui.update_presets = function(pdata)
    local children = pdata.gui.presets_flow.children
    local selected_presets = pdata.selected_presets
    local death_presets = pdata.death_presets
    for i=1, #children-2 do
        local preset = children[i].children[1]
        local rip = children[i].children[2]
        local preset_name = preset.caption
        preset.style = selected_presets[preset_name] and "at_preset_button_selected" or "at_preset_button"
        rip.style = death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
    end
    local s = table_size(selected_presets)
    if s == 1 then
        pdata.gui.preset_textfield.text = next(selected_presets)
    elseif s > 1 then
        pdata.gui.preset_textfield.text = ""
    end
end

function at_gui.create_main_window(player, pdata)
    local flags = pdata.flags
    pdata.selected = false
    local cols = constants.slot_columns
    local rows = constants.slot_rows
    local btns = player.character_logistic_slot_count
    local width = constants.slot_table_width
    local height = constants.slot_table_height
    width = (btns <= (rows*cols)) and width or (width + 12)
    local gui_data = gui.build(player.gui.screen,{
        {type = "frame", style = "outer_frame", handlers = "main.window", save_as = "main.window", children = {
            {type = "frame", style = "inner_frame_in_outer_frame", direction = "vertical", style_mods = {maximal_height = 656}, children = {
                {type = "flow", save_as = "main.titlebar.flow", children = {
                    {type = "label", style = "frame_title", caption = "Auto Trash", elem_mods = {ignored_by_interaction = true}},
                    {type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = {ignored_by_interaction = true}},
                    {template = "frame_action_button", sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black",
                        handlers = "main.close_button", save_as = "main.titlebar.close_button"}
                }},
                {type = "flow", direction = "horizontal", style_mods = {horizontal_spacing = 12}, children = {
                    {type = "frame", style = "inside_shallow_frame", direction = "vertical", children = {
                        {type = "frame", style = "subheader_frame", children={
                            {type = "label", style = "subheader_caption_label", caption = "Logistics configuration"},
                            {template = "pushers.horizontal"},
                            {type = "sprite-button", style = "tool_button_green", style_mods = {padding = 0},
                                sprite = "utility/check_mark_white", tooltip = {"module-inserter-config-button-apply"}},
                            {type = "sprite-button", style = "tool_button_red", sprite = "utility/reset_white"},
                            {type = "sprite-button", style = "tool_button", sprite = "utility/export_slot", tooltip = {"autotrash_export_tt"}},
                            {type = "sprite-button", style = "tool_button", sprite = "mi_import_string", tooltip = {"autotrash_import_tt"}}
                        }},
                        {type = "flow", direction="vertical", style_mods = {padding= 12, top_padding = 8, vertical_spacing = 10}, children = {
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style = "at_slot_table_scroll_pane", name = "config_rows", save_as = "main.config_rows",
                                    style_mods = {
                                        width = width,
                                        --height = height,
                                    },
                                    children = {
                                        gui.templates.slot_table.main(btns, pdata),
                                    }
                                }
                            }},
                            {type = "frame", style = "bordered_frame", style_mods = {right_padding = 8, horizontally_stretchable = "on"}, children = {
                                {type = "flow", direction = "vertical", children = {
                                    {type = "table", save_as = "sliders.table", style_mods = {minimal_height = 60}, column_count = 2, children = {
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption = {"auto-trash-request"}}
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", save_as = "sliders.request", minimum_value = 0, maximum_value = 42},
                                            {type = "textfield", save_as = "sliders.request_text", style = "slider_value_textfield"}
                                        }},
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption={"auto-trash-trash"}},
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", save_as = "sliders.trash", minimum_value = 0, maximum_value = 42},
                                            {type = "textfield", save_as = "sliders.trash_text", style = "slider_value_textfield"}
                                        }},
                                    }},
                                    {type = "drop-down", style = "at_quick_actions",
                                        items = constants.quick_actions,
                                        selected_index = 1,
                                        tooltip = {"autotrash_quick_actions_tt"}
                                    },
                                    {template = "pushers.horizontal"}
                                }}
                            }},
                            at_gui.templates.settings(flags, pdata),
                        }},

                    }},
                    {type = "frame", style = "inside_shallow_frame", direction = "vertical", children = {
                        {type = "frame", style = "subheader_frame", children={
                            {type = "label", style = "subheader_caption_label", caption = "Presets"},
                            {template = "pushers.horizontal"},
                            {type = "sprite-button", style = "tool_button", sprite = "utility/export_slot", tooltip = {"module-inserter-export_tt"}},
                            {type = "sprite-button", style = "tool_button", sprite = "mi_import_string", tooltip = {"module-inserter-import_tt"}},
                        }},
                        {type = "flow", direction="vertical", style_mods = {maximal_width = 274, padding= 12, top_padding = 8, vertical_spacing = 12}, children = {
                            {type = "flow", children = {
                                {type = "textfield", style = "at_save_as_textfield", save_as = "preset_textfield", text = ""},
                                {template = "pushers.horizontal"},
                                {type = "button", caption = {"gui-save-game.save"}, style = "at_save_button"}
                            }},
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style_mods = {extra_right_padding_when_activated = -4}, children = {
                                    {type = "flow", direction = "vertical", save_as = "presets_flow", style_mods = {left_padding = 4, top_padding = 8, width = 230}, children =
                                        gui.templates.presets(pdata),
                                    }
                                }}
                            }},
                        }}
                    }}
                }}
            }},
        }
    }})
    log(serpent.block(pdata.gui))
    gui_data.main.titlebar.flow.drag_target = gui_data.main.window
    gui_data.main.window.force_auto_center()
    gui_data.main.window.visible = false
    pdata.gui = gui_data
    at_gui.toggle_sliders(pdata, false)
end


function at_gui.init(player, pdata)
    at_gui.create_main_window(player, pdata)
end

function at_gui.destroy(player, pdata)
    local player_index = player.index
    gui.update_filters("main", player_index, nil, "remove")
    pdata.gui.main.window.destroy()
    if pdata.gui.import then
        if pdata.gui.import.window.main then
            pdata.gui.import.window.main.destroy()
        end
    end
    pdata.gui.main = nil
    pdata.gui.presets = nil
    pdata.gui_open = false
end

function at_gui.open(player, pdata)
    local window_frame = pdata.gui.main.window
    if window_frame and window_frame.valid then
        window_frame.visible = true
        pdata.flags.gui_open = true
    end
    --player.opened = pdata.gui.window
end

function at_gui.close(player, pdata)
    local window_frame = pdata.gui.main.window
    if window_frame and window_frame.valid then
        window_frame.visible = false
        pdata.flags.gui_open = false
    end
    --at_gui.destroy(player, pdata)
    --player.opened = nil
end

function at_gui.toggle(player, pdata)
    if pdata.flags.gui_open then
        at_gui.close(player, pdata)
    else
        at_gui.open(player, pdata)
    end
end
return at_gui