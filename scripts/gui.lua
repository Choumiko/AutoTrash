local gui = require("__flib__.gui")
local table =require("__flib__.table")

local mod_gui = require ("__core__.lualib.mod-gui")

local constants = require("constants")
local presets = require("scripts.presets")
--local player_data = require("scripts.player-data")

local at_util = require("scripts.util")
local format_number = at_util.format_number
local item_prototype = at_util.item_prototype
local in_network = at_util.in_network
local get_non_equipment_network = at_util.get_non_equipment_network

local clamp = function(v, min, max)
    return (v < min) and min or (v > max and max or v)
end

local format_request = function(item_config)
    return (item_config.min and item_config.min >= 0) and item_config.min or (item_config.max and 0)
end

local format_trash = function(item_config)
    return (item_config.max < constants.max_request) and format_number(item_config.max, true) or "∞"
end

local function tonumber_max(n)
    n = tonumber(n) or 0
    return (n > constants.max_request) and constants.max_request or n
end

local function gcd(a, b)
    if a == b then
        return a
    elseif a > b then
        return gcd(a - b, b)
    elseif b > a then
        return gcd(a, b-a)
    end
end

local function get_network_data(player)
    local character = player.character
    if not character then return end
    local network = get_non_equipment_network(character)
    local requester = character.get_logistic_point(defines.logistic_member_index.character_requester)
    if not (network and requester and network.valid and requester.valid) then
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

local at_gui = {
    defines = {
        trash_above_requested = "trash_above_requested",
        trash_unrequested = "trash_unrequested",
        trash_network = "trash_network",
        pause_trash = "pause_trash",
        pause_requests = "pause_requests",
        network_button = "network_button",
    },
}

function at_gui.register_handlers()
    for name, id in pairs(defines.events) do
        if string.sub(name, 1, 6) == "on_gui" then
            script.on_event(id, at_gui.dispatch_handlers)
        end
    end
end

function at_gui.dispatch_handlers(event_data)
    local player = game.get_player(event_data.player_index)
    local pdata = global._pdata[event_data.player_index]
    event_data.player = player
    event_data.pdata = pdata
    local result = gui.dispatch_handlers(event_data)
    if result and not player.character then
        at_gui.close(player, pdata, true)
        player.print{"at-message.no-character"}
    end
    return result
end

local function import_presets(player, pdata, add_presets, stack)
    if stack and stack.valid_for_read then
        if stack.is_blueprint and stack.is_blueprint_setup() then
            local preset, cc_found = presets.import(stack.get_blueprint_entities(), stack.blueprint_icons)
            if cc_found then
                pdata.config_tmp = preset
                player.print({"string-import-successful", "AutoTrash configuration"})
                pdata.selected = false
                at_gui.adjust_slots(player, pdata, preset.max_slot)
                at_gui.update_buttons(pdata)
                at_gui.update_sliders(pdata)
                at_gui.mark_dirty(pdata)
                --named preset
                if stack.label and stack.label ~= "AutoTrash_configuration" then
                    local textfield = pdata.gui.main.preset_textfield
                    local preset_name = string.sub(stack.label, 11)
                    if add_presets and at_gui.add_preset(player, pdata, preset_name, preset) then
                        pdata.selected_presets = {[preset_name] = true}
                        at_gui.update_presets(pdata)
                    end
                    textfield.text = preset_name
                    player.clean_cursor()
                    textfield.focus()
                end
            else
                player.print({"", {"error-while-importing-string"}, " ", {"at-message.import-error"}})
            end
            return true
        elseif add_presets and stack.is_blueprint_book then
            local book_inventory = stack.get_inventory(defines.inventory.item_main)
            local any_cc = false
            for i = 1, #book_inventory do
                local bp = book_inventory[i]
                if bp.valid_for_read and bp.is_blueprint_setup() then
                    local config, cc = presets.import(bp.get_blueprint_entities(), bp.blueprint_icons)
                    if cc then
                        any_cc = true
                        at_gui.add_preset(player, pdata, bp.label, config)
                    end
                end
            end
            if any_cc then
                player.print({"string-import-successful", {"at-gui.presets"}})
                at_gui.update_presets(pdata)
            else
                player.print({"", {"error-while-importing-string"}, " ", {"at-message.import-error"}})
            end
            return true
        end
    end
    return false
end

at_gui.toggle_setting = {
    trash_above_requested = function(player, pdata)
        at_util.set_requests(player, pdata)
        return pdata.flags.trash_above_requested
    end,
    trash_unrequested = function(player, pdata)
        at_util.set_requests(player, pdata)
        return pdata.flags.trash_unrequested
    end,
    trash_network = function(player, pdata)
        if pdata.flags.trash_network and not next(pdata.networks) then
            player.print{"at-message.no-network-set"}
            pdata.flags.trash_network = false
            return false
        end

        if pdata.flags.trash_network and in_network(player, pdata) then
            at_util.unpause_trash(player, pdata)
            at_gui.update_main_button(pdata)
        end
        return pdata.flags.trash_network
    end,
    pause_trash = function(player, pdata)
        if pdata.flags.pause_trash then
            at_util.pause_trash(player, pdata)
        else
            at_util.unpause_trash(player, pdata)
        end
        at_gui.update_main_button(pdata)
        return pdata.flags.pause_trash
    end,
    pause_requests = function(player, pdata)
        if pdata.flags.pause_requests then
            at_util.pause_requests(player, pdata)
        else
            at_util.unpause_requests(player, pdata)
        end
        at_gui.update_main_button(pdata)
        at_gui.update_status_display(player, pdata)
        return pdata.flags.pause_requests
    end,
}

