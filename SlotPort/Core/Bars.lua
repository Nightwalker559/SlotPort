-- ============================================================
-- Bar list: which action bars exist, their names, whether they are enabled
-- and hold content. Selection lives in Selection.lua, ElvUI support in ElvUI.lua.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

-- Frame names of the default Blizzard bars in Midnight 12.0
-- barNum = math.ceil(startSlot / 12)
-- Blizzard's action pages are NOT sequential to its bar frames (confirmed
-- against the current retail action-bar page mapping) - page 2 (slots 13-24)
-- has no dedicated frame, and pages 3-6 map to frames in reverse order:
--   Bar 1: nil (MainActionBar, slots 1-12, always visible)
--   Bar 2: nil (slots 13-24, action page 2, no separate Blizzard frame)
--   Bar 3: MultiBarRight       (slots 25-36, "Action Bar 4")
--   Bar 4: MultiBarLeft        (slots 37-48, "Action Bar 5")
--   Bar 5: MultiBarBottomRight (slots 49-60, "Action Bar 3")
--   Bar 6: MultiBarBottomLeft  (slots 61-72, "Action Bar 2")
-- Bar 7-10: class bonus bars (no frame -> always show if occupied)
-- Midnight new bars (Action Bar 6-8): barNum 13/14/15 -> MultiBar5/6/7
local BAR_FRAMES = {
    [1]  = nil,                   -- always visible
    [2]  = nil,                   -- slots 13-24, no dedicated frame -> always show
    [3]  = "MultiBarRight",       -- slots 25-36
    [4]  = "MultiBarLeft",        -- slots 37-48
    [5]  = "MultiBarBottomRight", -- slots 49-60
    [6]  = "MultiBarBottomLeft",  -- slots 61-72
    -- Slots 73-120: class bonus bars, no frame check
    -- Midnight new bars (slots 145-180):
    [13] = "MultiBar5",           -- slots 145-156
    [14] = "MultiBar6",           -- slots 157-168
    [15] = "MultiBar7",           -- slots 169-180
}

-- Bar frame for an action page (page == barNum). Blizzard's own page -> frame
-- lookup (MultiActionBar_GetBarForPage, Blizzard_ActionBar/MultiActionBars.lua)
-- is preferred so new bars are picked up automatically; BAR_FRAMES above is
-- only the fallback if that function is missing or not ready yet.
local function GetBarFrameForPage(page)
    if MultiActionBar_GetBarForPage then
        local ok, frame = pcall(MultiActionBar_GetBarForPage, page)
        if ok and frame then return frame end
    end
    local frameName = BAR_FRAMES[page]
    return frameName and _G[frameName] or nil
end

local function IsDefaultBarVisible(barIndex)
    local frame = GetBarFrameForPage(barIndex)
    if not frame then return true end      -- no frame (page 1/2) or unknown -> always show
    return frame:IsShown()
end

-- Bonus bar index of a slot and whether that bonus bar is the active one
-- (C_ActionBar.GetBonusBarIndexForSlot / GetBonusBarIndex - the same lookup
-- Blizzard uses to classify slots). nil when the API is missing or the slot
-- belongs to no bonus bar. Diagnostic only (/sp debug). Verified in-game:
-- pages 7-11 (slots 73-132) return their page number as bonus bar index,
-- pages 1-6 and 12-15 return nil - matching the hard-coded ranges.
function SlotPort.GetBonusBarState(slot)
    local api = C_ActionBar
    if not (api and api.GetBonusBarIndexForSlot) then return nil, nil end
    local idx = api.GetBonusBarIndexForSlot(slot)
    if not idx then return nil, nil end
    local current = api.GetBonusBarIndex and api.GetBonusBarIndex()
    return idx, idx == current
end

-- True if any slot in first..last holds an action that has an icon
local function slotRangeHasContent(first, last)
    for slot = first, last do
        if GetActionInfo(slot) and GetActionTexture(slot) then return true end
    end
    return false
end
SlotPort.slotRangeHasContent = slotRangeHasContent   -- also used by ElvUI.lua

-- Class Form/stance spell IDs for the Form 1-4 / ElvUI 7-10 bars, in slot
-- order. Retail only - Warrior stances, classic Rogue Shadow Dance, Priest
-- Shadowform and Warlock Metamorphosis are Classic-era-only bonus bars and
-- don't apply on the current Midnight 12.0 patch.
local CLASS_FORM_SPELLS = {
    DRUID = { 768, 5215, 5487, 24858 }, -- Cat Form, Prowl, Bear Form, Moonkin Form
    ROGUE = { 1784 },                   -- Stealth
}

-- Returns the localized spell name for the current class's Form/stance bar
-- at the given index (1-4), or nil if this class has no form there.
local function GetClassFormName(index)
    local _, classToken = UnitClass("player")
    local spells = classToken and CLASS_FORM_SPELLS[classToken]
    local spellID = spells and spells[index]
    if not spellID then return nil end
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
end

