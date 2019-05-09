local lib_control = require '__AutoTrash__.lib_control'
local saveVar = lib_control.saveVar --luacheck: ignore
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_to_slider = lib_control.convert_to_slider
local set_trash = lib_control.set_trash
local set_requests = lib_control.set_requests
local get_requests = lib_control.get_requests
local mod_gui = require '__core__/lualib/mod-gui'

local function combine_from_vanilla(player)
    if not player.character then return end
    local tmp = {config = {}}
    local requests, max_slot = get_requests(player)
    local trash = player.auto_trash_filters
    log(serpent.block(trash))

    for name, config in pairs(requests) do
        config.trash = false
        tmp.config[config.slot] = config
        if trash[name] then
            config.trash = trash[name] > config.request and trash[name] or config.request
            trash[name] = nil
        end
    end
    local no_slot = {}
    for name, count in pairs(trash) do
        no_slot[#no_slot+1] = {
            name = name,
            request = 0,
            trash = count,
            slot = false
        }
    end
    local start = 1
    max_slot = max_slot or 0
    for _, s in pairs(no_slot) do
        for i = start, max_slot + #no_slot do
            if not tmp.config[i] then
                s.slot = i
                tmp.config[i] = s
                start = i + 1
                break
            end
        end
    end
    saveVar(tmp, "combined")
    log(serpent.block(tmp))
    return tmp
end

local function show_yarm(index)
    if remote.interfaces.YARM then
        remote.call("YARM", "set_filter", index, global.settings[index].YARM_active_filter)
    end
end

local function hide_yarm(index)
    if remote.interfaces.YARM then
        global.settings[index].YARM_active_filter = remote.call("YARM", "set_filter", index, "none")
    end
end

local GUI = {--luacheck: allow defined top
    defines = {
        main_button = "at_config_button",
        main_button_flow = "autotrash_main_flow",
        quick_presets = "at_quick_presets",

        trash_above_requested = "autotrash_above_requested",
        trash_unrequested = "autotrash_unrequested",
        trash_in_main_network = "autotrash_in_main_network",
        pause_trash = "autotrash_pause_trash",
        pause_requests = "autotrash_pause_requests",

        config_request = "at_config_request",
        config_trash = "at_config_trash",
        config_slider = "at_config_slider",
        config_slider_text = "at_config_slider_text",

        load_preset = "autotrash_preset_load_",
        delete_preset = "autotrash_preset_delete_"
    },
}

local def = GUI.defines

