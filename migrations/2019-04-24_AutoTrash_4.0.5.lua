for _, player in pairs(game.players) do
    local left = player.gui.left
    local top = player.gui.top
    local frame = left["auto-trash-config-frame"]
    local frame2 = left["auto-trash-logistics-config-frame"]
    local storage_frame = left["auto-trash-logistics-storage-frame"]
    if frame2 and frame2.valid then
        frame2.destroy()
    end
    if storage_frame and storage_frame.valid then
        storage_frame.destroy()
    end
    if frame and frame.valid then
        frame.destroy()
    end

    if top["auto-trash-config-button"] and top["auto-trash-config-button"].valid then
        top["auto-trash-config-button"].destroy()
    end
    if top["auto-trash-logistics-button"] and top["auto-trash-logistics-button"].valid then
        top["auto-trash-logistics-button"].destroy()
    end
    if top["auto-trash-main-flow"] and top["auto-trash-main-flow"].valid then
        top["auto-trash-main-flow"].clear()
        top["auto-trash-main-flow"].style = "at_main_flow"
    end
end