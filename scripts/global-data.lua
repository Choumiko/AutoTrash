local global_data = {}

function global_data.init()
    global._pdata = {}
    global.unlocked_by_force = {}
    global.trash_all_items = {}
end

function global_data.refresh()
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
    global.trash_all_items = all
end

return global_data