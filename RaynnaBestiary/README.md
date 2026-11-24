# Raynna's Bestiary

One standalone reference for monsters and items in WoW Forever.

- Alt-hover monsters for reference drops and chances.
- Alt-hover items for uses, recipes, clickable ingredients, quests and sources.
- Click monster loot to open its item details. Source rows provide locations and map links where available.
- `/rb` opens monster selection; `/rc` opens the item reference; `/rb settings` opens all Bestiary options.
- Tracker integration opens your tracked monsters. Clear restores the full list without changing history.

The optional RaynnaCodex folder is now only a legacy saved-history loader.
Keep it enabled for the first login after upgrading to migrate old Codex history,
scale and position. Once migrated, Bestiary works without it. No other addon is required.

Forever snapshots and explicit corrections are preferred; Classic fallback rates
are labelled and remain unverified for Forever. Missing dungeon data cannot be
invented. Hover works with readable creature IDs even if name/level are unavailable;
client-restricted IDs cannot be read by the addon.

## 2.3.0 interface update

- Source entries separate name/chance and location/level into two compact lines.
- Filter the current list by name/location, source type or known drop rates.
- Save favourite items, use clickable Back breadcrumbs, and browse shorter lists in a smaller panel.
- Hover the item header for the full native tooltip. Details lists the client's stats, requirements, effects and set text; exact hovered item links retain random bonuses.
- Map actions draw blue glows over recorded spawn locations, place the waypoint at the nearest comparable recorded location (densest-cluster fallback when player position is unavailable), and offer a Clear control. These are reference locations, not live spawn counts.
- Link clicks select the address; press Ctrl+C to copy it. Addons cannot use Blizzard's protected direct clipboard function.

Map rendering and interface behavior are covered by mocked tests; final visual verification requires the running Forever client.

## 2.3.1 layout refinement

NPC levels sit beside their names. Hover rows show the full action label again.
List filters and item search sit below the entries.

Live item stats, level requirements, effects and set text appear directly below
the item header. A separate scrollbar reveals overflow without scrolling the
source list. The native tooltip remains available by hovering the item name.

## 2.3.2

Fixed cooldown plural tokens being displayed as colour-code numbers. Removed
the redundant Details tab now that full item text has its own scrollable header.

## 2.3.3 map areas

Spawn overlays now use translucent blue filled regions with cyan outlines instead
of separate glows. Nearby records are grouped; distant camps stay separate.
These are estimated coverage areas, not authoritative spawn boundaries. The
nearest-location waypoint, map zoom/pan tracking and Clear control are retained.

## 2.4.0 shared browser and map navigation

- NPC drops and item details share one panel, Back history, saved entries, filters and search. NPC mode searches monsters; item mode searches items.
- Click an NPC source to view its drops; Show on map is available in NPC mode.
- Gold scrollbars match across lists and item descriptions. Gold ! badges mark quest-related entries.
- Hover transitions reset NPC/item selection without auto-pinning.
- Larger estimated spawn regions use smoother outlines and include matching map-area records.
- The selected location has a name/level label, a six-second pulse and a modest one-time zoom when supported. Manual map controls remain available.

## 2.4.1 navigation pinning

Clicking through to an item, NPC or ingredient list pins the reference panel,
preventing shorter pages from disappearing under the cursor. Back keeps it pinned.
Unpin restores normal Alt-hover dismissal; opening a hover preview alone does not pin.

Drop rows now show item types instead of database names and technical drop labels.
Source attribution and conditional requirements remain available on hover.

## 2.4.2 region labels

Every shaded spawn region now shows the NPC name and level at its geometric
centre. Text size adapts to the region, with a dark outline and shadow for contrast.

## 2.4.3 map tooltips

Hover shaded regions for NPC information and recorded spawn counts. Hover Clear
for an explanation of what it removes. Region detection does not intercept map
clicks or dragging, and yields to native map-pin tooltips.

## 2.4.4 hover recovery

Hiding the reference panel (including Show on map) releases its pin and temporary
item selection, so later NPC and inventory Alt-hover requests work normally.