-- Keeps SlotPort.BARS in physical slot order (Bar 1-6, Bonus Bar 1-4,
-- Skyriding, Bonus Bar 6, Action Bar 6-8), whichever of the registration
-- paths (static list, Skyriding, Default UI 6-8, ElvUI bars) added them.
-- Stable: bars sharing a start slot keep their relative order.
function SlotPort:SortBars()
    local position = {}
    for i, bar in ipairs(self.BARS) do position[bar] = i end
    table.sort(self.BARS, function(a, b)
        if a.startSlot ~= b.startSlot then return a.startSlot < b.startSlot end
        return position[a] < position[b]
    end)
end

function SlotPort:RefreshBarContent()
    local hasElvUI = self:HasElvUI()
    local elvuiDB  = hasElvUI and ElvUI and ElvUI[1] and ElvUI[1].db

    -- Register dragonriding bar only once; SortBars (end of this function)
    -- puts it into physical slot order, between Form 4 and Bonus Bar 6.
    local hasSkyBar = false
    for _, bar in ipairs(self.BARS) do
        if bar.isSkyriding then hasSkyBar = true; break end
    end
    if not hasSkyBar then
        local skyContent = false
        for s = 121, 132 do
            if GetActionInfo(s) then skyContent = true; break end
        end
        if not skyContent and HasBonusActionBar and HasBonusActionBar() then
            skyContent = true
        end
        if skyContent then
            table.insert(self.BARS, {
                name        = L("SKYRIDING_BAR"),
                startSlot   = 121,
                endSlot     = 132,
                isSkyriding = true,
                isEnabled   = true,
                hasContent  = true,
            })
        end
    end

    -- Default UI Bars 145-180 only registered without ElvUI. These are
    -- Blizzard "Action Bar 6/7/8" (MultiBar5/6/7), not "7/8/9" - Blizzard's
    -- action-page-to-bar-name mapping isn't sequential (see BAR_FRAMES above).
    -- Appended here; SortBars restores the physical slot order.
    if not hasElvUI then
        local defaultBars = {
            { name = L("BAR_BLIZZ_13"), startSlot = 145, endSlot = 156, isDefaultBar = true },
            { name = L("BAR_BLIZZ_14"), startSlot = 157, endSlot = 168, isDefaultBar = true },
            { name = L("BAR_BLIZZ_15"), startSlot = 169, endSlot = 180, isDefaultBar = true },
        }
        for _, def in ipairs(defaultBars) do
            local alreadyAdded = false
            for _, bar in ipairs(self.BARS) do
                if bar.startSlot == def.startSlot then alreadyAdded = true; break end
            end
            if not alreadyAdded then
                table.insert(self.BARS, def)
            end
        end
    end

    -- Class Form/stance bars (73-120) are a Default-UI-only concept. Under
    -- ElvUI they're superseded by ElvUI's own Bar 7-10 - which are NOT
    -- guaranteed to sit at slots 73-120: ElvUI's per-bar stance/state
    -- paging can point a bar at a different underlying slot per state, so
    -- reading 73-120 directly showed nothing for setups that use that
    -- paging. Strip the static entries once ElvUI is active; DetectElvUIBars
    -- (below) reads the bar's real button data instead.
    if hasElvUI then
        for i = #self.BARS, 1, -1 do
            if self.BARS[i].isFormBar then
                table.remove(self.BARS, i)
            end
        end
    end

    for i, bar in ipairs(self.BARS) do
        if not bar.isElvUI and not bar.isSkyriding then
            local barNum = math.ceil(bar.startSlot / 12)

            -- Bars 1-6 sit on the same physical slots regardless of UI, but
            -- ElvUI's bar numbering and Blizzard's "Action Bar" naming don't
            -- match 1:1 (e.g. slots 61-72 = ElvUI "Bar 6" = Blizzard "Action
            -- Bar 2"). Pick the label that matches whichever UI is active.
            if barNum >= 1 and barNum <= 6 and not bar.isDefaultBar then
                bar.name = hasElvUI and L("BAR_ELVUI_" .. barNum) or L("BAR_BLIZZ_" .. barNum)
            elseif bar.isFormBar then
                -- Only present when NOT hasElvUI (stripped above otherwise)
                bar.name = GetClassFormName(barNum - 6) or L("BAR_FORM_" .. (barNum - 6))
            end

            if bar.alwaysShow then
                -- Bar 1 only (MainActionBar): always active
                bar.isEnabled = true
            elseif elvuiDB and elvuiDB.actionbar then
                -- ElvUI active: ElvUI DB decides for all bars
                local cfg = elvuiDB.actionbar["bar" .. barNum]
                if cfg ~= nil then
                    bar.isEnabled = cfg.enabled == true
                else
                    -- No DB entry -> default bar, always active
                    bar.isEnabled = true
                end
            elseif bar.isDefaultBar or (barNum >= 2 and barNum <= 6) then
                -- Default UI Action Bar 6-8 and bars 2-6: check frame visibility
                -- (bar 2 has no frame in BAR_FRAMES -> IsDefaultBarVisible
                -- falls back to "always show", which is correct for page 2)
                bar.isEnabled = IsDefaultBarVisible(barNum)
            else
                -- Class bonus bars and Bonus Bar 6 (Default UI): always enabled,
                -- hasContent decides whether they're shown
                bar.isEnabled = true
            end

            bar.hasContent = slotRangeHasContent(bar.startSlot, bar.endSlot)
        end
    end

    self:SortBars()
end
