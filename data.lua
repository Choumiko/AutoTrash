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

data.raw["gui-style"].default["auto-trash-sprite-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 36,
        height = 36,
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

data.raw["gui-style"].default["auto-trash-button"] =
    {
        type = "button_style",
        parent = "auto-trash-sprite-button",
    }

data.raw["gui-style"].default["auto-trash-button-paused"] =
    {
        type = "button_style",
        parent = "auto-trash-sprite-button",
    }

data.raw["gui-style"].default["auto-trash-logistics-button"] =
    {
        type = "button_style",
        parent = "auto-trash-sprite-button",
    }

data.raw["gui-style"].default["auto-trash-logistics-button-paused"] =
    {
        type = "button_style",
        parent = "auto-trash-sprite-button",
    }

data.raw["gui-style"].default["auto-trash-expand-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 16,
        height = 16,
        padding = 0
    }

data:extend({
    {
      type="sprite",
      name="autotrash_trash",
      filename = "__AutoTrash__/graphics/gui2.png",
      width = 128,
      height = 128,
      x = 0,
      y = 0
}})

data:extend({
    {
      type="sprite",
      name="autotrash_trash_paused",
      filename = "__AutoTrash__/graphics/gui2.png",
      width = 128,
      height = 128,
      x = 128,
      y = 0
}})

data:extend({
    {
      type="sprite",
      name="autotrash_logistics",
      filename = "__AutoTrash__/graphics/gui2.png",
      width = 128,
      height = 128,
      x = 0,
      y = 128
}})

data:extend({
    {
      type="sprite",
      name="autotrash_logistics_paused",
      filename = "__AutoTrash__/graphics/gui2.png",
      width = 128,
      height = 128,
      x = 128,
      y = 128
}})

data:extend({
    {
      type="sprite",
      name="autotrash_expand",
      filename = "__core__/graphics/side-menu-icons.png",
      width = 64,
      height = 64,
      x = 0,
      y = 384
}})

data:extend({
    {
        type = "custom-input",
        name = "autotrash_pause",
        key_sequence = "SHIFT + P",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = "autotrash_pause_requests",
        key_sequence = "SHIFT + O",
        consuming = "none"
    },
    {
        type = "custom-input",
        name = "autotrash_trash_cursor",
        key_sequence = "SHIFT + T",
        consuming = "none"
    },
})
