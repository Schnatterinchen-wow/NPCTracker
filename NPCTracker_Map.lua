--[[
  World map pins + zone NPC list (your observations only).
  Pins use colored squares; no minimap layer in this version.
]]

local MAP = {}

local function defaultMapSettings()
  return {
    zoneEnabled = {},
    npcEnabled = {},
    panelPoint = nil,
  }
end

function MAP.EnsureMapSettings()
  if type(NPCTrackerMapSettings) ~= "table" then
    NPCTrackerMapSettings = defaultMapSettings()
    return
  end
  local m = NPCTrackerMapSettings
  if type(m.zoneEnabled) ~= "table" then
    m.zoneEnabled = {}
  end
  if type(m.npcEnabled) ~= "table" then
    m.npcEnabled = {}
  end
end

MAP.EnsureMapSettings()

local PIN_MAX = 800
local LIST_ROWS = 18
local ROW_HEIGHT = 18

local pinParent
local pinPool = {}
local pinCount = 0
local lastDrawT = 0
local DRAW_THROTTLE = 0.15

local panel
local scrollNames = {}
local scrollOffset = 0
local currentContinent
local currentZone
local currentNameList = {}

local TEXTURE_PIN = "Interface\\Buttons\\WHITE8X8"

local COLOR_OBS = { 1.0, 0.85, 0.15 }

local function ensurePath(t, k1, k2)
  if not t[k1] then t[k1] = {} end
  if k2 and not t[k1][k2] then t[k1][k2] = {} end
end

local function continentNameFromIndex(ci)
  if not ci or ci <= 0 then return nil end
  local c = { GetMapContinents() }
  return c[ci]
end

local function zoneNameFromIndex(ci, zi)
  if not ci or ci <= 0 then return nil end
  if not zi or zi == 0 then
    return continentNameFromIndex(ci)
  end
  local z = { GetMapZones(ci) }
  return z[zi]
end

local function ensureMapFilters()
  MAP.EnsureMapSettings()
end

function MAP.IsZoneEnabled(cont, zone)
  MAP.EnsureMapSettings()
  if not cont or not zone then return false end
  local z = NPCTrackerMapSettings.zoneEnabled[cont]
  return z and z[zone] == true
end

local function npcHiddenForZone(cont, zone, name)
  ensurePath(NPCTrackerMapSettings, "npcEnabled", cont)
  local v = NPCTrackerMapSettings.npcEnabled[cont][zone]
  if not v or v[name] == nil then return false end
  return v[name] == false
end

--- Zone keys that share the same map bucket (parent zone + subzones like "Westfall / Cave").
local function zoneKeysForBucket(cont, mapZone)
  local keys = {}
  local seen = {}
  local function add(z)
    if not z or seen[z] then return end
    seen[z] = true
    table.insert(keys, z)
  end
  add(mapZone)
  for _, entryBlock in pairs(NPCTrackerObservationDB.observationsByEntry) do
    if type(entryBlock) == "table" and type(entryBlock.entries) == "table" then
      for _, arr in pairs(entryBlock.entries) do
        if type(arr) == "table" then
          for i = 1, table.getn(arr) do
            local e = arr[i]
            if
              type(e) == "table"
              and e.continent == cont
              and e.zone
              and NPCTracker_ZoneBucketMatches(mapZone, e.zone)
            then
              add(e.zone)
            end
          end
        end
      end
    end
  end
  return keys
end

function MAP.IsNpcEnabled(cont, zone, name)
  if not MAP.IsZoneEnabled(cont, zone) then return false end
  ensurePath(NPCTrackerMapSettings, "npcEnabled", cont)
  for _, z in ipairs(zoneKeysForBucket(cont, zone)) do
    if npcHiddenForZone(cont, z, name) then return false end
  end
  return true
end

function MAP.SetZoneEnabled(cont, zone, on)
  MAP.EnsureMapSettings()
  ensurePath(NPCTrackerMapSettings, "zoneEnabled", cont)
  NPCTrackerMapSettings.zoneEnabled[cont][zone] = on and true or false
end

