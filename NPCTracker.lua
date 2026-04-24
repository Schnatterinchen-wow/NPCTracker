--[[
  NPCTracker — SuperWoW: locations by npc template id × spawn GUID; spells/auras per template in NPCTrackerScriptDB.
]]

NPCTrackerObservationDB = NPCTrackerObservationDB or {
  -- [npcEntryId] = { npcName, entries = { [guidKey] = { { source, continent, zone, ... }, ... } } }
  observationsByEntry = {},
}

-- Declared in .toc as SavedVariables; init here so it exists before NPCTracker_Map.lua loads.
-- NPCTracker_Map.lua calls MAP.EnsureMapSettings() when the UI loads.
NPCTrackerMapSettings = NPCTrackerMapSettings or {
  zoneEnabled = {},
  npcEnabled = {},
  panelPoint = nil,
}

-- Spells/auras keyed by creature template id only (no per-spawn GUID in this table).
NPCTrackerScriptDB = NPCTrackerScriptDB or {
  -- [npcEntry] = { spells = { id, ... max 20 }, auras = { id, ... max 8 } }
  byEntry = {},
}

--- Trim and collapse internal whitespace (UTF-8 safe enough for WoW names).
function NPCTracker_NormalizeNPCName(name)
  if not name or name == "" then
    return nil
  end
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  name = string.gsub(name, "%s+", " ")
  if name == "" then
    return nil
  end
  return name
end

--- Unit GUID when the client exposes it (e.g. SuperWoW: UnitExists also returns GUID).
--- Stock 1.12 returns only existence; second result is nil.
function NPCTracker_UnitGuid(unit)
  if not unit then
    return nil
  end
  local exists, guid = UnitExists(unit)
  if not exists or not guid or guid == "" then
    return nil
  end
  return guid
end

--- Normalize GUID for SavedVariables keys (SuperWoW hex strings).
function NPCTracker_NormalizeGuidKey(guid)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  local g = string.gsub(guid, "%s+", "")
  g = string.upper(g)
  g = string.gsub(g, "^0X", "0x")
  return g
end

--- True for creature NPC GUIDs (0xF130…); excludes players/pets (0xF140…).
function NPCTracker_IsCreatureNpcGuid(guid)
  local g = NPCTracker_NormalizeGuidKey(guid)
  if not g or string.len(g) < 6 then
    return false
  end
  return string.sub(g, 1, 6) == "0xF130"
end

--- Creature template (npc) id from 16-digit hex GUID (Turtle / 1.12 packed layout).
function NPCTracker_CreatureEntryFromGuid(guid)
  local g = NPCTracker_NormalizeGuidKey(guid)
  if not g then
    return nil
  end
  g = string.gsub(g, "^0x", "")
  if string.len(g) ~= 16 then
    return nil
  end
  if string.sub(g, 1, 4) ~= "F130" then
    return nil
  end
  local hi = tonumber(string.sub(g, 1, 8), 16)
  local lo = tonumber(string.sub(g, 9, 16), 16)
  if not hi or not lo then
    return nil
  end
  local lowByte = hi - math.floor(hi / 256) * 256
  local highByte = math.floor(lo / 16777216)
  return lowByte * 256 + highByte
end

--- Map coord 0–100 rounded to 2 decimals (nearest; reduces float noise in SavedVariables).
function NPCTracker_RoundCoord2(n)
  if n == nil then
    return nil
  end
  return math.floor(n * 100 + 0.5) / 100
end

--- @return number|nil  Model display id if `_G[GetCreatureDisplay|GetUnitDisplay|GetCreatureDisplayId]` exists (SuperWoW/Turtle), else nil.
function NPCTracker_TryCreatureDisplayId(unit)
  if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
    return nil
  end
  local tryNames = { "GetCreatureDisplay", "GetUnitDisplay", "GetCreatureDisplayId" }
  for i = 1, 3 do
    local f = _G and _G[tryNames[i]]
    if type(f) == "function" then
      local ok, id = pcall(f, unit)
      if ok and type(id) == "number" and id > 0 then
        return math.floor(id)
      end
    end
  end
  return nil
end

--- Map % 0–100; reject nil, NaN, (0,0), and out-of-range.
function NPCTracker_IsValidMapCoord(x, y)
  if x == nil or y == nil then
    return false
  end
  if x ~= x or y ~= y then
    return false
  end -- NaN
  if x == 0 and y == 0 then
    return false
  end
  if x < 0 or x > 100 or y < 0 or y > 100 then
    return false
  end
  return true
end

--- True when world-map zone label and stored bucket refer to the same area or
--- parent/child (e.g. "Westfall" vs "Westfall / Jangolode Mine").
function NPCTracker_ZoneBucketMatches(mapZone, storedZone)
  if not mapZone or not storedZone then
    return false
  end
  if mapZone == storedZone then
    return true
  end
  local p = mapZone .. " / "
  if string.sub(storedZone, 1, string.len(p)) == p then
    return true
  end
  p = storedZone .. " / "
  if string.sub(mapZone, 1, string.len(p)) == p then
    return true
  end
  return false
