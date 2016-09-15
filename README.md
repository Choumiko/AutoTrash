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

Todo:
---
- "Unlimited" number of slots
- Option to trash from (unfiltered) quickbar

***
Changelog
---
1.0.1/1.0.9

- fixed errors when using Hotkeys before Autotrash is unlocked

1.0.0

- version for Factorio 0.14.x

0.1.8

- added hotkey to add the item on the cursor to temporary trash. Toggles pausing autotrash when the cursor is empty
- added console command to hide/show the buttons: /c remote_call("at", "hide"), /c remote.call("at", "show")

0.1.7

- fixed logistic requests not working at all

0.1.6

- added tooltip to Pause buttons, showing the configured hotkey
- fixed migration error

0.1.5

- temporary trash gets removed from main inventory, quickbar and cursor 

0.1.4

- fixed error when restoring logistic requests

0.1.3

- update main network when a roboport gets mined/destroyed
- don't trash blueprints/books (clears the blueprint)

0.1.2

- added option to only trash items when the player is in a specific network (WIP)
- only trash items from the main inventory, cursor and quickbar are not touched
- added quicksettings to the top buttons, can be toggled by the "gear button"
 

0.1.1

- added option to trash all unrequested items from the main inventory
- GUI uses sprite buttons instead of checkboxes
- removed debug output

0.1.0

 - added hotkeys to toggle pause for Autotrash/Requests (Shift+P/Shift+O by default)
