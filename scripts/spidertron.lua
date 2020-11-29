local gui = require("__flib__.gui-beta")
local presets = require("scripts.presets")
local at_util = require("scripts.util")
local gui_util = require("scripts.gui-util")
local player_data = require("scripts.player-data")
local spider_gui = {}

local function set_requests(spider, requests, keep_presets)
    local set_request = spider.set_vehicle_logistic_slot
    local clear = spider.clear_vehicle_logistic_slot
    local config = requests.config
    local request_slot_count = spider.request_slot_count
    if keep_presets then
        local result = at_util.get_requests(spider.get_vehicle_logistic_slot, request_slot_count)
        local tmp = presets.merge(result, requests)
        for _, data in pairs(tmp.by_name) do
            set_request(data.slot, data)
        end
    else
        for i = 1, requests.max_slot do
            if config[i] then
                set_request(i, config[i])
            else
                clear(i)
            end
        end
        if request_slot_count > requests.max_slot then
            for i = requests.max_slot + 1, request_slot_count do
                clear(i)
            end
        end
    end
end

local collapse_sprites = {
    [true] = {
        sprite="utility/collapse",
        hovered_sprite="utility/collapse_dark",
        clicked_sprite="utility/collapse_dark"
    },
    [false] = {
        sprite="utility/expand",
        hovered_sprite="utility/expand_dark",
        clicked_sprite="utility/expand_dark"
    }
}

spider_gui.handlers = {
    load = function(e, msg)
        set_requests(e.entity, e.pdata.presets[msg.name], e.shift)
    end,
    collapse = function(e)
        local frame = e.pdata.gui.spider.preset_frame
        local new_state = not frame.visible
        frame.visible = new_state
        for k, v in pairs(collapse_sprites[new_state]) do
            e.element[k] = v
        end
        frame.parent.style.bottom_padding = new_state and 8 or 0
    end,
    save = function(e)
        local textfield = e.pdata.gui.spider.preset_textfield
        local config = at_util.get_requests(e.entity.get_vehicle_logistic_slot, e.entity.request_slot_count)
        if player_data.add_preset(e.player, e.pdata, textfield.text, config) then
            spider_gui.update(e.player, e.pdata)
            textfield.text = ""
        end
    end,
    textfield = function(e)
        e.element.select_all()
    end,
    trash_all = function(e)
        local all = {config = {}, by_name = {}, max_slot = 0, c_requests = 0}
        local filters = {
            {filter = "selection-tool", invert = true, mode = "and"},
            {filter = "type", type = "blueprint", invert = true, mode = "and"},
            {filter = "type", type = "blueprint-book", invert = true, mode = "and"},
            {filter = "type", type = "deconstruction-item", invert = true, mode = "and"},
            {filter = "type", type = "upgrade-item", invert = true, mode = "and"},
            {filter = "type", type = "copy-paste-tool", invert = true, mode = "and"},
            {filter = "type", type = "selection-tool", invert = true, mode = "and"},
            {filter = "flag", flag = "hidden", invert = true, mode = "and"},
        }
        local i = 1
        for name in pairs(game.get_filtered_item_prototypes(filters)) do
            all.config[i] = {name = name, min = 0, max = 0, slot = i}
            all.by_name[name] = all.config[i]
            i = i + 1
        end
        all.max_slot = i - 1
        set_requests(e.entity, all, true)
    end,
}

function spider_gui.presets(pdata)
    local ret = {}
    local i = 1
    for name in pairs(pdata.presets) do
        ret[i] = {
            type = "button", style = "at_preset_button", caption = name,
            actions = {on_click = {gui = "spider", action = "load", name = name}}
        }
        i = i + 1
    end
    ret[#ret+1] = {
        type = "button", style = "at_preset_button", caption = "Trash everything",
        actions = {on_click = {gui = "spider", action = "trash_all"}}
    }
    return ret
end

function spider_gui.init(player, pdata)
    spider_gui.destroy(pdata)
    local refs = gui.build(player.gui.relative, {
        {type = "frame", style = "inner_frame_in_outer_frame", direction = "vertical",-- style_mods = {width = 214},
            ref = {"main"},
            anchor = {gui = defines.relative_gui_type.spider_vehicle_gui, position = defines.relative_gui_position.right},--luacheck: ignore
            children = {
                {type = "flow", children = {
                    {type = "label", style = "frame_title", caption = "Logistics", elem_mods = {ignored_by_interaction = true}},
                    {type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = {ignored_by_interaction = true}},
                    gui_util.frame_action_button{sprite="utility/collapse", hovered_sprite="utility/collapse_dark", clicked_sprite="utility/collapse_dark",
                        actions = {on_click = {gui = "spider", action = "collapse"}},
                        tooltip={"at-gui.keep-open"}},
                }},
                {type = "frame", style = "inside_shallow_frame", direction = "vertical", ref = {"preset_frame"}, children = {
                    {type = "frame", style = "subheader_frame", style_mods = {left_padding = 8}, children={
                        {type = "textfield", style = "long_number_textfield", ref = {"preset_textfield"},
                            actions = {on_click = {gui = "spider", action = "textfield"}},
                        },
                        gui_util.pushers.horizontal,
                        {type = "sprite-button", sprite = "utility/check_mark",style = "item_and_count_select_confirm",
                            tooltip = {"at-gui.spider-save"},
                            actions = {on_click = {gui = "spider", action = "save"}}
                        }
                    }},
                    {type = "flow", direction="vertical", style = "at_right_container_flow", children = {
                        {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                            {type = "scroll-pane", style = "at_right_scroll_pane", style_mods = {maximal_height = 500}, children = {
                                {type = "flow", direction = "vertical",
                                    ref = {"presets"},
                                    style_mods = {vertically_stretchable = false, padding = 8, horizontally_stretchable = true},
                                    children = spider_gui.presets(pdata)
                                },
                            }}
                        }},
                    }}
                }},
            }
        }
    })
    pdata.gui.spider = refs
end

function spider_gui.update(player, pdata)
    if not (player.opened_gui_type == defines.gui_type.entity and player.opened and player.opened.type == "spider-vehicle") then
        return
    end
    local gui_spider = pdata.gui.spider and pdata.gui.spider.presets
    if not (gui_spider and gui_spider.valid) then
        spider_gui.init(player, pdata)
    end
    pdata.gui.spider.presets.clear()
    gui.build(pdata.gui.spider.presets, spider_gui.presets(pdata))
end

function spider_gui.destroy(pdata)
    if not (pdata.gui.spider and pdata.gui.spider.main and pdata.gui.spider.main.valid) then
        return
    end
    pdata.gui.spider.main.destroy()
    pdata.gui.spider = nil
end

return spider_gui