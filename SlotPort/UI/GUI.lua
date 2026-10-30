-- ============================================================
-- Main window: sidebar, bars page (bar cards with slot buttons), log page,
-- export/import footer. The macros and characters pages live in
-- MacroPage.lua and CharsPage.lua.
-- ============================================================

-- Locale access
local function L(key) return (SlotPortL and SlotPortL[key]) or key end


SlotPortGUI = {}

-- ----------------------------------------------------------
-- Confirmation popups for destructive actions
-- ----------------------------------------------------------
StaticPopupDialogs["SLOTPORT_CONFIRM_RESET_SLOTS"] = {
    text         = "",
    button1      = YES,
    button2      = NO,
    OnAccept     = function()
        local ok, result = SlotPort:ResetSelectedSlots()
        if ok then
            SlotPortGUI:AppendLog(L("RESET_SLOTS_BTN"), string.format(L("RESET_SLOTS_DONE"), result), false)
            SlotPortGUI:RefreshAllSlots()
        else
            SlotPortGUI:AppendLog(L("RESET_SLOTS_BTN"), tostring(result), true)
        end
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SLOTPORT_CONFIRM_DELETE_MACROS"] = {
    text         = "",
    button1      = YES,
    button2      = NO,
    OnAccept     = function()
        local ok, result = SlotPort:DeleteSelectedMacros()
        if ok then
            SlotPortGUI:AppendLog(L("DELETE_MACROS_BTN"), string.format(L("DELETE_MACROS_DONE"), result), false)
        else
            SlotPortGUI:AppendLog(L("DELETE_MACROS_BTN"), tostring(result), true)
        end
        SlotPortMacroGUI:RebuildList()
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Export: shows the export string pre-filled and highlighted, ready for Ctrl+C.
-- data (3rd arg to StaticPopup_Show) is the export string.
StaticPopupDialogs["SLOTPORT_EXPORT"] = {
    text         = L("EXPORT_POPUP_TEXT"),
    button1      = OKAY,
    hasEditBox   = true,
    editBoxWidth = 350,
    maxLetters   = 0,
    OnShow = function(self, data)
        local editBox = self:GetEditBox()
        editBox:SetText((data or ""):gsub("|", "||"))
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed  = function(self) self:GetParent():Hide() end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Import: empty editbox, paste and confirm. Auto-detects SLOTPORT: /
-- SLOTPORTMACRO: (optionally !SP3!-compressed); slots and macros may be pasted together.
StaticPopupDialogs["SLOTPORT_IMPORT"] = {
    text         = L("IMPORT_POPUP_TEXT"),
    button1      = L("IMPORT_BTN"),
    button2      = CANCEL,
    hasEditBox   = true,
    editBoxWidth = 350,
    maxLetters   = 0,
    OnShow = function(self)
        local editBox = self:GetEditBox()
        editBox:SetText("")
        editBox:SetFocus()
    end,
    OnAccept = function(self)
        local raw = (self:GetEditBox():GetText() or ""):gsub("||", "|")
        local results, err = SlotPort.ImportString(raw)
        if not results then
            SlotPortGUI:AppendLog(L("POPUP_ERROR"), err, true)
            return
        end
        for _, r in ipairs(results) do
            SlotPortGUI:AppendLog(r.ok and L("POPUP_IMPORT") or L("POPUP_ERROR"), r.msg, not r.ok)
            if r.ok then
                if r.kind == "macros" then
                    SlotPortMacroGUI:RebuildList()
                else
                    SlotPortGUI:RefreshAllSlots()
                end
            end
        end
    end,
    EditBoxOnEnterPressed  = function(self) self:GetParent():GetButton1():Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local ui = SlotPort.ui
local WHITE, C, rgba = ui.WHITE, ui.C, ui.rgba
local CreateBox, CreateText, CreateButton = ui.CreateBox, ui.CreateText, ui.CreateButton
local CreateCheckMark, CreateScroll, CreateSearchBox = ui.CreateCheckMark, ui.CreateScroll, ui.CreateSearchBox

-- ----------------------------------------------------------
-- Layout constants
-- ----------------------------------------------------------
local SLOT_SIZE     = 30
local SLOT_GAP      = 3
local SLOTS_PER_BAR = 12
local HEADER_H      = 28
local CARD_PAD      = 12
local CARD_H        = HEADER_H + SLOT_SIZE + 10
local CARD_GAP      = 6

local SIDEBAR_W = 132
local FRAME_H   = 500
local ROW_W     = SLOTS_PER_BAR * SLOT_SIZE + (SLOTS_PER_BAR - 1) * SLOT_GAP   -- 393
local LIST_W    = ROW_W + CARD_PAD * 2                                           -- 417
local FRAME_W   = SIDEBAR_W + 14 + LIST_W + 12 + 14 + 2                          -- 591 (+2: window border)

-- ----------------------------------------------------------
-- Slot buttons
-- ----------------------------------------------------------
local function PaintSlot(btn, hasTex, selected)
    btn._hasTex = hasTex
    if hasTex then
        btn:SetBackdropColor(rgba(C.slotFilled))
        btn.num:Hide()
        btn.icon:Show()
    else
        btn:SetBackdropColor(rgba(C.slotEmpty))
        btn.num:Show()
        btn.icon:Hide()
    end
    if selected then
        btn:SetBackdropBorderColor(rgba(C.accent))
        -- empty slots only get the accent border; the tint is for icons
        btn.selOverlay:SetShown(hasTex)
        btn.num:SetTextColor(rgba(selected and C.accent or C.dim, 0.8))
    else
        btn.num:SetTextColor(rgba(C.dim))
        btn:SetBackdropBorderColor(rgba(C.line))
        btn.selOverlay:Hide()
    end
end

local function RefreshSlotButton(btn, slot, barDef, btnIndex)
    local tex
    if barDef and barDef.isElvUI and barDef.elvuiBarNum and not barDef.fixedSlot then
        tex = SlotPort:GetElvUIButtonTexture(barDef.elvuiBarNum, btnIndex)
        if not tex then tex = GetActionTexture(slot) end
    else
        tex = GetActionTexture(slot)
    end
    if tex then btn.icon:SetTexture(tex) end
    PaintSlot(btn, tex ~= nil, SlotPort.selectedSlots[slot])
    return tex ~= nil
end

local function ShowSlotTooltip(self)
    local slot = self._slotID
    if not slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        GameTooltip:SetSpellByID(id)
    elseif actionType == "item" then
        GameTooltip:SetItemByID(id)
        local isToy = (PlayerHasToy and PlayerHasToy(id))
                   or (C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(id))
        if isToy then
            local spellName = C_Item.GetItemSpell and select(1, C_Item.GetItemSpell(id))
            GameTooltip:AddLine("|cffFF69B4" .. L("TT_TOY_LABEL") .. "|r" ..
                (spellName and ("  |cff888888(" .. spellName .. ")|r") or ""))
        end
    elseif actionType == "summonmount" then
        if id == SlotPort.RANDOM_MOUNT_ID then
            GameTooltip:SetText("|cff00ccff" .. L("TT_MOUNT_RANDOM") .. "|r")
        else
            local name = C_MountJournal and C_MountJournal.GetMountInfoByID
                         and C_MountJournal.GetMountInfoByID(id)
            GameTooltip:SetText((name or string.format(L("TT_SLOT_TYPE"), slot, "Mount ID " .. tostring(id))))
            GameTooltip:AddLine("|cff00ccff" .. L("TT_MOUNT_TYPE") .. "|r")
        end
    elseif actionType == "companion" or actionType == "summonpet" then
        GameTooltip:SetText(string.format(L("TT_SLOT_TYPE"), slot, "Pet #" .. tostring(id)))
        GameTooltip:AddLine("|cffaaddff" .. L("TT_PET_TYPE") .. "|r")
    elseif actionType == "macro" then
        local name = GetMacroInfo(id)
        if not name or name == "" then
            name = GetActionText(slot)
        end
        GameTooltip:SetText("|cffffcc00" .. L("TT_MACRO_PREFIX") .. "|r" .. (name or "?"))
    elseif actionType then
        GameTooltip:SetText(string.format(L("TT_SLOT_TYPE"), slot, actionType))
    else
        GameTooltip:SetText(string.format(L("TT_EMPTY_SLOT"), slot))
    end
    GameTooltip:Show()
end

-- Slot buttons are pooled per bar card: the slot/bar they represent is
-- assigned in BindCard, so nothing here captures a slot id.
local function CreateSlotButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)
    btn:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints()
    overlay:SetColorTexture(rgba(C.accent, 0.28))
    overlay:Hide()
    btn.selOverlay = overlay

    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)

    local num = CreateText(btn, "SlotPortFontTiny", C.dim)
    num:SetPoint("TOPLEFT", 3, -3)
    btn.num = num

    btn:SetScript("OnEnter", ShowSlotTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- barIndex comes from the bound barDef, not from math.ceil(slot/12):
    -- ElvUI/skyriding slot ids don't follow the 12-per-bar scheme.
    btn:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn ~= "LeftButton" or not self._slotID then return end
        SlotPort:ToggleSlot(self._slotID)
        PaintSlot(self, self._hasTex, SlotPort.selectedSlots[self._slotID])
        local barIdx = self.barDef and self.barDef._barIndex
        if barIdx then SlotPortGUI:RefreshBarCheckbox(barIdx) end
        SlotPortGUI:UpdateStatusText()
    end)

    PaintSlot(btn, false, false)
    return btn
end

-- ----------------------------------------------------------
-- Bar cards
-- ----------------------------------------------------------
local function CreateBarCard(parent)
    local card = CreateBox(parent, C.card, C.line)
    card:SetHeight(CARD_H)

    local header = CreateFrame("Button", nil, card)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)

    local check = CreateCheckMark(header, 16)
    check:SetPoint("LEFT", CARD_PAD, 0)
    card.check = check

    card.name = CreateText(header, "SlotPortFontNormal", C.text)
    card.name:SetPoint("LEFT", check, "RIGHT", 10, 0)

    card.count = CreateText(header, "SlotPortFontSmall", C.dim)
    card.count:SetPoint("LEFT", card.name, "RIGHT", 8, 0)

    card.tag = CreateText(header, "SlotPortFontSmall", C.accent, "RIGHT")
    card.tag:SetPoint("RIGHT", -CARD_PAD, 0)

    header:SetScript("OnEnter", function() card:SetBackdropBorderColor(rgba(C.lineHi)) end)
    header:SetScript("OnLeave", function() SlotPortGUI:RefreshBarCheckbox(card._barIndex) end)
    header:SetScript("OnClick", function()
        local idx = card._barIndex
        if not idx then return end
        SlotPort:ToggleBar(idx, not SlotPort:IsBarFullySelected(idx))
        local bar = SlotPort.BARS[idx]
        if bar then
            for slot = bar.startSlot, bar.endSlot do
                local sb = SlotPort.slotButtons[slot]
                if sb then PaintSlot(sb, sb._hasTex, SlotPort.selectedSlots[slot]) end
            end
        end
        SlotPortGUI:RefreshBarCheckbox(idx)
        SlotPortGUI:UpdateStatusText()
    end)

    card.slots = {}
    for i = 1, SLOTS_PER_BAR do
        local sb = CreateSlotButton(card)
        sb:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + (i - 1) * (SLOT_SIZE + SLOT_GAP), -HEADER_H)
        card.slots[i] = sb
    end
    return card
