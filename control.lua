require "__core__/lualib/util"

local v = require '__AutoTrash__/semver'
local saveVar = require '__AutoTrash__.lib_control'.saveVar
local convert = require '__AutoTrash__.lib_control'.convert
local debugDump = require '__AutoTrash__.lib_control'.debugDump
local pause_requests = require '__AutoTrash__.lib_control'.pause_requests
local format_number = require '__AutoTrash__.lib_control'.format_number
local mod_gui = require '__core__/lualib/mod-gui'

local MAX_CONFIG_SIZES = {
    ["character-logistic-trash-slots-1"] = 10,
    ["character-logistic-trash-slots-2"] = 30
}

local GUI = require "__AutoTrash__/gui"

local function init_global()
    global = global or {}
    global["config"] = global["config"] or {}
    global["config_tmp"] =  global["config_tmp"] or {}
    global["logistics-config"] = global["logistics-config"] or {}
    global["logistics-config-tmp"] = global["logistics-config-tmp"] or {}
    global["storage"] = global["storage"] or {}
    global.active = global.active or {}
    global.mainNetwork = global.mainNetwork or {}
    global["logistics-active"] = global["logistics-active"] or {}
    global.configSize = global.configSize or {}
    global.temporaryTrash = global.temporaryTrash or {}
    global.temporaryRequests = global.temporaryRequests or {}
    global.settings = global.settings or {}
end

--config[player_index][slot] = {name = "item", min=0, max=100}
--min: if > 0 set as request
--max: if == 0 and trash unrequested
--if min == max : set req = trash
--if min and max : set req and trash, ensure max > min
--if min and not max (== -1?) : set req, unset trash
--if min == 0 and max : unset req, set trash
--if min == 0 and max == 0: unset req, set trash to 0

local function init_player(player)
    local index = player.index
    global.config[index] = global.config[index] or {}
    global["logistics-config"][index] = global["logistics-config"][index] or {}
    global["config_tmp"][index] = global["config_tmp"][index] or {config = {}, settings = {}, max_slot = 0}
    global["logistics-config-tmp"][index] = global["logistics-config-tmp"][index] or {}
    global["logistics-active"][index] = true
    global.active[index] = true
    global.mainNetwork[index] = false
    global.storage[index] = global.storage[index] or {}
    global.temporaryRequests[index] = global.temporaryRequests[index] or {}
    global.temporaryTrash[index] = global.temporaryTrash[index] or {}
    global.settings[index] = global.settings[index] or {}
    if global.settings[index].auto_trash_above_requested == nil then
        global.settings[index].auto_trash_above_requested = false
    end
    if global.settings[index].auto_trash_unrequested == nil then
        global.settings[index].auto_trash_unrequested = false
    end
    if global.settings[index].auto_trash_in_main_network == nil then
        global.settings[index].auto_trash_in_main_network = false
    end

    GUI.init(player)
end

local function init_players(resetGui)
    if not global.mainNetwork then
        init_global()
    end
    for _, player in pairs(game.players) do
        if resetGui then
            GUI.destroy(player)
        end
        init_player(player)
    end
end

local function init_force(force)
    if not global.configSize then
        init_global()
    end
    if not global.configSize[force.name] then
        if force.technologies["character-logistic-trash-slots-2"].researched then
            global.configSize[force.name] = MAX_CONFIG_SIZES["character-logistic-trash-slots-2"]
        else
            global.configSize[force.name] = MAX_CONFIG_SIZES["character-logistic-trash-slots-1"]
        end
    end
end

local function init_forces()
    for _, force in pairs(game.forces) do
        init_force(force)
    end
end

--run once per save
local function on_init()
    init_global()
    init_forces()
    --script.on_event(defines.events.on_tick, function() update_gui() end)
end

-- run when loading/when player joins mp (only on connecting player)
local function on_load()

end


