-- Additional Forever relationships omitted by the original Bestiary metadata export.
local _, Parent = ...
local A = Parent.Items
function A.Relation(entity, id, field)
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, version = false, nil
    if metadata then
        ok, version = pcall(metadata, 'QuestieDB', 'Version')
    end
    if not ok or type(version) ~= 'string' then
        version = ''
    end
    local major, minor, patch = (version or ''):match('^(%d+)%.(%d+)%.(%d+)$')
    local newer = major
        and (tonumber(major) > 1 or tonumber(major) == 1 and (tonumber(minor) > 0 or tonumber(patch) > 13))
    local provider = newer and LibQuestieDB and LibQuestieDB[entity]
    if provider and type(provider.Get) == 'function' then
        local ok, value = pcall(provider.Get, id, field)
        if ok and value ~= nil then
            return value
        end
    end
    local records = entity == 'Quest' and A.QuestDetails or entity == 'Object' and A.Objects or A.ExtraItems
    return records[id] and records[id][field]
end

function A.QuestSupplyRows(item)
    local rows = {}
    for _, questID in ipairs(A.SuppliedItems[item] or {}) do
        -- Recheck the field so newer optional metadata can remove an old association.
        if A.Relation('Quest', questID, 'sourceItemId') == item then
            local name = A.Relation('Quest', questID, 'name') or ('Quest ' .. questID)
            local starters = A.Relation('Quest', questID, 'startedBy') or {}
            local count = 0
            for _, npc in ipairs(starters[1] or {}) do
                local npcName = A.ReferenceMetadata.Npc.Get(npc, 'name') or ('NPC ' .. npc)
                rows[#rows + 1] = {
                    title = name,
                    detail = 'Given on quest acceptance / ' .. npcName,
                    npcID = npc,
                    kind = 'Quest supply',
                    questID = questID,
                    extra = 'QuestieDB Forever / '
                        .. A.MonsterZones(npc)
                        .. ' / Quest availability and prerequisites apply.',
                }
                count = count + 1
            end
            for _, object in ipairs(starters[2] or {}) do
                rows[#rows + 1] = {
                    title = name,
                    detail = 'Given on quest acceptance / '
                        .. (A.Relation('Object', object, 'name') or ('Object ' .. object)),
                    objectID = object,
                    kind = 'Quest supply',
                    questID = questID,
                }
                count = count + 1
            end
            if count == 0 then
                rows[#rows + 1] = {
                    title = name,
                    detail = 'Given when accepting this quest',
                    kind = 'Quest supply',
                    questID = questID,
                }
            end
        end
    end
    return rows
end

function A.AdditionalSources(item)
    local rows = A.QuestSupplyRows(item)
    for _, object in ipairs(A.Relation('Item', item, 'objectDrops') or {}) do
        rows[#rows + 1] = {
            title = A.Relation('Object', object, 'name') or ('Object ' .. object),
            detail = 'World object / chance unknown',
            objectID = object,
            kind = 'Object',
            extra = 'QuestieDB Forever reference / may require an active quest.',
        }
    end
    for _, container in ipairs(A.Relation('Item', item, 'itemDrops') or {}) do
        rows[#rows + 1] = {
            title = A.ItemInfo(container),
            detail = 'Contained in this item / click to inspect',
            itemID = container,
            kind = 'Container',
        }
    end
    return rows
end
