local gui_util = {}

gui_util.frame_action_button = function(params)
    local ret = {type = "sprite-button", style = "frame_action_button", mouse_button_filter={"left"}}
    for k, v in pairs(params) do
        ret[k] = v
    end
    return ret
end

gui_util.preset = function(preset_name, pdata)
    local style = pdata.selected_presets[preset_name] and "at_preset_button_selected" or "at_preset_button"
    local rip_style = pdata.death_presets[preset_name] and "at_preset_button_small_selected" or "at_preset_button_small"
    return {type = "flow", direction = "horizontal", name = preset_name, children = {
        {type = "button", style = style, caption = preset_name, name = preset_name,
            actions = {on_click = {gui = "presets", action = "load"}},
        },
        {type = "sprite-button", style = rip_style, sprite = "autotrash_rip",
            tooltip = {"at-gui.tooltip-rip"},
            actions = {on_click = {gui = "presets", action = "change_death_preset"}},
        },
        {type = "sprite-button", style = "at_delete_preset", sprite = "utility/trash",
            actions = {on_click = {gui = "presets", action = "delete"}},
        }
    }}
end

gui_util.presets = function(pdata)
    local ret = {}
    local i = 1
    for name in pairs(pdata.presets) do
        ret[i] = gui_util.preset(name, pdata)
        i = i + 1
    end
    return ret
end

return gui_util