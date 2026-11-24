-- Short factual summaries, checked against Wowhead Forever on 2026-11-15.
-- Prefer the running client's item effect text when available. No wiki prose copied.
local _, Parent = ...
local A = Parent.Items
A.DescriptionSources = {
    [5838] = 'https://www.wowhead.com/forever/quest=1136/frostmaw',
    [1708] = 'https://www.wowhead.com/forever/item=1708/sweet-nectar',
    [3371] = 'https://www.wowhead.com/forever/item=3371/empty-vial',
    [118] = 'https://www.wowhead.com/forever/item=118/minor-healing-potion',
}
function A.Green(value)
    return '|cff78df87' .. tostring(value) .. '|r'
end
function A.ItemDescription(id)
    if id == 286979 then
        return "Rotmender's Raiment set gloves. Found among Ruins of Lordaeron dungeon drops; binds when equipped. Individual NPC drop chances are not fully verified."
    end
    if id == 5838 then
        return 'Quest instructions for luring Frostmaw. Melor Stonehoof gives you this scroll when you accept Frostmaw; it is not a normal monster drop.'
    end
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
        if ok and type(data) == 'table' and type(data.lines) == 'table' then
            for _, line in ipairs(data.lines) do
                local value = line.leftText
                if
                    (not issecretvalue or not issecretvalue(value))
                    and type(value) == 'string'
                    and (value:find('^Use:') or value:find('^Equip:'))
                then
                    return value
                end
            end
        end
    end
    if id == 1708 then
        local requirement = 'Requires level 25.'
        if UnitLevel and UnitLevel('player') < 25 then
            requirement = '|cffff7070' .. requirement .. '|r'
        end
        return 'Drink to recover '
            .. A.Green('1,345 mana')
            .. ' over '
            .. A.Green('27 seconds')
            .. ' while seated. '
            .. requirement
    elseif id == 118 then
        return 'A healing consumable restoring '
            .. A.Green('70-90 health')
            .. '. Cooldown: 2 minutes. Crafted with First Aid in Forever.'
    elseif id == 3371 then
        return 'A disposable crafting container for potions, oils and other recipes. Used by several professions in Forever; sold by supply vendors.'
    end
end

-- Keep the exact hyperlink: suffixes, enchants and instance bonuses are not
-- represented by the base item ID. The client remains the authority for stats.
function A.ItemDetailRows(link)
    local data
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, value = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and type(value) == 'table' then
            data = value
        end
    end
    local result = {}
    local function add(left, right)
        if type(left) ~= 'string' or (issecretvalue and issecretvalue(left)) then
            return
        end
        if type(right) == 'string' and (not issecretvalue or not issecretvalue(right)) and right ~= '' then
            left = left .. ' / ' .. right
        end
        if left ~= '' then
            result[#result + 1] = { title = A.EffectText(left), detail = '', itemDetail = true }
        end
    end
    if data and type(data.lines) == 'table' then
        for _, line in ipairs(data.lines) do
            add(line.leftText, line.rightText)
        end
    end
    if #result == 0 then
        if not A.detailScanner then
            A.detailScanner =
                CreateFrame('GameTooltip', 'RaynnaBestiaryItemScanner', UIParent, 'GameTooltipTemplate')
        end
        local scanner = A.detailScanner
        scanner:SetOwner(UIParent, 'ANCHOR_NONE')
        scanner:SetHyperlink(link)
        local count = scanner:NumLines()
        if type(count) == 'number' then
            for i = 1, count do
                local left, right =
                    _G['RaynnaBestiaryItemScannerTextLeft' .. i],
                    _G['RaynnaBestiaryItemScannerTextRight' .. i]
                add(left and left:GetText(), right and right:GetText())
            end
        end
        scanner:Hide()
    end
    if #result == 0 then
        result[1] =
            { title = 'Item details are loading', detail = 'Hover the item name for its full game tooltip.' }
    end
    return result
end
