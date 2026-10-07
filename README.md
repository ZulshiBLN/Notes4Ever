# Notes4Ever

An in-game notebook for **World of Warcraft: Forever**.

Create pages, organise them in folders, and keep notes on anything — dungeons,
professions, routes, to-do lists — without leaving the game.

> Status: in development. Nothing is released yet. The current build loads on
> WoW: Forever; folders and pages can be created, organised and written in.

## Commands

| Command | Does |
|---|---|
| `/n4e` or `/notes` | opens or closes the notebook window |
| `/n4e status` | prints the version and, for account and character notes, their count, schema, creation time, load count and how many unreadable sets are kept |

The AddOn compartment entry (the button beside the minimap) opens the window
too. Escape closes it; drag it to move it, and the corner grip to resize it.

## Organising notes

The window's left side lists **Account notes** and **Character notes**. Click
a folder to open or close it. Right-click a row for:

- **New folder** / **New page** — inside the clicked folder; you name it at once
- **Rename**
- **Move to** — any folder of either set; moving between account and
  character notes takes the whole subtree along
- **Delete** — asks first and says how many folders and pages go with it

Click a page to write in it on the right. Text is saved a moment after you
stop typing, and at once when you close the window, open another page,
change the tree, log out or `/reload`. Escape leaves the text field; a
second Escape closes the window.

## Where your notes live, and how to keep them

Notes4Ever keeps two sets of notes: **account notes**, shared by all your
characters, and **character notes**, which belong to one character. The game
stores them in its `WTF` folder:

```
WTF\Account\<account>\SavedVariables\Notes4Ever.lua                        account notes
WTF\Account\<account>\<realm>\<character>\SavedVariables\Notes4Ever.lua    character notes
```

Three things to know:

- **The game saves only on `/reload`, logout, disconnect and quit.** If the
  game crashes, everything since the last of those is lost. No addon can
  prevent that.
- **Each save moves the previous file to `Notes4Ever.lua.bak`** — and replaces
  the `.bak` that was there. The `.bak` is always the state before the last
  save, no older. If Notes4Ever warns at login that notes could not be read or
  went missing, copy both `Notes4Ever.lua` and `Notes4Ever.lua.bak` somewhere
  safe *before* any `/reload` or logout. To restore, close the game first and
  copy the file back; the game overwrites the folder when it exits.
- **Character notes stay with the character's folder.** After a rename, a
  realm transfer or a faction change, the game starts a new, empty folder; the
  old notes are still in the old folder, and Notes4Ever may warn that they are
  missing. Keep anything you cannot lose in your account notes.

## License

[MIT](LICENSE)
