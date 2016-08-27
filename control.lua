require "util"

MAX_CONFIG_SIZES = {
  ["character-logistic-trash-slots-1"] = 10,
  ["character-logistic-trash-slots-2"] = 30
}
MAX_STORAGE_SIZE = 6

require "gui"

local function init_global()
  global = global or {}
  global["config"] = global["config"] or {}
  global["config-tmp"] =  global["config-tmp"] or {}
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
  global.guiData = global.guiData or {}
end

local function init_player(player)
  local index = player.index
  global.config[index] = global.config[index] or {}
  global["logistics-config"][index] = global["logistics-config"][index] or {}
  global["config-tmp"][index] = global["config-tmp"][index] or {}
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
  if global.settings[index].options_extended == nil then
    global.settings[index].options_extended = false
  end
  if global.settings[index].auto_trash_in_main_network == nil then
    global.settings[index].auto_trash_in_main_network = false
  end

  global.guiData[index] = global.guiData[index] or {}

  gui_init(player)
end

local function init_players(resetGui)
  if not global.mainNetwork then
    init_global()
  end
  for i,player in pairs(game.players) do
    if resetGui then
      gui_destroy(player)
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
  for i, force in pairs(game.forces) do
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
    local oldVersion = data.mod_changes.AutoTrash.old_version or "0.0.0"

    if oldVersion < "0.0.55" then
      global = nil
    end

    init_global()
    init_forces()
    init_players()

    if oldVersion < "0.1.1" then
      for _, p in pairs(game.players) do
        gui_close(p)
      end
    end

    if oldVersion < "0.1.3" then
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

    global.version = newVersion
  end

  local items = game.item_prototypes
  for player_index, p in pairs(global.config) do
    for i=#p,1,-1 do
      if not items[p[i].name] then
        table.remove(global.config[player_index], i)
      end
    end
  end
  for player_index, p in pairs(global["config-tmp"]) do
    for i=#p,1,-1 do
      if not items[p[i].name] then
        table.remove(global["config-tmp"][player_index], i)
      end
    end
  end
end

local function on_player_created(event)
  init_player(game.players[event.player_index])
end

local function on_force_created(event)
  init_force(event.force)
end

local function on_forces_merging(event)
--debugDump(event,true)
end

function count_keys(hashmap)
  local result = 0
  for _, __ in pairs(hashmap) do
    result = result + 1
  end
  return result
end

function requested_items(player)
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

function get_requests(player)
  local requests = {}
  -- get requested items
  if player.character and player.force.character_logistic_slot_count > 0 then
    for c=1,player.force.character_logistic_slot_count do
      requests[c] = player.character.get_request_slot(c)
    end
  end
  return requests
end

function set_requests(player, requests)
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

function inMainNetwork(player)
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

