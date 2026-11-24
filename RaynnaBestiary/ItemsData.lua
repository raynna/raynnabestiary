-- Item relationships are indexed once. Saved history contains IDs, not duplicate databases.
local _, Parent = ...
local A = Parent.Items
local uses, products, books = {}, {}, {}
local function append(index, id, recipe)
    index[id] = index[id] or {}
    table.insert(index[id], recipe)
end
for _, recipe in ipairs(A.Recipes) do
    for _, reagent in ipairs(recipe[6]) do
        append(uses, reagent[1], recipe)
    end
    if recipe[5] > 0 then
        append(products, recipe[5], recipe)
    end
    for _, id in ipairs(recipe[7]) do
        append(books, id, recipe)
    end
end
local recipeBySpell = {}
for _, recipe in ipairs(A.Recipes) do
    recipeBySpell[recipe[1]] = recipe
end
for item in pairs(A.ExtraItems or {}) do
    local spell = A.Relation('Item', item, 'teachesSpell')
    if recipeBySpell[spell] then
        append(books, item, recipeBySpell[spell])
    end
end

function A.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function A.ItemID(value)
    if not A.Readable(value) then
        return nil
    end
    if type(value) == 'number' then
        return value > 0 and value == math.floor(value) and value or nil
    end
    if type(value) == 'string' then
        return tonumber(value:match('item:(%d+)')) or tonumber(value:match('^%d+$'))
    end
end

function A.ItemInfo(id)
    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
    if api then
        local ok, name, link, quality, _, _, kind, subtype, _, _, icon, sell = pcall(api, id)
        if ok and A.Readable(name) and type(name) == 'string' then
            return name, icon, kind, subtype, sell, link, quality
        end
    end
    id = A.ItemID(id) or id
    local record = A.BundledMetadata.Item[id]
    local name = A.ItemNames[id] or (record and record.name) or A.LootReference.names[id]
    local recipe = products[id] and products[id][1]
    return name or (recipe and recipe[2]) or ('Item ' .. id), 134400
end

