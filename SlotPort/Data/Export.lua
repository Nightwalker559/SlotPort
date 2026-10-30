-- ============================================================
-- Export: slots -> "SLOTPORT:v1|slot:type:id:extra|..." string (optionally
-- !SP3!-compressed), plus the codec and the splitting helpers shared with
-- Import.lua and Macros.lua.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

-- Escapes a literal "|" for the export format ("||"); see SlotPort.SplitEntries.
local function esc(s)
    return (tostring(s):gsub("|", "||"))
end

local function emptyEntry(slot)
    return slot .. ":empty::"
end

-- Helper: robustly determine a macro's export name
--
-- Since patch 10.2, GetActionInfo() for actionType=="macro" no longer
-- returns the macroID in 'id', but the ID of the macro's content
-- (SpellID, ItemID etc.) - or garbage. GetMacroInfo(id) therefore
-- returns the wrong macro name or none at all.
--
-- Reliable order:
--   1. GetActionText(slot)  - reads the name directly from the action slot,
--                             reliable since 10.2, independent of the id issue
--   2. GetMacroInfo(macroID) - fallback if slot is nil (e.g. ElvUI path)
--   3. Macro body as last resort (prefix "~body~")
-- ----------------------------------------------------------
local function getMacroExportName(macroID, slot)
    if slot then
        local actionText = GetActionText(slot)
        if actionText and actionText ~= "" then return actionText end
    end
    if macroID then
        local name, _, body = GetMacroInfo(macroID)
        if name and name ~= "" then return name end
        if body and body ~= "" then
            local firstLine = body:match("^([^\n]+)") or body
            return "~body~" .. firstLine:sub(1, 40)
        end
    end
    return nil
end

local function toyEntry(slot, itemID)
    local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if itemName then
        return string.format("%d:toy:%d:%s", slot, itemID, esc(itemName))
    end
    return string.format("%d:toy:%d:", slot, itemID)
end

local function mountEntry(slot, mountID)
    local mountName = ""
    if mountID and mountID ~= SlotPort.RANDOM_MOUNT_ID and C_MountJournal then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        mountName = name and esc(name) or ""
    end
    return string.format("%d:summonmount:%d:%s", slot, mountID or 0, mountName)
end

local function spellEntry(slot, spellID)
    if SlotPort.isPetSpell(spellID) then
        return string.format("%d:petspell:%d:", slot, spellID or 0)
    end
    return string.format("%d:spell:%d:", slot, SlotPort.baseSpellID(spellID) or 0)
end

-- Button frame names per default-UI bar (used for single-key-assist detection).
-- NOTE: Blizzard's action pages are not sequential to its bar frames - page 2
-- (slots 13-24) has no dedicated frame, and pages 3-6 map in reverse order
-- (see Core/Bars.lua BAR_FRAMES for the authoritative mapping).
local ASSIST_BTN_FRAME_NAMES = {
    [1]  = "ActionButton",
    -- [2] intentionally omitted: slots 13-24 (page 2) has no dedicated frame
    [3]  = "MultiBarRightButton",       -- slots 25-36
    [4]  = "MultiBarLeftButton",        -- slots 37-48
    [5]  = "MultiBarBottomRightButton", -- slots 49-60
    [6]  = "MultiBarBottomLeftButton",  -- slots 61-72
    [13] = "MultiBar5Button",           -- slots 145-156
    [14] = "MultiBar6Button",           -- slots 157-168
    [15] = "MultiBar7Button",           -- slots 169-180
}

-- True if the single-button assistant sits on this default-UI slot.
-- GetActionInfo returns the currently suggested spell, not the assist itself,
-- so the button frame is checked instead. Blizzard uses ActionButton1-12 for
-- all bar pages (incl. form bars 7-10 while in the matching form).
local function isAssistedCombatSlot(slot)
    local btnIndex = ((slot - 1) % 12) + 1
    local barNum   = math.ceil(slot / 12)
    local frameName = ASSIST_BTN_FRAME_NAMES[barNum]
    if not frameName and barNum >= 7 and barNum <= 10 then
        frameName = "ActionButton"
    end
    if not frameName then return false end
    local btn = _G[frameName .. btnIndex]
    return btn and btn.AssistedCombatRotationFrame
        and btn.AssistedCombatRotationFrame:IsShown() or false
end