function on_tick(event)
  if event.tick % 120 == 0 then
    local status, err = pcall(function()
      for _, player in pairs(game.players) do
        local player_index = player.index
        if player.valid and player.connected and global.config[player_index] and global.active[player_index]
          and inMainNetwork(player) then
          local godController = player.controller_type == defines.controllers.god
          local main_inventory = godController and player.get_inventory(defines.inventory.god_main) or player.get_inventory(defines.inventory.player_main)
          local trash = player.get_inventory(defines.inventory.player_trash)

          if not global.temporaryTrash[player_index] then global.temporaryTrash[player_index] = {} end
          local requests = requested_items(player)
          for i=#global.temporaryTrash[player_index],1,-1 do
            local item = global.temporaryTrash[player_index][i]
            if item and item.name ~= "" and item.name ~= "blueprint" and item.name ~= "blueprint-book" then
              local count = player.get_item_count(item.name) --counts main,quick + cursor
              local requested = requests[item.name] and requests[item.name] or 0
              local desired = math.max(requested, item.count)
              local diff = count - desired
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
            end
          end
          local configSize = global.configSize[player.force.name]
          local already_trashed = {}
          for i, item in pairs(global.config[player_index]) do
            if item and item.name ~= "" and item.name ~= "blueprint" and item.name ~= "blueprint-book" and i <= configSize then
              already_trashed[item.name] = item.count
              local count = player.get_item_count(item.name)
              local requested = requests[item.name] and requests[item.name] or 0
              local desired = math.max(requested, item.count)
              local diff = count - desired
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
            end
          end
          local requests_by_name = {}

          --local config = global.config[player_index]
          for name, r in pairs(requests) do
            requests_by_name[name] = true
            if global.settings[player_index].auto_trash_above_requested then
              if not already_trashed[name] then
                local count = player.get_item_count(name)
                local diff = count - r
                if diff > 0 then
                  local stack = {name=name, count=diff}
                  local c = trash.insert(stack)
                  if c > 0 then
                    local removed = main_inventory.remove{name=name, count=c}
                    if c > removed then
                      trash.remove{name=name, count = c - removed}
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
                  stack.name = name
                  stack.count = count
                  local c = trash.insert(stack)
                  if c > 0 then
                    local removed = main_inventory.remove{name=name, count=c}
                    if c > removed then
                      trash.remove{name=name, count = c - removed}
                    end
                  end
                end
              end
            end
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
script.on_event(defines.events.on_forces_merging, on_forces_merging)
script.on_event(defines.events.on_tick, on_tick)

function on_pre_mined_item(event)
  if event.entity.type == "roboport" then
    for player_index, entity in pairs(global.mainNetwork) do
      if entity == event.entity then
        --get another roboport from the network
        local newEntity = false
        for _, cell in pairs(entity.logistic_network.cells) do
          if cell.owner ~= entity and cell.owner.valid then
            newEntity = cell.owner
            break
          end
        end
        global.mainNetwork[player_index] = newEntity
      end
    end
  end
end

script.on_event(defines.events.on_preplayer_mined_item, on_pre_mined_item)
script.on_event(defines.events.on_robot_pre_mined, on_pre_mined_item)
script.on_event(defines.events.on_entity_died, on_pre_mined_item)

--script.on_event(defines.events.on_built_entity, on_built_entity)
--script.on_event(defines.events.on_robot_built_entity, on_built_entity)


function add_order(player)
  local entities = player.cursor_stack.get_blueprint_entities()
  local orders = {}
  for _, ent in pairs(entities) do
    if not orders[ent.name] then
      orders[ent.name] = 0
    end
    orders[ent.name] = orders[ent.name] + 1
  end
  debugDump(orders,true)
end

function add_to_trash(player, item, count)
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

function pause_requests(player)
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

function unpause_requests(player)
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

function toggle_autotrash_pause(player, element)
  global.active[player.index] = not global.active[player.index]
  local mainButton = player.gui.top[GUI.mainFlow][GUI.mainButton]
  if global.active[player.index] then
    mainButton.style = "auto-trash-button"
    if element then
      element.caption = {"auto-trash-config-button-pause"}
    end
  else
    mainButton.style = "auto-trash-button-paused"
    if element then
      element.caption = {"auto-trash-config-button-unpause"}
    end
  end
  gui_close(player)
end

function toggle_autotrash_pause_requests(player)
  global["logistics-active"][player.index] = not global["logistics-active"][player.index]
  local mainButton = player.gui.top[GUI.mainFlow][GUI.logisticsButton]
  if global["logistics-active"][player.index] then
    mainButton.style = "auto-trash-logistics-button"
    unpause_requests(player)
  else
    mainButton.style = "auto-trash-logistics-button-paused"
    pause_requests(player)
  end
  gui_close(player)
end

script.on_event(defines.events.on_gui_click, function(event)
  local status, err = pcall(function()
    local element = event.element
    --debugDump(element.name, true)
    local player_index = event.player_index
    local player = game.players[player_index]
    if element.name == "auto-trash-config-button" then
      if player.cursor_stack.valid_for_read then
        if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
          add_order(player)
        elseif player.cursor_stack.name ~= "blueprint" then
          add_to_trash(player, player.cursor_stack.name, 0)
        end
      else
        global.guiData[player_index] = gui_open_frame(player)
      end
    elseif element.name == GUI.expandButton then
      gui_toggle_settings(player)
    elseif element.name == "auto-trash-apply" or element.name == "auto-trash-logistics-apply" then
      gui_save_changes(player)
    elseif element.name == "auto-trash-clear-all" or element.name == "auto-trash-logistics-clear-all" then
      gui_clear_all(player)
    elseif element.name == "auto-trash-pause" then
      toggle_autotrash_pause(player)
    elseif element.name == "auto-trash-logistics-button" then
      global.guiData[player_index] = gui_open_logistics_frame(player)
    elseif element.name == "auto-trash-logistics-pause" then
      toggle_autotrash_pause_requests(player)
    elseif element.name  == "auto-trash-logistics-storage-store" then
      gui_store(player)
    elseif element.name == GUI.trash_in_main_network then
      global.settings[player_index].auto_trash_in_main_network = not global.settings[player_index].auto_trash_in_main_network
      update_settings(player)
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
          gui_display_message(player.gui.left[GUI.configFrame], false, "auto-trash-not-in-network")
        end
      end
      element.caption = global.mainNetwork[player.index] and {"auto-trash-unset-main-network"} or {"auto-trash-set-main-network"}
    elseif element.name == GUI.trash_above_requested then
      global.settings[player_index].auto_trash_above_requested = not global.settings[player_index].auto_trash_above_requested
      update_settings(player)
    elseif element.name == GUI.trash_unrequested then
      global.settings[player_index].auto_trash_unrequested = not global.settings[player_index].auto_trash_unrequested
      if global.settings[player_index].auto_trash_unrequested then
        global.settings[player_index].auto_trash_above_requested = true
      end
      update_settings(player)
    else
      event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
      local type, index, _ = string.match(element.name, "auto%-trash%-(%a+)%-(%d+)%-*(%d*)")
      if not type then
        type, index, _ = string.match(element.name, "auto%-trash%-logistics%-(%a+)%-(%d+)%-*(%d*)")
      end
      if type and index then
        if type == "item" then
          gui_set_item(player, type, tonumber(index))
        elseif type == "restore" then
          gui_restore(player, tonumber(index))
        elseif type == "remove" then
          gui_remove(player, tonumber(index))
        end
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end)

script.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == "character-logistic-trash-slots-1" then
    for _, player in pairs(event.research.force.players) do
      gui_init(player, "trash")
    end
    return
  end
  if event.research.name == "character-logistic-slots-1" then
    for _, player in pairs(event.research.force.players) do
      gui_init(player, "requests")
    end
    return
  end
  if event.research.name == "character-logistic-trash-slots-2" then
    global.configSize[event.research.force.name] = MAX_CONFIG_SIZES["character-logistic-trash-slots-2"]
  end
end)

script.on_event("autotrash_pause", function(event)
  toggle_autotrash_pause(game.players[event.player_index])
end)

script.on_event("autotrash_pause_requests", function(event)
  toggle_autotrash_pause_requests(game.players[event.player_index])
end)

script.on_event("autotrash_trash_cursor", function(event)
  local player = game.players[event.player_index]
  local cursorStack = player.cursor_stack
  if cursorStack.valid_for_read then
    add_to_trash(player, cursorStack.name, 0)
  else
    toggle_autotrash_pause(game.players[event.player_index])
  end
end)

function debugDump(var, force)
  if false or force then
    for _, player in pairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function saveVar(var, name)
  var = var or global
  local n = name or ""
  game.write_file("autotrash"..n..".lua", serpent.block(var, {name="glob", comment=false}))
end
--/c remote.call("at","saveVar")
remote.add_interface("at",
  {
    saveVar = function(name)
      saveVar(global, name)
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
      gui_init(game.player)
    end
  })