end

local function BindCard(card, barIndex, barDef)
    barDef._barIndex = barIndex
    card._barIndex = barIndex

    local isAssisted = false
    local firstBtn = _G["ActionButton" .. barDef.startSlot]
    if firstBtn and firstBtn.AssistedCombatRotationFrame then
        isAssisted = firstBtn.AssistedCombatRotationFrame:IsShown()
    end

    card._plainName = barDef.name
    local dimmed = (barDef.isEnabled == false)
    card.name:SetText(barDef.name)
    if dimmed then
        card.name:SetTextColor(rgba(C.dim))
    elseif barDef.isSkyriding then
        card.name:SetTextColor(rgba(C.accent))
    else
        card.name:SetTextColor(rgba(C.text))
    end
    card.tag:SetText(isAssisted and L("ASSISTED_COMBAT_LABEL") or "")

    for i = 1, SLOTS_PER_BAR do
        local sb   = card.slots[i]
        local slot = barDef.startSlot + (i - 1)
        if slot > barDef.endSlot then
            sb:Hide()
            sb._slotID = nil
        else
            sb._slotID  = slot
            sb.barDef   = barDef
            sb.btnIndex = i
            sb.num:SetText(((slot - 1) % SLOTS_PER_BAR) + 1)
            SlotPort.slotButtons[slot] = sb
            sb:Show()
        end
    end
