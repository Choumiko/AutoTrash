local prefix = "autotrash_"
data:extend({
    {
        type = "int-setting",
        name = prefix .. "update_rate",
        setting_type = "runtime-global",
        default_value = 120,
        minimum_value = 1,
        order = "a"
    },
})

--per user
data:extend({
    {
        type = "bool-setting",
        name = prefix .. "trash_equals_requests",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "a"
    },
    {
        type = "bool-setting",
        name = prefix .. "overwrite",
        setting_type = "runtime-per-user",
        default_value = true,
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
        hidden = true,
        order = "e",
        localised_name = {"autotrash_open_library_name", {"gui-blueprint-library.title"}},
        localised_description = {"autotrash_open_library", {"gui-blueprint-library.title"}}
    },
    {
        type = "int-setting",
        name = prefix .. "gui_displayed_columns",
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 1,
        order = "v"
    },
    {
        type = "int-setting",
        name = prefix .. "gui_rows_before_scroll",
        setting_type = "runtime-per-user",
        default_value = 7,
        minimum_value = 1,
        order = "w"
    },
    {
        type = "int-setting",
        name = prefix .. "status_count",
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 1,
        order = "x"
    },
    {
        type = "int-setting",
        name = prefix .. "status_columns",
        setting_type = "runtime-per-user",
        default_value = 1,
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
