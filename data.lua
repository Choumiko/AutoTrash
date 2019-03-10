data.raw["gui-style"].default["auto-trash-small-button"] = {
    type = "button_style",
    parent = "button",
}

data.raw["gui-style"].default["auto-trash-textfield-small"] =
    {
        type = "textbox_style",
        width = 40,
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
        padding = 0
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
