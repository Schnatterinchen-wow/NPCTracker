# NPCTracker (Turtle WoW)
## Schnatterinchen-wow on Github
In-game **NPC location and script capture** for **Turtle WoW 1.12 with SuperWoW** (creature GUIDs `0xF130…`). Export SavedVariables for **external tools** or the Turtle WoW database when you want to cross-check ids.
Tracked NPC data is in the following folder:
\WoW\WTF\Account\ACCOUNT\SavedVariables\NPCTracker.lua

## Goals

- Record **continent**, **zone bucket** (e.g. `Stormwind City / Trade District`), map **x/y**, level, reaction per sample; store by **npc template id** × **instance GUID** (`observationsByEntry`).
- Auto adds **one** sample per spawn; manual can add more for the same GUID.
- **Spells / auras** per npc template id in `NPCTrackerScriptDB` (no GUID layer; caps 5 / 3 unique ids).
- Zone list aligned with `addon/twow-zones.txt` via `zones_registry.lua`.

## File layout

```
addons/NPCTracker/NPCTracker/
├── NPCTracker.toc          # Load order, SavedVariables
├── NPCTracker.lua          # API, prune
├── NPCTracker_Map.lua      # World map pins + zone NPC list (observations only)
├── NPCTracker_Record.lua   # Auto-record + manual /npct record
├── NPCTracker_Script.lua   # Spells/auras (SuperWoW)
├── zones_registry.lua
└── README.md
```

Optional in-repo (not loaded by the addon TOC): `tools/npct_export.py` for CSV/JSON from SavedVariables, and other helper scripts if you maintain them.

## World map UI (`NPCTracker_Map.lua`)

### Slash commands

| Command | Effect |
|--------|--------|
| `/npct` | Toggles the NPC list / map panel (show or hide). |
| `/npctracker` | Same as `/npct`. |
| `/npct map` | Same as `/npct` — opens or closes the panel. |
| `/npct pins` | Forces a full refresh of world-map pins (no panel toggle). |
| `/npct record` or `/npct rec` | **Manual observation**: saves target (or mouseover if no target). Requires a **SuperWoW creature GUID** (`0xF130…`). |
| `/npct autorecord` | Prints autorecord status (on/off, mouseover on/off). |
| `/npct autorecord on` / `off` | Enables or disables automatic recording on target/mouseover. |
| `/npct autorecord mouseover on` / `mouseover off` | Enables or disables auto-record from mouseover (target still works when mouseover is off). |

You can also type `/npct` with no argument; it behaves like `/npct map`.

### Auto-record (`NPCTracker_Record.lua`)

- **Automatic** samples run on `PLAYER_TARGET_CHANGED` (target) and optionally `UPDATE_MOUSEOVER_UNIT` (mouseover).
- **One** auto sample per **spawn GUID** (same npc template id); a **new** spawn (new GUID) gets another pin. **Manual** `/npct record` can append more samples for the same GUID.
- Units without a usable **SuperWoW creature GUID** are skipped (no silent fallback storage).
- **Defaults** (in `NPCTrackerObservationDB.autorecord`): `enabled = true`, `mouseover = true`.
- Records require a valid **player map position** (not 0,0) and a resolvable **zone** via `GetRealZoneText()` + `TWOW_ContinentForZone`.

- **World map:** **Gold** pins for your observations only (tooltip includes stored **zone** when present). No minimap layer.
- **Per zone:** Checkbox **“Show pins for this zone”** — master on/off for that map (matches the current world map zone).
- **Per NPC:** Checkboxes in the list; uncheck to hide that NPC’s pins only.
- **All on / All off:** Sets every NPC in the current zone list on or off (does not change the zone master).
- **Scroll bar:** Moves through long NPC lists (18 rows visible).
- **Saved:** `NPCTrackerMapSettings` — zone toggles, per-NPC toggles, panel position.

Pins use the **same map zone** as the world map (`GetCurrentMapContinent` / `GetCurrentMapZone` + `GetMapZones`). If your client locale does not match English zone names in `twow-zones.txt` / the registry, the list may be empty until names align.

## SavedVariables

- **`NPCTrackerObservationDB`** — Account-wide persistence (see `NPCTracker.toc`). **`observationsByEntry`**: `[npcEntryId] = { npcName = "…", entries = { [guidKey] = { { source, continent, zone, subzone, t, x, y, level, reaction }, … } } }` — one array per spawn GUID (no duplicate `guid` on each row); auto adds **one** sample per `(entryId, guid)` unless manual. Also **`autorecord`** (`enabled`, `mouseover`). Use **`/npct prune`** to drop invalid coordinate rows if you ever need to clean the DB.
- **`NPCTrackerMapSettings`** — Map panel position and which NPCs/zones show pins.
- **`NPCTrackerScriptDB`** — **`byEntry[npcEntryId] = { spells = { … }, auras = { … } }`**: up to **5** unique spell ids from `UNIT_CASTEVENT` and **3** from `UnitBuff` / `UnitDebuff`, merged for that template (not stored per spawn GUID).

