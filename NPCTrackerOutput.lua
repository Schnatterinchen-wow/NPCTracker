--[[
  Example fragment only — not loaded by NPCTracker.toc.
  SuperWoW: locations under observationsByEntry; optional script data in NPCTrackerScriptDB.
]]

NPCTrackerObservationDB = {
  observationsByEntry = {
    [8674] = {
      npcName = "Example NPC",
      entries = {
        ["0xF1300021DE01375A"] = {
          {
            source = "auto",
            continent = "Eastern Kingdoms",
            zone = "Stormwind City / Trade District",
            subzone = "Trade District",
            t = 148337.95,
            x = 60.8,
            y = 71.44,
            reaction = 7,
            level = 50,
            classification = "normal",
          },
        },
      },
    },
  },
  autorecord = { enabled = true, mouseover = true },
  autoRecordLastFiveGuids = {},
}

NPCTrackerScriptDB = {
  byEntry = {
    [8674] = {
      spells = { 2457 },
      auras = {},
    },
  },
}
