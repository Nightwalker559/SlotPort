# SlotPort

Export and import your action bar layouts and macros between characters, as one compact string you can copy, share or store anywhere.

For World of Warcraft Retail (12.1.0, 12.1.5). English and German. Works with the default Blizzard UI and ElvUI; Bartender4 is detected.

**Author:** Nightwalker559 · **License:** MIT with AI restriction

---

## Features

- **Action bars:** select whole bars or single slots. Supported: spells, items, toys, macros, mounts, battle pets, equipment sets, flyouts, pet spells and the single-button assistant.
- **Macros:** export global and character macros. Macros with the same name are updated, missing ones created.
- **One string:** slots and macros together, compressed, starting with `!SP3!`.
- **Every bar in slot order:** Bar 1-6, Bonus Bar 1-4 (class form bars show the form name), Skyriding, Bonus Bar 6 and Action Bar 6-8. The default UI uses Blizzard's bar names, ElvUI its own. Bars that are switched off are greyed out but can still be exported.
- **Reset slots** before importing a new layout.
- **Clear feedback:** the export reports empty slots, the Log page lists everything imported or skipped, and why.

## Usage

Open the window with `/sp` or `/slotport` (sidebar: Bars, Macros, Log).

- **Export:** select bars (click a bar header) or single slots, or macros on the Macros page. Click **Export** and copy the string with Ctrl+C.
- **Import:** on the target character open `/sp`, click **Import**, paste the string and confirm. Macros are imported first, then the slots. Not possible in combat.

| Command | What it does |
| --- | --- |
| `/sp` | Open or close the window |
| `/sp macros` | Open the macros page |
| `/sp export` | Export the selected slots and show the string |
| `/sp import <string>` | Import a string (slots, macros or both) |
| `/sp debug` | Bar and slot diagnostics (`/sp debug slots`, `bonus`, `spell <id>` for details) |
| `/sp help` | List the commands |

## Good to know

- Empty slots in the export clear the matching slot on import.
- Macros without `#show`/`#showtooltip` keep their exported icon; macros with it get the default icon so it stays dynamic.
- Slots whose spell, item or macro does not exist on the target character are skipped and logged.
- WoW allows 120 global and 18 character macros; macros over the limit are skipped.

---

See the [changelog](https://github.com/Nightwalker559/SlotPort/blob/main/CHANGELOG.md) for the version history.

## Feedback

Found a bug or have an idea? [Open an issue on GitHub](https://github.com/Nightwalker559/SlotPort/issues). `/sp debug` output helps a lot for bar and slot problems.

## License

MIT with AI restriction (no use for AI or machine learning), see [LICENSE.md](https://github.com/Nightwalker559/SlotPort/blob/main/LICENSE.md).