local gui_functions = {
    main_button = function(event, player)
        local element = event.element
        local player_index = event.player_index
        if event.button == defines.mouse_button_type.right then
            GUI.open_quick_presets(player_index, element.parent)
        else
            GUI.close_quick_presets(player_index, element.parent)
            if player.cursor_stack.valid_for_read then--luacheck: ignore
                -- if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
                --     add_order(player)
                -- elseif player.cursor_stack.name ~= "blueprint" then
                --     add_to_trash(player, player.cursor_stack.name)
                -- end
            else
                if global.gui_elements.config_frame[event.player_index] then
                    GUI.close(player)
                else
                    GUI.open_logistics_frame(player)
                end
            end
        end
        return
    end,

    apply_changes = function(event, player)
        local player_index = event.player_index
        global.config_new[player_index] = util.table.deepcopy(global.config_tmp[player_index])
        global.dirty[player_index] = false
        global.gui_elements.reset_button[player_index].enabled = false
        if player.mod_settings["autotrash_close_on_apply"].value then
            GUI.close(player)
        end

        if not global.settings[player_index].pause_trash then
            set_trash(player)
        end
        if not global.settings[player_index].pause_requests then
            set_requests(player)
        end
    end,

    reset_changes = function(event, _)
        local player_index = event.player_index
        if global.dirty[player_index] then
            global.config_tmp[player_index] = util.table.deepcopy(global.config_new[player_index])
            event.element.enabled = false
            global.selected[player_index] = false
            global.selected_presets[player_index] = {}
            global.dirty[player_index] = false
            GUI.update_buttons(player_index)
            GUI.update_sliders(player_index)
            GUI.update_presets(player_index)
        end
    end,

    clear_config = function(event, _)
        local player_index = event.player_index
        local mode = global.settings[player_index].clear_option
        local config_tmp = global.config_tmp[player_index]
        if mode == 1 then
            config_tmp.config = {}
            global.selected[player_index] = false
        elseif mode == 2 then
            for _, config in pairs(config_tmp.config) do
                config.request = 0
            end
        elseif mode == 3 then
            for _, config in pairs(config_tmp.config) do
                config.trash = false
            end
        end
        global.dirty[player_index] = true
        GUI.update_buttons(player_index)
        GUI.update_sliders(player_index)
    end,

    clear_option_changed = function(event, _, _)
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        global.settings[event.player_index].clear_option = event.element.selected_index
    end,

    load_quick_preset = function(event, player, params)--luacheck: ignore
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        local player_index = event.player_index
        local name = event.element.get_item(event.element.selected_index)
        if global.storage_new[player_index][name] then
            global.selected_presets[player_index] = {[name] = true}
            global.config_new[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
            global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
            global.selected[player_index] = false
            global.dirty[player_index] = false
            if not global.settings[player_index].pause_trash then
                set_trash(player)
            end
            if not global.settings[player_index].pause_requests then
                set_requests(player)
            end
            display_message(player, "Preset '" .. tostring(name) .. "' loaded", "success")
            GUI.update_presets(player_index)
            GUI.create_buttons(player)
            GUI.update_sliders(player_index)
        else
            display_message(player, "Unknown preset: " .. tostring(name), true)
        end
        GUI.deregister_action(event.element)
        event.element.destroy()
    end,

    save_preset = function(event, player, params)
        local player_index = event.player_index
        local name = params.textfield.text
        if name == "" then
            display_message(player, {"auto-trash-storage-name-not-set"}, true)
            params.textfield.focus()
            return
        end
        if global.storage_new[player_index][name] then
            display_message(player, {"auto-trash-storage-name-in-use"}, true)
            --TODO create confirmation window to overwrite?
            return
        end

        global.storage_new[player_index][name] = util.table.deepcopy(global.config_tmp[player_index])
        GUI.add_preset(player_index, name, table_size(global.storage_new[player_index]))
        global.selected_presets[player_index] = {[name] = true}
        GUI.update_presets(player_index)
    end,

    set_main_network = function(event, player)
        local player_index = event.player_index
        if global.mainNetwork[player_index] then
            global.mainNetwork[player_index] = false
        else
            local network = player.character and player.character.logistic_network or false
            if network then
                local cell = network.find_cell_closest_to(player.position)
                global.mainNetwork[player_index] = cell and cell.owner or false
            end
            if not global.mainNetwork[player_index] then
                display_message(player, {"auto-trash-not-in-network"}, true)
            end
        end
        event.element.caption = global.mainNetwork[player_index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
    end,

    import_from_vanilla = function(event, player)
        local player_index = event.player_index
        global.config_tmp[player_index] = combine_from_vanilla(player)
        global.selected[player_index] = false
        global.dirty[player_index] = true
        GUI.update_buttons(player_index)
        GUI.update_sliders(player_index)
    end,

    config_button_changed = function(event, player, params)
        --log(serpent.line(params))
        -- log(serpent.line(event))
        local player_index = event.player_index
        local old_selected = global.selected[player_index]
        if event.name == defines.events.on_gui_click then
            if event.button == defines.mouse_button_type.right then
                if not event.element.elem_value then return end
                log("Clear button")
                assert(params.slot ~= old_selected)
                log(serpent.block(params))
                global.config_tmp[player_index].config[params.slot] = nil
                global.dirty[player_index] = true
                GUI.destroy_create_button(player_index, event.element.parent, params.slot, old_selected)
                --GUI.update_button(player_index, event.element.parent, params.slot, old_selected)
            elseif event.button == defines.mouse_button_type.left then
                if not event.element.elem_value or old_selected == params.slot then return end--empty button
                log("Select button: " .. params.slot .. " old: " .. tostring(old_selected))
                global.selected[player_index] = params.slot
                local flow = event.element.parent
                GUI.destroy_create_button(player_index, flow, params.slot, params.slot)
                --GUI.update_button(player_index, flow, params.slot, params.slot)
                GUI.destroy_create_button(player_index, flow.parent.children[old_selected], old_selected, params.slot)
                --GUI.update_button(player_index, flow, old_selected, params.slot)
            end
        elseif event.name == defines.events.on_gui_elem_changed then
            if event.element.elem_value then
                if event.element.elem_value == params.item then return end--changed to same item
                log("New item")
                local ruleset_grid = event.element.parent.parent
                local found
                for i, flow in pairs(ruleset_grid.children) do
                    if i ~= params.slot and flow.children[1].elem_value == event.element.elem_value then
                        log(serpent.line{i=i, params=params, s = global.selected[player_index]} )
                        display_message(player, {"", {"cant-set-duplicate-request", game.item_prototypes[event.element.elem_value].localised_name}}, true)
                        event.element.elem_value = params.item
                        global.selected[player_index] = i
                        GUI.destroy_create_button(player_index, flow, params.slot, i)
                        GUI.destroy_create_button(player_index, flow, i, i)
                        found = true
                        break
                    end
                end
                if not found then
                    log("changed")
                    global.selected[player_index] = params.slot
                    global.dirty[player_index] = true
                    local config_tmp = global.config_tmp[player_index].config
                    config_tmp[params.slot] = {name = event.element.elem_value, request = game.item_prototypes[event.element.elem_value].default_request_amount, trash = false, slot = params.slot}
                    GUI.update_button(player_index, event.element.parent, params.slot, params.slot)
                    GUI.update_button(player_index, event.element.parent.parent.children[old_selected], old_selected, params.slot)
                end
            elseif params.item then
                log("Clear button2")
                assert(params.slot == old_selected)
                global.selected[player_index] = false
                global.config_tmp[player_index].config[params.slot] = nil
                global.dirty[player_index] = true
                GUI.update_button(player_index, event.element.parent, params.slot)
            end
        else
            log("Unhandled event: " .. GUI.get_event_name(event.name))
            return
        end
        GUI.update_sliders(player_index)
    end,

    request_textfield_changed = function(event, _, _)
        if event.name ~= defines.events.on_gui_text_changed then return end
        local player_index = event.player_index
        local selected = global.selected[player_index]
        local item_config = global.config_tmp[player_index].config[selected]
        if not (selected and item_config) then
            GUI.update_sliders(player_index)
            return
        end
        local number = tonumber(event.element.text)
        assert(number >= 0, "request has to be a positive number") --TODO remove
        assert(item_config.name, "item config without name")
        item_config.request = number
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and number > item_config.trash then
            item_config.trash = number
        end
        global.dirty[player_index] = true
        GUI.update_sliders(player_index)
    end,

    trash_textfield_changed = function(event, player, params)--luacheck: ignore
        log("trash text changed")
    end
}

function GUI.deregister_action(element)
    local player_gui_actions = global.gui_actions[element.player_index]
    if not player_gui_actions then
        return
    end
    player_gui_actions[element.index] = nil
    for k, child in pairs(element.children) do
        GUI.deregister_action(child)
    end
end

--[[
    params = {
        type: function name
    }
--]]
function GUI.register_action(element, params)
    local gui_actions = global.gui_actions
    local player_gui_actions = gui_actions[element.player_index]
    if not player_gui_actions then
        gui_actions[element.player_index] = {}
        player_gui_actions = gui_actions[element.player_index]
    end
    player_gui_actions[element.index] = params
    --log(serpent.block(global.gui_actions[element.player_index]))
end

function GUI.get_event_name(i)
    for key, v in pairs(defines.events) do
        if v == i then
            return key
        end
    end
end

function GUI.generic_event(event)
    local gui = event.element
    if not (gui and gui.valid) then return end

    local player_gui_actions = global.gui_actions[gui.player_index]
    if not player_gui_actions then return end

    local action = player_gui_actions[gui.index]
    if not action then return end
    log(GUI.get_event_name(event.name))
    log(serpent.line(action.type))
    gui_functions[action.type](event, game.get_player(gui.player_index), action)
    --log(serpent.block(global.gui_elements))
    log("Registered gui actions:" .. table_size(player_gui_actions))
    return true
end

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)[GUI.defines.main_button_flow]
    if button_flow and button_flow.valid and button_flow[GUI.defines.main_button] and button_flow[GUI.defines.main_button].valid then
        global.gui_elements.main_button[player.index] = button_flow[GUI.defines.main_button]
        return
    end
    log("init gui")
    if player.force.technologies["character-logistic-slots-1"].researched
    or player.force.technologies["character-logistic-trash-slots-1"].researched then
        local flow = button_flow.add{
            type = "flow",
            name = GUI.defines.main_button_flow,
            style = "at_main_flow",
            direction = "horizontal"
        }
        local button = flow.add{
            type = "sprite-button",
            name = GUI.defines.main_button,
            style = "at_sprite_button"
        }
        button.sprite = "autotrash_trash"
        global.gui_elements.main_button[player.index] = button
        GUI.register_action(button, {type = "main_button"})
    end
end

function GUI.update_main_button(player_index)
    local mainButton = global.gui_elements.main_button[player_index]
    if not (mainButton and mainButton.valid) then
        return
    end
    local settings = global.settings[player_index]
    if settings.pause_trash and not settings.pause_requests then
        mainButton.sprite = "autotrash_trash_paused"
    elseif settings.pause_requests and not settings.pause_trash then
        mainButton.sprite = "autotrash_requests_paused"
    elseif settings.pause_trash and settings.pause_requests then
        mainButton.sprite = "autotrash_both_paused"
    else
        mainButton.sprite = "autotrash_trash"
    end
    GUI.update_settings(player_index)
end

function GUI.update_settings(player_index)
    local frame = global.gui_elements.trash_options[player_index]
    if not (frame and frame.valid) then return end
    local settings = global.settings[player_index]
    frame[GUI.defines.trash_unrequested].state = settings.auto_trash_unrequested
    frame[GUI.defines.trash_above_requested].state = settings.auto_trash_above_requested
    frame[GUI.defines.trash_in_main_network].state = settings.auto_trash_in_main_network
    frame[GUI.defines.pause_trash].state = settings.pause_trash
    frame[GUI.defines.pause_requests].state = settings.pause_requests
end

function GUI.delete(player_index)
    for k, guis in pairs(global.gui_elements) do
        local element = guis[player_index]
        if element and element.valid then
            GUI.deregister_action(element)
            element.destroy()
        end
        guis[player_index] = nil
    end
end

-- function GUI.update_selected_button(player)
--     button.children[2].caption = format_number(format_trash(item_config), true)
--     button.children[1].caption = format_number(format_request(item_config), true)
-- end

function GUI.update_sliders(player_index)
    local slider_flow = global.gui_elements.slider_flow[player_index]
    if not (slider_flow and slider_flow.valid) then return end

    local item_config = global.config_tmp[player_index].config[global.selected[player_index]]
    local visible = item_config and true or false
    for _, child in pairs(slider_flow.children) do
        child.visible = visible
    end
    if visible then
        slider_flow[def.config_request][def.config_slider].slider_value = convert_to_slider(item_config.request)
        slider_flow[def.config_request][def.config_slider_text].text = format_request(item_config) or 0
        slider_flow[def.config_trash][def.config_slider].slider_value = item_config.trash and convert_to_slider(item_config.trash) or 42
        slider_flow[def.config_trash][def.config_slider_text].text = format_trash(item_config) or "∞"
    end
    local reset = global.gui_elements.reset_button[player_index]
    if not (reset and reset.valid) then return end
    reset.enabled = global.dirty[player_index]
end

function GUI.update_button_action(button, i, _, foo)
    local action
    if button.locked then
        action = {type = "config_button_changed", slot = i, item = button.elem_value}
    else
        action = {type = "config_button_changed", slot = i, item = button.elem_value}
    end
    if foo then
        log(serpent.block(action))
    end
    GUI.register_action(button, action)
    -- if button.elem_value then
    --     log(i .. " " .. tostring(button.elem_value) .. "\t\t\t" .. action.type .. " " .. tostring(button.locked) .. " " .. button.style.name)
    -- end
end

function GUI.clear_button(button, i)
    button.locked = false
    button.elem_value = nil
    button.children[1].caption = ""
    button.children[2].caption = ""
    button.style = "at_button_slot"
    GUI.update_button_action(button, i, nil)
end

function GUI.destroy_create_button(player_index, flow, i, selected)
        if not i then return end
        if not (flow and flow.valid) then return end
        GUI.deregister_action(flow)
        flow.clear()
        --log("update button: " .. i .. " " .. tostring(selected))
        local button = GUI.create_button(player_index, flow, i, selected)
        GUI.update_button_action(button, i, selected, true)
        return button
end

function GUI.update_button(player_index, flow, i, selected)
        local button = flow.children[1]
        local req = global.config_tmp[player_index].config[i]
        button.locked = req and i ~= selected
        if req then
            button.children[1].caption = format_number(format_request(req), true)
            button.children[2].caption = format_number(format_trash(req), true)
            button.elem_value = req.name
        else
            button.children[1].caption = ""
            button.children[2].caption = ""
            button.elem_value = nil
        end
        --button.style = button.locked and "at_button_slot_locked" or "at_button_slot"
        button.style = (i == selected) and "at_button_slot_selected" or "at_button_slot"
        GUI.update_button_action(button, i, selected)
end

function GUI.update_buttons(player_index, old_selected)
    --log("update buttons")
    local scroll_pane = global.gui_elements.config_scroll[player_index]
    if not (scroll_pane and scroll_pane.valid) then return end
    local ruleset_grid = scroll_pane.children[1]
    if not (ruleset_grid and ruleset_grid.valid) then return end

    local selected = global.selected[player_index]
    local req, button
    local start = old_selected or 1
    log("update buttons, start: " .. start)
    for i = start, #ruleset_grid.children do
    --for i, button in pairs(ruleset_grid.children) do
        button = ruleset_grid.children[i].children[1]
        req = global.config_tmp[player_index].config[i]
        button.locked = req and i ~= selected
        if req then
            button.children[1].caption = format_number(format_request(req), true)
            button.children[2].caption = format_number(format_trash(req), true)
            button.elem_value = req.name
        else
            button.children[1].caption = ""
            button.children[2].caption = ""
            button.elem_value = nil
        end
        --button.style = button.locked and "at_button_slot_locked" or "at_button_slot"
        button.style = "at_button_slot"
        if i == selected then
            button.style = "at_button_slot_selected"
        end
        GUI.update_button_action(button, i, selected)
        -- if req then
        --     log(button.style.name .. "\t\t" .. req.name .. "\t\t" .. tostring(button.locked))
        -- end
    end
    --log("")
end

function GUI.create_button(player_index, flow, i, selected)
        local req = global["config_tmp"][player_index].config[i]
        local elem_value = req and req.name or nil
        local button = flow.add{
            type = "choose-elem-button",
            elem_type = "item"
        }
        button.elem_value = elem_value
        --button.style = selected == i and "at_button_slot_selected" or "at_button_slot"

        local lbl_top = button.add{
            type = "label",
            style = "at_request_label_top",
            ignored_by_interaction = true,
            caption = ""
        }
        local lbl_bottom = button.add{
            type = "label",
            style = "at_request_label_bottom",
            ignored_by_interaction = true,
            caption = ""
        }
        if elem_value then
            lbl_top.caption = format_number(format_request(req), true)
            lbl_bottom.caption = format_number(format_trash(req), true)
            --disable popup gui, keeps on_click active
            button.locked = not (i == selected)
        end
        --button.style = button.locked and "at_button_slot_locked" or "at_button_slot"
        button.style = "at_button_slot"
        if i == selected then
            button.style = "at_button_slot_selected"
        end
        return button
end

--creates/updates the choose-elem-buttons (update because i do something wierd with locked = true)
function GUI.create_buttons(player, old_selected)
    local player_index = player.index
    local scroll_pane = global.gui_elements.config_scroll[player_index]
    if not (scroll_pane and scroll_pane.valid) then return end
    local ruleset_grid = scroll_pane.children[1]
    if ruleset_grid and ruleset_grid.valid and not old_selected then
        GUI.deregister_action(ruleset_grid)
        ruleset_grid.destroy()
    end
    local mod_settings = player.mod_settings
    local slots = mod_settings["autotrash_slots"].value or player.character.request_slot_count
    local selected = global.selected[player_index]
    local start
    if not old_selected then
        ruleset_grid = scroll_pane.add{
            type = "table",
            column_count = mod_settings["autotrash_gui_columns"].value,
            style = "slot_table"
        }
        start = 1
    else
        start = old_selected
        local children = ruleset_grid.children
        for i = start, slots do
            GUI.deregister_action(children[i])
            children[i].destroy()
        end
    end
    log("create buttons, start: " .. start)
    local flow
    for i = start, slots do
        flow = ruleset_grid.add{type = "flow", direction = "horizontal"}
        local button = GUI.create_button(player_index, flow, i, selected)
        GUI.update_button_action(button, i, selected)

        -- if req then
        --     log(button.style.name .. "\t\t" .. req.name .. "\t\t" .. tostring(button.locked))
        -- end
    end
    --log("create_buttons, selected: " .. serpent.line(global.selected[player_index]) .. "\n")
end

function GUI.open_quick_presets(player_index)
    local button_flow = global.gui_elements.main_button[player_index]
    if not (button_flow and button_flow.valid) then
        return
    end
    if button_flow[GUI.defines.quick_presets] and button_flow[GUI.defines.quick_presets].valid then
        GUI.deregister_action(button_flow[GUI.defines.quick_presets])
        button_flow[GUI.defines.quick_presets].destroy()
        return
    end

    local quick_presets = button_flow.add{
        type = "list-box",
        name = GUI.defines.quick_presets
    }

    local i = 1
    local tmp = {}
    for key, _ in pairs(global.storage_new[player_index]) do
        tmp[i] = key
        i = i + 1
    end
    quick_presets.items = tmp
    GUI.register_action(quick_presets, {type = "load_quick_preset"})
end

function GUI.close_quick_presets(player_index)
    local button_flow = global.gui_elements.main_button[player_index]
    if not button_flow or not button_flow.valid then
        return
    end
    if button_flow[GUI.defines.quick_presets] and button_flow[GUI.defines.quick_presets].valid then
        GUI.deregister_action(button_flow[GUI.defines.quick_presets])
        button_flow[GUI.defines.quick_presets].destroy()
        return
    end
end

function GUI.open_logistics_frame(player)
    local player_index = player.index
    hide_yarm(player_index)
    local left = mod_gui.get_frame_flow(player)

    local frame = left.add{
        type = "frame",
        caption = {"gui-logistic.title"},
        direction = "vertical"
    }
    global.gui_elements.config_frame[player_index] = frame

    local config_flow_h = frame.add{
        type = "flow",
        name = GUI.defines.config_flow_h,
        direction = "horizontal"
    }

    local scroll_pane = config_flow_h.add{
        type = "scroll-pane",
    }
    scroll_pane.style.maximal_height = 38 * player.mod_settings["autotrash_gui_max_rows"].value + 6
    global.gui_elements.config_scroll[player_index] = scroll_pane

    if not global.config_tmp[player_index].config[global.selected[player_index]] then
        global.selected[player_index] = false
    end

    GUI.create_buttons(player)

    local button_flow = config_flow_h.add{
        type = "flow",
        direction = "vertical",
        style = "shortcut_bar_column"
    }
    local checkmark = button_flow.add{
        type = "sprite-button",
        style = "shortcut_bar_button_green",
        sprite = "utility/check_mark_white"
    }
    checkmark.style.top_padding = 4
    checkmark.style.right_padding = 4
    checkmark.style.bottom_padding = 4
    checkmark.style.left_padding = 4

    GUI.register_action(checkmark, {type = "apply_changes"})

    local reset_button = button_flow.add{
        type = "sprite-button",
        style = "shortcut_bar_button_red",
        sprite = "utility/reset_white"
    }
    reset_button.enabled = global.dirty[player_index]

    global.gui_elements.reset_button[player_index] = reset_button
    GUI.register_action(reset_button, {type = "reset_changes"})

    GUI.register_action(button_flow.add{
            type = "sprite-button",
            style = "shortcut_bar_button",
            sprite = "utility/downloading",
            tooltip = "Import from vanilla gui"
        },
        {type = "import_from_vanilla"}
    )
    --TODO: Import/export presets
    -- button_flow.add{
    --     type = "sprite-button",
    --     --name = GUI.defines.,
    --     style = "shortcut_bar_button_blue",
    --     sprite = "utility/import_slot",
    --     --tooltip = "Import from vanilla gui"
    -- }

    -- checkmark = button_flow.add{
    --     type = "sprite-button",
    --     --name = GUI.defines.,
    --     style = "shortcut_bar_button_blue",
    --     sprite = "utility/export_slot",
    --     --tooltip = "Import from vanilla gui"
    -- }

    -- checkmark.style.top_padding = 6
    -- checkmark.style.right_padding = 6
    -- checkmark.style.bottom_padding = 6
    -- checkmark.style.left_padding = 6

    local slider_vertical_flow = frame.add{
        type = "table",
        column_count = 2
    }
    global.gui_elements.slider_flow[player_index] = slider_vertical_flow

    slider_vertical_flow.style.minimal_height = 60
    slider_vertical_flow.add{
        type = "label",
        caption = {"gui-logistic.title-request-short"}
    }
    local slider_flow_request = slider_vertical_flow.add{
        type = "flow",
        name = GUI.defines.config_request,
        direction = "horizontal",
    }
    slider_flow_request.style.vertical_align = "center"

    slider_flow_request.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 41,
    }
    local request_textfield = slider_flow_request.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(request_textfield, {type = "request_textfield_changed"})

    slider_vertical_flow.add{
        type = "label",
        caption = {"auto-trash-trash"}
    }
    local slider_flow_trash = slider_vertical_flow.add{
        type = "flow",
        name = GUI.defines.config_trash,
        direction = "horizontal",
    }
    slider_flow_trash.style.vertical_align = "center"

    slider_flow_trash.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 42,
    }
    local trash_textfield = slider_flow_trash.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(trash_textfield, {type = "trash_textfield_changed"})
    GUI.update_sliders(player_index)

    --TODO add a dropdown for quick actions, that apply to each item e.g.
    --Set trash to requested amount
    --Set trash to stack size
    --Set requests to stack size
    --in/decrease by 1 stack size

    local trash_options = frame.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical",
    }
    global.gui_elements.trash_options[player_index] = trash_options
    trash_options.style.use_header_filler = false
    trash_options.style.horizontally_stretchable = true
    trash_options.style.font = "default-bold"

    local settings = global.settings[player_index]

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_above_requested,
        caption = {"auto-trash-above-requested"},
        state = settings.auto_trash_above_requested
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_unrequested,
        caption = {"auto-trash-unrequested"},
        state = settings.auto_trash_unrequested,
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.trash_in_main_network,
        caption = {"auto-trash-in-main-network"},
        state = settings.auto_trash_in_main_network,
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.pause_trash,
        caption = {"auto-trash-config-button-pause"},
        tooltip = {"auto-trash-tooltip-pause"},
        state = settings.pause_trash
    }

    trash_options.add{
        type = "checkbox",
        name = GUI.defines.pause_requests,
        caption = {"auto-trash-config-button-pause-requests"},
        tooltip = {"auto-trash-tooltip-pause-requests"},
        state = settings.pause_requests
    }

    GUI.register_action(trash_options.add{
                type = "button",
                caption = global.mainNetwork[player_index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
                },
                {type = "set_main_network"}
    )

    local button_grid = frame.add{
        type = "table",
        column_count = 2,
        name = "auto-trash-button-grid"
    }

    local clear_button = button_grid.add{
        type = "button",
        caption = {"gui.clear"}
    }

    local clear_option = button_grid.add{
        type = "drop-down",
        items = {
            [1] = "Both",
            [2] = "Requests",
            [3] = "Trash"
        },
        selected_index = settings.clear_option
    }
    global.gui_elements.clear_option[player_index] = clear_option
    GUI.register_action(clear_button, {type = "clear_config"})
    GUI.register_action(clear_option, {type = "clear_option_changed"})

    local storage_frame = left.add{
        type = "frame",
        caption = {"auto-trash-storage-frame-title"},
        direction = "vertical"
    }
    storage_frame.style.minimal_width = 200
    global.gui_elements.storage_frame[player_index] = storage_frame


    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 2,
        name = "auto-trash-logistics-storage-buttons"
    }
    local save_as = storage_frame_buttons.add{
        type = "textfield",
        text = ""
    }

    local save_button = storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save-as"},
        style = "at_small_button"
    }

    global.gui_elements.storage_textfield[player_index] = save_as
    GUI.register_action(save_button, {type = "save_preset", textfield = save_as})

    local storage_scroll = storage_frame.add{
        type = "scroll-pane",
    }

    storage_scroll.style.maximal_height = math.ceil(38*10+4)
    local storage_grid = storage_scroll.add{
        type = "table",
        column_count = 2,
    }
    global.gui_elements.storage_grid[player_index] = storage_grid

    local i = 1
    for key, _ in pairs(global.storage_new[player_index]) do
        GUI.add_preset(player_index, key, i)
        i = i + 1
    end
    GUI.update_presets(player_index)
