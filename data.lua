local data_util = require("__flib__.data-util")
require("prototypes.styles")

local tint = {r=255, g=240, b=0}

data:extend{
    data_util.build_sprite("autotrash_selection", nil, data_util.planner_base_image, 64, 4, {tint=tint})
}

data:extend {
    {
        type = "selection-tool",
        name = "autotrash-network-selection",
        icons = {{icon=data_util.planner_base_image, icon_size=64, icon_mipmaps=4, tint=tint}},
        stack_size = 1,
        flags = {"hidden", "only-in-cursor", "not-stackable", "draw-logistic-overlay"},
        draw_label_for_cursor_render = true,
        selection_color = { r = 0, g = 1, b = 0 },
        alt_selection_color = { r = 0, g = 0, b = 1 },
        selection_mode = {"blueprint"},
        alt_selection_mode = {"blueprint"},
        selection_cursor_box_type = "copy",
        alt_selection_cursor_box_type = "copy",
        entity_type_filters = {"roboport"},
        alt_entity_type_filters = {"roboport"},
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