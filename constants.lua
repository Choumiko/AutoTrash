local constants = {}

constants.max_request = 4294967295

constants.quick_actions = {
    [1] = {"autotrash_quick_actions"},
    [2] = {"autotrash_clear_requests"},
    [3] = {"autotrash_clear_trash"},
    [4] = {"autotrash_clear_both"},
    [5] = {"autotrash_trash_to_requests"},
    [6] = {"autotrash_requests_to_trash"}
}

constants.trash_blacklist = {
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-item"] = true,
    ["upgrade-item"] = true,
    ["copy-paste-tool"] = true,
    ["selection-tool"] = true,
}
return constants