function MAP.SetNpcEnabled(cont, mapZone, name, on)
  MAP.EnsureMapSettings()
  ensurePath(NPCTrackerMapSettings, "npcEnabled", cont)
  for _, z in ipairs(zoneKeysForBucket(cont, mapZone)) do
    if not NPCTrackerMapSettings.npcEnabled[cont][z] then
      NPCTrackerMapSettings.npcEnabled[cont][z] = {}
    end
    if on then
      NPCTrackerMapSettings.npcEnabled[cont][z][name] = nil
    else
      NPCTrackerMapSettings.npcEnabled[cont][z][name] = false
    end
  end
end

function MAP.SetAllNpcs(cont, zone, on)
  MAP.EnsureMapSettings()
  ensurePath(NPCTrackerMapSettings, "npcEnabled", cont)
  local names = NPCTracker_ListNPCNamesForZone(cont, zone)
  if on then
    for _, z in ipairs(zoneKeysForBucket(cont, zone)) do
      NPCTrackerMapSettings.npcEnabled[cont][z] = nil
    end
  else
    for _, n in ipairs(names) do
      MAP.SetNpcEnabled(cont, zone, n, false)
    end
  end
end

local function getOrCreatePin(i)
  if not pinPool[i] then
    local f = CreateFrame("Frame", "NPCTrackerPin" .. i, pinParent)
    f:SetWidth(10)
    f:SetHeight(10)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture(TEXTURE_PIN)
    f.tex = t
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tipTitle or "NPC", 1, 1, 1)
      if self.tipSub then
        GameTooltip:AddLine(self.tipSub, 0.8, 0.8, 0.8)
      end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    pinPool[i] = f
  end
  return pinPool[i]
end

local function hidePins()
  for i = 1, pinCount do
    pinPool[i]:Hide()
  end
  pinCount = 0
end

local function showPin(xPct, yPct, r, g, b, title, sub)
  if pinCount >= PIN_MAX then return end
  pinCount = pinCount + 1
  local w = WorldMapDetailFrame:GetWidth()
  local h = WorldMapDetailFrame:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return end
  local px = xPct / 100 * w
  local py = -yPct / 100 * h
  local pin = getOrCreatePin(pinCount)
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", pinParent, "TOPLEFT", px, py)
  pin.tex:SetVertexColor(r, g, b, 0.95)
  pin.tipTitle = title
  pin.tipSub = sub
  pin:Show()
end

local function drawObservationPins(cont, zone, npc, data)
  if not data or not data.entries then return end
  ensureMapFilters()
  for _, e in pairs(data.entries) do
    if type(e) == "table" and e.x and e.y and NPCTracker_IsValidMapCoord(e.x, e.y) then
      local sub = "Observation"
      if e.source then
        sub = sub .. " (" .. tostring(e.source) .. ")"
      end
      if e.zone then
        sub = sub .. " @ " .. e.zone
      end
      if e.displayId then
        sub = sub .. " | display " .. tostring(e.displayId)
      end
      if e.dungeon and e.parentZone then
        sub = sub .. " | " .. tostring(e.dungeon) .. " (ref " .. tostring(e.parentZone) .. ")"
      end
      if e.classification then
        sub = sub .. " | " .. tostring(e.classification)
      end
    end
  end
end

function MAP.RefreshPins(force)
  hidePins()
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end
  if not pinParent then return end
  local t = GetTime()
  if not force and (t - lastDrawT < DRAW_THROTTLE) then return end
  lastDrawT = t

  local ci = GetCurrentMapContinent()
  local zi = GetCurrentMapZone()
  if not ci or ci <= 0 then return end
  local cName = continentNameFromIndex(ci)
  local zName = zoneNameFromIndex(ci, zi)
  if not cName or not zName then return end

  if not MAP.IsZoneEnabled(cName, zName) then return end

  local names = NPCTracker_ListNPCNamesForZone(cName, zName)
  for _, npc in ipairs(names) do
    if MAP.IsNpcEnabled(cName, zName, npc) then
      local src = NPCTracker_GetNPCBySource(cName, zName, npc)
      drawObservationPins(cName, zName, npc, src.observation)
    end
  end
end

