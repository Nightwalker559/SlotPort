-- ============================================================
-- Characters page of the main window: saved layouts of every character
-- (Data/Characters.lua). Flat list of pooled rows: one row per saved
-- character, followed by one row per specialization while the character is
-- expanded.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

local ui = SlotPort.ui
local WHITE, C, rgba = ui.WHITE, ui.C, ui.rgba
local CreateText, CreateButton, CreateCheckMark, CreateScroll = ui.CreateText, ui.CreateButton, ui.CreateCheckMark, ui.CreateScroll

-- data (3rd arg to StaticPopup_Show) = { key = character key, specID = spec or nil for the whole character }
StaticPopupDialogs["SLOTPORT_CONFIRM_DELETE_CHAR"] = {
    text         = L("CHARS_DELETE_CONFIRM"),
    button1      = YES,
    button2      = NO,
    OnAccept     = function(_, data)
        SlotPort:DeleteSnapshot(data.key, data.specID)
        SlotPortCharsGUI:Rebuild()
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

SlotPortCharsGUI = {}

-- Builds the page widgets into `page` (called once by SlotPortGUI:CreateMainFrame)
function SlotPortCharsGUI:BuildPage(page)
    local charsHint = CreateText(page, "SlotPortFontSmall", C.dim)
    charsHint:SetPoint("TOPLEFT", 0, -2)
    charsHint:SetPoint("TOPRIGHT", -40, -2)
    charsHint:SetText(L("CHARS_HINT"))

    -- Only characters of the current class are listed unless this is ticked
    local showAll = CreateFrame("Button", nil, page)
    showAll:SetHeight(22)
    showAll:SetPoint("TOPLEFT", charsHint, "BOTTOMLEFT", 0, -8)
    showAll:SetPoint("TOPRIGHT", charsHint, "BOTTOMRIGHT", 0, -8)
    local showAllCheck = CreateCheckMark(showAll, 16)
    showAllCheck:SetPoint("LEFT", 0, 0)
    local showAllText = CreateText(showAll, "SlotPortFontSmall", C.muted)
    showAllText:SetPoint("LEFT", showAllCheck, "RIGHT", 8, 0)
    showAllText:SetText(L("CHARS_SHOW_ALL"))
    local showAllHidden = CreateText(showAll, "SlotPortFontSmall", C.dim)
    showAllHidden:SetPoint("LEFT", showAllText, "RIGHT", 8, 0)
    showAll:SetScript("OnClick", function()
        local global = SlotPort.db.global
        global.showAllChars = not global.showAllChars or nil
        SlotPortCharsGUI:Rebuild()
    end)
    SlotPortCharsGUI.showAllCheck  = showAllCheck
    SlotPortCharsGUI.showAllHidden = showAllHidden

    local charsScroll, charsContent = CreateScroll(page)
    charsScroll:SetPoint("TOPLEFT", showAll, "BOTTOMLEFT", 0, -8)
    charsScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)
    SlotPortCharsGUI.listContent = charsContent
    SlotPortCharsGUI.scroll      = charsScroll

    local charsEmpty = CreateText(page, "SlotPortFontNormal", C.dim, "CENTER")
    charsEmpty:SetPoint("CENTER", charsScroll, "CENTER", 0, 0)
    charsEmpty:SetText(L("CHARS_EMPTY"))
    SlotPortCharsGUI.emptyText = charsEmpty
end

local CHAR_ROW_H = 30
local SPEC_ROW_H = 26
local ROW_GAP    = 4
local DEL_W      = 30   -- delete button, wide enough to read the cross at a glance

local function AgeText(t)
    local diff = time() - (t or 0)
    if diff < 60 then return L("CHARS_NOW") end
    return string.format(L("CHARS_AGO"), SecondsToTime(diff, true, false, 1))
end

