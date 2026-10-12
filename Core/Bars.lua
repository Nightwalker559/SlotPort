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

-- True if any of the first `count` buttons of an ElvUI bar holds an action
local function elvuiBarHasContent(barNum, count)
    for s = 1, count do
        local btnType = SlotPort:GetElvUIButtonInfo(barNum, s)
        if btnType and btnType ~= "empty" then return true end
    end
    return false
end

-- ElvUI bars 7-10 that fall back to Blizzard's Form/stance slots instead of
-- real ElvUI button data (see DetectElvUIBars)
local function isFormFallbackBar(fixedSlot, elvuiBarNum)
    return fixedSlot and elvuiBarNum >= 7 and elvuiBarNum <= 10
end

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

    -- Register dragonriding bar only once. Inserted right after the last
    -- bar with endSlot <= 120 (i.e. after Form 4) so it stays in physical
    -- slot order: Bars 1-6 -> Form 1-4 -> Skyriding (121-132) -> Bonus Bar 6
    -- (133-144). A plain table.insert (append) used to place it at the very
    -- end of the array instead, after Bonus Bar 6 - wrong order.
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
            local insertPos = #self.BARS + 1
            for i, bar in ipairs(self.BARS) do
                if bar.endSlot <= 120 then insertPos = i + 1 end
            end
            table.insert(self.BARS, insertPos, {
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
    -- Correct physical slot order: Bar 1-6 -> Form 1-4 -> Skyriding ->
    -- Bonus Bar 6 -> Action Bar 6-8. Appended at the end of the current
    -- list (Skyriding/Bonus Bar 6 are already registered by this point)
    -- rather than right after Bar 6, which used to push Form 1-4/Skyriding/
    -- Bonus Bar 6 further down instead of keeping them right after Bar 6.
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

-- ----------------------------------------------------------
-- ElvUI helper functions
-- ----------------------------------------------------------

-- Checks whether an ElvUI bar is active in the ElvUI settings
local function IsElvUIBarEnabled(barNum)
    if ElvUI and ElvUI[1] then
        local db = ElvUI[1].db
        if db and db.actionbar and db.actionbar["bar" .. barNum] then
            return db.actionbar["bar" .. barNum].enabled == true
        end
    end
    local btn = _G["ElvUI_Bar" .. barNum .. "Button1"]
    if btn then
        local parent = btn:GetParent()
        return parent and parent:IsShown() or false
    end
    return false
end

-- Determine the actual displayed slot count via the ElvUI DB
local function GetElvUIBarSlotCount(barNum)
    if ElvUI and ElvUI[1] and ElvUI[1].db and ElvUI[1].db.actionbar then
        local cfg = ElvUI[1].db.actionbar["bar" .. barNum]
        if cfg and cfg.buttons and tonumber(cfg.buttons) then
            return tonumber(cfg.buttons)
        end
    end
    local count = 0
    for s = 1, 12 do
        if _G["ElvUI_Bar" .. barNum .. "Button" .. s] then
            count = count + 1
        else
            break
        end
    end
    return count
end

-- ----------------------------------------------------------
-- ElvUI Custom Bar Detection (Bars 7-15 = extra/custom bars beyond
-- the base 6 - bars 7-12 come from ElvUI itself or ElvUI_ExtraActionBars,
-- bars 13-15 are the Midnight-era Action Bar 6/7/8 equivalents, which sit
-- at a fixed, known Blizzard slot (marked `fixedSlot` below) so their
-- content can be read directly instead of via ElvUI's own button data.
-- Bars 7-10 ALSO have a well-known fallback slot (73/85/97/109, Blizzard's
-- Form/stance action pages) - unlike 13-15 this is applied even when
-- ElvUI's own bar 7-10 button frame doesn't exist at all, since many ElvUI
-- profiles never configure those bar numbers even though the underlying
-- Form/stance content (for Druids, Rogues, etc.) is always there. Real
-- ElvUI button data is still preferred over the fallback when available.
-- (An earlier attempt at this looked broken - turned out RefreshAllSlots
-- was skipping icon refresh for disabled bars entirely, unrelated to how
-- the content was read; see UI/GUI.lua RefreshAllSlots.)
-- ----------------------------------------------------------
function SlotPort:DetectElvUIBars()
    if not self:HasElvUI() then return end

    -- Step 1: determine slot base for each bar by reading it directly off
    -- the bar's first button. No cross-bar extrapolation for 7-12: their
    -- slot range isn't guaranteed to follow a fixed arithmetic step from
    -- bar to bar, so guessing here risks registering the wrong slots.
    local barSlots = {}
    for barNum = 7, 15 do
        local btn = _G["ElvUI_Bar" .. barNum .. "Button1"]
        if btn then
            local slot = tonumber(btn:GetAttribute("action"))
            if not slot then
                local state = btn:GetAttribute("state")
                if state then slot = tonumber(btn:GetAttribute("labaction-" .. state)) end
            end
            if slot then barSlots[barNum] = slot end
        end
    end

    -- Step 2: fall back to a well-known slot when ElvUI's own button data
    -- didn't give us one. Bars 13-15 map to Blizzard's MultiBar5/6/7
    -- ("Action Bar 6/7/8"); bars 7-10 map to Blizzard's Form/stance pages.
    -- For 13-15 this only kicks in when the button frame exists but its
    -- attributes aren't populated yet (not toggled on this session). For
    -- 7-10 it applies even with NO button frame at all - many ElvUI setups
    -- never configure those bar numbers, but the Form/stance content is
    -- always there for classes that have it, so the bar should still show.
    -- `usedFallback` tracks this per bar so Step 3 only treats it as a
    -- direct-read fixed slot when the fallback was actually used - if a
    -- real ElvUI bar 7-10 IS configured, its actual content is preferred.
    local KNOWN_ELVUI_SLOT = { [7] = 73, [8] = 85, [9] = 97, [10] = 109, [13] = 145, [14] = 157, [15] = 169 }
    local usedFallback = {}
    for barNum, slot in pairs(KNOWN_ELVUI_SLOT) do
        if not barSlots[barNum]
           and (barNum <= 10 or _G["ElvUI_Bar" .. barNum .. "Button1"]) then
            barSlots[barNum] = slot
            usedFallback[barNum] = true
        end
    end

    -- Step 3: register - as long as the bar's buttons actually exist (or,
    -- for 7-10, the Form/stance fallback applied). Not gated on
    -- IsElvUIBarEnabled(): ElvUI's "enabled" checkbox only controls
    -- whether the bar is drawn on screen, not whether its content/keybinds
    -- work - a player can have a fully-populated bar with "enabled"
    -- unchecked. isEnabled is still recorded below so the GUI can dim it,
    -- consistent with how bars 1-6 are handled.
    for barNum = 7, 15 do
        local baseSlot = barSlots[barNum]
        if baseSlot then

            local alreadyRegistered = false
            for _, bar in ipairs(self.BARS) do
                if bar.elvuiBarNum == barNum then alreadyRegistered = true; break end
            end

            if not alreadyRegistered then
                -- Only a genuine fixed-slot read when the fallback was used
                -- (13-15 always use it when registered at all; 7-10 only
                -- when no real ElvUI bar data was found for them).
                local isFixedSlot = usedFallback[barNum] == true
                local slotCount = isFixedSlot and 12 or GetElvUIBarSlotCount(barNum)
                if slotCount == 0 then slotCount = 5 end

                -- Known Blizzard slot: read it directly, same as Bar 1-6
                -- (doesn't depend on ElvUI's button/attribute state).
                local hasContent
                if isFixedSlot then
                    hasContent = slotRangeHasContent(baseSlot, baseSlot + slotCount - 1)
                else
                    hasContent = elvuiBarHasContent(barNum, slotCount)
                end

                -- Under ElvUI only ElvUI's own numbering is used ("Bar 7");
                -- the Blizzard/class form names are a Default UI label only
                -- (RefreshBarContent, bar.isFormBar).
                local name = string.format(L("BAR_ELVUI_FMT"), barNum)

                local newBar = {
                    name        = name,
                    startSlot   = baseSlot,
                    endSlot     = baseSlot + slotCount - 1,
                    isElvUI     = true,
                    fixedSlot   = isFixedSlot,
                    elvuiBarNum = barNum,
                    -- Every ElvUI bar (also 7-10 on the Form/stance
                    -- fallback) is active only if ElvUI has it enabled, same
                    -- as bars 1-6; inactive ones are dimmed in the GUI.
                    isEnabled   = IsElvUIBarEnabled(barNum),
                    hasContent  = hasContent,
                }

                -- Find the correct position: after the last ElvUI bar with a lower number,
                -- or after the last non-ElvUI bar if no ElvUI bar exists yet.
                local insertPos = #self.BARS + 1
                for i = #self.BARS, 1, -1 do
                    local b = self.BARS[i]
                    if b.isElvUI and b.elvuiBarNum < barNum then
                        insertPos = i + 1
                        break
                    elseif not b.isElvUI then
                        insertPos = i + 1
                        break
                    end
                end
                table.insert(self.BARS, insertPos, newBar)

                if SlotPortGUI then
                    SlotPortGUI:AppendLog("ElvUI", string.format(
                        L("ELVUI_BAR_DETECTED"), barNum, baseSlot, baseSlot + slotCount - 1, slotCount))
                end
            end
        end
    end

    self:SortBars()
end

-- ----------------------------------------------------------
-- Dynamic bar refresh
-- ----------------------------------------------------------
function SlotPort:RefreshElvUIBars()
    local removedAny = false
    local i = 1
    while i <= #self.BARS do
        local bar = self.BARS[i]
        if bar.isElvUI then
            -- Only drop the bar if its buttons are actually gone (e.g. profile
            -- switch removed the custom bar entirely). A merely-disabled bar
            -- ("enabled" unchecked in ElvUI) keeps its content/keybinds
            -- working and stays registered, just dimmed - see DetectElvUIBars.
            -- Bars 7-10 using the Form/stance fallback (fixedSlot, no real
            -- ElvUI button data) never depend on the frame existing at all,
            -- so they're never dropped for that reason.
            local isFallbackFormBar = isFormFallbackBar(bar.fixedSlot, bar.elvuiBarNum)
            local stillExists = isFallbackFormBar or
                _G["ElvUI_Bar" .. bar.elvuiBarNum .. "Button1"] ~= nil
            if not stillExists then
                table.remove(self.BARS, i)
                removedAny = true
            else
                bar.isEnabled = IsElvUIBarEnabled(bar.elvuiBarNum)
                if bar.fixedSlot then
                    bar.hasContent = slotRangeHasContent(bar.startSlot, bar.endSlot)
                else
                    bar.hasContent = elvuiBarHasContent(bar.elvuiBarNum, bar.endSlot - bar.startSlot + 1)
                end
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    self:DetectElvUIBars()
    -- A removed bar can leave its previously-selected slots orphaned in
    -- selectedSlots (no current bar covers that range anymore). These are
    -- invisible in the grid (their row is gone) but still counted by
    -- GetSelectedCount(), causing "X selected" to exceed what Export()
    -- actually processes (which only iterates currently-registered bars).
    if removedAny then
        self:PruneOrphanedSelections()
    end
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

-- ----------------------------------------------------------
-- Auto-refresh: hooks on ElvUI bar frames and the ElvUI module
-- ----------------------------------------------------------
local function getEnabledState()
    local state = {}
    for i, bar in ipairs(SlotPort.BARS) do
        state[i] = bar.isEnabled
    end
    return state
end

local function enabledStateChanged(before, after)
    if #before ~= #after then return true end
    for i = 1, #before do
        if before[i] ~= after[i] then return true end
    end
    return false
end

function SlotPort:SetupElvUIWatchers()
    if not self:HasElvUI() then return end

    local pending = false
    local function onBarChanged()
        -- Coalesce bursts (ElvUI shows/hides several bars at once) into one refresh
        if pending then return end
        pending = true
        RunNextFrame(function()
            pending = false
            -- ElvUI bar frames must not be touched during combat lockdown
            if InCombatLockdown() then return end

            local stateBefore = getEnabledState()
            SlotPort:RefreshBarContent()
            SlotPort:RefreshElvUIBars()
            local stateAfter = getEnabledState()

            if enabledStateChanged(stateBefore, stateAfter) and SlotPortGUI.mainFrame then
                SlotPortGUI:RebuildGrid()
            elseif SlotPortGUI.mainFrame and SlotPortGUI.mainFrame:IsShown() then
                SlotPortGUI:RefreshAllSlots()
            end
        end)
    end

    -- Guarded per-frame/per-function so re-running this on every zone
    -- change (PLAYER_ENTERING_WORLD calls this on every loading screen,
    -- not just once at login) doesn't stack duplicate OnShow/OnHide hooks
    -- on the same persistent frame - onBarChanged would otherwise fire
    -- once per accumulated hook layer for a single real change.
    for barNum = 7, 15 do
        local btn = _G["ElvUI_Bar" .. barNum .. "Button1"]
        if btn then
            local parent = btn:GetParent()
            if parent and not parent._spHookedShowHide then
                parent._spHookedShowHide = true
                parent:HookScript("OnShow", onBarChanged)
                parent:HookScript("OnHide", onBarChanged)
            end
        end
    end

    if ElvUI and ElvUI[1] and not SlotPort._elvUIPositionHookSet then
        local ok, AB = pcall(function() return ElvUI[1]:GetModule("ActionBars") end)
        if ok and AB and AB.PositionAndSizeBar then
            SlotPort._elvUIPositionHookSet = true
            hooksecurefunc(AB, "PositionAndSizeBar", onBarChanged)
        end
    end
end

-- ----------------------------------------------------------
-- Third-party detection (12.0: C_AddOns API)
-- ----------------------------------------------------------
function SlotPort:IsAddonLoaded(name)
    return C_AddOns.IsAddOnLoaded(name) == true
end

function SlotPort:HasBartender4()
    return self:IsAddonLoaded("Bartender4")
end

function SlotPort:HasElvUI()
    return self:IsAddonLoaded("ElvUI")
end

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

function SlotPort:SelectAll()
    for _, bar in ipairs(self.BARS) do
        -- Every registered bar is always shown as a row (dimmed, not
        -- hidden, when disabled - see UI/GUI.lua), so a
        -- disabled-but-populated bar is just as selectable as an active
        -- one. Only skip bars with nothing to select.
        local shown = bar.alwaysShow or bar.isSkyriding or bar.hasContent
        if shown then
            for slot = bar.startSlot, bar.endSlot do
                self.selectedSlots[slot] = true
            end
        end
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

-- ----------------------------------------------------------
-- Read ElvUI button attributes
-- ----------------------------------------------------------
local LAB_STATES = { "default", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }

function SlotPort:GetElvUIButtonInfo(elvuiBarNum, buttonIndex)
    local btn = _G["ElvUI_Bar" .. elvuiBarNum .. "Button" .. buttonIndex]
    if not btn then return nil, nil end

    local function tryLAB(s)
        local t = btn:GetAttribute("labtype-"   .. s)
        local a = btn:GetAttribute("labaction-" .. s)
        if t and t ~= "empty" and a ~= nil then return t, a end
    end

    local btnType, btnAction
    local currentState = btn:GetAttribute("state")
    if currentState then
        btnType, btnAction = tryLAB(currentState)
    end
    if not btnType then
        for _, s in ipairs(LAB_STATES) do
            btnType, btnAction = tryLAB(s)
            if btnType then break end
        end
    end

    if not btnType then
        local nativeType = btn:GetAttribute("type")
        if nativeType == "spell" then
            btnType, btnAction = "spell", btn:GetAttribute("spell")
        elseif nativeType == "item" then
            btnType, btnAction = "item", btn:GetAttribute("item")
        elseif nativeType == "macro" then
            local macroName = btn:GetAttribute("macro-name") or btn:GetAttribute("macroname")
            local macroText = btn:GetAttribute("macrotext")
            if macroName then
                local idx = GetMacroIndexByName(macroName)
                if idx and idx > 0 then
                    btnType, btnAction = "macro", idx
                end
            elseif macroText then
                btnType, btnAction = "macro_text", macroText
            end
        end
    end

    if not btnType then return nil, nil end

    if btnType == "action" then
        local slotID = tonumber(btnAction)
        if slotID then
            local realType, realID = GetActionInfo(slotID)
            if realType then return realType, realID end
        end
        return nil, nil
    end

    return btnType, btnAction
end

-- Icon texture of an ElvUI button
function SlotPort:GetElvUIButtonTexture(elvuiBarNum, buttonIndex)
    local btnType, btnAction = self:GetElvUIButtonInfo(elvuiBarNum, buttonIndex)
    if not btnType then return nil end

    if btnType == "spell" and btnAction then
        return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tonumber(btnAction))
    elseif btnType == "item" and btnAction then
        return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(tonumber(btnAction))
    elseif btnType == "macro" and btnAction then
        local _, tex = GetMacroInfo(btnAction)
        return tex
    elseif btnType == "action" and btnAction then
        return GetActionTexture(tonumber(btnAction))
    end

    return nil
end

