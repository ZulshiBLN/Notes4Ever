# Notes4Ever

An in-game notebook for **World of Warcraft: Forever**.

Create pages, organise them in folders, and keep notes on anything — dungeons,
professions, routes, to-do lists — without leaving the game.

> Status: in development. Nothing is released yet. The current build loads on
> WoW: Forever and reports its status; notes cannot be written yet.

## Commands

| Command | Does |
|---|---|
| `/n4e status` or `/notes` | prints the version and, for account and character notes, schema, creation time, load count and how many unreadable sets are kept |

The AddOn compartment entry (the button beside the minimap) does the same.

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
