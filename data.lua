-- data:extend{
--   {
--     type = "item-with-tags",
--     name = "cheesy_item",
--     icon = "__base__/graphics/icons/cut-paste-tool.png",
--     icon_size = 32,
--     flags = {"only-in-cursor", "hidden"},

--     stack_size = 1,
--     stackable = false,
--     can_be_mod_opened = false
--   }}

local styles = data.raw["gui-style"].default

local function yellowbuttongraphicalset()
    return
    {
        border = 1,
        filename = "__core__/graphics/gui.png",
        position = {111, 72},
        size = 36,
        scale = 1
    }
end

local function redbuttongraphicalset()
    return
    {
        border = 1,
        filename = "__core__/graphics/gui.png",
        position = {111, 36},
        size = 36,
        scale = 1
    }
end

local function bluebuttongraphicalset()
    return
    {
        border = 1,
        filename = "__core__/graphics/gui.png",
        position = {221, 36},
        size = 36,
        scale = 1
    }
end

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

local default = util.table.deepcopy(styles.slot_button)

styles["at_button_slot"] = {
    type = "button_style",
    parent = "logistic_button_slot",
    --default_graphical_set = default,
    --hovered_graphical_set = default,
    --clicked_graphical_set = default.clicked_graphical_set,
    --disabled_graphical_set = default,
    --selected_graphical_set = default.default_graphical_set,
    --selected_hovered_graphical_set = default,
    --selected_clicked_graphical_set = default.default_graphical_set,
}

styles["at_button_slot_selected"] = {
    type = "button_style",
    parent = "logistic_button_selected_slot",
    -- default_graphical_set = orangebuttongraphcialset(),--luacheck:ignore
    -- hovered_graphical_set = orangebuttongraphcialset(),--luacheck:ignore
    -- clicked_graphical_set = orangebuttongraphcialset(),--luacheck:ignore

    -- selected_graphical_set = default.selected_hovered_graphical_set,
    -- selected_hovered_graphical_set = default.selected_hovered_graphical_set,
    -- selected_clicked_graphical_set = orangebuttongraphcialset(),--luacheck:ignore
}

styles["at_button_slot_items_on_the_way"] = {
    type = "button_style",
    parent = "logistic_button_selected_slot",
    default_graphical_set = yellowbuttongraphicalset(),
}

styles["at_button_slot_items_not_available"] = {
    type = "button_style",
    parent = "logistic_button_selected_slot",
    default_graphical_set = redbuttongraphicalset(),
}

styles["at_button_slot_items_not_enough"] = {
    type = "button_style",
    parent = "logistic_button_selected_slot",
    default_graphical_set = bluebuttongraphicalset(),
}

styles["at_button_slot_locked"] = {
    type = "button_style",
    parent = "logistic_button_slot",
    --default_graphical_set = default.default_graphical_set,
    --hovered_graphical_set = default,
    clicked_graphical_set = default.selected_hovered_graphical_set,
    --disabled_graphical_set = default,
    selected_graphical_set = default.default_graphical_set, --did something good
    --selected_hovered_graphical_set = default.hovered_graphical_set,
    selected_clicked_graphical_set = default.selected_hovered_graphical_set,
}

styles["at_main_flow"] = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    padding = 0

}

styles["at_small_button"] = {
    type = "button_style",
    parent = "button",
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
}

styles["at_delete_preset"] = {
    type = "button_style",
    parent = "red_icon_button",
    padding = 0
}

styles["at_shortcut_bar_button"] = {
    type = "button_style",
    parent = "shortcut_bar_button",
    padding = 4
}

styles["at_shortcut_bar_button_green"] = {
    type = "button_style",
    parent = "shortcut_bar_button_green",
    padding = 4
}

styles["at_shortcut_bar_button_blue"] = {
    type = "button_style",
    parent = "shortcut_bar_button_blue",
    padding = 4
}

styles["at_preset_button_small"] = {
    type = "button_style",
    parent = "button",
    width = 28,
    height = 28,
    natural_width = 28,
    natural_height = 28,
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
    size = 128,
    position = {0, 0}
}}

data:extend{{
    type = "sprite",
    name = "autotrash_trash_paused",
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

}}

data:extend{{
    type = "sprite",
    name = "autotrash_requests_paused",
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
}}

data:extend{
    {
        type = "sprite",
        name = "autotrash_both_paused",
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
        size = 64,
    }
}

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