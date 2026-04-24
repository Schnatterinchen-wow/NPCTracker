# NPCTracker — data reference (concise)

## SavedVariables

One file: `WTF\Account\<ACCOUNT>\SavedVariables\NPCTracker.lua` (tables below).

| Table | Role |
|-------|------|
| `NPCTrackerObservationDB` | Per **npc entry id** → per **spawn GUID** → array of observation rows. |
| `NPCTrackerMapSettings` | World-map panel: which zones / NPCs show pins; `panel` position. |
| `NPCTrackerScriptDB` | Per **npc entry id**: unique `spells` / `auras` spell ids (not per-GUID). |

## Caps (counts)

| What | Limit |
|------|--------|
| Observations per **(entry id, spawn GUID string)** | Up to **64** rows; auto adds until full (old auto rows can be dropped; manual rows replace other manuals only for that GUID). Tuned in `NPCTracker_Record.lua` (`MAX_AUTO_SAMPLES_PER_GUID`). |
| `spells` per entry id in `NPCTrackerScriptDB` | **20** first-seen unique cast spell ids (then further ids ignored). `NPCTracker_Script.lua` `MAX_SPELLS`. |
| `auras` per entry id | **8** first-seen unique aura spell ids. `MAX_AURAS`. |

## `observationsByEntry` structure

- **Key (number):** npc **template / entry id** (same as DB `?npc=`, see below).
- **Value:** `npcName` (string), `entries` (table).
- **Key in `entries` (string):** normalized creature **GUID** for one spawn, e.g. `0xF130…`.
- **Value:** array of one or more **sample** tables (one row = one record event).

## Observation row fields (one sample)

| Field | Meaning |
|-------|---------|
| `t` | `GetTime()` **session** time in **seconds** (not ms), 2 decimal places. Not world height. |
| `x`, `y` | **Player** world-map position, **0–100** %, 2 dp (`GetPlayerMapPosition` at record). |
| `continent` | String, e.g. `Eastern Kingdoms`, `Kalimdor`, or `Unknown`. |
| `zone` | Zone bucket: `GetRealZoneText()`, with ` " / " ` + `GetMinimapZoneText()` if subzone differs. |
| `subzone` | Minimap subzone when it differed from real zone; else omitted. |
| `source` | `"auto"` or `"manual"`. |
| `level` | `UnitLevel` |
| `reaction` | `UnitReaction` vs player |
| `displayId` | Model display id, if a client function exists (`GetCreatureDisplay` / `GetUnitDisplay` / `GetCreatureDisplayId`); else omitted. |
| `creatureType` | `UnitCreatureType` (number) |
| `classification` | `UnitClassification` (string, e.g. `normal`, `elite`) |
| (no `guid` on row) | Instance identity is the **key** in `entries`. |

`guid` is stripped from the row before save; the **spawn key** in `entries[guidKey]` is the GUID string.

## `NPCTrackerScriptDB.byEntry[entry]`

| Field | Meaning |
|-------|---------|
| `spells` | Unique spell **ids** seen from `UNIT_CASTEVENT` (caster = that creature). Web: `?spell=<id>`. |
| `auras` | Unique **spell** ids from `UnitBuff` / `UnitDebuff` on record. Same web link style. |

## `NPCTrackerMapSettings` (brief)

- `zoneEnabled[continent][zone]` — show pins for that map zone; `false` = off.
- `npcEnabled[continent][zone][name]` — per-NPC; `false` = hidden.
- `panelPoint` — panel anchor for UI (if set).

## `autorecord` (inside `NPCTrackerObservationDB`)

- `enabled` — auto samples on.
- `mouseover` — also sample on mouseover when enabled.

## GUID → npc template id (entry id)

- Creature NPC GUID: prefix **`0xF130`** (16 hex digits total after `0x`).
- The **entry id** is the **pack** decoded in `NPCTracker_CreatureEntryFromGuid` in `NPCTracker.lua` (32-bit high/low from the 8+8 hex pairs); use that function as the **source of truth**—do not reimplement from prose if the client uses non-trivial bit layout.
- **Web (npc):** `https://www.wowhead.com/npc=<entry>` (replace `<entry>` with the decimal id). Other DBs: same `npc=` or `?npc=<entry>` as their URL scheme.
- The GUID still contains **per-spawn** bits (tail of hex); the **key** in `entries` is the full string so two spawns of the same entry stay separate.
- **Spells** in `NPCTrackerScriptDB` use **spell** ids, not npc ids: `?spell=<id>` on Wowhead and similar.
