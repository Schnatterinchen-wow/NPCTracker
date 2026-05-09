# NPCTracker — data reference (concise)

## SavedVariables

One file: `WTF\Account\<ACCOUNT>\SavedVariables\NPCTracker.lua` (tables below). Expect the shapes documented here; there is no migration from older layouts—reset or edit the file if it drifts.

| Table | Role |
|-------|------|
| `NPCTrackerObservationDB` | Per **npc entry id** → per **spawn GUID** → array of observation rows. |
| `NPCTrackerMapSettings` | World-map panel: which zones / NPCs show pins; `panel` position. |
| `NPCTrackerScriptDB` | Per **npc entry id**: unique `spells` / `auras` spell ids (not per-GUID). |

## Caps (counts)

| What | Limit |
|------|--------|
| Observations per **(entry id, spawn GUID string)** | Up to **64** rows; auto adds until full (old auto rows can be dropped; manual rows replace other manuals only for that GUID). Tuned in `NPCTracker_Record.lua` (`MAX_AUTO_SAMPLES_PER_GUID`). |
| **Auto** re-hover / re-target spam | **`autoRecordLastFiveGuids`** — MRU list of up to **5** normalized spawn GUID keys. If the current unit’s GUID is already in this list, **auto** does not append another row (silent). A GUID leaves the list after **5 other distinct** GUIDs have been auto-recorded. **`/npct record` ignores this** and does not update the ring. `AUTO_GUID_RING_MAX` in `NPCTracker_Record.lua`. |
| **Patrol** samples per **(entry id, spawn GUID string)** | Up to **5** rows with `source = "patrol"`; on the 6th the oldest patrol row is dropped (FIFO by `t`). Auto/manual rows are not touched. `MAX_PATROL_SAMPLES_PER_GUID` in `NPCTracker_Record.lua`. `/npct patrol clear` removes every patrol row for the targeted spawn. |
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
| `continent` | String, e.g. `Eastern Kingdoms`, `Kalimdor`, or `Unknown`. In **instances**, if `GetRealZoneText()` matches `dungeons_registry.lua` (`twow-dungeons`), continent is derived from the dungeon’s **associated zone** (`TWOW_ContinentForAssociatedZone`). |
| `zone` | Zone bucket: `GetRealZoneText()`, with ` " / " ` + `GetMinimapZoneText()` if subzone differs. |
| `dungeon` | Set when the instance name matched the dungeon list: registry **dungeon name**. |
| `parentZone` | Set with `dungeon`: **associated zone** (entrance / continent reference). |
| `subzone` | Minimap subzone when it differed from real zone; else omitted. |
| `source` | `"auto"`, `"manual"`, or `"patrol"`. Recorded by `/npct record` for `manual` and `/npct patrol` for `patrol`. |
| `level` | `UnitLevel` |
| `reaction` | `UnitReaction` vs player |
| `displayId` | Model display id when a client API returns it; else omitted. |
| `creatureType` | `UnitCreatureType` (number) when present. |
| `classification` | `UnitClassification` when present: `"normal"`, `"elite"`, `"rare"`, `"rareelite"`, `"worldboss"`, `"trivial"`, `"minus"`, etc. Omitted if the API is missing or returns empty. |
| (no `guid` on row) | Instance identity is the **key** in `entries`. |

`guid` is stripped from the row before save; the **spawn key** in `entries[guidKey]` is the GUID string.

## `NPCTrackerScriptDB.byEntry[entry]`

| Field | Meaning |
|-------|---------|
| `spells` | Unique spell **ids** seen from `UNIT_CASTEVENT` (caster = that creature). Web: `?spell=<id>`. |
| `auras` | Unique **spell** ids from `UnitBuff` / `UnitDebuff` on record. Same web link style. |

## `NPCTrackerMapSettings` (brief)

- `zoneEnabled[continent][zone]` — pins only when **value is `true`**. Default is **off** (nil/false) until you enable “Show pins for this zone” for that map.
- `npcEnabled[continent][zone][name]` — per-NPC; `false` = hidden.
- `panelPoint` — panel anchor for UI (if set).

## `autorecord` (inside `NPCTrackerObservationDB`)

- `enabled` — auto samples on.
- `mouseover` — also sample on mouseover when enabled.

## `autoRecordLastFiveGuids` (inside `NPCTrackerObservationDB`)

- Array of up to **5** strings: normalized creature **GUID** keys (same form as keys under `entries`), **most recent last**.
- After each successful **auto** record, the spawn GUID for that sample is moved to the MRU end; the list is trimmed from the front.
- **Auto** attempts whose GUID is **already in the list** return without writing (no chat message).
- **Manual** `/npct record` does **not** read or write this list.

## GUID → npc template id (entry id)

- Creature NPC GUID: prefix **`0xF130`** (16 hex digits total after `0x`).
- The **entry id** is the **pack** decoded in `NPCTracker_CreatureEntryFromGuid` in `NPCTracker.lua` (32-bit high/low from the 8+8 hex pairs); use that function as the **source of truth**—do not reimplement from prose if the client uses non-trivial bit layout.
- **Web (npc):** `https://www.wowhead.com/npc=<entry>` (replace `<entry>` with the decimal id). Other DBs: same `npc=` or `?npc=<entry>` as their URL scheme.
- The GUID still contains **per-spawn** bits (tail of hex); the **key** in `entries` is the full string so two spawns of the same entry stay separate.
- **Spells** in `NPCTrackerScriptDB` use **spell** ids, not npc ids: `?spell=<id>` on Wowhead and similar.

## Dungeon list (`dungeons_registry.lua`)

- Source: `addon/twow-dungeons.txt` (embedded as `DUNGEON_ROWS`). Columns: release, level range, dungeon name, associated zone, bosses note, quests note.
- **Continent** for a sample in a matching instance = continent of **associated zone** (`TWOW_ContinentForZone`; **Blackrock Mountain** still uses a **fallback** because that name is absent from `twow-zones`).
- Client spelling may differ (`The Stockade` vs `Stockades`): see `DUNGEON_ZONE_TEXT_ALIASES` in `dungeons_registry.lua`.
