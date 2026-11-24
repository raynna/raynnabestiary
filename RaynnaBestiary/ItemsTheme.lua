-- Shared panel appearance. All colors, textures, layers and dimensions are presentation only.

local _, Parent = ...
local Addon = Parent.Items
local panels = {}
function Addon.ApplyAppearance()
    local appearance = Addon.db.appearance or {}
    for _, panel in ipairs(panels) do
        panel:SetBackdropColor(0.035, 0.027, 0.018, appearance.opacity or 0.97)
        panel.raynnaPaper:SetAlpha(appearance.paper == false and 0 or 0.3)
    end
end
Addon.Theme = { gold = { 1, 0.82, 0.18 }, text = { 0.92, 0.86, 0.72 }, muted = { 0.8, 0.74, 0.6 } }
function Addon.SkinPanel(frame, titleBar)
    panels[#panels + 1] = frame
    frame:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
        tile = true,
        tileSize = 32,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.035, 0.027, 0.018, 0.97)
    frame:SetBackdropBorderColor(0.74, 0.55, 0.22, 1)
    if not frame.raynnaPaper then
        local paper = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
        paper:SetPoint('TOPLEFT', 5, titleBar and -27 or -5)
        paper:SetPoint('BOTTOMRIGHT', -5, 5)
        paper:SetTexture('Interface\\AddOns\\RaynnaBestiary\\Media\\RaynnaParchment.tga')
        paper:SetVertexColor(0.42, 0.36, 0.27, 1)
        paper:SetAlpha(0.3)
        frame.raynnaPaper = paper
    end
    if titleBar and not frame.raynnaTitleArt then
        local art = frame:CreateTexture(nil, 'ARTWORK', nil, 0)
        art:SetPoint('TOPLEFT', 4, -4)
        art:SetPoint('TOPRIGHT', -4, -4)
        art:SetHeight(22)
        art:SetColorTexture(0.24, 0.115, 0.035, 1)
        local grain = frame:CreateTexture(nil, 'ARTWORK', nil, 1)
        grain:SetAllPoints(art)
        grain:SetTexture('Interface\\AddOns\\RaynnaBestiary\\Media\\RaynnaParchment.tga')
        grain:SetVertexColor(0.45, 0.22, 0.07, 1)
        grain:SetAlpha(0.4)
        frame.raynnaTitleArt = art
        local line = frame:CreateTexture(nil, 'ARTWORK', nil, 2)
        line:SetPoint('TOPLEFT', 5, -26)
        line:SetPoint('TOPRIGHT', -5, -26)
        line:SetHeight(1)
        line:SetColorTexture(0.63, 0.43, 0.14, 0.9)
    end
    Addon.ApplyAppearance()
end

-- Presentation-only source colours; labels and numeric sort values remain intact.
function Addon.SourceStyle(entry)
    local kind = entry.kind or ''
    if kind:find('Quest') or (entry.title or ''):find('^%[Quest%]') then
        return 'Quest', 'ffd45c'
    end
    if entry.recipe then
        return 'Crafting', 'c59bff'
    end
    if kind == 'Vendor' then
        return 'Vendor', '65d9db'
    end
    if kind == 'Object' then
        return 'World object', 'e3b879'
    end
    if kind == 'Container' then
        return 'Container', 'e3b879'
    end
    if kind == 'Dungeon trash' then
        return 'Dungeon trash', 'f3aa73'
    end
    if entry.npcID or kind == 'Monster drop' then
        return 'Monster drop', 'f3aa73'
    end
end
function Addon.ColourMissing(text)
    text = text or ''
    for _, phrase in ipairs({
        'Chance unknown',
        'chance unknown',
        'Level unknown',
        'Zone unavailable',
        'No recorded coordinates',
        'No specific use recorded',
        'No source recorded',
        'Coverage is incomplete',
    }) do
        text = text:gsub(phrase, '|cffe68b8b' .. phrase .. '|r')
    end
    return text
