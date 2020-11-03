data:extend({
    {
        type = "int-setting",
        name = "autotrash_update_rate",
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
        name = "autotrash_trash_equals_requests",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "a"
    },
    {
        type = "bool-setting",
        name = "autotrash_overwrite",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "b"
    },
    {
        type = "bool-setting",
        name = "autotrash_reset_on_close",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "c"
    },
    {
        type = "bool-setting",
        name = "autotrash_close_on_apply",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "d"
    },
    {
        type = "bool-setting",
        name = "autotrash_open_library",
        setting_type = "runtime-per-user",
        default_value = false,
        hidden = false,
        order = "e",
    },
    {
        type = "int-setting",
        name = "autotrash_gui_displayed_columns",
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 5,
        maximum_value = 40,
        allowed_values = {5, 10, 15, 20, 25, 30, 35, 40},
        order = "v"
    },
    {
        type = "int-setting",
        name = "autotrash_gui_rows_before_scroll",
        setting_type = "runtime-per-user",
        default_value = 6,
        minimum_value = 1,
        order = "w"
    },
    {
        type = "int-setting",
        name = "autotrash_status_count",
        setting_type = "runtime-per-user",
        default_value = 10,
        minimum_value = 1,
        order = "x"
    },
    {
        type = "int-setting",
        name = "autotrash_status_columns",
        setting_type = "runtime-per-user",
        default_value = 1,
        minimum_value = 1,
        order = "y"
    },
    {
        type = "bool-setting",
        name = "autotrash_display_messages",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "z"
    },
})
