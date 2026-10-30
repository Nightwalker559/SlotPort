-- ============================================================
-- SlotPort diagnostics.
--   /sp debug [slots | bonus | spell <id>]   - bar/slot overview (see DebugCommand)
--   /run SlotPort.DebugTestNativeEncoding()
--   /run SlotPort.DebugCountRealExport()
-- The /run helpers are meant for troubleshooting export/import issues,
-- e.g. corrupted round-trips on the native !SP3! codec.
-- ============================================================

local function L(key) return (SlotPortL and SlotPortL[key]) or key end

-- ----------------------------------------------------------
-- /sp debug
-- ----------------------------------------------------------
function SlotPort.DebugCommand(arg)
    if arg == "slots" then
        print("|cff00ccffSlotPort Debug:|r " .. L("DBG_SLOTS_HEADER"))
        local found = 0
        for s = 1, 200 do
            local aType, id = GetActionInfo(s)
            if aType then
                -- texture=nil with a type set is what makes SlotPort treat
                -- a slot as empty (see slotRangeHasContent in Core/Bars.lua)
                print(string.format("  Slot %3d: type=%-14s id=%s  texture=%s  HasAction=%s", s,
                    tostring(aType), tostring(id), tostring(GetActionTexture(s)),
                    tostring(C_ActionBar and C_ActionBar.HasAction and C_ActionBar.HasAction(s))))
                found = found + 1
            end
        end
        if found == 0 then print(L("DBG_SLOTS_NONE")) end
        print(string.format(L("DBG_SLOTS_TOTAL"), found))
        return
    end

    -- Dumps Blizzard's own slot classification (C_ActionBar bonus/override
    -- bar indices + page -> bar frame) so the hard-coded slot ranges in
    -- Core/Bars.lua can be checked against the real values in-game.
    if arg == "bonus" then
        print("|cff00ccffSlotPort Debug:|r Blizzard bar classification")
        local api = C_ActionBar
        if not api then
            print("  C_ActionBar: n/a")
            return
        end
        local function call(name, ...)
            local f = api[name]
            if not f then return "n/a" end
            local ok, v = pcall(f, ...)
            return ok and tostring(v) or "error"
        end
        print(string.format("  BonusBarIndex=%s  BonusBarOffset=%s  HasBonusActionBar=%s",
            call("GetBonusBarIndex"), call("GetBonusBarOffset"), call("HasBonusActionBar")))
        print(string.format("  Vehicle=%s  Override=%s  TempShapeshift=%s  Extra=%s  MultiCast=%s",
            call("GetVehicleBarIndex"), call("GetOverrideBarIndex"),
            call("GetTempShapeshiftBarIndex"), call("GetExtraBarIndex"),
            call("GetMultiCastBarIndex")))
        for page = 1, 15 do
            local first, last = (page - 1) * 12 + 1, page * 12
            local frameName = "-"
            if MultiActionBar_GetBarForPage then
                local ok, frame = pcall(MultiActionBar_GetBarForPage, page)
                if ok and frame and frame.GetName then frameName = tostring(frame:GetName()) end
            end
            local used = 0
            for s = first, last do
                if GetActionInfo(s) then used = used + 1 end
            end
            print(string.format("  Page %2d  Slots %3d-%-3d  bonus(first/last)=%s/%s  frame=%s  filled=%d",
                page, first, last,
                call("GetBonusBarIndexForSlot", first), call("GetBonusBarIndexForSlot", last),
                frameName, used))
        end
        return
    end

    if arg and arg:match("^spell%s+%d+") then
        local spellID = tonumber(arg:match("(%d+)"))
        print("|cff00ccffSlotPort Debug:|r " .. string.format(L("DBG_SPELL_SEARCH"), spellID))
        print("  C_Spell.GetSpellName: " .. tostring(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)))
        print("  IsPlayerSpell: " .. tostring(IsPlayerSpell and IsPlayerSpell(spellID)))
        print("  IsSpellKnown: " .. tostring(IsSpellKnown and IsSpellKnown(spellID)))

        -- Base/override resolution, form, and whether picking the spell up works at all
        local book = C_SpellBook
        local function probe(label, fn, ...)
            local ok, a = pcall(fn, ...)
            print("  " .. label .. ": " .. tostring(ok and a or ("error: " .. tostring(a))))
        end
        if book and book.FindBaseSpellByID then probe("FindBaseSpellByID", book.FindBaseSpellByID, spellID) end
        if book and book.FindSpellOverrideByID then probe("FindSpellOverrideByID", book.FindSpellOverrideByID, spellID) end
        if book and book.IsSpellInSpellBook then probe("IsSpellInSpellBook", book.IsSpellInSpellBook, spellID, Enum.SpellBookSpellBank.Player, true) end
        if GetShapeshiftForm then print("  GetShapeshiftForm: " .. tostring(GetShapeshiftForm())) end
        if C_Spell and C_Spell.PickupSpell then
            ClearCursor()
            local ok, err = pcall(C_Spell.PickupSpell, spellID)
            print("  PickupSpell -> cursor: " .. tostring(ok and GetCursorInfo() or ("error: " .. tostring(err))))
            ClearCursor()
        end

        local foundAny = false
        -- Player bank: via skill lines (correct API, see Core/Cache.lua)
        SlotPort.ForEachSpellBookItem(Enum.SpellBookSpellBank.Player, function(slot, info)
            if info.spellID == spellID or info.actionID == spellID then
                foundAny = true
                ClearCursor()
                local ok = pcall(C_SpellBook.PickupSpellBookItem, slot, Enum.SpellBookSpellBank.Player)
                local picked = ok and GetCursorInfo() or "nothing"
                ClearCursor()
                print(string.format("  [Player] slot=%d  itemType=%s  spellID=%s  actionID=%s  name=%s  bookPickup=%s",
                    slot, tostring(info.itemType), tostring(info.spellID), tostring(info.actionID), tostring(info.name), tostring(picked)))
            end
            return false
        end)
        -- Pet bank
        SlotPort.ForEachSpellBookItem(Enum.SpellBookSpellBank.Pet, function(slot, info)
            if info.spellID == spellID or info.actionID == spellID then
                foundAny = true
                print(string.format("  [Pet] slot=%d  itemType=%s  spellID=%s  actionID=%s  name=%s",
                    slot, tostring(info.itemType), tostring(info.spellID), tostring(info.actionID), tostring(info.name)))
            end
            return false
        end)

        if not foundAny then
            print("  |cffff4444" .. L("DBG_SPELL_NOT_FOUND") .. "|r")
        end
        return
    end

    print("|cff00ccffSlotPort Debug:|r")
    print("  Version:    " .. SlotPort.version)
    print("  DB:         " .. tostring(SlotPort.db ~= nil))
    print("  ElvUI:      " .. tostring(SlotPort:HasElvUI()))

    SlotPort:DetectElvUIBars()

    -- Registered bars
    print(string.format("  " .. L("DBG_BARS"), #SlotPort.BARS))
    for i, bar in ipairs(SlotPort.BARS) do
        local tag = bar.isElvUI and " [ElvUI]" or bar.isSkyriding and " [Sky]" or bar.isDefaultBar and " [Default]" or ""
        local bonusIdx, bonusActive = SlotPort.GetBonusBarState(bar.startSlot)
        print(string.format("    [%d] %-22s  Slots %3d-%-3d  content=%-5s  enabled=%-5s  bonus=%s/%s%s",
            i, bar.name, bar.startSlot, bar.endSlot,
            tostring(bar.hasContent), tostring(bar.isEnabled),
            tostring(bonusIdx), tostring(bonusActive), tag))
    end

    if SlotPort:HasElvUI() then
        -- -- ElvUI mode -----------------------------------------------
        print("|cff00ccffSlotPort Debug:|r |cff00aaffElvUI active|r")
        print("  ElvUI Bar Frames (1-15):")
        for barNum = 1, 15 do
            -- ElvUI names bars differently depending on version:
            -- Standard: ElvUI_Bar1 ... ElvUI_Bar15
            -- Alternative: ActionBar1 or other names
            local frame = _G["ElvUI_Bar" .. barNum]
            local btn1  = _G["ElvUI_Bar" .. barNum .. "Button1"]
            -- Count buttons directly (GetElvUIBarSlotCount isn't global)
            local count = 0
            if btn1 then
                for s = 1, 12 do
                    if _G["ElvUI_Bar" .. barNum .. "Button" .. s] then count = count + 1
                    else break end
                end
                -- Read from ElvUI DB if available
                if ElvUI and ElvUI[1] and ElvUI[1].db and ElvUI[1].db.actionbar then
                    local cfg = ElvUI[1].db.actionbar["bar" .. barNum]
                    if cfg and tonumber(cfg.buttons) then count = tonumber(cfg.buttons) end
                end
            end
            if frame or btn1 then
                local shown     = frame and frame:IsShown() or "n/a"
                local dbEnabled = "n/a"
                local baseSlot  = "?"
                if ElvUI and ElvUI[1] and ElvUI[1].db and ElvUI[1].db.actionbar then
                    local cfg = ElvUI[1].db.actionbar["bar" .. barNum]
                    dbEnabled = cfg and tostring(cfg.enabled) or "no cfg"
                end
                if btn1 then
                    local s = btn1:GetAttribute("action")
                    if not s then
                        local state = btn1:GetAttribute("state")
                        if state then s = btn1:GetAttribute("labaction-" .. state) end
                    end
                    if not s then s = btn1:GetAttribute("labaction-default") end
                    baseSlot = tostring(s or "?")
                end
                local btnType, btnAction = SlotPort:GetElvUIButtonInfo(barNum, 1)
                print(string.format("    ElvUI_Bar%-2d  shown=%-5s  db=%-8s  buttons=%-2d  slot1=%-4s  btn1=%s/%s",
                    barNum, tostring(shown), dbEnabled, count, baseSlot,
                    tostring(btnType), tostring(btnAction)))
            end
        end
    else
        -- -- Default UI mode -------------------------------------------
        print("|cff00ccffSlotPort Debug:|r |cffaaffaaDefault UI|r")
        print("  Blizzard Bar Frames:")
        local blizzFrames = {
            { name = "MainActionBar",       slots = "1-12"    },
            { name = "MultiBarRight",       slots = "25-36"   },
            { name = "MultiBarLeft",        slots = "37-48"   },
            { name = "MultiBarBottomRight", slots = "49-60"   },
            { name = "MultiBarBottomLeft",  slots = "61-72"   },
            { name = "MultiBar5",           slots = "145-156" },
            { name = "MultiBar6",           slots = "157-168" },
            { name = "MultiBar7",           slots = "169-180" },
        }
        for _, entry in ipairs(blizzFrames) do
            local frame = _G[entry.name]
            local shown = frame and frame:IsShown() or false
            print(string.format("    %-26s slots=%-9s shown=%s",
                entry.name, entry.slots, tostring(shown)))
        end
    end
    print("|cff888888SlotPort:|r " .. L("DBG_TIP"))
end

-- Diagnostic helper: run "/run SlotPort.DebugTestNativeEncoding()" in-game.
-- Writes the report into the SlotPort export box (if the window is open)
-- so it can be selected/Ctrl+C'd like a normal export - WoW's own chat
-- frame frequently fails to make multi-line print() output copyable.
-- Falls back to chat print() if the window isn't open.
--
-- IMPORTANT: never log raw binary values (CompressString output,
-- DecodeBase64 output) directly - they contain embedded NUL bytes, and
-- WoW's EditBox:SetText() treats the string as a C string internally,
-- truncating (or blanking) everything from the first NUL onward. Only
-- lengths, booleans, and confirmed-printable text (base64, decompressed
-- plain text) are safe to include.
function SlotPort.DebugTestNativeEncoding()
    local lines = {}
    local function log(...)
        local parts = { ... }
        for i, v in ipairs(parts) do parts[i] = tostring(v) end
        lines[#lines + 1] = table.concat(parts, " ")
    end

    log("C_EncodingUtil available =", tostring(SlotPort.NativeCompressAvailable()))
    if not SlotPort.NativeCompressAvailable() then
        SlotPort.DebugTestNativeEncoding_Output(lines)
        return
    end

    local method = Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    log("Enum.CompressionMethod.Deflate =", tostring(method))

    local test = "SLOTPORT:v1|1:spell:133:"
    local ok1, compressed = pcall(C_EncodingUtil.CompressString, test, method)
    log("CompressString(test, method) ok =", ok1, " byteLen =", ok1 and compressed and #compressed or "n/a")

    local ok2, compressed2 = pcall(C_EncodingUtil.CompressString, test)
    log("CompressString(test) ok =", ok2, " byteLen =", ok2 and compressed2 and #compressed2 or "n/a")

    local c = compressed or compressed2
    if not c then SlotPort.DebugTestNativeEncoding_Output(lines); return end

    local ok3, encoded = pcall(C_EncodingUtil.EncodeBase64, c)
    log("EncodeBase64 ok =", ok3, " result =", ok3 and tostring(encoded) or "n/a")
    if not ok3 or not encoded then SlotPort.DebugTestNativeEncoding_Output(lines); return end

    local ok4, decoded = pcall(C_EncodingUtil.DecodeBase64, encoded)
    log("DecodeBase64 ok =", ok4, " byteLen =", ok4 and decoded and #decoded or "n/a")

    local ok5, decompressed = pcall(C_EncodingUtil.DecompressString, decoded, method)
    log("DecompressString(data, method) ok =", ok5, " result =", ok5 and tostring(decompressed) or "n/a")

    local ok6, decompressed2 = pcall(C_EncodingUtil.DecompressString, decoded)
    log("DecompressString(data) ok =", ok6, " result =", ok6 and tostring(decompressed2) or "n/a")

    log("short roundtrip match =", tostring((decompressed or decompressed2) == test))

    -- Large-payload test: reproduces corruption that only shows up on
    -- realistic-sized export strings (short test above always passed).
    local parts = { "SLOTPORT:v1" }
    for i = 1, 45 do
        parts[#parts + 1] = string.format("%d:spell:%d:", i, 100000 + i)
    end
    local bigTest = table.concat(parts, "|")
    log("big test length =", #bigTest, " entries =", #parts)

    local bigEncoded = SlotPort.NativeCompress(bigTest)
    log("big NativeCompress ok =", bigEncoded ~= nil, " encodedLen =", bigEncoded and #bigEncoded or "n/a")
    if not bigEncoded then SlotPort.DebugTestNativeEncoding_Output(lines); return end

    local bigDecoded, bigErr = SlotPort.NativeDecompress(bigEncoded)
    log("big NativeDecompress ok =", bigDecoded ~= nil, " err =", tostring(bigErr))
    if not bigDecoded then SlotPort.DebugTestNativeEncoding_Output(lines); return end

    log("big roundtrip match =", tostring(bigDecoded == bigTest))
    if bigDecoded ~= bigTest then
        log("big roundtrip LENGTH orig =", #bigTest, " decoded =", #bigDecoded)
        -- Find first mismatching byte (safe: bigTest/bigDecoded are the
        -- known plain-text payload, not raw compressed binary)
        local n = math.min(#bigTest, #bigDecoded)
        for i = 1, n do
            if bigTest:sub(i, i) ~= bigDecoded:sub(i, i) then
                log("first mismatch at byte", i,
                    " orig=", bigTest:sub(math.max(1, i - 5), i + 5),
                    " decoded=", bigDecoded:sub(math.max(1, i - 5), i + 5))
                break
            end
        end
    end

    SlotPort.DebugTestNativeEncoding_Output(lines)
end

-- Writes debug lines into the export box (copyable via Ctrl+C) if the
-- SlotPort window is open; otherwise falls back to chat.
function SlotPort.DebugTestNativeEncoding_Output(lines)
    local report = "SlotPort debug report:\n" .. table.concat(lines, "\n")

    -- Safety net: strip any stray NUL/control bytes (besides newline) that
    -- would otherwise truncate/blank the EditBox's underlying C string.
    -- Done via a manual byte scan (string.byte/char), not a gsub pattern -
    -- embedding raw control bytes in a "[...]" pattern class caused a
    -- "malformed pattern" error in-game, so patterns are avoided entirely here.
    do
        local buf = {}
        for i = 1, #report do
            local b = report:byte(i)
            if b == 0 or (b < 32 and b ~= 10) then
                buf[i] = "?"
            else
                buf[i] = report:sub(i, i)
            end
        end
        report = table.concat(buf)
    end

    -- The export popup has a single-line edit box (newlines are dropped), so
    -- the report is shown as one line with " ; " separators. The popup
    -- escapes "|" itself.
    local oneLine = (report:gsub("\n", " ; "))
    if SlotPortGUI and SlotPortGUI.ShowExportString then
        SlotPortGUI:ShowExportString(oneLine)
        print("|cff00ccffSlotPort:|r Debug report opened - press Ctrl+C to copy it.")
    else
        print("|cff00ccffSlotPort:|r " .. oneLine)
    end
end

-- Diagnostic helper: run "/run SlotPort.DebugCountRealExport()" in-game
-- AFTER selecting the same slots that showed the mismatch. Performs a real
-- export, decodes it back, and reports exactly how many entries the split
-- produces vs. how many the exporter says it wrote - pinpoints whether the
-- mismatch is in export (written vs. actual parts), the codec round-trip,
-- or the import-side split.
function SlotPort.DebugCountRealExport()
    local lines = {}
    local function log(...)
        local parts = { ... }
        for i, v in ipairs(parts) do parts[i] = tostring(v) end
        lines[#lines + 1] = table.concat(parts, " ")
    end

    local str, writtenOrErr = SlotPort:Export()
    if not str then
        log("Export failed:", tostring(writtenOrErr))
        SlotPort.DebugTestNativeEncoding_Output(lines)
        return
    end
    local written = writtenOrErr
    log("Export() written =", written)
    log("Export string length =", #str, " prefix =", str:sub(1, 5))

    local decoded, err = SlotPort.DecodeFromExport(str)
    if not decoded then
        log("DecodeFromExport failed:", tostring(err))
        SlotPort.DebugTestNativeEncoding_Output(lines)
        return
    end
    log("Decoded length =", #decoded)

    local header = decoded:match("^%s*([^\n|]+)")
    log("Header =", tostring(header))

    local entries = SlotPort.SplitEntries(decoded)

    log("Total entries (incl. header) =", #entries)
    log("Entries after header =", #entries - 1)
    log("Matches written count =", tostring(#entries - 1 == written))

    -- List every entry's first token (slot number) to spot duplicates/bogus splits
    for i = 2, #entries do
        local slotStr = entries[i]:match("^(%d+):") or "??"
        log(string.format("  entry[%d] slot=%s raw=%s", i - 1, slotStr,
            entries[i]:sub(1, 60)))
    end

    SlotPort.DebugTestNativeEncoding_Output(lines)
end
