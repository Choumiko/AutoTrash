![Top GUI](http://i.imgur.com/lg3Zpgk.png)
Configure AutoTrash for the items you want to be moved to the trash slots automatically

AutoTrash:
---
Clicking the trash icon with an item in your hand, adds that item to the temporary trash, once that item is completely removed, it also gets removed from AutoTrash.
Clicking it without an icon opens the gui. Click the grey squares with an item in your hand to add it to the list. In the textfield you can set how many items should stay in your inventory (defaults to 0 if nothing is set)
If an item is also set in your logistic requests, that amount is also protected from being "trashed" (no need to use the textfield then).
Number of slots is tied to the trash research. Level 1 unlocks it with 10 slots, Level 2 changes it to 30 slots.

Logistics:
---
Mostly the same as AutoTrash, but changing your request slots when clicking Save.
You can save/load different setups for easier switching.
The number of slots is equal to your logistics slots research.

Items get trashed every 2 seconds for now. Hitting Pause will, wait for it.., pause AutoTrash :D

Hotkeys:
---
- Shift + P: Pauses Autotrash
- Shift + O: Pause logistic requests
- Shift + T: Add item on cursor to temporary trash. Pause/Unpause Autotrash if cursor is empty

Console commands:
---
- Show/Hide buttons: /c remote_call("at", "hide"), /c remote.call("at", "show")

[More info](https://forums.factorio.com/viewtopic.php?f=97&t=16016)