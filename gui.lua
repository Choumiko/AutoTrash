local presets = require "__AutoTrash__/presets"
local lib_control = require '__AutoTrash__.lib_control'
local saveVar = lib_control.saveVar --luacheck: ignore
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_to_slider = lib_control.convert_to_slider
local convert_from_slider = lib_control.convert_from_slider
local set_trash = lib_control.set_trash
local pause_trash = lib_control.pause_trash
local unpause_trash = lib_control.unpause_trash
local set_requests = lib_control.set_requests
local in_network = lib_control.in_network
local item_prototype = lib_control.item_prototype
local mod_gui = require '__core__/lualib/mod-gui'

local max_value = 4294967295 --2^32-1

local function tonumber_max(n)
    n = tonumber(n)
    return (n and n > max_value) and max_value or n
end

local function combine_from_vanilla(player)
    if not player.character then return end
    local tmp = {config = {}, max_slot = 0, c_requests = 0}
    local requests, max_slot, c_requests = lib_control.get_requests(player)
    local trash = player.auto_trash_filters

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
                max_slot = max_slot > i and max_slot or i
                break
            end
        end
    end
    tmp.max_slot = max_slot
    tmp.c_requests = c_requests
    return tmp
end

local function show_yarm(player, pdata)
    if remote.interfaces.YARM then
        remote.call("YARM", "set_filter", player.index, pdata.settings.YARM_active_filter)
    end
end

local function hide_yarm(player, pdata)
    if remote.interfaces.YARM then
        pdata.settings.YARM_active_filter = remote.call("YARM", "set_filter", player.index, "none")
    end
end

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
        network_button = "network_button",

        config_request = "at_config_request",
        config_trash = "at_config_trash",
        config_slider = "at_config_slider",
        config_slider_text = "at_config_slider_text",
    },
}

function GUI.clear_button(player, pdata, params, config_tmp)
    if config_tmp.config[params.slot].request > 0 then
        config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
    end
    config_tmp.config[params.slot] = nil
    if params.slot == config_tmp.max_slot then
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
    local gui_elements = pdata.gui_elements
    local ruleset_grid = gui_elements.ruleset_grid
    local columns = player.mod_settings["autotrash_gui_columns"].value
    local count = #ruleset_grid.children
    local max_buttons = config_tmp.max_slot + columns + 1
    local request_slots = player.character.request_slot_count + 1
    max_buttons = max_buttons > request_slots and max_buttons or request_slots
    if count >= max_buttons then
        for i = count, max_buttons, -1 do
            assert(not config_tmp.config[i], "Should be empty")-- TODO: remove
            GUI.deregister_action(ruleset_grid.children[i], pdata, true)
        end
    end
    GUI.mark_dirty(pdata)
end

function GUI.extend_buttons(player, max_slot, pdata)
    local gui_elements = pdata.gui_elements
    local ruleset_grid = gui_elements.ruleset_grid
    local count = #ruleset_grid.children
    if max_slot >= count then
        local last = GUI.create_buttons(player, count+1, pdata)
        gui_elements.config_scroll.scroll_to_element(ruleset_grid.children[last], "top-third")
    end
end

