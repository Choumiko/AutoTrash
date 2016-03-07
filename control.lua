require "defines"
require "util"

MAX_CONFIG_SIZE = 10
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
  global["logistics-active"] = global["logistics-active"] or {}
  global.configSize = global.configSize or {}
  global.temporaryTrash = global.temporaryTrash or {}
  global.temporaryRequests = global.temporaryRequests or {}
  global.settings = global.settings or {}
end

local function init_player(player)
  global.config[player.name] = global.config[player.name] or {}
  global["logistics-config"][player.name] = global["logistics-config"][player.name] or {}
  global["config-tmp"][player.name] = global["config-tmp"][player.name] or {}
  global["logistics-config-tmp"][player.name] = global["logistics-config-tmp"][player.name] or {}
  global["logistics-active"][player.name] = true
  global.active[player.name] = true
  global.storage[player.name] = global.storage[player.name] or {}
  global.temporaryRequests[player.name] = global.temporaryRequests[player.name] or {}
  global.temporaryTrash[player.name] = global.temporaryTrash[player.name] or {}
  global.settings[player.name] = global.settings[player.name] or {}
  gui_init(player)
end

local function init_players(resetGui)
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
    global.configSize[force.name] = force.technologies["character-logistic-trash-slots-2"].researched and 30 or MAX_CONFIG_SIZE
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
    local oldVersion = data.mod_changes.AutoTrash.old_version
    if oldVersion then
      if oldVersion < "0.0.4" then
        global = {}
      end
      if oldVersion < "0.0.51" then
        init_global()
        init_forces()
        init_players(true)
        global.version = nil
      elseif oldVersion < "0.0.53" then
        init_global()
        init_forces()
        init_players()
      end
    -- mod was added to existing save
    else
      init_global()
      init_forces()
      init_players()
    end
  end
  --debugDump(data,true)
  --handle removed items
  local items = game.item_prototypes
  for name, p in pairs(global.config) do
    local delete = {}
    for i=#p,1,-1 do
      if not items[p[i].name] then
        table.remove(global.config[name], i)
      end
    end
  end
  for name, p in pairs(global["config-tmp"]) do
    local delete = {}
    for i=#p,1,-1 do
      if not items[p[i].name] then
        table.remove(global["config-tmp"][name], i)
      end
    end
  end
end

-- run once
local function on_player_created(event)
  --debugDump(event,true)
  init_player(game.players[event.player_index])
end

local function on_force_created(event)
  --debugDump(event,true)
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
  if not global["logistics-config"][player.name] then
    global["logistics-config"][player.name] = {}
  end
  local storage = global["logistics-config"][player.name]
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

