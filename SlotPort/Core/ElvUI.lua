-- ============================================================
-- Third-party detection and ElvUI support: ElvUI bar detection (bars 7-15),
-- the watchers that keep the bar list in sync with ElvUI, and reading the
-- content of ElvUI buttons.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

local slotRangeHasContent = SlotPort.slotRangeHasContent

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

