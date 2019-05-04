require "__core__/lualib/util"
local mod_gui = require '__core__/lualib/mod-gui'

local v = require '__AutoTrash__/semver'
local lib_control = require '__AutoTrash__.lib_control'
local GUI = require "__AutoTrash__/gui"
local presets = require "__AutoTrash__/presets"

local saveVar = lib_control.saveVar
local debugDump = lib_control.debugDump
local display_message = lib_control.display_message
local format_number = lib_control.format_number
local format_request = lib_control.format_request
local format_trash = lib_control.format_trash
local convert_from_slider = lib_control.convert_from_slider

local gui_def = GUI.defines
local floor = math.floor

local function cleanup_table(tbl, tbl_name)
    if tbl then
        log("Cleaning " .. tostring(tbl_name) or "table")
        for pi, stored in pairs(tbl) do
            log("Processing: " .. pi)
            local r = 0
            for i, p in pairs(stored) do
                if p and not p.name or (p.name and p.name == "") then
                    stored[i] = nil
                    r = r + 1
                end
            end
            if r > 0 then
                log("Removed " .. r .. " invalied entries")
            end
        end
    end
end

local function convert_logistics()
    log("Merging Request and Trash slots")
    local tmp, config, no_slot
    local max_slot = 0
    for player_index, stored in pairs(global["logistics-config"]) do
        local player = game.get_player(player_index)
        if player then
            log("Processing requests for: " .. tostring(player.name) .. " (" .. player_index .. ")")
            tmp = {config = {}, config_by_name = {}, settings = {}}
            for i, p in pairs(stored) do
                tmp.config[i] = {
                    name = p.name,
                    request = p.count and p.count or 0,
                    trash = false,
                    slot = i
                }
                tmp.config_by_name[p.name] = tmp.config[i]
                max_slot = max_slot < i and i or max_slot
                log(serpent.line(tmp.config[i]))
            end
            no_slot = {}
            log("Merging trash for: " .. tostring(player.name) .. " (" .. player_index .. ")")
            for i, trash in pairs(global.config[player_index]) do
                config = tmp.config_by_name[trash.name]
                if config then
                    if config.request > trash.count then
                        log("Adjusting trash amount for " .. trash.name .. " from " .. trash.count .. " to " .. config.request)
                    end
                    config.trash = (config.request > trash.count) and config.request or trash.count
                    log(serpent.line(config))
                else
                    tmp.config_by_name[trash.name] = {
                        name = trash.name,
                        request = 0,
                        trash = trash.count,
                        slot = false
                    }
                    log("Adding " .. serpent.line(tmp.config_by_name[trash.name]))
                    no_slot[#no_slot+1] = tmp.config_by_name[trash.name]
                end
            end
            saveVar(global, "premerge")
            local start = 1
            for _, s in pairs(no_slot) do
                for i = start, max_slot + #no_slot do
                    if not tmp.config[i] then
                        s.slot = i
                        tmp.config[i] = s
                        start = i + 1
                        log("Assigning slot " .. serpent.line(s))
                        break
                    end
                end
            end
            global.config_tmp[player_index] = tmp
        end
    end
end

local function convert_storage(storage)
    if not storage or not storage.store then return end

    if storage.requests and table_size(storage.requests) > 0 then
        for i, p in pairs(storage.requests) do
            if p and (p.name == false or p.name == "") then
                storage.requests[i] = nil
            end
        end
        storage.store["paused_requests"] = storage.requests
    end
    local tmp = {}
    for name, stored in pairs(storage.store) do
        log("Converting: " .. name)
        tmp[name] = {config = {}, config_by_name = {}, settings = {}}
        for i, p in pairs(stored) do
            tmp[name].config[i] = {
                name = p.name,
                request = p.count and p.count or 0,
                trash = false,
                slot = i
            }
            tmp[name].config_by_name[p.name] = tmp[name].config[i]
            log(serpent.line(tmp[name].config[i]))
        end
    end
    return tmp
end

local function set_requests(player)
    if player.character then
        local character = player.character
        local storage = global.config_new[player.index].config
        local set_request_slot = character.set_request_slot
        local clear_request_slot = character.clear_request_slot
        local req

        for c = 1, character.request_slot_count do
            req = storage[c]
            if req then
                set_request_slot({name = req.name, count = req.request}, c)
            else
                clear_request_slot(c)
            end
        end
    end
end

local function get_requests(player)
    if not player.character then
        return {}
    end
    local requests = {}
    local get_request_slot = player.character.get_request_slot
    local t, max_slot
    for c = player.character.request_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = {name = t.name, request = t.count, slot = c}
        end
    end
    return requests, max_slot
end

local function get_requests_by_index(player)--luacheck: ignore
    if not player.character then
        return {}
    end
    local requests = {}
    local get_request_slot = player.character.get_request_slot
    local t, max_slot
    for c = player.character.request_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[c] = {name = t.name, request = t.count, slot = c}
        end
    end
    return requests, max_slot
end

local function requested_items(player)
    if not player.character then
        return {}
    end
    local requests = {}
    local get_request_slot = player.character.get_request_slot
    local t, max_slot
    for c = player.character.request_slot_count, 1, -1 do
        t = get_request_slot(c)
        if t then
            max_slot = not max_slot and c or max_slot
            requests[t.name] = t.count
        end
    end
    return requests
end

local function combine_from_vanilla(player)
    if not player.character then return end
    local tmp = {config = {}, config_by_name = {}}
    local requests, max_slot = get_requests(player)
    local trash = player.auto_trash_filters
    log(serpent.block(trash))
--    local no_slot = {}
    for name, config in pairs(requests) do
        config.trash = false
        tmp.config[config.slot] = config
        tmp.config_by_name[name] = config
        if trash[name] then
            config.trash = trash[name] > config.request and trash[name] or config.request
            trash[name] = nil
        end
    end
    local no_slot = {}
    for name, count in pairs(trash) do
        tmp.config_by_name[name] = {
            name = name,
            request = 0,
            trash = count,
            slot = false
        }
        no_slot[#no_slot+1] = tmp.config_by_name[name]
    end
    local start = 1
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
    saveVar(tmp, "_combined")
    log(serpent.block(tmp))
    return tmp
end

local function set_trash(player)
    if player.character then
        local trash_filters = {}
        --TODO ensure trash >= requests
        for name, item_config in pairs(global.config_new[player.index].config_by_name) do
            if item_config.trash then
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
    log("init_global")
    global = global or {}
    global["config"] = global["config"] or {}
    global["config_new"] = global["config_new"] or {}
    global["config_tmp"] =  global["config_tmp"] or {}
    global.selected = global.selected or {}
    global["storage"] = global["storage"] or {}
    global["storage_new"] = global["storage_new"] or {}

    global.mainNetwork = global.mainNetwork or {}
    global.temporaryTrash = global.temporaryTrash or {}
    global.temporaryRequests = global.temporaryRequests or {}
    global.settings = global.settings or {}
    global.dirty = global.dirty or {}
    global.selected_presets = global.selected_presets or {}
end

--[[
config[player_index][slot] = {name = "item", min = 0, max = 100}
min: if > 0 set as request
max: if == 0 and trash unrequested
if min == max : set req = trash
if min and max : set req and trash, ensure max > min
if min and not max (== -1?) : set req, unset trash
if min == 0 and max : unset req, set trash
if min == 0 and max == 0: unset req, set trash to 0
]]

local function init_player(player)
    log("init_player " .. player.name)
    local index = player.index
    global.config[index] = global.config[index] or {}
    global.config_new[index] = global.config_new[index] or {config = {}, config_by_name = {}, settings = {}}
    global["config_tmp"][index] = global["config_tmp"][index] or {config = {}, config_by_name = {}, settings = {}}
    global.selected[index] = global.selected[index] or false

    global.mainNetwork[index] = false
    global.storage[index] = global.storage[index] or {}
    global.storage_new[index] = global.storage_new[index] or {}
    global.temporaryRequests[index] = global.temporaryRequests[index] or {}
    global.temporaryTrash[index] = global.temporaryTrash[index] or {}
    global.settings[index] = global.settings[index] or util.table.deepcopy(default_settings)
    global.dirty[index] = global.dirty[index] or false
    global.selected_presets[index] = global.selected_presets[index] or {}
    GUI.init(player)
end

local function init_players(resetGui)
    for _, player in pairs(game.players) do
        if resetGui then
            GUI.destroy(player)
        end
        init_player(player)
    end
end

local function on_init()
    log("on_init")
    init_global()
end

local function on_load()
    log("on_load")
    assert(1 == GUI.index_from_name(gui_def.choose_button .. 1), "Update GUI.index_from_name, you fool!")--TODO remove
end

local function on_pre_player_removed(event)
    log("Removing invalid player index " .. event.player_index)
    for name, _ in pairs(global) do
        log("    Removing " .. name)
        if name ~= "version" then
            global[name][event.player_index] = nil
        end
    end
end

local function on_configuration_changed(data)
    log(serpent.block(data))
    if not data then
        return
    end
    if data.mod_changes and data.mod_changes.AutoTrash then
        local newVersion = data.mod_changes.AutoTrash.new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes.AutoTrash.old_version
        oldVersion = oldVersion and v(oldVersion)
        log("Updating AutoTrash from " .. tostring(oldVersion) .. " to " .. tostring(newVersion))
        if oldVersion then
            if oldVersion < v'0.0.55' then
                global = nil
            end
            init_global()
            init_players()

            if oldVersion < v'4.0.1' then
                init_players(true)
                if global.config then
                    for _, c in pairs(global.config) do
                        for i, p in pairs(c) do
                            if p.name == "" then
                                p.name = false
                            end
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
                    s.options_extended = nil
                end
            end

            if oldVersion < v'4.0.6' then
                saveVar(global, "storage_pre_cleanup")
                global.needs_import = {}
                global.config[10] = {}
                for pi, _ in pairs(global.config) do
                    if not game.get_player(pi) then
                        on_pre_player_removed{player_index = pi}
                    end
                end

                for i, p in pairs(game.players) do
                    GUI.close(p)
                    global.needs_import[i] = true
                end
                --script.on_nth_tick()

                if global.active then
                    for i, active in pairs(global.active) do
                        global.settings[i].pause_trash = not active
                    end
                end
                if global["logistics-active"] then
                    for i, active in pairs(global["logistics-active"]) do
                        global.settings[i].pause_requests = not active
                    end
                end

                cleanup_table(global.config,'global.config')
                cleanup_table(global["logistics-config"],'global["logistics-config"]')

                saveVar(global, "storage_pre")
                convert_logistics()

                if global.storage then
                    for _, storage in pairs(global.storage) do
                        cleanup_table(storage.store, 'global.storage' .. '[' .. _ .. '].store')
                    end
                end

                for player_index, player in pairs(game.players) do
                    log("Converting storage for " .. player.name .. " (" .. player_index .. ")")
                    global.storage_new[player_index] = convert_storage(global.storage[player_index])
                end

                global.guiData = nil
                global["logistics-active"] = nil
                global.active = nil
                global["config-tmp"] = nil
                global["logistics-config-tmp"] = nil

                saveVar(global, "storage_post")
                --error()
            end
        end

        global.version = newVersion
    end

    init_global()
    init_players()
    local items = game.item_prototypes

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
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = true
    --TODO backup current requests?
    local character = player.character
    for c = 1, character.request_slot_count do
        character.clear_request_slot(c)
    end
    GUI.update(player)
end

local function unpause_requests(player)
    if not player.character then
        return
    end
    global.settings[player.index].pause_requests = false
    --TODO restore current requests?
    set_requests(player)
    GUI.update(player)
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
    --log("main inventory changed " .. serpent.block(event))
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
                if not requests[name] and not trash_filters[name]  and not trash_blacklist[protos[name].type] then
                    trash_filters[name] = 0
                end
            end
            player.auto_trash_filters = trash_filters
        end
    end
end

local function on_player_trash_inventory_changed(event)
    local player = game.get_player(event.player_index)
    local inventory = player.get_main_inventory()
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    local desired, changed
    for name, saved_count in pairs(global.temporaryTrash[player.index]) do
        if trash_filters[name] then
             desired = requests[name] and requests[name] or 0
            if inventory.get_item_count(name) <= desired then
                player.print({"", "removed ", game.item_prototypes[name].localised_name, " from temporary trash"})
                log("Removed ".. name .. " " .. serpent.block(event))
                trash_filters[name] = tonumber(saved_count)
                global.temporaryTrash[player.index][name] = nil
                changed = true
            end
        end
    end
    if changed then
        player.auto_trash_filters = trash_filters
    end
end

local function add_to_trash(player, item)
    log("add to trash " .. game.tick)
    local player_index = player.index
    if trash_blacklist[item] then
        display_message(player, {"", game.item_prototypes[item].localised_name, " is on the blacklist for trashing"}, true)
        return
    end
    global.temporaryTrash[player_index][item] = player.auto_trash_filters[item] or true --true: wasn't set, remove when cleaning temporaryTrash
    local trash_filters = player.auto_trash_filters
    local requests = requested_items(player)
    if not trash_filters[item] then
        trash_filters[item] = requests[item] or 0
        log(serpent.block(trash_filters))
        player.auto_trash_filters = trash_filters
    end
    player.print({"", "Added ", game.item_prototypes[item].localised_name, " to temporary trash"})
end

local function on_player_toggled_map_editor(event)
    log("toggled map editor " .. serpent.block(event))
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
script.on_event(defines.events.on_player_main_inventory_changed, on_player_main_inventory_changed)
script.on_event(defines.events.on_player_trash_inventory_changed, on_player_trash_inventory_changed)

script.on_event(defines.events.on_player_toggled_map_editor, on_player_toggled_map_editor)
script.on_event(defines.events.on_pre_player_removed, on_pre_player_removed)
script.on_event(defines.events.on_pre_player_died, on_pre_player_died)
script.on_event(defines.events.on_player_changed_position, on_player_changed_position)

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
        log("Unselect: " .. serpent.line({i = selected, item = element.elem_value}))
        element.locked = element.elem_value or false
    end
    global.selected[player_index] = false
    GUI.update_sliders(game.get_player(player_index))
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
        GUI.update_sliders(game.get_player(player_index))
    end
    log("Selected " .. serpent.line({i = global.selected[player_index], item = element.elem_value}))
    GUI.create_buttons(game.get_player(player_index))
end

local function clear_elem_button(player_index, index, element)
    local name = element.elem_value or global["config_tmp"][player_index].config[index].name
    global["config_tmp"][player_index].config_by_name[name] = nil
    global["config_tmp"][player_index].config[index] = nil
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
        local player = game.get_player(player_index)
        local left = mod_gui.get_frame_flow(player)
        local config_frame = left[gui_def.config_frame]
        local storage_frame = left[gui_def.storage_frame]
        if config_frame and not config_frame.valid then
            log("Invalid config frame")
            GUI.close(player)
            return
        end
        if storage_frame and not storage_frame.valid then
            log("Invalid storage frame")
            GUI.close(player)
            return
        end
        log("on click " .. serpent.line(element.name))
        log(serpent.line(event))

        if element.name == gui_def.main_button then
            if event.button == defines.mouse_button_type.right then
                GUI.open_quick_presets(player, element.parent)
            else
                GUI.close_quick_presets(player, element.parent)
                if player.cursor_stack.valid_for_read then
                    if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
                        add_order(player)
                    elseif player.cursor_stack.name ~= "blueprint" then
                        add_to_trash(player, player.cursor_stack.name)
                    end
                else
                    if left[gui_def.config_frame] then
                        GUI.close(player, left)
                    else
                        GUI.open_logistics_frame(player)
                    end
                end
            end
            return
        end

        if element.type == "choose-elem-button" then
            local index = GUI.index_from_name(element.name)
            --log(serpent.line({elem = element.elem_value, locked = element.locked, selected = global.selected[player_index]}))
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

        --No gui, nothing to do anymore
        if not config_frame then
            return
        end

        if element.name == gui_def.save_button then
            GUI.apply_changes(player, element)
            if not global.settings[player_index].pause_trash then
                set_trash(player)
            end
            if not global.settings[player_index].pause_requests then
                set_requests(player)
            end
        elseif element.name == gui_def.reset_button then
            GUI.reset_changes(player, element)
        elseif element.name == gui_def.clear_button then
            GUI.clear_all(player, element)
        elseif element.name  == gui_def.store_button then
            GUI.store(player, element)
        elseif element.name == gui_def.set_main_network then
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
            element.caption = global.mainNetwork[player_index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
        elseif element.name == gui_def.import_vanilla then
            global.config_tmp[player_index] = combine_from_vanilla(player)
            GUI.create_buttons(player)
            GUI.update_sliders(player)
        else
            local type, index, _ = string.match(element.name, "autotrash_preset_(%a+)_(%d*)")
            if type and index then
                log(serpent.line({t = type, i = index}))
                if type == "load" then
                    if not event.shift and not event.control then
                        GUI.restore(player, element)
                    else
                        local selected_presets = global.selected_presets[player_index]
                        if not selected_presets[element.caption] then
                            log("merging preset")
                            selected_presets[element.caption] = index
                        else
                            log("unmerging preset")
                            selected_presets[element.caption] = nil
                        end
                        global.config_tmp[player_index] = {config = {}, config_by_name = {}, settings = {}}
                        for name, _ in pairs(selected_presets) do
                            global.config_tmp[player_index] = presets.merge(global.config_tmp[player_index], global.storage_new[player_index][name])
                        end
                        GUI.update_presets(player)
                        GUI.create_buttons(player)
                        GUI.update_sliders(player)
                    end
                elseif type == "delete" then
                    GUI.remove(player, element, tonumber(index))
                else
                    error("Unexpected type/index from " .. element.name)--TODO remove
                end
                log(serpent.block(global.selected_presets[player_index]))
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

        if element.name == gui_def.trash_in_main_network then
            if element.state and not global.mainNetwork[player_index] then
                player.print("No main network set")
                element.state = false
            else
                global.settings[player_index].auto_trash_in_main_network = element.state
                if element.state and inMainNetwork(player) then
                    unpause_trash(player)
                end
            end
        elseif element.name == gui_def.trash_above_requested then
            global.settings[player_index].auto_trash_above_requested = element.state
            if global.settings[player_index].auto_trash_unrequested and not global.settings[player_index].auto_trash_above_requested then
                global.settings[player_index].auto_trash_above_requested = true
                element.state = true
                player.print({"", "'", {"auto-trash-above-requested"}, "' has to be active if '", {"auto-trash-unrequested"}, "' is active"})
            end
        elseif element.name == gui_def.trash_unrequested then
            global.settings[player_index].auto_trash_unrequested = element.state
            if global.settings[player_index].auto_trash_unrequested then
                global.settings[player_index].auto_trash_above_requested = true
                element.parent[gui_def.trash_above_requested].state = true
            end
        elseif element.name == gui_def.pause_trash then
            if element.state then
                pause_trash(player)
            else
                unpause_trash(player)
            end
        elseif element.name == gui_def.pause_requests then
            if element.state then
                pause_requests(player)
            else
                unpause_requests(player)
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_gui_selection_state_changed(event)
    local status, err = pcall(function()
        log(serpent.block(event))
        local player_index = event.player_index
        local player = game.get_player(player_index)
        local name = event.element.get_item(event.element.selected_index)
        if global.storage_new[event.player_index][name] then
            global.selected_presets[player_index] = {[name] = true}
            global.config_new[player_index] = util.table.deepcopy(global.storage_new[player_index][name])
            global.selected[player_index] = false
            global.dirty[player_index] = false
            if not global.settings[player_index].pause_trash then
                set_trash(player)
            end
            if not global.settings[player_index].pause_requests then
                set_requests(player)
            end
            display_message(player, "Preset '" .. tostring(name) .. "' loaded", "success")
        else
            display_message(player, "Unknown preset: " .. tostring(name), true)
        end
        event.element.destroy()
    end)
    if not status then
        if event.element and event.element.valid then
            event.element.destroy()
        end
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
                select_elem_button(event.player_index, element.parent[gui_def.choose_button .. i])
            end
        else
            clear_elem_button(player_index, index, element)
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local max = 2^32-1
local function update_selected_value(player_index, element, number, check)
    local n = floor(tonumber(number) or 0)
    n = n <= max and n or max
    local flow = element.parent
    local player = game.get_player(player_index)
    local frame_new = GUI.get_ruleset_grid(player)
    local i = global.selected[player_index]

    local button = frame_new and frame_new.children[i]
    if not button or not button.valid then
        GUI.update_sliders(player)
        return
    end
    assert(button.elem_value)--TODO remove
    global["config_tmp"][player_index].config[i] = global["config_tmp"][player_index].config[i] or {name = false, trash = 0, request = 0}
    global["config_tmp"][player_index].config_by_name[button.elem_value] = global["config_tmp"][player_index].config[i]
    local item_config = global["config_tmp"][player_index].config[i]
    item_config.name = button.elem_value

    if flow.name == gui_def.config_request then
        assert(n >= 0, "request has to be a positive number") --TODO remove
        item_config.request = n
        button.children[1].caption = format_number(format_request(item_config), true)
        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if item_config.trash and n > item_config.trash then
            item_config.trash = n
            button.children[2].caption = format_number(format_trash(item_config), true)
        end
    elseif flow.name == gui_def.config_trash then
        if element.type == "slider" and element.slider_value == 42 then
            n = false
        end
        item_config.trash = n
        button.children[2].caption = format_number(format_trash(item_config), true)

        --prevent trash being set to a lower value than request to prevent infinite robo loop
        if check and n and item_config.request > n then
            item_config.request = n
            button.children[2].caption = format_number(format_request(item_config), true)
        end
    end
    global.dirty[player_index] = true
    GUI.update_sliders(player)
end

local function on_gui_value_changed(event)
    if event.element.name ~= gui_def.config_slider then
        return
    end
    if not global.selected[event.player_index] then
        GUI.update_sliders(game.get_player(event.player_index))
        return
    end
    if event.element.name == gui_def.config_slider then
        update_selected_value(event.player_index, event.element, convert_from_slider(event.element.slider_value), true)
    end
end

local function on_gui_text_changed(event)
    if event.element.name ~= gui_def.config_slider_text then
        return
    end
    if not global.selected[event.player_index] then
        GUI.update_sliders(game.get_player(event.player_index))
        return
    end
    if event.element.name == gui_def.config_slider_text then
        update_selected_value(event.player_index, event.element, event.element.text)
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
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

local function on_research_finished(event)
    if event.research.name == "character-logistic-trash-slots-1" or
        event.research.name == "character-logistic-slots-1" then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player)
        end
        return
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
            add_to_trash(player, cursorStack.name)
        else
            toggle_autotrash_pause(player)
        end
    end
end
script.on_event("autotrash_trash_cursor", autotrash_trash_cursor)

local at_commands = {
    reload = function()
    game.reload_mods()

    local button_flow = mod_gui.get_button_flow(game.player)[GUI.defines.main_button]
    if button_flow and button_flow.valid then
        button_flow.destroy()
    end

    init_global()
    init_players()
    game.player.print("Mods reloaded")
end
}

commands.add_command("reload_mods", "", at_commands.reload)

--/c remote.call("at","saveVar")
remote.add_interface("at",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init_gui = function()
            GUI.init(game.player)
        end,

        hide = function()
            local button = mod_gui.get_button_flow(game.player)[gui_def.main_button]
            if button then
                button.visible = false
            end
        end,

        show = function()
            local button = mod_gui.get_button_flow(game.player)[gui_def.main_button]
            if button then
                button.visible = true
            end
        end
    })
