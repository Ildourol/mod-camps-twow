-- Lua 5.0 / vanilla event globals. No custom executable or direct world picking.
local _table_insert = table.insert
local _table_remove = table.remove
local tinsert = (type(tinsert) == "function" and tinsert) or function(t, a, b)
    if b ~= nil then _table_insert(t, a, b)
    else _table_insert(t, table.getn(t) + 1, a) end
end
local tremove = (type(tremove) == "function" and tremove) or function(t, pos)
    if pos ~= nil then return _table_remove(t, pos)
    else local n = table.getn(t); if n > 0 then return _table_remove(t, n) end end
end
table.insert = tinsert
table.remove = tremove

local TC = { serial = 0, ready = false, isConnecting = false, token = nil, page = 0, view = "CATALOG",
    rows = {}, queue = {}, nextSend = 0, selected = nil, mode = "CAMP", step = 0.5, totalPages = 1,
    editEntry = nil, editKind = 0, campUsage = nil, campRadius = 40, isPublic = false,
    chosenRadius = 40, chosenPublic = false, campFilter = 0, hasCamp = false, myCampId = nil }

-- Register frame for standard ESC key closing
tinsert(UISpecialFrames, "TurtleCampsFrame")

-- Completely silence protocol messages and whispers from chat frame
local origChatFrame_OnEvent = ChatFrame_OnEvent
ChatFrame_OnEvent = function(event)
    if event == "CHAT_MSG_SYSTEM" and type(arg1) == "string" and string.sub(arg1, 1, 8) == "TCAMP/1~" then
        return
    end
    if (event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_WHISPER") and type(arg1) == "string" and string.find(arg1, "%.camp 1~") then
        return
    end
    origChatFrame_OnEvent(event)
end

for i = 1, 7 do
    local cf = getglobal("ChatFrame" .. i)
    if cf and cf.AddMessage then
        local origAdd = cf.AddMessage
        cf.AddMessage = function(this, msg, r, g, b, id)
            if type(msg) == "string" and (string.find(msg, "TCAMP/1~") or string.find(msg, "%.camp 1~")) then
                return
            end
            origAdd(this, msg, r, g, b, id)
        end
    end
end

-- Main Window (Compact, elegant 840x600 frame)
local frame = CreateFrame("Frame", "TurtleCampsFrame", UIParent)
frame:SetWidth(840); frame:SetHeight(600); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true); frame:EnableMouse(true); frame:EnableMouseWheel(true); frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0.06, 0.07, 0.09, 0.94)
frame:SetBackdropBorderColor(0.85, 0.72, 0.35, 1.0)
frame:SetFrameStrata("DIALOG"); frame:Hide()

-- Reusable UI Helpers
local function label(text, x, y, width, font)
    local f = frame:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y); f:SetWidth(width or 600)
    f:SetJustifyH("LEFT"); f:SetText(text); return f
end

local function button(text, x, y, width, action, height, parent)
    local p = parent or frame
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(height or 22); b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    b:SetText(text); b:SetScript("OnClick", action); return b
end

local function box(name, x, y, width, parent)
    local p = parent or frame
    local b = CreateFrame("EditBox", name, p, "InputBoxTemplate")
    b:SetWidth(width); b:SetHeight(20); b:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    b:SetAutoFocus(false); b:SetMaxLetters(48)
    b:SetScript("OnEscapePressed", function() this:ClearFocus() end); return b
end

local tooltipTimer = CreateFrame("Frame", "TurtleCampsTooltipTimer", UIParent)
local pendingTip = nil

local function cancelPendingTooltip()
    pendingTip = nil
    GameTooltip:Hide()
end

tooltipTimer:SetScript("OnUpdate", function()
    if pendingTip then
        if GetTime() >= pendingTip.showAt then
            local owner = pendingTip.owner
            if owner and owner:IsVisible() then
                GameTooltip:SetOwner(owner, pendingTip.anchor or "ANCHOR_RIGHT")
                local title = type(pendingTip.title) == "function" and pendingTip.title() or pendingTip.title
                GameTooltip:SetText(tostring(title or ""), 1.0, 0.82, 0.0)
                if type(pendingTip.desc) == "function" then
                    local res = pendingTip.desc(GameTooltip)
                    if type(res) == "string" and res ~= "" then
                        GameTooltip:AddLine(res, 1.0, 1.0, 1.0, 1)
                    end
                elseif type(pendingTip.desc) == "string" and pendingTip.desc ~= "" then
                    GameTooltip:AddLine(pendingTip.desc, 1.0, 1.0, 1.0, 1)
                end
                GameTooltip:Show()
            end
            pendingTip = nil
        end
    end
end)

local function setTooltip(btn, title, desc, anchor)
    if not btn then return end
    btn:SetScript("OnEnter", function()
        pendingTip = {
            owner = this,
            title = title,
            desc = desc,
            anchor = anchor or "ANCHOR_RIGHT",
            showAt = GetTime() + 3.0
        }
    end)
    btn:SetScript("OnLeave", function()
        if pendingTip and pendingTip.owner == this then
            pendingTip = nil
        end
        GameTooltip:Hide()
    end)
end

-- Header Plate
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
titleText:SetText("|cffffd100TURTLE|r|cffffffffCAMPS|r  |cff888888v0.3.0|r")

local statusBadge = CreateFrame("Button", "TurtleCampsStatusBadge", frame)
statusBadge:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -10)
statusBadge:SetWidth(20); statusBadge:SetHeight(22)
statusBadge:EnableMouse(true)

local statusDot = statusBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusDot:SetPoint("CENTER", statusBadge, "CENTER", 0, 0)
statusDot:SetText("|cffffaa00\226\151\143|r")

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", frame, "TOPLEFT", 234, -14)
status:SetWidth(560); status:SetJustifyH("LEFT")
status:SetText("Connecting to server...")
local function message(text) status:SetText(text) end

setTooltip(statusBadge, "TurtleCamps Session", function(tip)
    if TC.ready then
        tip:AddDoubleLine("Status:", "|cff00ff00Connected|r", 0.7, 0.7, 0.7, 0, 1, 0)
        tip:AddDoubleLine("Mode:", (TC.mode == "GM") and "|cffffaa00GM Mode|r" or "|cff00ccffCamp Mode|r", 0.7, 0.7, 0.7, 1, 1, 1)
        if TC.campUsage then
            tip:AddDoubleLine("Camp Props:", TC.campUsage, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if TC.campRadius then
            tip:AddDoubleLine("Camp Radius:", tostring(TC.campRadius) .. " yd", 0.7, 0.7, 0.7, 1, 1, 1)
        end
        tip:AddLine("Click to re-synchronize session", 0.6, 0.6, 0.6)
    elseif TC.isConnecting then
        tip:AddDoubleLine("Status:", "|cffffaa00Negotiating HELLO...|r", 0.7, 0.7, 0.7, 1, 0.8, 0)
    else
        tip:AddDoubleLine("Status:", "|cffff0000Offline / Standby|r", 0.7, 0.7, 0.7, 1, 0, 0)
        tip:AddLine("Click to connect", 0.7, 0.7, 0.7)
    end
end, "ANCHOR_BOTTOMLEFT")

local function escape(s)
    s = tostring(s or "")
    local res = string.gsub(s, "[%%|~%c]", function(c) return string.format("%%%02X", string.byte(c)) end)
    return res
end
local function decode(s)
    local res = string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
    return res
end
local function split(s)
    local a = {}; local start = 1
    while true do
        local at = string.find(s, "~", start, true)
        if not at then
            local val = decode(string.sub(s, start))
            tinsert(a, val)
            return a
        end
        local val = decode(string.sub(s, start, at - 1))
        tinsert(a, val)
        start = at + 1
    end
end

local connect, request

connect = function(silent)
    TC.pending = nil; TC.ready = false; TC.token = nil
    TC.isConnecting = true
    statusDot:SetText("|cffffaa00\226\151\143|r")
    if not silent then message("Connecting to server...") end
    local hasHello = false
    for _, q in ipairs(TC.queue) do
        if q.op == "HELLO" then hasHello = true; break end
    end
    if not hasHello then
        tinsert(TC.queue, 1, {op="HELLO", fields={}})
    end
end

statusBadge:SetScript("OnClick", function() connect(false) end)

request = function(op, fields)
    if op ~= "HELLO" and not TC.ready then
        if not TC.isConnecting then connect(true) end
        if table.getn(TC.queue) < 16 then
            tinsert(TC.queue, {op=op, fields=fields or {}})
        end
        return
    end
    if table.getn(TC.queue) >= 16 then message("Please wait for pending controls."); return end
    tinsert(TC.queue, {op=op, fields=fields or {}})
end

local closeBtn = CreateFrame("Button", "TurtleCampsCloseBtn", frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    if TC.token then tinsert(TC.queue, {op="CANCEL", fields={TC.token}}) end
    frame:Hide()
end)
setTooltip(closeBtn, "Close Window", "Close the TurtleCamps window and cancel any active placement.")
frame:SetScript("OnHide", function() cancelPendingTooltip() end)

-- Forward declarations
local refresh, updateButtonStates

-- 2D Picture / Thematic Icon Card (Right Column)
local iconCard = CreateFrame("Frame", "TurtleCampsIconCard", frame)
iconCard:SetWidth(274); iconCard:SetHeight(128)
iconCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 550, -42)
iconCard:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
iconCard:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
iconCard:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

local iconFrame = CreateFrame("Frame", nil, iconCard)
iconFrame:SetWidth(76); iconFrame:SetHeight(76)
iconFrame:SetPoint("TOPLEFT", iconCard, "TOPLEFT", 10, -10)
iconFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
iconFrame:SetBackdropBorderColor(0.85, 0.72, 0.35, 1.0)