local gui_functions = {
    main_button = function(event, pdata)
        local player = event.player
        local gui_elements = pdata.gui_elements
        if event.button == defines.mouse_button_type.right then
            if not (event.control) then
                GUI.close(player, pdata)
                GUI.open_quick_presets(pdata)
            else
                if gui_elements.status_flow then
                    GUI.close_status_flow(pdata)
                else
                    if gui_elements.config_frame then
                        GUI.close(player, pdata, true)
                        GUI.open_status_flow(player, pdata)
                        GUI.open_logistics_frame(player, pdata)
                    else
                        GUI.open_status_flow(player, pdata)
                    end
                end
            end
        else
            GUI.close_quick_presets(pdata)
            if player.cursor_stack and player.cursor_stack.valid_for_read then--luacheck: ignore
                -- if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
                --     add_order(player)
                -- elseif player.cursor_stack.name ~= "blueprint" then
                --     add_to_trash(player, player.cursor_stack.name)
                -- end
            else
                if gui_elements.config_frame then
                    GUI.close(player, pdata)
                else
                    GUI.open_logistics_frame(player, pdata)
                end
            end
        end
    end,

    apply_changes = function(event, pdata)
        local player = event.player
        pdata.config_new = util.table.deepcopy(pdata.config_tmp)
        local status_flow = pdata.gui_elements.status_flow
        if status_flow and status_flow.valid then
            status_flow.clear()
            GUI.update_status_flow(player, pdata)
        end
        pdata.dirty = false
        pdata.gui_elements.reset_button.enabled = false
        if player.mod_settings["autotrash_close_on_apply"].value then
            GUI.close(player, pdata)
        end

        if not pdata.settings.pause_trash then
            set_trash(player, pdata)
        end
        if not pdata.settings.pause_requests then
            set_requests(player, pdata)
        end
    end,

    reset_changes = function(event, pdata)
        if pdata.dirty then
            pdata.config_tmp = util.table.deepcopy(pdata.config_new)
            event.element.enabled = false
            pdata.selected_presets = {}
            pdata.dirty = false
            GUI.hide_sliders(pdata)
            GUI.update_buttons(event.player, pdata)
            GUI.update_presets(pdata)
        end
    end,

    request_blueprint = function(event)
        if event.name ~= defines.events.on_gui_click then return end
        local player = event.player
        local cursor_stack = player.cursor_stack
        if not (cursor_stack and cursor_stack.valid_for_read) then
            log("Empty cursor")
            return
        end
        if not (cursor_stack.is_blueprint or cursor_stack.is_blueprint_book) then
            log("No bp item")
            return
        end
        local bp = cursor_stack.is_blueprint and cursor_stack or cursor_stack.get_inventory(defines.inventory.item_main)[cursor_stack.active_index]
        if not bp.is_blueprint_setup() then
            log("Not setup")
            return
        end
        log("Adding temp requests")
        log(serpent.line(bp.cost_to_build))
    end,

    quick_actions = function(event, pdata)
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        local element = event.element
        local index = element.selected_index
        if index == 1 then return end

        local config_tmp = pdata.config_tmp
        if index == 2 then
            for _, config in pairs(config_tmp.config) do
                config.request = 0
            end
            config_tmp.c_requests = 0
            GUI.update_sliders(pdata)
        elseif index == 3 then
            for _, config in pairs(config_tmp.config) do
                config.trash = false
            end
            GUI.update_sliders(pdata)
        elseif index == 4 then
            config_tmp.config = {}
            config_tmp.max_slot = 0
            config_tmp.c_requests = 0
            GUI.hide_sliders(pdata)
        elseif index == 5 then
            for _, config in pairs(config_tmp.config) do
                if config.request > 0 then
                    config.trash = config.request
                end
            end
            GUI.update_sliders(pdata)
        elseif index == 6 then
            local c = 0
            for _, config in pairs(config_tmp.config) do
                if config.trash then
                    config.request = config.trash
                    c = config.request > 0 and c + 1 or c
                end
            end
            config_tmp.c_requests = c
        end
        element.selected_index = 1

        GUI.mark_dirty(pdata)
        GUI.update_buttons(event.player, pdata)
    end,

    load_preset = function(event, pdata)
        local element = event.element
        local name = element.caption
        local config_tmp
        local gui_elements = pdata.gui_elements
        if not event.shift and not event.control then
            pdata.selected_presets = {[name] = true}
            config_tmp = util.table.deepcopy(pdata.storage_new[name])
            pdata.selected = false
            gui_elements.storage_textfield.text = name
        else
            local selected_presets = pdata.selected_presets
            if not selected_presets[name] then
                selected_presets[name] = true
            else
                selected_presets[name] = nil
            end
            local tmp = {config = {}, max_slot = 0, c_requests = 0}
            for key, _ in pairs(selected_presets) do
               presets.merge(tmp, pdata.storage_new[key])
            end
            config_tmp = tmp
            pdata.selected = false
            GUI.update_presets(pdata)
        end
        pdata.config_tmp = config_tmp
        local ruleset_grid = gui_elements.ruleset_grid
        local count = #ruleset_grid.children
        if config_tmp.max_slot >= count then
            local last = GUI.create_buttons(event.player, count+1, pdata)
            gui_elements.config_scroll.scroll_to_element(ruleset_grid.children[last], "top-third")
        end
        GUI.update_buttons(event.player, pdata)
        GUI.mark_dirty(pdata, true)
        GUI.hide_sliders(pdata)
    end,

    change_death_preset = function(event, pdata, params)
        local name = params.name
        if not (event.shift or event.control) then
            pdata.death_presets = {[name] = true}
        else
            local selected_presets = pdata.death_presets
            if not selected_presets[name] then
                selected_presets[name] = true
            else
                selected_presets[name] = nil
            end
        end
        GUI.update_presets(pdata)
    end,

    load_quick_preset = function(event, pdata)
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        local element = event.element
        local name = element.get_item(element.selected_index)
        local stored_preset = pdata.storage_new[name]
        local settings = pdata.settings
        if stored_preset then
            local player = event.player
            pdata.selected_presets = {[name] = true}
            pdata.config_new = util.table.deepcopy(stored_preset)
            local status_flow = pdata.gui_elements.status_flow
            if status_flow and status_flow.valid then
                status_flow.clear()
                GUI.update_status_flow(player, pdata)
            end
            pdata.config_tmp = util.table.deepcopy(stored_preset)
            pdata.selected = false
            pdata.dirty = false
            if not settings.pause_trash then
                set_trash(player, pdata)
            end
            if not settings.pause_requests then
                set_requests(player, pdata)
            end
            display_message(player, "Preset '" .. tostring(name) .. "' loaded", "success")
        end
        GUI.deregister_action(element, pdata, true)
    end,

    save_preset = function(event, pdata)
        local textfield = pdata.gui_elements.storage_textfield
        local name = textfield.text
        if name == "" then
            display_message(event.player, {"auto-trash-storage-name-not-set"}, true)
            textfield.focus()
            return
        end
        if pdata.storage_new[name] then
            local player = event.player
            if not player.mod_settings["autotrash_overwrite"].value then
                display_message(player, {"auto-trash-storage-name-in-use"}, true)
                textfield.focus()
                return
            end
            display_message(player, "Preset " .. name .." updated", "success")
        else
            GUI.add_preset(name, pdata)
        end

        pdata.storage_new[name] = util.table.deepcopy(pdata.config_tmp)

        pdata.selected_presets = {[name] = true}
        GUI.update_presets(pdata)
    end,

    delete_preset = function(event, pdata, params)
        local preset_flow = event.element.parent
        local name = params.name

        pdata.selected_presets[name] = nil
        pdata.storage_new[name] = nil
        GUI.deregister_action(preset_flow, pdata, true)
        GUI.update_presets(pdata)
    end,

    set_main_network = function(event, pdata)
        local player = event.player
        if pdata.main_network then
            pdata.main_network = false
        else
            pdata.main_network = lib_control.get_network_entity(player)
            if not pdata.main_network then
                display_message(player, {"auto-trash-not-in-network"}, true)
            end
        end
        GUI.update_settings(pdata)
    end,

    import_from_vanilla = function(event, pdata)
        pdata.config_tmp = combine_from_vanilla(event.player)
        GUI.mark_dirty(pdata)
        GUI.hide_sliders(pdata)
        GUI.update_buttons(event.player, pdata)
    end,

    config_button_changed = function(event, pdata, params)
        local old_selected = pdata.selected
        local config_tmp = pdata.config_tmp
        local element = event.element
        local elem_value = element.elem_value
        local player = event.player
        if event.name == defines.events.on_gui_click then
            if event.button == defines.mouse_button_type.right then
                if not elem_value then
                    pdata.selected = false
                    GUI.update_button(pdata, old_selected)
                    GUI.hide_sliders(pdata)
                    GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                    return
                end
                GUI.clear_button(player, pdata, params, config_tmp)
                GUI.update_button(pdata, params.slot, old_selected, element)
                GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
            elseif event.button == defines.mouse_button_type.left then
                if event.shift then
                    local cursor_ghost = player.cursor_ghost
                    if not cursor_ghost and not player.cursor_stack.valid_for_read and elem_value then
                        pdata.selected = params.slot
                        player.cursor_ghost = elem_value
                        GUI.update_button(pdata, params.slot, old_selected, element)
                        GUI.update_button(pdata, old_selected, params.slot)
                        GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                        GUI.update_sliders(pdata)
                        return
                    elseif cursor_ghost and cursor_ghost.name == config_tmp.config[old_selected].name then
                        if elem_value then--always true, even when shift clicking an empty button with a ghost, since it gets set before on_click
                            local tmp = util.table.deepcopy(config_tmp.config[params.slot])
                            config_tmp.config[params.slot] = util.table.deepcopy(config_tmp.config[old_selected])
                            config_tmp.config[old_selected] = tmp
                            player.cursor_ghost = nil
                            pdata.selected = params.slot
                            config_tmp.max_slot = params.slot > config_tmp.max_slot and params.slot or config_tmp.max_slot
                            GUI.extend_buttons(player, config_tmp.max_slot, pdata)
                            GUI.update_button(pdata, params.slot, params.slot, element)
                            GUI.update_button(pdata, old_selected, params.slot)
                            GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                            GUI.mark_dirty(pdata)
                            GUI.update_sliders(pdata)
                            return
                        end
                    end
                end
                if not elem_value or old_selected == params.slot then return end--empty button
                pdata.selected = params.slot
                GUI.update_button(pdata, params.slot, params.slot, element)
                GUI.update_button(pdata, old_selected, params.slot)
                GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                GUI.update_sliders(pdata)
            end
        elseif event.name == defines.events.on_gui_elem_changed then
            if event.player.cursor_ghost then return end--dragging to an empty slot, on_gui_click raised later
            if elem_value then
                if elem_value == params.item then return end--changed to same item
                local gui_elements = pdata.gui_elements
                local ruleset_grid = gui_elements.ruleset_grid
                local found
                for i, button in pairs(ruleset_grid.children) do
                    if i ~= params.slot and button.elem_value == elem_value then
                        display_message(event.player, {"", {"cant-set-duplicate-request", item_prototype(elem_value).localised_name}}, true)
                        element.elem_value = params.item
                        pdata.selected = i
                        gui_elements.config_scroll.scroll_to_element(button.parent.children[i], "top-third")
                        GUI.update_button(pdata, params.slot, i)
                        GUI.update_button(pdata, i, i)
                        if old_selected and old_selected ~= i and old_selected ~= params.slot then
                            GUI.update_button(pdata, old_selected, params.slot)
                        end
                        GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                        GUI.update_sliders(pdata)
                        found = true
                        break
                    end
                end
                if not found then
                    pdata.selected = params.slot
                    config_tmp.config[params.slot] = {
                        name = elem_value, request = item_prototype(elem_value).default_request_amount,
                        trash = false, slot = params.slot
                    }
                    config_tmp.max_slot = params.slot > config_tmp.max_slot and params.slot or config_tmp.max_slot
                    if config_tmp.config[params.slot].request > 0 then
                        config_tmp.c_requests = config_tmp.c_requests + 1
                    end
                    GUI.mark_dirty(pdata)
                    GUI.update_sliders(pdata)
                    GUI.update_button(pdata, params.slot, params.slot, element)
                    GUI.update_button(pdata, old_selected, params.slot)
                    GUI.extend_buttons(player, config_tmp.max_slot, pdata)
                    GUI.update_button_styles(player, pdata)--TODO: only update changed buttons
                end
            elseif params.item then
                GUI.clear_button(player, pdata, params, config_tmp)
                GUI.hide_sliders(pdata)
                GUI.update_button(pdata, params.slot, false, element)
            end
        else
            log("Unhandled event: " .. GUI.get_event_name(event.name))
            return
        end
    end,

    request_amount_changed = function(event, pdata)
        if event.name ~= defines.events.on_gui_text_changed and event.name ~= defines.events.on_gui_value_changed then return end
        local selected = pdata.selected
        local config_tmp = pdata.config_tmp
        local item_config = config_tmp.config[selected]
        if not selected or not item_config then
            error("Request amount changed without a selected item")
        end
        local number
        if event.name == defines.events.on_gui_text_changed then
            number = tonumber_max(event.element.text) or 0
        elseif event.name == defines.events.on_gui_value_changed then
            number = tonumber_max(convert_from_slider(event.element.slider_value)) or 0
        end
        if number == item_config.request then return end
        if item_config.request == 0 and number > 0 then
            config_tmp.c_requests = config_tmp.c_requests + 1
        end
        if item_config.request > 0 and number == 0 then
            config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
        end
        item_config.request = number
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and number > item_config.trash then
            item_config.trash = number
        end
        GUI.mark_dirty(pdata)
        GUI.update_button(pdata, selected, selected)
        GUI.update_sliders(pdata)
    end,

    trash_amount_changed = function(event, pdata)
        if event.name ~= defines.events.on_gui_text_changed and event.name ~= defines.events.on_gui_value_changed then return end
        local selected = pdata.selected
        local config_tmp = pdata.config_tmp
        local item_config = config_tmp.config[selected]
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
                if item_config.request > 0 and number == 0 then
                    config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
                end
                item_config.request = number
            end
        end
        item_config.trash = number
        GUI.mark_dirty(pdata)
        GUI.update_button(pdata, selected, selected)
        GUI.update_sliders(pdata)
    end,

    toggle_pause_trash = function(event, pdata)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        if event.element.state then
            pause_trash(event.player, pdata)
        else
            unpause_trash(event.player, pdata)
        end
        GUI.update_main_button(pdata)
    end,

    toggle_pause_requests = function(event, pdata)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        if event.element.state then
            lib_control.pause_requests(event.player, pdata)
        else
            lib_control.unpause_requests(event.player, pdata)
        end
        GUI.update_main_button(pdata)
    end,

    toggle_trash_option = function(event, pdata)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        local settings = pdata.settings
        settings[event.element.name] = event.element.state
        if not settings.pause_trash then
            set_trash(event.player, pdata)
        end
    end,

    toggle_trash_network = function(event, pdata)
        if event.name ~= defines.events.on_gui_checked_state_changed then return end
        local element = event.element
        local player = event.player
        if element.state and not pdata.main_network then
            player.print("No main network set")
            element.state = false
        else
            pdata.settings.trash_network = element.state
            if element.state and in_network(player, pdata) then
                unpause_trash(player, pdata)
                GUI.update_main_button(pdata)
            end
        end
    end,

    export_config = function(event, pdata)
        local player = event.player
        local stack = player.cursor_stack
        if not stack then return end
        if stack.valid_for_read and not (stack.name == "blueprint" and not stack.is_blueprint_setup()) then
            player.print("Click with an empty cursor or an empty blueprint")
            return
        end
        if not stack.set_stack{name = "blueprint", count = 1} then
            player.print({"", {"error-while-importing-string"}, " Could not set stack"})
            log("Error setting stack")
            return
        end
        local ents, icons = presets.export(pdata.config_tmp)
        stack.set_blueprint_entities(ents)
        stack.blueprint_icons = icons
        if table_size(pdata.selected_presets) == 1 then
            stack.label = "AutoTrash_" .. next(pdata.selected_presets)
        else
            stack.label = "AutoTrash_configuration"
        end
        if event.shift then
            if player.mod_settings["autotrash_open_library"].value then
                player.opened = defines.gui_type.blueprint_library
            end
            return
        end

        local text = stack.export_stack()
        stack.clear()--the blueprint we spawned in
        local gui = player.gui.center
        local frame = gui.add{type = "frame", caption = {"gui.export-to-string"}, direction = "vertical"}
        local textfield = frame.add{type = "text-box"}
        textfield.word_wrap = true
        textfield.read_only = true
        textfield.style.height = player.display_resolution.height * 0.3 / player.display_scale
        textfield.style.width = player.display_resolution.width * 0.3 / player.display_scale
        textfield.text = text
        textfield.select_all()
        textfield.focus()
        local flow = frame.add{type = "flow", direction = "horizontal"}
        flow.style.horizontally_stretchable = true
        local pusher = flow.add{type = "flow"}
        pusher.style.horizontally_stretchable = true
        GUI.register_action(
            pdata,
            flow.add{type = "button", caption = {"gui.close"}, style = "dialog_button"},
            {type = "import_export_close", frame = frame}
        )
    end,

    import_config = function(event, pdata)
        local player = event.player
        local stack = player.cursor_stack
        if not stack then return end
        if stack and stack.valid_for_read and stack.name == "blueprint" and stack.is_blueprint_setup() then
            pdata.config_tmp = presets.import(stack.get_blueprint_entities(), stack.blueprint_icons)
            player.print({"string-import-successful", "AutoTrash configuration"})
            pdata.selected = false
            if stack.label ~= "Autotrash_configuration" then
                local textfield = pdata.gui_elements.storage_textfield
                if textfield and textfield.valid then
                    textfield.text = string.sub(stack.label, 11)
                end
            end
            GUI.update_buttons(player, pdata)
            GUI.hide_sliders(pdata)
            return
        end
        local gui = player.gui.center
        local frame = gui.add{type = "frame", caption = {"gui-blueprint-library.import-string"}, direction = "vertical"}
        local textfield = frame.add{type = "text-box"}
        textfield.word_wrap = true
        textfield.focus()
        textfield.style.height = player.display_resolution.height * 0.3 / player.display_scale
        textfield.style.width = player.display_resolution.width * 0.3 / player.display_scale
        local flow = frame.add{type = "flow", direction = "horizontal"}
        flow.style.horizontally_stretchable = true
        GUI.register_action(
            pdata,
            flow.add{type = "button", caption = {"gui.close"}, style = "dialog_button"},
            {type = "import_export_close", frame = frame}
        )
        local pusher = flow.add{type = "flow"}
        pusher.style.horizontally_stretchable = true
        GUI.register_action(
            pdata,
            flow.add{type = "button", caption = {"gui-blueprint-library.import"}, style = "confirm_button"},
            {type = "import_confirm", frame = frame, textfield = textfield}
        )
    end,

    import_confirm = function(event, pdata, params)
        local player = event.player
        local frame, textfield = params.frame, params.textfield
        if not (frame and frame.valid) then return end
        if not (textfield and textfield.valid) then return end
        local stack = player.cursor_stack
        if not stack then return end
        if stack.valid_for_read and not (stack.name == "blueprint" and not stack.is_blueprint_setup()) then
            player.print("Click with an empty cursor or empty blueprint")
            return
        end
        if not stack.set_stack{name = "blueprint", count = 1} then
            player.print({"", {"error-while-importing-string"}, " Could not set stack"})
            GUI.deregister_action(frame, pdata, true)
            return
        end
        stack.import_stack(textfield.text)
        pdata.selected = false
        pdata.config_tmp = presets.import(stack.get_blueprint_entities(), stack.blueprint_icons)
        if stack.label ~= "Autotrash_configuration" then
            textfield = pdata.gui_elements.storage_textfield
            if textfield and textfield.valid then
                textfield.text = string.sub(stack.label, 11)
            end
        end
        stack.clear()--the blueprint we spawned in
        player.print({"string-import-successful", "AutoTrash configuration"})
        GUI.update_buttons(player, pdata)
        GUI.hide_sliders(pdata)
        GUI.deregister_action(frame, pdata, true)
    end,

    import_export_close = function(_, _, params, pdata)
        GUI.deregister_action(params.frame, pdata, true)
    end,
}

