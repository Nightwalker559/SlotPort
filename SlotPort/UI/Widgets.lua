-- ============================================================
-- Own skin for the SlotPort window: Graphite theme, fonts and the widget
-- helpers (box, text, button, check mark, scroll frame, search box). No
-- dependency on Blizzard templates, AceGUI or ElvUI. Exported as SlotPort.ui
-- for GUI.lua and the page files.
-- ============================================================

local WHITE = "Interface\\Buttons\\WHITE8X8"

local C = {
    bg         = { 0.082, 0.090, 0.110 },
    side       = { 0.067, 0.075, 0.094 },
    card       = { 0.106, 0.114, 0.141 },
    line       = { 0.149, 0.165, 0.200 },
    lineHi     = { 0.227, 0.251, 0.298 },
    text       = { 0.843, 0.855, 0.878 },
    muted      = { 0.541, 0.565, 0.612 },
    dim        = { 0.357, 0.380, 0.431 },
    accent     = { 0.208, 0.769, 0.941 },
    accentHi   = { 0.330, 0.830, 0.965 },
    onAccent   = { 0.043, 0.063, 0.078 },
    danger     = { 0.886, 0.337, 0.337 },
    slotEmpty  = { 0.114, 0.125, 0.153 },
    slotFilled = { 0.055, 0.063, 0.078 },
}

local function rgba(c, a) return c[1], c[2], c[3], a or 1 end

local FONT_PATH = STANDARD_TEXT_FONT
local fontNormal = CreateFont("SlotPortFontNormal")
fontNormal:SetFont(FONT_PATH, 12, "")
local fontSmall = CreateFont("SlotPortFontSmall")
fontSmall:SetFont(FONT_PATH, 11, "")
local fontTiny = CreateFont("SlotPortFontTiny")
fontTiny:SetFont(FONT_PATH, 10, "")
local fontTitle = CreateFont("SlotPortFontTitle")
fontTitle:SetFont(FONT_PATH, 15, "")
local fontClose = CreateFont("SlotPortFontClose")
fontClose:SetFont(FONT_PATH, 24, "")

-- ----------------------------------------------------------
-- Widget helpers
-- ----------------------------------------------------------
local function CreateBox(parent, bg, border, borderAlpha)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    if bg then f:SetBackdropColor(rgba(bg)) else f:SetBackdropColor(0, 0, 0, 0) end
    if border then f:SetBackdropBorderColor(rgba(border, borderAlpha)) else f:SetBackdropBorderColor(0, 0, 0, 0) end
    return f
end

local function CreateText(parent, font, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "SlotPortFontNormal")
    fs:SetTextColor(rgba(color or C.text))
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local BTN_STYLES = {
    primary = { bg = C.accent, bgHi = C.accentHi, border = C.accent,  text = C.onAccent, textHi = C.onAccent },
    outline = { bg = nil,      bgHi = C.card,     border = C.lineHi,  text = C.text,     textHi = C.text },
    ghost   = { bg = nil,      bgHi = C.card,     border = nil,       text = C.muted,    textHi = C.text },
    danger  = { bg = nil,      bgHi = C.card,     border = nil,       text = C.danger,   textHi = C.danger },
    active  = { bg = C.accent, bgA = 0.16, bgHi = C.accent, bgHiA = 0.24, border = nil, text = C.accent, textHi = C.accent },
}

local function PaintButton(b, hover)
    local st = b._st
    local bg = hover and st.bgHi or st.bg
    if bg then
        local a = hover and st.bgHiA or st.bgA or 1
        b:SetBackdropColor(rgba(bg, a))
    else
        b:SetBackdropColor(0, 0, 0, 0)
    end
    if st.border then b:SetBackdropBorderColor(rgba(st.border)) else b:SetBackdropBorderColor(0, 0, 0, 0) end
    b.text:SetTextColor(rgba(hover and st.textHi or st.text))
end