local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
iconTexture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 4, -4)
iconTexture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -4, 4)
iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Campfire")

local iconNameText = iconCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
iconNameText:SetPoint("TOPLEFT", iconCard, "TOPLEFT", 94, -12)
iconNameText:SetWidth(170); iconNameText:SetJustifyH("LEFT")
iconNameText:SetText("No item selected")

local iconIdText = iconCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
iconIdText:SetPoint("TOPLEFT", iconCard, "TOPLEFT", 94, -42)
iconIdText:SetWidth(170); iconIdText:SetJustifyH("LEFT")
iconIdText:SetText("Select an entity to inspect")

local iconCategoryBadge = iconCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
iconCategoryBadge:SetPoint("TOPLEFT", iconCard, "TOPLEFT", 94, -62)
iconCategoryBadge:SetWidth(170); iconCategoryBadge:SetJustifyH("LEFT")
iconCategoryBadge:SetText("")

local iconHelpText = iconCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
iconHelpText:SetPoint("BOTTOMLEFT", iconCard, "BOTTOMLEFT", 10, 8)
iconHelpText:SetWidth(254); iconHelpText:SetJustifyH("LEFT")
iconHelpText:SetText("|cff888888Double-click to preview. Shift-click to link.|r")

local creatureIconMap = {
    Beast = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
    Critter = "Interface\\Icons\\Ability_Hunter_Pet_Cat",
    Demon = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    Elemental = "Interface\\Icons\\Spell_Fire_Elemental_Totem",
    Giant = "Interface\\Icons\\INV_Misc_Head_Giant_01",
    Humanoid = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
    Mechanical = "Interface\\Icons\\Trade_Engineering",
    Totem = "Interface\\Icons\\Spell_Nature_ManaRegenTotem"
}

local function update2DPicture(row)
    if not row then
        iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Campfire")
        iconNameText:SetText("No item selected")
        iconIdText:SetText("Select an entity to inspect")
        iconCategoryBadge:SetText("")
        return
    end

    local dispName = row.name or ("ID " .. (row.id or row.entry or ""))
    iconNameText:SetText(dispName)
    iconIdText:SetText("Entry ID: " .. tostring(row.id or row.entry or ""))

    if row.kind == "item" or row.entityKind == 2 then
        iconCategoryBadge:SetText("|cff00ccff[Item]|r " .. (row.category or ""))
        local itemNum = tonumber(row.id or row.entry)
        local itemIcon = nil
        if itemNum and GetItemInfo then
            local _, _, _, _, _, _, _, _, itex = GetItemInfo(itemNum)
            itemIcon = itex
        end
        iconTexture:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    elseif row.kind == "npc" or row.kind == "creature" or row.entityKind == 1 then
        local cat = row.category or "Creature"
        iconCategoryBadge:SetText("|cff55ff55[" .. cat .. "]|r")
        local icon = creatureIconMap[cat] or "Interface\\Icons\\INV_Misc_MonsterHead_01"
        iconTexture:SetTexture(icon)
    elseif row.kind == "camp" then
        iconCategoryBadge:SetText("|cffffaa00[Camp]|r")
        iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    else
        local cat = row.category or "Props"
        if cat == "Buildings" then
            iconCategoryBadge:SetText("|cffff8800[Building]|r")
            iconTexture:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
        elseif string.find(string.lower(dispName), "fire") or string.find(string.lower(dispName), "camp") then
            iconCategoryBadge:SetText("|cffffd100[Prop]|r " .. cat)
            iconTexture:SetTexture("Interface\\Icons\\Spell_Fire_Fire")
        elseif string.find(string.lower(dispName), "chair") or string.find(string.lower(dispName), "bench") then
            iconCategoryBadge:SetText("|cffffd100[Prop]|r " .. cat)
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_WoodBench")
        elseif string.find(string.lower(dispName), "crate") or string.find(string.lower(dispName), "barrel") then
            iconCategoryBadge:SetText("|cffffd100[Prop]|r " .. cat)
            iconTexture:SetTexture("Interface\\Icons\\INV_Crate_01")
        else
            iconCategoryBadge:SetText("|cffffd100[Prop]|r " .. cat)
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Campfire")
        end
    end
end

-- Database Links Box (Right Column)
local webBox = CreateFrame("Frame", "TurtleCampsWebBox", frame)
webBox:SetWidth(274); webBox:SetHeight(132)
webBox:SetPoint("TOPLEFT", iconCard, "BOTTOMLEFT", 0, -6)
webBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
webBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
webBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

local function wLabel(text, x, y, font)
    local l = webBox:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", webBox, "TOPLEFT", x, y); l:SetJustifyH("LEFT"); l:SetText(text)
    return l
end
wLabel("Database & Web Links", 8, -6, "GameFontNormal")

local dbLinkMode = "WOWHEAD" -- "WOWHEAD", "TURTLE_DB", or "VIEWER_3D"
local linkWowheadBtn, linkTurtleBtn, linkViewerBtn

local webLinkBox = CreateFrame("EditBox", "TurtleCampsWebURL", webBox, "InputBoxTemplate")
webLinkBox:SetWidth(256); webLinkBox:SetHeight(20); webLinkBox:SetPoint("TOPLEFT", webBox, "TOPLEFT", 8, -48)
webLinkBox:SetAutoFocus(false)
webLinkBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
webLinkBox:SetScript("OnEditFocusGained", function() this:HighlightText() end)
webLinkBox:SetScript("OnMouseUp", function() this:HighlightText() end)
webLinkBox:SetScript("OnEditFocusLost", function()
    if this.HighlightText then this:HighlightText(0, 0) end
end)

local function setWebUrl(url)
    webLinkBox:SetText(url)
    if webLinkBox.HighlightText then
        webLinkBox:HighlightText(0, 0)
    end
end

local function updateWebLink()
    local entryId = nil
    local kind = 0 -- 0 = object, 1 = npc/creature, 2 = item
    if TC.selected then
        entryId = TC.selected.id or TC.selected.entry
        kind = TC.selected.entityKind or ((TC.selected.kind == "npc" or TC.selected.kind == "creature") and 1 or (TC.selected.kind == "item" and 2 or 0))
    elseif TC.editEntry then
        entryId = TC.editEntry
        kind = TC.editKind or 0
    end

    if not entryId or entryId == "" or tonumber(entryId) == 0 then
        if dbLinkMode == "VIEWER_3D" then
            setWebUrl("https://xian55.github.io/tortoise-db-viewer/")
        elseif dbLinkMode == "TURTLE_DB" then
            setWebUrl("https://database.turtle-wow.org/")
        else
            setWebUrl("https://www.wowhead.com/classic/")
        end
        return
    end

    local paramStr = "object"
    if kind == 1 then paramStr = "npc"
    elseif kind == 2 then paramStr = "item" end

    if dbLinkMode == "VIEWER_3D" then
        setWebUrl("https://xian55.github.io/tortoise-db-viewer/?" .. paramStr .. "=" .. entryId)
    elseif dbLinkMode == "TURTLE_DB" then
        setWebUrl("https://database.turtle-wow.org/?" .. paramStr .. "=" .. entryId)
    else
        setWebUrl("https://www.wowhead.com/classic/" .. paramStr .. "=" .. entryId)
    end
end

local function updateLinkModeButtons()
    if dbLinkMode == "WOWHEAD" then
        linkWowheadBtn:LockHighlight(); linkTurtleBtn:UnlockHighlight(); linkViewerBtn:UnlockHighlight()
    elseif dbLinkMode == "TURTLE_DB" then
        linkWowheadBtn:UnlockHighlight(); linkTurtleBtn:LockHighlight(); linkViewerBtn:UnlockHighlight()
    else
        linkWowheadBtn:UnlockHighlight(); linkTurtleBtn:UnlockHighlight(); linkViewerBtn:LockHighlight()
    end
    updateWebLink()
end

linkWowheadBtn = CreateFrame("Button", nil, webBox, "UIPanelButtonTemplate")
linkWowheadBtn:SetWidth(80); linkWowheadBtn:SetHeight(18); linkWowheadBtn:SetPoint("TOPLEFT", webBox, "TOPLEFT", 8, -24)
linkWowheadBtn:SetText("Wowhead")
linkWowheadBtn:SetScript("OnClick", function() dbLinkMode = "WOWHEAD"; updateLinkModeButtons() end)
setTooltip(linkWowheadBtn, "Classic Wowhead", "Switch link box to the Classic Wowhead database URL for this entity.")

linkTurtleBtn = CreateFrame("Button", nil, webBox, "UIPanelButtonTemplate")
linkTurtleBtn:SetWidth(80); linkTurtleBtn:SetHeight(18); linkTurtleBtn:SetPoint("TOPLEFT", webBox, "TOPLEFT", 92, -24)
linkTurtleBtn:SetText("Turtle DB")
linkTurtleBtn:SetScript("OnClick", function() dbLinkMode = "TURTLE_DB"; updateLinkModeButtons() end)
setTooltip(linkTurtleBtn, "Turtle WoW Database", "Switch link box to the Turtle WoW database URL for custom and vanilla items.")

linkViewerBtn = CreateFrame("Button", nil, webBox, "UIPanelButtonTemplate")
linkViewerBtn:SetWidth(80); linkViewerBtn:SetHeight(18); linkViewerBtn:SetPoint("TOPLEFT", webBox, "TOPLEFT", 176, -24)
linkViewerBtn:SetText("3D View")
linkViewerBtn:SetScript("OnClick", function() dbLinkMode = "VIEWER_3D"; updateLinkModeButtons() end)
setTooltip(linkViewerBtn, "3D Model Viewer", "Switch link box to the online 3D web model viewer URL.")

updateLinkModeButtons()
wLabel("|cff888888Click URL & press Ctrl+C to copy|r", 8, -72, "GameFontDisableSmall")