end
function Addon.SourceDetail(entry)
    if entry.lootLayout then
        return entry.detail or ''
    end
    local label, color = Addon.SourceStyle(entry)
    local detail = Addon.ColourMissing(entry.detail)
    if label then
        local short = (
            { ['Monster drop'] = 'Drop', ['World object'] = 'Object', ['Dungeon trash'] = 'Trash' }
        )[label] or label
        local prefix = '|cff' .. color .. '[' .. short .. ']|r'
        if detail:sub(1, #label) == label then
            return prefix .. detail:sub(#label + 1)
        end
        return prefix .. ' / ' .. detail
    end
    return detail
end

local schools = {
    Arcane = 'c59bff',
    Frost = '70cfff',
    Fire = 'ff9b55',
    Nature = '78df87',
    Shadow = 'b58be8',
    Holy = 'ffe282',
    Physical = 'dec5a0',
}
local stats = {
    Strength = 'f28b82',
    Agility = '8bdc73',
    Intellect = '79b9ff',
    Stamina = 'f3bf70',
    Spirit = 'd6a0ed',
}
function Addon.HasStatText(value)
    if type(value) ~= 'string' then
        return false
    end
    for stat in pairs(stats) do
        if value:lower():find('%f[%a]' .. stat:lower() .. '%f[%A]') then
            return true
        end
    end
    return false
end
-- Colour plain text spans only, preserving existing item-quality/number markup.
function Addon.EffectText(value)
    if type(value) ~= 'string' then
        return value
    end
    -- Tooltip data contains unrendered WoW plural tokens (1 |4Sec:Secs;).
    -- Resolve these before colouring numbers, or the control digit becomes text.
    value = value:gsub('(%d[%d,%.]*)(%s*)|4([^:;]*):([^;]*);', function(number, space, singular, plural)
        local count = tonumber((number:gsub(',', '')))
        return number .. space .. (count == 1 and singular or plural)
    end)
    local function format(span)
        local lower = span:lower()
        local beneficial = lower:find('increases') or lower:find('restores') or lower:find('heals')
        local harmful = lower:find('damage taken') and lower:find('increases')
        local pluralTokens = {}
        span = span:gsub('|4[^;]*;', function(token)
            pluralTokens[#pluralTokens + 1] = token
            return '\001' .. string.rep('P', #pluralTokens) .. '\002'
        end)
        span = span:gsub('(%d[%d,%.]*%%?)', function(number)
            local colour = harmful and 'e68b8b' or beneficial and '78df87' or '9cc9e8'
            return '|cff' .. colour .. number .. '|r'
        end)
        for school, colour in pairs(schools) do
            span = span:gsub('%f[%a]' .. school .. '%f[%A]', '|cff' .. colour .. school .. '|r')
        end
        for stat, colour in pairs(stats) do
            local pattern = '%f[%a]['
                .. stat:sub(1, 1)
                .. stat:sub(1, 1):lower()
                .. ']'
                .. stat:sub(2)
                .. '%f[%A]'
            span = span:gsub(pattern, function(word)
                return '|cff' .. colour .. word .. '|r'
            end)
        end
        span = span:gsub('^Equip:', '|cffffd45cEquip:|r'):gsub('^Use:', '|cffffd45cUse:|r')
        span = span:gsub('\001(P+)\002', function(key)
            return pluralTokens[#key]
        end)
        return span
    end
    local output, start = {}, 1
    while true do
        local first, last = value:find('|c%x%x%x%x%x%x%x%x.-|r', start)
        if not first then
            output[#output + 1] = format(value:sub(start))
            break
        end
        output[#output + 1] = format(value:sub(start, first - 1))
        output[#output + 1] = value:sub(first, last)
        start = last + 1
    end
    return table.concat(output)
end
function Addon.ColourItemTooltip(tooltip)
    local name = tooltip:GetName()
    if type(name) ~= 'string' then
        return
    end
    local count = tooltip:NumLines()
    if type(count) ~= 'number' then
        return
    end
    for index = 1, count do
        local line = _G[name .. 'TextLeft' .. index]
        local value = line and line:GetText()
        if
            type(value) == 'string'
            and (not issecretvalue or not issecretvalue(value))
            and (value:find('^Equip:') or value:find('^Use:') or Addon.HasStatText(value))
        then
            line:SetText(Addon.EffectText(value))
        end
    end
end
