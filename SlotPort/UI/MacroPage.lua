-- ============================================================
-- Macros page of the main window: global/character macro lists with
-- selection for export and delete.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

local ui = SlotPort.ui
local WHITE, C, rgba = ui.WHITE, ui.C, ui.rgba
local CreateText, CreateButton, CreateCheckMark, CreateScroll = ui.CreateText, ui.CreateButton, ui.CreateCheckMark, ui.CreateScroll

local MACRO_ROW_H = 28

SlotPortMacroGUI = {}

-- Builds the page widgets into `page` (called once by SlotPortGUI:CreateMainFrame)
function SlotPortMacroGUI:BuildPage(page)
    local macroBar = CreateFrame("Frame", nil, page)
    macroBar:SetPoint("TOPLEFT", 0, 0)
    macroBar:SetPoint("TOPRIGHT", -40, 0)
    macroBar:SetHeight(28)

    SlotPortMacroGUI.activeTab = SlotPortMacroGUI.activeTab or "g"
    SlotPortMacroGUI._tabs = {}
    local function refreshTabs()
        for _, t in ipairs(SlotPortMacroGUI._tabs) do
            t.btn:SetStyle(t.id == SlotPortMacroGUI.activeTab and "active" or "outline")
        end
    end
    local tabDefs = { { id = "g", labelKey = "TAB_GLOBAL" }, { id = "c", labelKey = "TAB_CHAR" } }
    local prevTab
    for idx, def in ipairs(tabDefs) do
        local id = def.id
        local btn = CreateButton(macroBar, L(def.labelKey), "outline", function()
            SlotPortMacroGUI.activeTab = id
            refreshTabs()
            SlotPortMacroGUI:RebuildList()
        end, 90)
        if prevTab then btn:SetPoint("LEFT", prevTab, "RIGHT", 4, 0) else btn:SetPoint("LEFT", 0, 0) end
        SlotPortMacroGUI._tabs[idx] = { id = id, btn = btn }
        prevTab = btn
    end
    refreshTabs()

    local mNone = CreateButton(macroBar, L("DESELECT_ALL"), "outline", function()
        SlotPort:DeselectAllMacros(SlotPortMacroGUI.activeTab)
        SlotPortMacroGUI:RebuildList()
    end, 70)
    mNone:SetPoint("RIGHT", 0, 0)
    local mAll = CreateButton(macroBar, L("SELECT_ALL"), "outline", function()
        SlotPort:SelectAllMacros(SlotPortMacroGUI.activeTab)
        SlotPortMacroGUI:RebuildList()
    end, 70)
    mAll:SetPoint("RIGHT", mNone, "LEFT", -6, 0)

    local macroScroll, macroContent = CreateScroll(page)
    macroScroll:SetPoint("TOPLEFT", macroBar, "BOTTOMLEFT", 0, -10)
    macroScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)
    SlotPortMacroGUI.listContent = macroContent
    SlotPortMacroGUI.scroll      = macroScroll
end

local function CreateMacroRowFrame(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(MACRO_ROW_H)
    row:SetBackdrop({ bgFile = WHITE })
    row:SetBackdropColor(0, 0, 0, 0)

    row._check = CreateCheckMark(row, 16)
    row._check:SetPoint("LEFT", 8, 0)

    local iconTex = row:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(20, 20)
    iconTex:SetPoint("LEFT", 34, 0)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row._icon = iconTex

    local nameStr = CreateText(row, "SlotPortFontNormal", C.text)
    nameStr:SetPoint("LEFT",  row, "LEFT",  62, 0)
    nameStr:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    nameStr:SetMaxLines(1)
    row._nameStr = nameStr

    row:SetScript("OnClick", function(self_row)
        if not self_row._macro then return end
        SlotPort:ToggleMacro(self_row._macro.index)
        SlotPortMacroGUI:_RefreshRowState(self_row)
        SlotPortGUI:UpdateStatusText()
    end)
    row:SetScript("OnEnter", function(self_row)
        if not self_row._macro then return end
        self_row._hover = true
        SlotPortMacroGUI:_RefreshRowState(self_row)
        GameTooltip:SetOwner(self_row, "ANCHOR_RIGHT")
        GameTooltip:SetText(self_row._macro.name, 1, 1, 1)
        local body = self_row._macro.body
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self_row)
        self_row._hover = false
        SlotPortMacroGUI:_RefreshRowState(self_row)
        GameTooltip:Hide()
    end)
    return row
end

function SlotPortMacroGUI:_RefreshRowState(row)
    if not row._macro then return end
    local sel = SlotPort.selectedMacros[row._macro.index]
    row._check:SetState(sel and "full" or "none")
    if sel then
        row:SetBackdropColor(rgba(C.accent, row._hover and 0.2 or 0.12))
    elseif row._hover then
        row:SetBackdropColor(rgba(C.card))
    else
        row:SetBackdropColor(0, 0, 0, 0)
    end
end

function SlotPortMacroGUI:UpdateStatusText()
    SlotPortGUI:UpdateStatusText()
end

function SlotPortMacroGUI:RebuildList()
    if not self.listContent then return end
    self._rowPool = self._rowPool or {}

    local activeScope = self.activeTab or "g"
    local macros = {}
    for _, m in ipairs(SlotPort:GetAllMacros()) do
        if m.scope == activeScope then
            macros[#macros + 1] = m
        end
    end
    self.listContent:SetHeight(math.max(1, #macros * MACRO_ROW_H))

    for i, m in ipairs(macros) do
        if not self._rowPool[i] then
            self._rowPool[i] = CreateMacroRowFrame(self.listContent)
        end
        local row = self._rowPool[i]
        row._macro = m

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  self.listContent, "TOPLEFT",  0, -(i - 1) * MACRO_ROW_H)
        row:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -(i - 1) * MACRO_ROW_H)

        -- Icon: FileDataID (number) or texture path (string)
        local iconVal = tonumber(tostring(m.icon or "")) or tostring(m.icon or "")
        if iconVal and iconVal ~= "" and iconVal ~= 0 then
            local ok = pcall(function() row._icon:SetTexture(iconVal) end)
            if not ok then row._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
        else
            row._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        row._nameStr:SetText(m.name)
        self:_RefreshRowState(row)
        row:Show()
    end

    for i = #macros + 1, #self._rowPool do
        self._rowPool[i]:Hide()
    end

    if self.scroll then self.scroll.UpdateBar() end
    SlotPortGUI:UpdateStatusText()
end

-- Open/close the main window on the macros page
function SlotPortMacroGUI:Toggle()
    local gui = SlotPortGUI
    if gui.mainFrame and gui.mainFrame:IsShown() and gui.page == "macros" then
        gui.mainFrame:Hide()
        return
    end
    gui:Open("macros")
end
