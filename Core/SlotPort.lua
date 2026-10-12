SlotPort = {}
-- Single source of truth: read the version from the .toc file instead of
-- maintaining a second hardcoded copy here.
SlotPort.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("SlotPort", "Version")) or "?"
SlotPort.selectedSlots = {}
SlotPort.slotButtons   = {}   -- [slotNumber] = Button (populated by UI/GUI.lua)

-- Locale access: read from SlotPortL at runtime (available after ADDON_LOADED)
local function L(key) return (SlotPortL and SlotPortL[key]) or key end

-- ----------------------------------------------------------
-- Bar definitions
-- Blizzard ActionBar mapping in WoW Midnight 12.0:
--   Bar 1-5:  default bars (always visible)
--   Slots 73-120: class bonus bars (druid forms, warrior stances, vehicle)
--   Slots 121-132: dragonriding / possess
--   Slots 145-180: MultiBar5/6/7 (Default UI) OR ElvUI bars 13-15
--   -> registered dynamically in RefreshBarContent depending on the active UI
-- ----------------------------------------------------------
SlotPort.BARS = {
    -- Bar 1: always visible (MainActionBar can't be disabled)
    -- Names for bars 1-6 are placeholders here; RefreshBarContent (Core/Bars.lua)
    -- overwrites them every refresh with the ElvUI or Blizzard name that
    -- actually matches the physical slot range (they don't line up 1:1 -
    -- e.g. slots 61-72 are ElvUI "Bar 6" but Blizzard "Action Bar 2").
    { name = L("BAR_BLIZZ_1"),  startSlot = 1,   endSlot = 12,  alwaysShow = true },
    -- Bars 2-6: ElvUI-driven via DB, Default UI via frame visibility
    { name = L("BAR_BLIZZ_2"),  startSlot = 13,  endSlot = 24  },
    { name = L("BAR_BLIZZ_3"),  startSlot = 25,  endSlot = 36  },
    { name = L("BAR_BLIZZ_4"),  startSlot = 37,  endSlot = 48  },
    { name = L("BAR_BLIZZ_5"),  startSlot = 49,  endSlot = 60  },
    { name = L("BAR_BLIZZ_6"),  startSlot = 61,  endSlot = 72  },
    -- Class form/stance bars (73-120), Default UI only. Under ElvUI these
    -- are removed and replaced by ElvUI's own Bar 7-10 (see Core/Bars.lua
    -- RefreshBarContent/DetectElvUIBars) - ElvUI's per-bar stance/state
    -- paging isn't guaranteed to point at these same slots, so its own
    -- button data is read instead once ElvUI is active.
    { name = L("BAR_FORM_1"),    startSlot = 73,  endSlot = 84,  isFormBar = true },
    { name = L("BAR_FORM_2"),    startSlot = 85,  endSlot = 96,  isFormBar = true },
    { name = L("BAR_FORM_3"),    startSlot = 97,  endSlot = 108, isFormBar = true },
    { name = L("BAR_FORM_4"),    startSlot = 109, endSlot = 120, isFormBar = true },
    -- Bonus Bar 6 (slots 133-144): unknown usage (dimmed in the GUI when empty)
    { name = L("BAR_BONUS_6"),   startSlot = 133, endSlot = 144 },
    -- Action Bar 6-8 (Default UI: MultiBar5/6/7) and dragonriding are added dynamically
}

-- ----------------------------------------------------------
-- Addon initialization & slash commands
-- ----------------------------------------------------------

local defaults = {
    global = {
        windowPos = nil,
    },
}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SlotPort" then
        if SlotPort:HasBartender4() then
            print("|cff00ccffSlotPort:|r " .. L("BARTENDER_DETECTED"))
        end
        if SlotPort:HasElvUI() then
            print("|cff00ccffSlotPort:|r " .. L("ELVUI_DETECTED"))
        end

    elseif event == "PLAYER_LOGIN" then
        -- Initialize the DB here - UnitName("player") and GetRealmName()
        -- are guaranteed to be available from PLAYER_LOGIN onward
        SlotPort.db = LibStub("AceDB-3.0"):New("SlotPortDB", defaults, "Default")
        print("|cff00ccffSlotPort v" .. SlotPort.version .. "|r " .. L("LOADED_MSG"))

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- PLAYER_ENTERING_WORLD: GetActionInfo is now available for all bars
        RunNextFrame(function()
            SlotPort:RefreshBarContent()
            SlotPort:DetectElvUIBars()
            SlotPort:SetupElvUIWatchers()
            if SlotPortGUI.mainFrame and SlotPortGUI.mainFrame:IsShown() then
                SlotPortGUI:RebuildGrid()
            end
        end)
    end
end)

-- Slash commands
SLASH_SLOTPORT1 = "/slotport"
SLASH_SLOTPORT2 = "/sp"

SlashCmdList["SLOTPORT"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "show" then
        SlotPortGUI:Toggle()

    elseif cmd == "export" then
        local str, info, filled = SlotPort:Export()
        if str then
            print("|cff00ccffSlotPort:|r " .. string.format(L("EXPORTED_COUNT"), info))
            if filled and filled > 0 and filled < info then
                print("|cff00ccffSlotPort:|r " .. string.format(L("EXPORTED_EMPTY_NOTE"), info - filled))
            end
            if filled == 0 then
                print("|cffffcc00SlotPort:|r " .. L("EXPORT_ALL_EMPTY_WARN"))
            end
            SlotPortGUI:ShowExportString(str)
        else
            print("|cffff4444SlotPort " .. L("ERROR_PREFIX") .. "|r " .. tostring(info))
        end

    elseif cmd == "import" then
        if arg and arg ~= "" then
            local results, err = SlotPort.ImportString(arg)
            if not results then
                print("|cffff4444SlotPort " .. L("ERROR_PREFIX") .. "|r " .. tostring(err))
            else
                for _, r in ipairs(results) do
                    if r.ok then
                        print("|cff00ccffSlotPort:|r " .. r.msg)
                    else
                        print("|cffff4444SlotPort " .. L("ERROR_PREFIX") .. "|r " .. r.msg)
                    end
                end
            end
        else
            print(L("CMD_USAGE_IMPORT"))
        end

    elseif cmd == "debug" then
        if SlotPort.DebugCommand then SlotPort.DebugCommand(arg) end

    elseif cmd == "macros" then
        SlotPortMacroGUI:Toggle()

    elseif cmd == "help" then
        print("|cff00ccffSlotPort – " .. L("CMD_HELP") .. "|r")
        print("  |cffffcc00/sp|r                – " .. L("CMD_SHOW"))
        print("  |cffffcc00/sp export|r         – " .. L("CMD_EXPORT"))
        print("  |cffffcc00/sp import <str>|r   – " .. L("CMD_IMPORT"))
        print("  |cffffcc00/sp macros|r         – " .. L("CMD_MACROS"))
        print("  |cffffcc00/sp debug|r          – " .. L("CMD_DEBUG"))
    else
        print("|cffff4444SlotPort:|r " .. L("CMD_UNKNOWN"))
    end
end
