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
        main_button = "at-config-button",
        main_button_flow = "auto-trash-main-flow", --Don't rename, preserves top button order in existing saves
        quick_presets = "at_quick_presets",

        config_frame = "at-config-frame",
        config_scroll = "at_config_scroll",
        config_grid = "at_ruleset_grid",

        storage_frame = "at-logistics-storage-frame",
        storage_scroll = "at_storage_scroll",

        trash_above_requested = "autotrash_above_requested",
        trash_unrequested = "autotrash_unrequested",
        trash_in_main_network = "autotrash_in_main_network",

        button_flow = "autotrash_button_flow",

        trash_options = "autotrash_trash_options",
        pause_trash = "autotrash_pause_trash",
        pause_requests = "autotrash_pause_requests",
        config_request = "at_config_request",
        config_trash = "at_config_trash",
        config_slider = "at_config_slider",
        config_slider_text = "at_config_slider_text",

        choose_button = "autotrash_item_",
        load_preset = "autotrash_preset_load_",
        delete_preset = "autotrash_preset_delete_"
    },
}

local def = GUI.defines

local gui_functions = {
    main_button = function(event, player)
        local element = event.element
        if event.button == defines.mouse_button_type.right then
            GUI.open_quick_presets(player, element.parent)
        else
            GUI.close_quick_presets(player, element.parent)
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

    apply_changes = function(_, player)
        local player_index = player.index
        global.config_new[player_index] = util.table.deepcopy(global.config_tmp[player_index])
        global.dirty[player_index] = false
        global.gui_elements.reset_button[player_index].enabled = false
        if player.mod_settings["autotrash_close_on_apply"].value then
            GUI.close(player)
        end

        if not global.settings[player.index].pause_trash then
            set_trash(player)
        end
        if not global.settings[player.index].pause_requests then
            set_requests(player)
        end
    end,

    reset_changes = function(event, player)
        if global.dirty[player.index] then
            global.config_tmp[player.index] = util.table.deepcopy(global.config_new[player.index])
            event.element.enabled = false
            global.selected[player.index] = false
            global.selected_presets[player.index] = {}
            global.dirty[player.index] = false
            GUI.create_buttons(player)
            GUI.update_sliders(player)
            GUI.update_presets(player)
        end
    end,

    clear_config = function(_, player)
        local player_index = player.index
        local mode = global.settings[player.index].clear_option
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
        GUI.create_buttons(player)
    end,

    clear_option_changed = function(event, player, params)--luacheck: ignore
        if event.name ~= defines.events.on_gui_selection_state_changed then return end
        global.settings[player.index].clear_option = event.element.selected_index
    end,

    save_preset = function(_, player, params)
        local player_index = player.index
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
        GUI.add_preset(player, name, table_size(global.storage_new[player_index]))
        global.selected_presets[player_index] = {[name] = true}
        GUI.update_presets(player)
    end,

    set_main_network = function(event, player)
        local player_index = player.index
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

    import_from_vanilla = function(_, player)
        global.config_tmp[player.index] = combine_from_vanilla(player)
        GUI.create_buttons(player)
        GUI.update_sliders(player)
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
    log(serpent.block(global.gui_actions[element.player_index]))
end

function GUI.generic_event(event, player)
    local gui = event.element
    if not (gui and gui.valid) then return end

    local player_gui_actions = global.gui_actions[gui.player_index]
    if not player_gui_actions then return end

    local action = player_gui_actions[gui.index]
    if not action then return end
    log(serpent.line({action, event}))
    gui_functions[action.type](event, player, action)
    log(serpent.block(global.gui_elements))
    return true
end


function GUI.get_ruleset_grid(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    return frame[def.config_flow_h] and frame[def.config_flow_h][def.config_scroll] and frame[def.config_flow_h][def.config_scroll][def.config_grid]
end

function GUI.index_from_name(name)
    return tonumber(string.match(name, GUI.defines.choose_button .. "(%d+)"))
end

function GUI.init(player)
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow[GUI.defines.main_button_flow] then
        return
    end
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
        GUI.register_action(button, {type = "main_button"})
    end
end

function GUI.update(player)
    local mainButton = mod_gui.get_button_flow(player)[GUI.defines.main_button_flow]
    mainButton = mainButton and mainButton[GUI.defines.main_button]
    if not mainButton then
        return
    end
    local settings = global.settings[player.index]
    if settings.pause_trash and not settings.pause_requests then
        mainButton.sprite = "autotrash_trash_paused"
    elseif settings.pause_requests and not settings.pause_trash then
        mainButton.sprite = "autotrash_requests_paused"
    elseif settings.pause_trash and settings.pause_requests then
        mainButton.sprite = "autotrash_both_paused"
    else
        mainButton.sprite = "autotrash_trash"
    end
    GUI.update_settings(player)
end

function GUI.update_settings(player)
    local frame = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    frame = frame[GUI.defines.trash_options]
    if not frame or not frame.valid then return end
    local settings = global.settings[player.index]
    frame[GUI.defines.trash_unrequested].state = settings.auto_trash_unrequested
    frame[GUI.defines.trash_above_requested].state = settings.auto_trash_above_requested
    frame[GUI.defines.trash_in_main_network].state = settings.auto_trash_in_main_network
    frame[GUI.defines.pause_trash].state = settings.pause_trash
    frame[GUI.defines.pause_requests].state = settings.pause_requests
end

function GUI.delete(player)
    local player_index = player.index
    for k, guis in pairs(global.gui_elements) do
        local element = guis[player_index]
        if element and element.valid then
            GUI.deregister_action(element)
            element.destroy()
        end
        guis[player_index] = nil
    end
end

function GUI.update_sliders(player)
    local left = mod_gui.get_frame_flow(player)[GUI.defines.config_frame]
    local slider_flow = left and left.valid and left["at_slider_flow_vertical"]
    if not slider_flow or not slider_flow.valid then
        return
    end
    local player_index = player.index
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

--creates/updates the choose-elem-buttons (update because i do something wierd with locked = true)
function GUI.create_buttons(player)
    local left = mod_gui.get_frame_flow(player)
    local frame = (left and left.valid) and left[GUI.defines.config_frame]
    if not frame or not frame.valid then
        return
    end
    frame = frame[GUI.defines.config_flow_h]

    local scroll_pane = frame[def.config_scroll]
    scroll_pane = scroll_pane or frame.add{
        type = "scroll-pane",
        name = def.config_scroll,
    }
    local mod_settings = player.mod_settings
    local display_rows = mod_settings["autotrash_gui_max_rows"].value
    scroll_pane.style.maximal_height = 38 * display_rows + 6

    local ruleset_grid = scroll_pane[def.config_grid]
    if ruleset_grid and ruleset_grid.valid then
        ruleset_grid.destroy()
    end

    ruleset_grid = scroll_pane.add{
        type = "table",
        column_count = mod_settings["autotrash_gui_columns"].value,
        name = def.config_grid,
        style = "slot_table"
    }

    local player_index = player.index
    local slots = mod_settings["autotrash_slots"].value or player.character.request_slot_count
    for i = 1, slots-1 do
        local req = global["config_tmp"][player_index].config[i]
        local elem_value = req and req.name or nil
        local button_name = GUI.defines.choose_button .. i
        local choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = button_name,
            elem_type = "item"
        }
        choose_button.elem_value = elem_value
        choose_button.style = global.selected[player_index] == i and "at_button_slot_selected" or "at_button_slot"

        local lbl_top = choose_button.add{
            type = "label",
            style = "at_request_label_top",
            ignored_by_interaction = true,
            caption = " "
        }

        local lbl_bottom = choose_button.add{
            type = "label",
            style = "at_request_label_bottom",
            ignored_by_interaction = true,
            caption = " "
        }

        if elem_value then
            lbl_top.caption = format_number(format_request(req), true)
            lbl_bottom.caption = format_number(format_trash(req), true)
            --disable popup gui, keeps on_click active
            choose_button.locked = choose_button.name ~=  GUI.defines.choose_button .. tostring(global.selected[player_index])
        end
    end

    local extend_button_flow = ruleset_grid.add{
        type = "flow",
        name = "autotrash-extend-flow",
        direction = "vertical",
        style = "at_extend_flow"
    }

    local minus = extend_button_flow.add{
        type = "button",
        name = "autotrash-extend-less",
        caption = "-",
        style = "at_sprite_button"
    }
    local plus = extend_button_flow.add{
        type = "sprite-button",
        name = "autotrash-extend-more",
        caption = "+",
        style = "at_sprite_button"
    }
    minus.style.maximal_height = 16
    minus.style.minimal_width = 16
    minus.style.font = "default-bold"
    plus.style.maximal_height = 16
    plus.style.minimal_width = 16
    plus.style.font = "default-bold"
end

function GUI.open_quick_presets(player, main_flow)
    local button_flow = main_flow or mod_gui.get_button_flow(player)[GUI.defines.main_button_flow]
    if not button_flow or not button_flow.valid then
        return
    end
    if button_flow[GUI.defines.quick_presets] and button_flow[GUI.defines.quick_presets].valid then
        button_flow[GUI.defines.quick_presets].destroy()
        return
    end

    local quick_presets = button_flow.add{
        type = "list-box",
        name = GUI.defines.quick_presets
    }

    local i = 1
    local tmp = {}
    for key, _ in pairs(global.storage_new[player.index]) do
        tmp[i] = key
        i = i + 1
    end
    quick_presets.items = tmp
end

function GUI.close_quick_presets(player, main_flow)
    local button_flow = main_flow or mod_gui.get_button_flow(player)[GUI.defines.main_button_flow]
    if not button_flow or not button_flow.valid then
        return
    end
    if button_flow[GUI.defines.quick_presets] and button_flow[GUI.defines.quick_presets].valid then
        button_flow[GUI.defines.quick_presets].destroy()
        return
    end
end

function GUI.open_logistics_frame(player)
    local player_index = player.index
    assert(not global.selected[player.index], "selected should be false")
    log("Selected: " .. serpent.line(global.selected[player_index]))
    hide_yarm(player_index)
    local left = mod_gui.get_frame_flow(player)

    local frame = left.add{
        type = "frame",
        caption = {"gui-logistic.title"},
        name = GUI.defines.config_frame,
        direction = "vertical"
    }
    global.gui_elements.config_frame[player_index] = frame

    local config_flow_h = frame.add{
        type = "flow",
        name = GUI.defines.config_flow_h,
        direction = "horizontal"
    }

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
        name = "at_slider_flow_vertical",
        column_count = 2
    }
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
    slider_flow_request.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }

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
    slider_flow_trash.add{
        type = "textfield",
        name = GUI.defines.config_slider_text,
        style = "slider_value_textfield",
    }

    GUI.update_sliders(player)

    --TODO add a dropdown for quick actions, that apply to each item e.g.
    --Set trash to requested amount
    --Set trash to stack size
    --Set requests to stack size
    --in/decrease by 1 stack size

    local trash_options = frame.add{
        type = "frame",
        name = GUI.defines.trash_options,
        style = "bordered_frame",
        direction = "vertical",
    }
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
        name = GUI.defines.storage_frame,
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
        name = GUI.defines.storage_scroll
    }

    storage_scroll.style.maximal_height = math.ceil(38*10+4)
    local storage_grid = storage_scroll.add{
        type = "table",
        column_count = 2,
    }
    global.gui_elements.storage_grid[player_index] = storage_grid

    local i = 1
    for key, _ in pairs(global.storage_new[player_index]) do
        GUI.add_preset(player, key, i)
        i = i + 1
    end
    GUI.update_presets(player)