at_gui.templates = {
    slot_table = {
        main = function(btns, pdata)
            local ret = {type = "table", column_count = pdata.settings.columns, style = "at_filter_group_table", save_as = "main.slot_table",
                style_mods = {minimal_height = pdata.settings.rows * 40}, children = {}}
            for i=1, btns do
                ret.children[i] = at_gui.templates.slot_table.button(i, pdata)
            end
            ret.children[btns+1] = at_gui.templates.slot_table.count_change()
            return ret
        end,
        button = function(i, pdata)
            local style = (i == pdata.selected) and "yellow_slot_button" or "slot_button"
            local config = pdata.config_tmp.config[i]
            local req = config and format_number(format_request(config), true) or ""
            local trash = config and format_trash(config)
            return {type = "choose-elem-button", name = i, elem_mods = {elem_value = config and config.name, locked = config and i ~= pdata.selected},
                        handlers = "main.slots.item_button", elem_type = "item", style = style, children = {
                        {type = "label", style = "at_request_label_top", ignored_by_interaction = true, caption = req},
                        {type = "label", style = "at_request_label_bottom", ignored_by_interaction = true, caption = trash}
                    }}
        end,
        count_change = function()
            return {type = "flow", name = "count_change", direction="vertical", style_mods = {vertical_spacing=0}, children={
                {type = "button", caption="-", handlers="main.slots.decrease", style = "slot_count_change_button"},
                {type = "button", caption="+", handlers = "main.slots.increase", style = "slot_count_change_button"}
            }}
        end,
    },
    frame_action_button = function(params)
        local ret = {type = "sprite-button", style = "frame_action_button", mouse_button_filter={"left"}}
        for k, v in pairs(params) do
            ret[k] = v
        end
        return ret
    end,
    pushers = {
        horizontal = {type = "empty-widget", style_mods = {horizontally_stretchable = true}},
        vertical = {type = "empty-widget", style_mods = {vertically_stretchable = true}}
    },
    import_export_window = function(bp_string, mode)
        local caption = bp_string and {"gui.export-to-string"} or {"gui-blueprint-library.import-string"}
        local button_caption = bp_string and {"gui.close"} or {"gui-blueprint-library.import"}
        local button_handler = bp_string and "import.close_button" or "import.import_button"
        return {type = "frame", save_as = "window.main", style = "inner_frame_in_outer_frame", direction = "vertical", children = {
                {type = "flow", save_as = "window.titlebar", children = {
                    {type = "label", style = "frame_title", caption = caption, elem_mods = {ignored_by_interaction = true}},
                    {type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = {ignored_by_interaction = true}},
                    at_gui.templates.frame_action_button{handlers = "import.close_button", save_as = "close_button",
                        sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black"
                    }
                }},
                {type = "text-box", text = bp_string, save_as = "window.textbox", elem_mods = {word_wrap = true}, style_mods = {width = 400, height = 250}},
                {type = "flow", direction = "horizontal", children={
                        at_gui.templates.pushers.horizontal,
                        {type = "label", name = "mode", caption = mode, visible = false},
                        {type = "button", handlers = button_handler, style = "dialog_button", caption = button_caption}
                }}
            }}
    end,

    settings = function(flags)
        return {type = "frame", style = "at_bordered_frame", children = {
            {type = "flow", direction = "vertical", save_as = "main.trash_options", children = {
                {
                    type = "checkbox",
                    name = at_gui.defines.trash_above_requested,
                    caption = {"at-gui.trash-above-requested"},
                    state = flags.trash_above_requested,
                    handlers = "main.settings.toggle"
                },
                {
                    type = "checkbox",
                    name = at_gui.defines.trash_unrequested,
                    caption = {"at-gui.trash-unrequested"},
                    state = flags.trash_unrequested,
                    handlers = "main.settings.toggle"
                },
                {
                    type = "checkbox",
                    name = at_gui.defines.trash_network,
                    caption = {"at-gui.trash-in-main-network"},
                    state = flags.trash_network,
                    handlers = "main.settings.toggle"
                },
                {
                    type = "checkbox",
                    name = at_gui.defines.pause_trash,
                    caption = {"at-gui.pause-trash"},
                    tooltip = {"at-gui.tooltip-pause-trash"},
                    state = flags.pause_trash,
                    handlers = "main.settings.toggle"
                },
                {
                    type = "checkbox",
                    name = at_gui.defines.pause_requests,
                    caption = {"at-gui.pause-requests"},
                    tooltip = {"at-gui.tooltip-pause-requests"},
                    state = flags.pause_requests,
                    handlers = "main.settings.toggle"
                },
                {
                    type = "flow", style_mods = {vertical_align = "center"}, children = {
                        {type = "label", caption = "Main networks: "},
                        {type = "button", caption = "+", style = "tool_button", handlers = "main.settings.add_network",
                            tooltip = {"at-gui.tooltip-add-network"}
                        },
                        {type = "button", caption = "-", style = "tool_button", handlers = "main.settings.remove_network",
                            tooltip = {"at-gui.tooltip-remove-network"}
                        },
                        {type = "sprite-button", sprite = "utility/rename_icon_normal", style = "tool_button",
                            save_as = "main.network_edit_button",
                            handlers = "main.settings.edit_networks", tooltip = {"at-gui.tooltip-edit-networks"}},
                    }
                },
                at_gui.templates.pushers.horizontal
            }},
        }}
    end,

    preset = function(preset_name, pdata)
        local style = pdata.selected_presets[preset_name] and "at_preset_button_selected" or "at_preset_button"
        local rip_style = pdata.death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
        return {type = "flow", direction = "horizontal", name = preset_name, children = {
            {type = "button", style = style, caption = preset_name, name = preset_name, handlers = "main.presets.load"},
            {type = "sprite-button", style = rip_style, sprite = "autotrash_rip", handlers = "main.presets.change_death_preset",
                tooltip = {"at-gui.tooltip-rip"}
            },
            {type = "sprite-button", style = "at_delete_preset", sprite = "utility/trash", handlers = "main.presets.delete"},
        }}
    end,

    presets = function(pdata)
        local ret = {}
        local i = 1
        for name in pairs(pdata.presets) do
            ret[i] = at_gui.templates.preset(name, pdata)
            i = i + 1
        end
        return ret
    end,

    networks = function(pdata)
        local ret = {}
        local i = 1
        for id, network in pairs(pdata.networks) do
            if network and network.valid then
                ret[i] = {type = "flow", name = id, direction = "horizontal", style_mods = {vertical_align = "center"}, children = {
                    {type = "label", caption = {"", {"gui-logistic.network"}, " #" .. id}},
                    at_gui.templates.pushers.horizontal,
                    {type = "sprite-button", style = "tool_button", sprite = "utility/map", handlers = "main.networks.view",
                        tooltip = {"at-gui.tooltip-show-network"}
                    },
                    {type = "sprite-button", style = "tool_button", sprite = "utility/trash", handlers = "main.networks.remove"},
                }}
                i = i + 1
            end
        end
        return ret
    end,
}