-- Quick Spawn Section (Inside webBox)
wLabel("Quick Spawn by ID:", 8, -88, "GameFontNormalSmall")
local directEntryBox = box("TurtleCampsDirectID", 8, -106, 90, webBox)

local quickSpawnKind = 0
local kindNames = { [0] = "Object", [1] = "Creature", [2] = "Item" }
local kindToggleBtn = CreateFrame("Button", nil, webBox, "UIPanelButtonTemplate")
kindToggleBtn:SetWidth(70); kindToggleBtn:SetHeight(20); kindToggleBtn:SetPoint("TOPLEFT", webBox, "TOPLEFT", 106, -106)
kindToggleBtn:SetText("Object")
kindToggleBtn:SetScript("OnClick", function()
    quickSpawnKind = quickSpawnKind + 1
    if quickSpawnKind > 2 then quickSpawnKind = 0 end
    this:SetText(kindNames[quickSpawnKind])
end)
setTooltip(kindToggleBtn, "Entity Type", "Cycle manual spawn ID resolution between Gameobject (GO), Creature (NPC), and Item.")

local quickSpawnBtn = button("Spawn", 182, -106, 80, function()
    local val = tonumber(directEntryBox:GetText())
    if val and val > 0 then
        if TC.token then request("CANCEL", {TC.token}) end
        request("PREVIEW", {val, quickSpawnKind})
        message("Spawning " .. kindNames[quickSpawnKind] .. " ID " .. val .. "...")
    else
        message("Enter a valid numeric ID.")
    end
end, 20, webBox)
setTooltip(quickSpawnBtn, "Quick Spawn", "Directly spawn the entered ID at your location without searching the catalog.")

-- Controls Shortcut Guide Card (Right Column)
local navBox = CreateFrame("Frame", nil, frame)
navBox:SetWidth(274); navBox:SetHeight(124)
navBox:SetPoint("TOPLEFT", webBox, "BOTTOMLEFT", 0, -6)
navBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
navBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
navBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

local function nLabel(text, x, y, font)
    local l = navBox:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", navBox, "TOPLEFT", x, y); l:SetJustifyH("LEFT"); l:SetText(text)
    return l
end
nLabel("Mouse & Key Shortcuts", 8, -6, "GameFontNormal")
nLabel("|cffffd100Wheel:|r Elevation (Z)", 8, -24)
nLabel("|cffffd100Shift+Wheel:|r Rotate Yaw", 8, -42)
nLabel("|cffffd100Ctrl+Wheel:|r Forward / Back", 8, -60)
nLabel("|cffffd100Alt+Wheel:|r Strafe Left / Right", 8, -78)
nLabel("|cff888888Click new item to auto-cancel preview|r", 8, -100, "GameFontDisableSmall")

-- Search and Category Filters
local query = box("TurtleCampsQuery", 62, -70, 140)
local category = box("TurtleCampsCategory", 260, -70, 95)
label("Search:", 16, -72, 45, "GameFontHighlightSmall")
label("Cat:", 232, -72, 28, "GameFontHighlightSmall")

-- Top Navigation Tabs (Left Container)
local tabButtons = {}
local function updateTabHighlights()
    for k, btn in pairs(tabButtons) do
        if TC.view == k then btn:LockHighlight() else btn:UnlockHighlight() end
    end
end

tabButtons["CATALOG"] = button("Props", 16, -42, 62, function() TC.view="CATALOG"; category:SetText(""); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["CATALOG"], "Props Catalog", "Browse tents, campfires, furniture, decorations, and placeable world props.")

tabButtons["BUILDINGS"] = button("Buildings", 80, -42, 70, function() TC.view="BUILDINGS"; category:SetText("Buildings"); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["BUILDINGS"], "Buildings Catalog", "Browse large pavilions, lodges, towers, and permanent shelter models.")

tabButtons["CREATURES"] = button("Creatures", 152, -42, 72, function() TC.view="CREATURES"; category:SetText("Creatures"); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["CREATURES"], "Creatures & NPCs", "Browse camp companions, guards, vendors, and ambient NPCs.")

tabButtons["ITEMS"] = button("Items", 226, -42, 56, function() TC.view="ITEMS"; category:SetText("Items"); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["ITEMS"], "Items Catalog", "Browse placeable equipment, supplies, weapons, and ground clutter.")

tabButtons["OBJECTS"] = button("Owned", 284, -42, 58, function() TC.view="OBJECTS"; category:SetText(""); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["OBJECTS"], "Active Camp Spawns", "View, inspect, edit, or delete all props currently placed in your active camp.")

tabButtons["CAMPS"] = button("Camps", 344, -42, 58, function() TC.view="CAMPS"; category:SetText(""); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["CAMPS"], "Camp List", "View your established camp details or discover and travel to public camps.")

tabButtons["FAVORITES"] = button("Favs", 404, -42, 58, function() TC.view="FAVORITES"; category:SetText(""); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["FAVORITES"], "Favorite Props", "Quickly access your bookmarked props and frequently used decorations.")

tabButtons["RECENT"] = button("Recent", 464, -42, 62, function() TC.view="RECENT"; category:SetText(""); query:SetText(""); TC.page=0; refresh() end, 22)
setTooltip(tabButtons["RECENT"], "Recently Placed", "View the history of props and items you have placed in this session.")

local clearBtn = button("X", 360, -70, 20, function()
    query:SetText(""); category:SetText(""); TC.page=0; refresh()
end, 20)
setTooltip(clearBtn, "Clear Filters", "Clear search query and category filters to show all props.")

local searchBtn = button("Search", 384, -70, 52, function() TC.page=0; refresh() end, 20)
setTooltip(searchBtn, "Search Catalog", "Filter catalog entries matching the entered keyword or numeric ID.")

-- Uncapped Pagination Controls
local firstPageBtn = button("<<", 440, -70, 20, function() if TC.page > 0 then TC.page = 0; refresh() end end, 20)
setTooltip(firstPageBtn, "First Page", "Jump to page 1")

local prevPageBtn = button("<", 462, -70, 18, function() if TC.page > 0 then TC.page = TC.page - 1; refresh() end end, 20)
setTooltip(prevPageBtn, "Prev", "Browse previous page")

local pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pageText:SetPoint("TOPLEFT", frame, "TOPLEFT", 480, -73)
pageText:SetWidth(44); pageText:SetJustifyH("CENTER")
pageText:SetText("1/1")

local nextPageBtn = button(">", 524, -70, 18, function() TC.page = TC.page + 1; refresh() end, 20)
setTooltip(nextPageBtn, "Next", "Browse next page")

local skipPageBtn = button(">>", 544, -70, 20, function() TC.page = TC.page + 10; refresh() end, 20)
setTooltip(skipPageBtn, "Skip +10", "Skip forward 10 pages")

local function scrollTable(dir)
    if not dir then return end
    if dir > 0 then
        if TC.page > 0 then
            TC.page = TC.page - 1
            refresh()
        end
    elseif dir < 0 then
        if not TC.totalPages or (TC.page + 1 < TC.totalPages) then
            TC.page = TC.page + 1
            refresh()
        end
    end
end

-- Catalogue Table Frame (8 Rows, height 234)
local tableFrame = CreateFrame("Frame", "TurtleCampsTableFrame", frame)
tableFrame:SetWidth(524); tableFrame:SetHeight(234)
tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -96)
tableFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
tableFrame:SetBackdropColor(0.02, 0.03, 0.04, 0.85)
tableFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)
tableFrame:EnableMouseWheel(true)
tableFrame:SetScript("OnMouseWheel", function()
    scrollTable(arg1)
end)

local colH1 = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colH1:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 8, -4); colH1:SetWidth(50); colH1:SetJustifyH("LEFT"); colH1:SetText("ID")

local colH2 = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colH2:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 60, -4); colH2:SetWidth(250); colH2:SetJustifyH("LEFT"); colH2:SetText("Name")

local colH3 = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colH3:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 314, -4); colH3:SetWidth(130); colH3:SetJustifyH("LEFT"); colH3:SetText("Category / Info")

local colH4 = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colH4:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 448, -4); colH4:SetWidth(68); colH4:SetJustifyH("CENTER"); colH4:SetText("Type")

local rowFrames = {}
local lastRowClickTime = 0
local lastRowClickIndex = 0

local function isRowSelected(row)
    if not TC.selected or not row then return false end
    if row.kind == "object" then
        return (TC.selected.id and row.id and tostring(TC.selected.id) == tostring(row.id))
    elseif row.kind == "camp" then
        return (TC.selected.id and row.id and tostring(TC.selected.id) == tostring(row.id))
    else
        if TC.selected.id and row.id and tostring(TC.selected.id) == tostring(row.id) then return true end
        if TC.selected.entry and row.entry and tostring(TC.selected.entry) == tostring(row.entry) then return true end
        return false
    end
end