local function CreateButton(parent, label, style, onClick, minW)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetHeight(28)
    b.text = b:CreateFontString(nil, "OVERLAY", "SlotPortFontNormal")
    b.text:SetPoint("CENTER", 0, 0)
    b._st = BTN_STYLES[style or "outline"]
    b._minW = minW or 0
    function b:SetLabel(t)
        self.text:SetText(t or "")
        self:SetWidth(math.max(self._minW, self.text:GetStringWidth() + 26))
    end
    function b:SetStyle(name)
        self._st = BTN_STYLES[name]
        PaintButton(self, false)
    end
    b:SetLabel(label)
    PaintButton(b, false)
    b:SetScript("OnEnter", function(self) PaintButton(self, true) end)
    b:SetScript("OnLeave", function(self) PaintButton(self, false) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Square check mark: state is "none", "part" or "full"
local function CreateCheckMark(parent, size)
    local box = CreateBox(parent, C.side, C.lineHi)
    box:SetSize(size or 16, size or 16)
    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("CENTER", 0, 0)
    tick:SetSize((size or 16) - 2, (size or 16) - 2)
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetDesaturated(true)
    tick:SetVertexColor(rgba(C.onAccent))
    local dash = box:CreateTexture(nil, "OVERLAY")
    dash:SetPoint("CENTER", 0, 0)
    dash:SetSize(8, 2)
    dash:SetColorTexture(rgba(C.onAccent))
    box.tick, box.dash = tick, dash
    function box:SetState(state)
        if state == "none" then
            self:SetBackdropColor(rgba(C.side))
            self:SetBackdropBorderColor(rgba(C.lineHi))
            self.tick:Hide(); self.dash:Hide()
        else
            self:SetBackdropColor(rgba(C.accent))
            self:SetBackdropBorderColor(rgba(C.accent))
            self.tick:SetShown(state == "full")
            self.dash:SetShown(state == "part")
        end
    end
    box:SetState("none")
    return box
end

-- Slim scroll frame with a thin custom scroll bar.
-- Returns scroll, content. onWidth(w) is called whenever the viewport width changes.
local function CreateScroll(parent, onWidth)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(5)
    track:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    5, 0)
    track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5, 0)
    local trackBG = track:CreateTexture(nil, "BACKGROUND")
    trackBG:SetAllPoints()
    trackBG:SetColorTexture(rgba(C.line, 0.6))

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(5)
    thumb:SetHeight(30)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(rgba(C.lineHi))

    local function update()
        local range  = scroll:GetVerticalScrollRange() or 0
        local trackH = track:GetHeight() or 0
        if range <= 0.5 or trackH <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local viewH  = scroll:GetHeight() or 0
        local thumbH = math.max(24, trackH * viewH / (viewH + range))
        local pos    = (scroll:GetVerticalScroll() / range) * (trackH - thumbH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -pos)
    end
    scroll.UpdateBar = update

    scroll:SetScript("OnScrollRangeChanged", update)
    scroll:SetScript("OnVerticalScroll", update)
    scroll:SetScript("OnSizeChanged", function(_, w)
        content:SetWidth(w)
        if onWidth then onWidth(w) end
        update()
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 42)))
    end)

    local drag
    thumb:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        drag = { y = y / self:GetEffectiveScale(), s = scroll:GetVerticalScroll() }
        self:SetScript("OnUpdate", function()
            local _, cy = GetCursorPosition()
            cy = cy / thumb:GetEffectiveScale()
            local range = scroll:GetVerticalScrollRange() or 0
            local free  = track:GetHeight() - thumb:GetHeight()
            if free <= 0 or not drag then return end
            local new = drag.s + (drag.y - cy) / free * range
            scroll:SetVerticalScroll(math.min(range, math.max(0, new)))
        end)
    end)
    local function stopDrag() thumb:SetScript("OnUpdate", nil) end
    thumb:SetScript("OnMouseUp", stopDrag)
    thumb:SetScript("OnHide", stopDrag)

    return scroll, content
end

local function CreateSearchBox(parent, placeholder, onChange)
    local box = CreateBox(parent, C.side, C.line)
    box:SetHeight(28)
    local eb = CreateFrame("EditBox", nil, box)
    eb:SetPoint("TOPLEFT", 10, -1)
    eb:SetPoint("BOTTOMRIGHT", -10, 1)
    eb:SetFontObject("SlotPortFontNormal")
    eb:SetTextColor(rgba(C.text))
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(40)
    local ph = CreateText(box, "SlotPortFontNormal", C.dim)
    ph:SetPoint("LEFT", 10, 0)
    ph:SetText(placeholder)
    eb:SetScript("OnTextChanged", function(self)
        ph:SetShown(self:GetText() == "")
        onChange(self:GetText())
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function() box:SetBackdropBorderColor(rgba(C.accent)) end)
    eb:SetScript("OnEditFocusLost",   function() box:SetBackdropBorderColor(rgba(C.line)) end)
    box.editBox = eb
    return box
end

SlotPort.ui = {
    WHITE = WHITE, C = C, rgba = rgba,
    CreateBox = CreateBox, CreateText = CreateText, CreateButton = CreateButton,
    CreateCheckMark = CreateCheckMark, CreateScroll = CreateScroll, CreateSearchBox = CreateSearchBox,
}
