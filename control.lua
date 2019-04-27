require "__core__/lualib/util"

local v = require '__AutoTrash__/semver'
local lib_control = require '__AutoTrash__.lib_control'
local saveVar = lib_control.saveVar
local convert = lib_control.convert
local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_from_slider = lib_control.convert_from_slider
local mod_gui = require '__core__/lualib/mod-gui'

local GUI = require "__AutoTrash__/gui"

local floor = math.floor

local MAX_CONFIG_SIZES = {
    ["character-logistic-trash-slots-1"] = 10,
    ["character-logistic-trash-slots-2"] = 30
}

local function set_requests(player)
    if player.character then
        local storage = global.config_new[player.index].config
        local slots = player.force.character_logistic_slot_count
        if slots > 0 then
            local req
            for c=1, slots do
                req = storage[c]
                if req then
                    player.character.set_request_slot({name = req.name, count = req.request > -1 and req.request or 0}, c)
                else
                    player.character.clear_request_slot(c)
                end
            end
        end
    end
end

local function get_requests(player)
    local requests = {}
    if player.character and player.force.character_logistic_slot_count > 0 then
        local character = player.character
        local t
        for c=1,player.force.character_logistic_slot_count do
            t = character.get_request_slot(c)
            if t then
                requests[t.name] = t.count
            end
        end
    end
    return requests
end

local function set_trash(player)
    if player.character then
        local trash_filters = {}
        --TODO ensure trash >= requests
        for name, item_config in pairs(global.config_new[player.index].config_by_name) do
            if item_config.trash and item_config.trash > -1 then
                trash_filters[name] = item_config.trash
            end
        end
        player.auto_trash_filters = trash_filters
    end
end

local default_settings = {
    auto_trash_above_requested = false,
    auto_trash_unrequested = false,
    auto_trash_in_main_network = false,
    pause_trash = false,
    pause_requests = false,
}

local function init_global()
    global = global or {}
    global["config"] = global["config"] or {}
    global["config_new"] = global["config_new"] or {}
    global["config_tmp"] =  global["config_tmp"] or {}
    global.selected = global.selected or {}
    global["storage"] = global["storage"] or {}
    global["storage_new"] = global["storage_new"] or {}

    global.mainNetwork = global.mainNetwork or {}
    global.configSize = global.configSize or {}
    global.temporaryTrash = global.temporaryTrash or {}
    global.temporaryRequests = global.temporaryRequests or {}
    global.settings = global.settings or {}
end

--[[
config[player_index][slot] = {name = "item", min=0, max=100}
min: if > 0 set as request
max: if == 0 and trash unrequested
if min == max : set req = trash
if min and max : set req and trash, ensure max > min
if min and not max (== -1?) : set req, unset trash
if min == 0 and max : unset req, set trash
if min == 0 and max == 0: unset req, set trash to 0
]]

local function init_player(player)
    local index = player.index
    global.config[index] = global.config[index] or {}
    global.config_new[index] = global.config_new[index] or {}
    global["config_tmp"][index] = global["config_tmp"][index] or {config = {}, config_by_name = {}, settings = {}, slot = false}
    global.selected[index] = global.selected[index] or false

    global.mainNetwork[index] = false
    global.storage[index] = global.storage[index] or {}
    global.storage_new[index] = global.storage_new[index] or {}
    global.temporaryRequests[index] = global.temporaryRequests[index] or {}
    global.temporaryTrash[index] = global.temporaryTrash[index] or {}
    global.settings[index] = global.settings[index] or util.table.deepcopy(default_settings)

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

local function on_init()
    init_global()
    init_forces()
end

local function on_load()
    assert(1 == GUI.index_from_name(GUI.defines.choose_button .. 1), "Update GUI.index_from_name, you fool!")--TODO remove
end