-- run once
local function on_configuration_changed(data)
    if not data or not data.mod_changes then
        return
    end
    --Autotrash changed, got added
    if data.mod_changes.AutoTrash then
        local newVersion = data.mod_changes.AutoTrash.new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes.AutoTrash.old_version or '0.0.0'
        oldVersion = v(oldVersion)
        if oldVersion < v'0.0.55' then
            global = nil
        end

        init_global()
        init_forces()
        init_players()

        if oldVersion < v'0.1.1' then
            for _, p in pairs(game.players) do
                GUI.close(p)
            end
        end

        if oldVersion < v'0.1.3' then
            local cell
            for player_index, network in pairs(global.mainNetwork) do
                if network and network.valid then
                    cell = network.cells[1]
                    if cell and cell.valid then
                        global.mainNetwork[player_index] = cell.owner
                    end
                end
            end
        end

        if oldVersion < v'4.0.1' then
            --saveVar(global, "config_changed")
            init_players(true)
            for _, c in pairs(global.config) do
                for i, p in pairs(c) do
                    if p.name == "" then
                        p.name = false
                    end
                end
            end
            if global["config-tmp"] then
                for _, c in pairs(global["config-tmp"]) do
                    for i, p in pairs(c) do
                        if p.name == "" then
                            p.name = false
                        end
                    end
                end
            end

            for _, c in pairs(global["logistics-config"]) do
                for i, p in pairs(c) do
                    if p.name == "" then
                        p.name = false
                    end
                end
            end
            for _, c in pairs(global["logistics-config-tmp"]) do
                for i, p in pairs(c) do
                    if p.name == "" then
                        p.name = false
                    end
                end
            end

            for i, s in pairs(global.settings) do
                if s.options_extended ~= nil then
                    s.options_extended = nil
                end
            end
            --saveVar(global, "config_changed_done")
        end

        if oldVersion < v'4.0.4' then
            for _, p in pairs(game.players) do
                GUI.destroy_frames(p)
            end
        end

        -- if oldVersion < v'4.1.0' then
        --     convert()
        -- end

        global.version = newVersion
    end
    init_global()
    init_players()
    local items = game.item_prototypes
    for player_index, p in pairs(global.config) do
        for i=#p,1,-1 do
            if not items[p[i].name] then
                table.remove(global.config[player_index], i)
            end
        end
    end
    for player_index, p in pairs(global["config_tmp"]) do
        for i=#p.config,1,-1 do
            if not items[p.config[i].name] then
                table.remove(global["config_tmp"][player_index].config, i)
            end
        end
    end
end

local function on_player_created(event)
    init_player(game.get_player(event.player_index))
end

local function on_force_created(event)
    init_force(event.force)
end

local function requested_items(player)
    local requests = {}
    -- get requested items
    if player.character and player.force.character_logistic_slot_count > 0 then
        for c=1,player.force.character_logistic_slot_count do
            local request = player.character.get_request_slot(c)
            if request and (not requests[request.name] or (requests[request.name] and request.count > requests[request.name])) then
                requests[request.name] = request.count
            end
        end
    end
    return requests
end

local function inMainNetwork(player)
    if not global.settings[player.index].auto_trash_in_main_network then
        return true
    end

    local currentNetwork = player.surface.find_logistic_network_by_position(player.position, player.force)
    local entity = global.mainNetwork[player.index]
    if currentNetwork and entity and entity.valid and currentNetwork == entity.logistic_network then
        return true
    end
    return false
end

