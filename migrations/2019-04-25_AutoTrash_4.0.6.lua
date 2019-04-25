local mod_gui = require '__core__/lualib/mod-gui'
for _, player in pairs(game.players) do
    --for my borked dev saves
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow["auto-trash-config-button"] and button_flow["auto-trash-config-button"].valid then
        button_flow["auto-trash-config-button"].destroy()
    end
    local storage_frame = mod_gui.get_frame_flow(player)["auto-trash-logistics-storage-frame"]
    if storage_frame and storage_frame.valid then
        local config_frame = storage_frame.parent and storage_frame.parent["at-config-frame"]
        if config_frame and config_frame.valid then
            config_frame.destroy()
        end
        storage_frame.destroy()
    end
end