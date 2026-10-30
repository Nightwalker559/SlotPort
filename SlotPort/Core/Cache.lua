-- ----------------------------------------------------------
-- Spellbook iteration (Player OR Pet)
--
-- IMPORTANT: C_SpellBook.GetNumSpellBookItemsForSpellBank() unreliably
-- returns 0 in Midnight 12.0 - this is NOT the correct API to list
-- all spellbook entries. The correct method is iterating skill lines
-- (see Blizzard_APIDocumentation / warcraft.wiki.gg):
--   GetNumSpellBookSkillLines() -> number of skill lines (tabs)
--   GetSpellBookSkillLineInfo(i).itemIndexOffset / .numSpellBookItems
--     -> offset + slot count of that skill line
-- The pet bank has no skill-line concept; the direct 1..N scan
-- remains correct there (HasPetSpells returns the count).
-- ----------------------------------------------------------

-- Iterates all spellbook items of a bank and calls callback(slotIndex, info).
-- Stops early if the callback returns true (for early-exit searches).
function SlotPort.ForEachSpellBookItem(bank, callback)
    if not C_SpellBook or not Enum or not Enum.SpellBookSpellBank then return end

    if bank == Enum.SpellBookSpellBank.Pet then
        -- Pet bank: no skill-line concept, direct scan
        local count = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells() or 0
        for i = 1, count do
            local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
            if info and callback(i, info) then return end
        end
        return
    end

    -- Player bank: iterate via skill lines (correct API)
    if not C_SpellBook.GetNumSpellBookSkillLines then return end
    local numLines = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for line = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo and lineInfo.itemIndexOffset and lineInfo.numSpellBookItems then
            local offset, numSlots = lineInfo.itemIndexOffset, lineInfo.numSpellBookItems
            for slot = offset + 1, offset + numSlots do
                local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if info and callback(slot, info) then return end
            end
        end
    end
end

-- ----------------------------------------------------------
-- Pet spell cache
-- actionID for pet spells is a packed value.
-- Real SpellID = bit.band(actionID, 0xFFFFFF)
-- ----------------------------------------------------------
SlotPort.petSpellCache = nil

local function buildPetSpellCache()
    SlotPort.petSpellCache = {}
    if not Enum or not Enum.SpellBookSpellBank then return end
    SlotPort.ForEachSpellBookItem(Enum.SpellBookSpellBank.Pet, function(i, info)
        local rawID   = info.actionID or info.spellID or 0
        local spellID = bit.band(rawID, 0xFFFFFF)
        if spellID and spellID > 0 then
            SlotPort.petSpellCache[spellID] = i
        end
        return false
    end)
end

function SlotPort.isPetSpell(spellID)
    if not spellID then return false end
    if SlotPort.petSpellCache == nil then buildPetSpellCache() end
    return SlotPort.petSpellCache[spellID] ~= nil
end

function SlotPort.getPetSpellIndex(spellID)
    if SlotPort.petSpellCache == nil then buildPetSpellCache() end
    return SlotPort.petSpellCache and SlotPort.petSpellCache[spellID]
end

-- Base spell of a form/talent variant. GetActionInfo reports the variant that
-- is active right now (cat form: Wild Charge 49376 instead of 102401), which
-- only exists on a character while it is in that form; the spellbook and
-- PickupSpell work with the base spell. Unchanged when the API is missing.
function SlotPort.baseSpellID(spellID)
    local book = C_SpellBook
    if not (spellID and book and book.FindBaseSpellByID) then return spellID end
    return book.FindBaseSpellByID(spellID) or spellID
end

-- Searches for a SpellID/FlyoutID/ActionID in the player's spellbook (all skill lines).
-- Returns slotIndex or nil.
function SlotPort.findPlayerSpellBookSlot(id)
    if not id or not Enum or not Enum.SpellBookSpellBank then return nil end
    local found = nil
    SlotPort.ForEachSpellBookItem(Enum.SpellBookSpellBank.Player, function(slot, info)
        if info.spellID == id or info.actionID == id then
            found = slot
            return true
        end
        return false
    end)
    return found
end

-- ----------------------------------------------------------
-- Mount cache: spellID -> mountID
-- ----------------------------------------------------------
function SlotPort.buildMountSpellCache()
    local cache = {}
    if not C_MountJournal then return cache end
    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return cache end
    for _, mountID in ipairs(mountIDs) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        if spellID and type(spellID) == "number" and spellID > 0 then
            cache[spellID] = mountID
        end
    end
    return cache
end

-- Determine the displayIndex for C_MountJournal.Pickup(displayIndex) from a mountID
function SlotPort.getMountDisplayIndex(mountID)
    if not C_MountJournal then return nil end
    C_MountJournal.SetSearch("")
    local numMounts = C_MountJournal.GetNumDisplayedMounts()
    for mi = 1, numMounts do
        if C_MountJournal.GetDisplayedMountID(mi) == mountID then
            return mi
        end
    end
    return nil
end

-- ----------------------------------------------------------
-- True if the item ID is a toy the player owns
-- ----------------------------------------------------------
function SlotPort.IsToy(itemID)
    if not itemID then return false end
    return (PlayerHasToy and PlayerHasToy(itemID))
        or (C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(itemID))
        or false
end
