local presets = require "__AutoTrash__/presets"
local lib_control = require '__AutoTrash__.lib_control'
local saveVar = lib_control.saveVar --luacheck: ignore
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local debugDump = lib_control.debugDump
local convert_to_slider = lib_control.convert_to_slider
local convert_from_slider = lib_control.convert_from_slider
local set_trash = lib_control.set_trash
local pause_trash = lib_control.pause_trash
local unpause_trash = lib_control.unpause_trash
local set_requests = lib_control.set_requests
local get_requests = lib_control.get_requests
local pause_requests = lib_control.pause_requests
local unpause_requests = lib_control.unpause_requests
local in_network = lib_control.in_network
local mod_gui = require '__core__/lualib/mod-gui'

local max_value = 4294967295 --2^32-1

local function tonumber_max(n)
    n = tonumber(n)
    return n > max_value and max_value or n
end

local function combine_from_vanilla(player_index)
    local player = game.get_player(player_index)
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

-- local function set_item_config(player_index, i, request, trash)

-- end

local GUI = {--luacheck: allow defined top
    defines = {
        main_button = "at_config_button",
        main_button_flow = "autotrash_main_flow",
        quick_presets = "at_quick_presets",


        trash_above_requested = "trash_above_requested",
        trash_unrequested = "trash_unrequested",
        trash_network = "trash_network",
        pause_trash = "autotrash_pause_trash",
        pause_requests = "autotrash_pause_requests",

        config_request = "at_config_request",
        config_trash = "at_config_trash",
        config_slider = "at_config_slider",
        config_slider_text = "at_config_slider_text",
    },
}

