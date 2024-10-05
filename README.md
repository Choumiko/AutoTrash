Configure different presets for your logistic request and auto-trash slots

![Config](https://mods-data.factorio.com/assets/ee3e3a9131dcaddd3c9ee49a3dced17af37a6de8.png)

Features:
---
- Configure request and trash settings in one window
- Save and load multiple presets
- Export/Import the configuration and presets (as a string or blueprint/book)
- Display the requests status:
    + Red: missing items
    + Yellow: items are on the way
    + Blue: some items are on the way, but not enough are available
- Pause requests when dying
- Load one or more preset after respawning
- Trash unrequested items
- Pause autotrash when not in certain networks
- Pause requests/auto-trash individually
- Shift click configured items in the gui to quickly reorder them (keep shift pressed when clicking the second time):
![ClickDrop](https://i.imgur.com/h8XcENe.gif)

Notes:
---
- This mod may change your vanilla Logistic and Auto Trash slots at any time (depending on your settings), so i suggest to configure them only in the mods gui if you don't want to loose your changes
- Export/Import: I suggest to keep the created strings as a blueprint in the blueprint library. If you have modded items configured and import the string in a save without these items you might even loose items that are still available. Importing from a blueprint from the library will only remove the missing items, keeping everything else intact.

Hotkeys:
---
- Shift + P: Pauses Autotrash
- Shift + O: Pause logistic requests
- Shift + T: Add item on cursor to temporary trash. Pause/Unpause Autotrash if cursor is empty
- Control + L: Toggle AutoTrash gui
- Unbound: Toggle trashing of unrequested items

Commands:
---
- /at_import - Import the vanilla request and trash settings into the mod gui:
- /at_reset - Reset gui
- /at_compress - Removes empty rows in the logistics configuratuon gui
- /at_insert_row <number> - Add an empty row after row #<number>, e.g. /at_insert_row 2 - Inserts an empty row after row #2

Todo:
---
- Temporary requests
- Order blueprint items

[More info](https://forums.factorio.com/viewtopic.php?f=97&t=16016)