local data_util = require("__flib__.data-util")

local frame_action_icons = "__AutoTrash__/graphics/frame-action-icons.png"

data:extend{
    -- frame action icons
    data_util.build_sprite("at_pin_black", {0, 64}, frame_action_icons, 32),
    data_util.build_sprite("at_pin_white", {32, 64}, frame_action_icons, 32),
}

local styles = data.raw["gui-style"].default

styles["at_request_label_bottom"] = {
    type = "label_style",
    parent = "count_label",
    height = 36,
    width = 36,
    vertical_align = "bottom",
    horizontal_align = "right",
    right_padding = 2
}

styles["at_request_label_top"] = {
    type = "label_style",
    parent = "at_request_label_bottom",
    vertical_align = "top",
}

styles["at_button_slot"] = {
    type = "button_style",
    parent = "slot_button",
}

styles["at_main_flow"] = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    padding = 0

}

styles["at_save_button"] = {
    type = "button_style",
    parent = "button",
    width = 60
}

styles["at_sprite_button"] = {
    type = "button_style",
    parent = "mod_gui_button",
}

styles["at_preset_button"] = {
    type = "button_style",
    parent = "button",
}

local button = styles.button

styles["at_selected_tool_button"] = {
    type = "button_style",
    parent = "tool_button",
    default_font_color = button.selected_font_color,
    default_graphical_set = button.selected_graphical_set,

    hovered_font_color = button.selected_hovered_font_color,
    hovered_graphical_set = button.selected_hovered_graphical_set,

    clicked_font_color = button.selected_clicked_font_color,
    clicked_vertical_offset = 1, -- text/icon goes down on click
    clicked_graphical_set = button.selected_clicked_graphical_set,
}

styles["at_preset_button_selected"] = {
    type = "button_style",
    parent = "at_preset_button",
    default_font_color = button.selected_font_color,
    default_graphical_set = button.selected_graphical_set,

    hovered_font_color = button.selected_hovered_font_color,
    hovered_graphical_set = button.selected_hovered_graphical_set,

    clicked_font_color = button.selected_clicked_font_color,
    clicked_vertical_offset = 1, -- text/icon goes down on click
    clicked_graphical_set = button.selected_clicked_graphical_set,
}

styles["at_delete_preset"] = {
    type = "button_style",
    parent = "tool_button_red",
    padding = 0
}

styles["at_preset_button_small"] = {
    type = "button_style",
    parent = "button",
    width = 28,
    height = 28,
    -- natural_width = 28,
    -- natural_height = 28,
    padding = 0
}

styles["at_preset_button_small_selected"] = {
    type = "button_style",
    parent = "at_preset_button_small",
    default_font_color = button.selected_font_color,
    default_graphical_set = button.selected_graphical_set,

    hovered_font_color = button.selected_hovered_font_color,
    hovered_graphical_set = button.selected_hovered_graphical_set,

    clicked_font_color = button.selected_clicked_font_color,
    clicked_vertical_offset = 1, -- text/icon goes down on click
    clicked_graphical_set = button.selected_clicked_graphical_set,
}

styles["at_request_status_table"] = {
    type = "table_style",
    horizontal_spacing = 1,
    vertical_spacing = 1
}

styles["at_preset_button"] = {
    type = "button_style",
    width = 150
}

styles["at_save_as_textfield"] = {
    type = "textbox_style",
    horizontally_stretchable = "on",
    width = 150
}

styles["at_quick_actions"] = {
    type = "dropdown_style",
    minimal_width = 216
}

styles["at_slider_flow"] = {
    type = "horizontal_flow_style",
    vertical_align = "center"
}

styles.at_slot_table_scroll_pane = {
    type = "scroll_pane_style",
    parent = "flib_naked_scroll_pane",
    padding = 0,
    margin = 0,
    extra_padding_when_activated = 0,
    horizontally_squashable = "off",
}

styles.at_filter_group_table = {
    type = "table_style",
    horizontal_spacing = 0,
    vertical_spacing = 0,
    padding = 0,
    background_graphical_set =
    {
        position = {282, 17},
        corner_size = 8,
        overall_tiling_horizontal_padding = 4,
        overall_tiling_horizontal_size = 32,
        overall_tiling_horizontal_spacing = 8,
        overall_tiling_vertical_padding = 4,
        overall_tiling_vertical_size = 32,
        overall_tiling_vertical_spacing = 8
    }
}

data:extend{
    {
        type = "sprite",
        name = "at_import_string",
        filename = "__base__/graphics/icons/shortcut-toolbar/mip/import-string-x24.png",
        priority = "extra-high-no-scale",
        size = 24,
        scale = 0.5,
        mipmap_count = 2,
        flags = {"gui-icon"}
    }
}

data:extend{
    {
        type = "sprite",
        name = "autotrash_trash",
        filename = "__AutoTrash__/graphics/gui2.png",
        flags = {"icon"},
        size = 128,
        position = {0, 0}
    },
    {
        type = "sprite",
        name = "autotrash_trash_paused",
        flags = {"icon"},
        layers = {
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {0, 0}
            },
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {128, 0}
            }
        }
    },
    {
        type = "sprite",
        name = "autotrash_requests_paused",
        flags = {"icon"},
        layers = {
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {0, 0}
            },
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {0, 128}
            }
        }
    },
    {
        type = "sprite",
        name = "autotrash_both_paused",
        flags = {"icon"},
        layers = {
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {0, 0}
            },
            {
                filename = "__AutoTrash__/graphics/gui2.png",
                size = 128,
                position = {128, 128}
            }
        }
    },
    {
        type = "sprite",
        name = "autotrash_rip",
        filename = "__AutoTrash__/graphics/rip.png",
        flags = {"icon"},
        size = 64,
    }
}

data:extend{
    {
        type = "custom-input",
        name = "autotrash_pause",
        key_sequence = "SHIFT + P",
        consuming = "none",
    },
    {
        type = "custom-input",
        name = "autotrash_pause_requests",
        key_sequence = "SHIFT + O",
        consuming = "none",
    },
    {
        type = "custom-input",
        name = "autotrash_trash_cursor",
        key_sequence = "SHIFT + T",
        consuming = "none"
    },
}