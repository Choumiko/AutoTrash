GUI = {
  mainFlow = "auto-trash-main-flow",
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
  if not player.gui.top[GUI.mainFlow] and
    (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research == "trash"
    or player.force.technologies["character-logistic-slots-1"].researched or after_research == "requests") then

    player.gui.top.add{
      type = "flow",
      name = GUI.mainFlow,
      direction = "horizontal"
    }
  end
  if player.gui.top[GUI.mainFlow] and not player.gui.top[GUI.mainFlow][GUI.logisticsButton] and
    (player.force.technologies["character-logistic-slots-1"].researched or after_research == "requests") then

    if player.gui.top[GUI.mainFlow][GUI.mainButton] then player.gui.top[GUI.mainFlow][GUI.mainButton].destroy() end
    player.gui.top[GUI.mainFlow].add{
      type = "button",
      name = GUI.logisticsButton,
      style = "auto-trash-logistics-button"
    }
  end

  if player.gui.top[GUI.mainFlow] and not player.gui.top[GUI.mainFlow][GUI.mainButton] and
    (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research == "trash") then

    player.gui.top[GUI.mainFlow].add{
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
  if player.gui.top[GUI.mainFlow] then
    player.gui.top[GUI.mainFlow].destroy()
  end
end

function gui_open_frame(player)
  local frame = player.gui.left[GUI.configFrame]
  local frame2 = player.gui.left[GUI.logisticsConfigFrame]
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if frame2 then
    frame2.destroy()
  end
  if storage_frame then
    storage_frame.destroy()
  end
  if frame then
    frame.destroy()
    global["config-tmp"][player.index] = nil
    if remote.interfaces.YARM and global.settings[player.index].YARM_old_expando then
      remote.call("YARM", "show_expando", player.index)
    end
    return
  end

  -- If player config does not exist, we need to create it.
  global["config"][player.index] = global["config"][player.index] or {}
  if global.active[player.index] == nil then global.active[player.index] = true end

  -- Temporary config lives as long as the frame is open, so it has to be created
  -- every time the frame is opened.
  global["config-tmp"][player.index] = {}
  local configSize = global.configSize[player.force.name] 
  -- We need to copy all items from normal config to temporary config.
  local i = 0
  for i = 1, configSize  do
    if i > #global["config"][player.index] then
      global["config-tmp"][player.index][i] = { name = "", count = 0 }
    else
      global["config-tmp"][player.index][i] = {
        name = global["config"][player.index][i].name,
        count = global["config"][player.index][i].count
      }
    end
  end
  if remote.interfaces.YARM then
    global.settings[player.index].YARM_old_expando = remote.call("YARM", "hide_expando", player.index)
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
  local colspan = configSize > 10 and 9 or 6
  colspan = configSize > 54 and 12 or colspan
  local ruleset_grid = frame.add{
    type = "table",
    colspan = colspan,
    name = "auto-trash-ruleset-grid"
  }
  local j = 1
  for i=1,colspan/3 do
    ruleset_grid.add{
      type = "label",
      name = "auto-trash-grid-header-"..j,
      caption = {"auto-trash-config-header-1"}
    }
    j = j+1
    ruleset_grid.add{
      type = "label",
      name = "auto-trash-grid-header-"..j,
      caption = {"auto-trash-config-header-2"}
    }
    j=j+1
    ruleset_grid.add{
      type = "label",
      caption = ""
    }
  end

  for i = 1, configSize do
    local style = global["config-tmp"][player.index][i].name or "style"
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

    local count = tonumber(global["config-tmp"][player.index][i].count)
    if global["config-tmp"][player.index][i].name ~= "" and count and count >= 0 then
      amount.text = count
    end
  end
  
  frame.add{
    type = "checkbox",
    name = "auto-trash-above-requested",
    caption = {"auto-trash-above-requested"},
    state = global.settings[player.index].auto_trash_above_requested
  }

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
  local caption = global.active[player.index] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"}
  button_grid.add{
    type = "button",
    name = "auto-trash-pause",
    caption = caption
  }
end

function gui_open_logistics_frame(player, redraw)
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
    if not redraw then
      global["logistics-config-tmp"][player.index] = nil
      if remote.interfaces.YARM and global.settings[player.index].YARM_old_expando then
        remote.call("YARM", "show_expando", player.index)
      end
      return
    end
  end

  -- If player config does not exist, we need to create it.
  global["logistics-config"][player.index] = global["logistics-config"][player.index] or {}
  if global["logistics-active"][player.index] == nil then global["logistics-active"][player.index] = true end

  -- Temporary config lives as long as the frame is open, so it has to be created
  -- every time the frame is opened.
  global["logistics-config-tmp"][player.index] = get_requests(player)

  if remote.interfaces.YARM then
    global.settings[player.index].YARM_old_expando = remote.call("YARM", "hide_expando", player.index)
  end

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
    local req = global["logistics-config-tmp"][player.index][i]
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

    local req = global["logistics-config-tmp"][player.index][i]
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
    name = "auto-trash-logistics-apply",
    caption = {"auto-trash-config-button-apply"}
  }
  button_grid.add{
    type = "button",
    name = "auto-trash-logistics-clear-all",
    caption = {"auto-trash-config-button-clear-all"}
  }
  local caption = global["logistics-active"][player.index] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"}
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

  if global["storage"][player.index] and global["storage"][player.index].store then
    local i = 1
    for key, _ in pairs(global["storage"][player.index].store) do
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
  local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]

  local key = player.gui.left[GUI.configFrame] and "" or "logistics-"

  if global[key.."config-tmp"][player.index] then
    local i = 0
    global[key.."config"][player.index] = {}
    local grid = frame["auto-trash-ruleset-grid"]
    for i, config in pairs(global[key.."config-tmp"][player.index]) do
      if global[key.."config-tmp"][player.index][i].name == "" then
        global[key.."config"][player.index][i] = { name = "", count = "" }
      else
        global[key.."config-tmp"][player.index][i].count = GUI.sanitizeNumber(grid["auto-trash-amount-"..i].text,0)
        local amount = global[key.."config-tmp"][player.index][i].count
        global[key.."config"][player.index][i] = {
          name = global[key.."config-tmp"][player.index][i].name,
          count = amount or 0
        }
      end
    end
    global[key.."config-tmp"][player.index] = nil
  end

  if key == "logistics-" then
    set_requests(player, global["logistics-config"][player.index])
    if not global["logistics-active"][player.index] then
      pause_requests(player)
    end
  end
  if remote.interfaces.YARM and global.settings[player.index].YARM_old_expando then
    remote.call("YARM", "show_expando", player.index)
  end
  --saveVar(global, "saved")
  if frame then
    frame.destroy()
  end
  if storage_frame then
    storage_frame.destroy()
  end
