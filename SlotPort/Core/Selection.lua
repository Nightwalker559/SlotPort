-- ============================================================
-- Slot selection and clearing of the selected slots
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

-- ----------------------------------------------------------
-- Slot selection
-- ----------------------------------------------------------
function SlotPort:ToggleSlot(slot)
    self.selectedSlots[slot] = not self.selectedSlots[slot] or nil
end


function SlotPort:ToggleBar(barIndex, selected)
    local bar = self.BARS[barIndex]
    if not bar then return end
    for slot = bar.startSlot, bar.endSlot do
        self.selectedSlots[slot] = selected or nil
    end
end

-- Set ([slot] = true) of every slot on a bar worth exporting. Every registered
-- bar is always shown as a row (dimmed, not hidden, when disabled - see
-- UI/GUI.lua), so a disabled-but-populated bar is just as selectable as an
-- active one. Only bars with nothing on them are skipped.
function SlotPort:CollectAllSlots()
    local slots = {}
    for _, bar in ipairs(self.BARS) do
        if bar.alwaysShow or bar.isSkyriding or bar.hasContent then
            for slot = bar.startSlot, bar.endSlot do
                slots[slot] = true
            end
        end
    end
    return slots
end

function SlotPort:SelectAll()
    for slot in pairs(self:CollectAllSlots()) do
        self.selectedSlots[slot] = true
    end
end

function SlotPort:DeselectAll()
    wipe(self.selectedSlots)
end

function SlotPort:GetSelectedCount()
    local count = 0
    for _ in pairs(self.selectedSlots) do count = count + 1 end
    return count
end

function SlotPort:IsBarFullySelected(barIndex)
    local bar = self.BARS[barIndex]
    if not bar then return false end
    for slot = bar.startSlot, bar.endSlot do
        if not self.selectedSlots[slot] then return false end
    end
    return true
end

-- ----------------------------------------------------------
-- Reset (clear) all selected action bar slots
-- ----------------------------------------------------------
function SlotPort:ResetSelectedSlots()
    if InCombatLockdown() then
        return false, L("IN_COMBAT")
    end

    local slots = {}
    for slot in pairs(self.selectedSlots) do
        slots[#slots + 1] = slot
    end

    if #slots == 0 then
        return false, L("NO_SLOTS_SEL")
    end

    local cleared = 0
    for _, slot in ipairs(slots) do
        PickupAction(slot)
        if GetCursorInfo() then
            ClearCursor()
            cleared = cleared + 1
        else
            ClearCursor()
        end
    end

    self:DeselectAll()
    return true, cleared
end

-- Removes any selectedSlots entries that don't fall within the range of a
-- currently-registered bar. Called after self.BARS changes (bar removed/
-- disabled) so the selection count always matches what Export() will
-- actually process. See RefreshElvUIBars.
function SlotPort:PruneOrphanedSelections()
    local orphaned = {}
    for slot in pairs(self.selectedSlots) do
        local covered = false
        for _, bar in ipairs(self.BARS) do
            if slot >= bar.startSlot and slot <= bar.endSlot then
                covered = true
                break
            end
        end
        if not covered then
            orphaned[#orphaned + 1] = slot
        end
    end
    for _, slot in ipairs(orphaned) do
        self.selectedSlots[slot] = nil
    end
    return #orphaned
end