end

--- Drop observation rows not taken in this map zone (per-entry continent/zone when present).
function NPCTracker_FilterObservationForMapZone(block, continent, mapZone)
  if not block or not block.entries then
    return block
  end
  local out = { entries = {} }
  for _, e in ipairs(block.entries) do
    if type(e) == "table" then
      local ok = true
      if e.continent and e.continent ~= continent then
        ok = false
      end
      if ok and e.zone and not NPCTracker_ZoneBucketMatches(mapZone, e.zone) then
        ok = false
      end
      if ok then
        table.insert(out.entries, e)
      end
    end
  end
  if table.getn(out.entries) == 0 then
    return nil
  end
  return out
end

local function mergeObservationBlocks(a, b)
  if not a or not a.entries then
    return b
  end
  if not b or not b.entries then
    return a
  end
  local out = { entries = {} }
  for _, e in ipairs(a.entries) do
    table.insert(out.entries, e)
  end
  for _, e in ipairs(b.entries) do
    table.insert(out.entries, e)
  end
  return out
end

--- Merge observations (by npc entry × instance GUID buckets) for one NPC name + map zone.
local function mergeObservationsByEntryForName(continent, zone, npcName, into)
  local byEntry = NPCTrackerObservationDB.observationsByEntry
  if not byEntry or type(byEntry) ~= "table" then
    return into
  end
  for _, entryBlock in pairs(byEntry) do
    if type(entryBlock) == "table" and entryBlock.npcName == npcName and type(entryBlock.entries) == "table" then
      local samples = {}
      for _, arr in pairs(entryBlock.entries) do
        if type(arr) == "table" then
          for i = 1, table.getn(arr) do
            local e = arr[i]
            if type(e) == "table" and e.zone and NPCTracker_ZoneBucketMatches(zone, e.zone) then
              local ec = e.continent
              if not ec or ec == "" then
                ec = continent
              end
              if ec == continent then
                table.insert(samples, e)
              end
            end
          end
        end
      end
      if table.getn(samples) > 0 then
        into = mergeObservationBlocks(into, { entries = samples })
      end
    end
  end
  return into
end

--- @param continent string Kalimdor | Eastern Kingdoms | Unknown
--- @param zone string e.g. "Westfall" (must match twow-zones.txt / registry where known)
--- @param npcName string localized UnitName
--- Returns `{ observation = block | nil }` filtered to the current map zone.
function NPCTracker_GetNPCBySource(continent, zone, npcName)
  local o = mergeObservationsByEntryForName(continent, zone, npcName, nil)
  o = NPCTracker_FilterObservationForMapZone(o, continent, zone)
  return {
    observation = o,
  }
end

--- All NPC names observed for this map zone (from observationsByEntry).
function NPCTracker_ListNPCNamesForZone(continent, zone)
  local seen = {}
  local byEntry = NPCTrackerObservationDB.observationsByEntry
  if byEntry and type(byEntry) == "table" then
    for _, entryBlock in pairs(byEntry) do
      if type(entryBlock) == "table" and entryBlock.npcName and type(entryBlock.entries) == "table" then
        local hit = false
        for _, arr in pairs(entryBlock.entries) do
          if type(arr) == "table" then
            for i = 1, table.getn(arr) do
              local e = arr[i]
              if
                type(e) == "table"
                and (e.continent or continent) == continent
                and e.zone
                and NPCTracker_ZoneBucketMatches(zone, e.zone)
              then
                hit = true
                break
              end
            end
          end
          if hit then
            break
          end
        end
        if hit then
          seen[entryBlock.npcName] = true
        end
      end
    end
  end
  local list = {}
  for n, _ in pairs(seen) do
    table.insert(list, n)
  end
  table.sort(list)
  return list
end

--- Remove invalid coordinate entries from SavedVariables (called from /npct prune).
function NPCTracker_PruneInvalidObservations()
  local db = NPCTrackerObservationDB
  if not db then
    return 0
  end
  local removed = 0
  local function pruneEntries(entries)
    local kept = {}
    for _, e in ipairs(entries) do
      if type(e) == "table" and NPCTracker_IsValidMapCoord(e.x, e.y) then
        e.x = NPCTracker_RoundCoord2(e.x)
        e.y = NPCTracker_RoundCoord2(e.y)
        if e.t and type(e.t) == "number" then
          e.t = NPCTracker_RoundCoord2(e.t)
        end
        table.insert(kept, e)
      else
        removed = removed + 1
      end
    end
    return kept
  end
  local byEntry = db.observationsByEntry
  if type(byEntry) == "table" then
    for _, entryBlock in pairs(byEntry) do
      if type(entryBlock) == "table" and type(entryBlock.entries) == "table" then
        for gkey, arr in pairs(entryBlock.entries) do
          if type(arr) == "table" then
            entryBlock.entries[gkey] = pruneEntries(arr)
            if table.getn(entryBlock.entries[gkey]) == 0 then
              entryBlock.entries[gkey] = nil
            end
          end
        end
      end
    end
  end
  return removed
end