local function updateNameList()
  currentNameList = NPCTracker_ListNPCNamesForZone(currentContinent, currentZone)
  local maxOffset = math.max(0, table.getn(currentNameList) - LIST_ROWS)
  if scrollOffset > maxOffset then scrollOffset = maxOffset end
  if scrollOffset < 0 then scrollOffset = 0 end

  for i = 1, LIST_ROWS do
    local row = scrollNames[i]
    local idx = i + scrollOffset
    if idx <= table.getn(currentNameList) then
      local name = currentNameList[idx]
      row.label:SetText(name)
      row:SetChecked(MAP.IsNpcEnabled(currentContinent, currentZone, name))
      row.npcName = name
      row:Show()
    else
      row:Hide()
    end
  end

  local sb = panel and panel.scrollBar
  if sb then
    local max = math.max(0, table.getn(currentNameList) - LIST_ROWS)
    if max < 0 then max = 0 end
    sb:SetMinMaxValues(0, max)
    if scrollOffset > max then scrollOffset = max end
    sb:SetValue(scrollOffset)
  end
end

local lastListContinent
local lastListZone

local function syncPanelFromMap()
  local ci = GetCurrentMapContinent()
  local zi = GetCurrentMapZone()
  if not ci or ci <= 0 then return end
  local cName = continentNameFromIndex(ci)
  local zName = zoneNameFromIndex(ci, zi)
  if cName ~= lastListContinent or zName ~= lastListZone then
    scrollOffset = 0
    lastListContinent = cName
    lastListZone = zName
  end
  currentContinent = cName
  currentZone = zName
  if panel and panel.title then
    panel.title:SetText("NPCTracker: " .. (currentZone or "?"))
  end
  if panel and panel.zoneCheck then
    panel.zoneCheck:SetChecked(MAP.IsZoneEnabled(currentContinent, currentZone))
  end
  updateNameList()
end

function MAP.RefreshPanel()
  if not panel then return end
  syncPanelFromMap()
end

function MAP.PrintChecklist()
  local tag = "|cff33ffccNPCTracker|r"
  DEFAULT_CHAT_FRAME:AddMessage(tag .. " — in-game checklist")
  local lines = {
    "/npct help — print this checklist in chat (same text as the panel Checklist button).",
    "Open the world map (M) so pins can refresh on the detail frame.",
    "/npct — toggle the panel; check “Show pins for this zone” (off by default until you enable it) and per-NPC boxes.",
    "Gold pins = your observations (zone label in tooltip when stored per sample). SuperWoW creature GUID required.",
    "/npct record (macro) — saves target or mouseover (creature 0xF130… GUID only).",
    "/npct patrol (alias /npct pat) — record up to 5 patrol points per spawn GUID (FIFO, 6th drops oldest); /npct patrol clear wipes the spawn's patrol path.",
    "/npct autorecord — on/off, mouseover on/off (auto skips re-hover of the same spawn GUID while it stays in a 5-GUID MRU ring; /npct record always saves).",
    "New or unlisted Turtle zones: continent falls back to the map or “Unknown”; your samples are still saved.",
    "Caves/interiors: when the minimap subzone differs from the zone name, storage uses “Zone / Subzone”.",
    "Bad coordinates (0,0 or outside 0–100) are not saved; run /npct prune to remove invalid samples from saved data.",
  }
  for _, line in ipairs(lines) do
    DEFAULT_CHAT_FRAME:AddMessage("  • " .. line)
  end
end

