local constants = {}

constants.max_request = 4294967295

constants.quick_actions = {
    [1] = {"at-gui.quick-actions"},
    [2] = {"at-gui.clear-requests"},
    [3] = {"at-gui.clear-trash"},
    [4] = {"at-gui.clear-both"},
    [5] = {"at-gui.trash-to-requests"},
    [6] = {"at-gui.requests-to-trash"}
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