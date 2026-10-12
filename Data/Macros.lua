-- ============================================================
-- Export format:  SLOTPORTMACRO:v1|name:iconID:body:g|name:iconID:body:c|...
-- Escaping:        | -> ||   ;   : in name -> {CL}   ;   \n in body -> {NL}
-- Scope tag:       :g = global macro   :c = character macro
-- Backwards compat: no scope tag -> character macro
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

SlotPort.selectedMacros = {}

-- ----------------------------------------------------------
-- Escape helpers
-- ----------------------------------------------------------
local function escapeName(s)
    return tostring(s or ""):gsub(":", "{CL}"):gsub("|", "||")
end

local function escapeBody(s)
    return tostring(s or ""):gsub("|", "||"):gsub("\n", "{NL}")
end

local function unescapeName(s)
    return (s or ""):gsub("{CL}", ":"):gsub("||", "|")
end

local function unescapeBody(s)
    return (s or ""):gsub("{NL}", "\n"):gsub("||", "|")
end

-- ----------------------------------------------------------
-- List all macros (global + character)
-- scope: "g" = global (1..numGlobal), "c" = character (121..120+numChar)
-- ----------------------------------------------------------
function SlotPort:GetAllMacros()
    local result = {}
    local numGlobal, numChar = GetNumMacros()
    for i = 1, numGlobal do
        local name, icon, body = GetMacroInfo(i)
        if name and name ~= "" then
            result[#result + 1] = { index = i, name = name, icon = icon, body = body or "", scope = "g" }
        end
    end
    for i = 121, 120 + numChar do
        local name, icon, body = GetMacroInfo(i)
        if name and name ~= "" then
            result[#result + 1] = { index = i, name = name, icon = icon, body = body or "", scope = "c" }
        end
    end
    return result
end

-- ----------------------------------------------------------
-- Export
-- ----------------------------------------------------------
function SlotPort:ExportMacros()
    if self:GetSelectedMacroCount() == 0 then
        return nil, L("NO_MACROS_SELECTED")
    end
    local parts   = { "SLOTPORTMACRO:v1" }
    local written = 0
    for _, m in ipairs(self:GetAllMacros()) do
        if self.selectedMacros[m.index] then
            parts[#parts + 1] = escapeName(m.name) .. ":" .. tostring(m.icon or "") .. ":" .. escapeBody(m.body) .. ":" .. m.scope
            written = written + 1
        end
    end
    if written == 0 then return nil, L("NO_MACROS_SELECTED") end
    local raw = table.concat(parts, "|")
    return SlotPort.EncodeForExport(raw), written
end

-- ----------------------------------------------------------
-- Import
-- Existing macro (same name) -> EditMacro.
-- New macro -> CreateMacro with the correct scope.
-- Backwards compatible: no scope tag -> character macro.
-- ----------------------------------------------------------
function SlotPort:ImportMacros(str)
    if not str or str:match("^%s*$") then
        return false, L("EMPTY_STRING")
    end

    -- Decode SP3 format if needed
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, 5) == "!SP3!" then
        local decoded, err = SlotPort.DecodeFromExport(str)
        if not decoded then
            return false, L("MACRO_INVALID_FORMAT") .. (err and (" (" .. err .. ")") or "")
        end
        str = decoded
    end

    local header = str:match("^%s*([^\n|]+)")
    if header ~= "SLOTPORTMACRO:v1" then
        return false, L("MACRO_INVALID_FORMAT")
    end

    local entries = SlotPort.SplitEntries(str)

    local imported = 0
    local skipped  = 0
    local errors   = {}

    for i = 2, #entries do
        -- Scope tag optional: name:icon:body:g or name:icon:body:c or name:icon:body (legacy)
        local nameEsc, iconStr, bodyEsc, scopeTag = entries[i]:match("^([^:]*):([^:]*):(.*):([gc])$")
        if not nameEsc then
            -- Backwards compatibility: no scope tag -> character macro
            nameEsc, iconStr, bodyEsc = entries[i]:match("^([^:]*):([^:]*):(.*)$")
            scopeTag = "c"
        end

        if not nameEsc then
            skipped = skipped + 1
        else
            local name = unescapeName(nameEsc)
            local body = unescapeBody(bodyEsc)
            -- Icon: macros with "#show"/"#showtooltip" get their icon dynamically,
            -- so they are created with the default question-mark icon (restoring
            -- the exported icon would freeze it). Macros without it keep the icon
            -- the user set manually, so it is restored from the export.
            local DEFAULT_ICON = "INV_Misc_QuestionMark"
            local icon = DEFAULT_ICON
            local exportedIcon = tonumber(iconStr)
            if exportedIcon and exportedIcon > 0 and not body:lower():find("#show", 1, true) then
                icon = exportedIcon
            end
            local perChar = (scopeTag == "c")

            local existingIdx = GetMacroIndexByName(name)
            if existingIdx and existingIdx > 0 then
                local editOk = pcall(EditMacro, existingIdx, name, icon, body)
                if not editOk and icon ~= DEFAULT_ICON then
                    editOk = pcall(EditMacro, existingIdx, name, DEFAULT_ICON, body)
                end
                if editOk then
                    imported = imported + 1
                else
                    skipped = skipped + 1
                    table.insert(errors, string.format(L("MACRO_EDIT_FAILED"), name))
                end
            else
                local ok, idx = pcall(CreateMacro, name, icon, body, perChar)
                if not ok and icon ~= DEFAULT_ICON then
                    -- exported icon ID not usable here -> fall back to the default icon
                    ok, idx = pcall(CreateMacro, name, DEFAULT_ICON, body, perChar)
                end
                -- Validation: global macros have index < 121, character macros >= 121
                local valid = ok and idx and ((perChar and idx >= 121) or (not perChar and idx < 121))
                if valid then
                    imported = imported + 1
                else
                    skipped = skipped + 1
                    table.insert(errors, string.format(L("MACRO_LIMIT_REACHED"), name))
                end
            end
        end
    end

    local msg = string.format(L("MACROS_IMPORTED"), imported)
    if skipped > 0 then msg = msg .. string.format(L("SKIPPED"), skipped) end
    if #errors > 0  then msg = msg .. L("HINTS_PREFIX") .. table.concat(errors, "\n") end
    return true, msg
end

-- ----------------------------------------------------------
-- Selection
-- ----------------------------------------------------------
function SlotPort:ToggleMacro(index)
    self.selectedMacros[index] = not self.selectedMacros[index] or nil
end

function SlotPort:SelectAllMacros(scope)
    for _, m in ipairs(self:GetAllMacros()) do
        if not scope or m.scope == scope then
            self.selectedMacros[m.index] = true
        end
    end
end

function SlotPort:DeselectAllMacros(scope)
    if not scope then
        wipe(self.selectedMacros)
    else
        for _, m in ipairs(self:GetAllMacros()) do
            if m.scope == scope then
                self.selectedMacros[m.index] = nil
            end
        end
    end
end

function SlotPort:GetSelectedMacroCount()
    local c = 0
    for _ in pairs(self.selectedMacros) do c = c + 1 end
    return c
end

-- ----------------------------------------------------------
-- Delete all selected macros
-- Deletes by name (not index) so removing one macro can't
-- shift the indices of the others mid-loop.
-- ----------------------------------------------------------
function SlotPort:DeleteSelectedMacros()
    if self:GetSelectedMacroCount() == 0 then
        return false, L("NO_MACROS_SELECTED")
    end

    local names = {}
    for _, m in ipairs(self:GetAllMacros()) do
        if self.selectedMacros[m.index] then
            names[#names + 1] = m.name
        end
    end

    local deleted = 0
    for _, name in ipairs(names) do
        local idx = GetMacroIndexByName(name)
        if idx and idx > 0 then
            local ok = pcall(DeleteMacro, idx)
            if ok then deleted = deleted + 1 end
        end
    end

    wipe(self.selectedMacros)
    return true, deleted
end