end

function GUI.close(player, frame_flow)
    local left = frame_flow or mod_gui.get_frame_flow(player)
    local storage_frame = left[GUI.defines.storage_frame]
    local frame = left[GUI.defines.config_frame]

    local gui_elements = global.gui_elements
    if storage_frame and storage_frame.valid then
        GUI.deregister_action(storage_frame)
        storage_frame.destroy()
        gui_elements.storage_frame[player.index] = nil
        gui_elements.storage_textfield[player.index] = nil
        gui_elements.storage_grid[player.index] = nil
    end
    if frame and frame.valid then
        GUI.deregister_action(frame)
        frame.destroy()
        gui_elements.config_frame[player.index] = nil
        gui_elements.clear_option[player.index] = nil
        gui_elements.reset_button[player.index] = nil
    end
    if player.mod_settings["autotrash_reset_on_close"].value then
        global.config_tmp[player.index] = util.table.deepcopy(global.config_new[player.index])
        global.dirty[player.index] = false
    end
    global.selected[player.index] = false
    show_yarm(player.index)
end

function GUI.set_item(player, index, element)
    local player_index = player.index
    if not index then
        return
    end

    local elem_value = element.elem_value
    if elem_value then
        local config_tmp = global.config_tmp[player_index].config
        for i, item in pairs(config_tmp) do
            if item.name == elem_value then
                display_message(player, {"", {"cant-set-duplicate-request", game.item_prototypes[elem_value].localised_name}}, true)
                element.elem_value = nil
                return i
            end
        end
        log(serpent.line(config_tmp))
        config_tmp[index] = {name = elem_value, request = game.item_prototypes[elem_value].default_request_amount, trash = false, slot = index}
    end
    return true