-- ----------------------------------------------------------
-- Export entry for one slot of a standard (Blizzard API) bar
-- ----------------------------------------------------------
local function exportStandardSlot(slot)
    if isAssistedCombatSlot(slot) then
        return string.format("%d:assistedcombat:%d:", slot, SlotPort.ASSISTED_COMBAT_SPELL_ID)
    end

    local actionType, id, subtype = GetActionInfo(slot)

    -- GetActionInfo still reports a type for leftover placeholders of deleted
    -- macros ("macro", id 0, no texture); HasAction is false for those
    -- (verified in-game on slots 38-40) and is the canonical emptiness check.
    if actionType and C_ActionBar and C_ActionBar.HasAction
       and C_ActionBar.HasAction(slot) == false then
        return emptyEntry(slot)
    end

    if not actionType then
        return emptyEntry(slot)

    elseif actionType == "spell" then
        return spellEntry(slot, id)

    elseif actionType == "item" then
        if SlotPort.IsToy(id) then
            return toyEntry(slot, id)
        end
        return string.format("%d:item:%d:", slot, id or 0)

    elseif actionType == "macro" then
        local macroName = getMacroExportName(id, slot)
        if macroName then
            return string.format("%d:macro:%s:", slot, esc(macroName))
        end
        return emptyEntry(slot)

    elseif actionType == "summonmount" then
        return mountEntry(slot, id)

    elseif actionType == "companion" or actionType == "summonpet" then
        local petName = ""
        if id and C_PetJournal then
            local name = C_PetJournal.GetPetInfoBySpeciesID and
                         C_PetJournal.GetPetInfoBySpeciesID(id)
            petName = name and esc(name) or tostring(id)
        end
        return string.format("%d:%s:%d:%s", slot, actionType, id or 0,
            petName ~= "" and petName or (subtype or ""))

    elseif actionType == "equipmentset" then
        return string.format("%d:equipmentset:%s:", slot, tostring(id or ""))

    elseif actionType == "flyout" then
        return string.format("%d:flyout:%d:", slot, id or 0)
    end

    -- Any other type: export generically
    return string.format("%d:%s:%s:%s", slot, tostring(actionType),
        tostring(id or ""), tostring(subtype or ""))
end

-- ----------------------------------------------------------
-- Export entry for one button of an ElvUI bar (read via ElvUI button data)
-- ----------------------------------------------------------
local function exportElvUISlot(bar, buttonIndex, slot, mountCache)
    local btnType, btnAction = SlotPort:GetElvUIButtonInfo(bar.elvuiBarNum, buttonIndex)

    if not btnType then
        return emptyEntry(slot)

    elseif btnType == "macro" then
        local macroName = getMacroExportName(btnAction, slot)
        if macroName then
            return string.format("%d:elvui_macro:%s:%d", slot, esc(macroName), bar.elvuiBarNum)
        end
        return emptyEntry(slot)

    elseif btnType == "spell" then
        local spellID = tonumber(btnAction)
        local cachedMountID = spellID and mountCache[spellID]
        if cachedMountID then
            return mountEntry(slot, cachedMountID)
        elseif SlotPort.isPetSpell(spellID) then
            return string.format("%d:petspell:%d:", slot, spellID)
        end
        return string.format("%d:elvui_spell:%s:%d", slot,
            tostring(SlotPort.baseSpellID(spellID) or btnAction), bar.elvuiBarNum)

    elseif btnType == "item" then
        local itemID = tonumber(btnAction)
        if itemID and SlotPort.IsToy(itemID) then
            return toyEntry(slot, itemID)
        end
        return string.format("%d:elvui_item:%s:%d", slot, tostring(btnAction), bar.elvuiBarNum)
    end

    return string.format("%d:elvui_%s:%s:%d", slot, btnType,
        tostring(btnAction or ""), bar.elvuiBarNum)
end

-- ----------------------------------------------------------
-- Export
-- ----------------------------------------------------------
function SlotPort:Export()
    if self:GetSelectedCount() == 0 then
        return nil, L("NO_SLOTS_SELECTED")
    end
    return self:ExportSlots(self.selectedSlots)
end

