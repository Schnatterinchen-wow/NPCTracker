--[[
  Observations → NPCTrackerObservationDB (SuperWoW only)

  Storage: npc entry id → { npcName, entries[guidKey] = { sample, … } }.
  Each sample carries continent/zone; the spawn GUID is the table key, not a field on the row.
  t = GetTime() (session time, seconds) rounded; not world z/elevation.
  Auto: spam guard — remembers the last N distinct spawn GUIDs auto-recorded; re-hovering one of those
  skips a new auto row until it ages out of the ring. Still capped per GUID (MAX_AUTO_SAMPLES_PER_GUID).
  Manual (/npct record): always writes; does not use the ring.
  Manual detail: each /npct record removes prior manual row(s) for that GUID, then stores one new manual; auto rows stay.
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
  eb.npcName = npcName
  if not eb.entries[gkey] then
    eb.entries[gkey] = {}
  end
  return eb.entries[gkey]
end

--- At most this many **auto** samples per (template id, spawn GUID); extra autos drop the oldest by `t`.
local MAX_AUTO_SAMPLES_PER_GUID = 64

--- Auto only: skip new row if spawn GUID is still in this many most recently auto-recorded distinct GUIDs.
local AUTO_GUID_RING_MAX = 5

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
    db.autorecord = { enabled = true, mouseover = true }
  end
  if not db.autoRecordLastFiveGuids then
    db.autoRecordLastFiveGuids = {}
  end
end

local function isGuidInAutoRing(gkey)
  if not gkey or gkey == "" then
    return false
  end
  ensureAutoSettings()
  local list = NPCTrackerObservationDB.autoRecordLastFiveGuids
  for i = 1, table.getn(list) do
    if list[i] == gkey then
      return true
    end
  end
  return false
end

--- MRU at end; evict from front when over AUTO_GUID_RING_MAX. Used only after a successful **auto** record.
local function touchGuidAutoRing(gkey)
  if not gkey or gkey == "" then
    return
  end
  ensureAutoSettings()
  local list = NPCTrackerObservationDB.autoRecordLastFiveGuids
  for i = table.getn(list), 1, -1 do
    if list[i] == gkey then
      table.remove(list, i)
    end
  end
  table.insert(list, gkey)
  while table.getn(list) > AUTO_GUID_RING_MAX do
    table.remove(list, 1)
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

--- Continent: overworld zone (zones_registry), else dungeon instance -> associated zone (dungeons_registry), else map, else Unknown.
--- Zone bucket: "Westfall" or "Westfall / Jangolode Mine" when minimap subzone differs.
--- Returns optional dungeon meta when `rz` matches twow-dungeons (for parentZone + labels).
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
  local dunMeta = TWOW_GetDungeonMetaForZoneText(rz)
  local cont = TWOW_ContinentForZone(rz)
  if not cont and dunMeta then
    cont = TWOW_ContinentForAssociatedZone(dunMeta.associatedZone)
  end
  if not cont then
    local ci = GetCurrentMapContinent()
    if ci and ci > 0 then
      cont = continentNameFromIndex(ci)
    end
  end
  if not cont then
    cont = "Unknown"
  end
  return cont, effectiveZone, (mz and mz ~= "" and mz ~= rz) and mz or nil, dunMeta
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
  if UnitClassification then
    local cl = UnitClassification(unit)
    if type(cl) == "string" and cl ~= "" then
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

  local cont, zone, subHint, dunMeta = resolveZoneContinent()
  if not zone or zone == "" then
    return false, "no zone"
  end

  local entry = buildEntry(unit, sourceTag, subHint)
  if not entry then
    return false, "no position"
  end
  entry.continent = cont
  entry.zone = zone
  if dunMeta then
    entry.dungeon = dunMeta.name
    entry.parentZone = dunMeta.associatedZone
  end

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

  -- Auto: do not spam rows when mouseover/target fires repeatedly for the same spawn GUID.
  if not force and isGuidInAutoRing(gkey) then
    return false, "guid_ring"
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

  if not force then
    touchGuidAutoRing(gkey)
  end

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
      .. (entry.dungeon and (" |cffaad4ff(dungeon: " .. entry.dungeon .. ", ref: " .. entry.parentZone .. ")|r") or "")
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