end

-- ----------------------------------------------------------
-- Status / refresh
-- ----------------------------------------------------------
function SlotPortGUI:RefreshBarCheckbox(barIndex)
    local card = self.cards and self.cards[barIndex]
    local bar  = SlotPort.BARS[barIndex]
    if not card or not bar then return end
    local sel, total = 0, 0
    for slot = bar.startSlot, bar.endSlot do
        total = total + 1
        if SlotPort.selectedSlots[slot] then sel = sel + 1 end
    end
    local state = (sel == 0) and "none" or ((sel == total) and "full" or "part")
    card.check:SetState(state)
    if state == "full" then
        card:SetBackdropBorderColor(rgba(C.accent, 0.6))
    else
        card:SetBackdropBorderColor(rgba(C.line))
    end
end

function SlotPortGUI:UpdateStatusText()
    if not self.slotsText then return end
    local count = SlotPort:GetSelectedCount()
    if count == 0 then
        self.slotsText:SetText(L("NO_SLOTS_SEL"))
        self.slotsText:SetTextColor(rgba(C.dim))
    else
        self.slotsText:SetText(
            "|cff35c4f0" .. count .. "|r " ..
            (count == 1 and L("SLOTS_WORD") or L("SLOTS_WORD_PLURAL")) .. " " ..
            L("SLOTS_SELECTED_SUFFIX"))
        self.slotsText:SetTextColor(rgba(C.muted))
    end
    local mCount = SlotPort:GetSelectedMacroCount()
    if mCount == 0 then
        self.macrosText:SetText(L("NO_MACROS_SEL"))
        self.macrosText:SetTextColor(rgba(C.dim))
    else
        self.macrosText:SetText(
            "|cff35c4f0" .. mCount .. "|r " ..
            (mCount == 1 and L("MACROS_WORD") or L("MACROS_WORD_PLURAL")) .. " " ..
            L("SLOTS_SELECTED_SUFFIX"))
        self.macrosText:SetTextColor(rgba(C.muted))
    end