-- Exports the slots in the set `slots` ([slot] = true), whichever bars they sit on.
-- Also used for the character snapshots (Data/Characters.lua), which export
-- every slot instead of the user's selection.
function SlotPort:ExportSlots(slots)
    SlotPort.petSpellCache = nil
    local mountCache = SlotPort.buildMountSpellCache()

    local parts = { "SLOTPORT:v1" }

    for _, bar in ipairs(self.BARS) do
        local numSlots = bar.endSlot - bar.startSlot + 1
        for s = 1, numSlots do
            local slot = bar.startSlot + (s - 1)
            if slots[slot] then
                if bar.isElvUI and not bar.fixedSlot then
                    parts[#parts + 1] = exportElvUISlot(bar, s, slot, mountCache)
                else
                    -- Standard bars and the skyriding bar (which may hold any
                    -- action type, not just the dragonriding spells)
                    parts[#parts + 1] = exportStandardSlot(slot)
                end
            end
        end
    end

    -- Every selected slot of a registered bar yields exactly one entry
    local written = #parts - 1
    if written == 0 then
        return nil, L("ALL_EMPTY")
    end

    -- Third return: how many of the entries are real (non-empty) actions.
    -- Empty entries are still exported on purpose - importing them clears
    -- the target slot (Import.lua HANDLERS.empty).
    local filled = 0
    for i = 2, #parts do
        if not parts[i]:find("^%d+:empty::") then filled = filled + 1 end
    end

    return SlotPort.EncodeForExport(table.concat(parts, "|")), written, filled
end

-- ----------------------------------------------------------
-- SP3 codec: native C_EncodingUtil.CompressString + EncodeBase64
-- -> "!SP3!...". Native since patch 11.1.5, no external library.
-- ----------------------------------------------------------
local function nativeCompressAvailable()
    return C_EncodingUtil and C_EncodingUtil.CompressString
       and C_EncodingUtil.DecompressString
       and C_EncodingUtil.EncodeBase64 and C_EncodingUtil.DecodeBase64
end
SlotPort.NativeCompressAvailable = nativeCompressAvailable

local function nativeCompress(raw)
    local method = Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local ok, compressed = pcall(C_EncodingUtil.CompressString, raw, method)
    if not ok or not compressed then
        ok, compressed = pcall(C_EncodingUtil.CompressString, raw)
    end
    if not ok or not compressed then return nil end
    local ok2, encoded = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not ok2 or not encoded then return nil end
    return encoded
end
SlotPort.NativeCompress = nativeCompress

local function nativeDecompress(encoded)
    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, encoded)
    if not ok or not compressed then return nil, "DecodeBase64 failed" end
    local method = Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local ok2, raw = pcall(C_EncodingUtil.DecompressString, compressed, method)
    if not ok2 or not raw then
        ok2, raw = pcall(C_EncodingUtil.DecompressString, compressed)
    end
    if not ok2 or not raw then return nil, "DecompressString failed" end
    return raw
end
SlotPort.NativeDecompress = nativeDecompress

function SlotPort.EncodeForExport(raw)
    if nativeCompressAvailable() then
        local encoded = nativeCompress(raw)
        if encoded then
            -- Self-verify: immediately decode what we just encoded and compare
            -- to the original. Guards against native CompressString/
            -- DecompressString round-trip corruption on larger payloads (stray
            -- bytes survive a bad round-trip and import extra slots). Never
            -- hand out a compressed string we haven't verified decodes correctly.
            local ok, verified = pcall(nativeDecompress, encoded)
            if ok and verified == raw then
                return "!SP3!" .. encoded
            end
        end
    end
    -- Native codec unavailable or failed verification: export uncompressed
    -- rather than risk a corrupted compressed string.
    return raw
end

-- Splits an export string on "|" separators. Content fields (macro/toy/item/
-- mount names) escape a literal "|" as "||" at export time. A char-by-char
-- scan is required to tell "||" (literal pipe) apart from a single "|"
-- (entry separator) - gmatch("[^|]+") can't: it would split escaped content
-- into extra bogus entries and inflate the imported slot count.
-- Newlines are normalised to "|" for manually typed strings.
function SlotPort.SplitEntries(str)
    str = str:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", "|")

    local entries = {}
    local buf = {}
    local i, len = 1, #str
    while i <= len do
        local c = str:sub(i, i)
        if c == "|" then
            if str:sub(i + 1, i + 1) == "|" then
                buf[#buf + 1] = "|"  -- escaped literal pipe
                i = i + 2
            else
                entries[#entries + 1] = table.concat(buf)
                buf = {}
                i = i + 1
            end
        else
            buf[#buf + 1] = c
            i = i + 1
        end
    end
    entries[#entries + 1] = table.concat(buf)
    return entries
end

-- Splits pasted import text into its parts (slots / macros). A single-line
-- edit box (Export/Import popup) can't carry newlines, so parts are joined by
-- a space on export; here they are split on their markers instead, which
-- also keeps older newline-separated strings working.
function SlotPort.SplitImportParts(raw)
    local s = tostring(raw or ""):gsub("\r\n?", "\n")
    s = s:gsub("%s*!SP3!", "\n!SP3!")
    s = s:gsub("%s+SLOTPORTMACRO:", "\nSLOTPORTMACRO:")
    s = s:gsub("%s+SLOTPORT:", "\nSLOTPORT:")
    local parts = {}
    for rawLine in s:gmatch("[^\n]+") do
        local line = rawLine:match("^%s*(.-)%s*$")
        if line ~= "" then parts[#parts + 1] = line end
    end
    return parts
end

function SlotPort.DecodeFromExport(str)
    if not str or str == "" then return nil end

    if str:sub(1, 5) == "!SP3!" then
        if not nativeCompressAvailable() then
            return nil, "C_EncodingUtil not available"
        end
        return nativeDecompress(str:sub(6))
    end

    -- No prefix -> return directly (uncompressed / legacy plain string)
    return str
end

