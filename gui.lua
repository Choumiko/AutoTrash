local MAX_STORAGE_SIZE = 6
local pause_requests = require '__AutoTrash__.lib_control'.pause_requests
local format_number = require '__AutoTrash__.lib_control'.format_number
local mod_gui = require '__core__/lualib/mod-gui'
local function count_keys(hashmap)
    local result = 0
    for _, _ in pairs(hashmap) do
        result = result + 1
    end
    return result
end

local function get_requests(player) --luacheck: ignore
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
    local storage = global.config_new[player.index].config
    local slots = player.force.character_logistic_slot_count
    if player.character and slots > 0 then
        local req
        for c=1, slots do
            req = storage[c]
            if req then
                player.character.set_request_slot({name = req.name, count = req.request or 0}, c)
            else
                player.character.clear_request_slot(c)
            end
        end
    end
end

local function show_yarm(index)
    if remote.interfaces.YARM and global.settings[index].YARM_old_expando then
        remote.call("YARM", "show_expando", index)
    end
end

local function hide_yarm(index)
    if remote.interfaces.YARM then
        global.settings[index].YARM_old_expando = remote.call("YARM", "hide_expando", index)
    end
end

local GUI = {
    mainFlow = "auto-trash-main-flow",
    mainButton = "auto-trash-config-button",
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
        local logistics_button = player.gui.top[GUI.mainFlow].add{
            type = "sprite-button",
            name = GUI.logisticsButton,
            style = "auto-trash-sprite-button"
        }
        logistics_button.sprite = "autotrash_logistics"
    end

    if player.gui.top[GUI.mainFlow] and (player.force.technologies["character-logistic-trash-slots-1"].researched or after_research == "trash") then
        if not player.gui.top[GUI.mainFlow][GUI.mainButton] then
            local trash_button = player.gui.top[GUI.mainFlow].add{
                type = "sprite-button",
                name = GUI.mainButton,
                style = "auto-trash-sprite-button"
            }
            trash_button.sprite = "autotrash_trash"
        end
    end
end

local function get_settings_group(player)
    local left = mod_gui.get_frame_flow(player)
    local other = left[GUI.configFrame]
    local result = {}
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

--only for moving to mod_gui frame
function GUI.destroy_frames(player)
    local left = player.gui.left
    local frame = left[GUI.configFrame]
    local frame2 = left[GUI.logisticsConfigFrame]
    local storage_frame = left[GUI.logisticsStorageFrame]
    if frame2 then
        frame2.destroy()
    end
    if storage_frame then
        storage_frame.destroy()
    end
    if frame then
        frame.destroy()
    end
end

function GUI.open_frame(player)
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.configFrame]
    local frame2 = left[GUI.logisticsConfigFrame]
    local storage_frame = left[GUI.logisticsStorageFrame]
    if frame2 then
        frame2.destroy()
    end
    if storage_frame then
        storage_frame.destroy()
    end
    if frame then
        frame.destroy()
        global["config-tmp"][player.index] = nil
        show_yarm(player.index)
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
            global["config-tmp"][player.index][i] = { name = false, count = 0 }
        else
            global["config-tmp"][player.index][i] = {
                name = global["config"][player.index][i].name,
                count = global["config"][player.index][i].count
            }
        end
    end

    hide_yarm(player.index)

    -- Now we can build the GUI.
    frame = left.add{
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
    pane.style.maximal_height = math.ceil(44*10)

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

    local choose_button
    for i = 1, configSize do
        local req = global["config-tmp"][player.index][i]
        local elem_value = req and req.name or nil

        --log(serpent.block(req))
        choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = "auto-trash-item-" .. i,
            style = "slot_button",
            elem_type = "item"
        }
        choose_button.elem_value = elem_value

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
        if global["config-tmp"][player.index][i].name and count and count >= 0 then
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

function GUI.update_sliders(player_index, visible)
    local player = game.get_player(player_index)
    local left = mod_gui.get_frame_flow(player)["at-config-frame"]
    if left and left["at-slider-flow-vertical"] then
        for _, child in pairs(left["at-slider-flow-vertical"].children) do
            child.visible = visible
        end
    end