end

-- Reload all slot icons.
-- Loop uses bar.endSlot - bar.startSlot + 1 instead of a hardcoded 12 so
-- ElvUI bars with fewer slots are handled correctly. Icons always refresh,
-- even for a disabled bar - the dimmed name already shows it's inactive,
-- and the player shouldn't have to enable it just to see what's on it.
function SlotPortGUI:RefreshAllSlots()
    if not self.cards then return end
    for i, bar in ipairs(SlotPort.BARS) do
        local card = self.cards[i]
        if card then
            local numSlots, filled = bar.endSlot - bar.startSlot + 1, 0
            for s = 1, numSlots do
                local slot = bar.startSlot + (s - 1)
                local btn  = SlotPort.slotButtons[slot]
                if btn and RefreshSlotButton(btn, slot, bar, s) then
                    filled = filled + 1
                end
            end
            card.count:SetText(filled .. "/" .. numSlots)
            self:RefreshBarCheckbox(i)
        end
    end
    self:UpdateStatusText()
end

function SlotPortGUI:ShowExportString(str)
    StaticPopup_Show("SLOTPORT_EXPORT", nil, nil, str or "")
end

-- ----------------------------------------------------------
-- Log: append entry
-- ----------------------------------------------------------
local MAX_LOG_CHARS = 20000

function SlotPortGUI:AppendLog(title, msg, isError)
    if not self.logBox then return end
    local color = isError and "|cffff4444" or "|cff35c4f0"
    local line  = color .. title .. ":|r " .. tostring(msg or "")
    local cur   = self.logBox._readOnlyText or ""
    local new   = cur ~= "" and (cur .. "\n" .. line) or line
    if #new > MAX_LOG_CHARS then
        -- keep the newest entries; the cut-off first line is dropped
        new = new:sub(-MAX_LOG_CHARS):gsub("^[^\n]*\n", "")
    end
    self.logBox._readOnlyText = new   -- set before SetText so OnTextChanged doesn't revert it
    self.logBox:SetText(new)
    local sf = self.logBox:GetParent()
    RunNextFrame(function()
        if sf and sf.SetVerticalScroll then
            sf:SetVerticalScroll(sf:GetVerticalScrollRange())
        end
    end)
    if self.page ~= "log" and self.navButtons and self.navButtons.log then
        self.navButtons.log.dot:SetColorTexture(rgba(isError and C.danger or C.accent))
        self.navButtons.log.dot:Show()
    end