local function on_tick(event)
    if event.tick % 120 == 0 then
        local status, err = pcall(function()
            for _, player in pairs(game.players) do
                local player_index = player.index
                if player.valid and player.connected and global.active[player_index]
                    and inMainNetwork(player) then
                    local godController = player.controller_type == defines.controllers.god
                    local main_inventory = godController and player.get_inventory(defines.inventory.god_main) or player.get_inventory(defines.inventory.player_main)
                    local trash = player.get_inventory(defines.inventory.player_trash)
                    local dirty = false
                    if not global.temporaryTrash[player_index] then global.temporaryTrash[player_index] = {} end
                    local requests = requested_items(player)
                    for i=#global.temporaryTrash[player_index],1,-1 do
                        local item = global.temporaryTrash[player_index][i]
                        if item and item.name ~= "" and item.name ~= "blueprint" and item.name ~= "blueprint-book" then
                            local count = player.get_item_count(item.name) --counts main,quick + cursor
                            local requested = requests[item.name] and requests[item.name] or 0
                            local desired = math.max(requested, item.count)
                            local diff = count - desired
                            local t_item, t_index = main_inventory.find_item_stack(item.name)
                            local has_grid = game.item_prototypes[item.name].equipment_grid or (t_item and t_item.grid)
                            if not has_grid then
                                local stack = {name=item.name, count=diff}
                                if diff > 0 then
                                    local c = trash.insert(stack)
                                    if c > 0 then
                                        local removed = player.remove_item{name=item.name, count=c} --temporary items are removed from main,quickbar and cursor
                                        diff = diff - removed
                                        if c > removed then
                                            trash.remove{name=item.name, count = c - removed}
                                        end
                                    end
                                end
                                if diff <= 0 then
                                    player.print({"", "removed ", game.item_prototypes[item.name].localised_name, " from temporary trash"})
                                    global.temporaryTrash[player_index][i] = nil
                                end
                            else --item with equipment grid
                                if diff > 0 and t_item then
                                    for ti = #trash, 1, -1 do
                                        if trash[ti].valid and not trash[ti].valid_for_read then
                                            if trash[ti].swap_stack(main_inventory[t_index]) then
                                                dirty = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local configSize = global.configSize[player.force.name]
                    local already_trashed = {}
                    for i, item in pairs(global.config[player_index]) do
                        if item and item.name and item.name ~= "blueprint" and item.name ~= "blueprint-book" and i <= configSize then
                            already_trashed[item.name] = true
                            local count = player.get_item_count(item.name)
                            local requested = requests[item.name] and requests[item.name] or 0
                            local desired = math.max(requested, item.count)
                            local diff = count - desired
                            local t_item, t_index = main_inventory.find_item_stack(item.name)
                            local has_grid = game.item_prototypes[item.name].equipment_grid or (t_item and t_item.grid)
                            if not has_grid then
                                local stack = {name=item.name, count=diff}
                                if diff > 0 then
                                    local c = trash.insert(stack)
                                    if c > 0 then
                                        local removed = main_inventory.remove{name=item.name, count=c}
                                        if c > removed then
                                            trash.remove{name=item.name, count = c - removed}
                                        end
                                    end
                                end
                            else
                                if diff > 0 and t_item then
                                    for ti = #trash, 1, -1 do
                                        if trash[ti].valid and not trash[ti].valid_for_read then
                                            if trash[ti].swap_stack(main_inventory[t_index]) then
                                                dirty = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local requests_by_name = {}

                    for name, r in pairs(requests) do
                        requests_by_name[name] = true
                        if global.settings[player_index].auto_trash_above_requested then
                            if not already_trashed[name] then
                                local count = player.get_item_count(name)
                                local diff = count - r
                                if diff > 0 then
                                    local t_item, t_index = main_inventory.find_item_stack(name)
                                    local has_grid = game.item_prototypes[name].equipment_grid or (t_item and t_item.grid)
                                    if not has_grid then
                                        local stack = {name=name, count=diff}
                                        local c = trash.insert(stack)
                                        if c > 0 then
                                            local removed = main_inventory.remove{name=name, count=c}
                                            if c > removed then
                                                trash.remove{name=name, count = c - removed}
                                            end
                                        end
                                    else
                                        if t_item then
                                            for ti = #trash, 1, -1 do
                                                if trash[ti].valid and not trash[ti].valid_for_read then
                                                    if trash[ti].swap_stack(main_inventory[t_index]) then
                                                        dirty = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if global.settings[player_index].auto_trash_unrequested then
                        if main_inventory and not main_inventory.is_empty() then
                            local contents = main_inventory.get_contents()
                            local stack = {name="", count = 0}
                            for name, count in pairs(contents) do
                                if not requests_by_name[name] and name ~= "blueprint" and name ~= "blueprint-book" then
                                    local t_item, t_index = main_inventory.find_item_stack(name)
                                    local has_grid = game.item_prototypes[name].equipment_grid or (t_item and t_item.grid)
                                    if not has_grid then
                                        stack.name = name
                                        stack.count = count
                                        local c = trash.insert(stack)
                                        if c > 0 then
                                            local removed = main_inventory.remove{name=name, count=c}
                                            if c > removed then
                                                trash.remove{name=name, count = c - removed}
                                            end
                                        end
                                    else
                                        if t_item then
                                            for ti = #trash, 1, -1 do
                                                if trash[ti].valid and not trash[ti].valid_for_read then
                                                    if trash[ti].swap_stack(main_inventory[t_index]) then
                                                        dirty = true
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if dirty then
                        trash.sort_and_merge()
                    end
                end
            end
        end)
        if not status then
            debugDump(err, true)
        end
    end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
