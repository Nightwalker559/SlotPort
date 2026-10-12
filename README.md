# SlotPort

Export and import your action bar layouts and macros between characters, as one compact string you can copy, share or store anywhere.

## Features

- **Action bars:** pick whole bars or single slots and export them. Spells, items, toys, macros, mounts, battle pets, equipment sets, flyouts, pet spells and the single-button assistant are supported.
- **Macros:** export global and character macros. Existing macros with the same name are updated, missing ones are created.
- **One string for everything:** slots and macros can be exported and imported together. Strings are compressed and start with `!SP3!`.
- **Default UI and ElvUI:** bar names follow the active UI (Blizzard "Action Bar 1-8" or ElvUI "Bar 1-15"), listed in slot order. Bonus bars and the skyriding bar are included.
- **Reset slots:** clear the selected slots before importing a new layout.
- **Own window:** a flat dark window with a sidebar (Bars, Macros, Log), a bar search, and a selection summary. It looks the same with or without ElvUI.
- **Languages:** English and German.

## Usage

Open the window with `/sp` or `/slotport`.

| Command | What it does |
| --- | --- |
| `/sp` | Open or close the window |
| `/sp macros` | Open the window on the macros page |
| `/sp export` | Export the selected slots and show the string |
| `/sp import <string>` | Import a string (slots, macros, or both) |
| `/sp debug` | Show bar and slot diagnostics (`/sp debug slots`, `/sp debug bonus`, `/sp debug spell <id>`) |
| `/sp help` | List the commands |

### Export

1. Open `/sp`, select bars (click a bar's header) or single slots. On the Macros page, select macros.
2. Click **Export**, then copy the string from the popup with Ctrl+C.

### Import

1. Log in on the target character and open `/sp`.
2. Click **Import**, paste the string and confirm. Macros are imported first, then the slots.
3. The Log page shows what was imported and what was skipped, and why.

Import is not possible in combat.

## Good to know

- **Macro icons:** macros without `#show`/`#showtooltip` keep their exported icon. Macros with it get the default icon so the icon stays dynamic.
- **Missing spells:** slots whose spell, item or macro doesn't exist on the target character are skipped and listed in the log.
- **Macro limits:** WoW allows 120 global and 18 character macros. Macros over the limit are skipped.
- **Empty slots:** empty slots in the export clear the matching slot on import.
- **Disabled bars:** bars that are switched off (e.g. in ElvUI) are shown dimmed; their contents can still be exported.

## Compatibility

- World of Warcraft Retail (Interface 12.1.0, 12.1.5)
- Optional: ElvUI, Bartender4 (detected)

## Libraries

- LibStub
- AceDB-3.0

Both are bundled in `Libs/`.

## Changelog

Release notes are in `CHANGELOG.md` in the addon folder.