end

-- ----------------------------------------------------------
-- Pages
-- ----------------------------------------------------------
function SlotPortGUI:ShowPage(id)
    if not self.pages or not self.pages[id] then return end
    self.page = id
    for pid, page in pairs(self.pages) do
        page:SetShown(pid == id)
    end
    for pid, nav in pairs(self.navButtons) do
        nav:SetStyle(pid == id and "active" or "ghost")
    end
    self.btnResetSlots:SetShown(id == "bars")
    self.btnDeleteMacros:SetShown(id == "macros")
    -- the characters page copies saved layouts, it has nothing to export from the selection
    self.btnExport:SetShown(id ~= "chars")
    if id == "log" then self.navButtons.log.dot:Hide() end
    if id == "macros" then SlotPortMacroGUI:RebuildList() end
    if id == "chars" then SlotPortCharsGUI:Rebuild() end
end

-- Position the visible bar cards (search filter applied)
function SlotPortGUI:LayoutBars()
    if not self.cards or not self.listContent then return end
    local q = strlower(self.filter or "")
    local y = 0
    for _, card in ipairs(self.cards) do
        if card._barIndex then
            local name = strlower(card._plainName or "")
            if q == "" or name:find(q, 1, true) then
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT",  self.listContent, "TOPLEFT",  0, -y)
                card:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
                card:Show()
                y = y + CARD_H + CARD_GAP
            else
                card:Hide()
            end
        else
            card:Hide()
        end
    end
    self.listContent:SetHeight(math.max(1, y - CARD_GAP))
    if self.barScroll then self.barScroll.UpdateBar() end
end

-- (Re)bind the pooled bar cards to the current SlotPort.BARS, e.g. after
-- an ElvUI bar change. Does not change window visibility.
function SlotPortGUI:RebuildGrid()
    if not self.mainFrame then return end
    self.cards = self.cards or {}
    for k in pairs(SlotPort.slotButtons) do SlotPort.slotButtons[k] = nil end

    for i, barDef in ipairs(SlotPort.BARS) do
        local card = self.cards[i]
        if not card then
            card = CreateBarCard(self.listContent)
            self.cards[i] = card
        end
        BindCard(card, i, barDef)
    end
    for i = #SlotPort.BARS + 1, #self.cards do
        self.cards[i]._barIndex = nil
    end

    self:LayoutBars()
    self:RefreshAllSlots()
end