end

function gui_clear_all(player)
  local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  local key = player.gui.left[GUI.configFrame] and "" or "logistics-"

  if not frame then return end
  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  for i, c in pairs(global[key.."config-tmp"][player.index]) do
    global[key.."config-tmp"][player.index][i] = { name = "", count = {} }
    ruleset_grid["auto-trash-item-" .. i].style = "at-icon-style"
    ruleset_grid["auto-trash-amount-" .. i].text = ""
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
  local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
  local key = player.gui.left[GUI.configFrame] and "config-tmp" or "logistics-config-tmp"
  if not frame or not global[key][player.index] then return end

  local stack = player.cursor_stack
  if not stack.valid_for_read then
    stack = {type = "empty", name = ""}
    global[key][player.index][index].name = ""
  end

  local i = 0

  for i, _ in pairs(global[key][player.index]) do
    if stack.type ~= "empty" and index ~= i and global[key][player.index][i].name == stack.name then
      gui_display_message(frame, false, "auto-trash-item-already-set")
      return
    end
  end
  if not global[key][player.index][index] then
    global[key][player.index][index] = {name="", count=""}
  end
  if stack.type == "empty" or stack.name ~= global[key][player.index][index].name then
    global[key][player.index][index].count = ""
  end

  global[key][player.index][index].name = stack.name
  if stack.type ~= "empty" then
    if key == "logistics-config-tmp" then
      global[key][player.index][index].count = game.item_prototypes[stack.name].default_request_amount
    else
      global[key][player.index][index].count = 0
    end
  end

  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  local style = global[key][player.index][index].name ~= "" and "at-icon-"..global[key][player.index][index].name or "at-icon-style"
  ruleset_grid["auto-trash-" .. type1 .. "-" .. index].style = style
  ruleset_grid["auto-trash-" .. type1 .. "-" .. index].state = false
  ruleset_grid["auto-trash-amount" .. "-" .. index].text = global[key][player.index][index].count
