# SlotPort – Changelog

---

## 1.2.2

### New
- Characters page: the action bar layout of every character you log in on is saved automatically, per specialization, together with the character's own macros. Characters expand into their specializations; "Copy" opens the export string to paste into Import on a new character, so you no longer have to log into the old one first. Only characters of your current class are listed; "Show all characters" lists everyone.

---

## 1.2.1

### New
- Export now reports how many of the exported slots are empty, and warns when all of them are (importing empty entries only clears the target slots). Shown for `/sp export` and the Export button.
- `/sp debug bonus`: dumps Blizzard's own bar classification (bonus/vehicle/override/extra/multicast bar indices, bonus bar index per action page, page -> bar frame).
- `/sp debug slots` now also shows each slot's texture and `HasAction`; `/sp debug` shows the bonus bar index of every registered bar.

### Changed
- The bar list is always in physical slot order: Bar 1-6, Bonus Bar 1-4, Skyriding, Bonus Bar 6, Action Bar 6-8. Under ElvUI the ElvUI bars 7-10 and 13-15 now sit at their slots instead of after Skyriding/Bonus Bar 6.
- Under ElvUI the bars use ElvUI's own names only ("Bar 1" ... "Bar 15"; Skyriding and Bonus Bar 6 have no ElvUI number); the Default UI uses Blizzard's names. ElvUI bars 7-10 were called "ElvUI 7-10" before.
- Under ElvUI, bars 7-10 are now dimmed when switched off in ElvUI, like bars 2-6 and 13-15 (before they always counted as active). The "(inactive)" suffix is gone; dimmed bars are only greyed out.
- German bar names follow the converter naming: "Aktionsleiste 1 - Page 2", "Bonus Bar 1-4/6", "Skyriding".
- The bar frame for a Default UI bar is now looked up through Blizzard's `MultiActionBar_GetBarForPage` (the old frame table remains as a fallback).
- Export treats a slot as empty when `C_ActionBar.HasAction` reports no action, e.g. leftover placeholders of deleted macros (type `macro`, id 0).
- Fixed slot ranges (bars 1-6, bonus bars 73-132, Action Bar 6-8) checked against Blizzard's `C_ActionBar` data; no changes were needed.
- TOC Interface versions are now 12.1.0 and 12.1.5 (12.0.7 dropped).

---

## 1.2.0

### New
- Macro import now restores the exported icon for macros that have no `#show`/`#showtooltip` line (e.g. a manually chosen icon). Macros with `#show`/`#showtooltip` still get the default icon so it stays dynamic. If the icon can't be used, the default icon is used instead.
- Bar search: filter the bar list by name.
- Selection summary (slots and macros) in the sidebar; partial bar selection is shown with a dash.
- Log page with an unread marker in the sidebar.

### Changed
- New own window design ("Graphite" look, sidebar layout with pages Bars / Macros / Log) replaces both the Default UI look and the ElvUI skin - one look for everyone. The macro window is now a page of the main window (`/sp macros` opens it).
- Bars are shown as cards: click the card header to select the whole bar. Export is the one highlighted action; destructive actions (reset slots / delete macros) sit separately at the bottom left.
- Switching bars (e.g. after an ElvUI change) no longer recreates the window; bar cards and slot buttons are reused.
- All delayed refreshes (`C_Timer.After`) now use `RunNextFrame`; the ElvUI bar watcher coalesces bursts into one refresh.
- Folder structure: `Core/` (SlotPort, Bars, Cache, Debug), `Data/` (Macros, Export, Import), `UI/` (GUI), `Locales/`, `Libs/`, `Media/`. Files are now capitalized; `textures/` became `Media/`.
- Bundled libraries checked: `LibStub` (v2) and `AceDB-3.0` (v35, Ace3 release r1403 from Aug 2026) are the current releases.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Exporting slots and macros together and importing them on another character only imported the macros: the two parts were separated by a newline, which the single-line Export/Import edit box does not carry. Parts are now joined by a space and split again on import by their markers (older newline-separated strings still import).

### Removed
- `ElvUI_Skin.lua` and the bundled `AceGUI-3.0` library (only used for the old checkboxes).

---

## 1.1.5

