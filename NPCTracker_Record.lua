--[[
  Observations → NPCTrackerObservationDB (SuperWoW only)

  Storage: npc entry id → { npcName, entries[guidKey] = { sample, … } }.
  Each sample carries continent/zone; the spawn GUID is the table key, not a field on the row.
  t = GetTime() (session time, seconds) rounded; not world z/elevation. Use displayId for model variant.
  Auto: can store many samples per (entry id, same spawn GUID) up to a cap; oldest auto is dropped.
  Manual: each /npct record removes prior manual row(s) for that GUID, then stores one new manual; auto rows stay.
]]

local function ensureObsByEntry(entryId, gkey, npcName)
  local db = NPCTrackerObservationDB
  if not db.observationsByEntry then
    db.observationsByEntry = {}
  end
  if not db.observationsByEntry[entryId] then
    db.observationsByEntry[entryId] = { npcName = npcName, entries = {} }
  end
  local eb = db.observationsByEntry[entryId]
  if type(eb.entries) ~= "table" then
    eb.entries = {}
  end
  eb.npcName = npcName
  if not eb.entries[gkey] then
    eb.entries[gkey] = {}
  end
  return eb.entries[gkey]
end

--- At most this many **auto** samples per (template id, spawn GUID); extra autos drop the oldest by `t`.
local MAX_AUTO_SAMPLES_PER_GUID = 64

local function stripPreviousManualSamples(entries)
  if not entries or type(entries) ~= "table" then
    return
  end
  local kept = {}
  for i = 1, table.getn(entries) do
    local e = entries[i]
    if type(e) == "table" and e.source ~= "manual" then
      table.insert(kept, e)
    end
  end
  for i = table.getn(entries), 1, -1 do
    table.remove(entries, i)
  end
  for i = 1, table.getn(kept) do
    table.insert(entries, kept[i])
  end
end

--- Return true if one oldest `source == "auto"` row was removed to make room.
local function tryDropOldestAutoSample(entries)
  if not entries or type(entries) ~= "table" then
    return false
  end
  local bestI, bestT
  for i = 1, table.getn(entries) do
    local e = entries[i]
    if type(e) == "table" and e.source == "auto" and type(e.t) == "number" then
      if not bestT or e.t < bestT then
        bestT = e.t
        bestI = i
      end
    end
  end
  if not bestI then
    return false
  end
  table.remove(entries, bestI)
  return true
end

local function ensureAutoSettings()
  local db = NPCTrackerObservationDB
  if not db.autorecord then
    db.autorecord = {
      enabled = true,
      mouseover = true,
    }
  end
  if db.autorecord.enabled == nil then
    db.autorecord.enabled = true
  end
  if db.autorecord.mouseover == nil then
    db.autorecord.mouseover = true
  end
end

local function continentNameFromIndex(ci)
  if not ci or ci <= 0 then
    return nil
  end
  local c = { GetMapContinents() }
  return c[ci]
end

local function playerMapPercent()
  local px, py = GetPlayerMapPosition("player")
  if not px or not py or (px == 0 and py == 0) then
    return nil, nil
  end
  return px * 100, py * 100
end

--- Continent from registry (real zone name), else from map, else "Unknown".
--- Zone bucket: "Westfall" or "Westfall / Jangolode Mine" when minimap subzone differs.
local function resolveZoneContinent()
  local rz = GetRealZoneText()
  local mz = GetMinimapZoneText()
  if not rz or rz == "" then
    rz = "?"
  end
  local effectiveZone = rz
  if mz and mz ~= "" and mz ~= rz then
    effectiveZone = rz .. " / " .. mz
  end
  local cont = TWOW_ContinentForZone(rz)
  if not cont then
    local ci = GetCurrentMapContinent()
    if ci and ci > 0 then
      cont = continentNameFromIndex(ci)
    end
  end
  if not cont then
    cont = "Unknown"
  end
  return cont, effectiveZone, (mz and mz ~= "" and mz ~= rz) and mz or nil
end

local function buildEntry(unit, sourceTag, subzoneHint)
  local x, y = playerMapPercent()
  if not x then
    return nil
  end
  local fx = NPCTracker_RoundCoord2(x)
  local fy = NPCTracker_RoundCoord2(y)
  if not NPCTracker_IsValidMapCoord(fx, fy) then
    return nil
  end
  local lvl = UnitLevel(unit)
  local react = UnitReaction(unit, "player")
  local e = {
    x = fx,
    y = fy,
    level = lvl,
    reaction = react,
    t = NPCTracker_RoundCoord2(GetTime()),
    source = sourceTag or "auto",
  }
  if subzoneHint then
    e.subzone = subzoneHint
  end
  local did = NPCTracker_TryCreatureDisplayId(unit)
  if did then
    e.displayId = did
  end
  if UnitCreatureType then
    local ct = UnitCreatureType(unit)
    if type(ct) == "number" and ct >= 0 then
      e.creatureType = ct
    end
  end
  if UnitClassification then
    local cl = UnitClassification(unit)
    if cl and cl ~= "" then
      e.classification = cl
    end
  end
  local guid = NPCTracker_UnitGuid(unit)
  if guid then
    e.guid = guid
  end
  return e
end