at_gui.handlers = {
    mod_gui_button = {
        on_gui_click = function(e)
            if e.button == defines.mouse_button_type.right then
                if e.control then
                    at_gui.toggle_status_display(e.player, e.pdata)
                end
            elseif e.button == defines.mouse_button_type.left then
                --local player = e.player
                --local cursor_stack = player.cursor_stack
                --if cursor_stack and cursor_stack.valid_for_read then
                    -- local bp
                    -- local pdata = e.pdata
                    -- if cursor_stack.is_blueprint_book then
                    --     bp = cursor_stack.get_inventory(defines.inventory.item_main)[cursor_stack.active_index]
                    -- elseif cursor_stack.is_blueprint and cursor_stack.is_blueprint_setup() then
                    --     bp = cursor_stack
                    -- end
                    -- local cost = bp.cost_to_build
                    -- local success = true
                    -- for item, count in pairs(cost) do
                    --     local request = player_data.find_request(player, item)
                    --     if request then
                    --         if request.min < count then
                    --             request.min = count
                    --         end
                    --         if request.max < count then
                    --             request.max = request.min
                    --         end
                    --     else
                    --         request = {name = item, min = count, max = constants.max_request}
                    --     end
                    --     local added = player_data.set_request(player, pdata, request, true)
                    --     success = success and added
                    --     if added then
                    --         pdata.flags.has_temporary_requests = true
                    --     end
                    -- end
                    -- if success then
                    --     player.print("Added blueprint items to temporary requests")
                    -- else
                    --     player.print("Not all blueprint items could be added")
                    -- end
                --else
                    at_gui.toggle(e.player, e.pdata)
                --end
            end
        end,
    },
    main = {
        pin_button = {
            on_gui_click = function(e)
                local pdata = e.pdata
                if pdata.flags.pinned then
                    pdata.gui.main.titlebar.pin_button.style = "frame_action_button"
                    pdata.flags.pinned = false
                    pdata.gui.main.window.force_auto_center()
                    e.player.opened = pdata.gui.main.window
                else
                    pdata.gui.main.titlebar.pin_button.style = "flib_selected_frame_action_button"
                    pdata.flags.pinned = true
                    pdata.gui.main.window.auto_center = false
                    e.player.opened = nil
                end
            end
        },
        close_button = {
            on_gui_click = function(e)
                at_gui.close(e.player, e.pdata)
            end
        },
        window = {
            on_gui_closed = function(e)
                if not e.pdata.flags.pinned then
                    at_gui.close(e.player, e.pdata)
                end
            end
        },
        apply_changes = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                local adjusted = false
                for _, config in pairs(pdata.config_tmp.config) do
                    if config.max < config.min then
                        adjusted = true
                        config.max = config.min
                        player.print{"at-message.adjusted-trash-amount", at_util.item_prototype(config.name).localised_name, config.max}
                    end
                end

                pdata.config_new = table.deep_copy(pdata.config_tmp)
                pdata.dirty = false
                pdata.gui.main.reset_button.enabled = false
                at_util.set_requests(player, pdata)
                if pdata.settings.close_on_apply then
                    at_gui.close(player, pdata)
                end
                if adjusted then
                    at_gui.update_buttons(pdata)
                end
                at_gui.update_status_display(player, pdata)
            end
        },
        reset = {
            on_gui_click = function(e)
                local pdata = e.pdata
                if pdata.flags.dirty then
                    pdata.config_tmp = table.deep_copy(pdata.config_new)
                    e.element.enabled = false
                    pdata.selected_presets = {}
                    pdata.selected = false
                    pdata.flags.dirty = false
                    at_gui.adjust_slots(e.player, pdata, pdata.config_tmp.max_slot)
                    at_gui.update_buttons(pdata)
                    at_gui.update_sliders(pdata)
                    at_gui.update_presets(pdata)
                end
            end
        },
        export = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                local name
                if table_size(pdata.selected_presets) == 1 then
                    name = "AutoTrash_" .. next(pdata.selected_presets)
                else
                    name = "AutoTrash_configuration"
                end
                if table_size(pdata.config_tmp.config) == 0 then
                    player.print({"at-message.no-config-set"})
                    return
                end
                local text = presets.export(pdata.config_tmp, name)
                if e.shift then
                    local stack = player.cursor_stack
                    if stack.valid_for_read then
                        player.print({"at-message.empty-cursor-needed"})
                        return
                    else
                        if stack.import_stack(text) ~= 0 then
                            player.print({"failed-to-import-string", name})
                            return
                        end
                    end
                else
                    at_gui.create_import_window(player, pdata, text, "single")
                end
            end
        },
        export_all = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                if not next(pdata.presets) then
                    player.print{"at-message.no-presets-to-export"}
                    return
                end
                local text = presets.export_all(pdata)
                if e.shift then
                    local stack = player.cursor_stack
                    if stack.valid_for_read then
                        player.print{"at-message.empty-cursor-needed"}
                        return
                    else
                        if stack.import_stack(text) ~= 0 then
                            player.print{"failed-to-import-string"}
                            return
                        end
                    end
                else
                    at_gui.create_import_window(player, pdata, text, "all")
                end
            end
        },
        import = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                if not import_presets(player, pdata, false, player.cursor_stack) then
                    at_gui.create_import_window(player, pdata, nil, "single")
                end
            end
        },
        import_all = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                if not import_presets(player, pdata, true, player.cursor_stack) then
                    at_gui.create_import_window(player, pdata, nil, "all")
                end
            end
        },
        slots = {
            item_button = {
                on_gui_click = function(e)
                    local player = e.player
                    local pdata = e.pdata
                    local elem_value = e.element.elem_value
                    local old_selected = pdata.selected
                    local index = tonumber(e.element.name)
                    if e.button == defines.mouse_button_type.right then
                        if not elem_value then
                            pdata.selected = false
                            at_gui.update_button(pdata, old_selected, pdata.gui.main.slot_table.children[old_selected])
                            at_gui.update_sliders(pdata)
                            return
                        end
                        at_gui.clear_button(pdata, index, e.element)
                    elseif e.button == defines.mouse_button_type.left then
                        if e.shift then
                            local config_tmp = pdata.config_tmp
                            local cursor_ghost = player.cursor_ghost
                            --pickup ghost
                            if elem_value and not cursor_ghost and not player.cursor_stack.valid_for_read then
                                pdata.selected = index
                                player.cursor_ghost = elem_value
                            --drop ghost
                            elseif cursor_ghost and old_selected then
                                local old_config = config_tmp.config[old_selected]
                                if elem_value and old_config and cursor_ghost.name == old_config.name then
                                    local tmp = table.deep_copy(config_tmp.config[index])
                                    config_tmp.config[index] = table.deep_copy(old_config)
                                    config_tmp.config[index].slot = index
                                    if tmp then
                                        tmp.slot = old_selected
                                    end
                                    config_tmp.config[old_selected] = tmp
                                    player.cursor_ghost = nil
                                    pdata.selected = index
                                    config_tmp.max_slot = index > config_tmp.max_slot and index or config_tmp.max_slot
                                    at_gui.mark_dirty(pdata)
                                end
                                if not old_config then
                                    pdata.selected = false
                                    old_selected = false
                                    player.cursor_ghost = nil
                                end
                            end
                            at_gui.update_button(pdata, index, e.element)
                            at_gui.update_button(pdata, old_selected)
                            at_gui.update_button_styles(player, pdata)--TODO: only update changed buttons
                            at_gui.update_sliders(pdata)
                        else
                            if not elem_value or old_selected == index then return end
                            if player.cursor_ghost then
                                local old_config = old_selected and pdata.config_tmp.config[old_selected]
                                -- "interrupted" click-drag, reset value
                                if elem_value and old_config and old_config.name == elem_value then
                                    e.element.elem_value = nil
                                    return
                                end
                            end
                            pdata.selected = index
                            if old_selected then
                                local old = pdata.gui.main.slot_table.children[old_selected]
                                at_gui.update_button(pdata, old_selected, old)
                            end
                            at_gui.update_button(pdata, index, e.element)
                            at_gui.update_button_styles(player, pdata)--TODO: only update changed buttons
                            at_gui.update_sliders(pdata)
                        end
                    end
                end,
                on_gui_elem_changed = function(e)
                    local player = e.player
                    local pdata = e.pdata
                    local old_selected = pdata.selected
                    --dragging to an empty slot, on_gui_click raised later
                    if player.cursor_ghost and old_selected then return end

                    local elem_value = e.element.elem_value
                    local index = tonumber(e.element.name)
                    if elem_value then
                        local item_config = pdata.config_tmp.config[index]
                        if item_config and elem_value == item_config.name then return end
                        for i, v in pairs(pdata.config_tmp.config) do
                            if i ~= index and elem_value == v.name then
                                player.print({"cant-set-duplicate-request", item_prototype(elem_value).localised_name})
                                pdata.selected = i
                                at_gui.update_button(pdata, i, pdata.gui.main.slot_table.children[i])
                                pdata.gui.main.config_rows.scroll_to_element(pdata.gui.main.slot_table.children[i], "top-third")
                                if item_config then
                                    e.element.elem_value = item_config.name
                                else
                                    e.element.elem_value = nil
                                end
                                at_gui.update_button_styles(player, pdata)--TODO: only update changed buttons
                                at_gui.update_sliders(pdata)
                                return
                            end
                        end
                        pdata.selected = index
                        local request_amount = item_prototype(elem_value).default_request_amount
                        local trash_amount = pdata.settings.trash_equals_requests and request_amount or constants.max_request
                        local config_tmp = pdata.config_tmp
                        config_tmp.config[index] = {
                            name = elem_value, min = request_amount,
                            max = trash_amount, slot = index
                        }
                        config_tmp.max_slot = index > config_tmp.max_slot and index or config_tmp.max_slot
                        if config_tmp.config[index].min > 0 then
                            config_tmp.c_requests = config_tmp.c_requests + 1
                        end
                        at_gui.mark_dirty(pdata)
                        at_gui.update_button(pdata, index, e.element)
                        if old_selected then
                            at_gui.update_button(pdata, old_selected, pdata.gui.main.slot_table.children[old_selected])
                        end
                        at_gui.update_button_styles(player, pdata)--TODO: only update changed buttons
                        at_gui.update_sliders(pdata)
                    else
                        at_gui.clear_button(pdata, index, e.element)
                    end
                end
            },
            decrease = {
                on_gui_click = function (e)
                    at_gui.decrease_slots(e.player, e.pdata)
                end,
            },
            increase = {
                on_gui_click = function(e)
                    at_gui.increase_slots(e.player, e.pdata)
                end,
            },
        },
        presets = {
            save = {
                on_gui_click = function(e)
                    local player = e.player
                    local pdata = e.pdata
                    local textfield = pdata.gui.main.preset_textfield
                    local name = textfield.text
                    if at_gui.add_preset(player, pdata, name) then
                        pdata.selected_presets = {[name] = true}
                        at_gui.update_presets(pdata)
                    else
                        textfield.focus()
                    end

                end
            },
            load = {
                on_gui_click = function(e)
                    local player = e.player
                    local pdata = e.pdata
                    local name = e.element.caption
                    if not e.shift and not e.control then
                        pdata.selected_presets = {[name] = true}
                        pdata.config_tmp = table.deep_copy(pdata.presets[name])
                        pdata.selected = false
                        pdata.gui.main.preset_textfield.text = name
                    else
                        local selected_presets = pdata.selected_presets
                        if not selected_presets[name] then
                            selected_presets[name] = true
                        else
                            selected_presets[name] = nil
                        end
                        local tmp = {config = {}, max_slot = 0, c_requests = 0}
                        for key, _ in pairs(selected_presets) do
                            presets.merge(tmp, pdata.presets[key])
                        end
                        pdata.config_tmp = tmp
                        pdata.selected = false
                    end
                    at_gui.adjust_slots(player, pdata, pdata.config_tmp.max_slot)
                    at_gui.update_buttons(pdata)
                    at_gui.mark_dirty(pdata, true)
                    at_gui.update_presets(pdata)
                    at_gui.update_sliders(pdata)
                end
            },
            delete = {
                on_gui_click = function(e)
                    local pdata = e.pdata
                    local parent = e.element.parent
                    local name = parent.name
                    gui.update_filters("main.presets", e.player_index, {e.element.index, parent.children[1].index, parent.children[2].index}, "remove")
                    parent.destroy()
                    pdata.selected_presets[name] = nil
                    pdata.death_presets[name] = nil
                    pdata.presets[name] = nil
                    at_gui.update_presets(pdata)
            end
            },
            change_death_preset = {
                on_gui_click = function(e)
                    local pdata = e.pdata
                    local name = e.element.parent.name
                    if not (e.shift or e.control) then
                        pdata.death_presets = {[name] = true}
                    else
                        local selected_presets = pdata.death_presets
                        if not selected_presets[name] then
                            selected_presets[name] = true
                        else
                            selected_presets[name] = nil
                        end
                    end
                    at_gui.update_presets(pdata)
                end,
            },
            textfield = {
                on_gui_click = function(e)
                    e.element.select_all()
                end
            }
        },
        sliders = {
            request = {
                on_gui_value_changed = function(e)
                    local pdata = e.pdata
                    if not pdata.selected then return end
                    at_gui.update_request_config(e.element.slider_value, pdata)
                end,
                on_gui_text_changed = function(e)
                    local pdata = e.pdata
                    if not pdata.selected then return end
                    at_gui.update_request_config(tonumber_max(e.element.text), pdata, true)
                end,
            },
            trash = {
                on_gui_value_changed = function(e)
                    local pdata = e.pdata
                    if not pdata.selected then return end
                    at_gui.update_trash_config(e.player, pdata, e.element.slider_value, "slider")
                end,
                on_gui_text_changed = function(e)
                    local pdata = e.pdata
                    if not pdata.selected then return end
                    at_gui.update_trash_config(e.player, pdata, tonumber_max(e.element.text), "text")
                end,
                on_gui_confirmed = function(e)
                    local pdata = e.pdata
                    if not pdata.selected then return end
                    at_gui.update_trash_config(e.player, pdata, tonumber_max(e.element.text), "confirmed")
                end
            }
        },
        quick_actions = {
            on_gui_selection_state_changed = function(e)
                local pdata = e.pdata
                local element = e.element
                local index = element.selected_index
                if index == 1 then return end

                local config_tmp = pdata.config_tmp
                if index == 2 then
                    for _, config in pairs(config_tmp.config) do
                        config.min = 0
                    end
                    config_tmp.c_requests = 0
                elseif index == 3 then
                    for _, config in pairs(config_tmp.config) do
                        config.max = constants.max_request
                    end
                elseif index == 4 then
                    config_tmp.config = {}
                    config_tmp.max_slot = 0
                    config_tmp.c_requests = 0
                    pdata.selected = false
                elseif index == 5 then
                    for _, config in pairs(config_tmp.config) do
                        if config.min > 0 then
                            config.max = config.min
                        end
                    end
                elseif index == 6 then
                    local c = 0
                    for _, config in pairs(config_tmp.config) do
                        if config.max < constants.max_request then
                            config.min = config.max
                            c = config.min > 0 and c + 1 or c
                        end
                    end
                    config_tmp.c_requests = c
                end
                element.selected_index = 1
                at_gui.mark_dirty(pdata)
                at_gui.update_sliders(pdata)
                at_gui.update_buttons(pdata)
            end
        },
        settings = {
            toggle = {
                on_gui_checked_state_changed = function(e)
                    local pdata = e.pdata
                    local player = e.player
                    if not player.character then return end
                    local name = e.element.name
                    if at_gui.toggle_setting[name] then
                        pdata.flags[name] = e.element.state
                        e.element.state = at_gui.toggle_setting[name](e.player, pdata)
                    end
                end
            },
            add_network = {
                on_gui_click = function(e)
                    local player = e.player
                    if not player.character then return end
                    local pdata = e.pdata
                    local new_network = at_util.get_network_entity(player)
                    if new_network then
                        local new_id = new_network.unit_number
                        if pdata.networks[new_id] then
                            player.print{"at-message.network-exists", new_id}
                            return
                        end
                        local new_net = new_network.logistic_network
                        for id, network in pairs(pdata.networks) do
                            if network and network.valid then
                                if network.logistic_network == new_net then
                                    player.print{"at-message.network-exists", id}
                                    return
                                end
                            else
                                pdata.networks[id] = nil
                            end
                        end
                        pdata.networks[new_id] = new_network
                        player.print{"at-message.added-network", new_id}
                    else
                        player.print{"at-message.not-in-network"}
                    end
                    at_gui.update_networks(player, pdata)
                end
            },
            remove_network = {
                on_gui_click = function(e)
                    local player = e.player
                    if not player.character then return end
                    local pdata = e.pdata
                    local current_network = at_util.get_network_entity(player)
                    if current_network then
                        local nid = current_network.unit_number
                        if pdata.networks[nid] then
                            pdata.networks[nid] = nil
                            player.print{"at-message.removed-network", nid}
                            at_gui.update_networks(player, pdata)
                            return
                        end
                        local new_net = current_network.logistic_network
                        for id, network in pairs(pdata.networks) do
                            if network and network.valid then
                                if network.logistic_network == new_net then
                                    pdata.networks[id] = nil
                                    player.print{"at-message.removed-network", id}
                                    return
                                end
                            else
                                pdata.networks[id] = nil
                            end
                        end
                    else
                        player.print{"at-message.not-in-network"}
                    end
                    at_gui.update_networks(player, pdata)
                end
            },
            edit_networks = {
                on_gui_click = function(e)
                    local pdata = e.pdata
                    at_gui.update_networks(e.player, pdata)
                    local visible = not pdata.gui.main.networks.visible
                    e.element.style = visible and "at_selected_tool_button" or "tool_button"
                    pdata.gui.main.networks.visible = visible
                    pdata.gui.main.presets.visible = not visible
                end
            },
            selection_tool = {
                on_gui_click = function(e)
                    local player = e.player
                    local pdata = e.pdata
                    local cursor_stack = player.cursor_stack
                    if cursor_stack and cursor_stack.valid_for_read then
                        player.clean_cursor()
                    end
                    if cursor_stack.set_stack{name = "autotrash-network-selection", count = 1} then
                        local location = pdata.gui.main.window.location
                        location.x = 50
                        pdata.gui.main.window.location = location
                    end
                end,
            }
        },
        networks = {
            view = {
                on_gui_click = function(e)
                    local pdata = e.pdata
                    local id = tonumber(e.element.parent.name)
                    local entity = pdata.networks[id]
                    if entity and entity.valid then
                        e.player.zoom_to_world(entity.position, 0.3)
                        local location = pdata.gui.main.window.location
                        location.x = 50
                        pdata.gui.main.window.location = location
                    end
                end
            },
            remove = {
                on_gui_click = function(e)
                    local pdata = e.pdata
                    local flow = e.element.parent
                    local id = tonumber(flow.name)
                    if id then
                        pdata.networks[id] = nil
                    end
                    gui.update_filters("main.networks", e.player_index, {e.element.index, flow.children[2].index}, "remove")
                    flow.destroy()
                end
            },
        }
},
    import = {
        import_button = {
            on_gui_click = function(e)
                local player = e.player
                local pdata = e.pdata
                local add_presets = e.element.parent.mode.caption == "all"
                local inventory = game.create_inventory(1)

                inventory.insert{name = "blueprint"}
                local stack = inventory[1]
                local result = stack.import_stack(pdata.gui.import.window.textbox.text)
                if result ~= 0 then
                    inventory.destroy()
                    return result
                end
                result = import_presets(player, pdata, add_presets, stack)
                inventory.destroy()
                if not result then
                    player.print({"failed-to-import-string", "Unknown error"})
                end
                gui.handlers.import.close_button.on_gui_click(e)
            end
        },
        close_button = {
            on_gui_click = function(e)
                local pdata = e.pdata
                gui.update_filters("import", e.player_index, nil, "remove")
                pdata.gui.import.window.main.destroy()
                pdata.gui.import = nil
            end
        }
    },
}
gui.add_handlers(at_gui.handlers)