local function render()
    for i = 1, 8 do
        local row = TC.rows[i]
        local rf = rowFrames[i]
        if row then
            rf.idText:SetText(tostring(row.id or row.entry or ""))
            local displayName = row.name or ("Entry " .. (row.id or row.entry or ""))
            rf.catText:SetText(row.category or row.detail or "")
            local badge = "[Object]"
            if row.kind == "npc" or row.kind == "creature" or row.entityKind == 1 then
                badge = "|cff55ff55[" .. (row.category or "Creature") .. "]|r"
                rf.nameText:SetTextColor(0.4, 1.0, 0.4)
            elseif row.kind == "item" or row.entityKind == 2 then
                badge = "|cff00ccff[Item]|r"
                rf.nameText:SetTextColor(0.3, 0.8, 1.0)
            elseif row.kind == "camp" then
                badge = "|cffffaa00[Camp]|r"
                rf.nameText:SetTextColor(1.0, 0.8, 0.2)
            else
                if row.category == "Buildings" then badge = "|cffff8800[Building]|r" end
                rf.nameText:SetTextColor(1.0, 0.9, 0.6)
            end
            if row.kind == "object" then
                if row.camp and tonumber(row.camp) and tonumber(row.camp) > 0 then
                    badge = "|cffffaa00[Camp #" .. row.camp .. "]|r"
                else
                    badge = "|cff888888[World]|r"
                end
            end
            rf.badgeText:SetText(badge)
            rf:Show()
            if isRowSelected(row) then
                rf:SetBackdropBorderColor(1.0, 0.85, 0.1, 1.0)
                rf:SetBackdropColor(0.35, 0.28, 0.08, 0.85)
                rf.nameText:SetText("|cffffd100\226\150\186 |r" .. displayName)
            else
                rf:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)
                if math.mod(i, 2) == 0 then rf:SetBackdropColor(0.08, 0.09, 0.12, 0.45)
                else rf:SetBackdropColor(0.05, 0.05, 0.07, 0.3) end
                rf.nameText:SetText(displayName)
            end
        else
            rf:Hide()
        end
    end
    updateButtonStates()
end

for i = 1, 8 do
    local index = i
    local rf = CreateFrame("Button", "TurtleCampsRow" .. i, tableFrame)
    rf:SetWidth(512); rf:SetHeight(24)
    rf:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 6, -20 - (i - 1) * 26)
    rf:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    rf:SetBackdropColor(0.06, 0.07, 0.1, 0.4)
    rf:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.4)
    rf:EnableMouse(true)
    rf:EnableMouseWheel(true)
    rf:SetScript("OnMouseWheel", function()
        scrollTable(arg1)
    end)

    rf.idText = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rf.idText:SetPoint("LEFT", rf, "LEFT", 4, 0); rf.idText:SetWidth(48); rf.idText:SetJustifyH("LEFT")

    rf.nameText = rf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rf.nameText:SetPoint("LEFT", rf, "LEFT", 54, 0); rf.nameText:SetWidth(250); rf.nameText:SetJustifyH("LEFT")

    rf.catText = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rf.catText:SetPoint("LEFT", rf, "LEFT", 308, 0); rf.catText:SetWidth(130); rf.catText:SetJustifyH("LEFT")

    rf.badgeText = rf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rf.badgeText:SetPoint("RIGHT", rf, "RIGHT", -4, 0); rf.badgeText:SetWidth(68); rf.badgeText:SetJustifyH("CENTER")

    rf:SetScript("OnClick", function()
        local row = TC.rows[index]
        if not row then return end

        -- Auto-cancel previous preview if choosing a new item from list
        if TC.token and (not TC.selected or (TC.selected.id ~= row.id and TC.selected.entry ~= row.id)) then
            request("CANCEL", {TC.token})
        end

        -- Shift-Click support to link into chat
        if IsShiftKeyDown() then
            if ChatFrameEditBox and ChatFrameEditBox:IsShown() then
                if row.kind == "item" or row.entityKind == 2 then
                    ChatFrameEditBox:Insert("|cffffffff|Hitem:" .. row.id .. ":0:0:0|h[" .. (row.name or ("Item " .. row.id)) .. "]|h|r")
                elseif row.kind == "npc" or row.kind == "creature" or row.entityKind == 1 then
                    ChatFrameEditBox:Insert("[" .. (row.name or ("Creature " .. row.id)) .. "] (Creature " .. row.id .. ")")
                elseif row.kind == "camp" then
                    ChatFrameEditBox:Insert("Camp " .. row.id)
                else
                    ChatFrameEditBox:Insert("[" .. (row.name or ("Object " .. row.id)) .. "] (Object " .. row.id .. ")")
                end
                return
            end
        end

        TC.selected = row
        render()
        update2DPicture(row)
        updateWebLink()

        -- Double-Click to preview immediately
        local now = GetTime()
        if lastRowClickIndex == index and (now - lastRowClickTime) < 0.4 then
            if row.kind == "prop" or row.kind == "npc" or row.kind == "creature" or row.kind == "item" then
                request("PREVIEW", {row.id, row.entityKind or 0})
                message("Previewing " .. (row.name or row.id) .. "...")
            elseif row.kind == "object" then
                request("EDIT", {row.id})
            end
        end
        lastRowClickTime = now
        lastRowClickIndex = index
    end)

    rf:SetScript("OnEnter", function()
        cancelPendingTooltip()
        local row = TC.rows[index]
        if not row then return end
        this:SetBackdropColor(0.18, 0.2, 0.28, 0.5)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if row.kind == "item" or row.entityKind == 2 then
            GameTooltip:SetHyperlink("item:" .. row.id .. ":0:0:0")
        else
            GameTooltip:AddLine(row.name or ("ID " .. row.id), 1.0, 0.82, 0.0)
            GameTooltip:AddDoubleLine("Entry ID:", tostring(row.id or row.entry), 0.7, 0.7, 0.7, 1, 1, 1)
            local typeLabel = "GameObject (Prop)"
            if row.kind == "npc" or row.kind == "creature" or row.entityKind == 1 then typeLabel = "Creature (" .. (row.category or "NPC") .. ")"
            elseif row.kind == "object" then typeLabel = "Spawned Camp Object"
            elseif row.kind == "camp" then typeLabel = "Camp Location" end
            GameTooltip:AddDoubleLine("Type:", typeLabel, 0.7, 0.7, 0.7, 0.4, 0.8, 1)
            GameTooltip:AddLine("Double-click to preview. Shift-click to paste link in chat.", 0.2, 1.0, 0.2)
        end
        GameTooltip:Show()
    end)

    rf:SetScript("OnLeave", function()
        local row = TC.rows[index]
        if not isRowSelected(row) then
            if math.mod(index, 2) == 0 then this:SetBackdropColor(0.08, 0.09, 0.12, 0.45)
            else this:SetBackdropColor(0.05, 0.05, 0.07, 0.3) end
        end
        GameTooltip:Hide()
    end)

    rowFrames[i] = rf
end

-- Contextual Action Bars (Placed directly below table at y = -336)
local catActionsFrame = CreateFrame("Frame", "TurtleCampsCatActions", frame)
catActionsFrame:SetWidth(524); catActionsFrame:SetHeight(28)
catActionsFrame:SetPoint("TOPLEFT", tableFrame, "BOTTOMLEFT", 0, -4)

local btnPreview = button("Preview Item", 0, 0, 96, function()
    if TC.selected and (TC.selected.kind == "prop" or TC.selected.kind == "npc" or TC.selected.kind == "creature" or TC.selected.kind == "item") then
        request("PREVIEW", {TC.selected.id, TC.selected.entityKind or 0})
    end
end, 24, catActionsFrame)
setTooltip(btnPreview, "Preview Item", "Summon a temporary live preview of the selected prop at your feet to position before saving.")

local btnFavorite = button("Fav +/-", 100, 0, 68, function()
    if not TC.selected then return end
    local id = tostring(TC.selected.id or TC.selected.entry)
    if TurtleCampsDB.favorites[id] then
        TurtleCampsDB.favorites[id] = nil
    else
        local n = 0; for _ in pairs(TurtleCampsDB.favorites) do n = n + 1 end
        if n >= 50 then message("Favorite limit: 50"); return end
        TurtleCampsDB.favorites[id] = {
            name = TC.selected.name or id,
            kind = TC.selected.kind or "prop",
            entityKind = TC.selected.entityKind or 0
        }
    end
    message("Favorites updated.")
end, 24, catActionsFrame)
setTooltip(btnFavorite, "Toggle Favorite", "Add or remove the selected prop from your personal Favorites list.")