function GUI.deregister_action(element, pdata, destroy)
    if not (element and element.valid) then return end
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then
        return
    end
    player_gui_actions[element.index] = nil
    for k, child in pairs(element.children) do
        GUI.deregister_action(child, pdata)
    end
    if destroy then
        element.destroy()
    end
end

--[[
    params = {
        type: function name
    }
--]]
function GUI.register_action(pdata, element, params)
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then
        pdata.gui_actions = {}
        player_gui_actions = pdata.gui_actions
    end
    player_gui_actions[element.index] = params
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
    local player_index = event.player_index
    local pdata = global._pdata[player_index]
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then return end

    local action = player_gui_actions[gui.index]
    if not action then return end

    local player = game.get_player(player_index)
    local profile_inner = game.create_profiler()
    local status, err = pcall(function()
        profile_inner.reset()
        if not player.character then
            GUI.close(player, pdata, true)
            GUI.close_quick_presets(pdata)
            player.print({"autotrash_no_character"})
            return
        end
        event.player = player
        gui_functions[action.type](event, pdata, action)
        profile_inner.stop()
    end)
    -- log{"", "Inner: ", profile_inner}
    --log("Selected: " .. tostring(pdata.selected))
    --log("Registered gui actions:" .. table_size(player_gui_actions))
    if not status then
        log("Error running event: " .. tostring(GUI.get_event_name(event.name)))
        log("Event: " .. serpent.line(event))
        log("Action: " ..serpent.line(action and action.type))
        log(serpent.block(pdata.config_tmp, {name = "config_tmp", comment = false}))
        lib_control.debugDump(err, player, true)
        local s
        for name, elem in pairs(pdata.gui_elements) do
            s = name .. ": "
            if elem and not elem.valid then
                log(s .. "invalid")
            elseif not elem then
                log(s .. "nil")
            end
        end
    end
