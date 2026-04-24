--[[
  Canonical Turtle WoW zone list (from addon/twow-zones.txt).
  Columns: Release, Level, Zone, New/revamped areas, Faction, Continent

  Use this as the first split: Continent -> Zone name (must match GetRealZoneText()
  where possible; add aliases in npc_tracker.lua if the client string differs).
]]

local ROWS = {
  { "Patch 1.15.0", "N/A", "Alah'Thalas", "Completely new zone (Silvermoon Remnant/High elf faction capital)", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "N/A", "Stormwind City", "Stormwind Harbor, Little Silvermoon, Davenburg", "Alliance", "Eastern Kingdoms" },
  { "Patch 1.17.1", "1-10", "Blackstone Island", "Completely new zone (Durotar Labor Union/Goblin starting zone)", "Horde", "Kalimdor" },
  { "Vanilla", "1-10", "Dun Morogh", "Frostmane Hollow, Gnomeregan Reclamation Facility (lvl 10-38, Gnomeregan Exiles faction capital), Ironforge Airfield, Rugford's Mountain Rest", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "1-10", "Durotar", "Sparkwater Port (lvl 1-36, Durotar Labor Union/Goblin faction capital)", "Horde", "Kalimdor" },
  { "Vanilla", "1-10", "Elwynn Forest", "None", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "1-10", "Mulgore", "Redcloud Roost, Suntail Pass", "Horde", "Kalimdor" },
  { "Vanilla", "1-10", "Teldrassil", "Ursan Heights", "Alliance", "Kalimdor" },
  { "Patch 1.17.1", "1-10", "Thalassian Highlands", "Completely new zone (Silvermoon Remnant/High elf starting zone)", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "1-10", "Tirisfal Glades", "Tirisfal uplands (lvl 15-20 Horde; lvl 30 Alliance)", "Horde", "Eastern Kingdoms" },
  { "Vanilla", "10-20", "Darkshore", "None", "Alliance", "Kalimdor" },
  { "Vanilla", "10-20", "Loch Modan", "Farstrider Lodge", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "10-20", "Silverpine Forest", "None", "Horde", "Eastern Kingdoms" },
  { "Vanilla", "10-20", "Westfall", "None", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "10-20", "The Barrens", "Anchor's Edge", "Horde", "Kalimdor" },
  { "Vanilla", "15-25", "Redridge Mountains", "Redwall Keep", "Alliance", "Eastern Kingdoms" },
  { "Vanilla", "15-27", "Stonetalon Mountains", "Amani'alor (lvl 10-12, Revantusk Trolls faction capital), Bramblethorn Pass, Powder Town, Blacksand Oil Fields, Bael Hardul, Venture Camp, Broken Cliff Mine, Earthen Ring", "Neutral", "Kalimdor" },
  { "Vanilla", "18-30", "Ashenvale", "Forest Song, Thalanaar, Talonbranch Glade, Demon Fall Ridge, Warsong Lumber Camp", "Neutral", "Kalimdor" },
  { "Vanilla", "18-30", "Duskwood", "None", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "18-30", "Wetlands", "Dun Agrath, Hawk's Vigil, Green Belt Gnoll Camp, Dragonmaw Gates", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "20-35", "Hillsbrad Foothills", "None", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "25-35", "Thousand Needles", "Ironstone Camp, Sagh's Refuge, Windhorn Canyon", "Neutral", "Kalimdor" },
  { "Patch 1.18.0", "28-34", "Northwind", "Completely new zone", "Alliance", "Eastern Kingdoms" },
  { "Patch 1.18.0", "29-34", "Balor", "Completely new zone", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "30-40", "Alterac Mountains", "None", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "30-40", "Arathi Highlands", "Wildtusk Village, Ruins of Zul'rasaz (lvl 40-43), Farwell Stead, Gallant Square, Livingstone Croft", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "30-40", "Desolace", "None", "Neutral", "Kalimdor" },
  { "Vanilla", "30-45", "Stranglethorn Vale", "None", "Neutral", "Eastern Kingdoms" },
  { "Patch 1.18.0", "33-38", "Grim Reaches", "Completely new zone", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "35-45", "Dustwallow Marsh", "Westhaven Hollow, Blackhorn Village, Deserter's Hideout, Hermit of the East Coast", "Neutral", "Kalimdor" },
  { "Vanilla", "35-45", "Badlands", "Ruins of Corthan, Scalebane Ridge, Crystalline Oasis, Crystalline Pinnacle, Redbrand's Digsite, Angor Digsite, Ruins of Zeth", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "35-45", "Swamp of Sorrows", "Sorrowguard Keep", "Neutral", "Eastern Kingdoms" },
  { "Patch 1.17.0", "39-46", "Gilneas", "Completely new zone", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "40-50", "Feralas", "Ronae'Thalas, Chimaera Roost Vale", "Neutral", "Kalimdor" },
  { "Vanilla", "40-50", "Hinterlands", "Rasaz Trails", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "40-50", "Tanaris", "Sandmoon Village, Slickwick Oil Rig", "Neutral", "Kalimdor" },
  { "Patch 1.16.0", "40-50", "Icepoint Rock", "Completely new zone[1]", "Neutral", "Kalimdor" },
  { "Vanilla", "45-50", "Searing Gorge", "None", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "45-55", "Azshara", "Flaxwhisker Front, Bloodfist Point, Maw of Ursoc, Rethress Sanctum, Ursolan, Timbermaw Hold Gate", "Neutral", "Kalimdor" },
  { "Vanilla", "45-55", "Blasted Lands", "None", "Neutral", "Eastern Kingdoms" },
  { "Patch 1.16.0", "48-53", "Lapidis Isle", "Completely new zone", "Alliance", "Eastern Kingdoms" },
  { "Patch 1.16.0", "48-53", "Gillijim's Isle", "Completely new zone", "Horde", "Eastern Kingdoms" },
  { "Vanilla", "48-55", "Un'Goro Crater", "None", "Neutral", "Kalimdor" },
  { "Vanilla", "48-55", "Felwood", "Shrine of the Betrayer, Talonbranch Glade", "Neutral", "Kalimdor" },
  { "Patch 1.18.1", "50-56", "Moonwhisper Coast", "Completely new zone", "Neutral", "Kalimdor" },
  { "Vanilla", "50-58", "Burning Steppes", "Karfang Hold", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "51-58", "Western Plaguelands", "None", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "53-60", "Eastern Plaguelands", "Forlorn Summit", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "53-60", "Winterspring", "None", "Neutral", "Kalimdor" },
  { "Patch 1.16.4", "54-60", "Tel'Abim", "Completely new zone", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "55-60", "Deadwind Pass", "Master's Cellar, Morgan's Plot", "Neutral", "Eastern Kingdoms" },
  { "Patch 1.16.0", "55-60", "Scarlet Enclave", "Completely new zone[1]", "Neutral", "Eastern Kingdoms" },
  { "Vanilla", "55-60", "Moonglade", "None", "Neutral", "Kalimdor" },
  { "Vanilla", "55-60", "Silithus", "None", "Neutral", "Kalimdor" },
  { "Patch 1.17.0", "58-60", "Hyjal", "Completely new zone", "Neutral", "Kalimdor" },
}

