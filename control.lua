require "defines"
require "util"

MAX_CONFIG_SIZE = 10
MAX_STORAGE_SIZE = 12

require "gui"

local function initGlob()

  if not global.version then
    global.config = {}
    global["config-tmp"] = {}
    global["storage"] = {}
    global.version = "0.0.1"
    global.guiVersion = {}
    global.configSize = {}
  end

  global["config"] = global["config"] or {}
  global["config-tmp"] = global["config-tmp"] or {}
  global["storage"] = global["storage"] or {}
  global.guiVersion = global.guiVersion or {}
  global.active = global.active or {}
  global.configSize = global.configSize or {}

  if global.version < "0.0.2" then
    for p, _ in pairs(global.config) do
      if global.active[p] == nil then
        global.active[p] = true
      end
    end
    global.version = "0.0.2"
  end

  if global.version < "0.0.3" then
    for _, force in pairs(game.forces) do
      local size = force.technologies["character-logistic-trash-slots-2"].researched and 30 or 10
      global.configSize[force.name] = size
    end
    global.version = "0.0.3"
  end

  global.version = "0.0.3"
end

local function oninit()
  initGlob()
  game.on_event(defines.events.on_tick, function() update_gui() end)
end

local function onload()
  initGlob()
  game.on_event(defines.events.on_tick, function() update_gui() end)
end

function update_gui(player)
  local status, err = pcall(function()
    if player then
      gui_init(player)
    else
      for _, p in pairs(game.players) do
        gui_init(p)
      end
    end
    game.on_event(defines.events.on_tick, on_tick)
  end)
  if not status then
    debugDump(err, true)
  end
end

function on_tick(event)
  if event.tick % 120 == 0 then
    local status, err = pcall(function()
      for pi, player in pairs(game.players) do
        if not player.valid or not player.connected or not global.config[player.name] or not global.active[player.name] then
          break
        end
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

        for i, item in pairs(global.config[player.name]) do
          if item.name == "" then
            break
          end
          local stack = {name=item.name, count=1}
          local count = player.get_item_count(item.name)
          local desired = requests[item.name] and requests[item.name] + item.count or item.count
          local diff = count - desired
          if diff > 0 then
            --player.print(item.name.. ": " .. diff)
            local trash = player.get_inventory(defines.inventory.player_trash)
            for j=1,diff do
              if trash.can_insert(stack) then
                player.remove_item(stack)
                trash.insert(stack)
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

game.on_init(oninit)
game.on_load(onload)

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
  global["config"][player.name] = global["config"][player.name] or {}
  if global.active[player.name] == nil then global.active[player.name] = true end

  for i = 1, global.configSize[player.force.name] do
    if i > #global["config"][player.name] then
      global["config"][player.name][i] = { name = "", count = 0 }
    end
    if global["config"][player.name][i].name == "" then
      global["config"][player.name][i] = {name = item, count  = count}
      player.print({"", "added ", game.get_localised_item_name(item), " to auto trash"})
      return
    end
  end
  player.print({"", "Couldn't add ", game.get_localised_item_name(item), " to auto trash."})
end

game.on_event(defines.events.on_gui_click, function(event)
  local status, err = pcall(function()
    local element = event.element
    --debugDump(element.name, true)
    local player = game.get_player(event.player_index)
    if not global.guiVersion[player.name] then global.guiVersion[player.name] = "0.0.0" end

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
    elseif element.name == "auto-trash-apply" then
      gui_save_changes(player)
    elseif element.name == "auto-trash-clear-all" then
      gui_clear_all(player)
    elseif element.name == "auto-trash-pause" then
      global.active[player.name] = not global.active[player.name]
      local mainButton = player.gui.top[GUI.mainButton]
      if global.active[player.name] then
        mainButton.style = "auto-trash-button"
        element.caption = {"auto-trash-config-button-pause"}
      else
        mainButton.style = "auto-trash-button-paused"
        element.caption = {"auto-trash-config-button-unpause"}
      end
    else
      event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
      local type, index, slot = string.match(element.name, "auto%-trash%-(%a+)%-(%d+)%-*(%d*)")
      --debugDump({t=type,i=index,s=slot},true)
      if type and index then
        if type == "item" then
          gui_set_item(player, type, tonumber(index))
        end
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end)

game.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == "character-logistic-trash-slots-1" then
    for _, player in pairs(event.research.force.players) do
      gui_init(player, true)
    end
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
  game.makefile("autotrash"..n..".lua", serpent.block(var, {name="glob"}))
end

remote.add_interface("at",
  {
    saveVar = function(name)
      saveVar(global, name)
    end
  })
