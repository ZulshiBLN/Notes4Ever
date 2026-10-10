# Notes4Ever

An in-game notebook for **World of Warcraft: Forever**.

Create pages, organise them in folders, and keep notes on anything — dungeons,
professions, routes, to-do lists — without leaving the game.

> Status: in development. Nothing is released yet. The current build loads on
> WoW: Forever; folders and pages can be created, organised, written in,
> searched, exported and imported.

## Commands

| Command | Does |
|---|---|
| `/n4e` or `/notes` | opens or closes the notebook window |
| `/n4e status` | prints the version, the window's design and, for account and character notes, their count, schema, creation time, load count and how many unreadable sets are kept |

The AddOn compartment entry (the button beside the minimap) opens the window
too. Escape closes it; drag it to move it, and the corner grip to resize it.

## Organising notes

The window's left side lists **Account notes** and **Character notes**. Click
a folder to open or close it. Right-click a row for:

- **New folder** / **New page** — inside the clicked folder; you name it first, and Cancel creates nothing
- **Rename**
- **Move to** — any folder of either set; moving between account and
  character notes takes the whole subtree along
- **Delete** — asks first and says how many folders and pages go with it
- **Export** — on any row; see below
- **Import here** — on a folder; see below

Click a page to write in it on the right. Text is saved a moment after you
stop typing, and at once when you close the window, open another page,
change the tree, log out or `/reload`. Escape leaves the text field; a
second Escape closes the window.

## Formatting

The toolbar above the page acts where the cursor is:

- **Heading** makes the cursor's line a gold heading, and back.
- **Colour** colours the word at the cursor. Between words, it colours what
  you type next. **Default** takes the colour away.
- **Bullet** puts a bullet before the cursor's line, and takes it away.
- **Checkbox** puts a box before the cursor's line; on a box, it ticks or
  unticks it.
- **Icon** inserts a raid marker, quest sign, coin or role icon.

The game's text field steps over an icon as if it were not there: a click
right of an icon lands a little too far right, and the arrow keys never
stop directly behind one. So Icon inserts the icon with a space after it
and leaves the cursor there - keep typing. Later, a click or the arrow keys
reach the place after that space.

## Searching

Type into the box above the tree. It then shows only the pages whose title
or text contains what you typed, and the folders whose title does - a
folder with everything in it. Upper and lower case do not matter for A–Z;
umlauts must match as typed. While you search, clicking a folder does not
open or close it, and the page you have open stays open. Clear the box to
see the whole tree again, as it was.

## Export and import

**Export** writes a page, a folder with everything in it, or a whole set of
notes as plain text. The dialog shows it selected: press **Ctrl+C**, then
paste it wherever you keep it - a text file is a backup the game's own files
cannot give you, and the text can be shared.

**Import here** reads such text into the folder you clicked: paste it with
**Ctrl+V** and click Accept. What you import is added next to what is there;
nothing is overwritten. If the text is not a valid export, the dialog says
why and adds nothing.

The text is meant to be readable:

```
Notes4Ever export 2
# Dungeons/
## Blackrock Depths/
### Route
{icon:heading} {gold}Route{/}
First left, then {red}beware the golem{/} {icon:skull}
# Shopping
• 20 linen
```

Each `#` is a level; a title ending in `/` is a folder; the lines under a
page's title are its text. Formatting is written in braces: a colour by its
name - `{red}`, `{orange}`, `{gold}`, `{green}`, `{blue}`, `{purple}`,
`{grey}` - or as `{#rrggbb}`, its end as `{/}`, an icon as `{icon:skull}`.
A literal `{` is written `\{`, a literal `\` as `\\`; anything else in
braces is refused with the reason. Exports from earlier builds (`Notes4Ever
export 1`) still import. Pasting a very large export takes the game a few
seconds - about ten for 100,000 characters - so for large collections,
export single folders.

## Design

The window has the Blizzard look: gold frame, parchment. With EllesmereUI
installed, it takes on EllesmereUI's flat, dark look instead: its backdrop and
border, close button, scroll bar, font and accent colour for the selected row.
Notes4Ever has no setting for this; EllesmereUI decides, and its look applies
only while all three of these are on:

1. EllesmereUI's **Blizzard Skins+** module
2. its switch for third-party addons
3. Notes4Ever's own toggle, under *Blizzard Skins+ > Window Skins >
   Third-Party Addons*

Turning Notes4Ever's toggle on changes an open window at once. Turning any of
them off needs a `/reload` before the Blizzard look returns; until then
`/n4e status` still names EllesmereUI. To keep the Blizzard look while using
EllesmereUI, turn Notes4Ever's toggle off there.

## Where your notes live, and how to keep them

Notes4Ever keeps two sets of notes: **account notes**, shared by all your
characters, and **character notes**, which belong to one character. The game
stores them in its `WTF` folder:

```
WTF\Account\<account>\SavedVariables\Notes4Ever.lua                        account notes
WTF\Account\<account>\<realm>\<character>\SavedVariables\Notes4Ever.lua    character notes
```

Four things to know:

- **The game saves only on `/reload`, logout, disconnect and quit.** If the
  game crashes, everything since the last of those is lost. No addon can
  prevent that.
- **Each save moves the previous file to `Notes4Ever.lua.bak`** — and replaces
  the `.bak` that was there. The `.bak` is always the state before the last
  save, no older. If Notes4Ever warns at login that notes could not be read or
  went missing, copy both `Notes4Ever.lua` and `Notes4Ever.lua.bak` somewhere
  safe *before* any `/reload` or logout. To put a copied file back, close the
  game first; the game overwrites the folder when it exits.
- **Notes that could not be read are kept, not overwritten.** While any are
  kept, right-clicking *Account notes* or *Character notes* shows **Kept for
  recovery**, listing each kept set with its date. **Restore** puts everything that can
  still be read into a new folder "Restored …"; **Discard** removes the set
  for good, after asking. A set saved by a newer Notes4Ever can only be
  discarded until you update. Export regularly - it is the only backup that
  does not depend on the game's files.
- **Character notes stay with the character's folder.** After a rename, a
  realm transfer or a faction change, the game starts a new, empty folder; the
  old notes are still in the old folder, and Notes4Ever may warn that they are
  missing. Keep anything you cannot lose in your account notes.

## License

[MIT](LICENSE)