script.on_event(defines.events.on_tick, on_tick)

local function on_pre_mined_item(event)
    local status, err = pcall(function()
        if event.entity.type == "roboport" then
            for player_index, entity in pairs(global.mainNetwork) do
                if entity == event.entity then
                    --get another roboport from the network
                    local newEntity = false
                    if entity.logistic_network and entity.logistic_network.valid then
                        for _, cell in pairs(entity.logistic_network.cells) do
                            if cell.owner ~= entity and cell.owner.valid then
                                newEntity = cell.owner
                                break
                            end
                        end
                    end
                    if not newEntity and global.mainNetwork[player_index] then
                        game.get_player(player_index).print("Autotrash main network has been unset")
                    end
                    global.mainNetwork[player_index] = newEntity
                end
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

script.on_event(defines.events.on_pre_player_mined_item, on_pre_mined_item)
script.on_event(defines.events.on_robot_pre_mined, on_pre_mined_item)
script.on_event(defines.events.on_entity_died, on_pre_mined_item)

--script.on_event(defines.events.on_built_entity, on_built_entity)
--script.on_event(defines.events.on_robot_built_entity, on_built_entity)


local function add_order(player)
    local entities = player.cursor_stack.get_blueprint_entities()
    local orders = {}
    for _, ent in pairs(entities) do
        if not orders[ent.name] then
            orders[ent.name] = 0
        end
        orders[ent.name] = orders[ent.name] + 1
    end
    --debugDump(orders,true)
end

local function add_to_trash(player, item, count)
    local player_index = player.index
    global.temporaryTrash[player_index] = global.temporaryTrash[player_index] or {}
    if global.active[player_index] == nil then global.active[player_index] = true end
    for i=#global.temporaryTrash[player_index],1,-1 do
        local t_item = global.temporaryTrash[player_index][i]
        if t_item and t_item.name == "" then
            break
        end
        local requests = requested_items(player)
        local pcount = player.get_item_count(t_item.name)
        local desired = requests[t_item.name] and requests[t_item.name] + t_item.count or t_item.count
        local diff = pcount - desired
        if diff < 1 then
            player.print({"", "removed ", game.item_prototypes[t_item.name].localised_name, " from temporary trash"})
            global.temporaryTrash[player_index][i] = nil
        end
    end

    if #global.temporaryTrash[player_index] >= 5 then
        player.print({"", "Couldn't add ", game.item_prototypes[item].localised_name, " to temporary trash."})
        return
    end
    table.insert(global.temporaryTrash[player_index], {name = item, count = count})
    player.print({"", "added ", game.item_prototypes[item].localised_name, " to temporary trash"})
end

--function add_to_requests(player, item, count)
--  local player_index = player.index
--  global.temporaryRequests[player_index] = global.temporaryRequests[player_index] or {}
--  if global["logistics-active"][player_index] == nil then global["logistics-active"][player_index] = true end
--  local index = false
--
--  for i=#global.temporaryRequests[player_index],1,-1 do
--    local req = global.temporaryRequests[player_index][i]
--    if req and req.name == "" then
--      break
--    end
--    if req.name == item then
--      index = i
--    end
--  end
--
--  if #global.temporaryRequests[player_index] > player.force.character_logistic_slot_count then
--    player.print({"", "Couldn't add ", game.item_prototypes[item].localised_name, " to temporary requests."})
--    return
--  end
--
--  if not index then
--    table.insert(global.temporaryTrash[player_index], {name = item, count = count})
--  else
--    global.temporaryTrash[player_index][index].count = global.temporaryTrash[player_index][index].count + count
--  end
--
--  table.insert(global.temporaryRequests[player_index], {name = item, count = count})
--  player.print({"", "added ", game.item_prototypes[item].localised_name, " to temporary requests"})
--end

local function unpause_requests(player)
    local player_index = player.index
    if not global.storage[player_index] then
        global.storage[player_index] = {}
    end
    local storage = global.storage[player_index].requests or {}
    local slots = player.force.character_logistic_slot_count
    if player.character and slots > 0 then
        for c=1, slots do
            if storage[c] then
                player.character.set_request_slot(storage[c], c)
            end
        end
        global.storage[player_index].requests = {}
    end
end

local function toggle_autotrash_pause(player, element)
    global.active[player.index] = not global.active[player.index]
    local mainButton = player.gui.top[GUI.mainFlow][GUI.mainButton]
    if global.active[player.index] then
        mainButton.sprite = "autotrash_trash"
        if element then
            element.caption = {"auto-trash-config-button-pause"}
        end
    else
        mainButton.sprite = "autotrash_trash_paused"
        if element then
            element.caption = {"auto-trash-config-button-unpause"}
        end
    end
    GUI.close(player)
end

local function toggle_autotrash_pause_requests(player)
    global["logistics-active"][player.index] = not global["logistics-active"][player.index]
    local mainButton = player.gui.top[GUI.mainFlow][GUI.logisticsButton]
    if global["logistics-active"][player.index] then
        mainButton.sprite = "autotrash_logistics"
        unpause_requests(player)
    else
        mainButton.sprite = "autotrash_logistics_paused"
        pause_requests(player)
    end
    GUI.close(player)
end

local function unselect_elem_button(player_index, parent)
    local selected = global.selected[player_index]
    local element = selected and parent[selected]
    if selected and element then
        element.style = "logistic_button_slot"
        log("unselect: " .. serpent.line({elem=element.elem_value, locked = element.locked}))
        element.locked = element.elem_value or false
    end
    global.selected[player_index] = false
    GUI.update_sliders(player_index, false)
    log("selected: " .. serpent.line(global.selected[player_index]))
end

local function select_elem_button(player_index, element)
    local selected = global.selected[player_index]
    log("locked: " .. serpent.line(element.locked))
    log("old selected " .. serpent.line(selected))
    if selected then
        if selected ~= element.name then
            unselect_elem_button(player_index, element.parent)
        else
            return
        end
    end
    if element.elem_value and element.locked then
        element.locked = false
        element.style = "logistic_button_selected_slot"
        global.selected[player_index] = element.name
    end
    GUI.open_logistics_frame(game.get_player(player_index), true)
    log("new selected " .. serpent.line(global.selected[player_index]))
end

local function on_gui_click(event)
    local status, err = pcall(function()
        local element = event.element
        if element.type == "checkbox" then
            return
        end
        local player_index = event.player_index
        if element.type == "choose-elem-button" then
            local index = tonumber(string.match(element.name, "auto%-trash%-item%-(%d+)"))
            index = tonumber(index)
            log("on click " .. serpent.line(element.name))
            log(serpent.line(event))
            log(serpent.line({elem=element.elem_value, locked = element.locked, selected = global.selected[player_index]}))
            if not index then
                return
            end
            if event.button == defines.mouse_button_type.left then
                if element.elem_value then
                    if element.locked then
                        unselect_elem_button(player_index, element.parent)
                        select_elem_button(player_index, element)
                        return
                    else
                        return
                    end
                else
                    unselect_elem_button(player_index, element.parent)
                end
            -- clear the button here, since it's locked and gui_elem_changed doesn't trigger
            elseif event.button == defines.mouse_button_type.right then
                element.elem_value = nil
                element.locked = false
                global["config_tmp"][player_index].config[index] = nil
                element.children[1].caption = ""
                element.children[2].caption = ""
                unselect_elem_button(player_index, element.parent)
                GUI.open_logistics_frame(game.get_player(player_index), true)
            end
            return
        end
        -- log(serpent.block(event))
        -- log(serpent.block({name = element.name}))
        local player = game.get_player(player_index)
        if element.name == "auto-trash-config-button" then
            if player.cursor_stack.valid_for_read then
                if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
                    add_order(player)
                elseif player.cursor_stack.name ~= "blueprint" then
                    add_to_trash(player, player.cursor_stack.name, 0)
                end
            else
                GUI.open_frame(player)
            end
        elseif element.name == "auto-trash-apply" or element.name == "auto-trash-logistics-apply" then
            GUI.save_changes(player)
        elseif element.name == "auto-trash-clear-all" or element.name == "auto-trash-logistics-clear-all" then
            GUI.clear_all(player)
        elseif element.name == "auto-trash-pause" then
            toggle_autotrash_pause(player)
        elseif element.name == "auto-trash-logistics-button" then
            GUI.open_logistics_frame(player)
        elseif element.name == "auto-trash-logistics-pause" then
            toggle_autotrash_pause_requests(player)
        elseif element.name  == "auto-trash-logistics-storage-store" then
            GUI.store(player)
        elseif element.name == "auto-trash-set-main-network" then
            if global.mainNetwork[player_index] then
                global.mainNetwork[player_index] = false
            else
                local network = player.surface.find_logistic_network_by_position(player.position, player.force) or false
                if network then
                    local cell = network.find_cell_closest_to(player.position)
                    global.mainNetwork[player_index] = cell and cell.owner or false
                end
                if not global.mainNetwork[player_index] then
                    GUI.display_message(mod_gui.get_frame_flow(player)[GUI.configFrame], false, "auto-trash-not-in-network")
                end
            end
            element.caption = global.mainNetwork[player.index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
        else
            event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
            local type, index, _ = string.match(element.name, "auto%-trash%-(%a+)%-(%d+)%-*(%d*)")
            if not type then
                type, index, _ = string.match(element.name, "auto%-trash%-logistics%-(%a+)%-(%d+)%-*(%d*)")
            end
            --log(serpent.block({t=type, i=tonumber(index)}))
            if type and index then
                if type == "restore" then
                    GUI.restore(player, tonumber(index))
                elseif type == "remove" then
                    GUI.remove(player, tonumber(index))
                end
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_checked_changed_state(event)
    local status, err = pcall(function()
        local element = event.element

        --log(serpent.block(element.name))
        --log(serpent.block(element.state))
        --saveVar(global, "pre_checked_changed")
        local player_index = event.player_index
        local player = game.get_player(player_index)

        if element.name == GUI.trash_in_main_network then
            global.settings[player_index].auto_trash_in_main_network = not global.settings[player_index].auto_trash_in_main_network
            GUI.update_settings(player)
        elseif element.name == GUI.trash_above_requested then
            global.settings[player_index].auto_trash_above_requested = not global.settings[player_index].auto_trash_above_requested
            if global.settings[player_index].auto_trash_unrequested and not global.settings[player_index].auto_trash_above_requested then
                global.settings[player_index].auto_trash_above_requested = true
                player.print({"", "'", {"auto-trash-above-requested"}, "' has to be active if '", {"auto-trash-unrequested"}, "' is active"})
            end
            GUI.update_settings(player)
        elseif element.name == GUI.trash_unrequested then
            global.settings[player_index].auto_trash_unrequested = not global.settings[player_index].auto_trash_unrequested
            if global.settings[player_index].auto_trash_unrequested then
                global.settings[player_index].auto_trash_above_requested = true
            end
            GUI.update_settings(player)
        end
        --saveVar(global, "post_checked_changed")
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_elem_changed(event)
    local status, err = pcall(function()
        log("elem_changed: " .. event.element.name)
        local element = event.element
        local player_index = event.player_index
        --event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
        local index = tonumber(string.match(element.name, "auto%-trash%-item%-(%d+)"))
        index = tonumber(index)
        if not index then
            return
        end
        local elem_value = element.elem_value

        --log(serpent.line({i=index, elem_value = elem_value}))
        if elem_value then
            local i = GUI.set_item(game.get_player(player_index), index, element)
            log("set_item " .. serpent.line(i))
            if i == true then
                element.locked = true
                select_elem_button(event.player_index, element)
            elseif i then
                local name = "auto-trash-item-" .. i
                select_elem_button(event.player_index, element.parent[name])
            end
        else
            global["config_tmp"][player_index].config[index] = nil
            element.children[1].caption = ""
            element.children[2].caption = ""
            unselect_elem_button(event.player_index, element.parent)
            GUI.open_logistics_frame(game.get_player(player_index), true)
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function update_selected_value(player_index, flow, number)
    local n = math.floor(tonumber(number) or 50)
    flow["at-config-slider-text"].text = n > -1 and n or "∞"
    flow["at-config-slider"].slider_value = n
    local frame_new = flow.parent.parent["at-config-scroll"]["at-ruleset-grid"]
    -- log(global.selected[player_index])
    -- log(serpent.line(#frame_new.children))
    local i = tonumber(string.match(global.selected[player_index], "auto%-trash%-item%-(%d+)"))

    local button = frame_new.children[i]
    if not button or not button.valid then
        return
    end
    local item_config = global["config_tmp"][player_index].config[i] and global["config_tmp"][player_index].config[i] or {name = false, trash = 0, request = 0}
    item_config.name = button.elem_value

    if flow.name == "at-slider-flow-request" then
        item_config.request = n
        if button then
            button.children[1].caption = format_number(n, true)
        end
    elseif flow.name == "at-slider-flow-trash" then
        item_config.trash = n
        if button then
            button.children[2].caption = n > -1 and format_number(n, true) or "∞"
        end
    end
    global["config_tmp"][player_index].config[i] = item_config
end

local function on_gui_value_changed(event)
    if not global.selected[event.player_index] then
        return
    end
    if not event.element.name == "at-config-slider" then
        return
    end
    update_selected_value(event.player_index, event.element.parent, event.element.slider_value)
end

local function on_gui_text_changed(event)
    if not global.selected[event.player_index] then
        return
    end
    if not event.element.name == "at-config-slider-text" then
        return
    end
    update_selected_value(event.player_index, event.element.parent, event.element.text)
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_changed_state)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

local function on_research_finished(event)
    init_global()
    if event.research.name == "character-logistic-trash-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player, "trash")
        end
        return
    end
    if event.research.name == "character-logistic-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player, "requests")
        end
        return
    end
    if event.research.name == "character-logistic-trash-slots-2" then
        global.configSize[event.research.force.name] = MAX_CONFIG_SIZES["character-logistic-trash-slots-2"]
    end
end
script.on_event(defines.events.on_research_finished, on_research_finished)

local function autotrash_pause(event)
    local player = game.get_player(event.player_index)
    if player.force.technologies["character-logistic-trash-slots-1"].researched then
        toggle_autotrash_pause(player)
    end
end
script.on_event("autotrash_pause", autotrash_pause)

local function autotrash_pause_requests(event)
    local player = game.get_player(event.player_index)
    if player.force.technologies["character-logistic-slots-1"].researched then
        toggle_autotrash_pause_requests(player)
    end
end
script.on_event("autotrash_pause_requests", autotrash_pause_requests)

local function autotrash_trash_cursor(event)
    local player = game.get_player(event.player_index)
    if player.force.technologies["character-logistic-trash-slots-1"].researched then
        local cursorStack = player.cursor_stack
        if cursorStack.valid_for_read then
            add_to_trash(player, cursorStack.name, 0)
        else
            toggle_autotrash_pause(player)
        end
    end
end
script.on_event("autotrash_trash_cursor", autotrash_trash_cursor)

--/c remote.call("at","saveVar")
remote.add_interface("at",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        convert = function()
            convert()
            init_global()
            init_players()
        end,

        init = function()
            init_global()
            init_forces()
            init_players()
        end,

        setConfigSize = function(size1, size2)
            local s1 = size1 and size1 or MAX_CONFIG_SIZES["character-logistic-trash-slots-1"]
            local s2 = size2 and size2 or MAX_CONFIG_SIZES["character-logistic-trash-slots-2"]
            if s1 > s2 then
                s1, s2 = s2, s1
            end
            --check max size (to avoid gui hanging out of the game
            s1 = s1 > 80 and 80 or s1
            s2 = s2 > 80 and 80 or s2
            --update all forces
            if not global.configSize then
                init_global()
            end
            for _, force in pairs(game.forces) do
                if force.technologies["character-logistic-trash-slots-2"].researched then
                    global.configSize[force.name] = s2
                else
                    global.configSize[force.name] = s1
                end
            end
        end,

        debugLog = function()
            for i,p in pairs(game.players) do
                local name = p.name or "noName"
                local c_valid = "not connected"
                if p.connected then
                    c_valid = (p.character and p.character.valid) and p.character.name or "false"
                end
                if p.controller_type == defines.controllers.god then
                    c_valid = "god controller"
                end
                debugDump("Player: "..name.." index: "..i.." character: "..c_valid,true)
            end
        end,

        reset = function(confirm)
            if confirm then
                global = nil
                init_global()
                init_forces()
                init_players()
            end
        end,

        init_gui = function()
            GUI.init(game.player)
        end,

        hide = function()
            if game.player.gui.top[GUI.mainFlow] then
                game.player.gui.top[GUI.mainFlow].visible = false
            end
        end,

        show = function()
            if game.player.gui.top[GUI.mainFlow] then
                game.player.gui.top[GUI.mainFlow].visible = true
            end
        end,
    })