end

function GUI.close(player)
    local player_index = player.index
    local gui_elements = global.gui_elements
    local storage_frame = gui_elements.storage_frame[player_index]
    local frame = gui_elements.config_frame[player_index]

    if storage_frame and storage_frame.valid then
        GUI.deregister_action(storage_frame)
        storage_frame.destroy()
        gui_elements.storage_frame[player_index] = nil
        gui_elements.storage_textfield[player_index] = nil
        gui_elements.storage_grid[player_index] = nil
    end
    if frame and frame.valid then
        GUI.deregister_action(frame)
        frame.destroy()
        gui_elements.config_frame[player_index] = nil
        gui_elements.config_scroll[player_index] = nil
        gui_elements.slider_flow[player_index] = nil
        gui_elements.trash_options[player_index] = nil
        gui_elements.clear_option[player_index] = nil
        gui_elements.reset_button[player_index] = nil
    end
    if player.mod_settings["autotrash_reset_on_close"].value then
        global.config_tmp[player_index] = util.table.deepcopy(global.config_new[player_index])
        global.dirty[player_index] = false
    end
    show_yarm(player_index)
end

function GUI.update_presets(player_index)
    local storage_grid = global.gui_elements.storage_grid[player_index]
    if not (storage_grid and storage_grid.valid) then return end
    local children = storage_grid.children
    local presets = global.selected_presets[player_index]
    for i=1, #children, 2 do
        if presets[children[i].caption] then
            children[i].style = "at_preset_button_selected"
        else
            children[i].style = "at_preset_button"
        end
    end
    if table_size(presets) == 1 then
        global.gui_elements.storage_textfield[player_index].text = next(presets)
    else
        global.gui_elements.storage_textfield[player_index].text = ""
    end
