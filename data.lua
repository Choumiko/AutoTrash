require "lib"

data.raw["gui-style"].default["auto-trash-small-button"] = {
    type = "button_style",
    parent = "button",
}

data.raw["gui-style"].default["auto-trash-textfield-small"] =
    {
        type = "textbox_style",
        left_padding = 3,
        right_padding = 2,
        minimal_width = 30,
    }

data.raw["gui-style"].default["auto-trash-table"] =
    {
        type = "table_style",
        parent = "table",
    }

data.raw["gui-style"].default["auto-trash-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 33,
        height = 33,
        top_padding = 6,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
    }

data.raw["gui-style"].default["auto-trash-sprite-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 32,
        height = 32,
        top_padding = 0,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
        sprite = {
            filename = "__core__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 32,
            height = 32,
            x = 111,
        },
    }


data.raw["gui-style"].default["auto-trash-button-paused"] =
    {
        type = "button_style",
        parent = "button",
        width = 33,
        height = 33,
        top_padding = 6,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
    }

data.raw["gui-style"].default["auto-trash-logistics-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 33,
        height = 33,
        top_padding = 6,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
    }

data.raw["gui-style"].default["auto-trash-logistics-button-paused"] =
    {
        type = "button_style",
        parent = "button",
        width = 33,
        height = 33,
        top_padding = 6,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
    }

data.raw["gui-style"].default["auto-trash-expand-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 16,
        height = 16,
    }

data:extend({
    {
        type = "custom-input",
        name = "autotrash_pause",
        key_sequence = "SHIFT + p",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = "autotrash_pause_requests",
        key_sequence = "SHIFT + o",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = "autotrash_trash_cursor",
        key_sequence = "SHIFT + t",
        consuming = "none"
    },
})