function on_tick(event)
  if event.tick % 120 == 0 then
    local status, err = pcall(function()
      for pi, player in pairs(game.players) do
        if not player.valid or not player.connected or not global.config[player.name] or not global.active[player.name] then
          break
        end
        if not global.temporaryTrash[player.name] then global.temporaryTrash[player.name] = {} end
        local requests = requested_items(player)
        for i=#global.temporaryTrash[player.name],1,-1 do
          local item = global.temporaryTrash[player.name][i]
          if item and item.name ~= "" then
            local count = player.get_item_count(item.name)
            local requested = requests[item.name] and requests[item.name] or 0
            local desired = math.max(requested, item.count)
            local diff = count - desired
            local stack = {name=item.name, count=diff}
            if diff > 0 then
              local trash = player.get_inventory(defines.inventory.player_trash)
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
              global.temporaryTrash[player.name][i] = nil
            end
          end
        end
        for i, item in pairs(global.config[player.name]) do
          if item and item.name ~= "" then
            local count = player.get_item_count(item.name)
            local requested = requests[item.name] and requests[item.name] or 0
            local desired = math.max(requested, item.count)
            local diff = count - desired
            local stack = {name=item.name, count=diff}
            if diff > 0 then
              local trash = player.get_inventory(defines.inventory.player_trash)
              local c = trash.insert(stack)
              if c > 0 then
                local removed = player.remove_item{name=item.name, count=c}
                if c > removed then
                  trash.remove{name=item.name, count = c - removed}
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
  global.temporaryTrash[player.name] = global.temporaryTrash[player.name] or {}
  if global.active[player.name] == nil then global.active[player.name] = true end
  for i=#global.temporaryTrash[player.name],1,-1 do
    local item = global.temporaryTrash[player.name][i]
    if item and item.name == "" then
      break
    end
    local requests = requested_items(player)
    local count = player.get_item_count(item.name)
    local desired = requests[item.name] and requests[item.name] + item.count or item.count
    local diff = count - desired
    if diff < 1 then
      player.print({"", "removed ", game.item_prototypes[item.name].localised_name, " from temporary trash"})
      global.temporaryTrash[player.name][i] = nil
    end
  end

  if #global.temporaryTrash[player.name] >= 5 then
    player.print({"", "Couldn't add ", game.item_prototypes[item].localised_name, " to temporary trash."})
    return
  end
  table.insert(global.temporaryTrash[player.name], {name = item, count = count})
  player.print({"", "added ", game.item_prototypes[item].localised_name, " to temporary trash"})
end

function add_to_requests(player, item, count)
  global.temporaryRequests[player.name] = global.temporaryRequests[player.name] or {}
  if global["logistics-active"][player.name] == nil then global["logistics-active"][player.name] = true end
  local index = false

  for i=#global.temporaryRequests[player.name],1,-1 do
    local req = global.temporaryRequests[player.name][i]
    if req and req.name == "" then
      break
    end
    if req.name == item then
      index = i
    end
  end

  if #global.temporaryRequests[player.name] > player.force.character_logistic_slot_count then
    player.print({"", "Couldn't add ", game.item_prototypes[item].localised_name, " to temporary requests."})
    return
  end

  if not index then
    table.insert(global.temporaryTrash[player.name], {name = item, count = count})
  else
    global.temporaryTrash[player.name][index].count = global.temporaryTrash[player.name][index].count + count
  end

  table.insert(global.temporaryRequests[player.name], {name = item, count = count})
  player.print({"", "added ", game.item_prototypes[item].localised_name, " to temporary requests"})
end

function pause_requests(player)
  if not global.storage[player.name] then
    global.storage[player.name] = {requests={}}
  end
  global.storage[player.name].requests = global.storage[player.name].requests or {}

  local storage = global.storage[player.name].requests
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
  if not global.storage[player.name] then
    global.storage[player.name] = {}
  end
  local storage = global.storage[player.name].requests or {}
  local slots = player.force.character_logistic_slot_count
  if player.character and slots > 0 then
    for c=1, slots do
      if storage[c] then
        player.character.set_request_slot(storage[c], c)
      end
    end
    global.storage[player.name].requests = {}
  end
end

script.on_event(defines.events.on_gui_click, function(event)
  local status, err = pcall(function()
    local element = event.element
    --debugDump(element.name, true)
    local player = game.get_player(event.player_index)
    if element.name == "auto-trash-config-button" then
      if player.cursor_stack.valid_for_read then
        if player.cursor_stack.name == "blueprint" and player.cursor_stack.is_blueprint_setup() then
          add_order(player)
        elseif player.cursor_stack.name ~= "blueprint" then
          add_to_trash(player, player.cursor_stack.name, 0)
        end
      else
        gui_open_frame(player)
      end
    elseif element.name == "auto-trash-apply" or element.name == "auto-trash-logistics-apply" then
      gui_save_changes(player)
    elseif element.name == "auto-trash-clear-all" or element.name == "auto-trash-logistics-clear-all" then
      gui_clear_all(player)
    elseif element.name == "auto-trash-pause" then
      global.active[player.name] = not global.active[player.name]
      local mainButton = player.gui.top[GUI.mainFlow][GUI.mainButton]
      if global.active[player.name] then
        mainButton.style = "auto-trash-button"
        element.caption = {"auto-trash-config-button-pause"}
      else
        mainButton.style = "auto-trash-button-paused"
        element.caption = {"auto-trash-config-button-unpause"}
      end
    elseif element.name == "auto-trash-logistics-button" then
      gui_open_logistics_frame(player)
    elseif element.name == "auto-trash-logistics-pause" then
      global["logistics-active"][player.name] = not global["logistics-active"][player.name]
      local mainButton = player.gui.top[GUI.mainFlow][GUI.logisticsButton]
      if global["logistics-active"][player.name] then
        mainButton.style = "auto-trash-logistics-button"
        element.caption = {"auto-trash-config-button-pause"}
        unpause_requests(player)
      else
        mainButton.style = "auto-trash-logistics-button-paused"
        element.caption = {"auto-trash-config-button-unpause"}
        pause_requests(player)
      end
    elseif element.name  == "auto-trash-logistics-storage-store" then
      gui_store(player)
    else
      event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
      local type, index, slot = string.match(element.name, "auto%-trash%-(%a+)%-(%d+)%-*(%d*)")
      if not type then
        type, index, slot = string.match(element.name, "auto%-trash%-logistics%-(%a+)%-(%d+)%-*(%d*)")
      end
      --debugDump({t=type,i=index,s=slot},true)
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
    global.configSize[event.research.force.name] = 30
  end
end)

function debugDump(var, force)
  if false or force then
    for i,player in ipairs(game.players) do
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
  local var = var or global
  local n = name or ""
  game.write_file("autotrash"..n..".lua", serpent.block(var, {name="glob", comment=false}))
end

remote.add_interface("at",
  {
    saveVar = function(name)
      saveVar(global, name)
    end,
    init = function()
      init_global()
      init_forces()
      init_players()
    end
  })