local function craftRow(recipe, prefix, item)
    local quantity
    for _, reagent in ipairs(recipe[6]) do
        if reagent[1] == item then
            quantity = reagent[2]
        end
    end
    local title = prefix .. recipe[2]
    local ingredientView = prefix == 'Made with: '
    if ingredientView then
        local parts = {}
        for index, reagent in ipairs(recipe[6]) do
            if index <= 2 then
                parts[#parts + 1] = reagent[2] .. ' x ' .. A.ItemInfo(reagent[1])
            end
        end
        title = 'Made with: ' .. table.concat(parts, ', ') .. (#recipe[6] > 2 and ' ...' or '')
    end
    return {
        title = title,
        detail = recipe[3] .. (quantity and (' / uses ' .. A.Green(quantity)) or '') .. ' / Forever',
        itemID = recipe[5] > 0 and recipe[5] or nil,
        recipe = recipe,
        action = ingredientView and 'ingredients' or nil,
    }
end

function A.IngredientRows(recipe)
    local rows = {}
    for _, reagent in ipairs(recipe[6]) do
        rows[#rows + 1] = {
            title = A.Green(reagent[2]) .. ' x ' .. A.ItemInfo(reagent[1]),
            detail = 'Ingredient / click for uses and sources',
            itemID = reagent[1],
            quantity = reagent[2],
        }
    end
    return rows
end

function A.BuildUses(id)
    local rows = {}
    for _, supply in ipairs(A.QuestSupplyRows(id)) do
        rows[#rows + 1] = {
            title = '[Quest] ' .. supply.title,
            detail = 'Provided for this quest / see Sources for the quest giver',
            npcID = supply.npcID,
            objectID = supply.objectID,
            questID = supply.questID,
        }
    end
    for _, questID in ipairs(A.RequiredItems[id] or {}) do
        local name = A.Relation('Quest', questID, 'name') or ('Quest ' .. questID)
        rows[#rows + 1] =
            { title = '[Quest] ' .. name, detail = 'Required to start this quest / QuestieDB Forever' }
    end
    for _, action in ipairs(A.CampUses or {}) do
        if action[2] == id then
            rows[#rows + 1] =
                { title = action[4], detail = action[5] .. ' / uses ' .. A.Green(action[3]) .. ' / Forever' }
        end
    end
    for _, quest in ipairs(A.ItemQuests(id)) do
        rows[#rows + 1] = {
            title = '[Quest] ' .. quest.name,
            detail = quest.starts and 'Starts this quest' or 'Used for this quest / requirements may apply',
        }
    end
    for _, recipe in ipairs(books[id] or {}) do
        rows[#rows + 1] = craftRow(recipe, 'Teaches: ', id)
    end
    for _, recipe in ipairs(products[id] or {}) do
        rows[#rows + 1] = craftRow(recipe, 'Made with: ', id)
    end
    for _, recipe in ipairs(uses[id] or {}) do
        rows[#rows + 1] = craftRow(recipe, '', id)
    end
    if #rows == 0 then
        rows[1] = {
            title = 'No specific use recorded',
            detail = 'Coverage is incomplete; this does not mean the item is useless.',
        }
    end
    return rows
end

function A.BuildSources(id)
    local rows = A.AdditionalSources(id)
    for _, recipe in ipairs(products[id] or {}) do
        rows[#rows + 1] = craftRow(recipe, 'Made with: ', id)
    end
    for key, source in pairs(A.ReferenceItem(id).drops) do
        local npcID = type(key) == 'number' and key or tonumber(tostring(key):match('^vendor:(%d+)$'))
        local detail = source.details or (type(key) == 'number' and A.MonsterZones(key)) or ''
        local location = detail
        local levelText = type(source.minLevel) == 'number'
                and source.minLevel > 0
                and ('Lv ' .. source.minLevel .. (source.maxLevel and source.maxLevel > source.minLevel and ('-' .. source.maxLevel) or ''))
            or 'Lv ?'
        local rate = source.rate and A.Green(string.format('%.2f%%', source.rate)) or 'Chance unknown'
        if type(source.minLevel) == 'number' and source.minLevel > 0 then
            detail = 'Lv '
                .. source.minLevel
                .. (source.maxLevel and source.maxLevel > source.minLevel and ('-' .. source.maxLevel) or '')
                .. ' / '
                .. detail
        elseif not source.kind then
            detail = 'Level unknown / ' .. detail
        end
        rows[#rows + 1] = {
            title = source.name,
            location = location ~= '' and location or 'Zone unavailable',
            levelText = levelText,
            sourceLayout = npcID ~= nil,
            conditional = source.conditional,
            detail = (source.kind or rate) .. ' / ' .. detail,
            extra = source.kind and ''
                or (
                    rate
                    .. (source.conditional and ' (conditional)' or '')
                    .. ' / '
                    .. (source.source or 'Classic reference')
                    .. (source.metadataSource and (' / NPC details: ' .. source.metadataSource) or '')
                ),
            foreverSource = source.foreverSource,
            rate = source.rate,
            kind = source.kind,
            npcID = npcID,
        }
    end
    table.sort(rows, function(a, b)
        local ar = type(a.rate) == 'number' and a.rate or -1
        local br = type(b.rate) == 'number' and b.rate or -1
        if ar ~= br then
            return ar > br
        end
        if (a.foreverSource or false) ~= (b.foreverSource or false) then
            return a.foreverSource == true
        end
        if (a.kind or '') ~= (b.kind or '') then
            return (a.kind or '') > (b.kind or '')
        end
        return a.title < b.title
    end)
    if #rows == 0 then
        rows[1] = { title = 'No source recorded', detail = 'New or changed Forever items may be missing.' }
    end
    return rows
end

function A.Remember(id)
    local history = A.db.history
    for index = #history, 1, -1 do
        if history[index] == id then
            table.remove(history, index)
        end
    end
    table.insert(history, 1, id)
    while #history > 40 do
        table.remove(history)
    end
    A.db.lastItem = id
end

function A.Search(text)
    local id = A.ItemID(text)
    if id then
        return { { title = A.ItemInfo(id), itemID = id, detail = 'Open item reference' } }
    end
    text = string.lower(text or '')
    local result, seen = {}, {}
    local function add(item, name)
        if not seen[item] and type(name) == 'string' and string.find(string.lower(name), text, 1, true) then
            seen[item] = true
            result[#result + 1] = { title = name, itemID = item, detail = 'Open item reference' }
        end
    end
    if text == '' then
        for _, item in ipairs(A.db.history) do
            add(item, A.ItemInfo(item))
        end
    else
        for item, record in pairs(A.BundledMetadata.Item) do
            add(item, record.name)
        end
        for item, name in pairs(A.LootReference.names) do
            add(item, name)
        end
        for item, recipes in pairs(products) do
            add(item, recipes[1][2])
        end
        table.sort(result, function(a, b)
            return a.title < b.title
        end)
    end
    return result
end

function A.Summary(id)
    local description = A.ItemDescription(id)
    if description then
        return description
    end
    local supplied = A.QuestSupplyRows(id)
    if #supplied > 0 then
        return 'Provided when accepting '
            .. supplied[1].title
            .. '. See Sources for the quest giver; quest prerequisites may apply.'
    end
    local count = #(uses[id] or {})
    if count > 0 then
        return 'Crafting material used in '
            .. A.Green(count)
            .. ' recorded Forever recipes. See Uses for materials and professions.'
    end
    if books[id] then
        return 'Recipe item: teaches a crafting recipe. Profession requirements apply.'
    end
    local _, _, kind, subtype = A.ItemInfo(id)
    return (kind and (kind .. (subtype and (' / ' .. subtype) or '') .. '. ') or '')
        .. (#A.ItemQuests(id) > 0 and 'Also used for quests; see Uses. ' or '')
        .. 'Browse recorded uses and sources below.'
end
