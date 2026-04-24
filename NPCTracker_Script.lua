--[[
  NPCTrackerScriptDB — spell casts + auras per npc template id (entry), no per-spawn GUID storage.

  Locations stay in NPCTrackerObservationDB.observationsByEntry; this table is script metadata only.

  Spells: up to 5 unique spell ids from UNIT_CASTEVENT (SuperWoW), merged across all seen spawns of that entry.
  Auras: up to 3 unique aura spell ids from UnitBuff/UnitDebuff when a unit is recorded.
]]

local MAX_SPELLS = 5
local MAX_AURAS = 3

local function listContains(t, id)
  for i = 1, table.getn(t) do
    if t[i] == id then
      return true
    end
  end
  return false
end

local function appendUniqueCap(dst, id, maxn)
  if not id or type(id) ~= "number" or id < 1 then
    return
  end
  if listContains(dst, id) then
    return
  end
  if table.getn(dst) >= maxn then
    return
  end
  table.insert(dst, id)
end

local function ensureScriptDb()
  if type(NPCTrackerScriptDB) ~= "table" then
    NPCTrackerScriptDB = { byEntry = {} }
  end
  if type(NPCTrackerScriptDB.byEntry) ~= "table" then
    NPCTrackerScriptDB.byEntry = {}
  end
end

local function ensureEntryBlock(entry)
  ensureScriptDb()
  if not NPCTrackerScriptDB.byEntry[entry] then
    NPCTrackerScriptDB.byEntry[entry] = { spells = {}, auras = {} }
  end
  local block = NPCTrackerScriptDB.byEntry[entry]
  if type(block) ~= "table" then
    block = { spells = {}, auras = {} }
    NPCTrackerScriptDB.byEntry[entry] = block
  end
  if type(block.spells) ~= "table" then
    block.spells = {}
  end
  if type(block.auras) ~= "table" then
    block.auras = {}
  end
  return block
end

local function addSpell(entry, spellId)
  if not spellId or type(spellId) ~= "number" or spellId < 1 then
    return
  end
  local block = ensureEntryBlock(entry)
  appendUniqueCap(block.spells, spellId, MAX_SPELLS)
end

local function addAura(entry, spellId)
  if not spellId or type(spellId) ~= "number" or spellId < 1 then
    return
  end
  local block = ensureEntryBlock(entry)
  appendUniqueCap(block.auras, spellId, MAX_AURAS)
end

function NPCTracker_Script_AddSpellForCasterGuid(casterGuid, spellId)
  if not SUPERWOW_VERSION or not casterGuid then
    return
  end
  if not NPCTracker_IsCreatureNpcGuid(casterGuid) then
    return
  end
  local entry = NPCTracker_CreatureEntryFromGuid(casterGuid)
  if not entry then
    return
  end
  addSpell(entry, spellId)
end

--- SuperWoW adds spell id as extra returns on UnitBuff/UnitDebuff; take last numeric in high slots.
local function auraSpellIdFromIndex(unit, index, useDebuff)
  local f = useDebuff and UnitDebuff or UnitBuff
  local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = f(unit, index)
  if not a1 then
    return nil
  end
  local vals = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 }
  for i = 10, 4, -1 do
    local v = vals[i]
    if v and type(v) == "number" and v >= 1 then
      return v
    end
  end
  return nil
end

function NPCTracker_Script_CaptureAurasForUnit(unit)
  if not unit or not UnitExists(unit) then
    return
  end
  if not SUPERWOW_VERSION then
    return
  end
  if UnitIsPlayer(unit) then
    return
  end
  local guid = NPCTracker_UnitGuid(unit)
  if not guid or not NPCTracker_IsCreatureNpcGuid(guid) then
    return
  end
  local entry = NPCTracker_CreatureEntryFromGuid(guid)
  if not entry then
    return
  end
  local block = ensureEntryBlock(entry)
  for i = 1, 32 do
    local sid = auraSpellIdFromIndex(unit, i, false)
    if not sid then
      break
    end
    addAura(entry, sid)
    if table.getn(block.auras) >= MAX_AURAS then
      return
    end
  end
  for i = 1, 32 do
    local sid = auraSpellIdFromIndex(unit, i, true)
    if not sid then
      break
    end
    addAura(entry, sid)
    if table.getn(block.auras) >= MAX_AURAS then
      return
    end
  end
end

function NPCTracker_Script_OnUnitRecorded(unit)
  NPCTracker_Script_CaptureAurasForUnit(unit)
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
if SUPERWOW_VERSION then
  ef:RegisterEvent("UNIT_CASTEVENT")
end

ef:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "NPCTracker" then
    ensureScriptDb()
  elseif event == "UNIT_CASTEVENT" and SUPERWOW_VERSION then
    local caster = arg1
    local spellId = arg4
    NPCTracker_Script_AddSpellForCasterGuid(caster, spellId)
  end
end)
