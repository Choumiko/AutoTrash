local gui = require("__flib__.gui-beta")
local presets = require("scripts.presets")
local at_util = require("scripts.util")
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
        set_requests(e.entity, e.pdata.presets[msg.name], e.pdata.flags.spider.keep_presets)
    end,
    toggle_keep = function(e, _)
        e.pdata.flags.spider.keep_presets = e.element.state
    end,
    collapse = function(e)
        local frame = e.pdata.gui.spider.preset_frame
        local new_state = not frame.visible
        frame.visible = new_state
        for k, v in pairs(collapse_sprites[new_state]) do
            e.element[k] = v
        end
        frame.parent.style.bottom_padding = new_state and 8 or 0
    end
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
    return ret
end

function spider_gui.init(player, pdata)
    local refs = gui.build(player.gui.relative, {
        {type = "frame", style = "inner_frame_in_outer_frame", direction = "vertical",-- style_mods = {width = 214},
            ref = {"main"},
            anchor = {gui = defines.relative_gui_type.spider_vehicle_gui, position = defines.relative_gui_position.right},
            children = {
                {type = "flow", children = {
                    {type = "label", style = "frame_title", caption = "Logistics", elem_mods = {ignored_by_interaction = true}},
                    {type = "empty-widget", style = "flib_titlebar_drag_handle", elem_mods = {ignored_by_interaction = true}},
                    at_util.frame_action_button{sprite="utility/collapse", hovered_sprite="utility/collapse_dark", clicked_sprite="utility/collapse_dark",
                        actions = {on_click = {gui = "spider", action = "collapse"}},
                        tooltip={"at-gui.keep-open"}},
                }},
                {type = "frame", style = "inside_shallow_frame", direction = "vertical", ref = {"preset_frame"}, children = {
                    {type = "frame", style = "subheader_frame", style_mods = {left_padding = 8}, children={
                        {type = "checkbox", caption = "Keep existing requests", state = pdata.flags.spider.keep_presets,
                            actions = {on_checked_state_changed = {gui = "spider", action = "toggle_keep"}}
                        },
                        {type = "empty-widget", style_mods = {horizontally_stretchable = true}}
                    }},
                    {type = "flow", direction="vertical", style = "at_right_container_flow", children = {
                        {type = "frame", style = "deep_frame_in_shallow_frame", children = {
                            {type = "scroll-pane", style = "at_right_scroll_pane", style_mods = {maximal_height = 500}, children = {
                                {type = "flow", direction = "vertical",
                                    ref = {"presets"},
                                    style_mods = {vertically_stretchable = false, padding = 8},
                                    children = spider_gui.presets(pdata)
                                },
                            }}
                        }},
                    }}
                }},
            }}
    })
    pdata.gui.spider = refs
end

function spider_gui.update(pdata)
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