local gui_functions = {
    main_button = function(event, player)
        local element = event.element
        local player_index = event.player_index
        if event.button == defines.mouse_button_type.right then
            GUI.close(player)
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
                if global.gui_elements.config_frame[player_index] then
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

    reset_changes = function(event)
        local player_index = event.player_index
        if global.dirty[player_index] then
            global.config_tmp[player_index] = util.table.deepcopy(global.config_new[player_index])
            event.element.enabled = false
            global.selected_presets[player_index] = {}
            global.dirty[player_index] = false
            GUI.hide_sliders(player_index)
            GUI.update_buttons(player_index)
            GUI.update_presets(player_index)
        end
    end,

    clear_config = function(event)
        local player_index = event.player_index
        local mode = global.settings[player_index].clear_option
        local config_tmp = global.config_tmp[player_index]
        if mode == 1 then
            config_tmp.config = {}
            GUI.hide_sliders(player_index)
        elseif mode == 2 then
            for _, config in pairs(config_tmp.config) do
                config.request = 0
            end
            GUI.update_sliders(player_index)
        elseif mode == 3 then
            for _, config in pairs(config_tmp.config) do
                config.trash = false
            end
            GUI.update_sliders(player_index)
        end
        GUI.mark_dirty(player_index)
        GUI.update_buttons(player_index)
    end,

    clear_option_changed = function(event)
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        global.settings[event.player_index].clear_option = event.element.selected_index
    end,

    load_preset = function(event)
        local player_index = event.player_index
        local element = event.element
        local name = element.caption
        if not event.shift and not event.control then
            global.selected_presets[player_index] = {[name] = true}
            global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
            global.selected[player_index] = false
            global.gui_elements.storage_textfield[player_index].text = name
            GUI.update_buttons(player_index)
        else
            local selected_presets = global.selected_presets[player_index]
            if not selected_presets[name] then
                selected_presets[name] = true
            else
                selected_presets[name] = nil
            end
            local tmp = {config = {}, max_slot = 0}
            for key, _ in pairs(selected_presets) do
               presets.merge(tmp, global.storage_new[player_index][key])
            end
            global.config_tmp[player_index] = tmp
            global.selected[player_index] = false
            GUI.update_presets(player_index)
            GUI.update_buttons(player_index)
        end
        GUI.mark_dirty(player_index, true)
        GUI.hide_sliders(player_index)
        log(serpent.block(global.selected_presets[player_index]))
    end,

    load_quick_preset = function(event)
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        local player_index = event.player_index
        local element = event.element
        local name = element.get_item(element.selected_index)
        if global.storage_new[player_index][name] then
            local player = game.get_player(player_index)
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
        end
        GUI.deregister_action(element)
        element.destroy()
    end,

    save_preset = function(event, player)
        local player_index = event.player_index
        local textfield = global.gui_elements.storage_textfield[player_index]
        local name = textfield.text
        if name == "" then
            display_message(player, {"auto-trash-storage-name-not-set"}, true)
            textfield.focus()
            return
        end
        if global.storage_new[player_index][name] then
            if not player.mod_settings["autotrash_overwrite"].value then
                display_message(player, {"auto-trash-storage-name-in-use"}, true)
                textfield.focus()
                return
            end
            display_message(player, "Preset " .. name .." updated", "success")
        else
            GUI.add_preset(player_index, name)
        end

        global.storage_new[player_index][name] = util.table.deepcopy(global.config_tmp[player_index])

        global.selected_presets[player_index] = {[name] = true}
        GUI.update_presets(player_index)
    end,

    delete_preset = function(event, _, params)
        local storage_grid = event.element.parent
        local player_index = event.player_index
        local name = params.name
        local btn1 = storage_grid[name]
        local btn2 = event.element

        global.selected_presets[player_index][name] = nil
        global.storage_new[player_index][name] = nil
        GUI.deregister_action(btn1)
        GUI.deregister_action(btn2)
        btn1.destroy()
        btn2.destroy()
        GUI.update_presets(player_index)
    end,

    set_main_network = function(event, _)
        local player_index = event.player_index
        local player = game.get_player(player_index)
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

    import_from_vanilla = function(event, _)
        local player_index = event.player_index
        global.config_tmp[player_index] = combine_from_vanilla(player_index)
        GUI.mark_dirty(player_index)
        GUI.hide_sliders(player_index)
        GUI.update_buttons(player_index)
    end,

    config_button_changed = function(event, player, params)
        --log(serpent.line(params))
        -- log(serpent.line(event))
        local player_index = event.player_index
        local old_selected = global.selected[player_index]
        local config_tmp = global.config_tmp[player_index]
        if event.name == defines.events.on_gui_click then
            if event.button == defines.mouse_button_type.right then
                if not event.element.elem_value then return end
                log("Clear button")
                assert(params.slot ~= old_selected)
                log(serpent.block(params))
                config_tmp.config[params.slot] = nil
                GUI.destroy_create_button(player_index, event.element.parent, params.slot, old_selected)
                GUI.mark_dirty(player_index)
                if params.slot == config_tmp.max_slot then
                    ----TODO: decrease number of buttons if last row + x buttons are empty
                    for i = params.slot-1, 1, -1 do
                        if config_tmp.config[i] then
                            config_tmp.max_slot = i
                            break
                        end
                    end
                end
                if config_tmp.max_slot == params.slot then
                    config_tmp.max_slot = 0
                end
            elseif event.button == defines.mouse_button_type.left then
                if not event.element.elem_value or old_selected == params.slot then return end--empty button
                log("Select button: " .. params.slot .. " old: " .. tostring(old_selected))
                global.selected[player_index] = params.slot
                local flow = event.element.parent
                GUI.destroy_create_button(player_index, flow, params.slot, params.slot)
                GUI.destroy_create_button(player_index, flow.parent.children[old_selected], old_selected, params.slot)
                GUI.update_sliders(player_index)
            end
        elseif event.name == defines.events.on_gui_elem_changed then
            if event.element.elem_value then
                if event.element.elem_value == params.item then return end--changed to same item
                log("New item")
                local ruleset_grid = global.gui_elements.config_scroll[player_index].children[1]
                local found
                for i, flow in pairs(ruleset_grid.children) do
                    if i ~= params.slot and flow.children[1].elem_value == event.element.elem_value then
                        log(serpent.line{i=i, params=params, s = global.selected[player_index], old_selected = old_selected} )
                        display_message(game.get_player(player_index), {"", {"cant-set-duplicate-request", game.item_prototypes[event.element.elem_value].localised_name}}, true)
                        event.element.elem_value = params.item
                        global.selected[player_index] = i
                        global.gui_elements.config_scroll[player_index].scroll_to_element(flow.parent.children[i], "top-third")
                        GUI.destroy_create_button(player_index, flow, params.slot, i)
                        GUI.destroy_create_button(player_index, flow, i, i)
                        if old_selected and old_selected ~= i and old_selected ~= params.slot then
                            GUI.destroy_create_button(player_index, flow.parent.children[old_selected], old_selected, params.slot)
                        end
                        GUI.update_sliders(player_index)
                        found = true
                        break
                    end
                end
                if not found then
                    log("changed")
                    global.selected[player_index] = params.slot
                    config_tmp.config[params.slot] = {
                        name = event.element.elem_value, request = game.item_prototypes[event.element.elem_value].default_request_amount,
                        trash = false, slot = params.slot
                    }
                    config_tmp.max_slot = params.slot > config_tmp.max_slot and params.slot or config_tmp.max_slot
                    GUI.mark_dirty(player_index)
                    GUI.update_sliders(player_index)
                    GUI.update_button(player_index, params.slot, params.slot, event.element)
                    GUI.update_button(player_index, old_selected, params.slot)
                    if config_tmp.max_slot == params.slot and not ruleset_grid.children[config_tmp.max_slot+1] then
                        log("more buttons")
                        local last = GUI.create_buttons(player, config_tmp.max_slot+1)
                        global.gui_elements.config_scroll[player_index].scroll_to_element(ruleset_grid.children[last].children[1], "top-third")
                    end
                end
            elseif params.item then
                log("Clear button2")
                assert(params.slot == old_selected)
                config_tmp.config[params.slot] = nil
                GUI.mark_dirty(player_index)
                GUI.hide_sliders(player_index)
                GUI.update_button(player_index, params.slot, false, event.element)
                if params.slot == config_tmp.max_slot then
                    ----TODO: decrease number of buttons if last row + x buttons are empty
                    for i = params.slot-1, 1, -1 do
                        if config_tmp.config[i] then
                            config_tmp.max_slot = i
                            break
                        end
                    end
                    if config_tmp.max_slot == params.slot then
                        config_tmp.max_slot = 0
                    end
                end
            end
        else
            log("Unhandled event: " .. GUI.get_event_name(event.name))
            return
        end
        log("max_slot: " .. config_tmp.max_slot)
    end,

    request_amount_changed = function(event, _, _)
        if event.name ~= defines.events.on_gui_text_changed and event.name ~= defines.events.on_gui_value_changed then return end
        local player_index = event.player_index
        local selected = global.selected[player_index]
        local item_config = global.config_tmp[player_index].config[selected]
        assert(item_config.name, "item config without name")--TODO: remove
        local number
        if event.name == defines.events.on_gui_text_changed then
            number = tonumber_max(event.element.text) or 0
        elseif event.name == defines.events.on_gui_value_changed then
            number = tonumber_max(convert_from_slider(event.element.slider_value)) or 0
        end
        item_config.request = number
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and number > item_config.trash then
            item_config.trash = number
        end
        GUI.mark_dirty(player_index)
        GUI.update_button(player_index, selected, selected)
        GUI.update_sliders(player_index)
    end,

    trash_amount_changed = function(event, _, _)
        if event.name ~= defines.events.on_gui_text_changed and event.name ~= defines.events.on_gui_value_changed then return end
        local player_index = event.player_index
        local selected = global.selected[player_index]
        local item_config = global.config_tmp[player_index].config[selected]
        assert(item_config.name, "item config without name")
        local number
        if event.name == defines.events.on_gui_text_changed then
            number = tonumber_max(event.element.text) or false
        elseif event.name == defines.events.on_gui_value_changed then
            if event.element.slider_value == 42 then
                number = false
            else
                number = tonumber_max(convert_from_slider(event.element.slider_value)) or false
            end
            if number and item_config.request > number then
                item_config.request = number
            end
        end
        item_config.trash = number
        GUI.mark_dirty(player_index)
        GUI.update_button(player_index, selected, selected)
        GUI.update_sliders(player_index)
    end,

    toggle_pause_trash = function(event, player)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        if event.element.state then
            pause_trash(player)
        else
            unpause_trash(player)
        end
        GUI.update_main_button(player.index)
    end,

    toggle_pause_requests = function(event, player)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        if event.element.state then
            pause_requests(player)
        else
            unpause_requests(player)
        end
        GUI.update_main_button(player.index)
    end,

    toggle_trash_option = function(event)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        global.settings[event.player_index][event.element.name] = event.element.state
    end,

    toggle_trash_network = function(event, player)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        local element = event.element
        if element.state and not global.mainNetwork[event.player_index] then
            player.print("No main network set")
            element.state = false
        else
            global.settings[event.player_index].autotrash_network = element.state
            if element.state and in_network(player) then
                unpause_trash(player)
                GUI.update_main_button(player.index)
            end
        end
    end,
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

    local player_gui_actions = global.gui_actions[event.player_index]
    if not player_gui_actions then return end

    local action = player_gui_actions[gui.index]
    if not action then return end
    local player = game.get_player(gui.player_index)
    log(GUI.get_event_name(event.name))
    log(serpent.line(action))
    local profile_inner = game.create_profiler()
    local profile_outer = game.create_profiler()
    local status, err = pcall(function()
        profile_inner.reset()
        gui_functions[action.type](event, player, action)
        profile_inner.stop()
    end)
    profile_outer.stop()
    -- log{"", "Inner: ", profile_inner}
    -- log{"", "Outer: ", profile_outer}
    log("Selected: " .. tostring(global.selected[event.player_index]))
    log("Registered gui actions:" .. table_size(player_gui_actions))
    if not status then
        --log(serpent.block(global.gui_elements))
        -- local s, elem
        -- for name, elems in pairs(global.gui_elements) do
        --     s = name .. ": "
        --     elem = elems[event.player_index]
        --     if elem and elem.valid then
        --         s = s .. "valid"
        --     elseif elem and not elem.valid then
        --         s = s .. "invalid"
        --     elseif not elem then
        --         s = s .. "nil"
        --     end
        --     log(s)
        -- end
        debugDump(err, player, true)
        log(debug.traceback())
    end
end

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow and button_flow[GUI.defines.main_button_flow] and button_flow[GUI.defines.main_button_flow].valid then
        return
    end
    if global.gui_elements.main_button[player.index] and global.gui_elements.main_button[player.index].valid then
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
    frame[GUI.defines.trash_unrequested].state = settings.trash_unrequested
    frame[GUI.defines.trash_above_requested].state = settings.trash_above_requested
    frame[GUI.defines.trash_network].state = settings.trash_network
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

function GUI.mark_dirty(player_index, keep_presets)
    local reset = global.gui_elements.reset_button[player_index]
    if not (reset and reset.valid) then return end
    reset.enabled = true
    global.dirty[player_index] = true
    if not keep_presets then
        global.selected_presets[player_index] = {}
    end
    GUI.update_presets(player_index)
end

function GUI.hide_sliders(player_index)
    global.selected[player_index] = false
    local slider_flow = global.gui_elements.slider_flow[player_index]
    if not (slider_flow and slider_flow.valid) then return end
    for _, child in pairs(slider_flow.children) do
        child.visible = false
    end
end

function GUI.update_sliders(player_index)
    local slider_flow = global.gui_elements.slider_flow[player_index]
    if not (slider_flow and slider_flow.valid) then return end

    local item_config = global.config_tmp[player_index].config[global.selected[player_index]]
    assert(item_config)--TODO: remove
    local visible = item_config and true or false
    for _, child in pairs(slider_flow.children) do
        child.visible = visible
    end
    if visible then
        slider_flow[GUI.defines.config_request][GUI.defines.config_slider].slider_value = convert_to_slider(item_config.request)
        slider_flow[GUI.defines.config_request][GUI.defines.config_slider_text].text = format_request(item_config) or 0
        slider_flow[GUI.defines.config_trash][GUI.defines.config_slider].slider_value = item_config.trash and convert_to_slider(item_config.trash) or 42
        slider_flow[GUI.defines.config_trash][GUI.defines.config_slider_text].text = format_trash(item_config) or "∞"
    end
end

function GUI.destroy_create_button(player_index, flow, i, selected)
        if not i then return end
        if not (flow and flow.valid) then return end
        GUI.deregister_action(flow)
        flow.clear()
        local button = GUI.create_button(player_index, flow, i, selected)
        GUI.register_action(button, {type = "config_button_changed", slot = i, item = button.elem_value})
        return button
end

function GUI.update_button(player_index, i, selected, button)
    if not (button and button.valid) then
        local config_grid = global.gui_elements.config_scroll[player_index].children[1]
        if not (config_grid and config_grid.valid) then return end
        if not (i and config_grid.children[i] and config_grid.children[i].valid) then return end
        button = config_grid.children[i].children[1]
    end
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
    button.style = (i == selected) and "at_button_slot_selected" or "at_button_slot"
    GUI.register_action(button, {type = "config_button_changed", slot = i, item = button.elem_value})
end

function GUI.update_buttons(player_index, old_selected)
    local scroll_pane = global.gui_elements.config_scroll[player_index]
    if not (scroll_pane and scroll_pane.valid) then return end
    local ruleset_grid = scroll_pane.children[1]
    if not (ruleset_grid and ruleset_grid.valid) then return end

    local selected = global.selected[player_index]
    local button
    local start = old_selected or 1
    log("update buttons, start: " .. start)
    for i = start, #ruleset_grid.children do
        button = ruleset_grid.children[i].children[1]
        GUI.update_button(player_index, i, selected, button)
    end
end

function GUI.create_button(player_index, flow, i, selected)
        local req = global["config_tmp"][player_index].config[i]
        local elem_value = req and req.name or nil
        local button = flow.add{
            type = "choose-elem-button",
            elem_type = "item",
            style = "at_button_slot"
        }

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
            button.elem_value = elem_value
            lbl_top.caption = format_number(format_request(req), true)
            lbl_bottom.caption = format_number(format_trash(req), true)
            --disable popup gui, keeps on_click active
            button.locked = not (i == selected)
        end
        if (i == selected) then
            button.style = "at_button_slot_selected"
        end

        GUI.register_action(button, {type = "config_button_changed", slot = i, item = button.elem_value})
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
    local columns = player.mod_settings["autotrash_gui_columns"].value
    local config_tmp = global.config_tmp[player_index]
    local max_slot = config_tmp.max_slot or columns
    local slots = player.character.request_slot_count
    slots = slots > max_slot and slots or max_slot
    slots = slots > columns and slots or columns
    --if the last button is occupied add a new row
    if config_tmp.config[slots] then
        slots = slots + columns
    end

    log("Creating " .. slots .. " slots")
    local selected = global.selected[player_index]
    local start
    if not old_selected then
        ruleset_grid = scroll_pane.add{
            type = "table",
            column_count = columns,
            style = "slot_table"
        }
        start = 1
    else
        start = old_selected
        local children = ruleset_grid.children
        for i = start, slots do
            if children[i] then
                GUI.deregister_action(children[i])
                children[i].destroy()
            end
        end
    end
    --local flowt = {type = "flow", direction = "horizontal"}
    local create_button = GUI.create_button
    for i = start, slots do
        create_button(player_index, ruleset_grid.add{type = "flow", direction = "horizontal", name = i}, i, selected)
    end
    return slots
end

function GUI.open_quick_presets(player_index)
    local button_flow = global.gui_elements.main_button[player_index].parent
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
    local button_flow = global.gui_elements.main_button[player_index].parent
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

    assert(not global.selected[player_index])--TODO: remove

    local frame = left.add{
        type = "frame",
        caption = {"gui-logistic.title"},
        direction = "vertical"
    }
    frame.style.minimal_width = 340
    global.gui_elements.config_frame[player_index] = frame

    local config_flow_v = frame.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical",
    }
    config_flow_v.style.horizontally_stretchable = true

    local config_flow_h = config_flow_v.add{
        type = "flow",
        name = GUI.defines.config_flow_h,
        direction = "horizontal"
    }

    local scroll_pane = config_flow_h.add{
        type = "scroll-pane",
    }
    scroll_pane.style.maximal_height = 38 * player.mod_settings["autotrash_gui_max_rows"].value + 6
    global.gui_elements.config_scroll[player_index] = scroll_pane

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
    --     style = "shortcut_bar_button_blue",
    --     sprite = "utility/import_slot",
    -- }

    -- button_flow.add{
    --     type = "sprite-button",
    --     style = "shortcut_bar_button_blue",
    --     sprite = "utility/export_slot",
    -- }

    local slider_vertical_flow = config_flow_v.add{
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

    local request_slider = slider_flow_request.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 41,
    }
    GUI.register_action(request_slider, {type = "request_amount_changed"})

    local request_textfield = slider_flow_request.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(request_textfield, {type = "request_amount_changed"})

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

    local trash_slider = slider_flow_trash.add{
        type = "slider",
        name = GUI.defines.config_slider,
        minimum_value = 0,
        maximum_value = 42,
    }
    GUI.register_action(trash_slider, {type = "trash_amount_changed"})

    local trash_textfield = slider_flow_trash.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(trash_textfield, {type = "trash_amount_changed"})

    GUI.hide_sliders(player_index)

    GUI.create_buttons(player)

    --TODO add a dropdown for quick actions, that apply to each item e.g.
    --Set trash to requested amount
    --Set trash to stack size
    --Set requests to stack size
    --in/decrease by 1 stack size

    local settings = global.settings[player_index]
    local button_grid = config_flow_v.add{
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

    local trash_options = frame.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical",
    }
    global.gui_elements.trash_options[player_index] = trash_options
    trash_options.style.use_header_filler = false
    trash_options.style.horizontally_stretchable = true
    trash_options.style.font = "default-bold"

    GUI.register_action(trash_options.add{
                            type = "checkbox",
                            name = GUI.defines.trash_above_requested,
                            caption = {"auto-trash-above-requested"},
                            state = settings[GUI.defines.trash_above_requested]
                        },
                        {type = "toggle_trash_option"})

    GUI.register_action(trash_options.add{
                            type = "checkbox",
                            name = GUI.defines.trash_unrequested,
                            caption = {"auto-trash-unrequested"},
                            state = settings[GUI.defines.trash_unrequested]
                        },
                        {type = "toggle_trash_option"})

    GUI.register_action(trash_options.add{
                            type = "checkbox",
                            name = GUI.defines.trash_network,
                            caption = {"auto-trash-in-main-network"},
                            state = settings[GUI.defines.trash_network]
                        },
                        {type = "toggle_trash_network"})

    GUI.register_action(trash_options.add{
                            type = "checkbox",
                            name = GUI.defines.pause_trash,
                            caption = {"auto-trash-config-button-pause"},
                            tooltip = {"auto-trash-tooltip-pause"},
                            state = settings.pause_trash
                        },
                        {type = "toggle_pause_trash"})

    GUI.register_action(trash_options.add{
                            type = "checkbox",
                            name = GUI.defines.pause_requests,
                            caption = {"auto-trash-config-button-pause-requests"},
                            tooltip = {"auto-trash-tooltip-pause-requests"},
                            state = settings.pause_requests
                        },
                        {type = "toggle_pause_requests"})

    GUI.register_action(trash_options.add{
                type = "button",
                caption = global.mainNetwork[player_index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
                },
                {type = "set_main_network"}
    )

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
    storage_frame_buttons.style.horizontally_stretchable = true

    local save_as = storage_frame_buttons.add{
        type = "textfield",
        text = ""
    }
    save_as.style.horizontally_stretchable = true
    save_as.style.width = 0
    save_as.style.minimal_width = 200

    local save_button = storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save-as"},
        style = "at_small_button"
    }

    global.gui_elements.storage_textfield[player_index] = save_as
    GUI.register_action(save_button, {type = "save_preset"})

    local storage_scroll = storage_frame.add{
        type = "scroll-pane",
    }

    storage_scroll.style.maximal_height = math.ceil(38*10+4)
    local storage_grid = storage_scroll.add{
        type = "table",
        column_count = 2,
    }
    global.gui_elements.storage_grid[player_index] = storage_grid

    for key, _ in pairs(global.storage_new[player_index]) do
        GUI.add_preset(player_index, key)
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
    global.selected[player_index] = false
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
    local selected_presets = global.selected_presets[player_index]
    for i=1, #children, 2 do
        if selected_presets[children[i].caption] then
            children[i].style = "at_preset_button_selected"
        else
            children[i].style = "at_preset_button"
        end
    end
    local s = table_size(selected_presets)
    if s == 1 then
        global.gui_elements.storage_textfield[player_index].text = next(selected_presets)
    elseif s > 1 then
        global.gui_elements.storage_textfield[player_index].text = ""
    end
end

function GUI.add_preset(player_index, preset_name)
    local storage_grid = global.gui_elements.storage_grid[player_index]
    if not (storage_grid and storage_grid.valid) then return end

    local preset = storage_grid.add{
        type = "button",
        caption = preset_name,
        name = preset_name
    }
    preset.style.maximal_width = 500

    local remove = storage_grid.add{
        type = "sprite-button",
        style = "red_icon_button",
        sprite = "utility/remove"
    }
    GUI.register_action(preset, {type = "load_preset"})
    GUI.register_action(remove, {type = "delete_preset", name = preset_name})

    remove.style.left_padding = 0
    remove.style.right_padding = 0
    remove.style.top_padding = 0
    remove.style.bottom_padding = 0
end

return GUI