Intended shape (you can extend fields per observation entry):

```lua
NPCTrackerObservationDB = {
  observationsByEntry = {
    [1287] = {
      npcName = "NPC Name",
      entries = {
        ["0xF130000507013750"] = {
          {
            x = 52.1,
            y = 38.4,
            level = 5,
            reaction = 2,
            t = 12345.6,
            source = "auto",
            continent = "Eastern Kingdoms",
            zone = "Stormwind City / Trade District",
            subzone = "Trade District",
          },
        },
      },
    },
  },
  autorecord = { enabled = true, mouseover = true },
}

NPCTrackerScriptDB = {
  byEntry = {
    [1287] = {
      spells = { 172, 53 },
      auras = { 139 },
    },
  },
}
```

Game clients only persist **Lua tables** via SavedVariables (no arbitrary SQL/files). Export for external tools is usually copy from WTF or a future `/dump`-style command.

## GUID and database NPC id (crosslinking)

With **SuperWoW**, `UnitExists` / `UnitGUID` expose a unit GUID; storage keys samples by that GUID string (e.g. `"0xF130000507013750"`). Rows under `observationsByEntry` usually omit a duplicate **`guid`** field because the spawn key is the GUID.

On Turtle WoW’s 1.12-style packing, that value is **not** the same number as the wiki/database **NPC id**, but the **template id (creature entry)** is **embedded** in the middle of the hex:

| Piece (after the `0x`) | Role |
|------------------------|------|
| First **4** hex digits (`F130`) | High-GUID / object class for units (constant for normal creatures). |
| Next **6** hex digits | **Creature template id** — same integer as **`?npc=`** on sites like [Turtle WoW Database](https://database.turtlecraft.gg/) (e.g. `000507` → **1287**, `002E5B` → **11867**). |
| Last **6** hex digits | Instance / spawn counter (identifies *this* spawn in the world; **not** map coordinates). |

**Parsing (for export tools or scripts):** strip the `0x`, take hex positions 5–10 (six characters), interpret as a hexadecimal integer — that decimal value is the **database NPC / entry id**. Example: `"0xF130000507013750"` → middle `000507` → **1287** → `https://database.turtlecraft.gg/?npc=1287`.

**Use this relation for:** joining observations to **`creature_template`-style ids**, stable links to external DB pages, and disambiguating duplicate NPC names — without treating the full 64-bit GUID as if it were the entry id.

**Do not expect:** world **x/y/z** inside the GUID (position stays in **`x` / `y`** on the observation, from the map API). The **tail** digits distinguish two live spawns of the same entry; they are not a substitute for coords and may not match a server DB `creature.guid` without core-specific rules.

**Requirement:** this addon expects **SuperWoW**-style creature GUIDs for recording and map data from `observationsByEntry`.

## Lua API (NPCTracker.lua)

- **`NPCTracker_GetNPCBySource(continent, zone, npcName)`**  
  Returns `{ observation = ... }` — the observation block filtered to the current map zone when per-entry `zone` / `continent` exist, or **`nil`** if none.

- **`NPCTracker_ListNPCNamesForZone(continent, zone)`**  
  Returns a sorted list of NPC **names** you have observed for that zone.

- **`NPCTracker_NormalizeGuidKey(guid)`**, **`NPCTracker_IsCreatureNpcGuid(guid)`**, **`NPCTracker_CreatureEntryFromGuid(guid)`**  
  Helpers for SuperWoW hex GUIDs (`0xF130…` creatures). Entry id matches the **database npc id** / `?npc=` (same packing as described under “GUID and database NPC id”).

- **`NPCTracker_FilterObservationForMapZone(block, continent, mapZone)`**  
  Returns a copy of an observation block with only entries whose stored **`continent` / `zone`** match the open map (skips rows missing those fields).

**Continent** strings must match the registry: `"Kalimdor"` or `"Eastern Kingdoms"`.  
**Zone** names should match `twow-zones.txt` / `GetRealZoneText()`; add aliases in code if the client string differs.

## Zone registry

`zones_registry.lua` defines `TWOW_ZONE_META`, `TWOW_ZONES_ORDERED`, and helpers `TWOW_GetZoneMeta`, `TWOW_ContinentForZone`. Keep this in sync with `addon/twow-zones.txt` when the server adds or renames zones.

## Known limitations

1. **Locale**: NPC **names** are whatever the client reports; exports use English zone buckets from `GetRealZoneText()` / minimap.

2. **SuperWoW**: without creature GUIDs, the addon does not record locations (no fallback path).