end

function GUI.update_presets(player)
    local storage_grid = global.gui_elements.storage_grid[player.index]
    if not (storage_grid and storage_grid.valid) then return end
    local children = storage_grid.children
    local presets = global.selected_presets[player.index]
    for i=1, #children, 2 do
        if presets[children[i].caption] then
            children[i].style = "at_preset_button_selected"
        else
            children[i].style = "at_preset_button"
        end
    end
    if table_size(presets) == 1 then
        global.gui_elements.storage_textfield[player.index].text = next(presets)
    else
        global.gui_elements.storage_textfield[player.index].text = ""
    end
end

function GUI.add_preset(player, preset_name, index)
    local storage_grid = global.gui_elements.storage_grid[player.index]
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

function GUI.restore(player, element)
    local player_index = player.index
    local name = element.caption

    global.selected_presets[player_index] = {[name] = true}
    global.config_tmp[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
    global.selected[player_index] = false
    global.dirty[player_index] = true

    global.gui_elements.storage_textfield[player_index].text = name
    GUI.update_presets(player)
    GUI.create_buttons(player)
    GUI.update_sliders(player)
end

function GUI.remove(player, element, index)
    local storage_grid = element.parent
    local btn1 = storage_grid[GUI.defines.load_preset .. index]
    local btn2 = storage_grid[GUI.defines.delete_preset .. index]
    assert(global.storage_new[player.index] and global.storage_new[player.index][btn1.caption]) --TODO remove
    global.selected_presets[player.index][btn1.caption] = nil
    global["storage_new"][player.index][btn1.caption] = nil
    btn1.destroy()
    btn2.destroy()
    GUI.update_presets(player)
end

return GUI