local CATEGORY_PRESETS = {
    CATALOG = {
        { label = "All", cat = "", query = "", tipTitle = "All Props", tipDesc = "Clear category filter to view all props" },
        { label = "Tents", cat = "Shelter", query = "", tipTitle = "Tents & Shelters", tipDesc = "Quick-filter by tents, canopies, and camp shelters" },
        { label = "Seats", cat = "Furniture", query = "", tipTitle = "Chairs & Tables", tipDesc = "Quick-filter by chairs, benches, tables, and seating" },
        { label = "Fires", cat = "Fire", query = "", tipTitle = "Campfires & Torches", tipDesc = "Quick-filter by campfires, braziers, torches, and flames" },
        { label = "Storage", cat = "Storage", query = "", tipTitle = "Crates & Barrels", tipDesc = "Quick-filter by crates, barrels, and camp supplies" },
        { label = "Banners", cat = "Banners", query = "", tipTitle = "Flags & Banners", tipDesc = "Quick-filter by flags, banners, and faction standards" },
        { label = "Nature", cat = "Nature", query = "", tipTitle = "Flora & Nature", tipDesc = "Quick-filter by trees, shrubs, and wilderness foliage" },
    },
    BUILDINGS = {
        { label = "All", cat = "Buildings", query = "", tipTitle = "All Buildings", tipDesc = "View all large buildings, lodges, and structures" },
        { label = "Houses", cat = "Buildings", query = "House", tipTitle = "Houses & Inns", tipDesc = "Filter buildings matching houses, taverns, cottages, and lodges" },
        { label = "Towers", cat = "Buildings", query = "Tower", tipTitle = "Towers & Keeps", tipDesc = "Filter watchtowers, guard towers, and spires" },
        { label = "Pavilions", cat = "Buildings", query = "Tent", tipTitle = "Large Pavilions", tipDesc = "Filter large marquee tents, pavilions, and canopy shelters" },
        { label = "Docks", cat = "Buildings", query = "Dock", tipTitle = "Docks & Piers", tipDesc = "Filter piers, boardwalks, docks, and harbor structures" },
        { label = "Gates", cat = "Buildings", query = "Gate", tipTitle = "Gates & Walls", tipDesc = "Filter palisades, fortress walls, and barricade gates" },
        { label = "Ruins", cat = "Buildings", query = "Ruin", tipTitle = "Ancient Ruins", tipDesc = "Filter pillars, temples, ruins, and stone monuments" },
    },
    CREATURES = {
        { label = "All", cat = "Creatures", query = "", tipTitle = "All Creatures", tipDesc = "View all camp creatures and NPCs" },
        { label = "Human", cat = "Humanoid", query = "", tipTitle = "Humanoids", tipDesc = "Filter humanoid NPCs, guards, vendors, and citizens" },
        { label = "Beast", cat = "Beast", query = "", tipTitle = "Beasts & Mounts", tipDesc = "Filter wild beasts, camp pets, horses, and wolves" },
        { label = "Critters", cat = "Critter", query = "", tipTitle = "Camp Critters", tipDesc = "Filter small ambient critters, rabbits, birds, and cats" },
        { label = "Undead", cat = "Undead", query = "", tipTitle = "Undead", tipDesc = "Filter undead guards, skeletons, and spirits" },
        { label = "Demons", cat = "Demon", query = "", tipTitle = "Demons", tipDesc = "Filter summoned demons, imps, and felstalkers" },
        { label = "Elements", cat = "Elemental", query = "", tipTitle = "Elementals", tipDesc = "Filter fire, water, earth, and air elementals" },
    },
    ITEMS = {
        { label = "All", cat = "Items", query = "", tipTitle = "All Items", tipDesc = "View all placeable equipment and ground clutter items" },
        { label = "Weapons", cat = "Weapon", query = "", tipTitle = "Weapons", tipDesc = "Filter swords, axes, bows, staves, and polearms" },
        { label = "Armor", cat = "Armor", query = "", tipTitle = "Armor & Gear", tipDesc = "Filter shields, helmets, boots, and armor clutter" },
        { label = "Food", cat = "Consumable", query = "Food", tipTitle = "Food & Drinks", tipDesc = "Filter camp meals, roasted meat, bread, and drinks" },
        { label = "Potions", cat = "Consumable", query = "Potion", tipTitle = "Potions & Elixirs", tipDesc = "Filter alchemy bottles, flasks, and magical brews" },
        { label = "Bags", cat = "Container", query = "", tipTitle = "Bags & Containers", tipDesc = "Filter knapsacks, pouches, sacks, and chests" },
        { label = "Books", cat = "Book", query = "", tipTitle = "Books & Tomes", tipDesc = "Filter open books, scrolls, tomes, and papers" },
    },
    FAVORITES = {
        { label = "All", cat = "", query = "", tipTitle = "All Favorites", tipDesc = "View all bookmarked props" },
    },
    RECENT = {
        { label = "All", cat = "", query = "", tipTitle = "All Recent", tipDesc = "View all recently placed props" },
    }
}

local function quickFilter(catName, queryName)
    category:SetText(catName or "")
    query:SetText(queryName or "")
    TC.page = 0
    refresh()
end

local catChips = {}
for i = 1, 7 do
    catChips[i] = button("", 0, 0, 48, function() end, 24, catActionsFrame)
    catChips[i]:Hide()
end

local function updateCategoryChips()
    local preset = CATEGORY_PRESETS[TC.view] or CATEGORY_PRESETS["CATALOG"]
    local x = 172
    for i = 1, 7 do
        local chip = catChips[i]
        local data = preset[i]
        if data then
            local w = 48
            if data.label == "All" then w = 34
            elseif string.len(data.label) >= 8 then w = 56
            elseif string.len(data.label) >= 7 then w = 52
            elseif string.len(data.label) <= 4 then w = 42
            else w = 48 end
            chip:SetPoint("TOPLEFT", catActionsFrame, "TOPLEFT", x, 0)
            chip:SetWidth(w)
            chip:SetText(data.label)
            local targetCat = data.cat
            local targetQuery = data.query
            chip:SetScript("OnClick", function()
                quickFilter(targetCat, targetQuery)
            end)
            setTooltip(chip, data.tipTitle, data.tipDesc)
            chip:Show()
            x = x + w + 2
        else
            chip:Hide()
        end
    end
end

-- Owned Spawns Actions Bar (Only shown on "OBJECTS" view)
local ownedActionsFrame = CreateFrame("Frame", "TurtleCampsOwnedActions", frame)
ownedActionsFrame:SetWidth(524); ownedActionsFrame:SetHeight(28)
ownedActionsFrame:SetPoint("TOPLEFT", tableFrame, "BOTTOMLEFT", 0, -4)
ownedActionsFrame:Hide()

local btnEdit = button("Edit Spawn", 0, 0, 74, function()
    if TC.selected and TC.selected.kind == "object" then request("EDIT", {TC.selected.id}) end
end, 24, ownedActionsFrame)
setTooltip(btnEdit, "Edit Spawn", "Activate precision transform controls to adjust position or rotation of this placed object.")

local btnDuplicate = button("Duplicate", 78, 0, 74, function()
    if TC.selected and TC.selected.kind == "object" then request("DUPLICATE", {TC.selected.id}) end
end, 24, ownedActionsFrame)
setTooltip(btnDuplicate, "Duplicate Spawn", "Spawn an identical clone of this object at its current position for quick placement.")

local btnDelete = button("Delete Spawn", 156, 0, 80, function()
    if TC.selected and TC.selected.kind == "object" then
        local delId = TC.selected.id
        if TC.token then request("CANCEL", {TC.token}) end
        request("DELETE", {delId})
        message("Force deleting spawn #" .. delId .. "...")
        for i = table.getn(TC.rows), 1, -1 do
            if tostring(TC.rows[i].id) == tostring(delId) then
                tremove(TC.rows, i)
            end
        end
        TC.selected = nil
        update2DPicture(nil)
        updateWebLink()
        render()
    else
        message("Select an owned spawn first.")
    end
end, 24, ownedActionsFrame)
setTooltip(btnDelete, "Force Delete Spawn", "Permanently force delete the selected spawn from the world and database immediately.")

local btnNearest = button("Nearest", 240, 0, 62, function() request("NEAREST", {0}) end, 24, ownedActionsFrame)
setTooltip(btnNearest, "Nearest Prop", "Automatically target and edit the closest owned camp prop to your character.")

local btnFacing = button("Facing", 306, 0, 62, function() request("NEAREST", {1}) end, 24, ownedActionsFrame)
setTooltip(btnFacing, "Facing Prop", "Automatically target and edit the camp prop directly in front of your character.")

local btnCampFilter
local function updateCampFilterBtn()
    if not btnCampFilter then return end
    if TC.campFilter == 1 then
        btnCampFilter:SetText("Filter: Camp")
    elseif TC.campFilter == 2 then
        btnCampFilter:SetText("Filter: World")
    else
        btnCampFilter:SetText("Filter: All")
    end
end

btnCampFilter = button("Filter: All", 372, 0, 144, function()
    if TC.campFilter == 0 then
        TC.campFilter = 1
        message("Showing only props in your camp.")
    elseif TC.campFilter == 1 then
        TC.campFilter = 2
        message("Showing only props outside camps (world).")
    else
        TC.campFilter = 0
        message("Showing all owned props.")
    end
    updateCampFilterBtn()
    TC.page = 0
    refresh()
end, 24, ownedActionsFrame)
setTooltip(btnCampFilter, "Camp Group Filter", "Cycle between showing All props, props assigned to your Camp, or free World props.")

-- Camps Actions Bar (Only shown on "CAMPS" view)
local campsActionsFrame = CreateFrame("Frame", "TurtleCampsCampsActions", frame)
campsActionsFrame:SetWidth(524); campsActionsFrame:SetHeight(28)
campsActionsFrame:SetPoint("TOPLEFT", tableFrame, "BOTTOMLEFT", 0, -4)
campsActionsFrame:Hide()

local btnClaim, btnPublic, btnRadius, breakButton

local function updateCampActionButtons()
    if btnClaim then
        btnClaim:SetText(TC.hasCamp and "Move Camp" or "Create Camp")
    end
    if btnPublic then
        local isPub = TC.hasCamp and TC.isPublic or TC.chosenPublic
        btnPublic:SetText(isPub and "Vis: Public" or "Vis: Private")
    end
    if btnRadius then
        local r = TC.hasCamp and TC.campRadius or TC.chosenRadius or 40
        btnRadius:SetText("Size: " .. r .. "y")
    end
end

btnClaim = button("Create Camp", 0, 0, 86, function()
    local pub = (TC.hasCamp and TC.isPublic) or TC.chosenPublic
    local rad = (TC.hasCamp and TC.campRadius) or TC.chosenRadius or 40
    request("CLAIM", { pub and 1 or 0, rad })
end, 24, campsActionsFrame)
setTooltip(btnClaim, "Establish / Relocate Camp", "Create your personal camp at your current position, or relocate your existing camp with the chosen radius and visibility settings.")

btnPublic = button("Vis: Private", 90, 0, 82, function()
    if TC.hasCamp then
        local newPub = TC.isPublic and 0 or 1
        request("PUBLIC", {newPub})
    else
        TC.chosenPublic = not TC.chosenPublic
        updateCampActionButtons()
        message("Camp creation set to " .. (TC.chosenPublic and "Public" or "Private"))
    end
end, 24, campsActionsFrame)
setTooltip(btnPublic, "Camp Visibility", "Toggle whether your camp is Public (discoverable and visitable by all players) or Private (only you).")