end

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)
    local main_flow = button_flow[GUI.defines.main_button_flow]
    if main_flow and main_flow.valid then return end
    local pdata = global._pdata[player.index]
    local main_button = pdata.gui_elements.main_button
    if main_button and main_button.valid then return end
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
        pdata.gui_elements.main_button = button
        GUI.register_action(pdata, button, {type = "main_button"})
    end
end

function GUI.update_main_button(pdata)
    local mainButton = pdata.gui_elements.main_button
    if not (mainButton and mainButton.valid) then
        return
    end
    local settings = pdata.settings
    if settings.pause_trash and not settings.pause_requests then
        mainButton.sprite = "autotrash_trash_paused"
    elseif settings.pause_requests and not settings.pause_trash then
        mainButton.sprite = "autotrash_requests_paused"
    elseif settings.pause_trash and settings.pause_requests then
        mainButton.sprite = "autotrash_both_paused"
    else
        mainButton.sprite = "autotrash_trash"
    end
    GUI.update_settings(pdata)
end

function GUI.update_settings(pdata)
    local frame = pdata.gui_elements.trash_options
    if not (frame and frame.valid) then return end
    local settings = pdata.settings
    local def = GUI.defines
    frame[def.trash_unrequested].state = settings.trash_unrequested
    frame[def.trash_above_requested].state = settings.trash_above_requested
    frame[def.trash_network].state = settings.trash_network
    frame[def.pause_trash].state = settings.pause_trash
    frame[def.pause_requests].state = settings.pause_requests
    frame[def.network_button].caption = pdata.main_network and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