end

function GUI.open_logistics_frame(player, redraw)
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.logisticsConfigFrame]
    local frame2 = left[GUI.configFrame]
    local frame_new = left["at-config-frame"]

    local storage_frame = left[GUI.logisticsStorageFrame]
    if frame2 then
        frame2.destroy()
    end
    if frame_new then
        frame_new.destroy()
        if storage_frame then
            storage_frame.destroy()
        end
        if not redraw then
            global.selected[player.index] = false
            show_yarm(player.index)
            return
        end
    end
    if frame then
        frame.destroy()
        if storage_frame then
            storage_frame.destroy()
        end
        if not redraw then
            global["logistics-config-tmp"][player.index] = nil
            show_yarm(player.index)
            return
        end
    end
    log("Selected: " .. serpent.line(global.selected[player.index]))
    frame_new = left.add{
        type = "frame",
        caption = {"auto-trash-logistics-config-frame-title"},
        name = "at-config-frame",
        direction = "vertical"
    }

    local scroll_pane = frame_new.add{
        type = "scroll-pane",
        name = "at-config-scroll",
        --vertical_scroll_policy = "auto-and-reserve-space"
    }
    scroll_pane.style.maximal_height = math.ceil(38*10+4)

    local slots = 60
    --slots = player.force.character_logistic_slot_count
    local column_count = 6
    local ruleset_grid = scroll_pane.add{
        type = "table",
        column_count = column_count,
        name = "at-ruleset-grid",
        style = "slot_table"
    }

    local item_config

    for i = 1, slots do
        local req = global["config_tmp"][player.index].config[i]
        local elem_value = req and req.name or nil
        local button_name = "auto-trash-item-" .. i
        local choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = button_name,
            style = "logistic_button_slot",
            elem_type = "item"
        }
        choose_button.elem_value = elem_value
        if global.selected[player.index] == button_name then
            choose_button.style = "logistic_button_selected_slot"
            item_config = global["config_tmp"][player.index].config[i]
        end

        local lbl_top = choose_button.add{
            type = "label",
            style = "auto-trash-request-label-top",
            ignored_by_interaction = true,
            caption = ""
        }

        local lbl_bottom = choose_button.add{
            type = "label",
            style = "auto-trash-request-label-bottom",
            ignored_by_interaction = true,
            caption = ""
        }

        if elem_value then
            lbl_top.caption = (req.request) and format_number(req.request, true) or (req.trash and "0") or ""
            lbl_bottom.caption = (req.trash and req.trash > -1) and format_number(req.trash, true) or "∞"
            choose_button.locked = choose_button.name ~= global.selected[player.index] --disable popup gui, keeps on_click active
        end
    end
    local slider_vertical_flow = frame_new.add{
        type = "table",
        name = "at-slider-flow-vertical",
        column_count = 2
    }
    slider_vertical_flow.style.minimal_height = 60
    local lbl_request = slider_vertical_flow.add{
        type = "label",
        caption = "Request"
    }
    local slider_flow_request = slider_vertical_flow.add{
        type = "flow",
        name = "at-slider-flow-request",
        direction = "horizontal",
    }
    slider_flow_request.style.vertical_align = "center"

    slider_flow_request.add{
        type = "slider",
        name = "at-config-slider",
        minimum_value = 0,
        maximum_value = 50000,
        value = item_config and tonumber((item_config.request) and item_config.request or (item_config.trash and 0) or -1) or 50
    }
    slider_flow_request.add{
        type = "textfield",
        name = "at-config-slider-text",
        style = "slider_value_textfield",
        text = item_config and tonumber((item_config.request) and item_config.request or (item_config.trash and 0) or -1) or 50
    }

    local lbl_trash = slider_vertical_flow.add{
        type = "label",
        caption = "Trash"
    }
    local slider_flow_trash = slider_vertical_flow.add{
        type = "flow",
        name = "at-slider-flow-trash",
        direction = "horizontal",
    }
    slider_flow_trash.style.vertical_align = "center"

    slider_flow_trash.add{
        type = "slider",
        name = "at-config-slider",
        minimum_value = -1,
        maximum_value = 50000,
        value = item_config and tonumber(item_config.trash and item_config.trash or -1) or -1
    }
    slider_flow_trash.add{
        type = "textfield",
        name = "at-config-slider-text",
        style = "slider_value_textfield",
        text = item_config and tonumber(item_config.trash and item_config.trash or -1) or -1
    }

    if not global.selected[player.index] then
        lbl_request.visible = false
        lbl_trash.visible = false
        slider_flow_request.visible = false
        slider_flow_trash.visible = false
    end

    local button_grid = frame_new.add{
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




    storage_frame = left.add{
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
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.configFrame] or left[GUI.logisticsConfigFrame]
    local storage_frame = left[GUI.logisticsStorageFrame]
    local frame_new = left["at-config-frame"]
    if frame then
        frame.destroy()
    end
    if storage_frame then
        storage_frame.destroy()
    end
    if frame_new then
        frame_new.destroy()
    end
end

function GUI.save_changes(player)
    -- Saving changes consists in:
    --   1. copying config-tmp to config <- that's bull, just get it from the gui <- not bull now, i only have 2 textfields
    --   2. removing config-tmp
    --   3. closing the frame
    local player_index = player.index

    global.config_new[player_index] = util.table.deepcopy(global.config_tmp[player_index])
    set_requests(player, global["logistics-config"][player_index])
    if not global["logistics-active"][player_index] then
        pause_requests(player)
    end

    show_yarm(player_index)
    GUI.close(player)
end

function GUI.clear_all(player)
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.configFrame] or left[GUI.logisticsConfigFrame]
    --local storage_frame = left[GUI.logisticsStorageFrame]
    local key = left[GUI.configFrame] and "" or "logistics-"

    if not frame then return end
    local ruleset_grid = global.guiData[player.index].ruleset_grid
    for i, _ in pairs(global[key.."config-tmp"][player.index]) do
        global[key.."config-tmp"][player.index][i] = { name = false, count = 0 }
        ruleset_grid["auto-trash-item-" .. i].elem_value = nil
        ruleset_grid["auto-trash-amount-" .. i].text = "0"
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

