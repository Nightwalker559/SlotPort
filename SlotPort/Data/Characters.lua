-- ============================================================
-- Character snapshots: the action bar layout of every character that logged
-- in, saved account-wide so a new character can copy it without first
-- logging into the old one.
--
-- SlotPortDB.global.chars["Name-Realm"] = {
--     name, realm, class, seen,
--     macros = <SLOTPORTMACRO export string of the character macros> | nil,
--     macroCount,
--     specs = { [specID] = { name, t, str = <SLOTPORT export string>, filled } },
-- }
-- Action bars are saved per specialization, so the slots live under the spec
-- (specID 0 = no specialization yet); character macros are per character.
-- The stored strings are the normal export format, so "copy" and import work
-- exactly like a manual export.
-- ============================================================

local L = function(key) return (SlotPortL and SlotPortL[key]) or key end

local SNAPSHOT_DELAY = 5   -- quiet time after the last change before saving
local NO_SPEC        = 0

local dirty        = true  -- the layout changed since the last snapshot
local lastChange   = 0
local timerPending = false

-- ----------------------------------------------------------
-- Current character
-- ----------------------------------------------------------
local function currentSpec()
    local api = C_SpecializationInfo
    local index = api and api.GetSpecialization and api.GetSpecialization()
    if not index then return NO_SPEC, nil end
    local specID, specName = api.GetSpecializationInfo(index)
    return specID or NO_SPEC, specName
end

local function charKey(name, realm)
    return name .. "-" .. realm
end

-- Key of the logged-in character and its active specID
function SlotPort:GetCurrentSnapshotKeys()
    return charKey(UnitName("player"), GetRealmName()), (currentSpec())
end

-- Saved characters live in the account-wide global table; created on demand
-- because AceDB strips empty default tables again at logout.
local function charStore()
    local global = SlotPort.db and SlotPort.db.global
    if not global then return nil end
    global.chars = global.chars or {}
    return global.chars
end

-- ----------------------------------------------------------
-- Snapshot
-- ----------------------------------------------------------
local function exportCharMacros()
    local list = {}
    for _, m in ipairs(SlotPort:GetAllMacros()) do
        if m.scope == "c" then list[#list + 1] = m end
    end
    if #list == 0 then return nil, 0 end
    return SlotPort:ExportMacroList(list)
end

-- Saves the layout of the logged-in character. Needs up-to-date SlotPort.BARS
-- (callers refresh them first). An entirely empty layout (fresh character,
-- bars just reset) never replaces an earlier snapshot.
function SlotPort:SnapshotCurrentCharacter()
    if not dirty then return end
    local chars = charStore()
    if not chars then return end

    local name, realm = UnitName("player"), GetRealmName()
    local slotStr, _, filled = self:ExportSlots(self:CollectAllSlots())
    dirty = false
    if not slotStr or filled == 0 then return end

    local key = charKey(name, realm)
    local entry = chars[key] or {}
    chars[key] = entry
    entry.name, entry.realm = name, realm
    entry.class = select(2, UnitClass("player"))
    entry.seen  = time()
    entry.macros, entry.macroCount = exportCharMacros()

    local specID, specName = currentSpec()
    entry.specs = entry.specs or {}
    entry.specs[specID] = { name = specName, t = time(), str = slotStr, filled = filled }
end

-- Refreshes the bar list, then saves if something changed. Used by the quiet-time
-- timer, logout and the characters page.
function SlotPort:FlushSnapshot()
    if not dirty or InCombatLockdown() then return end
    self:RefreshBarContent()
    self:RefreshElvUIBars()
    self:SnapshotCurrentCharacter()
end

-- ----------------------------------------------------------
-- Change tracking: slot/macro changes arrive in bursts (spec switch, dragging),
-- so the snapshot waits until things have been quiet for SNAPSHOT_DELAY.
-- ----------------------------------------------------------
local function onTimer()
    timerPending = false
    local remaining = lastChange + SNAPSHOT_DELAY - GetTime()
    if remaining > 0 then
        timerPending = true
        C_Timer.After(remaining, onTimer)
        return
    end
    SlotPort:FlushSnapshot()
end

local function markChanged()
    dirty = true
    lastChange = GetTime()
    if not timerPending then
        timerPending = true
        C_Timer.After(SNAPSHOT_DELAY, onTimer)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("UPDATE_MACROS")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- a snapshot skipped during combat is retried now
        if dirty then markChanged() end
    elseif event == "PLAYER_LOGOUT" then
        -- the game state may already be shutting down: never let it error
        pcall(SlotPort.FlushSnapshot, SlotPort)
    else
        markChanged()
    end
end)

-- ----------------------------------------------------------
-- Queries and actions for the characters page
-- ----------------------------------------------------------

-- Saved characters, current one first, then most recently seen. Each entry:
-- { key, name, realm, class, seen, macroCount, specs = { { id, name, t, filled }, ... } }
-- onlyClass (class token, optional) keeps only characters of that class; the
-- second return value is how many characters that filter left out.
function SlotPort:GetSnapshotChars(onlyClass)
    local chars = charStore()
    local result, hidden = {}, 0
    if not chars then return result, hidden end

    local currentKey = self:GetCurrentSnapshotKeys()
    for key, entry in pairs(chars) do
        if onlyClass and entry.class ~= onlyClass then
            hidden = hidden + 1
        else
            local specs = {}
            for specID, spec in pairs(entry.specs or {}) do
                specs[#specs + 1] = {
                    id = specID, name = spec.name or L("CHARS_NO_SPEC"),
                    t = spec.t, filled = spec.filled,
                }
            end
            table.sort(specs, function(a, b) return a.name < b.name end)
            result[#result + 1] = {
                key = key, name = entry.name, realm = entry.realm, class = entry.class,
                seen = entry.seen or 0, macroCount = entry.macroCount or 0, specs = specs,
            }
        end
    end
    table.sort(result, function(a, b)
        if (a.key == currentKey) ~= (b.key == currentKey) then return a.key == currentKey end
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.key < b.key
    end)
    return result, hidden
end

-- Export string for pasting into Import: character macros first (so the slots
-- that use them find them), then the slots of one specialization.
function SlotPort:GetSnapshotString(key, specID)
    local chars = charStore()
    local entry = chars and chars[key]
    local spec = entry and entry.specs and entry.specs[specID]
    if not spec then return nil end
    if entry.macros then return entry.macros .. " " .. spec.str end
    return spec.str
end

-- Deletes one specialization, or the whole character when specID is nil. A
-- character without any spec left is dropped as well.
function SlotPort:DeleteSnapshot(key, specID)
    local chars = charStore()
    local entry = chars and chars[key]
    if not entry then return end
    if specID ~= nil and entry.specs then
        entry.specs[specID] = nil
        if next(entry.specs) ~= nil then return end
    end
    chars[key] = nil
end
