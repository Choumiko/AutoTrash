local function count_keys(hashmap)
    local result = 0
    for _, _ in pairs(hashmap) do
        result = result + 1
    end
    return result
end

local function get_requests(player)
    local requests = {}
    -- get requested items
    if player.character and player.force.character_logistic_slot_count > 0 then
        for c=1,player.force.character_logistic_slot_count do
            requests[c] = player.character.get_request_slot(c)
        end
    end
    return requests
end

local function set_requests(player)
    local index = player.index
    if not global["logistics-config"][index] then
        global["logistics-config"][index] = {}
    end
    local storage = global["logistics-config"][index]
    local slots = player.force.character_logistic_slot_count
    if player.character and slots > 0 then
        for c=1, slots do
            if storage[c] and storage[c].name ~= "" then
                player.character.set_request_slot(storage[c], c)
            else
                player.character.clear_request_slot(c)
            end
        end
    end
end

local GUI = {
    mainFlow = "auto-trash-main-flow",
    mainButton = "auto-trash-config-button",
    optionsBar = "auto-trash-options-bar",
    expandButton = "auto-trash-expand-button",
    trash_above_requested = "auto-trash-above-requested",
    trash_unrequested = "auto-trash-unrequested",
    trash_in_main_network = "auto-trash-in-main-network",
    logisticsButton = "auto-trash-logistics-button",
    configFrame = "auto-trash-config-frame",
    logisticsConfigFrame = "auto-trash-logistics-config-frame",
    logisticsStorageFrame = "auto-trash-logistics-storage-frame",
    sanitizeName = function(name_)
        local name = string.gsub(name_, "_", " ")
        name = string.gsub(name, "^%s", "")
        name = string.gsub(name, "%s$", "")
        local pattern = "(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)"
        local element = "activeLine__"..name.."__".."something"
        local t1, t2, t3, _ = element:match(pattern)
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

function GUI.init(player, after_research)
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

    if player.gui.top[GUI.mainFlow] and (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research == "trash") then
        if not player.gui.top[GUI.mainFlow][GUI.mainButton] then
            player.gui.top[GUI.mainFlow].add{
                type = "button",
                name = GUI.mainButton,
                style = "auto-trash-button"
            }
        end
        if not player.gui.top[GUI.mainFlow][GUI.expandButton] then
            player.gui.top[GUI.mainFlow].add{
                type = "button",
                name = GUI.expandButton,
                style = "auto-trash-expand-button"
            }
        end
    end

    --  if player.gui.top[GUI.mainFlow] and (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research == "trash") then
    --    local bar = player.gui.top[GUI.mainFlow][GUI.optionsBar]
    --    if not bar then
    --      player.gui.top[GUI.mainFlow].add{
    --        type = "flow",
    --        name = GUI.optionsBar,
    --        direction = "vertical"
    --      }
    --    end

    --  end
end

local function get_settings_group(player)
    local bar = player.gui.top[GUI.mainFlow][GUI.optionsBar]
    local other = player.gui.left[GUI.configFrame]
    local result = {}
    if bar then
        table.insert(result, bar)
    end
    if other then
        table.insert(result, other)
    end
    return result
end

function GUI.update_settings(player)
    local groups = get_settings_group(player)
    local index = player.index
    for _, group in pairs(groups) do
        group[GUI.trash_unrequested].state = global.settings[index].auto_trash_unrequested
        group[GUI.trash_above_requested].state = global.settings[index].auto_trash_above_requested
        group[GUI.trash_in_main_network].state = global.settings[index].auto_trash_in_main_network
    end
end

function GUI.toggle_settings(player)
    local bar = player.gui.top[GUI.mainFlow][GUI.optionsBar]

    global.settings[player.index].options_extended = not global.settings[player.index].options_extended
    local show = global.settings[player.index].options_extended
    if show then

        if not bar then
            bar = player.gui.top[GUI.mainFlow].add{
                type = "flow",
                name = GUI.optionsBar,
                direction = "vertical"
            }
        end
        if not bar[GUI.trash_above_requested] then
            bar.add{
                type = "checkbox",
                name = GUI.trash_above_requested,
                caption = {"auto-trash-above-requested"},
                state = global.settings[player.index].auto_trash_above_requested
            }
        end
        if not bar[GUI.trash_unrequested] then
            bar.add{
                type = "checkbox",
                name = GUI.trash_unrequested,
                caption = {"auto-trash-unrequested"},
                state = global.settings[player.index].auto_trash_unrequested,
            }
        end
        if not bar[GUI.trash_in_main_network] then
            bar.add{
                type = "checkbox",
                name = GUI.trash_in_main_network,
                caption = {"auto-trash-in-main-network"},
                state = global.settings[player.index].auto_trash_in_main_network,
            }
        end
    else
        if bar then bar.destroy() end
    end
end

function GUI.destroy(player)
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

function GUI.open_frame(player)
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
        name = GUI.configFrame,
        direction = "vertical"
    }

    local error_label = frame.add{
        type = "label",
        caption = "---",
        name = "auto-trash-error-label"
    }
    error_label.style.minimal_width = 200
    local column_count = configSize > 10 and 9 or 6
    column_count = configSize > 54 and 12 or column_count

    local pane = frame.add{
        type = "scroll-pane",
    }
    pane.style.maximal_height = math.ceil(40*10)
    pane.can_scroll_horizontally = false

    local ruleset_grid = pane.add{
        type = "table",
        column_count = column_count,
        name = "auto-trash-ruleset-grid"
    }
    local j = 1
    for _=1,column_count/3 do
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
        style = style == "" and style or "item/" .. style
        ruleset_grid.add{
            type = "sprite-button",
            name = "auto-trash-item-" .. i,
            sprite = style,
            style = "auto-trash-sprite-button"
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
        name = GUI.trash_above_requested,
        caption = {"auto-trash-above-requested"},
        state = global.settings[player.index].auto_trash_above_requested
    }

    frame.add{
        type = "checkbox",
        name = GUI.trash_unrequested,
        caption = {"auto-trash-unrequested"},
        state = global.settings[player.index].auto_trash_unrequested,
    }

    frame.add{
        type = "checkbox",
        name = GUI.trash_in_main_network,
        caption = {"auto-trash-in-main-network"},
        state = global.settings[player.index].auto_trash_in_main_network,
    }

    local caption = global.mainNetwork[player.index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
    frame.add{
        type = "button",
        name = "auto-trash-set-main-network",
        caption = caption
    }

    local button_grid = frame.add{
        type = "table",
        column_count = 3,
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
    caption = global.active[player.index] and {"auto-trash-config-button-pause"} or {"auto-trash-config-button-unpause"}
    button_grid.add{
        type = "button",
        name = "auto-trash-pause",
        caption = caption,
        tooltip = {"auto-trash-tooltip-pause"}
    }

    return {ruleset_grid = ruleset_grid}
end

function GUI.open_logistics_frame(player, redraw)
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
    local column_count = 15
    local ruleset_grid = frame.add{
        type = "table",
        column_count = column_count,
        name = "auto-trash-ruleset-grid",
    }

    for i = 1, slots do
        local req = global["logistics-config-tmp"][player.index][i]
        local style = req and "item/" .. req.name or ""

        ruleset_grid.add{
            type = "sprite-button",
            name = "auto-trash-item-" .. i,
            sprite = style,
            style = "auto-trash-sprite-button"
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

        local count = req and tonumber(req.count) or ""
        if req and req.name ~= "" and count and count >= 0 then
            amount.text = count
        end
    end

    local button_grid = frame.add{
        type = "table",
        column_count = 3,
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
        caption = caption,
        tooltip = {"auto-trash-tooltip-pause-requests"}
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
        column_count = 3,
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
        column_count = 3,
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
    return {ruleset_grid = ruleset_grid}
end

function GUI.close(player)
    local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
    local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
    if frame then
        frame.destroy()
    end
    if storage_frame then
        storage_frame.destroy()
    end
    global.guiData[player.index] = nil
end

function GUI.save_changes(player)
    -- Saving changes consists in:
    --   1. copying config-tmp to config
    --   2. removing config-tmp
    --   3. closing the frame

    local key = player.gui.left[GUI.configFrame] and "" or "logistics-"

    if global[key.."config-tmp"][player.index] then
        global[key.."config"][player.index] = {}
        local grid = global.guiData[player.index].ruleset_grid
        for i, _ in pairs(global[key.."config-tmp"][player.index]) do
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
    GUI.close(player)
end

function GUI.clear_all(player)
    local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
    --local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
    local key = player.gui.left[GUI.configFrame] and "" or "logistics-"

    if not frame then return end
    local ruleset_grid = global.guiData[player.index].ruleset_grid
    for i, _ in pairs(global[key.."config-tmp"][player.index]) do
        global[key.."config-tmp"][player.index][i] = { name = "", count = {} }
        ruleset_grid["auto-trash-item-" .. i].sprite = ""
        ruleset_grid["auto-trash-amount-" .. i].text = ""
    end
end

function GUI.display_message(frame, storage, message)
    if not frame then return end
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

function GUI.set_item(player, type1, index)
    local frame = player.gui.left[GUI.configFrame] or player.gui.left[GUI.logisticsConfigFrame]
    local key = player.gui.left[GUI.configFrame] and "config-tmp" or "logistics-config-tmp"
    if not frame or not global[key][player.index] then return end

    if not global[key][player.index][index] then
        global[key][player.index][index] = {name="", count=""}
    end

    local stack = player.cursor_stack
    if not stack.valid_for_read then
        stack = {type = "empty", name = ""}
        global[key][player.index][index].name = ""
    end

    for i, _ in pairs(global[key][player.index]) do
        if stack.type ~= "empty" and index ~= i and global[key][player.index][i].name == stack.name then
            GUI.display_message(frame, false, "auto-trash-item-already-set")
            return
        end
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

    local ruleset_grid = global.guiData[player.index].ruleset_grid
    local style = global[key][player.index][index].name ~= "" and "item/"..global[key][player.index][index].name or ""
    ruleset_grid["auto-trash-" .. type1 .. "-" .. index].sprite = style
    ruleset_grid["auto-trash-amount" .. "-" .. index].text = global[key][player.index][index].count
end

function GUI.store(player)
    global["storage"][player.index] = global["storage"][player.index] or {}
    global["storage"][player.index].store = global["storage"][player.index].store or {}
    local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
    if not storage_frame then return end
    local textfield = storage_frame["auto-trash-logistics-storage-buttons"]["auto-trash-logistics-storage-name"]
    local name = textfield.text
    name = string.match(name, "^%s*(.-)%s*$")

    if not name or name == "" then
        GUI.display_message(storage_frame, true, "auto-trash-storage-name-not-set")
        return
    end
    if global["storage"][player.index].store[name] then
        GUI.display_message(storage_frame, true, "auto-trash-storage-name-in-use")
        return
    end

    --local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
    local index = count_keys(global["storage"][player.index]) + 1
    if index > MAX_STORAGE_SIZE then
        GUI.display_message(storage_frame, true, "auto-trash-storage-too-long")
        return
    end

    local ruleset_grid = global.guiData[player.index].ruleset_grid
    global["storage"][player.index].store[name] = {}
    for i,c in pairs(global["logistics-config-tmp"][player.index]) do
        global["storage"][player.index].store[name][i] = {name = c.name, count = 0}
        global["storage"][player.index].store[name][i].count = tonumber(ruleset_grid["auto-trash-amount-" .. i].text) or 0
    end
    GUI.display_message(storage_frame, true, "---")
    textfield.text = ""
    global.guiData[player.index] = GUI.open_logistics_frame(player,true)
end

function GUI.restore(player, index)
    local frame = player.gui.left[GUI.logisticsConfigFrame]
    local storage_frame = player.gui.left[GUI.logisticsStorageFrame]
    if not frame or not storage_frame then return end

    local storage_grid = storage_frame["auto-trash-logistics-storage-grid"]
    local storage_entry = storage_grid["auto-trash-logistics-storage-entry-" .. index]
    if not storage_entry then return end

    local name = string.match(storage_entry.caption, "^%s*(.-)%s*$")
    if not global["storage"][player.index] or not global["storage"][player.index].store[name] then return end

    global["logistics-config-tmp"][player.index] = {}
    local ruleset_grid = global.guiData[player.index].ruleset_grid
    local slots = player.force.character_logistic_slot_count
    for i = 1, slots do
        if global["storage"][player.index].store[name][i] then
            global["logistics-config-tmp"][player.index][i] = {name=global["storage"][player.index].store[name][i].name, count = global["storage"][player.index].store[name][i].count}
        else
            global["logistics-config-tmp"][player.index][i] = {name = "", count = ""}
        end
        local style = global["logistics-config-tmp"][player.index][i].name ~= "" and "item/"..global["logistics-config-tmp"][player.index][i].name or ""
        ruleset_grid["auto-trash-item-" .. i].sprite = style
        ruleset_grid["auto-trash-amount-" .. i].text = global["logistics-config-tmp"][player.index][i].count
    end
    GUI.display_message(storage_frame, true, "---")
end

function GUI.remove(player, index)
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
    GUI.display_message(storage_frame, true, "---")
end

return GUI
