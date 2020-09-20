local presets = {}

local function log_blueprint_entities(ents)--luacheck: ignore
    for i, ent in pairs(ents) do
        log(serpent.line({name = ent.name, entity_number = ent.entity_number, position = ent.position}))
        if ent.control_behavior then
            for j, item in pairs(ent.control_behavior.filters) do
                log("\t" .. serpent.line(item))
            end
        end
    end
end

--merge 2 presets,
--requests and trash are set to max(current, preset)
--if one preset has trash set to false it is set to a non false value
--slot from current are kept
function presets.merge(current, preset)
    local result = current.config
    local b = util.table.deepcopy(preset)
    local no_slot = {}
    local tmp
    local max_slot = current.max_slot
    local c_requests = current.c_requests

    for j, result_config in pairs(result) do
        tmp = result_config
        for i, config in pairs(b.config) do
            if config.name == result_config.name then
                tmp.request = (config.request > tmp.request) and config.request or tmp.request
                tmp.trash = (config.trash and tmp.trash and config.trash > tmp.trash) and config.trash or tmp.trash
                tmp.trash = (tmp.trash and tmp.trash < tmp.request) and tmp.request or tmp.trash
                b.config[i] = nil
                max_slot = max_slot > tmp.slot and max_slot or tmp.slot
                c_requests = tmp.request > 0 and c_requests + 1 or c_requests
                break
            end
        end
    end
    --preserve slot number if possible
    --TODO find out how b can be nil
    if not b then return end

    for i, config in pairs(b.config) do
        assert(i==config.slot)
        if not result[config.slot] then
            result[config.slot] = config
        else
            no_slot[#no_slot + 1] = config
        end
        max_slot = max_slot > config.slot and max_slot or config.slot
        c_requests = config.request > 0 and c_requests + 1 or c_requests
    end

    local start = 1
    for _, s in pairs(no_slot) do
        for i = start, max_slot + #no_slot do
            if not result[i] then
                s.slot = i
                result[i] = s
                start = i + 1
                max_slot = max_slot > i and max_slot or i
                break
            end
        end
    end
    current.max_slot = max_slot
    current.c_requests = c_requests
    return current, max_slot, c_requests
end

local ceil = math.ceil
--creates a blueprint with 2 rows of constant combinators
--first row for requests, second for trash (signal omitted when no trash value is set)
--preserves slot order, empty combinators are not included
-- for importing, slot can be recalculated by the x position: starting_slot = x * 18 + 1
-- y position of 0: request, y = 4: trash
function presets.export(preset)
    local item_slot_count = game.entity_prototypes["constant-combinator"].item_slot_count
    local combinators = ceil(preset.max_slot / item_slot_count)
    local half_cc = ceil(combinators / 2)
    local start
    local request_cc = {}
    local trash_cc = {}
    local bp = {}
    local item_config, request_items, trash_items, item_signal, pos_x
    local index_offset, index

    for cc = 1, combinators do
        pos_x = cc - 1
        index_offset = pos_x * item_slot_count
        start = index_offset + 1
        request_cc[cc] = {entity_number = cc, name = "constant-combinator", position = {x = pos_x, y = 0}, control_behavior = {filters = {}}}
        trash_cc[cc] = {entity_number = cc + half_cc, name = "constant-combinator", position = {x = pos_x, y = 4}, control_behavior = {filters = {}}}
        request_items = request_cc[cc].control_behavior.filters
        trash_items = trash_cc[cc].control_behavior.filters
        for i = start, start + item_slot_count - 1 do
            item_config = preset.config[i]
            if item_config then
                index = item_config.slot - index_offset
                item_signal = {name = item_config.name, type = "item"}
                request_items[#request_items+1] = {index = index, count = item_config.request, signal = item_signal}
                if item_config.trash then
                    trash_items[#trash_items+1] = {index = index, count = item_config.trash, signal = item_signal}
                end
            end
        end
        --maybe skip empty combinators (can mess with entity_number but does it matter?)
        bp[#bp+1] = request_cc[cc]
        bp[#bp+1] = trash_cc[cc]
    end
    --log_blueprint_entities(bp)
    return bp, {{index = 1, signal = {name = "signal-A", type = "virtual"}},{index = 2, signal = {name = "signal-T", type = "virtual"}},{index = 3, signal = {name = "signal-0", type = "virtual"}}}
end

--Storing the exported string in the blueprint library preserves it even when mod items have been removed
--Importing a string with invalid item signals removes the combinator containing the invalid signals.
function presets.import(preset, icons)
    local item_slot_count = game.entity_prototypes["constant-combinator"].item_slot_count
    local tmp = {config = {}, max_slot = 0, c_requests = 0}
    local config = tmp.config
    local index_offset, index
    local cc_found = false
    if icons then
        --log_blueprint_entities(preset)
        for _, cc in pairs(preset) do
            index_offset = (cc.position.x - 0.5) * item_slot_count
            if cc.name == "constant-combinator" and cc.control_behavior then
                cc_found = true
                for _, item_config in pairs(cc.control_behavior.filters) do
                    index = index_offset + item_config.index
                    if not config[index] then
                        config[index] = {name = item_config.signal.name, slot = index, trash = false, request = 0}
                    end
                    if (cc.position.y - 0.5) == 0 then
                        config[index].request = item_config.count
                    else
                        config[index].trash = item_config.count
                    end
                    tmp.max_slot = tmp.max_slot > index and tmp.max_slot or index
                    tmp.c_requests = config[index].request > 0 and (tmp.c_requests + 1) or tmp.c_requests
                end
            end
        end
    end
    return tmp, cc_found
end

return presets