local function createPanel()
  if panel then return end
  MAP.EnsureMapSettings()
  local f = CreateFrame("Frame", "NPCTrackerMapPanel", UIParent)
  f:SetWidth(280)
  f:SetHeight(480)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  f:SetBackdropColor(0, 0, 0, 0.9)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    this:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local p, relTo, relP, x, y = this:GetPoint()
    NPCTrackerMapSettings.panelPoint = { p, relTo, relP, x, y }
  end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -12)
  title:SetText("NPCTracker")
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    f:Hide()
  end)

  local zoneCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  zoneCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
  zoneCheck:SetScript("OnClick", function()
    MAP.SetZoneEnabled(currentContinent, currentZone, this:GetChecked() == 1)
    MAP.RefreshPins()
  end)
  local zl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  zl:SetPoint("LEFT", zoneCheck, "RIGHT", 4, 0)
  zl:SetText("Show pins for this zone")
  f.zoneCheck = zoneCheck

  local allOn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  allOn:SetWidth(72)
  allOn:SetHeight(22)
  allOn:SetPoint("TOPLEFT", zoneCheck, "BOTTOMLEFT", 0, -8)
  allOn:SetText("All on")
  allOn:SetScript("OnClick", function()
    MAP.SetAllNpcs(currentContinent, currentZone, true)
    updateNameList()
    MAP.RefreshPins()
  end)

  local allOff = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  allOff:SetWidth(72)
  allOff:SetHeight(22)
  allOff:SetPoint("LEFT", allOn, "RIGHT", 8, 0)
  allOff:SetText("All off")
  allOff:SetScript("OnClick", function()
    MAP.SetAllNpcs(currentContinent, currentZone, false)
    updateNameList()
    MAP.RefreshPins()
  end)

  local leg = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leg:SetPoint("TOPLEFT", allOn, "BOTTOMLEFT", 0, -6)
  leg:SetText("|cffeecc11■|r Your observations")
  leg:SetWidth(260)

  ensureMapFilters()
  local helpBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  helpBtn:SetWidth(96)
  helpBtn:SetHeight(22)
  helpBtn:SetPoint("TOPLEFT", leg, "BOTTOMLEFT", 0, -8)
  helpBtn:SetText("Checklist")
  helpBtn:SetScript("OnClick", function()
    MAP.PrintChecklist()
  end)

  local sb = CreateFrame("Slider", "NPCTrackerMapScrollBar", f, "UIPanelScrollBarTemplate")
  sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -200)
  sb:SetHeight(LIST_ROWS * ROW_HEIGHT + 4)
  sb:SetMinMaxValues(0, 0)
  sb:SetValueStep(1)
  sb:SetValue(0)
  sb:SetScript("OnValueChanged", function()
    scrollOffset = math.floor(this:GetValue())
    updateNameList()
  end)
  f.scrollBar = sb

  for i = 1, LIST_ROWS do
    local cb = CreateFrame("CheckButton", "NPCTrackerMapRow" .. i, f, "UICheckButtonTemplate")
    cb:SetWidth(240)
    cb:SetHeight(ROW_HEIGHT)
    cb:SetPoint("TOPLEFT", helpBtn, "BOTTOMLEFT", 0, -8 - (i - 1) * ROW_HEIGHT)
    local bt = getglobal("NPCTrackerMapRow" .. i .. "Text")
    if bt then bt:SetText("") end
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetWidth(200)
    fs:SetJustifyH("LEFT")
    cb.label = fs
    cb:SetScript("OnClick", function()
      local name = this.npcName
      if not name then return end
      MAP.SetNpcEnabled(currentContinent, currentZone, name, this:GetChecked() == 1)
      MAP.RefreshPins()
    end)
    scrollNames[i] = cb
  end

  local pt = NPCTrackerMapSettings.panelPoint
  if pt and pt[5] then
    f:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
  elseif pt and pt[4] and not pt[5] then
    f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else
    f:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
  end

  panel = f
end

local function createPinLayer()
  if pinParent then return end
  if not WorldMapDetailFrame then return end
  pinParent = CreateFrame("Frame", "NPCTrackerWorldMapPins", WorldMapDetailFrame)
  pinParent:SetAllPoints(WorldMapDetailFrame)
  pinParent:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 20)
end

--- Map/prune/help slash subcommands (registered from NPCTracker_Record.lua after all files load).
function MAP.HandleSlashMsg(msg)
  MAP.EnsureMapSettings()
  msg = string.lower(msg or "")
  if msg == "help" or msg == "checklist" then
    MAP.PrintChecklist()
    return
  end
  if msg == "prune" then
    local n = NPCTracker_PruneInvalidObservations()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r pruned " .. n .. " invalid coordinate sample(s).")
    MAP.RefreshPins(true)
    return
  end
  if msg == "map" or msg == "" then
    if not panel then createPanel() end
    if panel:IsVisible() then
      panel:Hide()
    else
      panel:Show()
      syncPanelFromMap()
      MAP.RefreshPins()
    end
  elseif msg == "pins" then
    MAP.RefreshPins(true)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("WORLD_MAP_UPDATE")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

loader:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "NPCTracker" then
    MAP.EnsureMapSettings()
    createPanel()
    createPinLayer()
    local prevShow = WorldMapFrame:GetScript("OnShow")
    WorldMapFrame:SetScript("OnShow", function()
      if prevShow then prevShow() end
      createPinLayer()
      MAP.RefreshPins(true)
      if panel and panel:IsVisible() then
        syncPanelFromMap()
      end
    end)
  elseif event == "WORLD_MAP_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    if pinParent then
      MAP.RefreshPins()
    end
    if panel and panel:IsVisible() then
      syncPanelFromMap()
    end
  end
end)

NPCTracker_Map = MAP