at_gui.update_request_config = function(number, pdata, from_text)
    local selected = pdata.selected
    local config_tmp = pdata.config_tmp
    local item_config = config_tmp.config[selected]
    if not from_text then
        number = number * item_prototype(item_config.name).stack_size
    end
    if item_config.min == 0 and number > 0 then
        config_tmp.c_requests = config_tmp.c_requests + 1
    end
    if item_config.min > 0 and number == 0 then
        config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
    end
    item_config.min = number
    --prevent trash being set to a lower value than request to prevent infinite robo loop
    if item_config.max < constants.max_request and number > item_config.max then
        item_config.max = number
    end
    at_gui.mark_dirty(pdata)
    at_gui.update_sliders(pdata)
    at_gui.update_button(pdata, pdata.selected)
end

at_gui.update_trash_config = function(player, pdata, number, source)
    local selected = pdata.selected
    local config_tmp = pdata.config_tmp
    local item_config = config_tmp.config[selected]
    if item_config then
        if source == "slider" then
            local stack_size = item_prototype(item_config.name).stack_size
            number = number < 10 and number * stack_size or constants.max_request
        end
        if source ~= "text" then
            if number < constants.max_request and item_config.min > number then
                if item_config.min > 0 and number == 0 then
                    config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
                end
                item_config.min = number
                if source == "confirmed" then
                    player.print{"at-message.adjusted-trash-amount", at_util.item_prototype(item_config.name).localised_name, number}
                end
            end
        end
        item_config.max = number
        at_gui.mark_dirty(pdata)
        at_gui.update_button(pdata, pdata.selected)
    else
        at_gui.update_button(pdata, pdata.selected)
        pdata.selected = false
    end
    at_gui.update_sliders(pdata)