btnRadius = button("Size: 40y", 176, 0, 74, function()
    local cur = TC.hasCamp and TC.campRadius or TC.chosenRadius or 40
    local nextR = 40
    if cur == 20 then nextR = 40
    elseif cur == 40 then nextR = 60
    elseif cur == 60 then nextR = 80
    else nextR = 20 end
    TC.chosenRadius = nextR
    if TC.hasCamp then
        request("RADIUS", {nextR})
    else
        updateCampActionButtons()
        message("Camp creation size set to " .. nextR .. " yards.")
    end
end, 24, campsActionsFrame)
setTooltip(btnRadius, "Camp Territory Size", "Cycle the camp territory radius between 20y, 40y, 60y, and 80y. All props placed within this radius belong to your camp.")

local btnVisit = button("Visit Camp", 254, 0, 80, function()
    if TC.selected and TC.selected.kind == "camp" then request("VISIT", {TC.selected.id})
    else request("GO", {}) end
end, 24, campsActionsFrame)
setTooltip(btnVisit, "Visit Camp", "Teleport directly to your camp or selected public camp.")

breakButton = button("Delete Camp", 338, 0, 92, function()
    if TC.confirmUntil and GetTime()<TC.confirmUntil then
        request("BREAK", {"CONFIRM"}); TC.confirmUntil=nil; breakButton:SetText("Delete Camp")
    else request("BREAK", {"REQUEST"}) end
end, 24, campsActionsFrame)
setTooltip(breakButton, "Delete Camp", "Permanently remove your camp and dismantle all camp objects.")

local btnStatusRefresh = button("Refresh", 434, 0, 82, function()
    request("STATUS", {})
    request("CAMPS", {TC.page or 0})
end, 24, campsActionsFrame)
setTooltip(btnStatusRefresh, "Refresh Camps", "Query latest camp limits and refresh public camp listings.")

local function updateContextualPanels()
    catActionsFrame:Hide(); ownedActionsFrame:Hide(); campsActionsFrame:Hide()
    if TC.view == "OBJECTS" then
        ownedActionsFrame:Show()
        updateCampFilterBtn()
    elseif TC.view == "CAMPS" then
        campsActionsFrame:Show()
        updateCampActionButtons()
    else
        catActionsFrame:Show()
        updateCategoryChips()
    end
end

-- Bottom Transform Bar (Only active when previewing/editing an object)
local transformCard = CreateFrame("Frame", "TurtleCampsTransformCard", frame)
transformCard:SetWidth(808); transformCard:SetHeight(154)
transformCard:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
transformCard:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
transformCard:SetBackdropColor(0.03, 0.04, 0.06, 0.92)
transformCard:SetBackdropBorderColor(0.5, 0.5, 0.6, 0.7)

local hudCoords = transformCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hudCoords:SetPoint("TOPLEFT", transformCard, "TOPLEFT", 12, -8)
hudCoords:SetWidth(784); hudCoords:SetJustifyH("LEFT")
hudCoords:SetText("|cff888888No active preview. Select an item and click Preview to begin.|r")

local function delta(x, y, z, o)
    if not TC.token then message("Preview or edit an object first."); return end
    local step = TC.step or 0.5
    if IsShiftKeyDown() then step = step * 4
    elseif IsControlKeyDown() then step = step * 0.2 end
    request("DELTA", {TC.token, x * step, y * step, z * step, o * (step / 0.5)})
end

-- Movement Buttons inside transformCard
local btnFwd = button("Fwd \226\150\178", 12, -32, 68, function() delta(1,0,0,0) end, 24, transformCard)
setTooltip(btnFwd, "Move Forward", "Nudge the preview prop forward relative to your character's facing direction.")

local btnBack = button("Back \226\150\188", 84, -32, 68, function() delta(-1,0,0,0) end, 24, transformCard)
setTooltip(btnBack, "Move Backward", "Nudge the preview prop backward relative to your character's facing direction.")

local btnLeft = button("\226\151\132 Left", 156, -32, 68, function() delta(0,1,0,0) end, 24, transformCard)
setTooltip(btnLeft, "Strafe Left", "Nudge the preview prop to the left relative to your character's facing direction.")

local btnRight = button("Right \226\150\182", 228, -32, 68, function() delta(0,-1,0,0) end, 24, transformCard)
setTooltip(btnRight, "Strafe Right", "Nudge the preview prop to the right relative to your character's facing direction.")

local btnRaise = button("Raise \226\150\178", 300, -32, 68, function() delta(0,0,1,0) end, 24, transformCard)
setTooltip(btnRaise, "Raise Elevation", "Move the preview prop upward along the vertical Z-axis.")

local btnLower = button("Lower \226\150\188", 372, -32, 68, function() delta(0,0,-1,0) end, 24, transformCard)
setTooltip(btnLower, "Lower Elevation", "Move the preview prop downward along the vertical Z-axis.")

local btnGround = button("Ground", 444, -32, 74, function() if TC.token then request("SNAP", {TC.token}) end end, 24, transformCard)
setTooltip(btnGround, "Snap Ground", "Raycast terrain and floor geometry to snap the prop flush with the surface (Hotkey: G).")

local btnYawL = button("Yaw \226\134\182", 522, -32, 68, function() delta(0,0,0,0.261799) end, 24, transformCard)
setTooltip(btnYawL, "Rotate Left", "Rotate the preview prop 15 degrees counter-clockwise.")

local btnYawR = button("Yaw \226\134\183", 594, -32, 68, function() delta(0,0,0,-0.261799) end, 24, transformCard)
setTooltip(btnYawR, "Rotate Right", "Rotate the preview prop 15 degrees clockwise.")

-- Sensitivity presets
local stepButtons = {}
local function updateStepHighlights()
    for s, btn in pairs(stepButtons) do
        if TC.step == s then btn:LockHighlight() else btn:UnlockHighlight() end
    end
end
stepButtons[0.1] = button("0.1y", 668, -32, 34, function() TC.step=0.1; updateStepHighlights() end, 24, transformCard)
stepButtons[0.5] = button("0.5y", 706, -32, 34, function() TC.step=0.5; updateStepHighlights() end, 24, transformCard)
stepButtons[2.0] = button("2.0y", 744, -32, 34, function() TC.step=2.0; updateStepHighlights() end, 24, transformCard)
setTooltip(stepButtons[0.1], "Fine Step", "0.1 yard precision adjustments")
setTooltip(stepButtons[0.5], "Normal Step", "0.5 yard standard distance")
setTooltip(stepButtons[2.0], "Coarse Step", "2.0 yard distance for larger movements")
updateStepHighlights()

-- Row 2 of Transform Bar: Save, Cancel, Undo, Status, GM/Camp, and Reload Cache
local btnSave = button("Save Spawn", 12, -66, 96, function()
    if TC.token then request("SAVE", {TC.token}) end
end, 26, transformCard)
setTooltip(btnSave, "Save Spawn", "Commit the prop's position and rotation permanently to the database.")

local btnCancel = button("Cancel", 112, -66, 76, function()
    if TC.token then request("CANCEL", {TC.token}) end
end, 26, transformCard)
setTooltip(btnCancel, "Cancel Preview", "Discard current placement adjustments and despawn the live preview.")

local btnUndo = button("Undo", 192, -66, 68, function() request("UNDO", {}) end, 26, transformCard)
setTooltip(btnUndo, "Undo Last Action", "Revert the most recent spawn, movement, or deletion action in your camp.")

local btnStatus = button("Status", 264, -66, 68, function() request("STATUS", {}) end, 26, transformCard)
setTooltip(btnStatus, "Query Status", "Check current prop usage quota, camp radius, and active permissions.")

local btnMode = button("GM / Camp", 336, -66, 88, function() request("MODE", {TC.mode=="GM" and "CAMP" or "GM"}) end, 26, transformCard)
setTooltip(btnMode, "Toggle Builder Mode", "Switch between Camp Mode (quota/radius restricted) and GM Mode (unrestricted world builder).")

local btnReload = button("Reload Cache", 428, -66, 96, function() request("RELOAD", {}) end, 26, transformCard)
setTooltip(btnReload, "Reload Cache", "Request the server to reload its prop catalog and permissions cache from the database.")

local subFooter = transformCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subFooter:SetPoint("BOTTOMLEFT", transformCard, "BOTTOMLEFT", 12, 8)
subFooter:SetText("|cff777777On-demand database browsing. Full support for props, buildings, creatures & items.|r")

-- Update Button States (Disables / Greys out buttons when not available)
updateButtonStates = function()
    local hasToken = (TC.token ~= nil)
    local moveControls = { btnFwd, btnBack, btnLeft, btnRight, btnRaise, btnLower, btnGround, btnYawL, btnYawR, btnSave, btnCancel }
    for _, b in ipairs(moveControls) do
        if hasToken then b:Enable() else b:Disable() end
    end

    local hasCatSel = (TC.selected and (TC.selected.kind == "prop" or TC.selected.kind == "npc" or TC.selected.kind == "creature" or TC.selected.kind == "item"))
    if hasCatSel then btnPreview:Enable(); btnFavorite:Enable() else btnPreview:Disable(); btnFavorite:Disable() end

    local hasOwnedSel = (TC.selected and TC.selected.kind == "object")
    if hasOwnedSel then btnEdit:Enable(); btnDuplicate:Enable(); btnDelete:Enable()
    else btnEdit:Disable(); btnDuplicate:Disable(); btnDelete:Disable() end

    local hasCampSel = (TC.selected and TC.selected.kind == "camp")
    if hasCampSel then btnVisit:Enable() else btnVisit:Disable() end
end

local function getCompassDir(deg)
    deg = math.mod(deg + 22.5, 360)
    local dirs = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    local idx = math.floor(deg / 45) + 1
    return dirs[idx] or "N"
end