TWOW_CONTINENTS = { "Eastern Kingdoms", "Kalimdor" }

-- [continent][zoneName] = { release, level, subareas, faction }
TWOW_ZONE_META = {}

-- Ordered zone names per continent (same order as source file)
TWOW_ZONES_ORDERED = {
  ["Eastern Kingdoms"] = {},
  ["Kalimdor"] = {},
}

local function build()
  for _, row in ipairs(ROWS) do
    local release, level, zone, subareas, faction, continent = row[1], row[2], row[3], row[4], row[5], row[6]
    if not TWOW_ZONE_META[continent] then
      TWOW_ZONE_META[continent] = {}
    end
    TWOW_ZONE_META[continent][zone] = {
      release = release,
      level = level,
      subareas = subareas,
      faction = faction,
    }
    table.insert(TWOW_ZONES_ORDERED[continent], zone)
  end
end

build()

--[[
  NPCTracker (SuperWoW): NPCTrackerObservationDB.observationsByEntry[templateId] =
  { npcName, entries = { [guidKey] = { samples } } }. See README.
]]

function TWOW_GetZoneMeta(continent, zoneName)
  local c = TWOW_ZONE_META[continent]
  if not c then return nil end
  return c[zoneName]
end

function TWOW_ContinentForZone(zoneName)
  for _, cont in ipairs(TWOW_CONTINENTS) do
    if TWOW_ZONE_META[cont] and TWOW_ZONE_META[cont][zoneName] then
      return cont
    end
  end
  return nil
end