end

at_gui.decrease_slots = function(player, pdata)
    local old_slots = player.character_logistic_slot_count
    local step = (10 * pdata.settings.columns) / gcd(10, pdata.settings.columns)
    local correct = (old_slots + 1) % step
    local new_slots = old_slots - correct - step
    if new_slots < pdata.config_tmp.max_slot then return end
    at_gui.adjust_slots(player, pdata, new_slots)
end

at_gui.increase_slots = function(player, pdata)
    local old_slots = player.character_logistic_slot_count
    local step = (10 * pdata.settings.columns) / gcd(10, pdata.settings.columns)
    local correct = (old_slots + 1) % step
    local new_slots = old_slots - correct + step
    at_gui.adjust_slots(player, pdata, new_slots)
end

at_gui.adjust_slots = function(player, pdata, slots)
    local step = (10*pdata.settings.columns) / gcd(10, pdata.settings.columns)
    if slots < pdata.config_tmp.max_slot then
        local old_slots = player.character_logistic_slot_count
        local correct = (old_slots + 1) % step
        slots = old_slots - correct
    end
    slots = clamp(slots, step-1, 65529)
    player.character_logistic_slot_count = slots
    slots = player.character_logistic_slot_count
    local slot_table = pdata.gui.main.slot_table
    local old_slots = #slot_table.children - 1
    if old_slots == slots then return end

    local diff = slots - old_slots
    if diff > 0 then
        gui.update_filters("main.slots.decrease", player.index, nil, "remove")
        gui.update_filters("main.slots.increase", player.index, nil, "remove")
        slot_table.count_change.destroy()
        for i = old_slots+1, slots do
            gui.build(slot_table, {at_gui.templates.slot_table.button(i, pdata)})
        end
        gui.build(slot_table, {at_gui.templates.slot_table.count_change()})
    elseif diff < 0 then
        for i = old_slots, slots+1, -1 do
            local btn = slot_table.children[i]
            gui.update_filters("main.slots.item_button", player.index, {btn.index}, "remove")
            btn.destroy()
        end
        if slots < step then
            slot_table.count_change.children[1].enabled = false
        end
    end

    local width = pdata.settings.columns * 40
    width = (slots <= (pdata.settings.rows * pdata.settings.columns)) and width or (width + 12)
    pdata.gui.main.config_rows.style.width = width
    pdata.gui.main.config_rows.scroll_to_bottom()
end

at_gui.update_buttons = function(pdata)
    if not pdata.flags.gui_open then return end
    local children = pdata.gui.main.slot_table.children
    for i=1, #children-1 do
        at_gui.update_button(pdata, i, children[i])
    end
end