refresh = function()
    TC.selected = nil
    render()
    update2DPicture(nil)
    updateWebLink()
    updateTabHighlights()
    updateContextualPanels()
    updateButtonStates()

    if TC.view=="CATALOG" or TC.view=="BUILDINGS" or TC.view=="CREATURES" or TC.view=="ITEMS" then
        local cat = category:GetText()
        if TC.view=="BUILDINGS" and cat=="" then cat="Buildings"
        elseif TC.view=="CREATURES" and cat=="" then cat="Creatures"
        elseif TC.view=="ITEMS" and cat=="" then cat="Items" end
        request("SEARCH", {query:GetText(), cat, TC.page})
    elseif TC.view=="OBJECTS" then request("OBJECTS", {TC.page, TC.campFilter or 0})
    elseif TC.view=="CAMPS" then request("CAMPS", {TC.page})
    else
        TC.rows={}
        local entries={}
        if TC.view=="FAVORITES" then
            for entry,item in pairs(TurtleCampsDB.favorites) do
                if type(item)=="table" then
                    tinsert(entries,{entry=entry,name=item.name,kind=item.kind or "prop",entityKind=item.entityKind or 0})
                else
                    tinsert(entries,{entry=entry,name=item,kind="prop",entityKind=0})
                end
            end
            table.sort(entries,function(a,b) return tonumber(a.entry)<tonumber(b.entry) end)
        else
            entries = TurtleCampsDB.recent
        end
        local nEntries = table.getn(entries)
        for i=TC.page*8+1,math.min(nEntries,TC.page*8+8) do
            local e=entries[i]
            local eKind = tonumber(e.entityKind) or (e.kind == "npc" and 1 or (e.kind == "item" and 2 or 0))
            local kTag = (eKind == 1) and "npc" or ((eKind == 2) and "item" or "prop")
            tinsert(TC.rows,{kind=kTag,entityKind=eKind,id=e.entry,name=e.name,category="(Saved)",detail=e.name.." (Saved Entry "..e.entry..")"})
        end
        local totalPages = math.max(1, math.ceil(nEntries / 8))
        TC.totalPages = totalPages
        pageText:SetText(string.format("%d/%d", TC.page+1, totalPages))
        render()
    end
end

query:SetScript("OnEnterPressed", function() TC.page=0; refresh(); this:ClearFocus() end)
category:SetScript("OnEnterPressed", function() TC.page=0; refresh(); this:ClearFocus() end)

-- MouseWheel Nudge Listener on main canvas / list scrolling
frame:SetScript("OnMouseWheel", function()
    local dir = arg1
    local overTable = false
    if MouseIsOver then
        overTable = MouseIsOver(tableFrame)
    end
    if overTable or not TC.token then
        scrollTable(dir)
        return
    end
    if TC.token then
        if IsShiftKeyDown() then delta(0, 0, 0, dir * 0.261799)
        elseif IsControlKeyDown() then delta(dir, 0, 0, 0)
        elseif IsAltKeyDown() then delta(0, dir, 0, 0)
        else delta(0, 0, dir, 0) end
    end
end)

-- Event Dispatcher
local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_SYSTEM")

events:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if type(TurtleCampsDB) ~= "table" then TurtleCampsDB = {} end
        if type(TurtleCampsDB.favorites) ~= "table" then TurtleCampsDB.favorites = {} end
        if type(TurtleCampsDB.recent) ~= "table" then TurtleCampsDB.recent = {} end
        local clean = {}; local n = 0
        for id, item in pairs(TurtleCampsDB.favorites) do
            if n < 50 and tonumber(id) then
                if type(item) == "table" and item.name then
                    clean[tostring(id)] = {
                        name = string.sub(item.name, 1, 48),
                        kind = item.kind or "prop",
                        entityKind = tonumber(item.entityKind) or 0
                    }
                    n = n + 1
                elseif type(item) == "string" then
                    clean[tostring(id)] = { name = string.sub(item, 1, 48), kind = "prop", entityKind = 0 }
                    n = n + 1
                end
            end
        end
        TurtleCampsDB.favorites = clean; clean = {}
        for i = 1, math.min(20, table.getn(TurtleCampsDB.recent)) do
            local e = TurtleCampsDB.recent[i]
            if type(e) == "table" and tonumber(e.entry) and type(e.name) == "string" then
                tinsert(clean, {
                    entry = e.entry,
                    name = string.sub(e.name, 1, 48),
                    kind = e.kind or "prop",
                    entityKind = tonumber(e.entityKind) or 0
                })
            end
        end
        TurtleCampsDB.recent = clean
    elseif event == "PLAYER_ENTERING_WORLD" then
        TC.ready = false; TC.token = nil; TC.queue = {}; TC.pending = nil
        statusDot:SetText("|cffffaa00\226\151\143|r")
        hudCoords:SetText("|cff888888No active preview. Select an item and click Preview to begin.|r")
        updateButtonStates()
        connect(true)
    elseif event == "CHAT_MSG_SYSTEM" and type(arg1) == "string" and string.sub(arg1, 1, 8) == "TCAMP/1~" then
        local f = split(arg1); local id = tonumber(f[2]); local op = f[3]
        if not TC.pending or id ~= TC.pending.id then return end
        if op == "BEGIN" then
            TC.rows = {}; TC.selected = nil
        elseif op == "ITEM" then
            if table.getn(TC.rows) < 8 then
                local eKind = tonumber(f[11]) or 0
                local kindTag = "prop"
                if eKind == 1 then kindTag = "creature" elseif eKind == 2 then kindTag = "item" end
                tinsert(TC.rows, {
                    kind = kindTag,
                    entityKind = eKind,
                    id = f[4],
                    name = f[5],
                    display = tonumber(f[7]),
                    size = tonumber(f[8]) or 1,
                    category = f[9],
                    detail = f[5] .. " | Entry " .. f[4] .. " Type " .. f[6] .. " Display " .. f[7]
                })
            end
        elseif op == "OBJECT" then
            if table.getn(TC.rows) < 8 then
                local eKind = tonumber(f[9]) or 0
                local kindLabel = (eKind == 1) and "Creature" or "Spawn"
                local campId = tonumber(f[10]) or 0
                tinsert(TC.rows, {
                    kind = "object",
                    entityKind = eKind,
                    id = f[4],
                    entry = f[5],
                    name = kindLabel .. " #" .. f[4] .. " (Entry " .. f[5] .. ")",
                    category = string.format("%.1f, %.1f, %.1f", tonumber(f[6]) or 0, tonumber(f[7]) or 0, tonumber(f[8]) or 0),
                    camp = campId,
                    detail = "GUID " .. f[4] .. " Entry " .. f[5] .. " at (" .. f[6] .. ", " .. f[7] .. ", " .. f[8] .. ")" .. (campId > 0 and (" [Camp #" .. campId .. "]") or " [World]")
                })
            end
        elseif op == "CAMP" then
            if table.getn(TC.rows) < 8 then
                local isPub = (f[9] == "PUBLIC")
                local visTag = isPub and " |cff00ff00[Public]|r" or " |cff888888[Private]|r"
                local rad = tonumber(f[10]) or 40
                tinsert(TC.rows, {
                    kind = "camp",
                    id = f[4],
                    radius = rad,
                    name = "Camp #" .. f[4] .. visTag,
                    category = "Map " .. f[5] .. " | " .. f[8] .. " props (" .. rad .. "y)",
                    detail = "Camp #" .. f[4] .. " on Map " .. f[5] .. " (" .. f[6] .. ", " .. f[7] .. ") with " .. f[8] .. " objects (Radius " .. rad .. "y)" .. (isPub and " (Public)" or " (Private)")
                })
            end
        elseif op == "END" then
            local total = tonumber(f[5]) or 0
            local curPage = tonumber(f[6]) or 0
            local totalPages = math.max(1, math.ceil(total / 8))
            TC.totalPages = totalPages
            pageText:SetText(string.format("%d/%d", curPage + 1, totalPages))
            render()
            message(f[4] .. ": " .. total .. " results, page " .. (curPage + 1))
        elseif op == "HELLO" then
            TC.ready = f[4] == "1"; TC.mode = f[5] == "1" and "GM" or "CAMP"
            TC.isConnecting = false
            if TC.ready then
                statusDot:SetText("|cff00ff00\226\151\143|r")
                message("Connected — " .. TC.mode .. " mode")
                request("STATUS", {})
                if frame:IsShown() and table.getn(TC.rows) == 0 and table.getn(TC.queue) <= 1 then
                    refresh()
                end
            else
                statusDot:SetText("|cffff0000\226\151\143|r")
                message("Module disabled or database prerequisite missing.")
            end
            updateButtonStates()
        elseif op == "PUBLIC" then
            TC.isPublic = (f[4] == "1")
            TC.chosenPublic = TC.isPublic
            message("Camp visibility: " .. (TC.isPublic and "|cff00ff00Public|r (visitors allowed)" or "|cffffaa00Private|r (only you)"))
            updateCampActionButtons()
        elseif op == "EDIT" then
            TC.token = f[4]
            TC.editEntry = f[5]
            TC.editKind = tonumber(f[10]) or 0
            local deg = math.floor((tonumber(f[9]) or 0) * 180 / 3.14159265 + 0.5)
            deg = math.mod(deg, 360)
            if deg < 0 then deg = deg + 360 end
            local comp = getCompassDir(deg)
            local kindName = (f[10] == "1") and "Creature" or "Object"
            hudCoords:SetText("|cff00ff00Editing " .. kindName .. " " .. f[5] .. "|r | X: " .. string.format("%.2f", f[6]) .. " Y: " .. string.format("%.2f", f[7]) .. " Z: " .. string.format("%.2f", f[8]) .. " | Yaw: " .. deg .. "\194\176 [" .. comp .. "]")
            updateWebLink()
            updateButtonStates()
        elseif op == "SAVED" then
            local name = f[5]
            local savedKind = "prop"
            local savedEntityKind = 0
            if TC.selected then
                if TC.selected.name then name = TC.selected.name end
                savedKind = TC.selected.kind or "prop"
                savedEntityKind = TC.selected.entityKind or 0
            end
            for i = table.getn(TurtleCampsDB.recent), 1, -1 do
                if tostring(TurtleCampsDB.recent[i].entry) == f[5] then tremove(TurtleCampsDB.recent, i) end
            end
            tinsert(TurtleCampsDB.recent, 1, { entry = f[5], name = name, kind = savedKind, entityKind = savedEntityKind })
            while table.getn(TurtleCampsDB.recent) > 20 do tremove(TurtleCampsDB.recent) end
            TC.token = nil; TC.editEntry = nil
            hudCoords:SetText("|cff00ff00Saved spawn " .. f[4] .. "|r")
            message("Saved spawn " .. f[4])
            updateButtonStates()
        elseif op == "DELETED" then
            local delId = f[4]
            TC.token = nil; TC.editEntry = nil
            hudCoords:SetText("|cff00ff00Deleted spawn #" .. delId .. "|r")
            message("Deleted spawn #" .. delId)
            if TC.selected and tostring(TC.selected.id) == tostring(delId) then
                TC.selected = nil
                update2DPicture(nil)
                updateWebLink()
            end
            for i = table.getn(TC.rows), 1, -1 do
                if tostring(TC.rows[i].id) == tostring(delId) then
                    tremove(TC.rows, i)
                end
            end
            render()
            updateButtonStates()
            if TC.view == "OBJECTS" then
                request("OBJECTS", {TC.page or 0})
            end
        elseif op == "UNDONE" then
            TC.token = nil; TC.editEntry = nil
            hudCoords:SetText("|cff00ff00Action undone|r")
            message("Action undone.")
            updateButtonStates()
            if TC.view == "OBJECTS" then
                request("OBJECTS", {TC.page or 0})
            end
        elseif op == "CLAIMED" then
            TC.hasCamp = true
            TC.myCampId = tonumber(f[4])
            TC.isPublic = (f[5] == "1")
            TC.chosenPublic = TC.isPublic
            TC.campRadius = tonumber(f[6]) or 40
            TC.chosenRadius = TC.campRadius
            message("Camp established/updated! (Radius: " .. TC.campRadius .. "y, " .. (TC.isPublic and "Public" or "Private") .. ")")
            updateCampActionButtons()
            request("STATUS", {})
            if TC.view == "CAMPS" then
                request("CAMPS", {0})
            end
        elseif op == "RADIUS" then
            TC.campRadius = tonumber(f[4]) or 40
            TC.chosenRadius = TC.campRadius
            message("Camp radius updated to " .. TC.campRadius .. " yards.")
            updateCampActionButtons()
        elseif op == "TRAVEL" then
            message("Teleporting to camp...")
        elseif op == "BROKEN" then
            TC.token = nil; TC.editEntry = nil; TC.rows = {}; TC.selected = nil
            TC.hasCamp = false
            TC.myCampId = nil
            hudCoords:SetText("|cff888888No active preview. Select an item and click Preview to begin.|r")
            message("Camp dismantled and all objects removed.")
            updateCampActionButtons()
            render()
            updateButtonStates()
            request("STATUS", {})
        elseif op == "CANCEL" or op == "MODE" then
            TC.token = nil; TC.editEntry = nil
            hudCoords:SetText("|cff888888No active preview. Select an item and click Preview to begin.|r")
            if op == "MODE" then TC.mode = f[4] end
            message(op .. " " .. (f[4] or ""))
            updateButtonStates()
        elseif op == "STATUS" then
            TC.campUsage = f[6] .. " / " .. f[7]
            TC.campRadius = tonumber(f[8]) or 40
            TC.chosenRadius = TC.campRadius
            TC.hasCamp = (f[10] == "1")
            if f[11] then
                TC.isPublic = (f[11] == "1")
                TC.chosenPublic = TC.isPublic
            end
            updateCampActionButtons()
            message("Mode: " .. f[5] .. " | Props: " .. f[6] .. "/" .. f[7] .. " | Radius: " .. f[8] .. "y | Has Camp: " .. (TC.hasCamp and "Yes" or "No"))
        elseif op == "CONFIRM" then
            TC.confirmUntil = GetTime() + 15
            breakButton:SetText("CONFIRM (15s)")
            message("Delete camp removes all camp objects. Click again within 15 seconds.")
        elseif op == "RELOAD" then
            TC.ready = false; TC.token = nil; TC.editEntry = nil
            statusDot:SetText("|cffff0000\226\151\143|r")
            message("Server cache reloaded.")
            updateButtonStates()
            connect(true)
        elseif op == "ERROR" then
            local errCode = f[4] or "ERROR"
            message("Server: " .. errCode)
            if errCode == "HANDSHAKE_OR_REPLAY" then
                TC.ready = false; TC.isConnecting = false
                connect(true)
            elseif errCode == "STALE_EDIT" then
                TC.token = nil; TC.editEntry = nil; TC.queue = {}
                hudCoords:SetText("|cffff0000Edit expired — preview again|r")
                updateButtonStates()
            end
        else
            message(op .. " " .. (f[4] or ""))
        end
        if op ~= "BEGIN" and op ~= "ITEM" and op ~= "OBJECT" and op ~= "CAMP" then TC.pending = nil end
    end