end

function GUI.delete(pdata)
    for _, element in pairs(pdata.gui_elements) do
        GUI.deregister_action(element, pdata, true)
    end
    pdata.gui_elements = {}
end

function GUI.mark_dirty(pdata, keep_presets)
    local reset = pdata.gui_elements.reset_button
    if not (reset and reset.valid) then return end
    reset.enabled = true
    pdata.dirty = true
    if not keep_presets then
        pdata.selected_presets = {}
    end
    GUI.update_presets(pdata)
end

function GUI.hide_sliders(pdata)
    pdata.selected = false
    local slider_flow = pdata.gui_elements.slider_flow
    if not (slider_flow and slider_flow.valid) then return end
    for _, child in pairs(slider_flow.children) do
        child.visible = false
    end
end

function GUI.update_sliders(pdata)
    local slider_flow = pdata.gui_elements.slider_flow
    if not (slider_flow and slider_flow.valid) then return end
    local selected = pdata.selected
    if not selected then GUI.hide_sliders(pdata) return end

    local item_config = pdata.config_tmp.config[selected]
    if not item_config then
        error("Update sliders without a selected item")
    end
    local visible = item_config and true or false
    for _, child in pairs(slider_flow.children) do
        child.visible = visible
    end
    if visible then
        local def = GUI.defines
        slider_flow[def.config_request][def.config_slider].slider_value = convert_to_slider(item_config.request)
        slider_flow[def.config_request][def.config_slider_text].text = format_request(item_config) or 0
        slider_flow[def.config_trash][def.config_slider].slider_value = item_config.trash and convert_to_slider(item_config.trash) or 42
        slider_flow[def.config_trash][def.config_slider_text].text = format_trash(item_config) or "∞"
    end
end

function GUI.update_button(pdata, i, selected, button)
    if not (button and button.valid) then
        local config_grid = pdata.gui_elements.ruleset_grid
        if not (config_grid and config_grid.valid) then return end
        if not (i and config_grid.children[i] and config_grid.children[i].valid) then return end
        button = config_grid.children[i]
    end
    local req = pdata.config_tmp.config[i]
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
    GUI.register_action(pdata, button, {type = "config_button_changed", slot = i, item = button.elem_value})
end

local function get_network_data(player)
    local character = player.character
    local network = character.logistic_network
    local requester = character.get_logistic_point(defines.logistic_member_index.character_requester)
    if not (network and requester) then
        return
    end
    local on_the_way = requester.targeted_items_deliver
    local available = network.get_contents()
    local item_count = player.get_main_inventory().get_contents()
    local cursor_stack = player.cursor_stack
    cursor_stack = (cursor_stack and cursor_stack.valid_for_read) and {[cursor_stack.name] = cursor_stack.count} or {}
    local get_inventory, inventory = player.get_inventory, defines.inventory
    local armor = get_inventory(inventory.character_armor).get_contents()
    local gun = get_inventory(inventory.character_guns).get_contents()
    local ammo = get_inventory(inventory.character_ammo).get_contents()

    return available, on_the_way, item_count, cursor_stack, armor, gun, ammo
end

