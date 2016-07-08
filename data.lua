require "lib"

data:extend({
  {
    type = "font",
    name = "auto-trash-small-font",
    from = "default",
    size = 14
  }
})

data.raw["gui-style"].default["auto-trash-small-button"] = {
  type = "button_style",
  parent = "button_style",
  font = "auto-trash-small-font"
}

data.raw["gui-style"].default["auto-trash-textfield-small"] =
  {
    type = "textfield_style",
    left_padding = 3,
    right_padding = 2,
    minimal_width = 30,
    font = "auto-trash-small-font"
  }

data.raw["gui-style"].default["auto-trash-table"] =
  {
    type = "table_style",
    parent = "table_style",
  }

data.raw["gui-style"].default["auto-trash-button"] =
  {
    type = "button_style",
    parent = "button_style",
    width = 33,
    height = 33,
    top_padding = 6,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    font = "auto-trash-small-font",
    default_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 64
      }
    },
    hovered_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 96
      }
    },
    clicked_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        width = 32,
        height = 32,
        x = 96
      }
    }
  }

data.raw["gui-style"].default["auto-trash-sprite-button"] =
  {
    type = "button_style",
    parent = "button_style",
    width = 32,
    height = 32,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    font = "auto-trash-small-font",
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
    parent = "button_style",
    width = 33,
    height = 33,
    top_padding = 6,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    font = "auto-trash-small-font",
    default_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 128
      }
    },
    hovered_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 160
      }
    },
    clicked_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        width = 32,
        height = 32,
        x = 160
      }
    }
  }

data.raw["gui-style"].default["auto-trash-logistics-button"] =
  {
    type = "button_style",
    parent = "button_style",
    width = 33,
    height = 33,
    top_padding = 6,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    font = "auto-trash-small-font",
    default_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 64,
        y = 32
      }
    },
    hovered_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 96,
        y = 32
      }
    },
    clicked_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        width = 32,
        height = 32,
        x = 96,
        y = 32
      }
    }
  }

data.raw["gui-style"].default["auto-trash-logistics-button-paused"] =
  {
    type = "button_style",
    parent = "button_style",
    width = 33,
    height = 33,
    top_padding = 6,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    font = "auto-trash-small-font",
    default_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 128,
        y = 32
      }
    },
    hovered_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32,
        x = 160,
        y = 32
      }
    },
    clicked_graphical_set =
    {
      type = "monolith",
      monolith_image =
      {
        filename = "__AutoTrash__/graphics/gui.png",
        width = 32,
        height = 32,
        x = 160,
        y = 32
      }
    }
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
  }
})