at_gui.get_button_style = function(i, selected, item, available, on_the_way, item_count, cursor_stack, armor, gun, ammo, paused)
    if paused or not (available and on_the_way and item and item.min > 0) then
        return (i == selected) and "yellow_slot_button" or "slot_button"
    end
    if i == selected then
        return "yellow_slot_button"
    end
    local n = item.name
    local diff = item.min - ((item_count[n] or 0) + (armor[n] or 0) + (gun[n] or 0) + (ammo[n] or 0) + (cursor_stack[n] or 0))

    if diff <= 0 then
        return "slot_button"
    else
        local diff2 = diff - (on_the_way[n] or 0) - (available[n] or 0)
        if diff2 <= 0 then
            return "yellow_slot_button", diff
        elseif (on_the_way[n] and not available[n]) then
        --item.name == "locomotive" then
            return "blue_slot", diff
        end
        return "red_slot_button", diff
    end
end

at_gui.update_button_styles = function(player, pdata)
    local ruleset_grid = pdata.gui.main.slot_table
    if not (ruleset_grid and ruleset_grid.valid) then return end
    local selected = pdata.selected
    local config = pdata.config_tmp
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)
    if not (available and on_the_way and config.c_requests > 0 and not pdata.flags.pause_requests) then
        local children = ruleset_grid.children
        for i=1, #children-1 do
            children[i].style = (i == selected) and "yellow_slot_button" or "slot_button"
        end
        return
    end
    config = config.config
    local ret = {}
    local buttons = ruleset_grid.children
    for i=1, #buttons-1 do
        local item = config[i]
        local style, diff = at_gui.get_button_style(i, selected, config[i], available, on_the_way, item_count, cursor_stack, armor, gun, ammo)
        if item and item.min > 0 then
            ret[item.name] = {style, diff}
        end
        buttons[i].style = style
    end
    return ret
end

at_gui.update_button = function(pdata, i, button)
    if not (button and button.valid) then
        if not i then return end
        button = pdata.gui.main.slot_table.children[i]
    end
    local req = pdata.config_tmp.config[i]
    if req then
        button.children[1].caption = format_number(format_request(req), true)
        button.children[2].caption = format_trash(req)
        button.elem_value = req.name
        button.locked = i ~= pdata.selected
    else
        button.children[1].caption = ""
        button.children[2].caption = ""
        button.elem_value = nil
        button.locked = false
    end
    button.style = (i == pdata.selected) and "yellow_slot_button" or "slot_button"
end

at_gui.clear_button = function(pdata, index, button)
    local config_tmp = pdata.config_tmp
    local config = config_tmp.config[index]
    if config then
        if config.min > 0 then
            config_tmp.c_requests = config_tmp.c_requests > 0 and config_tmp.c_requests - 1 or 0
        end
        if pdata.selected == index then pdata.selected = false end
        config_tmp.config[index] = nil
        if index == config_tmp.max_slot then
            config_tmp.max_slot = 0
            for i = index-1, 1, -1 do
                if config_tmp.config[i] then
                    config_tmp.max_slot = i
                    break
                end
            end
        end
    end
    at_gui.mark_dirty(pdata)
    at_gui.update_button(pdata, index, button)
    at_gui.update_sliders(pdata)
end

at_gui.update_sliders = function(pdata)
    if not pdata.flags.gui_open then return end
    if pdata.selected then
        local sliders = pdata.gui.main.sliders
        local item_config = pdata.config_tmp.config[pdata.selected]
        if item_config then
            local stack_size = item_prototype(item_config.name).stack_size
            sliders.request.slider_value = clamp(item_config.min / stack_size, 0, 10)
            sliders.request_text.text = format_request(item_config) or 0

            sliders.trash.slider_value = clamp(item_config.max / stack_size, 0, 10)
            sliders.trash_text.text = item_config.max < constants.max_request and item_config.max or "inf."
        end
    end
    local visible = pdata.selected and true or false
    for _, child in pairs(pdata.gui.main.sliders.table.children) do
        child.visible = visible
    end
end

at_gui.add_preset = function(player, pdata, name, config)
    config = config or pdata.config_tmp
    if name == "" then
        player.print({"at-message.name-not-set"})
        return
    end
    if pdata.presets[name] then
        if not pdata.settings.overwrite then
            player.print({"at-message.name-in-use"})
            return
        end
        pdata.presets[name] = table.deep_copy(config)
        player.print({"at-message.preset-updated", name})
    else
        pdata.presets[name] = table.deep_copy(config)
        gui.build(pdata.gui.main.presets_flow, {at_gui.templates.preset(name, pdata)})
    end
    return true
end

at_gui.update_presets = function(pdata)
    if not pdata.flags.gui_open then return end
    local children = pdata.gui.main.presets_flow.children
    local selected_presets = pdata.selected_presets
    local death_presets = pdata.death_presets
    for i=1, #children do
        local preset = children[i].children[1]
        local rip = children[i].children[2]
        local preset_name = preset.caption
        preset.style = selected_presets[preset_name] and "at_preset_button_selected" or "at_preset_button"
        rip.style = death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
    end
    local s = table_size(selected_presets)
    if s == 1 then
        pdata.gui.main.preset_textfield.text = next(selected_presets)
    elseif s > 1 then
        pdata.gui.main.preset_textfield.text = ""
    end
end

at_gui.update_networks = function(player, pdata)
    if not pdata.flags.gui_open then return end
    local networks = pdata.gui.main.networks_flow
    networks.clear()
    gui.update_filters("main.networks", player.index, nil, "remove")
    gui.build(networks, at_gui.templates.networks(pdata))
end

