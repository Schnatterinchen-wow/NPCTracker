--[[
  Turtle WoW dungeons (from addon/twow-dungeons.txt).
  Columns: release, level range, dungeon name, associated zone, modified bosses, modified quests.

  Used to resolve continent when GetRealZoneText() is the instance name (not an overworld zone in zones_registry).
  Continent comes from TWOW_ContinentForZone(associatedZone) or a small fallback for hub names missing from twow-zones.
]]

-- [1]=release [2]=level [3]=dungeon name [4]=associated zone [5]=bosses [6]=quests
local DUNGEON_ROWS = {
  { "Vanilla", "13-18", "Ragefire Chasm", "Orgrimmar", "None", "None" },
  { "Patch 1.18.1", "13-20", "Frostmane Hollow", "Dun Morogh", "4 bosses", "5 quests" },
  { "Vanilla", "17-24", "The Deadmines", "Westfall", "Jared Voss, Masterpiece Harvester", "4 new quests" },
  { "Vanilla", "17-24", "Wailing Caverns", "The Barrens", "Zandara Windhoof, Vangros", "5 new quests" },
  { "Vanilla", "22-30", "Stockades", "Stormwind City", "None", "1 new quest" },
  { "Vanilla", "22-31", "Blackfathom Deeps", "Ashenvale", "Velthelaxx the Defiler", "1 new quest" },
  { "Patch 1.18.0", "25-34", "Dragonmaw Retreat", "Wetlands", "13 bosses", "10 quests" },
  { "Patch 1.18.1", "26-30", "Windhorn Canyon", "Thousand Needles", "7 bosses", "? quests" },
  { "Vanilla", "27-36", "Scarlet Monastery Graveyard", "Tirisfal Glades", "Duke Dreadmoore", "1 new quest" },
  { "Vanilla", "29-38", "Gnomeregan", "Dun Morogh", "None", "4 new quests" },
  { "Patch 1.16.0", "32-38", "Crescent Grove", "Ashenvale", "7 bosses", "5 quests" },
  { "Vanilla", "32-39", "Scarlet Monastery Library", "Tirisfal Glades", "Brother Wystan", "None" },
  { "Vanilla", "32-42", "Razorfen Kraul", "The Barrens", "Rotthorn", "1 new quest" },
  { "Patch 1.18.0", "35-41", "Stormwrought Ruins", "Balor", "12 bosses", "14 quests" },
  { "Vanilla", "40-45", "Scarlet Monastery Armory", "Tirisfal Glades", "Armory Quartermaster Daghelm", "2 new quests" },
  { "Vanilla", "40-45", "Scarlet Monastery Cathedral", "Tirisfal Glades", "None", "2 new quests" },
  { "Vanilla", "40-51", "Uldaman", "Badlands", "None", "2 new quests" },
  { "Vanilla", "42-44", "Razorfen Downs", "The Barrens", "Death Prophet Rakameg", "1 new quest" },
  { "Patch 1.17.0", "43-49", "Gilneas City", "Gilneas", "8 bosses", "14 quests" },
  { "Vanilla", "45-55", "Maraudon", "Desolace", "None", "3 new quests" },
  { "Vanilla", "46-56", "Zul'Farrak", "Tanaris", "Zel'jeb the Ancient, Champion Razjal the Quick", "2 new quests" },
  { "Vanilla", "50-60", "Sunken Temple", "Swamp of Sorrows", "None", "4 new quests" },
  { "Vanilla", "52-60", "Blackrock Depths", "Blackrock Mountain", "None", "7 new quests" },
  { "Patch 1.16.1", "52-60", "Hateforge Quarry", "Burning Steppes", "5 bosses", "10 quests" },
  { "Vanilla", "55-60", "Dire Maul West", "Feralas", "None", "5 new quests" },
  { "Vanilla", "55-60", "Dire Maul East", "Feralas", "None", "2 new quests" },
  { "Vanilla", "55-60", "Lower Blackrock Spire", "Blackrock Mountain", "None", "5 new quests" },
  { "Vanilla", "58-60", "Dire Maul North", "Feralas", "None", "None" },
  { "Vanilla", "58-60", "Scholomance", "Western Plaguelands", "None", "2 new quests" },
  { "Vanilla", "58-60", "Stratholme", "Eastern Plaguelands", "None", "3 new quests" },
  { "Vanilla", "55-60", "Upper Blackrock Spire", "Blackrock Mountain", "None", "None" },
  { "Patch 1.16.0", "60", "Stormwind Vault", "Stormwind City", "6 bosses", "6 quests" },
  { "Patch 1.16.0", "60", "Karazhan Crypt", "Deadwind Pass", "7 bosses", "3 quests" },
}

--- [dungeonName] = { release, level, name, associatedZone, bossesMod, questsMod }
TWOW_DUNGEON_META = {}

--- Associated zone name (column 4) -> continent when that name is missing from twow-zones.txt.
--- Hubs listed in twow-zones.txt / zones_registry.lua do not need entries here (e.g. Orgrimmar → Kalimdor).
local ASSOCIATED_ZONE_CONTINENT_FALLBACK = {
  ["Blackrock Mountain"] = "Eastern Kingdoms",
}

--- Client GetRealZoneText() -> registry dungeon name (when client string differs).
local DUNGEON_ZONE_TEXT_ALIASES = {
  ["The Stockade"] = "Stockades",
  ["Stockade"] = "Stockades",
  ["The Deadmines"] = "The Deadmines",
}

local function build()
  for _, row in ipairs(DUNGEON_ROWS) do
    local name = row[3]
    TWOW_DUNGEON_META[name] = {
      release = row[1],
      level = row[2],
      name = name,
      associatedZone = row[4],
      bossesMod = row[5],
      questsMod = row[6],
    }
  end
end

build()

function TWOW_ContinentForAssociatedZone(associatedZoneName)
  if not associatedZoneName or associatedZoneName == "" then
    return nil
  end
  local c = TWOW_ContinentForZone(associatedZoneName)
  if c then
    return c
  end
  return ASSOCIATED_ZONE_CONTINENT_FALLBACK[associatedZoneName]
end

--- Returns TWOW_DUNGEON_META entry if `zoneText` matches a known dungeon (instance) name.
function TWOW_GetDungeonMetaForZoneText(zoneText)
  if not zoneText or zoneText == "" or zoneText == "?" then
    return nil
  end
  if TWOW_DUNGEON_META[zoneText] then
    return TWOW_DUNGEON_META[zoneText]
  end
  local ali = DUNGEON_ZONE_TEXT_ALIASES[zoneText]
  if ali and TWOW_DUNGEON_META[ali] then
    return TWOW_DUNGEON_META[ali]
  end
  local stripped = string.gsub(zoneText, "^[Tt]he%s+", "")
  if stripped ~= zoneText then
    if TWOW_DUNGEON_META[stripped] then
      return TWOW_DUNGEON_META[stripped]
    end
    if TWOW_DUNGEON_META["The " .. stripped] then
      return TWOW_DUNGEON_META["The " .. stripped]
    end
  end
  return nil
end
