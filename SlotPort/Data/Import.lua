local L = function(key) return (SlotPortL and SlotPortL[key]) or key end

local RANDOM_MOUNT_ID = 268435455   -- "Random Favorite Mount" pseudo mount ID
local ASSISTED_COMBAT_SPELL_ID = 1229376

-- ----------------------------------------------------------
-- Cursor helpers
-- ----------------------------------------------------------

-- Drops whatever is on the cursor into the slot. Returns true if something was placed.
local function placeCursor(slot)
    if not GetCursorInfo() then return false end
    PlaceAction(slot)
    ClearCursor()
    return true
end

local function pickupItem(itemIDOrName)
    if C_Item and C_Item.PickupItem then
        C_Item.PickupItem(itemIDOrName)
    else
        PickupItem(itemIDOrName)
    end
end

local function spellName(spellID)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)
end

local function pickupSpellBookItem(index, bank)
    if index and C_SpellBook and Enum and Enum.SpellBookSpellBank then
        C_SpellBook.PickupSpellBookItem(index, bank)
        return true
    end
    return false
end

-- Places a spell via C_Spell.PickupSpell, optionally falling back to a skill-line
-- spellbook search (GetNumSpellBookItemsForSpellBank is unreliable in 12.0, see
-- SlotPort.findPlayerSpellBookSlot in Core/Cache.lua).
local function placeSpell(slot, spellID, useSpellBookFallback)
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(spellID)
        if placeCursor(slot) then return true end
    end
    if useSpellBookFallback then
        local bookSlot = SlotPort.findPlayerSpellBookSlot(spellID)
        if pickupSpellBookItem(bookSlot, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
           and placeCursor(slot) then
            return true
        end
    end
    return false
end

-- Places a mount by its mountID (via its Mount Journal display index)
local function placeMount(slot, mountID)
    local dispIdx = SlotPort.getMountDisplayIndex(mountID)
    if not dispIdx then return false end
    C_MountJournal.Pickup(dispIdx)
    return placeCursor(slot)
end

local function placeToyViaToyBox(slot, itemID)
    if not (C_ToyBox and C_ToyBox.PickupToyBoxItem) then return false end
    return (pcall(function()
        C_ToyBox.PickupToyBoxItem(itemID)
        PlaceAction(slot)
        ClearCursor()
    end))
end

-- ----------------------------------------------------------
-- Per-type import handlers.
-- Each gets (slot, idStr, extra, ctx) and returns:
--   true            -> slot imported
--   false, message  -> slot skipped (message optional, added to the hints)
--   nil             -> nothing to do (not counted either way)
-- ----------------------------------------------------------
local HANDLERS = {}

HANDLERS.elvui_macro = function(slot, idStr)
    local macroName  = idStr:gsub("||", "|")
    local macroIndex = GetMacroIndexByName(macroName)
    if not (macroIndex and macroIndex > 0) then
        return false, string.format(L("MACRO_NOT_FOUND"), macroName, slot)
    end
    PickupMacro(macroIndex)
    if placeCursor(slot) then return true end
    return false, string.format(L("MACRO_NOT_PLACED"), macroName, slot)
end

HANDLERS.elvui_spell = function(slot, idStr, _, ctx)
    local spellID = tonumber(idStr)
    if not (spellID and spellID > 0) then return nil end

    -- Attempt 1: spell is a mount (detected via the mount cache)
    local cachedMountID = ctx.mountCache[spellID]
    if cachedMountID and placeMount(slot, cachedMountID) then return true end

    -- Attempt 2: normal spell
    if placeSpell(slot, spellID, false) then return true end
    return false, string.format(L("SPELL_NOT_AVAIL"), spellName(spellID), slot)
end

HANDLERS.elvui_item = function(slot, idStr)
    local itemID = tonumber(idStr)
    if not (itemID and itemID > 0) then return nil end
    pickupItem(itemID)
    if placeCursor(slot) then return true end
    return false, string.format(L("ITEM_NOT_AVAIL"),
        SlotPort.IsToy(itemID) and L("TOY_LABEL") or L("ITEM_LABEL"), itemID, slot)
end

HANDLERS.flyout = function(slot, idStr)
    local flyoutID = tonumber(idStr)
    if not (flyoutID and flyoutID > 0) then return nil end
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(flyoutID)
    end
    if placeCursor(slot) then return true end

    local bookSlot = SlotPort.findPlayerSpellBookSlot(flyoutID)
    if pickupSpellBookItem(bookSlot, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
       and placeCursor(slot) then
        return true
    end
    return false, string.format(L("FLYOUT_MANUAL"), slot)
end

HANDLERS.petspell = function(slot, idStr)
    local spellID = tonumber(idStr)
    if spellID then
        SlotPort.petSpellCache = nil
        local petIdx = SlotPort.getPetSpellIndex(spellID)
        if pickupSpellBookItem(petIdx, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet)
           and placeCursor(slot) then
            return true
        end
    end
    return false, string.format(L("PETSPELL_NOT_AVAIL"), spellName(spellID), slot)
end

HANDLERS.assistedcombat = function(slot, idStr)
    local assistSpellID = tonumber(idStr) or ASSISTED_COMBAT_SPELL_ID
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(assistSpellID)
        if placeCursor(slot) then return true end
    end
    return false, string.format(L("SPELL_NOT_IN_BOOK"), L("ASSISTED_COMBAT_LABEL"), slot)
end

HANDLERS.empty = function(slot)
    -- Clear the slot (source character had this slot empty)
    PickupAction(slot)
    ClearCursor()
    return true
end

HANDLERS.spell = function(slot, idStr)
    local spellID = tonumber(idStr)
    if not (spellID and spellID > 0) then return nil end
    if placeSpell(slot, spellID, true) then return true end
    return false, string.format(L("SPELL_NOT_IN_BOOK"), spellName(spellID), slot)
end

HANDLERS.item = function(slot, idStr)
    local itemID = tonumber(idStr)
    if not (itemID and itemID > 0) then return nil end

    if SlotPort.IsToy(itemID) then
        if placeToyViaToyBox(slot, itemID) then return true end
        local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
        if itemName then PickupItem(itemName) end
        if placeCursor(slot) then return true end
        return false, string.format(L("TOY_NOT_PLACEABLE"), itemID, slot)
    end

    pickupItem(itemID)
    if placeCursor(slot) then return true end
    return false, string.format(L("ITEM_NOT_IN_BAG"), itemID, slot)
end

HANDLERS.toy = function(slot, idStr, extra)
    local itemID   = tonumber(idStr)
    local itemName = (extra ~= "" and extra:gsub("||", "|")) or nil
    local validID  = itemID and itemID > 0

    if validID and placeToyViaToyBox(slot, itemID) then return true end
    if itemName then
        pickupItem(itemName)
        if placeCursor(slot) then return true end
    end
    if validID then
        pickupItem(itemID)
        if placeCursor(slot) then return true end
    end
    return false, string.format(L("TOY_NOT_PLACEABLE"), itemID or 0, slot)
end

HANDLERS.summonmount = function(slot, idStr)
    local mountID = tonumber(idStr)
    if not mountID then return nil end

    if mountID == RANDOM_MOUNT_ID then
        C_MountJournal.Pickup(0)
        if placeCursor(slot) then return true end
        return nil
    end

    -- Only mounts this character actually has in its journal
    local mountIDs = C_MountJournal and C_MountJournal.GetMountIDs()
    if mountIDs then
        for _, mID in ipairs(mountIDs) do
            if mID == mountID then
                if placeMount(slot, mID) then return true end
                break
            end
        end
    end
    return false, string.format(L("MOUNT_NOT_FOUND"), mountID, slot)
end

local function importPet(slot, idStr, extra)
    local speciesID = tonumber(idStr)
    local picked    = false
    if speciesID and C_PetJournal then
        C_PetJournal.ClearSearchFilter()
        for pi = 1, C_PetJournal.GetNumPets() do
            local petGUID, species = C_PetJournal.GetPetInfoByIndex(pi)
            if species == speciesID and petGUID then
                C_PetJournal.PickupPet(petGUID)
                picked = true
                break
            end
        end
    end
    if picked and placeCursor(slot) then return true end
    local petName = (extra ~= "" and extra:gsub("||", "|")) or tostring(speciesID)
    return false, string.format(L("PET_NOT_FOUND"), petName, slot)
end
HANDLERS.companion = importPet
HANDLERS.summonpet = importPet

HANDLERS.macro = function(slot, idStr)
    local macroName  = idStr:gsub("||", "|")
    local macroIndex

    if macroName:sub(1, 7) == "~body~" then
        -- Macro was exported by the start of its body (name unavailable)
        local globalMacros, charMacros = GetNumMacros()
        local totalMacros = (globalMacros or 0) + (charMacros or 0)
        local bodyPrefix  = macroName:sub(8)
        for mi = 1, totalMacros do
            local _, _, body = GetMacroInfo(mi)
            if body and body:sub(1, #bodyPrefix) == bodyPrefix then
                macroIndex = mi
                break
            end
        end
    else
        macroIndex = GetMacroIndexByName(macroName)
    end

    if not (macroIndex and macroIndex > 0) then
        return false, string.format(L("MACRO_NOT_FOUND"), macroName, slot)
    end
    PickupMacro(macroIndex)
    if placeCursor(slot) then return true end
    return false
end

HANDLERS.equipmentset = function(slot, idStr)
    for s = 1, C_EquipmentSet.GetNumEquipmentSets() do
        local name, _, setID = C_EquipmentSet.GetEquipmentSetInfo(s)
        if name == idStr then
            PickupEquipmentSet(setID)
            if placeCursor(slot) then return true end
            break
        end
    end
    return false, string.format(L("EQSET_NOT_FOUND"), idStr)
end

-- ----------------------------------------------------------
-- Import
-- ----------------------------------------------------------
function SlotPort:Import(str)
    if not str or str:match("^%s*$") then
        return false, L("EMPTY_STRING")
    end

    if InCombatLockdown() then
        return false, L("IN_COMBAT")
    end

    -- Decode SP3 format if needed
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, 5) == "!SP3!" then
        local decoded, err = SlotPort.DecodeFromExport(str)
        if not decoded then
            return false, L("INVALID_FORMAT") .. (err and (" (" .. err .. ")") or "")
        end
        str = decoded
    end

    -- Header check (trim leading whitespace for robustness)
    local header = str:match("^%s*([^\n|]+)")
    if header ~= "SLOTPORT:v1" then
        return false, L("INVALID_FORMAT")
    end

    local imported = 0
    local skipped  = 0
    local errors   = {}

    -- Build mount cache once (spellID -> mountID)
    SlotPort.petSpellCache = nil
    local ctx = { mountCache = SlotPort.buildMountSpellCache() }

    local maxSlot = 120
    for _, bar in ipairs(SlotPort.BARS) do
        if bar.endSlot > maxSlot then maxSlot = bar.endSlot end
    end

    -- Split the string (pipe-aware, also supports the newline format)
    local entries = SlotPort.SplitEntries(str)

    for i = 2, #entries do
        local entry = entries[i]

        -- Format: slot:type:id:extra  (extra may be empty)
        local slotStr, actionType, idStr, extra = entry:match("^(%d+):([^:]*):([^:]*):(.*)$")
        if not slotStr then
            slotStr, actionType, idStr = entry:match("^(%d+):([^:]*):([^:]*)$")
            extra = ""
        end

        local slot = tonumber(slotStr)

        if not slot or slot < 1 or slot > maxSlot then
            skipped = skipped + 1
            if slotStr then
                table.insert(errors, string.format(L("INVALID_SLOT"), tostring(slotStr)))
            end
        else
            local handler = HANDLERS[actionType]
            local isElvUIType = actionType and actionType:sub(1, 6) == "elvui_"
            if isElvUIType and not handler then
                -- Unknown ElvUI-prefixed type
                skipped = skipped + 1
                table.insert(errors, string.format(L("UNKNOWN_ELVUI_TYPE"), actionType:sub(7), slot))
            elseif not handler then
                skipped = skipped + 1
            else
                -- pcall: an error in one slot doesn't abort the rest.
                local ok, result, message = pcall(handler, slot, idStr, extra, ctx)
                if not ok then
                    local errMsg = tostring(result or "unknown error")
                    errMsg = errMsg:match("([^\n]+)") or errMsg
                    table.insert(errors, string.format("Slot %d: %s", slot, errMsg))
                    skipped = skipped + 1
                elseif result == true then
                    imported = imported + 1
                elseif result == false then
                    skipped = skipped + 1
                    if message then table.insert(errors, message) end
                end
            end
        end
    end

    local msg
    if imported == 0 and skipped > 0 then
        msg = string.format(L("IMPORTED_ZERO_HINT"), skipped)
    else
        msg = string.format(L("IMPORTED"), imported)
        if skipped > 0 then
            msg = msg .. string.format(L("SKIPPED"), skipped)
        end
    end
    if #errors > 0 then
        local displayErrors = errors
        local extra = 0
        if #errors > 10 then
            displayErrors = {}
            for i = 1, 10 do displayErrors[i] = errors[i] end
            extra = #errors - 10
        end
        msg = msg .. L("HINTS_PREFIX") .. table.concat(displayErrors, "\n")
        if extra > 0 then
            msg = msg .. string.format("\n(... %d %s)", extra, L("MORE_ERRORS"))
        end
    end

    return true, msg
end

-- ----------------------------------------------------------
-- Imports pasted text holding a slots part, a macros part, or both
-- (optionally !SP3!-compressed). Macros are imported first so slots that
-- reference them can find them.
-- Returns a list of { kind = "macros"|"slots", ok = bool, msg = string },
-- or nil plus an error message if nothing importable was found.
-- ----------------------------------------------------------
function SlotPort.ImportString(raw)
    if not raw or raw:match("^%s*$") then
        return nil, L("EMPTY_STRING")
    end

    local macroPart, slotPart
    for _, line in ipairs(SlotPort.SplitImportParts(raw)) do
        local content = line
        if line:sub(1, 5) == "!SP3!" then
            content = SlotPort.DecodeFromExport(line) or ""
        end
        if content:sub(1, 14) == "SLOTPORTMACRO:" then
            macroPart = line
        elseif content:sub(1, 9) == "SLOTPORT:" then
            slotPart = line
        end
    end

    if not macroPart and not slotPart then
        return nil, L("INVALID_FORMAT")
    end

    local results = {}
    if macroPart then
        local ok, msg = SlotPort:ImportMacros(macroPart)
        results[#results + 1] = { kind = "macros", ok = ok, msg = tostring(msg) }
    end
    if slotPart then
        local ok, msg = SlotPort:Import(slotPart)
        results[#results + 1] = { kind = "slots", ok = ok, msg = tostring(msg) }
    end
    return results
end
