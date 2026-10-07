# Changelog

All notable changes to Notes4Ever. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

Checked in game on WoW: Forever 1.60.1.70245 (interface 16001).

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
- `/n4e status` prints the addon's version and, for account and character
  notes, how many there are, the schema, when they were created, how often
  they were loaded and how many unreadable sets are kept.
- Saved notes that cannot be read are never overwritten: they are kept for
  recovery, and every login says so and how to secure the game's backup file.
- German texts on a German client; anything not yet translated shows in
  English.