-- ----------------------------------------------------------
-- Main window
-- ----------------------------------------------------------
local function ExportSelection()
    local hasSlots  = SlotPort:GetSelectedCount() > 0
    local hasMacros = SlotPort:GetSelectedMacroCount() > 0

    if not hasSlots and not hasMacros then
        SlotPortGUI:AppendLog(L("POPUP_ERROR"), L("NOTHING_TO_EXPORT"), true)
        return
    end

    local parts = {}

    -- Macros first (import order: macros before slots)
    if hasMacros then
        local mStr, mCount = SlotPort:ExportMacros()
        if mStr then
            parts[#parts + 1] = mStr
            SlotPortGUI:AppendLog(L("POPUP_EXPORT"), string.format(L("MACROS_EXPORTED"), mCount))
        else
            SlotPortGUI:AppendLog(L("POPUP_ERROR"), tostring(mCount), true)
        end
    end

    if hasSlots then
        local sStr, sCount, sFilled = SlotPort:Export()
        if sStr then
            parts[#parts + 1] = sStr
            SlotPortGUI:AppendLog(L("POPUP_EXPORT"), string.format(L("EXPORT_SUCCESS"), sCount))
            if sFilled and sFilled > 0 and sFilled < sCount then
                SlotPortGUI:AppendLog(L("POPUP_EXPORT"), string.format(L("EXPORTED_EMPTY_NOTE"), sCount - sFilled))
            end
            if sFilled == 0 then
                SlotPortGUI:AppendLog(L("POPUP_EXPORT"), L("EXPORT_ALL_EMPTY_WARN"), true)
            end
        else
            SlotPortGUI:AppendLog(L("POPUP_ERROR"), tostring(sCount), true)
        end
    end

    if #parts > 0 then
        StaticPopup_Show("SLOTPORT_EXPORT", nil, nil, table.concat(parts, " "))
    end
end

local function ResetSelection()
    if InCombatLockdown() then
        SlotPortGUI:AppendLog(L("RESET_SLOTS_BTN"), L("IN_COMBAT"), true)
        return
    end
    local count = SlotPort:GetSelectedCount()
    if count == 0 then
        SlotPortGUI:AppendLog(L("RESET_SLOTS_BTN"), L("NO_SLOTS_SEL"), true)
        return
    end
    StaticPopupDialogs["SLOTPORT_CONFIRM_RESET_SLOTS"].text = string.format(L("RESET_SLOTS_CONFIRM"), count)
    StaticPopup_Show("SLOTPORT_CONFIRM_RESET_SLOTS")
end

local function DeleteSelectedMacros()
    local count = SlotPort:GetSelectedMacroCount()
    if count == 0 then
        SlotPortGUI:AppendLog(L("DELETE_MACROS_BTN"), L("NO_MACROS_SEL"), true)
        return
    end
    StaticPopupDialogs["SLOTPORT_CONFIRM_DELETE_MACROS"].text = string.format(L("DELETE_MACROS_CONFIRM"), count)
    StaticPopup_Show("SLOTPORT_CONFIRM_DELETE_MACROS")
end

local function SavePosition(frame)
    local point, _, relPoint, xOfs, yOfs = frame:GetPoint()
    if point and SlotPort.db and SlotPort.db.global then
        SlotPort.db.global.windowPos = { point = point, relPoint = relPoint, x = xOfs, y = yOfs }
    end
end

function SlotPortGUI:CreateMainFrame()
    local frame = CreateFrame("Frame", "SlotPortFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(rgba(C.bg, 0.97))
    frame:SetBackdropBorderColor(rgba(C.line))
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    local pos = SlotPort.db and SlotPort.db.global and SlotPort.db.global.windowPos
    if pos and pos.x and pos.y then
        frame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "BOTTOMLEFT", pos.x, pos.y)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "SlotPortFrame")

    -- Slot changes: debounce, then refresh (or rebind if bars changed).
    -- Only listened to while the window is shown - Open() refreshes everything.
    frame:SetScript("OnShow", function(self) self:RegisterEvent("ACTIONBAR_SLOT_CHANGED") end)
    frame:SetScript("OnHide", function(self) self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED") end)
    local _slotChangedPending = false
    frame:SetScript("OnEvent", function()
        if _slotChangedPending then return end
        _slotChangedPending = true
        RunNextFrame(function()
            _slotChangedPending = false
            if InCombatLockdown() then return end
            local stateBefore = {}
            for i, bar in ipairs(SlotPort.BARS) do
                stateBefore[i] = { isEnabled = bar.isEnabled, hasContent = bar.hasContent }
            end

            SlotPort:RefreshBarContent()
            SlotPort:RefreshElvUIBars()

            local needRebuild = (#SlotPort.BARS ~= #stateBefore)
            if not needRebuild then
                for i, bar in ipairs(SlotPort.BARS) do
                    local before = stateBefore[i]
                    if not before or bar.isEnabled ~= before.isEnabled or
                       bar.hasContent ~= before.hasContent then
                        needRebuild = true; break
                    end
                end
            end

            if needRebuild then
                SlotPortGUI:RebuildGrid()
            elseif frame:IsShown() then
                SlotPortGUI:RefreshAllSlots()
            end
        end)
    end)

    self.mainFrame = frame

    -- ======================================================
    -- SIDEBAR
    -- ======================================================
    local side = CreateBox(frame, C.side, nil)
    side:SetPoint("TOPLEFT", 1, -1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDEBAR_W)

    local sideLine = side:CreateTexture(nil, "OVERLAY")
    sideLine:SetPoint("TOPRIGHT", 0, 0)
    sideLine:SetPoint("BOTTOMRIGHT", 0, 0)
    sideLine:SetWidth(1)
    sideLine:SetColorTexture(rgba(C.line))

    local title = CreateText(side, "SlotPortFontTitle", C.text)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff35c4f0Slot|rPort")

    local navDefs = {
        { id = "bars",   label = L("NAV_BARS")   },
        { id = "macros", label = L("MACRO_BTN")  },
        { id = "chars",  label = L("NAV_CHARS")  },
        { id = "log",    label = L("LOG_LABEL")  },
    }
    self.navButtons = {}
    local prev
    for _, def in ipairs(navDefs) do
        local nav = CreateButton(side, def.label, "ghost", function() SlotPortGUI:ShowPage(def.id) end)
        nav:SetHeight(30)
        nav:SetWidth(SIDEBAR_W - 17)
        if prev then
            nav:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
        else
            nav:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -56)
        end
        nav.text:ClearAllPoints()
        nav.text:SetPoint("LEFT", 12, 0)
        nav.text:SetJustifyH("LEFT")
        local dot = nav:CreateTexture(nil, "OVERLAY")
        dot:SetSize(6, 6)
        dot:SetPoint("RIGHT", -12, 0)
        dot:SetColorTexture(rgba(C.accent))
        dot:Hide()
        nav.dot = dot
        self.navButtons[def.id] = nav
        prev = nav
    end

    -- Addon hint (bottom) and selection summary (above it)
    local hintText = ""
    if SlotPort:HasBartender4() or SlotPort:HasElvUI() then
        local addons = {}
        if SlotPort:HasBartender4() then table.insert(addons, "Bartender4") end
        if SlotPort:HasElvUI()     then table.insert(addons, "ElvUI")      end
        hintText = table.concat(addons, " + ") .. " " .. L("ADDON_RECOGNIZED")
    end
    local hint = CreateText(side, "SlotPortFontSmall", C.dim)
    hint:SetPoint("BOTTOMLEFT", 16, 14)
    hint:SetWidth(SIDEBAR_W - 28)
    hint:SetText(hintText)

    self.macrosText = CreateText(side, "SlotPortFontSmall", C.dim)
    self.macrosText:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, 12)
    self.macrosText:SetWidth(SIDEBAR_W - 28)
    self.slotsText = CreateText(side, "SlotPortFontSmall", C.dim)
    self.slotsText:SetPoint("BOTTOMLEFT", self.macrosText, "TOPLEFT", 0, 8)
    self.slotsText:SetWidth(SIDEBAR_W - 28)

    -- ======================================================
    -- CONTENT
    -- ======================================================
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    local btnClose = CreateButton(content, "×", "ghost", function() frame:Hide() end, 32)
    btnClose.text:SetFontObject("SlotPortFontClose")
    btnClose:SetSize(32, 32)
    btnClose:SetPoint("TOPRIGHT", -8, -10)
    btnClose:SetScript("OnEnter", function(self)
        self.text:SetTextColor(rgba(C.danger))
    end)
    btnClose:SetScript("OnLeave", function(self)
        self.text:SetTextColor(rgba(C.muted))
    end)

    -- Footer: page-specific destructive action on the left, Import/Export on the right
    self.btnExport = CreateButton(content, L("EXPORT_BTN"), "primary", ExportSelection, 100)
    self.btnExport:SetPoint("BOTTOMRIGHT", -14, 12)
    local btnImport = CreateButton(content, L("IMPORT_BTN"), "outline", function()
        StaticPopup_Show("SLOTPORT_IMPORT")
    end, 100)
    btnImport:SetPoint("RIGHT", self.btnExport, "LEFT", -8, 0)

    self.btnResetSlots = CreateButton(content, L("RESET_SLOTS_BTN"), "danger", ResetSelection)
    self.btnResetSlots:SetPoint("BOTTOMLEFT", 14, 12)
    self.btnDeleteMacros = CreateButton(content, L("DELETE_MACROS_BTN"), "danger", DeleteSelectedMacros)
    self.btnDeleteMacros:SetPoint("BOTTOMLEFT", 14, 12)

    self.pages = {}
    local function NewPage(id)
        local page = CreateFrame("Frame", nil, content)
        page:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -12)
        page:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 56)
        self.pages[id] = page
        return page
    end

    -- ------------------------------------------------------
    -- Page: bars
    -- ------------------------------------------------------
    local barsPage = NewPage("bars")
    local barsBar = CreateFrame("Frame", nil, barsPage)
    barsBar:SetPoint("TOPLEFT", 0, 0)
    barsBar:SetPoint("TOPRIGHT", -40, 0)
    barsBar:SetHeight(28)

    local btnNone = CreateButton(barsBar, L("DESELECT_ALL"), "outline", function()
        SlotPort:DeselectAll()
        SlotPortGUI:RefreshAllSlots()
    end, 70)
    btnNone:SetPoint("RIGHT", 0, 0)
    local btnAll = CreateButton(barsBar, L("SELECT_ALL"), "outline", function()
        SlotPort:SelectAll()
        SlotPortGUI:RefreshAllSlots()
    end, 70)
    btnAll:SetPoint("RIGHT", btnNone, "LEFT", -6, 0)

    self.filter = ""
    local search = CreateSearchBox(barsBar, L("SEARCH_BAR"), function(text)
        SlotPortGUI.filter = text or ""
        SlotPortGUI:LayoutBars()
    end)
    search:SetPoint("LEFT", 0, 0)
    search:SetPoint("RIGHT", btnAll, "LEFT", -8, 0)

    local barScroll, barContent = CreateScroll(barsPage)
    barScroll:SetPoint("TOPLEFT", barsBar, "BOTTOMLEFT", 0, -10)
    barScroll:SetPoint("BOTTOMRIGHT", barsPage, "BOTTOMRIGHT", -12, 0)
    self.barScroll   = barScroll
    self.listContent = barContent
    SlotPortMacroGUI:BuildPage(NewPage("macros"))
    SlotPortCharsGUI:BuildPage(NewPage("chars"))

    -- ------------------------------------------------------
    -- Page: log
    -- ------------------------------------------------------
    local logPage = NewPage("log")
    local logBG = CreateBox(logPage, C.side, C.line)
    logBG:SetPoint("TOPLEFT", 0, 0)
    logBG:SetPoint("BOTTOMRIGHT", 0, 0)

    local logEditBox
    local logScroll = CreateScroll(logBG, function(w)
        if logEditBox then logEditBox:SetWidth(w) end
    end)
    logScroll:SetPoint("TOPLEFT", 10, -10)
    logScroll:SetPoint("BOTTOMRIGHT", -20, 10)

    logEditBox = CreateFrame("EditBox", nil, logScroll)
    logEditBox:SetWidth(380)
    logEditBox:SetHeight(20)
    logEditBox:SetMultiLine(true)
    logEditBox:SetAutoFocus(false)
    logEditBox:SetFontObject("SlotPortFontNormal")
    logEditBox:SetTextColor(rgba(C.text))
    logEditBox:SetMaxLetters(0)
    logEditBox:SetText("")
    logEditBox._readOnlyText = ""
    -- Read-only: userInput=true means the user typed/pasted/cut something.
    -- In that case, immediately revert to the last known state.
    logEditBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self._readOnlyText or "")
        end
    end)
    logEditBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    logEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if SlotPortGUI.mainFrame then SlotPortGUI.mainFrame:Hide() end
    end)
    logScroll:SetScrollChild(logEditBox)
    self.logBox = logEditBox

    return frame
end

-- ----------------------------------------------------------
-- Open / toggle
-- ----------------------------------------------------------
function SlotPortGUI:Open(page)
    SlotPort:RefreshBarContent()
    SlotPort:RefreshElvUIBars()

    local firstOpen = not self.mainFrame
    if firstOpen then self:CreateMainFrame() end
    self:RebuildGrid()
    self.mainFrame:Show()
    self:ShowPage(page or self.page or "bars")

    if firstOpen then
        -- Refresh again one frame later to make sure the action bar data is loaded
        RunNextFrame(function()
            if self.mainFrame and self.mainFrame:IsShown() then
                local barCount = #SlotPort.BARS
                SlotPort:RefreshBarContent()
                -- A bar registered by this refresh (e.g. Skyriding once its
                -- slots are loaded) shifts the sorted list: rebind the cards
                if #SlotPort.BARS ~= barCount then
                    self:RebuildGrid()
                else
                    self:RefreshAllSlots()
                end
            end
        end)
    end
end

function SlotPortGUI:Toggle()
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self:Open()
    end
end

-- GUI is created lazily on the first /sp via SlotPortGUI:Toggle().