function NPCTracker_TryRecordUnit(unit, force, sourceTag)
  if not unit or not UnitExists(unit) then
    return false, "no unit"
  end
  if UnitIsPlayer(unit) then
    return false, "player"
  end
  local name = NPCTracker_NormalizeNPCName(UnitName(unit))
  if not name or name == "" or name == "Unknown" then
    return false, "no name"
  end

  local cont, zone, subHint = resolveZoneContinent()
  if not zone or zone == "" then
    return false, "no zone"
  end

  local entry = buildEntry(unit, sourceTag, subHint)
  if not entry then
    return false, "no position"
  end
  entry.continent = cont
  entry.zone = zone

  local guid = entry.guid
  local gkey = guid and NPCTracker_NormalizeGuidKey(guid) or nil
  local entryId = guid and NPCTracker_CreatureEntryFromGuid(guid) or nil
  local useByEntry = entryId and entryId > 0 and gkey and NPCTracker_IsCreatureNpcGuid(guid)

  if not useByEntry then
    if force then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ffccNPCTracker|r requires a SuperWoW creature GUID (0xF130…). Target or mouseover a valid NPC."
      )
    end
    return false, "no_creature_guid"
  end

  local entries = ensureObsByEntry(entryId, gkey, name)
  if force and (sourceTag == "manual" or sourceTag == "rec") then
    stripPreviousManualSamples(entries)
  end
  while table.getn(entries) >= MAX_AUTO_SAMPLES_PER_GUID do
    if not tryDropOldestAutoSample(entries) then
      return false, "auto_cap"
    end
  end
  entry.guid = nil
  table.insert(entries, entry)

  if NPCTracker_Script_OnUnitRecorded then
    NPCTracker_Script_OnUnitRecorded(unit)
  end

  if NPCTracker_Map and NPCTracker_Map.RefreshPins then
    NPCTracker_Map.RefreshPins(true)
  end

  local xr = math.floor(entry.x + 0.5)
  local yr = math.floor(entry.y + 0.5)
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff33ffccNPCTracker|r Updated entry for: "
      .. name
      .. ", location "
      .. xr
      .. ","
      .. yr
      .. " in zone "
      .. zone
      .. (cont == "Unknown" and " |cffffcc00(continent Unknown)|r" or "")
      .. " |cffffcc00(npc "
      .. entryId
      .. ")|r"
  )
  return true
end

function NPCTracker_ManualRecord()
  if UnitExists("target") then
    return NPCTracker_TryRecordUnit("target", true, "manual")
  end
  if UnitExists("mouseover") then
    return NPCTracker_TryRecordUnit("mouseover", true, "manual")
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r: no target or mouseover to record.")
  return false
end

local function autoRecordUnit(unit)
  ensureAutoSettings()
  if not NPCTrackerObservationDB.autorecord.enabled then
    return
  end
  NPCTracker_TryRecordUnit(unit, false, "auto")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

frame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "NPCTracker" then
    ensureAutoSettings()
    return
  end
  ensureAutoSettings()
  if not NPCTrackerObservationDB.autorecord.enabled then
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    if UnitExists("target") then
      autoRecordUnit("target")
    end
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    if NPCTrackerObservationDB.autorecord.mouseover and UnitExists("mouseover") then
      autoRecordUnit("mouseover")
    end
  end
end)

function NPCTracker_AutoRecordSlash(msg)
  ensureAutoSettings()
  msg = string.lower(msg or "")
  local rest = string.gsub(msg, "^autorecord%s*", "")
  if rest == "on" or rest == "1" or rest == "true" then
    NPCTrackerObservationDB.autorecord.enabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r autorecord: |cff00ff00ON|r")
  elseif rest == "off" or rest == "0" or rest == "false" then
    NPCTrackerObservationDB.autorecord.enabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r autorecord: |cffff5555OFF|r")
  elseif rest == "mouseover on" or rest == "mouseover 1" then
    NPCTrackerObservationDB.autorecord.mouseover = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r mouseover autorecord: ON")
  elseif rest == "mouseover off" or rest == "mouseover 0" then
    NPCTrackerObservationDB.autorecord.mouseover = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r mouseover autorecord: OFF")
  else
    local on = NPCTrackerObservationDB.autorecord.enabled
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff33ffccNPCTracker|r autorecord: "
        .. (on and "|cff00ff00ON|r" or "|cffff5555OFF|r")
        .. ", mouseover "
        .. (NPCTrackerObservationDB.autorecord.mouseover and "on" or "off")
    )
  end
end

--- Slash commands: assign SLASH_* and SlashCmdList together (1.12 binds /npct via SLASH_* globals).
--- Doing this in the last-loaded file avoids "unknown command" if an earlier file errored before SLASH_* ran.
local function NPCTracker_SlashHandler(msg)
  local m = string.lower(msg or "")
  if m == "record" or m == "rec" then
    NPCTracker_ManualRecord()
    return
  end
  if string.find(m, "^autorecord") then
    NPCTracker_AutoRecordSlash(m)
    return
  end
  if NPCTracker_Map and NPCTracker_Map.HandleSlashMsg then
    NPCTracker_Map.HandleSlashMsg(msg)
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccNPCTracker|r: map module failed to load — check for Lua errors.")
  end
end

SLASH_NPCTRACKER1 = "/npct"
SLASH_NPCTRACKER2 = "/npctracker"
SlashCmdList["NPCTRACKER"] = NPCTracker_SlashHandler