function GUI.set_item(player, index, element)
    local left = mod_gui.get_frame_flow(player)
    local frame = left["at-config-frame"]
    --local key = left[GUI.configFrame] and "config-tmp" or "logistics-config-tmp"
    local player_index = player.index
    if not frame or not index then
        return
    end

    local elem_value = element.elem_value
    if elem_value then
        for i, item in pairs(global.config_tmp[player_index].config) do
            if index ~= i and item.name == elem_value then
                -- GUI.display_message(frame, false, "auto-trash-item-already-set")
                player.print({"auto-trash-item-already-set"})
                element.elem_value = nil
                return i
            end
        end
    end
    global["config_tmp"][player_index].config[index] = {name = elem_value, request = game.item_prototypes[elem_value].default_request_amount, trash = false}
    return true
end

function GUI.store(player)
    global["storage"][player.index] = global["storage"][player.index] or {}
    global["storage"][player.index].store = global["storage"][player.index].store or {}
    local left = mod_gui.get_frame_flow(player)
    local storage_frame = left[GUI.logisticsStorageFrame]
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
    local left = mod_gui.get_frame_flow(player)
    local frame = left[GUI.logisticsConfigFrame]
    local storage_frame = left[GUI.logisticsStorageFrame]
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
            global["logistics-config-tmp"][player.index][i] = {name = false, count = 0}
        end
        local style = global["logistics-config-tmp"][player.index][i].name or nil
        ruleset_grid["auto-trash-item-" .. i].elem_value = style
        ruleset_grid["auto-trash-amount-" .. i].text = global["logistics-config-tmp"][player.index][i].count
    end
    GUI.display_message(storage_frame, true, "---")
end

function GUI.remove(player, index)
    if not global["storage"][player.index] then return end
    local left = mod_gui.get_frame_flow(player)
    local storage_frame = left[GUI.logisticsStorageFrame]
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