local function on_configuration_changed(data)
    if not data then
        return
    end
    if data.mod_changes and data.mod_changes.AutoTrash then
        local newVersion = data.mod_changes.AutoTrash.new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes.AutoTrash.old_version or '0.0.0'
        oldVersion = v(oldVersion)
        if oldVersion < v'0.0.55' then
            global = nil
        end
        log("Updating AutoTrash from " .. tostring(oldVersion) .. " to " .. tostring(newVersion))
        init_global()
        init_forces()
        init_players()

        if oldVersion < v'4.0.1' then
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

            if global["logistics-config"] then
                for _, c in pairs(global["logistics-config"]) do
                    for i, p in pairs(c) do
                        if p.name == "" then
                            p.name = false
                        end
                    end
                end
            end

            if global["logistics-config-tmp"] then
                for _, c in pairs(global["logistics-config-tmp"]) do
                    for i, p in pairs(c) do
                        if p.name == "" then
                            p.name = false
                        end
                    end
                end
            end

            for i, s in pairs(global.settings) do
                if s.options_extended ~= nil then
                    s.options_extended = nil
                end
            end
        end

        if oldVersion < v'4.0.6' then
            for i, p in pairs(game.players) do
                GUI.init(p)
                global.config_tmp[i].config_by_name = global.config_tmp[i].config_by_name or {}
                global.config_new[i].config_by_name = global.config_new[i].config_by_name or {}
            end
            for pi, config in pairs(global.config_tmp) do
                for i, item in pairs(config.config) do
                    if item then
                        item.slot = i
                        global.config_tmp[pi].config_by_name[item.name] = item
                    end
                end
            end

            for pi, config in pairs(global.config_new) do
                if config and config.config then
                    for i, item in pairs(config.config) do
                        if item then
                            item.slot = i
                            global.config_new[pi].config_by_name[item.name] = item
                        end
                    end
                end
            end
            for pi, pstorage in pairs(global.storage_new) do
                for name, config in pairs(pstorage) do
                    global.storage_new[pi][name].config_by_name = global.storage_new[pi][name].config_by_name or {}
                    for i, item in pairs(config.config) do
                        if item then
                            item.slot = i
                            global.storage_new[pi][name].config_by_name[item.name] = item
                        end
                    end
                end
            end
            if global.active then
                for i, active in pairs(global.active) do
                    global.settings[i].pause_trash = not active
                end
                global.active = nil
            end

            if global["logistics-active"] then
                for i, active in pairs(global["logistics-active"]) do
                    global.settings[i].pause_requests = not active
                end
            end
            global["logistics-active"] = nil
        end

        -- if oldVersion < v'4.0.2' then
        --     convert()
        -- end
        global.version = newVersion
    end

    init_global()
    init_players()
    local items = game.item_prototypes
    if not global.config_new then convert() end
    for _, p in pairs(global.config_new) do
        for i, item_config in pairs(p.config) do
            if item_config and not items[item_config.name] then
                    p.config[i] = nil
                    p.config_by_name[item_config.name] = nil
            end
        end
    end
    for pi, p in pairs(global["config_tmp"]) do
        for i, item_config in pairs(p.config) do
            if item_config and not items[item_config.name] then
                    p.config[i] = nil
                    p.config_by_name[item_config.name] = nil
                    if global.selected[pi] and global.selected[pi] == i then
                        global.selected[pi] = false
                    end
                    GUI.create_buttons(game.get_player(pi))
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
    local currentNetwork = player.character.logistic_network
    local entity = global.mainNetwork[player.index]
    if currentNetwork and entity and entity.valid and currentNetwork == entity.logistic_network then
        return true
    end
    return false
end

