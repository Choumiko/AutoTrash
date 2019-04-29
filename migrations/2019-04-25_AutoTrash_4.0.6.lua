local mod_gui = require '__core__/lualib/mod-gui'
for _, player in pairs(game.players) do
    --for my borked dev saves
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow["auto-trash-config-button"] and button_flow["auto-trash-config-button"].valid then
        button_flow["auto-trash-config-button"].destroy()
    end
    local frame = mod_gui.get_frame_flow(player)["auto-trash-logistics-storage-frame"]
    if frame and frame.valid then
        frame.destroy()
    end
    frame = mod_gui.get_frame_flow(player)["auto-trash-config-frame"]
    if frame and frame.valid then
        frame.destroy()
    end
    frame = mod_gui.get_frame_flow(player)["auto-trash-logistics-config-frame"]
    if frame and frame.valid then
        frame.destroy()
    end
end