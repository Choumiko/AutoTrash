local constants = {}

constants.slot_columns = 10
constants.slot_rows = 6
constants.slot_table_width = constants.slot_columns * 40
constants.slot_table_height = constants.slot_rows * 40

constants.quick_actions = {
    [1] = {"autotrash_quick_actions"},
    [2] = {"autotrash_clear_requests"},
    [3] = {"autotrash_clear_trash"},
    [4] = {"autotrash_clear_both"},
    [5] = {"autotrash_trash_to_requests"},
    [6] = {"autotrash_requests_to_trash"}
}
return constants