### New
- Form 1-4 (Default UI only) show the actual form/stance name (e.g. "Cat Form", "Prowl", "Bear Form", "Moonkin Form" for Druids, "Stealth" for Rogues) instead of a generic label, for the classes that have one on the current retail patch. Classes without a form there show "Bonus Bar 1-4" (renamed from "Form 1-4" to match Blizzard's own naming). ElvUI keeps its own plain "ElvUI 7-10" numbering regardless of class - the form name is a Default UI/Blizzard-label thing only.

### Changed
- Main window is taller (8 bar rows visible instead of 6).
- The bar list now always shows every registered bar; disabled/empty bars are dimmed instead of hidden.
- Export/Import now uses native Blizzard `StaticPopupDialogs`: click Export to get a pre-filled, highlighted string ready for Ctrl+C, click Import to paste and confirm. `/sp export` opens the same popup.
- Export/Import buttons moved to their own row below Select All/Deselect/Reset, fixing overlap with those buttons.
- Updated bundled `LibStub` (v2) and `AceDB-3.0` (v35) to the current Ace3 release (r1403).
- Bar names now match the active UI: ElvUI shows its own "Bar 1-6" numbering, Default UI shows the correct Blizzard "Action Bar" names (they don't line up 1:1 - e.g. slots 61-72 are ElvUI "Bar 6" but Blizzard "Action Bar 2"). Also fixes the Default UI bars at slots 145-180, previously mislabeled "Action Bar 7-9" instead of "Action Bar 6-8".
- Bar and macro-row checkboxes now use an AceGUI-3.0 `CheckBox` widget instead of a raw Blizzard `CheckButton`/`UICheckButtonTemplate`. Requires the `AceGUI-3.0` library (core + `CheckBox` widget) alongside the existing `AceDB-3.0`. The ElvUI skin for checkboxes was rewritten to match the AceGUI widget's structure (`checkbg`/`check`/`highlight` textures) instead of Blizzard's `CheckButton` texture slots.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- ElvUI bars 13-15 only appeared after manually toggling one on and off: ElvUI doesn't populate a button's slot attribute until the bar has been enabled at least once this session. Now uses the known fixed slot mapping (145/157/169) instead of relying on that attribute, so they're detected immediately.
- ElvUI extra bars (7-15) were only registered when ElvUI's own "enabled" checkbox was on. That checkbox only controls on-screen visibility in ElvUI, not whether the bar's content/keybinds work - bars with it unchecked still had real content but never showed up in SlotPort. Now registered regardless of that checkbox and dimmed (not hidden) when disabled, matching bars 1-6.
- ElvUI's own custom bars weren't detected beyond the Midnight-era bars 13-15. Detection now covers ElvUI bars 7-15.
- Export/Import popup showed an empty edit box: patch 11.2 renamed `self.editBox`/`self.button1` on StaticPopup dialogs to accessor methods (`GetEditBox()`, `GetButton1()`); updated accordingly.
- Default UI bar visibility used the wrong Blizzard frame for bars 2-6 (e.g. Bar 3 checked `MultiBarBottomRight` instead of `MultiBarRight`), causing incorrect enabled/disabled detection in the bar list.
- Single Button Assistant (Assisted Combat) detection in `Export()` checked the wrong button frame for the same reason, and didn't check bar 6 or bars 13-15 at all.
- `/sp debug` showed wrong slot ranges for `MultiBarBottomLeft/Right`, `MultiBarRight/Left`.
- Bar list order didn't follow physical slot order: Skyriding (121-132) was appended after Bonus Bar 6 (133-144) instead of before it, and (Default UI only) Action Bar 6-8 (145-180) was inserted right after Action Bar 6 instead of at the end. Correct order is now Bar 1-6 -> Form 1-4 -> Skyriding -> Bonus Bar 6 -> Action Bar 6-8 (Default UI) / ElvUI extra bars.
- Class Form/stance bars (slots 73-120) are now hidden under ElvUI (superseded by ElvUI's own Bar 7-10, read via its actual button data) instead of duplicating the same slots as a second, separately-detected "ElvUI 7-10" entry.
- Disabled bars never showed their icons at all: `RefreshAllSlots` skipped the whole icon-refresh loop for any bar with `isEnabled == false`, so a bar's content was invisible until you turned it on in ElvUI - regardless of whether that content was actually readable. Icons now always refresh; the label dimming already shown for disabled bars is untouched.
- "Select All" skipped disabled-but-populated bars for the same outdated reason, so a bar with real content never got selected/exported unless it was active in ElvUI first.
- ElvUI's Bar 13-15 (fixed Blizzard slots 145/157/169, "Action Bar 6-8") now read their content directly from those slots instead of through ElvUI's per-button attributes, which are only populated once the bar has been toggled on at least once this session.
- ElvUI's Bar 7-10 didn't show up at all for many setups (e.g. Druids and other classes with Form/stance bars): they were only registered when ElvUI's own `ElvUI_Bar7`-`ElvUI_Bar10` button frames existed, which most ElvUI profiles never create since those bar numbers are rarely configured as their own bars. They now also fall back to Blizzard's Form/stance slots (73/85/97/109) when no real ElvUI bar data exists, so the class's actual Form/stance content always shows - matching Default UI's Form 1-4. A genuinely configured ElvUI bar 7-10 still takes priority over the fallback when it exists.
- `SetupElvUIWatchers` re-ran its hook registration on every `PLAYER_ENTERING_WORLD` (every loading screen/zone change, not just login), stacking a new `OnShow`/`OnHide`/`PositionAndSizeBar` hook on the same persistent frames each time - a single real bar change could fire the refresh handler once per accumulated hook after a long session. Hooks are now only ever attached once per frame/function.
- The ElvUI checkbox skin's `hooksecurefunc(cb, "SetValue", ...)` could stack the same way: AceGUI pools and reuses checkbox widget objects, and `RebuildGrid` resets the skin flag on every rebuild, so a recycled checkbox got re-hooked every time it was re-skinned. Now guarded by a separate flag that isn't reset, so each checkbox is only ever hooked once.

### Cleanup
- Translated remaining German code comments to English (`gui.lua`, `macros.lua`, `import.lua`, `deDE.lua`).
- Removed 5 dead locale keys left over from the pre-`StaticPopupDialogs` export/import UI (`EXPORT_IMPORT`, `CLEAR_BTN`, `COPY_HINT`, `COPY_KEY_WIN`, `COPY_KEY_MAC`).
- Fixed a misplaced comment header in the locale files (debug keys were labeled "ElvUI Skin options").
- Moved diagnostic-only functions (`DebugTestNativeEncoding`, `DebugCountRealExport`) out of `export.lua` into a new `debug.lua` module to keep the export/import code focused. No behavior change; the native codec helpers are now exposed as `SlotPort.NativeCompress`/`NativeDecompress`/`NativeCompressAvailable` so `debug.lua` can reach them.
- `RebuildGrid` now releases old bar checkboxes back to the AceGUI widget pool instead of discarding them, avoiding an orphaned-widget buildup on repeated rebuilds.
- "ElvUI Bar N detected" moved from a chat `print()` to the Protokoll log box - it could fire repeatedly (e.g. on zone changes) and spam the chat window.

---

## 1.1.4

### New
- Export now shows a "press Ctrl+C to copy" hint, since addons can't write to the clipboard directly.

### Changed
- Replaced LibDeflate with native `C_EncodingUtil` for export compression (`!SP3!` format).

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Import failed with "Ungültiges Format" for `!SP3!` exports.
- Import/export slot count mismatches – incorrect pipe-escaping and undercounted empty slots.
- Orphaned slot selections from removed ElvUI bars inflated the selected count.
- `/sp export` didn't focus the export box, so Ctrl+C didn't work.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Exporting slots and macros together and importing them on another character only imported the macros: the two parts were separated by a newline, which the single-line Export/Import edit box does not carry. Parts are now joined by a space and split again on import by their markers (older newline-separated strings still import).

### Removed
- LibDeflate dependency. Old `!SP2!` export strings are no longer importable.

---

## 1.1.3

### Changed
- Bumped TOC Interface version to 120100 for WoW patch 12.1.

---

## 1.1.2

### New
- "Reset Slots" button – clears selected slots, with confirmation.
- "Delete Macros" button – deletes selected macros, with confirmation.

### Changed
- Export performance: hoisted a per-slot table allocation out of the loop.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Macro import locked the icon, breaking dynamic `#showtooltip` icons.
- Import button crashed on click – invalid Lua 5.4 loop-variable reassignment.
- Addon version was hardcoded instead of read from the `.toc`.
- Hardcoded German strings in debug/error output bypassed the locale system.

---

## 1.1.1

### New
- Ctrl+C now auto-closes the window after copying the export text.
- Shared, correct spellbook iteration helper for Player/Pet banks.
- `/sp debug spell <id>` – looks up a spell/flyout ID across spellbook banks.

### Changed
- TOC now targets Interface `120007` only.
- All source comments translated to English.
- Removed redundant per-file header blocks (metadata lives in the `.toc`).

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Spell/flyout import fallback used an unreliable spellbook API; replaced with correct skill-line iteration.

---

## 1.1.0

### New
- Compressed export format `!SP2!` (LibDeflate + base64-like encoding).
- Macro window tabs: Global / Character.
- Global macros are now exportable, not just character macros.
- Scrollable bar list in the main window.

### Changed
- Empty bars are now always hidden, including ElvUI bars.
- Uniform scrollbar alignment across all three scroll areas.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- `!SP2!` import strings were rejected by the format auto-detection.
- ElvUI bar visibility regression removed enabled bars.
- Macro window anchored to a stale frame reference after a grid rebuild.
- Various `gui.lua` bugs (undefined width variable, escaping, debounce, dead code).

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Exporting slots and macros together and importing them on another character only imported the macros: the two parts were separated by a newline, which the single-line Export/Import edit box does not carry. Parts are now joined by a space and split again on import by their markers (older newline-separated strings still import).

### Removed
- Redundant "Charakter-Makros" header label.
- ~30 dead locale keys.

---

## 1.0.4

### Changed
- Export/Import merged into the main window; macro window now only handles selection.
- Export/Import auto-detect scope and format instead of a manual selector.
- Macro list made taller after removing the export section.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Character macro lookup by body prefix skipped character-scope macros.
- Misleading indentation in `export.lua`.
- Macro window didn't anchor to the main frame on first open.
- ESC didn't close the window while an EditBox had focus.
- Macro export text box could end up empty due to unescaped `|`.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Exporting slots and macros together and importing them on another character only imported the macros: the two parts were separated by a newline, which the single-line Export/Import edit box does not carry. Parts are now joined by a space and split again on import by their markers (older newline-separated strings still import).

### Removed
- Scope selector buttons (redundant after auto-detection).
- Export/Import UI from the macro window.
- A few dead locale keys and stale comments.

---

## 1.0.3

### New
- Macro window (`/sp macros`) – export/import macro name, icon, and body independently of action bars.
- `macros.lua` module with macro data logic.

### Changed
- Load order: `macros.lua` after `cache.lua`.

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Toy pickup in the ElvUI item path used a deprecated global.
- Export slot counter incorrectly included empty slots.

---

## 1.0.2

### New
- `cache.lua` – shared pet spell and mount caches.
- Action Bar 6–9 and Bonus Bar 6 support.
- Single Button Assistant detection and export.
- `/sp debug slots` command.

### Changed
- Split `SlotPort.lua` into separate core/bars/cache/export/import modules.
- Removed `settings.lua` (no configurable options).

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Action Bars 6–9 not recognized – slot ID ranges moved in WoW Midnight 12.0.
- Several bar ordering/visibility bugs (ElvUI vs. Default UI mixed up, disabled bars shown, wrong insert position).
- Single Button Assistant exported the wrong spell.
- `SlotPort.lua` syntax error prevented the addon from loading.

---

## 1.0.1

### New
- Optional ElvUI skin.
- Import result now lists skipped slots with reasons.

### Changed
- Mount journal scan optimized from O(slots × mounts) to O(mounts).

### Cleanup
- Export and import rewritten as small per-type handlers (no behavior change); shared helpers for pipe-aware splitting, toy detection, cursor placement and bar content scans replace several copy-pasted blocks.
- `/sp import` and the import popup share one code path and both accept slots and macros together.
- `/sp debug` moved to `Core/Debug.lua`; its report now opens in the export popup instead of a removed edit box.
- Slot-change events are ignored while the window is hidden.
- Removed unused code (`SlotPort:SetSlot`, `readOnly`/`isActive` bar flags, unused locale key); comments updated to the new file layout.

### Fixed
- Import broken by incorrect `|` escaping handling.
- Several outdated/incorrect API calls (spellbook, mount journal).
- Pet spell cache stored wrong spell IDs.
- AceDB initialized too early.
- TOC referenced wrong library filenames.

---

## 1.0.0

### New
- Export and import of action bar slots (Bars 1–10, Slots 1–120).
- Support for spells, items, toys, macros, mounts, battle pets, equipment sets, flyouts, pet spells.
- ElvUI custom bar detection, Skyriding bar, Bartender4 detection.
- AceDB-backed window position, localization (enUS, deDE).
- `/sp` and `/slotport` slash commands.