end

function GUI.add_preset(player_index, preset_name, index)
    local storage_grid = global.gui_elements.storage_grid[player_index]
    if not (storage_grid and storage_grid.valid) then return end
    assert(not storage_grid.children[index*2-1] and not storage_grid.children[index*2])--TODO remove

    storage_grid.add{
        type = "button",
        caption = preset_name,
        name = GUI.defines.load_preset .. index,
    }
    local remove = storage_grid.add{
        type = "sprite-button",
        name = GUI.defines.delete_preset .. index,
        style = "red_icon_button",
        sprite = "utility/remove"
    }
    remove.style.left_padding = 0
    remove.style.right_padding = 0
    remove.style.top_padding = 0
    remove.style.bottom_padding = 0
end

function GUI.restore(player_index, element)
    local name = element.caption

    global.selected_presets[player_index] = {[name] = true}
    global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
    global.selected[player_index] = false
    global.dirty[player_index] = true

    global.gui_elements.storage_textfield[player_index].text = name
    GUI.update_presets(player_index)
    GUI.update_buttons(player_index)
    GUI.update_sliders(player_index)
end

function GUI.remove(player_index, element, index)
    local storage_grid = element.parent
    local btn1 = storage_grid[GUI.defines.load_preset .. index]
    local btn2 = storage_grid[GUI.defines.delete_preset .. index]
    assert(global.storage_new[player_index] and global.storage_new[player_index][btn1.caption]) --TODO remove
    global.selected_presets[player_index][btn1.caption] = nil
    global["storage_new"][player_index][btn1.caption] = nil
    GUI.deregister_action(btn1)
    GUI.deregister_action(btn2)
    btn1.destroy()
    btn2.destroy()
    GUI.update_presets(player_index)
end

return GUI
