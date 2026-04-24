# NPCTracker (WoW 1.12 + SuperWoW)

Records **where you were on the world map** when you target/mouseover NPCs (position = **player** `GetPlayerMapPosition`), with **auto** and **manual** (`/npct record`) capture. Needs **SuperWoW** (creature `0xF130…` GUIDs). Merges **cast spell** and **aura** spell ids per **npc template id** into a second table.

**Install:** put the add-on folder here (path may vary with your client folder name):

`World of Warcraft\Interface\AddOns\NPCTracker\`  
(Repository folder `addon\NPCTracker\` with `NPCTracker.toc` inside = the add-on root.)

**Saved output (all SavedVariables in one file):**  
`World of Warcraft\WTF\Account\<ACCOUNT>\SavedVariables\NPCTracker.lua`

**In-game (main):**  
`/npct` — map panel and pins.  
`/npct record` or `/npct rec` — manual sample (target, else mouseover).  
`/npctracker` — same as `/npct`.  
Other: `/npct help`, `/npct pins`, `/npct autorecord`, `/npct prune`. **Field list, GUID → entry id, caps:** **NPCTracker-Data.md**.

---

### Example (shape of `NPCTracker.lua` inside SavedVariables)

```lua
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
            displayId = 1965,
            classification = "normal",
            creatureType = 7,
          },
        },
      },
    },
  },
  autorecord = { enabled = true, mouseover = true },
}

NPCTrackerMapSettings = { }  -- zone/npc panel toggles, panel position; see NPCTracker-Data.md

NPCTrackerScriptDB = {
  byEntry = {
    [8674] = {
      spells = { 2457 },
      auras = {},
    },
  },
}
```

(See **NPCTrackerOutput.lua** in this repo for the same example as a stand-alone fragment; it is not loaded by the add-on.)