end)

events:SetScript("OnUpdate", function()
    local now = GetTime()
    if TC.confirmUntil then
        local left = math.ceil(TC.confirmUntil - now)
        if left > 0 then
            breakButton:SetText("CONFIRM (" .. left .. "s)")
        else
            TC.confirmUntil = nil; breakButton:SetText("Delete Camp")
        end
    end
    if TC.pending and (now - TC.pending.sent) > 5 then
        TC.pending = nil; TC.queue = {}; TC.ready = false; TC.isConnecting = false; TC.token = nil; TC.editEntry = nil
        statusDot:SetText("|cffff0000\226\151\143|r")
        message("Server request timed out. Retrying connection...")
        hudCoords:SetText("|cffff0000Connection timed out — retrying|r")
        updateButtonStates()
        connect(true)
    end
    if TC.pending or now < TC.nextSend or table.getn(TC.queue) == 0 then return end
    local q = tremove(TC.queue, 1); TC.serial = TC.serial + 1
    local line = "1~" .. TC.serial .. "~" .. q.op
    for _, v in ipairs(q.fields) do line = line .. "~" .. escape(v) end
    if string.len(line) > 210 then message("Request too long."); return end
    TC.pending = { id = TC.serial, sent = now }; TC.nextSend = now + 0.25
    SendChatMessage(".camp " .. line, "WHISPER", nil, UnitName("player"))
end)

-- Global Keybinding Hooks
function TurtleCamps_Toggle()
    if frame:IsShown() then
        if TC.token then request("CANCEL", {TC.token}) end
        frame:Hide()
    else
        frame:Show()
        if not TC.ready then
            connect(true)
        elseif table.getn(TC.rows) == 0 then
            refresh()
        end
    end
end
function TurtleCamps_Save() if TC.token then request("SAVE", {TC.token}) end end
function TurtleCamps_Cancel() if TC.token then request("CANCEL", {TC.token}) end end
function TurtleCamps_Ground() if TC.token then request("SNAP", {TC.token}) end end
function TurtleCamps_Undo() request("UNDO", {}) end
function TurtleCamps_Delta(x, y, z, o) delta(x, y, z, o) end

SLASH_TURTLECAMPS1 = "/tc"
SLASH_TURTLECAMPS2 = "/turtlecamps"
SlashCmdList["TURTLECAMPS"] = function(msg)
    if msg and msg ~= "" then
        local _, _, cmd, arg = string.find(msg, "^(%S+)%s*(.*)")
        if cmd then cmd = string.lower(cmd) end
        if cmd == "go" or cmd == "home" or cmd == "visit" then
            if not TC.ready then connect(true) end
            if arg and arg ~= "" and tonumber(arg) then
                request("VISIT", {tonumber(arg)})
                message("Visiting camp #" .. arg .. "...")
            else
                request("GO", {})
                message("Teleporting to your camp...")
            end
            return
        end
        if cmd == "delete" or cmd == "del" or cmd == "remove" then
            local guid = tonumber(arg)
            if guid and guid > 0 then
                if not TC.ready then connect(true) end
                if TC.token then request("CANCEL", {TC.token}) end
                request("DELETE", {guid})
                message("Force deleting spawn #" .. guid .. "...")
                for i = table.getn(TC.rows), 1, -1 do
                    if tostring(TC.rows[i].id) == tostring(guid) then
                        tremove(TC.rows, i)
                    end
                end
                if TC.selected and tostring(TC.selected.id) == tostring(guid) then
                    TC.selected = nil
                    update2DPicture(nil)
                    updateWebLink()
                end
                render()
            else
                message("Usage: /tc delete <guid>")
            end
            return
        end
        if cmd == "spawn" or cmd == "preview" then
            local _, _, idStr, kindStr = string.find(arg, "^(%d+)%s*(%a*)")
            local entry = tonumber(idStr)
            if entry and entry > 0 then
                local kind = 0
                if kindStr then
                    kindStr = string.lower(kindStr)
                    if kindStr == "npc" or kindStr == "creature" or kindStr == "1" then kind = 1
                    elseif kindStr == "item" or kindStr == "2" then kind = 2 end
                end
                if not frame:IsShown() then frame:Show() end
                connect(true)
                if TC.token then request("CANCEL", {TC.token}) end
                request("PREVIEW", {entry, kind})
                message("Previewing entry " .. entry .. " (type " .. kind .. ")...")
                return
            else
                message("Usage: /tc spawn <entry_id> [object|creature|item]")
                return
            end
        end
    end
    TurtleCamps_Toggle()
end