local function pause_trash(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_trash = true
    --TODO backup current filters?
    player.character.auto_trash_filters = {}
    GUI.update(player)
end

local function unpause_trash(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_trash = false
    --TODO restore current filters?
    set_trash(player)
    GUI.update(player)
end

local function pause_requests(player)
    error("Needs rewrite!")
    --mainButton.sprite = "autotrash_logistics_paused"
    local player_index = player.index
    if not global.storage[player_index] then
        global.storage[player_index] = {requests={}}
    end
    global.storage[player_index].requests = global.storage[player_index].requests or {}

    local storage = global.storage[player_index].requests
    if player.character and player.force.character_logistic_slot_count > 0 then
        for c=1,player.force.character_logistic_slot_count do
            local request = player.character.get_request_slot(c)
            if request then
                storage[c] = {name = request.name, count = request.count}
                player.character.clear_request_slot(c)
                --requests[request.name] = request.count
            end
        end
    end
end

local function unpause_requests(player)
    error("Needs rewrite!")
    --mainButton.sprite = "autotrash_logistics"
    local player_index = player.index
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

local function on_tick(event) --luacheck: ignore
    if event.tick % 120 == 0 then
        local status, err = pcall(function()
            for _, player in pairs(game.players) do
                local player_index = player.index
                if player.valid and player.character and not global.settings[player_index].pause_trash
                    and inMainNetwork(player) then
                    local godController = player.controller_type == defines.controllers.god
                    local main_inventory = godController and player.get_inventory(defines.inventory.god_main) or player.get_inventory(defines.inventory.player_main)
                    local trash = player.get_inventory(defines.inventory.player_trash)
                    local dirty = false

                    local requests = requested_items(player)
                    for i=#global.temporaryTrash[player_index],1,-1 do
                        local item = global.temporaryTrash[player_index][i]
                        if item and item.name ~= "" and item.name ~= "blueprint" and item.name ~= "blueprint-book" then
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
                                        local removed = player.remove_item{name=item.name, count=c}
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

                    for name, r in pairs(requests) do
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

local trash_blacklist = {
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-item"] = true,
    ["upgrade-item"] = true,
    ["copy-paste-tool"] = true,
    ["selection-tool"] = true,
}

local function on_player_main_inventory_changed(event)
    log("main inventory changed " .. serpent.block(event))
    -- if not trash_blacklist then
    --     trash_blacklist = {}
    --     for name, proto in pairs(game.item_prototypes) do
    --         if not proto.stackable then
    --         log(name .. " " .. proto.type)
    --         end
    --     end
    -- end
    if not global.settings[event.player_index].pause_trash and global.settings[event.player_index].auto_trash_unrequested then
        local player = game.get_player(event.player_index)
        if player.character then
            local trash_filters = player.auto_trash_filters
            local contents = player.get_main_inventory().get_contents()
            local requests = get_requests(player)
            local protos = game.item_prototypes
            for name, _ in pairs(contents) do
                --TODO checking for trash_filters[name] would allow hand set exceptions, either set in the vanilla gui or the stored rulesets
                --possible problem when unchecking "unrequested" what trash filters should be reset to?
                --the one in global.config or the ones set in vanilla before it was checked (needs saving in global)
                if not requests[name] and not trash_blacklist[protos[name].type] and not trash_filters[name] then
                    trash_filters[name] = 0
                end
            end
            player.auto_trash_filters = trash_filters
        end
    end
end

-- local function on_player_trash_inventory_changed(event)
--     log("trash inventory changed " .. serpent.block(event))
-- end

local function on_player_toggled_map_editor(event)
    log("toggled map editor " .. serpent.block(event))
end

local function on_pre_player_removed(event)
    for k, name in pairs(global) do
        if name ~= "configSize" then
            global[name][event.player_index] = nil
        end
    end
end

local function on_pre_player_died(event)
    log("pre player died " .. serpent.block(event))
    local player = game.get_player(event.player_index)
    if player.mod_settings["autotrash_pause_on_death"].value then
        pause_requests(player)
    end
end

local function on_player_changed_position(event)
    if not global.settings[event.player_index].auto_trash_in_main_network then
        return
    end
    local player = game.get_player(event.player_index)
    if player.character then
        local in_network = inMainNetwork(player)
        local paused = global.settings[event.player_index].pause_trash
        if not in_network and not paused then
            pause_trash(player)
            if player.mod_settings["autotrash_display_messages"].value then
                display_message(player, "AutoTrash paused")
            end
            return
        elseif in_network and paused then
            unpause_trash(player)
            if player.mod_settings["autotrash_display_messages"].value then
                display_message(player, "AutoTrash unpaused")
            end
        end
    end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
script.on_event(defines.events.on_player_main_inventory_changed, on_player_main_inventory_changed)
--script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)

script.on_event(defines.events.on_player_toggled_map_editor, on_player_toggled_map_editor)
script.on_event(defines.events.on_pre_player_removed, on_pre_player_removed)
script.on_event(defines.events.on_pre_player_died, on_pre_player_died)
script.on_event(defines.events.on_player_changed_position, on_player_changed_position)
--script.on_event(defines.events.on_tick, on_tick)

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

local function add_order(player)
    local entities = player.cursor_stack.get_blueprint_entities()
    local orders = {}
    for _, ent in pairs(entities) do
        if not orders[ent.name] then
            orders[ent.name] = 0
        end
        orders[ent.name] = orders[ent.name] + 1
    end
end

local function add_to_trash(player, item, count)
    error("Rewrite that crap")
    local player_index = player.index

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

function add_to_requests(player, item, count)--luacheck: ignore

end

local function toggle_autotrash_pause(player)
    if global.settings[player.index].pause_trash then
        unpause_trash(player)
    else
        pause_trash(player)
    end
    GUI.close(player)
end

local function toggle_autotrash_pause_requests(player)
    if global.settings[player.index].pause_requests then
        unpause_requests(player)
    else
        pause_requests(player)
    end
    GUI.close(player)
end

local function unselect_elem_button(player_index, parent)
    local selected = global.selected[player_index]
    local element = selected and parent.children[selected]
    if selected and element then
        element.style = "logistic_button_slot"
        log("Unselect: " .. serpent.line({i=selected, item = element.elem_value}))
        element.locked = element.elem_value or false
    end
    global.selected[player_index] = false
    GUI.update_sliders(player_index)
end

local function select_elem_button(player_index, element)
    local selected = global.selected[player_index]
    if selected then
        if element.parent.children[selected].name ~= element.name then
            unselect_elem_button(player_index, element.parent)
        else
            return
        end
    end
    if element.elem_value then
        if element.locked then
            element.locked = false
            element.style = "logistic_button_selected_slot"
            global.selected[player_index] = GUI.index_from_name(element.name)
        end
        GUI.update_sliders(player_index)
    end
    log("Selected " .. serpent.line({i = global.selected[player_index], item = element.elem_value}))
    GUI.create_buttons(game.get_player(player_index))
end

local function clear_elem_button(player_index, index, element)
    global["config_tmp"][player_index].config[index] = nil
    global["config_tmp"][player_index].config_by_name[element.elem_value] = nil
    element.elem_value = nil
    element.locked = false
    element.children[1].caption = " "
    element.children[2].caption = " "
    unselect_elem_button(player_index, element.parent)
    GUI.create_buttons(game.get_player(player_index))
end

local function on_gui_click(event)
    local status, err = pcall(function()
        local element = event.element
        if not element.valid or element.type == "checkbox" then
            return
        end
        local player_index = event.player_index
        if element.type == "choose-elem-button" then
            local index = GUI.index_from_name(element.name)
            -- log("on click " .. serpent.line(element.name))
            -- log(serpent.line(event))
            --log(serpent.line({elem=element.elem_value, locked = element.locked, selected = global.selected[player_index]}))
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
                clear_elem_button(player_index, index, element)
            end
            return
        end

        local player = game.get_player(player_index)
        if element.name == GUI.defines.mainButton then
            if player.cursor_stack.valid_for_read then
                if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
                    add_order(player)
                elseif player.cursor_stack.name ~= "blueprint" then
                    add_to_trash(player, player.cursor_stack.name, 0)
                end
            else
                GUI.open_logistics_frame(player)
            end
        elseif element.name == GUI.defines.save_button then
            GUI.save_changes(player)
            set_requests(player)
            set_trash(player)
            if global.settings[player_index].pause_trash then
                pause_trash(player)
            end
            if global.settings[player_index].pause_requests then
                pause_requests(player)
            end
        elseif element.name == GUI.defines.clear_button then
            GUI.clear_all(player)
        elseif element.name  == GUI.defines.store_button then
            GUI.store(player, element)
        elseif element.name == GUI.defines.set_main_network then
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
            element.caption = global.mainNetwork[player.index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
        else
            element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
            local type, index, _ = string.match(element.name, "auto%-trash%-(%a+)%-(%d+)%-*(%d*)")
            if not type then
                type, index, _ = string.match(element.name, "auto%-trash%-logistics%-(%a+)%-(%d+)%-*(%d*)")
            end
            --log(serpent.block({t=type, i=tonumber(index), gui_index = element.index}))
            if type and index then
                if type == "restore" then
                    GUI.restore(player, element.caption)
                elseif type == "remove" then
                    GUI.remove(player, element, tonumber(index))
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

        local player_index = event.player_index
        local player = game.get_player(player_index)

        if element.name == GUI.defines.trash_in_main_network then
            if element.state and not global.mainNetwork[player_index] then
                player.print("No main network set")
                element.state = false
            else
                global.settings[player_index].auto_trash_in_main_network = element.state
                if element.state and inMainNetwork(player) then
                    unpause_trash(player)
                end
            end
        elseif element.name == GUI.defines.trash_above_requested then
            global.settings[player_index].auto_trash_above_requested = element.state
            if global.settings[player_index].auto_trash_unrequested and not global.settings[player_index].auto_trash_above_requested then
                global.settings[player_index].auto_trash_above_requested = true
                element.state = true
                player.print({"", "'", {"auto-trash-above-requested"}, "' has to be active if '", {"auto-trash-unrequested"}, "' is active"})
            end
        elseif element.name == GUI.defines.trash_unrequested then
            global.settings[player_index].auto_trash_unrequested = element.state
            if global.settings[player_index].auto_trash_unrequested then
                global.settings[player_index].auto_trash_above_requested = true
                element.parent[GUI.defines.trash_above_requested].state = true
            end
        elseif element.name == GUI.defines.pause_trash then
            if element.state then
                pause_trash(player)
            else
                unpause_trash(player)
            end
        elseif element.name == GUI.defines.pause_requests then
            if element.state then
                log("Pause requests")
                --pause_requests(player)
            else
                log("Unpause requests")
                --unpause_requests(player)
            end
        end
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
        local index = GUI.index_from_name(element.name)
        if not index then
            return
        end
        local elem_value = element.elem_value

        if elem_value then
            local i = GUI.set_item(game.get_player(player_index), index, element)
            if i == true then
                element.locked = true
                select_elem_button(event.player_index, element)
            elseif i then
                select_elem_button(event.player_index, element.parent[GUI.defines.choose_button .. i])
            end
        else
            clear_elem_button(player_index, index, element)
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function update_selected_value(player_index, flow, number)
    local n = floor(tonumber(number) or 0)
    local frame_new = flow.parent.parent["at-config-scroll"]["at-ruleset-grid"]
    local i = global.selected[player_index]

    local button = frame_new.children[i]
    if not button or not button.valid then--TODO or not button.elem_value ?
        return
    end
    global["config_tmp"][player_index].config[i] = global["config_tmp"][player_index].config[i] or {name = false, trash = 0, request = 0}
    global["config_tmp"][player_index].config_by_name[button.elem_value] = global["config_tmp"][player_index].config[i]
    local item_config = global["config_tmp"][player_index].config[i]
    item_config.name = button.elem_value

    if flow.name == "at-slider-flow-request" then
        item_config.request = n
        button.children[1].caption = format_number(format_request(item_config), true)
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and item_config.trash > -1 and item_config.request > item_config.trash then
            item_config.trash = item_config.request
            button.children[2].caption = format_number(format_trash(item_config), true)
        end
    elseif flow.name == "at-slider-flow-trash" then
        item_config.trash = n
        button.children[2].caption = format_number(format_trash(item_config), true)

        -- if item_config.request and item_config.request > n then
        --     item_config.trash = item_config.request
        -- end
    end
    GUI.update_sliders(player_index)
end

local function on_gui_value_changed(event)
    if event.element.name ~= "at-config-slider" then
        return
    end
    if not global.selected[event.player_index] then
        GUI.update_sliders(event.player_index)
        return
    end
    if event.element.name == "at-config-slider" then
        update_selected_value(event.player_index, event.element.parent, convert_from_slider(event.element.slider_value))
    end
end

local function on_gui_text_changed(event)
    if event.element.name ~= "at-config-slider-text" then
        return
    end
    if not global.selected[event.player_index] then
        GUI.update_sliders(event.player_index)
        return
    end
    if event.element.name == "at-config-slider-text" then
        update_selected_value(event.player_index, event.element.parent, event.element.text)
    end
end

local gui_settings = {
    ["autotrash_gui_columns"] = true,
    ["autotrash_gui_max_rows"] = true,
    ["autotrash_slots"] = true,
}
local function on_runtime_mod_setting_changed(event)
    if gui_settings[event.setting] then
        if event.player_index then
            GUI.create_buttons(game.get_player(event.player_index))
        else
            --update all guis, value was changed by script
            for _, player in pairs(game.players) do
                GUI.create_buttons(player)
            end
        end
    end
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_changed_state)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

local function on_research_finished(event)
    init_global()
    if event.research.name == "character-logistic-trash-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player)
        end
        return
    end
    if event.research.name == "character-logistic-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player)
        end
        return
    end
    if event.research.name == "character-logistic-trash-slots-2" then
        global.configSize[event.research.force.name] = MAX_CONFIG_SIZES["character-logistic-trash-slots-2"]
    end
end
script.on_event(defines.events.on_research_finished, on_research_finished)

script.on_event("autotrash_pause", function(e)
    toggle_autotrash_pause(game.get_player(e.player_index))
end)

script.on_event("autotrash_pause_requests", function(e)
    toggle_autotrash_pause_requests(game.get_player(e.player_index))
end)

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
            local button = mod_gui.get_button_flow(game.player)[GUI.defines.mainButton]
            if button then
                button.visible = false
            end
        end,

        show = function()
            local button = mod_gui.get_button_flow(game.player)[GUI.defines.mainButton]
            if button then
                button.visible = true
            end
        end,
    })