function at_gui.create_main_window(player, pdata)
    if not player.character then return end
    local flags = pdata.flags
    pdata.selected = false
    local cols = pdata.settings.columns
    local rows = pdata.settings.rows
    local btns = player.character_logistic_slot_count
    local width = cols * 40
    width = (btns <= (rows*cols)) and width or (width + 12)
    local max_height = (player.display_resolution.height / player.display_scale) * 0.97
    local max_width = (player.display_resolution.width / player.display_scale)
    local gui_data = gui.build(player.gui.screen,{
        {type = "frame", style = "outer_frame", style_mods = {maximal_width = max_width, maximal_height = max_height},
            handlers = "main.window", save_as = "main.window", children = {
            {type = "frame", style = "inner_frame_in_outer_frame", direction = "vertical", children = {
                {type = "flow", save_as = "main.titlebar.flow", children = {
                    {type = "label", style = "frame_title", caption = {"mod-name.AutoTrash"}, elem_mods = {ignored_by_interaction = true}},
                    {type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = {ignored_by_interaction = true}},
                    at_gui.templates.frame_action_button{sprite="at_pin_white", hovered_sprite="at_pin_black", clicked_sprite="at_pin_black",
                        handlers="main.pin_button", save_as="main.titlebar.pin_button", tooltip={"at-gui.keep-open"}},
                    at_gui.templates.frame_action_button{handlers = "main.close_button", save_as = "main.titlebar.close_button",
                        sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black",
                    }
                }},
                {type = "flow", direction = "horizontal", style = "inset_frame_container_horizontal_flow", children = {
                    {type = "frame", style = "inside_shallow_frame", direction = "vertical", children = {
                        {type = "frame", style = "subheader_frame", children={
                            {type = "label", style = "subheader_caption_label", caption = {"at-gui.logistics-configuration"}},
                            at_gui.templates.pushers.horizontal,
                            {type = "sprite-button", style = "tool_button_green", handlers = "main.apply_changes", style_mods = {padding = 0},
                                sprite = "utility/check_mark_white", tooltip = {"module-inserter-config-button-apply"}},
                            {type = "sprite-button", style = "tool_button_red", save_as = "main.reset_button", handlers = "main.reset",
                                sprite = "utility/reset_white"
                            },
                            {type = "sprite-button", style = "tool_button", handlers = "main.export", sprite = "utility/export_slot",
                                tooltip = {"at-gui.tooltip-export"}
                            },
                            {type = "sprite-button", style = "tool_button", handlers = "main.import", sprite = "at_import_string",
                                tooltip = {"at-gui.tooltip-import"}
                            }
                        }},
                        {type = "flow", direction="vertical", style_mods = {padding= 12, top_padding = 8, vertical_spacing = 10}, children = {
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style = "at_slot_table_scroll_pane", name = "config_rows", save_as = "main.config_rows",
                                    style_mods = {
                                        width = width,
                                        height = pdata.settings.rows * 40
                                    },
                                    children = {
                                        at_gui.templates.slot_table.main(btns, pdata),
                                    }
                                }
                            }},
                            {type = "frame", style = "at_bordered_frame", children = {
                                {type = "flow", direction = "vertical", children = {
                                    {type = "table", save_as = "main.sliders.table", style_mods = {height = 60}, column_count = 2, children = {
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption = {"at-gui.request"}}
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", save_as = "main.sliders.request", handlers = "main.sliders.request",
                                                minimum_value = 0, maximum_value = 10,
                                                style = "notched_slider",
                                            },
                                            {type = "textfield", style = "slider_value_textfield",
                                                numeric = true, allow_negative = false, lose_focus_on_confirm = true,
                                                save_as = "main.sliders.request_text", handlers = "main.sliders.request"
                                            },
                                        }},
                                        {type = "flow", direction = "horizontal", children = {
                                            {type = "label", caption={"at-gui.trash"}},
                                        }},
                                        {type ="flow", style = "at_slider_flow", direction = "horizontal", children = {
                                            {type = "slider", save_as = "main.sliders.trash", handlers = "main.sliders.trash",
                                                minimum_value = 0, maximum_value = 10,
                                                style = "notched_slider",
                                            },
                                            {type = "textfield", style = "slider_value_textfield",
                                                numeric = true, allow_negative = false, lose_focus_on_confirm = true,
                                                save_as = "main.sliders.trash_text", handlers = "main.sliders.trash"
                                            },
                                        }},
                                    }},
                                    {type = "drop-down", style = "at_quick_actions", handlers = "main.quick_actions",
                                        items = constants.quick_actions,
                                        selected_index = 1,
                                        tooltip = {"at-gui.tooltip-quick-actions"}
                                    },
                                    at_gui.templates.pushers.horizontal
                                }}
                            }},
                            at_gui.templates.settings(flags),
                        }},

                    }},
                    {type = "frame", save_as = "main.presets", style = "inside_shallow_frame", direction = "vertical", children = {
                        {type = "frame", style = "subheader_frame", children={
                            {type = "label", style = "subheader_caption_label", caption = {"at-gui.presets"}},
                            at_gui.templates.pushers.horizontal,
                            {type = "sprite-button", style = "tool_button", handlers = "main.export_all", sprite = "utility/export_slot",
                                tooltip = {"at-gui.tooltip-export-all"}},
                            {type = "sprite-button", style = "tool_button", handlers = "main.import_all", sprite = "at_import_string",
                                tooltip = {"at-gui.tooltip-import-all"}},
                        }},
                        {type = "flow", direction="vertical", style = "at_right_container_flow", children = {
                            {type = "flow", children = {
                                {type = "textfield", style = "long_number_textfield", save_as = "main.preset_textfield", handlers = "main.presets.textfield"},
                                at_gui.templates.pushers.horizontal,
                                {type = "button", caption = {"gui-save-game.save"}, style = "at_save_button", handlers = "main.presets.save"}
                            }},
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style = "at_right_scroll_pane", children = {
                                    {type = "flow", direction = "vertical", save_as = "main.presets_flow", style = "at_right_flow_in_scroll_pane", children =
                                        at_gui.templates.presets(pdata),
                                    },
                                }}
                            }},
                        }}
                    }},
                    {type = "frame", save_as = "main.networks", visible = false, style = "inside_shallow_frame", direction = "vertical", children = {
                        {type = "frame", style = "subheader_frame", children={
                            {type = "label", style = "subheader_caption_label", caption = {"gui-logistic.logistic-networks"}},
                            at_gui.templates.pushers.horizontal,
                            {type = "sprite-button", style = "tool_button", handlers = "main.settings.selection_tool", style_mods = {padding = 0},
                                sprite = "autotrash_selection", tooltip = {"at-gui.tooltip-selection-tool"}},
                        }},
                        {type = "flow", direction = "vertical", style = "at_right_container_flow", children = {
                            {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                                {type = "scroll-pane", style = "at_right_scroll_pane", children = {
                                    {type = "flow", direction = "vertical", save_as = "main.networks_flow", style = "at_right_flow_in_scroll_pane", children =
                                        at_gui.templates.networks(pdata),
                                    },
                                }}
                            }},
                        }}
                    }}
                }}
            }},
        }
    }})
    gui_data.main.titlebar.flow.drag_target = gui_data.main.window
    gui_data.main.window.force_auto_center()
    gui_data.main.window.visible = false

    pdata.gui.main = gui_data.main
    if pdata.flags.pinned then
        pdata.gui.main.titlebar.pin_button.style = "flib_selected_frame_action_button"
    end
    pdata.selected = false
end

function at_gui.create_import_window(player, pdata, bp_string, mode)
    if pdata.gui.import and pdata.gui.import.window and pdata.gui.import.window.main.valid then
        local window = pdata.gui.import.window.main
        gui.update_filters("import", player.index, nil, "remove")
        window.destroy()
        pdata.gui.import = nil
    end
    pdata.gui.import = gui.build(player.gui.screen, {at_gui.templates.import_export_window(bp_string, mode)}, pdata.gui)
    local import_window = pdata.gui.import.window
    import_window.titlebar.drag_target = pdata.gui.import.window.main
    import_window.main.force_auto_center()
    local textbox = import_window.textbox
    if bp_string then
        textbox.read_only = true
    end
    textbox.select_all()
    textbox.focus()
end


function at_gui.init(player, pdata)
    at_gui.destroy(player, pdata)
    local visible = pdata.flags.can_open_gui

    local main_button_flow = pdata.gui.mod_gui.flow
    if main_button_flow and main_button_flow.valid then
        main_button_flow.clear()
        gui.update_filters("mod_gui_button", player.index, nil, "remove")
    else
        pdata.gui.mod_gui.flow = mod_gui.get_button_flow(player).add{type = "flow", direction = "horizontal", name = "autotrash_main_flow",
            style = "at_main_flow"
        }
    end
    pdata.gui.mod_gui.button = pdata.gui.mod_gui.flow.add{type = "sprite-button", name = "at_config_button", style = mod_gui.button_style,
        sprite = "autotrash_trash", tooltip = {"at-gui.tooltip-main-button", pdata.flags.status_display_open and "On" or "Off"}}
    gui.update_filters("mod_gui_button", player.index, {pdata.gui.mod_gui.button.index}, "add")
    pdata.gui.mod_gui.flow.visible = visible
    at_gui.init_status_display(player, pdata)
end

