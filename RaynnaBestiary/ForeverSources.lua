-- Forever dungeon relationships, independent of Classic probability tables.
local _, A = ...
local bosses, itemSources = {}, {}
for key, dungeon in pairs(A.DungeonReference) do
    for id, boss in pairs(dungeon.bosses) do
        bosses[id] = { name = boss.name, zone = dungeon.name, area = dungeon.area, loot = boss.loot }
        for _, item in ipairs(boss.loot) do
            itemSources[item] = itemSources[item] or {}
            itemSources[item][id] = bosses[id]
        end
    end
    for _, item in ipairs(dungeon.trash) do
        itemSources[item] = itemSources[item] or {}
        itemSources[item]['dungeon:' .. key] = { name = dungeon.name, zone = dungeon.name, trash = true }
    end
end
-- Small factual supplements from Forever-specific sources, never inferred by name.
-- Checked 2026-11-21; remaining NPCs use the bundled/provider data.
local supplements = {
    [250622] = {
        minLevel = 15,
        maxLevel = 16,
        zone = 'Ruins of Lordaeron',
        source = 'Warcraft Wiki / Ragged Ghoul (Ruins of Lordaeron)',
    },
    [250623] = {
        minLevel = 15,
        maxLevel = 16,
        zone = 'Ruins of Lordaeron',
        source = 'Warcraft Wiki / Mangled Cadaver (Ruins of Lordaeron)',
    },
    [250619] = {
        minLevel = 15,
        maxLevel = 16,
        zone = 'Ruins of Lordaeron',
        source = 'Warcraft Wiki / Broodwidow (Ruins of Lordaeron)',
    },
    [250654] = {
        minLevel = 14,
        maxLevel = 15,
        zone = 'Ruins of Lordaeron',
        source = 'Warcraft Wiki / Ghostly Citizen (Ruins of Lordaeron)',
    },
    [256040] = {
        minLevel = 15,
        maxLevel = 16,
        zone = 'Ruins of Lordaeron',
        source = 'Efficient Games / NPC 256040',
    },
    [250625] = { zone = 'Ruins of Lordaeron', source = 'Forever Drop Rate / NPC 250625' },
    [255964] = { zone = 'Ruins of Lordaeron', source = 'Forever Drop Rate / NPC 255964' },
    [255109] = { zone = 'Ruins of Lordaeron', source = 'Forever Drop Rate / NPC 255109' },
    [250656] = { zone = 'Ruins of Lordaeron', source = 'Forever Drop Rate / NPC 250656' },
    [250629] = { zone = 'Ruins of Lordaeron', source = 'Forever Drop Rate / NPC 250629' },
}
local oldZones, oldMonster, oldItem = A.MonsterZones, A.ReferenceMonster, A.ReferenceItem
function A.MonsterZones(id)
    local record = supplements[id] or bosses[id]
    return record and record.zone or oldZones(id)
end
local function improve(id, row)
    local extra = supplements[id]
    if extra then
        if not row.minLevel or row.minLevel <= 0 then
            row.minLevel = extra.minLevel
        end
        if not row.maxLevel or row.maxLevel <= 0 then
            row.maxLevel = extra.maxLevel
        end
        row.metadataSource = extra.source
    end
    if row.minLevel and row.minLevel <= 0 then
        row.minLevel = nil
    end
    if row.maxLevel and row.maxLevel <= 0 then
        row.maxLevel = nil
    end
end
function A.ReferenceMonster(id, name, level, progressive)
    local result = oldMonster(id, name, level, progressive)
    improve(id, result)
    local boss = bosses[id]
    if boss then
        for _, item in ipairs(boss.loot) do
            if not result.drops[item] then
                result.drops[item] = {
                    link = 'item:' .. item,
                    name = A.LootReference.names[item],
                    source = 'Forever DungeonJournal / NorgannonDB',
                }
            end
        end
        result.mixedReference = true
    end
    return result
end
function A.ReferenceItem(item)
    local result = oldItem(item)
    -- Copy cached rows before supplementing: lookups must not mutate the base cache.
    for id, row in pairs(result.drops) do
        local copy = {}
        for key, value in pairs(row) do
            copy[key] = value
        end
        result.drops[id] = copy
        if type(id) == 'number' then
            improve(id, copy)
        end
    end
    for id, source in pairs(itemSources[item] or {}) do
        if not result.drops[id] then
            result.drops[id] = {
                name = source.name,
                kind = source.trash and 'Dungeon trash' or nil,
                details = source.zone,
                source = 'Forever DungeonJournal / NorgannonDB',
            }
        end
        result.drops[id].foreverSource = true
        if result.drops[id].rate then
            result.drops[id].source = (result.drops[id].source or 'Classic reference')
                .. ' / source also listed by Forever DungeonJournal'
        end
        if type(id) == 'number' then
            improve(id, result.drops[id])
        end
    end
    return result
end
