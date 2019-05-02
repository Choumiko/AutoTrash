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
    parent = "logistic_button_slot",
}

styles["at_button_slot_selected"] = {
    type = "button_style",
    parent = "logistic_button_selected_slot",
}

styles["at_small_button"] = {
    type = "button_style",
    parent = "button",
}

styles["at_sprite_button"] = {
    type = "button_style",
    parent = "button",
    width = 36,
    height = 36,
    padding = 0
}

styles["at_preset_button"] = {
    type = "button_style",
    parent = "button",
}

local button = styles.button

styles["at_preset_button_selected"] = {--luacheck: ignore
    type = "button_style",
    parent = "at_preset_button",
    default_font_color = button.selected_font_color,
    default_graphical_set = button.selected_graphical_set,

    hovered_font_color = button.selected_hovered_font_color,
    hovered_graphical_set = button.selected_hovered_graphical_set,

    clicked_font_color = button.selected_clicked_font_color,
    clicked_vertical_offset = 1, -- text/icon goes down on click
    clicked_graphical_set = button.selected_clicked_graphical_set,

    -- selected_font_color = button_hovered_font_color,
    -- selected_graphical_set =

    -- selected_hovered_font_color = button_hovered_font_color,
    -- selected_hovered_graphical_set =

    -- selected_clicked_font_color = button_hovered_font_color,
    -- selected_clicked_graphical_set =

}


styles["at_extend_flow"] = {
    type = "vertical_flow_style",
    parent = "vertical_flow",
    left_padding = 0,
    right_padding = 0,
    top_padding = 0,
    bottom_padding = 0,
    vertical_spacing = 0
}

data:extend{{
    type = "sprite",
    name = "autotrash_trash",
    filename = "__AutoTrash__/graphics/gui2.png",
    width = 128,
    height = 128,
    x = 0,
    y = 0
}}

data:extend{{
    type = "sprite",
    name = "autotrash_trash_paused",
    filename = "__AutoTrash__/graphics/gui2.png",
    width = 128,
    height = 128,
    x = 128,
    y = 0
}}

data:extend{{
    type = "sprite",
    name = "autotrash_logistics",
    filename = "__AutoTrash__/graphics/gui2.png",
    width = 128,
    height = 128,
    x = 0,
    y = 128
}}

data:extend{{
    type = "sprite",
    name = "autotrash_logistics_paused",
    filename = "__AutoTrash__/graphics/gui2.png",
    width = 128,
    height = 128,
    x = 128,
    y = 128
}}

data:extend{
    {
        type = "custom-input",
        name = "autotrash_pause",
        key_sequence = "SHIFT + P",
        consuming = "none",
        localised_name = {"auto-trash-config-button-pause"}
    },
    {
        type = "custom-input",
        name = "autotrash_pause_requests",
        key_sequence = "SHIFT + O",
        consuming = "none",
        localised_name = {"auto-trash-config-button-pause-requests"}
    },
    {
        type = "custom-input",
        name = "autotrash_trash_cursor",
        key_sequence = "SHIFT + T",
        consuming = "none"
    },
}