at_gui.init_status_display = function(player, pdata, keep_status)
    local status_flow = pdata.gui.status_flow
    if not (status_flow and status_flow.valid) then
        status_flow = mod_gui.get_frame_flow(player).autotrash_status_flow
        if not (status_flow and status_flow.valid) then
            status_flow = mod_gui.get_frame_flow(player).add{type = "flow", name = "autotrash_status_flow", direction = "vertical"}
        end
        pdata.gui.status_flow = status_flow
    end
    status_flow.clear()

    local visible = false
    if keep_status then
        visible = pdata.flags.can_open_gui and pdata.flags.status_display_open
    end
    status_flow.visible = visible
    pdata.flags.status_display_open = visible
    pdata.gui.status_table = nil

    local status_table = status_flow.add{
        type = "table",
        style = "at_request_status_table",
        column_count = pdata.settings.status_columns
    }
    pdata.gui.status_table = status_table

    for _ = 1, pdata.settings.status_count do
        status_table.add{
            type = "sprite-button",
            visible = false
        }
    end
    at_gui.update_status_display(player, pdata)
end

at_gui.open_status_display = function(player, pdata)
    local status_table = pdata.gui.status_table
    if not (status_table and status_table.valid) then
        at_gui.init_status_display(player, pdata)
    end
    if pdata.flags.can_open_gui then
        status_table.parent.visible = true
        pdata.flags.status_display_open = true
        pdata.gui.mod_gui.button.tooltip = {"at-gui.tooltip-main-button", "On"}
        at_gui.update_status_display(player, pdata)
    end
end

at_gui.close_status_display = function(pdata)
    pdata.flags.status_display_open = false
    pdata.gui.mod_gui.button.tooltip = {"at-gui.tooltip-main-button", "Off"}
    local status_table = pdata.gui.status_table
    if not (status_table and status_table.valid) then
        return
    end
    status_table.parent.visible = false
end

at_gui.toggle_status_display = function(player, pdata)
    if pdata.flags.status_display_open then
        at_gui.close_status_display(pdata)
    else
        at_gui.open_status_display(player, pdata)
    end
end

at_gui.update_status_display = function(player, pdata)
    if not pdata.flags.status_display_open then return end
    local status_table = pdata.gui.status_table
    if not (status_table and status_table.valid) then
        at_gui.init_status_display(player, pdata)
    end
    local available, on_the_way, item_count, cursor_stack, armor, gun, ammo = get_network_data(player)
    if not (available and not pdata.flags.pause_requests) then
        for _, child in pairs(status_table.children) do
            child.visible = false
        end
        return true
    end

    local max_count = pdata.settings.status_count
    local get_request_slot = player.character.get_request_slot

    local children = status_table.children
    local c = 1
    for i = 1, player.character_logistic_slot_count do
        local item = get_request_slot(i)
        if item and item.count > 0 then
            if c > max_count then return true end
            item.min = item.count
            if item.min > 0 then
                local style, diff = at_gui.get_button_style(i, false, item, available, on_the_way, item_count, cursor_stack, armor, gun, ammo)
                if style ~= "slot_button" then
                    local button = children[c]
                    button.style = style
                    button.sprite = "item/" .. item.name
                    button.number = diff
                    button.visible = true
                    c = c + 1
                end
            end
        end
    end
    for i = c, max_count do
        children[i].visible = false
    end
    return true
end

function at_gui.update_main_button(pdata)
    local mainButton = pdata.gui.mod_gui.button
    if not (mainButton and mainButton.valid) then
        return
    end
    local flags = pdata.flags
    if flags.pause_trash and not flags.pause_requests then
        mainButton.sprite = "autotrash_trash_paused"
    elseif flags.pause_requests and not flags.pause_trash then
        mainButton.sprite = "autotrash_requests_paused"
    elseif flags.pause_trash and flags.pause_requests then
        mainButton.sprite = "autotrash_both_paused"
    else
        mainButton.sprite = "autotrash_trash"
    end
    mainButton.tooltip = {"at-gui.tooltip-main-button", flags.status_display_open and "On" or "Off"}
    at_gui.update_settings(pdata)
end

function at_gui.update_settings(pdata)
    if not pdata.flags.gui_open then return end
    local frame = pdata.gui.main.trash_options
    if not (frame and frame.valid) then return end
    local flags = pdata.flags
    local def = at_gui.defines

    frame[def.trash_unrequested].state = flags.trash_unrequested
    frame[def.trash_above_requested].state = flags.trash_above_requested
    frame[def.trash_network].state = flags.trash_network
    frame[def.pause_trash].state = flags.pause_trash
    frame[def.pause_requests].state = flags.pause_requests
end

function at_gui.mark_dirty(pdata, keep_presets)
    local reset = pdata.gui.main.reset_button
    reset.enabled = true
    pdata.flags.dirty = true
    if not keep_presets then
        pdata.selected_presets = {}
    end
    at_gui.update_presets(pdata)
end

function at_gui.destroy(player, pdata)
    if pdata.gui.main and pdata.gui.main.window and pdata.gui.main.window.valid then
        pdata.gui.main.window.destroy()
    end
    gui.update_filters("main", player.index, nil, "remove")
    pdata.gui.main = {}
    pdata.flags.gui_open = false
    if pdata.gui.import and pdata.gui.import.window then
        if pdata.gui.import.window.main and pdata.gui.import.window.main.valid then
            pdata.gui.import.window.main.destroy()
        end
    end
    gui.update_filters("import", player.index, nil, "remove")
    pdata.gui.import = {}
end

function at_gui.open(player, pdata)
    if not pdata.flags.can_open_gui then return end
    if not player.character then
        player.print{"at-message.no-character"}
        at_gui.close(player, pdata, true)
        return
    end
    local window_frame = pdata.gui.main.window
    if not (window_frame and window_frame.valid) then
        if window_frame then
            player.print{"at-message.invalid-gui"}
        end
        at_gui.destroy(player, pdata)
        at_gui.create_main_window(player, pdata)
        window_frame = pdata.gui.main.window
    end
    window_frame.visible = true
    pdata.flags.gui_open = true
    if not pdata.flags.pinned then
        player.opened = window_frame
    end

    at_gui.adjust_slots(player, pdata, player.character_logistic_slot_count)
    at_gui.update_buttons(pdata)
    at_gui.update_button_styles(player, pdata)
    at_gui.update_settings(pdata)
    at_gui.update_sliders(pdata)
    at_gui.update_presets(pdata)
end

function at_gui.close(player, pdata, no_reset)
    local window_frame = pdata.gui.main.window
    if window_frame and window_frame.valid then
        window_frame.visible = false
    end
    pdata.flags.gui_open = false
    if not pdata.flags.pinned then
        player.opened = nil
    end
    if pdata.gui.main.networks and pdata.gui.main.presets then
        pdata.gui.main.networks.visible = false
        pdata.gui.main.presets.visible = true
        pdata.gui.main.network_edit_button.style = "tool_button"
    end
    if not no_reset and pdata.settings.reset_on_close then
        pdata.config_tmp = table.deep_copy(pdata.config_new)
        pdata.gui.main.reset_button.enabled = false
        pdata.dirty = false
    end
end

function at_gui.recreate(player, pdata)
    local was_open = pdata.flags.gui_open
    at_gui.destroy(player, pdata)
    if was_open then
        at_gui.open(player, pdata)
    else
        at_gui.create_main_window(player, pdata)
    end
end

function at_gui.toggle(player, pdata)
    if pdata.flags.gui_open then
        at_gui.close(player, pdata)
    else
        at_gui.open(player, pdata)
    end
end
return at_gui