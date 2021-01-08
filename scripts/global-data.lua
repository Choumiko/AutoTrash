local constants = require("constants")
local global_data = {}

function global_data.init()
    global._pdata = {}
    global.unlocked_by_force = {}
    global.trash_all_items = {}
end

function global_data.refresh()
    local all_trash = {config = {}, by_name = {}, max_slot = 0, c_requests = 0}
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
        --{filter = "place-result", mode = "and"}
    }
    local i = 0
    local group, subgroup
    local max_request = constants.max_request
    for name, proto in pairs(game.get_filtered_item_prototypes(filters)) do
        if group and group ~= proto.group.name and i % 10 > 0 then
            i = i + 1
            i = math.ceil(i/10) * 10 + 11
        elseif subgroup and subgroup ~= proto.subgroup.name then
            i = i + 1
            i = math.ceil(i/10) * 10 + 1
        else
            i = i + 1
        end

        subgroup = proto.subgroup.name
        group = proto.group.name
        all.config[i] = {name = name, min = 0, max = max_request, slot = i}
        all.by_name[name] = all.config[i]
        all_trash.config[i] = {name = name, min = 0, max = 0, slot = i}
        all_trash.by_name[name] = all_trash.config[i]
    end
    all_trash.max_slot = i - 1
    global.trash_all_items = all_trash
    global.all_items = all
end

return global_data