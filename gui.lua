GUI = {
  mainButton = "auto-trash-config-button",
  logisticsButton = "auto-trash-logistics-button",
  configFrame = "auto-trash-config-frame",
  logisticsConfigFrame = "auto-trash-logistics-config-frame",
  logisticsStorageFrame = "auto-trash-logistics-storage-frame",
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
  if not global.guiVersion[player.name] then global.guiVersion[player.name] = "0.0.0" end
  if not player.gui.top[GUI.mainButton]
    and (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research) then
    player.gui.top.add{
      type = "button",
      name = GUI.logisticsButton,
      style = "auto-trash-logistics-button"
    }
    player.gui.top.add{
      type = "button",
      name = GUI.mainButton,
      style = "auto-trash-button"
    }
  end
end

function gui_destroy(player)
  if player.gui.top[GUI.mainButton] then
    player.gui.top[GUI.mainButton].destroy()
  end
  if player.gui.top[GUI.logisticsButton] then
    player.gui.top[GUI.logisticsButton].destroy()
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
  for i = 1, global.configSize[player.force.name] do
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
  local colspan = global.configSize[player.force.name] > 10 and 9 or 6
  local ruleset_grid = frame.add{
    type = "table",
    colspan = colspan,
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
  ruleset_grid.add{
    type = "label",
    caption = ""
  }
  if colspan == 9 then
    ruleset_grid.add{
      type = "label",
      name = "auto-trash-grid-header-5",
      caption = {"auto-trash-config-header-1"}
    }
    ruleset_grid.add{
      type = "label",
      name = "auto-trash-grid-header-6",
      caption = {"auto-trash-config-header-2"}
    }
    ruleset_grid.add{
      type = "label",
      caption = ""
    }
  end

  for i = 1, global.configSize[player.force.name] do
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
    ruleset_grid.add{
      type = "label",
      caption = ""
    }

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

function gui_open_logistics_frame(player)
  local frame = player.gui.left[GUI.logisticsConfigFrame]
  local frame2 = player.gui.left[GUI.configFrame]
  
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if frame2 then
    frame2.destroy()
  end
  if frame then
    frame.destroy()
    if storage_frame then
      storage_frame.destroy()
    end
    global["logistics-config-tmp"][player.name] = nil
    return
  end

  -- If player config does not exist, we need to create it.
  global["logistics-config"][player.name] = global["logistics-config"][player.name] or {}
  if global["logistics-active"][player.name] == nil then global["logistics-active"][player.name] = true end

  -- Temporary config lives as long as the frame is open, so it has to be created
  -- every time the frame is opened.
  global["logistics-config-tmp"][player.name] = get_requests(player)

  -- We need to copy all items from normal config to temporary config.
  --  local i = 0
  --  for i = 1, global.configSize[player.force.name] do
  --    if i > #global["logistics-config"][player.name] then
  --      global["logistics-config-tmp"][player.name][i] = { name = "", count = 0 }
  --    else
  --      global["logistics-config-tmp"][player.name][i] = {
  --        name = global["logistics-config"][player.name][i].name,
  --        count = global["logistics-config"][player.name][i].count
  --      }
  --    end
  --  end

  -- Now we can build the GUI.
  frame = player.gui.left.add{
    type = "frame",
    caption = {"auto-trash-logistics-config-frame-title"},
    name = GUI.logisticsConfigFrame,
    direction = "vertical"
  }
  local error_label = frame.add{
    type = "label",
    caption = "---",
    name = "auto-trash-error-label"
  }
  error_label.style.minimal_width = 200
  local slots = player.force.character_logistic_slot_count
  local colspan = 15
  local ruleset_grid = frame.add{
    type = "table",
    colspan = colspan,
    name = "auto-trash-ruleset-grid",
  }

  for i = 1, slots do
    local req = global["logistics-config-tmp"][player.name][i]
    local style = req and req.name or "style"
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
    ruleset_grid.add{
      type = "label",
      caption = ""
    }
    
    local req = global["logistics-config-tmp"][player.name][i]
    local count = req and tonumber(req.count) or ""
    if req and req.name ~= "" and count and count >= 0 then
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
  local caption = global["logistics-active"][player.name] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"}
  button_grid.add{
    type = "button",
    name = "auto-trash-logistics-pause",
    caption = caption
  }
  
  storage_frame = player.gui.left.add{
    type = "frame",
    name = GUI.logisticsStorageFrame,
    caption = {"auto-trash-storage-frame-title"},
    direction = "vertical"
  }
  local storage_frame_error_label = storage_frame.add{
    type = "label",
    name = "auto-trash-logistics-storage-error-label",
    caption = "---"
  }
  storage_frame_error_label.style.minimal_width = 200
  local storage_frame_buttons = storage_frame.add{
    type = "table",
    colspan = 3,
    name = "auto-trash-logistics-storage-buttons"
  }
  storage_frame_buttons.add{
    type = "label",
    caption = {"auto-trash-storage-name-label"},
    name = "auto-trash-logistics-storage-name-label"
  }
  storage_frame_buttons.add{
    type = "textfield",
    text = "",
    name = "auto-trash-logistics-storage-name"
  }
  storage_frame_buttons.add{
    type = "button",
    caption = {"auto-trash-storage-store"},
    name = "auto-trash-logistics-storage-store",
    style = "auto-trash-small-button"
  }
  local storage_grid = storage_frame.add{
    type = "table",
    colspan = 3,
    name = "auto-trash-logistics-storage-grid"
  }

  if global["storage"][player.name] and global["storage"][player.name].store then
    local i = 1
    for key, _ in pairs(global["storage"][player.name].store) do
      storage_grid.add{
        type = "label",
        caption = key .. "        ",
        name = "auto-trash-logistics-storage-entry-" .. i
      }
      storage_grid.add{
        type = "button",
        caption = {"auto-trash-storage-restore"},
        name = "auto-trash-logistics-restore-" .. i,
        style = "auto-trash-small-button"
      }
      storage_grid.add{
        type = "button",
        caption = {"auto-trash-storage-remove"},
        name = "auto-trash-logistics-remove-" .. i,
        style = "auto-trash-small-button"
      }
      i = i + 1
    end
  end
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
  for i = 1, global.configSize[player.force.name] do
    global["config-tmp"][player.name][i] = { name = "", count = {} }
    ruleset_grid["auto-trash-item-" .. i].style = "at-icon-style"
  end
end

function gui_display_message(frame, storage, message)
  local label_name = "auto-trash-"
  if storage then label_name = label_name .. "logistics-storage-" end
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
end

function gui_store(player)
  global["storage"][player.name] = global["storage"][player.name] or {}
  global["storage"][player.name].store = global["storage"][player.name].store or {}
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if not storage_frame then return end
  local textfield = storage_frame["auto-trash-logistics-storage-buttons"]["auto-trash-logistics-storage-name"]
  local name = textfield.text
  name = string.match(name, "^%s*(.-)%s*$")

  if not name or name == "" then
    gui_display_message(storage_frame, true, "auto-trash-storage-name-not-set")
    return
  end
  if global["storage"][player.name].store[name] then
    gui_display_message(storage_frame, true, "auto-trash-storage-name-in-use")
    return
  end

  global["storage"][player.name].store[name] = {}
  local i = 0
  for i = 1, #global["logistics-config-tmp"][player.name] do
    global["storage"][player.name].store[name][i] = util.table.deepcopy(global["logistics-config-tmp"][player.name][i])
  end

  local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
  local index = count_keys(global["storage"][player.name]) + 1
  if index > MAX_STORAGE_SIZE + 1 then
    gui_display_message(storage_frame, true, "auto-trash-storage-too-long")
    return
  end

  storage_grid.add{
    type = "label",
    caption = name .. "        ",
    name = "auto-trash-logistics-storage-entry-" .. index
  }

  storage_grid.add{
    type = "button",
    caption = {"auto-trash-storage-restore"},
    name = "auto-trash-logistics-restore-" .. index,
    style = "auto-trash-small-button"
  }

  storage_grid.add{
    type = "button",
    caption = {"auto-trash-storage-remove"},
    name = "auto-trash-logistics-remove-" .. index,
    style = "auto-trash-small-button"
  }
  gui_display_message(storage_frame, true, "---")
  textfield.text = ""
  --saveVar(global, "stored")
end

function gui_restore(player, index)
  local frame = player.gui.left[GUI.logisticsConfigFrame]
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if not frame or not storage_frame then return end

  local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
  local storage_entry = storage_grid["auto-trash-logistics-storage-entry-" .. index]
  if not storage_entry then return end

  local name = string.match(storage_entry.caption, "^%s*(.-)%s*$")
  if not global["storage"][player.name] or not global["storage"][player.name][name] then return end

  global["logistics-config-tmp"][player.name] = {}
  local i = 0
  local ruleset_grid = frame["auto-trash-logistics-ruleset-grid"]
  local slots = player.force.character_logistic_slot_count
  for i = 1, slots do
    if i <= #global["storage"][player.name][name].store then
      global["logistics-config-tmp"][player.name][i] = global["storage"][player.name].store[name][i]
    end
    local style = global["logistics-config-tmp"][player.name][i].name ~= "" and "at-icon-"..global["logistics-config-tmp"][player.name][i].name or "at-icon-style"
    ruleset_grid["auto-trash-logistics-from-" .. i].style = style
    ruleset_grid["auto-trash-logistics-from-" .. i].state = false

  end
  gui_display_message(storage_frame, true, "---")
end

function gui_remove(player, index)
  if not global["storage"][player.name] then return end

  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if not storage_frame then return end
  local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
  local label = storage_grid["auto-trash-logistics-storage-entry-" .. index]
  local btn1 = storage_grid["auto-trash-logistics-restore-" .. index]
  local btn2 = storage_grid["auto-trash-logistics-remove-" .. index]

  if not label or not btn1 or not btn2 then return end

  local name = string.match(label.caption, "^%s*(.-)%s*$")
  label.destroy()
  btn1.destroy()
  btn2.destroy()

  global["storage"][player.name].store[name] = nil
  gui_display_message(storage_frame, true, "---")
end
