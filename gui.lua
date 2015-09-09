GUI = {
  mainButton = "auto-trash-config-button",
  configFrame = "auto-trash-config-frame",
  sanitizeName = function(name)
    local name = string.gsub(name, "_", " ")
    name = string.gsub(name, "^%s", "")
    name = string.gsub(name, "%s$", "")
    local pattern = "(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)"
    local element = "activeLine__"..name.."__".."something"
    local t1,t2,t3,t4 = element:match(pattern)
    if t1 == "activeLine" and t2 == name and t3 == "something" then
      return name
    else
      return false
    end
  end,

  sanitizeNumber = function(number, default)
    return tonumber(number) or default
  end
}

function gui_init(player, after_research)
  if not player.gui.top[GUI.mainButton]
    and (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research) then
    player.gui.top.add{
      type = "button",
      name = GUI.mainButton,
      style = "auto-trash-button"
    }
  end
end

function gui_open_frame(player)
  local frame = player.gui.left[GUI.configFrame]

  if frame then
    frame.destroy()
    global["config-tmp"][player.name] = nil
    return
  end

  -- If player config does not exist, we need to create it.
  global["config"][player.name] = global["config"][player.name] or {}
  if global.active[player.name] == nil then global.active[player.name] = true end

  -- Temporary config lives as long as the frame is open, so it has to be created
  -- every time the frame is opened.
  global["config-tmp"][player.name] = {}

  -- We need to copy all items from normal config to temporary config.
  local i = 0
  for i = 1, MAX_CONFIG_SIZE do
    if i > #global["config"][player.name] then
      global["config-tmp"][player.name][i] = { name = "", count = 0 }
    else
      global["config-tmp"][player.name][i] = {
        name = global["config"][player.name][i].name,
        count = global["config"][player.name][i].count
      }
    end
  end

  -- Now we can build the GUI.
  frame = player.gui.left.add{
    type = "frame",
    caption = {"auto-trash-config-frame-title"},
    name = "auto-trash-config-frame",
    direction = "vertical"
  }
  local error_label = frame.add{
    type = "label",
    caption = "---",
    name = "auto-trash-error-label"
  }
  error_label.style.minimal_width = 200
  local ruleset_grid = frame.add{
    type = "table",
    colspan = 5,
    name = "auto-trash-ruleset-grid"
  }
  ruleset_grid.add{
    type = "label",
    name = "auto-trash-grid-header-1",
    caption = {"auto-trash-config-header-1"}
  }
  ruleset_grid.add{
    type = "label",
    name = "auto-trash-grid-header-2",
    caption = {"auto-trash-config-header-2"}
  }

  ruleset_grid.add{
    type = "label",
    caption = ""
  }

  ruleset_grid.add{
    type = "label",
    name = "auto-trash-grid-header-3",
    caption = {"auto-trash-config-header-1"}
  }
  ruleset_grid.add{
    type = "label",
    name = "auto-trash-grid-header-4",
    caption = {"auto-trash-config-header-2"}
  }

  for i = 1, MAX_CONFIG_SIZE do
    local style = global["config-tmp"][player.name][i].name or "style"
    style = style == "" and "style" or style
    ruleset_grid.add{
      type = "checkbox",
      name = "auto-trash-item-" .. i,
      style = "at-icon-" ..style,
      state = false
    }

    local amount = ruleset_grid.add{
      type = "textfield",
      name = "auto-trash-amount-" .. i,
      style = "auto-trash-textfield-small",
      text = ""
    }
    if i%2 == 1 then
      ruleset_grid.add{
        type = "label",
        caption = ""
      }
    end
    local count = tonumber(global["config-tmp"][player.name][i].count)
    if global["config-tmp"][player.name][i].name ~= "" and count and count >= 0 then
      amount.text = count
    end
  end

  local button_grid = frame.add{
    type = "table",
    colspan = 3,
    name = "auto-trash-button-grid"
  }
  button_grid.add{
    type = "button",
    name = "auto-trash-apply",
    caption = {"auto-trash-config-button-apply"}
  }
  button_grid.add{
    type = "button",
    name = "auto-trash-clear-all",
    caption = {"auto-trash-config-button-clear-all"}
  }
  local caption = global.active[player.name] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"} 
  button_grid.add{
    type = "button",
    name = "auto-trash-pause",
    caption = caption
  }
end

