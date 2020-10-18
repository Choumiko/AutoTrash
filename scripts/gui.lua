local gui = require("__flib__.gui")
local constants = require("constants")


local at_gui = {}

at_gui.templates = {
    many_buttons = function(height, btns)
        local ret = {type = "table", column_count = constants.slot_columns, style = "at_filter_group_table", save_as = "foo", style_mods = {minimal_height = height}, children = {}}
        for i=1, btns do
            ret.children[i] = {type = "choose-elem-button", handlers = "slots.item_button", elem_type = "item", style = "at_button_slot"}
        end
        ret.children[btns+1] = {type = "flow", direction="vertical", style_mods = {vertical_spacing=0}, children={
            {type = "button", caption="-", handlers="slots.decrease", style = "slot_count_change_button"},
            {type = "button", caption="+", handlers = "slots.increase", style = "slot_count_change_button"}
        }}
        return ret
    end,
    frame_action_button = {type = "sprite-button", style = "frame_action_button", mouse_button_filter={"left"}},
    pushers = {
        horizontal = {type = "empty-widget", style_mods = {horizontally_stretchable = true}},
        vertical = {type = "empty-widget", style_mods = {vertically_stretchable = true}}
    },
    slot_table = function(btns, width, height)
        return (
                {type = "scroll-pane", style = "at_slot_table_scroll_pane", name = "config_rows", save_as = "main.config_rows",
                    style_mods = {width = width,
                        --height = height,
                        horizontally_stretchable = true,
                    },
                    children = {
                        gui.templates.many_buttons(height, btns),
                    },
            }
        )
    end,

    settings = function(flags, pdata)
        return {type = "frame", style = "deep_frame_in_shallow_frame", children = {
            {type = "flow", direction = "vertical", style_mods = {top_padding = 8, left_padding = 8}, children = {
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

    preset = function(preset_name)
        return {type = "flow", direction = "horizontal", name = preset_name, children = {
            {type = "button", style = "at_preset_button", caption = preset_name, name = preset_name},
            {type = "sprite-button", style = "at_preset_button_small", sprite = "autotrash_rip", tooltip = {"autotrash_tooltip_rip"}},
            {type = "sprite-button", style = "at_delete_preset", sprite = "utility/trash"},
        }}
    end
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

            end,
        },
        decrease = {
            on_gui_click = function (e)
                local player = game.get_player(e.player_index)
                local old_slots = player.character_logistic_slot_count
                local slots = old_slots > 9 and old_slots - 10 or old_slots
                at_gui.update_buttons(player, global._pdata[e.player_index], slots)
            end,
        },
        increase = {
            on_gui_click = function(e)
                local player = game.get_player(e.player_index)
                local old_slots = player.character_logistic_slot_count
                local slots = old_slots <= 65519 and old_slots + 10 or 65529
                at_gui.update_buttons(player, global._pdata[e.player_index], slots)
            end,
        },

    }
}
gui.add_handlers(at_gui.handlers)

at_gui.update_buttons = function(player, pdata, slots)
    player.character_logistic_slot_count = slots
    local rows = pdata.settings.slot_rows
    local cols = constants.slot_columns
    local width = (slots <= (rows*cols)) and cols*40 or (cols * 40 + 12)
    gui.update_filters("slots", player.index, nil, "remove")
    pdata.gui.main.config_rows.clear()
    pdata.gui.main.config_rows.style.width = width
    pdata.gui.main.config_rows.style.height = rows * 40
    gui.build(pdata.gui.main.config_rows, {gui.templates.many_buttons(rows*40, slots)})
    pdata.gui.main.config_rows.scroll_to_bottom()
end

function at_gui.create_main_window(player, pdata)
    local cols = constants.slot_columns
    local rows = pdata.settings.slot_rows
    local btns = player.character_logistic_slot_count
    local width = cols * 40
    local height = rows * 40
    width = (btns <= (rows*cols)) and width or (width + 12)
    local flags = pdata.flags
    local gui_data = gui.build(player.gui.screen,{
        {type = "frame", style = "outer_frame", handlers = "main.window", save_as = "main.window", style_mods = {maximal_height = 650}, children = {
            {type = "frame", style = "inner_frame_in_outer_frame", direction = "vertical", children = {
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
                            {type = "sprite-button", style = "tool_button_red", sprite = "utility/trash", tooltip = {"module-inserter-config-button-clear-all"}},
                        }},
                        {type = "flow", direction="vertical", style_mods = {padding= 12, top_padding = 8, vertical_spacing = 10}, children = {
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                gui.templates.slot_table(btns, width, height),
                            }},
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "flow", direction = "vertical", style_mods = {left_padding = 8, top_padding = 8}, children = {
                                    {type = "table", column_count = 2, children = {
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption = {"auto-trash-request"}}
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", minimum_value = 0, maximum_value = 42},
                                            {type = "textfield", style = "slider_value_textfield"}
                                        }},
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption={"auto-trash-trash"}},
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", minimum_value = 0, maximum_value = 42},
                                            {type = "textfield", style = "slider_value_textfield"}
                                        }},
                                    }},
                                    {type = "drop-down", style = "at_quick_actions",
                                        items = {
                                            [1] = {"autotrash_quick_actions"},
                                            [2] = {"autotrash_clear_requests"},
                                            [3] = {"autotrash_clear_trash"},
                                            [4] = {"autotrash_clear_both"},
                                            [5] = {"autotrash_trash_to_requests"},
                                            [6] = {"autotrash_requests_to_trash"}
                                        },
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
                            {type = "sprite-button", style = "tool_button", sprite = "mi_import_string", tooltip = {"module-inserter-import_tt"}},
                            {type = "sprite-button", style = "tool_button", sprite = "utility/export_slot", tooltip = {"module-inserter-export_tt"}},
                        }},
                        {type = "flow", direction="vertical", style_mods = {maximal_width = 274, padding= 12, top_padding = 8, vertical_spacing = 12}, children = {
                            {type = "flow", children = {
                                {type = "textfield", style = "at_save_as_textfield", text = ""},
                                {template = "pushers.horizontal"},
                                {type = "button", caption = {"gui-save-game.save"}, style = "at_save_button"}
                            }},
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style_mods = {extra_right_padding_when_activated = 0}, children = {
                                    {type = "flow", direction = "vertical", style_mods = {left_padding = 4, top_padding = 4, width = 230}, children = {
                                        gui.templates.preset("Test1"),
                                        gui.templates.preset("Test2"),
                                        gui.templates.preset("Test3"),
                                        gui.templates.preset("Test4"),
                                        gui.templates.preset("Test5"),
                                        gui.templates.preset("Test6"),
                                        gui.templates.preset("Test7"),
                                        gui.templates.preset("Test8"),
                                        gui.templates.preset("Test9"),
                                        gui.templates.preset("Test10"),
                                        gui.templates.preset("Test11"),
                                        -- gui.templates.preset("Test12"),
                                        -- gui.templates.preset("Test13"),
                                        {template = "pushers.horizontal"},
                                        {template = "pushers.vertical"}
                                    }}
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