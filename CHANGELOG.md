# Changelog

All notable changes to Notes4Ever. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

Checked in game on WoW: Forever 1.60.1.70291 (interface 16001), with and
without EllesmereUI 9.4.

### Added

- The notebook window: `/n4e`, `/notes` or the AddOn compartment entry open
  and close it, Escape closes it. It can be moved and resized and comes back
  where it was left.
- The tree on the window's left shows account and character notes, each
  folder and page marked by its own icon; folders open and close on click.
  Right-click a row for new folder, new page, rename, move to any folder of
  either set, and delete - which first asks, naming how many folders and
  pages go. A new folder or page is named first; Cancel creates nothing.
- Click a page to write in it. Text is saved a moment after you stop typing,
  and at once when you close the window, open another page, change the tree,
  log out or reload.
- With EllesmereUI installed and skinning third-party addons, the window takes
  on EllesmereUI's look - backdrop, border, close button, scroll bar, font,
  and its accent colour for the selected row. EllesmereUI's own toggle for
  Notes4Ever decides; turning it off takes a `/reload`.
- `/n4e status` prints the addon's version, the window's design and, for
  account and character notes, how many there are, the schema, when they
  were created, how often they were loaded and how many unreadable sets are
  kept.
- A toolbar above the page: gold headings, colours for a word or for what
  you type next, bullets, checkboxes to tick, and raid marker, quest, coin
  and role icons. An icon comes with a space after it, since the game's
  text field cannot put the cursor directly behind an icon.
- A search box above the tree shows only the pages and folders that contain
  what you type, by title or text.
- Export any page, folder or whole set of notes as readable text to copy out
  with Ctrl+C, as a backup or to share; import such text into any folder.
  Nothing is overwritten, and text that is not a valid export is refused
  with the reason.
- Saved notes that cannot be read are never overwritten: they are kept for
  recovery, and every login says so and how to secure the game's backup file.
  The root's right-click menu restores what can still be read into a new
  folder, or discards a kept set after asking.
- German texts on a German client; anything not yet translated shows in
  English.