end

function gui_store(player)
  global["storage"][player.index] = global["storage"][player.index] or {}
  global["storage"][player.index].store = global["storage"][player.index].store or {}
  local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
  if not storage_frame then return end
  local textfield = storage_frame["auto-trash-logistics-storage-buttons"]["auto-trash-logistics-storage-name"]
  local name = textfield.text
  name = string.match(name, "^%s*(.-)%s*$")

  if not name or name == "" then
    gui_display_message(storage_frame, true, "auto-trash-storage-name-not-set")
    return
  end
  if global["storage"][player.index].store[name] then
    gui_display_message(storage_frame, true, "auto-trash-storage-name-in-use")
    return
  end

  local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
  local index = count_keys(global["storage"][player.index]) + 1
  if index > MAX_STORAGE_SIZE then
    gui_display_message(storage_frame, true, "auto-trash-storage-too-long")
    return
  end
  local frame = player.gui.left[GUI.logisticsConfigFrame]
  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  global["storage"][player.index].store[name] = {}
  for i,c in pairs(global["logistics-config-tmp"][player.index]) do
    global["storage"][player.index].store[name][i] = {name = c.name, count = 0}
    global["storage"][player.index].store[name][i].count = tonumber(ruleset_grid["auto-trash-amount-" .. i].text) or 0
  end
  gui_display_message(storage_frame, true, "---")
  textfield.text = ""
  gui_open_logistics_frame(player,true)
  --  storage_grid.add{
  --    type = "label",
  --    caption = name .. "        ",
  --    name = "auto-trash-logistics-storage-entry-" .. index
  --  }
  --
  --  storage_grid.add{
  --    type = "button",
  --    caption = {"auto-trash-storage-restore"},
  --    name = "auto-trash-logistics-restore-" .. index,
  --    style = "auto-trash-small-button"
  --  }
  --
  --  storage_grid.add{
  --    type = "button",
  --    caption = {"auto-trash-storage-remove"},
  --    name = "auto-trash-logistics-remove-" .. index,
  --    style = "auto-trash-small-button"
  --  }

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
  if not global["storage"][player.index] or not global["storage"][player.index].store[name] then return end

  global["logistics-config-tmp"][player.index] = {}
  local ruleset_grid = frame["auto-trash-ruleset-grid"]
  local slots = player.force.character_logistic_slot_count
  for i = 1, slots do
    if global["storage"][player.index].store[name][i] then
      global["logistics-config-tmp"][player.index][i] = global["storage"][player.index].store[name][i]
    else
      global["logistics-config-tmp"][player.index][i] = {name = "", count = ""}
    end
    local style = global["logistics-config-tmp"][player.index][i].name ~= "" and "at-icon-"..global["logistics-config-tmp"][player.index][i].name or "at-icon-style"
    ruleset_grid["auto-trash-item-" .. i].style = style
    ruleset_grid["auto-trash-item-" .. i].state = false
    ruleset_grid["auto-trash-amount-" .. i].text = global["logistics-config-tmp"][player.index][i].count
  end
  gui_display_message(storage_frame, true, "---")
end

function gui_remove(player, index)
  if not global["storage"][player.index] then return end

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

  global["storage"][player.index].store[name] = nil
  gui_display_message(storage_frame, true, "---")
end