function gui_save_changes(player)
  -- Saving changes consists in:
  --   1. copying config-tmp to config
  --   2. removing config-tmp
  --   3. closing the frame

  if global["config-tmp"][player.name] then
    local i = 0
    global["config"][player.name] = {}
    local grid = player.gui.left[GUI.configFrame]["auto-trash-ruleset-grid"]
    for i = 1, #global["config-tmp"][player.name] do
      if global["config-tmp"][player.name][i].name == "" then
        global["config"][player.name][i] = { name = "", count = "" }
      else
      global["config-tmp"][player.name][i].count = GUI.sanitizeNumber(grid["auto-trash-amount-"..i].text,0)
      local amount = global["config-tmp"][player.name][i].count
        global["config"][player.name][i] = {
          name = global["config-tmp"][player.name][i].name,
          count = amount or 0
        }
      end
    end
    global["config-tmp"][player.name] = nil
  end
  saveVar(global, "saved")
  local frame = player.gui.left["auto-trash-config-frame"]
  if frame then
    frame.destroy()
  end
end

function gui_clear_all(player)
  local i = 0
  local frame = player.gui.left["auto-trash-config-frame"]
  if not frame then return end
  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  for i = 1, MAX_CONFIG_SIZE do
    global["config-tmp"][player.name][i] = { name = "", count = {} }
    ruleset_grid["auto-trash-item-" .. i].style = "at-icon-style"
  end
end

function gui_display_message(frame, storage, message)
  local label_name = "auto-trash-"
  if storage then label_name = label_name .. "storage-" end
  label_name = label_name .. "error-label"

  local error_label = frame[label_name]
  if not error_label then return end

  if message ~= "---" then
    message = {message}
  end
  error_label.caption = message
end

function gui_set_item(player, type1, index)
  local frame = player.gui.left["auto-trash-config-frame"]
  if not frame or not global["config-tmp"][player.name] then return end

  local stack = player.cursor_stack
  if not stack.valid_for_read then
    stack = {type = "empty", name = ""}
    global["config-tmp"][player.name][index].name = ""
  end

  local i = 0

  for i = 1, #global["config-tmp"][player.name] do
    if stack.type ~= "empty" and index ~= i and global["config-tmp"][player.name][i].name == stack.name then
      gui_display_message(frame, false, "auto-trash-item-already-set")
      return
    end
  end

  if stack.type == "empty" or stack.name ~= global["config-tmp"][player.name][index].name then
    global["config-tmp"][player.name][index].count = ""
  end
  
  global["config-tmp"][player.name][index].name = stack.name
  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  local style = global["config-tmp"][player.name][index].name ~= "" and "at-icon-"..global["config-tmp"][player.name][index].name or "at-icon-style"
  ruleset_grid["auto-trash-" .. type1 .. "-" .. index].style = style
  ruleset_grid["auto-trash-" .. type1 .. "-" .. index].state = false
end

function gui_set_modules(player, index, slot)
  local frame = player.gui.left["auto-trash-config-frame"]
  if not frame or not global["config-tmp"][player.name] then return end

  local stack = player.cursor_stack
  if not stack.valid_for_read then
    --gui_display_message(frame, false, "auto-trash-item-empty")
    stack = {type = "empty", name = ""}
  end
  if global["config-tmp"][player.name][index].from == "" then
    gui_display_message(frame, false, "auto-trash-item-no-entity")
    return
  end

  local type1 = "to"
  local config = global["config-tmp"][player.name][index]
  local modules = type(config[type1]) == "table" and config[type1] or {}
  local maxSlots = nameToSlots[config.from]
  if stack.type == "module" then
    if game.entity_prototypes[config.from].type == "beacon" and game.item_prototypes[stack.name].module_effects and game.item_prototypes[stack.name].module_effects["productivity"] then
      if game.item_prototypes[stack.name].module_effects["productivity"] ~= 0 then
        gui_display_message(frame,false,"auto-trash-no-productivity-beacon")
        return
      end
    end
    modules[slot] = stack.name
  elseif stack.type == "empty" then
    modules[slot] = false
  else
    gui_display_message(frame,false,"auto-trash-item-no-module")
    return
  end
  --debugDump(modules,true)
  global["config-tmp"][player.name][index][type1] = modules
  gui_update_modules(player, index)
end

function gui_update_modules(player, index)
  local frame = player.gui.left["auto-trash-config-frame"]
  local slots = nameToSlots[global["config-tmp"][player.name][index].from] or 1
  local modules = global["config-tmp"][player.name][index].to
  local flow = frame["auto-trash-ruleset-grid"]["auto-trash-slotflow-" .. index]
  for i=#flow.children_names,1,-1 do
    flow[flow.children_names[i]].destroy()
  end
  for i=1,slots do
    local style = modules[i] and "at-icon-" .. modules[i] or "at-icon-style"
    if flow["auto-trash-to-" .. index .. "-" .. i] then
      flow["auto-trash-to-" .. index .. "-" .. i].style = style
      flow["auto-trash-to-" .. index .. "-" .. i].state = false
    else
      flow.add{
        type = "checkbox",
        name = "auto-trash-to-" .. index .. "-" .. i,
        style = style,
        state = false
      }
    end
  end
end