function GUI.get_button_style(i, selected, item, available, on_the_way, item_count, cursor_stack, armor, gun, ammo, paused)
    if paused or not (available and on_the_way and item and item.request > 0) then
        return (i == selected) and "at_button_slot_selected" or "at_button_slot"
    end
    if i == selected then
        return "at_button_slot_selected"
    end
    local n, c = item.name, item.request
    local diff = c - (item_count[n] or 0) + (armor[n] or 0) + (gun[n] or 0) + (ammo[n] or 0) + (cursor_stack[n] or 0)

    if diff <= 0 then
        return "at_button_slot"
    else
        diff = diff - (on_the_way[n] or 0) - (available[n] or 0)
        if diff <= 0 then
            return "at_button_slot_items_on_the_way"
        elseif --(on_the_way[n] and not available[n]) then
        item.name == "locomotive" then
            return "at_button_slot_items_not_enough"
        end
        return "at_button_slot_items_not_available"
    end
end

function GUI.update_button_styles(player, pdata)
    local ruleset_grid = pdata.gui_elements.ruleset_grid
    if not (ruleset_grid and ruleset_grid.valid) then return end
    local selected = pdata.selected
    local config = pdata.config_tmp
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)

    if not (available and on_the_way and config.c_requests > 0 and not pdata.settings.pause_requests) then
        for i, button in pairs(ruleset_grid.children) do
            button.style = (i == selected) and "at_button_slot_selected" or "at_button_slot"
        end
        return true
    end
    config = config.config
    for i, button in pairs(ruleset_grid.children) do
        button.style = GUI.get_button_style(i, selected, config[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo)
    end
    return true
end

function GUI.update_buttons(player, pdata)
    local ruleset_grid = pdata.gui_elements.ruleset_grid
    if not (ruleset_grid and ruleset_grid.valid) then return end

    local selected = pdata.selected
    local config = pdata.config_tmp.config
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)

    for i, button in pairs(ruleset_grid.children) do
        GUI.update_button(pdata, i, selected, button)
        button.style = GUI.get_button_style(i, selected, config[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo, pdata.settings.pause_requests)
    end
end

function GUI.create_buttons(player, start, pdata)
    local scroll_pane = pdata.gui_elements.config_scroll
    if not (scroll_pane and scroll_pane.valid) then return end
    local ruleset_grid = scroll_pane.children[1]
    if ruleset_grid and ruleset_grid.valid and not start then
        GUI.deregister_action(ruleset_grid, pdata, true)
        pdata.gui_elements.ruleset_grid = nil
    end
    local columns = player.mod_settings["autotrash_gui_columns"].value
    local config_tmp = pdata.config_tmp
    local max_slot = config_tmp.max_slot or columns
    local slots = player.character.request_slot_count
    slots = slots > columns and slots or columns
    slots = slots > max_slot and slots or max_slot

    --if the last button is occupied add a new row
    if config_tmp.config[slots] then
        slots = slots + columns
    end

    local selected = pdata.selected
    if not start then
        ruleset_grid = scroll_pane.add{
            type = "table",
            column_count = columns,
            style = "slot_table"
        }
        start = 1
    else
        for i = start, slots do
            GUI.deregister_action(ruleset_grid.children[i], pdata, true)
        end
    end
    pdata.gui_elements.ruleset_grid = ruleset_grid
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)
    local button
    config_tmp = config_tmp.config
    for i = start, slots do
        button = ruleset_grid.add{
            type = "choose-elem-button",
            elem_type = "item",
            style = "at_button_slot"
        }

        button.add{
            type = "label",
            style = "at_request_label_top",
            ignored_by_interaction = true,
            caption = ""
        }
        button.add{
            type = "label",
            style = "at_request_label_bottom",
            ignored_by_interaction = true,
            caption = ""
        }
        GUI.update_button(pdata, i, selected, button)
        button.style = GUI.get_button_style(i, selected, config_tmp[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo, pdata.settings.pause_requests)
    end
    return slots
end

function GUI.open_quick_presets(pdata)
    local button_flow = pdata.gui_elements.main_button.parent
    if not (button_flow and button_flow.valid) then return end

    local quick_name = GUI.defines.quick_presets
    if button_flow[quick_name] and button_flow[quick_name].valid then
        GUI.deregister_action(button_flow[quick_name], pdata, true)
        return
    end

    local quick_presets = button_flow.add{
        type = "list-box",
        name = quick_name
    }

    local i = 1
    local tmp = {}
    for key, _ in pairs(pdata.storage_new) do
        tmp[i] = key
        i = i + 1
    end
    quick_presets.items = tmp
    GUI.register_action(pdata, quick_presets, {type = "load_quick_preset"})
end

function GUI.close_quick_presets(pdata)
    local button_flow = pdata.gui_elements.main_button.parent
    if not (button_flow and button_flow.valid) then return end
    GUI.deregister_action(button_flow[GUI.defines.quick_presets], pdata, true)
end

function GUI.update_status_flow(player, pdata)
    local status_flow = pdata.gui_elements.status_flow
    if not (status_flow and status_flow.valid) then
        return
    end

    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)
    status_flow.clear()
    if not (available and not pdata.settings.pause_requests) then
        return true
    end
    local config_tmp = pdata.config_new.config
    local style
    -- local button
    local c = 0
    local max_count = player.mod_settings["autotrash_status_count"].value
    local character = player.character
    local get_request_slot = character.get_request_slot--luacheck: ignore
    local item--luacheck: ignore
    for i = 1, character.request_slot_count do
        item = get_request_slot(i)
        if item and item.count > 0 then
    --TODO: looping over config_tmp is slightly faster, but may be out of sync with the actual requests
    -- for i, item in pairs(config_tmp) do--luacheck: ignore
    --     if item and item.request > 0 then
            if c >= max_count then break end
            style = GUI.get_button_style(i, false, config_tmp[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo)
            if style ~= "at_button_slot" then
                status_flow.add{
                    type = "sprite-button",
                    style = style,
                    ignored_by_interaction = true,
                }.sprite = "item/" .. item.name
                c = c + 1
            end
        end
    end
    return true
end

function GUI.open_status_flow(player, pdata)
    local left = mod_gui.get_frame_flow(player)
    local gui_elements = pdata.gui_elements

    local status_flow = gui_elements.status_flow
    if status_flow and status_flow.valid then
        GUI.deregister_action(status_flow, pdata, true)
        gui_elements.status_flow = nil
    end
    local mod_settings = player.mod_settings
    status_flow = left.add{
        type = "table",
        style = "at_request_status_table",
        column_count = mod_settings["autotrash_status_columns"].value
    }
    gui_elements.status_flow = status_flow

    local max_count, c = mod_settings["autotrash_status_count"].value, 0
    local config_tmp = pdata.config_new.config
    local style
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)
    for i, item in pairs(config_tmp) do
        if c >= max_count then break end
        if item and item.request > 0 then
            style = GUI.get_button_style(i, false, config_tmp[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo, pdata.settings.pause_requests)
            if style ~= "at_button_slot" then
                status_flow.add{
                    type = "sprite-button",
                    style = style,
                    ignored_by_interaction = true,
                }.sprite = "item/" .. item.name
                c = c + 1
            end
        end
    end
end

function GUI.close_status_flow(pdata)
    local gui_elements = pdata.gui_elements

    local status_flow = gui_elements.status_flow
    if status_flow and status_flow.valid then
        GUI.deregister_action(status_flow, pdata, true)
    end
    gui_elements.status_flow = nil
end

function GUI.open_logistics_frame(player, pdata)
    hide_yarm(player, pdata)
    local left = mod_gui.get_frame_flow(player)
    local gui_elements = pdata.gui_elements
    local gui_defines = GUI.defines
    pdata.selected = false

    local frame = left.add{
        type = "frame",
        style = "at_logistics_frame",
        caption = {"gui-logistic.title"},
        direction = "vertical"
    }
    gui_elements.config_frame = frame

    local config_flow_v = frame.add{
        type = "frame",
        style = "at_bordered_frame",
        direction = "vertical",
    }

    local config_flow_h = config_flow_v.add{
        type = "flow",
        name = gui_defines.config_flow_h,
        direction = "horizontal"
    }

    local scroll_pane = config_flow_h.add{
        type = "scroll-pane",
        vertical_scroll_policy = "auto-and-reserve-space"
    }
    scroll_pane.style.maximal_height = 38 * player.mod_settings["autotrash_gui_max_rows"].value + 6
    gui_elements.config_scroll = scroll_pane

    local button_flow = config_flow_h.add{
        type = "flow",
        direction = "vertical",
        style = "shortcut_bar_column"
    }
    local checkmark = button_flow.add{
        type = "sprite-button",
        style = "at_shortcut_bar_button_green",
        sprite = "utility/check_mark_white"
    }

    GUI.register_action(pdata, checkmark, {type = "apply_changes"})

    local reset_button = button_flow.add{
        type = "sprite-button",
        style = "shortcut_bar_button_red",
        sprite = "utility/reset_white"
    }
    reset_button.enabled = pdata.dirty

    gui_elements.reset_button = reset_button
    GUI.register_action(pdata, reset_button, {type = "reset_changes"})

    -- GUI.register_action(pdata, button_flow.add{
    --         type = "sprite-button",
    --         style = "at_shortcut_bar_button",
    --         sprite = "item/blueprint",
    --         tooltip = {"autotrash_request_blueprint"}
    --     },
    --     {type = "request_blueprint"}
    -- )

    local export_btn = button_flow.add{
        type = "sprite-button",
        style = "at_shortcut_bar_button_blue",
        sprite = "utility/export_slot",
        tooltip = {"autotrash_export_tt"}
    }
    GUI.register_action(pdata, export_btn, {type = "export_config"})

    local import_btn = button_flow.add{
        type = "sprite-button",
        style = "at_shortcut_bar_button_blue",
        sprite = "utility/import_slot",
        tooltip = {"autotrash_import_tt"}
    }
    GUI.register_action(pdata, import_btn, {type = "import_config"})

    local slider_vertical_flow = config_flow_v.add{
        type = "table",
        style = "at_slider_table",
        column_count = 2
    }
    gui_elements.slider_flow = slider_vertical_flow

    slider_vertical_flow.add{
        type = "label",
        caption = {"gui-logistic.title-request-short"}
    }
    local slider_flow_request = slider_vertical_flow.add{
        type = "flow",
        style = "at_slider_flow",
        name = gui_defines.config_request,
    }

    local request_slider = slider_flow_request.add{
        type = "slider",
        name = gui_defines.config_slider,
        minimum_value = 0,
        maximum_value = 41,
    }
    GUI.register_action(pdata, request_slider, {type = "request_amount_changed"})

    local request_textfield = slider_flow_request.add{
        type = "textfield",
        name = gui_defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(pdata, request_textfield, {type = "request_amount_changed"})

    slider_vertical_flow.add{
        type = "label",
        caption = {"auto-trash-trash"}
    }
    local slider_flow_trash = slider_vertical_flow.add{
        type = "flow",
        style = "at_slider_flow",
        name = gui_defines.config_trash,
    }

    local trash_slider = slider_flow_trash.add{
        type = "slider",
        name = gui_defines.config_slider,
        minimum_value = 0,
        maximum_value = 42,
    }
    GUI.register_action(pdata, trash_slider, {type = "trash_amount_changed"})

    local trash_textfield = slider_flow_trash.add{
        type = "textfield",
        name = gui_defines.config_slider_text,
        style = "slider_value_textfield",
    }
    GUI.register_action(pdata, trash_textfield, {type = "trash_amount_changed"})

    GUI.hide_sliders(pdata)

    GUI.create_buttons(player, nil, pdata)

    local quick_actions = config_flow_v.add{
        type = "drop-down",
        style = "at_quick_actions",
        items = {
            [1] = "Quick actions",
            [2] = "Clear requests",
            [3] = "Clear trash",
            [4] = "Clear both",
            [5] = "Set trash to requests",
            [6] = "Set requests to trash"
        },
        selected_index = 1
    }

    GUI.register_action(pdata, quick_actions, {type = "quick_actions"})

    local trash_options = frame.add{
        type = "frame",
        style = "at_bordered_frame",
        direction = "vertical",
    }
    gui_elements.trash_options = trash_options

    local settings = pdata.settings

    GUI.register_action(pdata, trash_options.add{
                            type = "checkbox",
                            name = gui_defines.trash_above_requested,
                            caption = {"auto-trash-above-requested"},
                            state = settings[gui_defines.trash_above_requested]
                        },
                        {type = "toggle_trash_option"})

    GUI.register_action(pdata, trash_options.add{
                            type = "checkbox",
                            name = gui_defines.trash_unrequested,
                            caption = {"auto-trash-unrequested"},
                            state = settings[gui_defines.trash_unrequested]
                        },
                        {type = "toggle_trash_option"})

    GUI.register_action(pdata, trash_options.add{
                            type = "checkbox",
                            name = gui_defines.trash_network,
                            caption = {"auto-trash-in-main-network"},
                            state = settings[gui_defines.trash_network]
                        },
                        {type = "toggle_trash_network"})

    GUI.register_action(pdata, trash_options.add{
                            type = "checkbox",
                            name = gui_defines.pause_trash,
                            caption = {"auto-trash-config-button-pause"},
                            tooltip = {"auto-trash-tooltip-pause"},
                            state = settings.pause_trash
                        },
                        {type = "toggle_pause_trash"})

    GUI.register_action(pdata, trash_options.add{
                            type = "checkbox",
                            name = gui_defines.pause_requests,
                            caption = {"auto-trash-config-button-pause-requests"},
                            tooltip = {"auto-trash-tooltip-pause-requests"},
                            state = settings.pause_requests
                        },
                        {type = "toggle_pause_requests"})

    GUI.register_action(pdata, trash_options.add{
                type = "button",
                name = gui_defines.network_button,
                caption = pdata.main_network and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
                },
                {type = "set_main_network"}
    )

    GUI.open_presets_frame(left, pdata)
end

function GUI.open_presets_frame(left, pdata)
    local gui_elements = pdata.gui_elements
    left = left or gui_elements.config_frame.parent
    local storage_frame = left.add{
        type = "frame",
        caption = {"auto-trash-storage-frame-title"},
        direction = "vertical"
    }
    gui_elements.storage_frame = storage_frame


    local storage_frame_buttons = storage_frame.add{
        type = "flow",
        style = "at_storage_frame_button_flow",
        direction = "horizontal",
        name = "auto-trash-logistics-storage-buttons"
    }

    local save_as = storage_frame_buttons.add{
        type = "textfield",
        style = "at_save_as_textfield",
        text = ""
    }

    local save_button = storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save"},
        style = "at_save_button"
    }

    gui_elements.storage_textfield = save_as
    GUI.register_action(pdata, save_button, {type = "save_preset"})

    local storage_scroll = storage_frame.add{
        type = "scroll-pane",
    }
    storage_scroll.style.maximal_height = math.ceil(38*10+4)

    local storage_grid = storage_scroll.add{
        type = "flow",
        style = "at_storage_grid_flow",
        direction = "vertical"
    }
    gui_elements.storage_grid = storage_grid

    for key, _ in pairs(pdata.storage_new) do
        GUI.add_preset(key, pdata)
    end
    GUI.update_presets(pdata)
end

function GUI.close(player, pdata, no_reset)
    local elements = pdata.gui_elements
    local storage_frame = elements.storage_frame
    local frame = elements.config_frame

    if storage_frame and storage_frame.valid then
        GUI.deregister_action(storage_frame, pdata, true)
        elements.storage_frame = nil
        elements.storage_textfield = nil
        elements.storage_grid = nil
    end
    if frame and frame.valid then
        GUI.deregister_action(frame, pdata, true)
        elements.config_frame = nil
        elements.config_scroll = nil
        elements.ruleset_grid = nil
        elements.slider_flow = nil
        elements.trash_options = nil
        elements.reset_button = nil
    end
    pdata.selected = false
    if not no_reset and player.mod_settings["autotrash_reset_on_close"].value then
        pdata.config_tmp = util.table.deepcopy(pdata.config_new)
        pdata.dirty = false
    end
    show_yarm(player, pdata)
end

function GUI.update_presets(pdata)
    local storage_grid = pdata.gui_elements.storage_grid
    if not (storage_grid and storage_grid.valid) then return end
    local children = storage_grid.children
    local selected_presets = pdata.selected_presets
    local death_presets = pdata.death_presets
    local preset_name, rip, preset
    for i=1, #children do
        preset = children[i].children[1]
        preset_name = preset.caption
        if selected_presets[preset_name] then
            preset.style = "at_preset_button_selected"
        else
            preset.style = "at_preset_button"
        end
        rip = children[i].children[2]
        rip.style = death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
    end
    local s = table_size(selected_presets)
    if s == 1 then
        pdata.gui_elements.storage_textfield.text = next(selected_presets)
    elseif s > 1 or s == 0 then
        pdata.gui_elements.storage_textfield.text = ""
    end
end

function GUI.add_preset(preset_name, pdata)
    local storage_grid = pdata.gui_elements.storage_grid
    if not (storage_grid and storage_grid.valid) then return end

    local preset_flow = storage_grid.add{
        type = "flow",
        direction = "horizontal"
    }

    local preset = preset_flow.add{
        type = "button",
        style = "at_preset_button",
        caption = preset_name,
        name = preset_name
    }

    local rip = preset_flow.add{
        type = "sprite-button",
        style = "at_preset_button_small",
        sprite = "autotrash_rip",
        tooltip = {"autotrash_tooltip_rip"}
    }

    local remove = preset_flow.add{
        type = "sprite-button",
        style = "at_delete_preset",
        sprite = "utility/remove"
    }

    GUI.register_action(pdata, preset, {type = "load_preset"})
    GUI.register_action(pdata, remove, {type = "delete_preset", name = preset_name, rip_button = rip})
    GUI.register_action(pdata, rip, {type = "change_death_preset", name = preset_name})
end

return GUI
