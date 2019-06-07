local prefix = "autotrash_"
data:extend({
    {
        type = "bool-setting",
        name = prefix .. "pause_on_death",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "a"
    },
    {
        type = "bool-setting",
        name = prefix .. "overwrite",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "b"
    },
    {
        type = "bool-setting",
        name = prefix .. "reset_on_close",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "c"
    },
    {
        type = "bool-setting",
        name = prefix .. "close_on_apply",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "d"
    },
    {
        type = "bool-setting",
        name = prefix .. "open_library",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "e",
        localised_name = {"autotrash_open_library_name", {"gui-blueprint-library.title"}},
        localised_description = {"autotrash_open_library", {"gui-blueprint-library.title"}}
    },
    -- {
    --     type = "string-setting",
    --     name = prefix .. "default_trash_amount",
    --     setting_type = "runtime-per-user",
    --     order = "f"
    -- },
    {
        type = "int-setting",
        name = prefix .. "threshold",
        setting_type = "runtime-per-user",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 4294967295,--2^32-1
        order = "g",
        localised_description = {"autotrash_threshold", {"auto-trash-above-requested"}}
    },
    {
        type = "int-setting",
        name = prefix .. "gui_columns",
        setting_type = "runtime-per-user",
        default_value = 6,
        minimum_value = 1,
        order = "x"
    },
    {
        type = "int-setting",
        name = prefix .. "gui_max_rows",
        setting_type = "runtime-per-user",
        default_value = 6,
        minimum_value = 1,
        order = "y"
    },
    {
        type = "bool-setting",
        name = prefix .. "display_messages",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "z"
    },
})
