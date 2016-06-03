require "lib"

for t, _ in pairs(data.raw) do
  for _, ent in pairs(data.raw[t]) do
    if ent.stack_size then
      local prototype = ent
      local style =
        {
          type = "checkbox_style",
          parent = "at-icon-style",
          default_background =
          {
            filename = prototype.icon,
            width = 32,
            height = 32,
            scale = 1.75
          },
          hovered_background =
          {
            filename = prototype.icon,
            width = 32,
            height = 32,
            scale = 1.75
          },
          checked_background =
          {
            filename = prototype.icon,
            width = 32,
            height = 32,
            scale = 1.75
          },
          clicked_background =
          {
            filename = prototype.icon,
            width = 32,
            height = 32,
            scale = 1.75
          }
        }
      data.raw["gui-style"].default["at-icon-"..prototype.name] = style
    end
  end
end

data.raw["gui-style"].default["at-icon-style"] =
  {
    type = "checkbox_style",
    parent = "checkbox_style",
    width = 32,
    height = 32,
    bottom_padding = 8,
    default_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111,
      scale = 1.75
    },
    hovered_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111,
      scale = 1.75
    },
    clicked_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111,
      scale = 1.75
    },
    checked =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111,
      scale = 1.75
    }
  }