local function PaintCharRow(row, hover)
    if row._isChar then
        row:SetBackdropColor(rgba(C.card))
        row:SetBackdropBorderColor(rgba(hover and C.lineHi or C.line))
    else
        row:SetBackdropColor(rgba(C.card, hover and 1 or 0))
        row:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function CreateCharRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })

    -- expand/collapse mark drawn from two bars: a minus, plus a vertical bar while collapsed
    row.toggle = CreateFrame("Frame", nil, row)
    row.toggle:SetSize(12, 12)
    row.toggle:SetPoint("LEFT", 10, 0)
    local barH = row.toggle:CreateTexture(nil, "OVERLAY")
    barH:SetSize(10, 2)
    barH:SetPoint("CENTER")
    barH:SetColorTexture(rgba(C.muted))
    row.toggleV = row.toggle:CreateTexture(nil, "OVERLAY")
    row.toggleV:SetSize(2, 10)
    row.toggleV:SetPoint("CENTER")
    row.toggleV:SetColorTexture(rgba(C.muted))

    row.del = CreateButton(row, "×", "danger", function()
        local label = row._isChar and row._label or (row._label .. " – " .. row._specLabel)
        StaticPopup_Show("SLOTPORT_CONFIRM_DELETE_CHAR", label, nil,
            { key = row._key, specID = row._specID })
    end, DEL_W)
    row.del.text:SetFontObject("SlotPortFontClose")
    row.del:SetSize(DEL_W, 24)
    row.del:SetPoint("RIGHT", -6, 0)

    row.copy = CreateButton(row, L("CHARS_COPY"), "outline", function()
        local str = SlotPort:GetSnapshotString(row._key, row._specID)
        if str then SlotPortGUI:ShowExportString(str) end
    end, 70)
    row.copy:SetHeight(22)
    row.copy:SetPoint("RIGHT", row.del, "LEFT", -6, 0)
    row.copy:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format(L("CHARS_COPY_TIP"), row._macroCount or 0), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.copy:HookScript("OnLeave", function() GameTooltip:Hide() end)

    row.name  = CreateText(row, "SlotPortFontNormal", C.text)
    row.info  = CreateText(row, "SlotPortFontSmall", C.dim, "RIGHT")
    row.info:SetWidth(170)
    row.info:SetWordWrap(false)
    row.realm = CreateText(row, "SlotPortFontSmall", C.dim)
    row.realm:SetMaxLines(1)

    row:SetScript("OnEnter", function(self) PaintCharRow(self, true) end)
    row:SetScript("OnLeave", function(self) PaintCharRow(self, false) end)
    row:SetScript("OnClick", function(self)
        if not self._isChar then return end
        SlotPortCharsGUI.expanded[self._key] = not SlotPortCharsGUI.expanded[self._key]
        SlotPortCharsGUI:Rebuild()
    end)
    return row
end

local function BindCharRow(row, c, isCurrent, expanded)
    row._isChar, row._key, row._specID = true, c.key, nil
    row._label, row._macroCount = c.name, c.macroCount

    row.toggle:Show()
    row.toggleV:SetShown(not expanded)
    row.copy:Hide()
    row.del:SetShown(not isCurrent)

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    row.name:SetText(c.name)
    if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(rgba(C.text)) end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.toggle, "RIGHT", 8, 0)

    row.info:ClearAllPoints()
    row.info:SetPoint("RIGHT", row, "RIGHT", isCurrent and -12 or -(DEL_W + 14), 0)
    row.info:SetText(string.format(L("CHARS_SPECS"), #c.specs) .. " · " .. AgeText(c.seen))

    row.realm:ClearAllPoints()
    row.realm:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.realm:SetPoint("RIGHT", row.info, "LEFT", -6, 0)
    row.realm:SetText(c.realm .. (isCurrent and (" · |cff35c4f0" .. L("CHARS_CURRENT") .. "|r") or ""))

    PaintCharRow(row, false)
end

local function BindSpecRow(row, c, s, isCurrent)
    row._isChar, row._key, row._specID = false, c.key, s.id
    row._label, row._specLabel, row._macroCount = c.name, s.name, c.macroCount

    row.toggle:Hide()
    row.copy:Show()
    row.del:SetShown(not isCurrent)

    row.name:SetText(s.name)
    row.name:SetTextColor(rgba(isCurrent and C.accent or C.text))
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row, "LEFT", 34, 0)

    row.info:ClearAllPoints()
    row.info:SetPoint("RIGHT", row.copy, "LEFT", -10, 0)
    row.info:SetText(string.format(L("CHARS_SLOTS"), s.filled or 0) .. " · " .. AgeText(s.t))

    row.realm:SetText("")
    PaintCharRow(row, false)
end

function SlotPortCharsGUI:Rebuild()
    if not self.listContent then return end
    SlotPort:FlushSnapshot()   -- the current character's row should show its latest layout
    self._rows = self._rows or {}
    self.expanded = self.expanded or {}

    local currentKey, currentSpec = SlotPort:GetCurrentSnapshotKeys()
    local n, y = 0, 0
    local function nextRow(height)
        n = n + 1
        local row = self._rows[n]
        if not row then
            row = CreateCharRow(self.listContent)
            self._rows[n] = row
        end
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  self.listContent, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
        row:Show()
        y = y + height + ROW_GAP
        return row
    end

    local showAll = SlotPort.db.global.showAllChars
    local _, myClass = UnitClass("player")
    local chars, hidden = SlotPort:GetSnapshotChars(not showAll and myClass or nil)
    self.showAllCheck:SetState(showAll and "full" or "none")
    self.showAllHidden:SetText(hidden > 0 and string.format(L("CHARS_HIDDEN"), hidden) or "")

    for _, c in ipairs(chars) do
        local isCurrent = (c.key == currentKey)
        if self.expanded[c.key] == nil then self.expanded[c.key] = isCurrent end
        BindCharRow(nextRow(CHAR_ROW_H), c, isCurrent, self.expanded[c.key])
        if self.expanded[c.key] then
            for _, s in ipairs(c.specs) do
                BindSpecRow(nextRow(SPEC_ROW_H), c, s, isCurrent and s.id == currentSpec)
            end
        end
    end
    for i = n + 1, #self._rows do self._rows[i]:Hide() end

    self.listContent:SetHeight(math.max(1, y - ROW_GAP))
    self.emptyText:SetShown(n == 0)
    if self.scroll then self.scroll.UpdateBar() end
end
