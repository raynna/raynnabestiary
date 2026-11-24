local _, Parent = ...
local A = Parent.Items
local frame, rows, entries, offset = nil, {}, {}, 0
local tab = 'uses'
local filterText, filterKind, knownOnly = '', 'All', false
local view, activeRecipe, navigation = 'item', nil, {}
local function pinNavigation()
    -- A shorter destination can move out from under the pointer on the same click.
    A.pinned = true
    A.manualOpen = false
    frame.pin:SetText('Unpin')
end
local function rememberView()
    navigation[#navigation + 1] = {
        item = A.currentItem,
        npc = A.currentNPC,
        link = A.currentLink,
        tab = tab,
        view = view,
        recipe = activeRecipe,
        entries = entries,
        query = filterText,
        kind = filterKind,
        known = knownOnly,
        offset = offset,
    }
    if #navigation > 40 then
        table.remove(navigation, 1)
    end
end
local function text(parent, size, x, y, width)
    local label = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    label:SetPoint('TOPLEFT', x, y)
    label:SetWidth(width)
    label:SetJustifyH('LEFT')
    label:SetTextColor(unpack(A.Theme.text))
    return label
end
local function button(parent, title, width, x, y, callback)
    local control = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    control:SetSize(width, 20)
    control:SetPoint('TOPLEFT', x, y)
    control:SetText(title)
    control:SetScript('OnClick', callback)
    if y == -125 then
        parent.navigationTabs = parent.navigationTabs or {}
        parent.navigationTabs[title:lower()] = control
        control.layoutX = x
    end
    return control
end
A.Button = button
A.Label = text

-- Mirror click precedence so the hint always describes the actual action.
function A.IsQuestEntry(entry)
    return entry
            and (entry.quest == true or (entry.kind or ''):find('Quest', 1, true) ~= nil or (
                entry.title or ''
            ):find('[Quest]', 1, true) ~= nil)
        or false
end
function A.EntryActionHint(entry)
    if not entry then
        return nil
    end
    if entry.url then
        return 'Select link >'
    end
    if entry.action == 'ingredients' and entry.recipe then
        return 'Ingredients >'
    end
    if entry.itemID then
        return 'View item >'
    end
    if entry.npcID then
        return 'View NPC >'
    end
    if entry.objectID then
        if #A.SourceLocations(entry.npcID, entry.objectID) > 0 then
            return 'Show on map >'
        end
    end
end
local function updateActionHint(row, hovering)
    local hint = hovering and A.EntryActionHint(row.entry)
    row.actionHint:SetText(hint or '')
    row.actionHint:SetShown(hint ~= nil and hint ~= false)
    row.actionHint:ClearAllPoints()
    row.actionHint:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -1, -18)
    row.title:SetWidth(
        row.entry and row.entry.sourceLayout and 139 or row.entry and row.entry.lootLayout and 194 or 278
    )
    row.detail:SetWidth(hint and 164 or 278)
end

local function rowTooltip(row)
    local entry = row.entry
    if not entry then
        return
    end
    local tip = A.tooltip
    tip:SetOwner(row, 'ANCHOR_LEFT')
    if entry.itemDetail then
        tip:AddLine(entry.title, 0.92, 0.86, 0.72, true)
    elseif entry.itemID and not entry.recipe then
        tip:SetHyperlink('item:' .. entry.itemID)
        A.ColourItemTooltip(tip)
        if entry.conditional then
            tip:AddLine('May require an active quest or other conditions.', 1, 0.82, 0.3, true)
        end
        if entry.referenceSource then
            tip:AddLine('Drop-rate source: ' .. entry.referenceSource, 0.7, 0.7, 0.65, true)
        end
    else
        tip:AddLine(A.ColourMissing(entry.title), 1, 0.82, 0)
        tip:AddLine(A.SourceDetail(entry), 0.9, 0.85, 0.7, true)
        if entry.recipe then
            tip:AddLine('Materials / Forever client data', 1, 0.82, 0)
            for _, reagent in ipairs(entry.recipe[6]) do
                tip:AddLine(A.Green(reagent[2]) .. ' x ' .. A.ItemInfo(reagent[1]), 0.9, 0.85, 0.7, true)
            end
            tip:AddLine(
                entry.action == 'ingredients' and 'Click to browse ingredients'
                    or 'Click to inspect the crafted item',
                0.6,
                0.8,
                1
            )
            if entry.recipe[9] then
                tip:AddLine(
                    'Yellow at ' .. entry.recipe[9] .. ' / grey at ' .. entry.recipe[10],
                    0.8,
                    0.75,
                    0.6,
                    true
                )
            end
            if entry.recipe[11] and #entry.recipe[11] > 0 then
                tip:AddLine('Required tools: ' .. table.concat(entry.recipe[11], ', '), 1, 0.7, 0.3, true)
            end
            tip:AddLine('Source: Forever client ' .. A.RecipeBuild, 0.8, 0.75, 0.6, true)
        end
        if entry.extra then
            tip:AddLine(A.ColourMissing(entry.extra), 0.8, 0.75, 0.6, true)
        end
        if entry.npcID or entry.objectID then
            local locations = A.SourceLocations(entry.npcID, entry.objectID)
            if #locations > 0 then
                tip:AddLine(
                    entry.npcID and 'Click: view NPC drops and map locations'
                        or 'Click: show spawn areas + nearest location',
                    0.45,
                    0.85,
                    1
                )
                local first = locations[1]
                local zone = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(first.area) or 'Location'
                tip:AddLine(zone .. string.format(' / %.1f, %.1f', first.x, first.y), 0.8, 0.75, 0.6)
                tip:AddLine(
                    #locations .. ' recorded locations; highlights are not live monster counts.',
                    0.8,
                    0.75,
                    0.6,
                    true
                )
            else
                tip:AddLine(A.ColourMissing('No recorded coordinates'), 0.8, 0.75, 0.6)
            end
        end
    end
    tip:SetFrameStrata('TOOLTIP')
    tip:SetFrameLevel(frame:GetFrameLevel() + 20)
    tip:Show()
end

local filterKinds =
    { 'All', 'Monster drop', 'Vendor', 'Quest', 'Crafting', 'World object', 'Container', 'Dungeon trash' }
function A.FilterEntries(list, query, kind, known)
    if (not query or query == '') and kind == 'All' and not known then return list end
    local result = {}
    query = (query or ''):lower()
    for _, entry in ipairs(list) do
        local category = A.SourceStyle(entry)
        local haystack = ((entry.title or '') .. ' ' .. (entry.detail or ''))
            :gsub('|c%x%x%x%x%x%x%x%x', '')
            :gsub('|r', '')
            :lower()
        if
            (query == '' or haystack:find(query, 1, true))
            and (kind == 'All' or category == kind)
            and (not known or type(entry.rate) == 'number')
        then
            result[#result + 1] = entry
        end
    end
    return result
end
function A.ClearListFilters()
    filterText, filterKind, knownOnly = '', 'All', false
    if frame and frame.listFilter then
        frame.listFilter:SetText('')
        frame.typeFilter:SetText('All sources')
        frame.knownFilter:SetText('Known rates: off')
    end
end

function A.FavouriteEntries()
    local result = {}
    for id, saved in pairs(A.db.favourites or {}) do
        if saved then
            result[#result + 1] =
                { itemID = id, title = A.ItemInfo(id), detail = 'Saved item / click to view' }
        end
    end
    table.sort(result, function(a, b)
        return a.title < b.title
    end)
    return result
end

local visibleLoot = {}
function A.IsVisibleLoot(id)
    return visibleLoot[id] == true
end
function A.Render()
    for id in pairs(visibleLoot) do visibleLoot[id] = nil end
    local visible = 7
    local headerShift = frame.headerShift or 0
    local activeTab = view == 'npc' and 'uses' or view == 'item' and tab or view
    for key, control in pairs(frame.navigationTabs or {}) do
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', control.layoutX, -125 - headerShift)
        control:SetNormalFontObject(key == activeTab and 'GameFontHighlightSmall' or 'GameFontNormalSmall')
    end
    local displayed = A.FilterEntries(entries, filterText, filterKind, knownOnly)
    local shown = math.max(1, math.min(visible, #displayed))
    local left, top = frame:GetLeft(), frame:GetTop()
    if frame:IsShown() and left and top then
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, top)
    end
    frame:SetHeight(266 + shown * 35 + headerShift)
    frame.scroll:SetHeight(shown * 35 - 8)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint('TOPLEFT', 329, -152 - headerShift)
    for _, pair in ipairs({
        { frame.count, 12, -(151 + shown * 35) },
        { frame.listFilter, 17, -(170 + shown * 35) },
        { frame.clearFilter, 235, -(168 + shown * 35) },
        { frame.typeFilter, 12, -(194 + shown * 35) },
        { frame.knownFilter, 176, -(194 + shown * 35) },
        { frame.source, 12, -(220 + shown * 35) },
        { frame.search, 17, -(239 + shown * 35) },
    }) do
        pair[1]:ClearAllPoints()
        pair[1]:SetPoint('TOPLEFT', pair[2], pair[3] - headerShift)
    end
    offset = math.max(0, math.min(offset, math.max(0, #displayed - visible)))
    for index, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 12, -150 - headerShift - (index - 1) * 35)
        local entry = displayed[index + offset]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            updateActionHint(row, row:IsMouseOver())
            row.title:SetHeight(entry.itemDetail and 32 or 14)
            row.title:SetWordWrap(entry.itemDetail == true)
            row.title:SetText(A.ColourMissing(entry.title))
            row.questBadge:SetShown(A.IsQuestEntry(entry))
            row.detail:SetText(
                entry.sourceLayout and A.ColourMissing(entry.location) or A.SourceDetail(entry)
            )
            row.sourceRate:SetShown(entry.sourceLayout == true or entry.lootLayout == true)
            row.sourceLevel:SetShown(entry.sourceLayout == true)
            if entry.sourceLayout or entry.lootLayout then
                local category, colour = A.SourceStyle(entry)
                local rate = type(entry.rate) == 'number'
                        and (A.Green(string.format('%.2f%%', entry.rate)) .. (entry.conditional and '*' or ''))
                    or (category == 'Vendor' and ('|cff' .. colour .. 'Vendor|r') or '|cffe68b8b? rate|r')
                row.sourceRate:SetText(rate)
                row.sourceLevel:SetText(entry.levelText == 'Lv ?' and '|cffe68b8bLv ?|r' or entry.levelText)
                local measured = row.title:GetStringWidth()
                local nameWidth = type(measured) == 'number' and math.min(139, measured) or 139
                row.sourceLevel:ClearAllPoints()
                row.sourceLevel:SetPoint('TOPLEFT', row, 'TOPLEFT', 35 + nameWidth, -3)
            end
            local icon = 'Interface\\Icons\\INV_Misc_Book_09'
            if entry.itemID then
                local name, itemIcon, kind, subtype = A.ItemInfo(entry.itemID)
                if entry.lootLayout then
                    visibleLoot[entry.itemID] = true
                    if name and name ~= 'Item ' .. entry.itemID then
                        row.title:SetText((entry.quest and '|cffffd45c[Quest]|r ' or '') .. name)
                    end
                    if not entry.quest and (subtype or kind) then row.detail:SetText(subtype or kind) end
                end
                icon = itemIcon
            end
            row.icon:SetTexture(icon)
            row.portrait:SetShown(entry.npcID ~= nil)
            A.SetBestiaryPortrait(row.portrait, entry.npcID, nil)
            row.icon:SetShown(entry.npcID == nil and not entry.itemDetail)
            row.title:SetTextColor(unpack(A.Theme.gold))
            if entry.itemID and ITEM_QUALITY_COLORS then
                local _, _, _, _, _, _, quality = A.ItemInfo(entry.itemID)
                local color = quality and A.Readable(quality) and ITEM_QUALITY_COLORS[quality]
                if color then
                    row.title:SetTextColor(color.r, color.g, color.b)
                end
            end
        end
    end
    frame.scroll:Update(#displayed, visible, offset, shown * 35 - 8)
    frame.count:SetText(
        #displayed > 0
                and ((offset + 1) .. '-' .. math.min(offset + visible, #displayed) .. ' / ' .. #displayed)
            or 'No matches'
    )
end

function A.SetSummary(summary)
    frame.summary:SetText(table.concat(summary, '\n'))
    frame.summary:SetHeight(0)
    local measured = frame.summary:GetStringHeight()
    local contentHeight = type(measured) == 'number' and measured or #summary * 14
    contentHeight = math.max(48, contentHeight + 4)
    local viewportHeight = math.min(140, contentHeight)
    frame.summary:SetHeight(contentHeight)
    frame.summaryContent:SetHeight(contentHeight)
    frame.summaryScroll:SetHeight(viewportHeight)
    frame.summaryBar:SetHeight(viewportHeight)
    frame.summaryContentHeight, frame.summaryViewportHeight = contentHeight, viewportHeight
    frame.summaryBar:Update(contentHeight, viewportHeight, 0, viewportHeight)
    frame.summaryScroll:SetVerticalScroll(0)
    frame.summaryBar:SetShown(contentHeight > viewportHeight)
    frame.summaryRange = math.max(0, contentHeight - viewportHeight)
    frame.headerShift = viewportHeight - 48
end

function A.NPCEntries(query, saved)
    local result = {}
    for _, npc in ipairs(Parent.FindNPCs(query or '', saved == 'recent' and 'recent' or nil)) do
        if saved ~= 'saved' or (A.db.favouriteNPCs or {})[npc.id] then
            result[#result + 1] =
                { npcID = npc.id, title = npc.name, detail = 'NPC / view drops and map locations' }
        end
    end
    return result
end
local function refreshNPC()
    local npc = A.currentNPC
    frame.name:SetText(npc.name)
    frame.name:SetTextColor(unpack(A.Theme.gold))
    frame.icon:Hide()
    frame.questBadge:Hide()
    frame.npcPortrait:Show()
    Parent.SetBestiaryPortrait(frame.npcPortrait, npc.npcID)
    frame.saveItem:SetText((A.db.favouriteNPCs or {})[npc.npcID] and 'Saved' or 'Save')
    local previous = navigation[#navigation]
    frame.breadcrumb:SetText(
        previous
                and ('< ' .. (previous.npc and previous.npc.name or A.ItemInfo(previous.link or previous.item)))
            or 'Monster reference'
    )
    frame.breadcrumbButton:SetShown(previous ~= nil)
    A.SetSummary({
        'Level ' .. Parent.LevelText(npc) .. ' / ' .. Parent.MonsterZones(npc.npcID),
        'Drop rates may differ on Forever.',
    })
    if view == 'npc' then
        entries = {}
        for id, drop in pairs(npc.drops or {}) do
            local record = A.BundledMetadata.Item[id]
            local name = drop.name or A.ItemNames[id] or (record and record.name) or A.LootReference.names[id]
            entries[#entries + 1] = {
                itemID = id,
                title = (drop.quest and '|cffffd45c[Quest]|r ' or '')
                    .. (name or drop.name or ('Item ' .. id)),
                detail = drop.quest and 'Quest item' or '',
                referenceSource = drop.source or 'Classic reference; unverified for Forever',
                rate = drop.rate,
                conditional = drop.conditional,
                quest = drop.quest,
                kind = 'Monster drop',
                lootLayout = true,
            }
        end
        table.sort(entries, function(a, b)
            if (a.rate or -1) ~= (b.rate or -1) then
                return (a.rate or -1) > (b.rate or -1)
            end
            return a.title < b.title
        end)
        if #entries == 0 then
            entries = npc.loadingDrops and {} or { { title = 'No recorded drops', detail = 'Coverage is incomplete for this NPC.' } }
        end
    elseif view == 'saved' then
        entries = A.NPCEntries('', 'saved')
    end
    frame.source:SetText(npc.loadingDrops and 'Loading drops...' or 'Reference loot / ? = unknown chance')
    A.Render()
end
function A.ShowNPC(npc, manual, keepPosition)
    if not npc or not npc.npcID then
        return
    end
    A.currentNPC, A.currentItem, A.currentLink = npc, nil, nil
    A.manualOpen = not not manual
    view, activeRecipe, offset = 'npc', nil, 0
    if not keepPosition then
        navigation = {}
    end
    A.returnToMonster, A.originName = nil, nil
    A.ClearListFilters()
    if not keepPosition and not manual then
        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x / scale + 8, y / scale + 8)
    end
    frame.pin:SetText(A.pinned and 'Unpin' or 'Pin')
    A.Refresh()
    frame:SetFrameLevel(
        math.max(frame:GetFrameLevel(), (GameTooltip and GameTooltip:GetFrameLevel() or 1) + 20)
    )
    frame:Show()
end
function A.NavigateNPC(entry)
    pinNavigation()
    rememberView()
    A.ShowNPC(Parent.ReferenceMonster(entry.npcID), true, true)
end

function A.Refresh()
    if not frame or (not A.currentItem and not A.currentNPC) then
        return
    end
    local npcMode = A.currentNPC ~= nil
    if frame.searchMode ~= npcMode then
        frame.searchMode = npcMode
        frame.search:SetText(npcMode and 'Search NPC name or ID' or 'Search item name or ID')
        frame.search:ClearFocus()
    end
    local tabs = frame.navigationTabs
    tabs.uses:SetText(npcMode and 'Drops' or 'Uses')
    tabs.sources:SetText(npcMode and 'Show on map' or 'Sources')
    local positions = npcMode and { 12, 71, 165, 219, 273 } or { 12, 77, 142, 207, 272 }
    local widths = npcMode and { 55, 90, 50, 50, 60 } or { 61, 61, 61, 61, 61 }
    for i, key in ipairs({ 'uses', 'sources', 'recent', 'saved', 'links' }) do
        tabs[key].layoutX = positions[i]
        tabs[key]:SetWidth(widths[i])
    end
    if npcMode then
        refreshNPC()
        return
    end
    frame.npcPortrait:Hide()
    frame.icon:Show()
    local id = A.currentItem
    local name, icon, _, _, _, _, quality = A.ItemInfo(A.currentLink or id)
    frame.name:SetText(name)
    frame.saveItem:SetText(A.db.favourites and A.db.favourites[id] and 'Saved' or 'Save')
    frame.breadcrumb:SetText(
        #navigation > 0
                and ('< ' .. (navigation[#navigation].npc and navigation[#navigation].npc.name or A.ItemInfo(
                    navigation[#navigation].link or navigation[#navigation].item
                )))
            or (A.originName and ('< ' .. A.originName) or 'Item reference')
    )
    frame.breadcrumbButton:SetShown(#navigation > 0 or A.returnToMonster ~= nil)
    local color = quality and A.Readable(quality) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        frame.name:SetTextColor(color.r, color.g, color.b)
    else
        frame.name:SetTextColor(unpack(A.Theme.gold))
    end
    frame.icon:SetTexture(icon)
    local _, _, itemKind = A.ItemInfo(A.currentLink or id)
    frame.questBadge:SetShown(itemKind == 'Quest' or #A.ItemQuests(id) > 0)
    local details = A.ItemDetailRows(A.currentLink or ('item:' .. id))
    local summary = {}
    if view == 'ingredients' then
        summary[1] = 'Ingredients for '
            .. activeRecipe[2]
            .. '. Click any material to browse its uses and sources.'
    else
        for _, entry in ipairs(details) do
            if entry.itemDetail then
                summary[#summary + 1] = entry.title
            end
        end
        if #summary == 0 then
            summary[1] = A.EffectText(A.Summary(id))
        end
    end
    A.SetSummary(summary)
    if view == 'saved' then
        entries = A.FavouriteEntries()
    end
    if view == 'item' then
        entries = tab == 'sources' and A.BuildSources(id) or A.BuildUses(id)
    end
    frame.source:SetText('|cff78df87Forever|r data / |cffe3b879Classic|r fallback; rates labelled per source')
    A.Render()
end

function A.ShowItem(id, manual, keepPosition)
    local link = type(id) == 'string' and id:find('item:', 1, true) and id or nil
    id = A.ItemID(id)
    if not id then
        return
    end
    A.currentNPC = nil
    A.currentItem, A.currentLink = id, link
    A.manualOpen = manual or false
    view, activeRecipe = 'item', nil
    A.ClearListFilters()
    if not keepPosition then
        navigation = {}
    end
    A.Remember(id)
    offset = 0
    frame.pin:SetText(A.pinned and 'Unpin' or 'Pin')
    local level = GameTooltip and GameTooltip:GetFrameLevel() or 1
    for _, compare in ipairs({ ShoppingTooltip1, ShoppingTooltip2 }) do
        level = math.max(level, compare:GetFrameLevel())
    end
    frame:SetFrameLevel(math.max(frame:GetFrameLevel(), level + 20))
    if not manual and not keepPosition then
        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x / scale + 8, y / scale + 8)
    end
    A.Refresh()
    frame:Show()
end

-- Use physical screen coordinates so differently scaled addons align correctly.
function A.PlaceBeside(source)
    if not source or not source.GetEffectiveScale then
        return
    end
    local sourceScale, scale = source:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, right, top = source:GetLeft(), source:GetRight(), source:GetTop()
    if not left or not right or not top then
        return
    end
    left, right, top = left * sourceScale, right * sourceScale, top * sourceScale
    local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local width, gap = frame:GetWidth() * scale, 8
    local x = right + gap
    if x + width > screenWidth then
        x = left - gap - width
    end
    x = math.max(0, math.min(x, screenWidth - width))
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x / scale, top / scale)
    -- Both reference windows use TOOLTIP strata. Explicitly raise the opened
    -- details above their caller, even when screen clamping forces an overlap.
    frame:SetFrameStrata('TOOLTIP')
    frame:SetFrameLevel(math.max(frame:GetFrameLevel(), source:GetFrameLevel() + 30))
end

function A.CaptureItemView()
    local item, link, oldTab, oldView, recipe = A.currentItem, A.currentLink, tab, view, activeRecipe
    local oldEntries, oldOffset, oldNavigation = entries, offset, navigation
    local query, kind, known = filterText, filterKind, knownOnly
    return function()
        A.currentItem, A.currentLink, tab, view, activeRecipe = item, link, oldTab, oldView, recipe
        entries, navigation = oldEntries, oldNavigation
        filterText, filterKind, knownOnly = query, kind, known
        frame.listFilter:SetText(query)
        frame.typeFilter:SetText(kind == 'All' and 'All sources' or kind)
        frame.knownFilter:SetText(known and 'Known rates: on' or 'Known rates: off')
        offset = oldOffset
        A.Refresh()
        frame:Show()
    end
end

function A.NavigateItem(id)
    pinNavigation()
    rememberView()
    A.ShowItem(id, A.manualOpen, true)
end

function A.ShowIngredients(recipe)
    pinNavigation()
    if #recipe[6] == 1 then
        A.NavigateItem(recipe[6][1][1])
        return
    end
    rememberView()
    view, activeRecipe = 'ingredients', recipe
    entries, offset = A.IngredientRows(recipe), 0
    A.Refresh()
end

function A.GoBack()
    local previous = table.remove(navigation)
    if not previous then
        if A.returnToMonster then
            local restore = A.returnToMonster
            A.returnToMonster, A.originName = nil, nil
            frame:Hide()
            restore()
        end
        return
    end
    pinNavigation()
    A.currentNPC = previous.npc
    A.currentItem, A.currentLink = previous.item, previous.link
    tab, view, activeRecipe = previous.tab, previous.view, previous.recipe
    entries = previous.entries
    filterText, filterKind, knownOnly = previous.query or '', previous.kind or 'All', previous.known or false
    frame.listFilter:SetText(previous.query or '')
    frame.typeFilter:SetText(filterKind == 'All' and 'All sources' or filterKind)
    frame.knownFilter:SetText(knownOnly and 'Known rates: on' or 'Known rates: off')
    offset = previous.offset
    A.Refresh()
end

function A.SetScale(value)
    local left, top, previousScale
    if frame:IsShown() then
        left, top, previousScale = frame:GetLeft(), frame:GetTop(), frame:GetEffectiveScale()
    end
    A.db.scale = math.max(0.4, math.min(1.8, value))
    frame:SetScale(A.db.scale)
    if left and top then
        local ratio = previousScale / frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left * ratio, top * ratio)
        if A.pinned then
            A.db.position = { 'TOPLEFT', 'BOTTOMLEFT', left * ratio, top * ratio }
        end
    end
end

function A.CreateUI()
    frame = CreateFrame('Frame', 'RaynnaBestiaryItemsWindow', UIParent, 'BackdropTemplate')
    A.frame = frame
    frame:SetSize(350, 462)
    frame:SetPoint('CENTER')
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata('TOOLTIP')
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', function()
        A.dragging = true
        frame:StartMoving()
    end)
    frame:SetScript('OnDragStop', function()
        A.dragging = false
        frame:StopMovingOrSizing()
        local point, _, relative, x, y = frame:GetPoint()
        A.db.position = { point, relative, x, y }
    end)
    local position = A.db.position
    if position then
        frame:ClearAllPoints()
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    end
    A.SkinPanel(frame, true)
    text(frame, 12, 12, -9, 200):SetText("RAYNNA'S BESTIARY")
    button(frame, 'Back', 43, 220, -5, A.GoBack)
    frame.pin = button(frame, 'Pin', 45, 267, -5, function()
        A.pinned = not A.pinned
        A.manualOpen = false
        frame.pin:SetText(A.pinned and 'Unpin' or 'Pin')
    end)
    button(frame, 'x', 20, 317, -5, function()
        A.pinned = false
        A.manualOpen = false
        A.dismissed = true
        frame:Hide()
    end)
    frame.icon = frame:CreateTexture(nil, 'ARTWORK')
    frame.icon:SetSize(30, 30)
    frame.icon:SetPoint('TOPLEFT', 12, -34)
    frame.questBadge = frame:CreateTexture(nil, 'OVERLAY')
    frame.questBadge:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
    frame.questBadge:SetSize(14, 14)
    frame.questBadge:SetPoint('TOPLEFT', 31, -51)
    frame.questBadge:Hide()
    frame.npcPortrait = CreateFrame('Frame', nil, frame)
    frame.npcPortrait:SetPoint('TOPLEFT', 12, -34)
    frame.npcPortrait:SetSize(30, 30)
    frame.npcPortrait:Hide()
    frame.name = text(frame, 12, 49, -35, 284)
    frame.headerItem = CreateFrame('Button', nil, frame)
    frame.headerItem:SetPoint('TOPLEFT', 12, -32)
    frame.headerItem:SetSize(321, 32)
    frame.headerItem:SetScript('OnEnter', function(self)
        if not A.currentItem then
            return
        end
        A.tooltip:SetOwner(self, 'ANCHOR_LEFT')
        A.tooltip:SetHyperlink(A.currentLink or ('item:' .. A.currentItem))
        A.ColourItemTooltip(A.tooltip)
        A.tooltip:SetFrameStrata('TOOLTIP')
        A.tooltip:SetFrameLevel(frame:GetFrameLevel() + 20)
        A.tooltip:Show()
    end)
    frame.headerItem:SetScript('OnLeave', function()
        A.tooltip:Hide()
    end)
    frame.breadcrumb = text(frame, 9, 49, -53, 226)
    frame.breadcrumbButton = CreateFrame('Button', nil, frame)
    frame.breadcrumbButton:SetPoint('TOPLEFT', 49, -51)
    frame.breadcrumbButton:SetSize(226, 18)
    frame.breadcrumbButton:SetScript('OnClick', A.GoBack)

    frame.saveItem = button(frame, 'Save', 49, 284, -51, function()
        if A.currentNPC then
            A.db.favouriteNPCs = A.db.favouriteNPCs or {}
            local id = A.currentNPC.npcID
            A.db.favouriteNPCs[id] = not A.db.favouriteNPCs[id] or nil
            A.Refresh()
            return
        end
        A.db.favourites = A.db.favourites or {}
        A.db.favourites[A.currentItem] = not A.db.favourites[A.currentItem] or nil
        A.Refresh()
    end)
    frame.breadcrumb:SetTextColor(unpack(A.Theme.muted))
    frame.summaryScroll = CreateFrame('ScrollFrame', nil, frame)
    frame.summaryScroll:SetPoint('TOPLEFT', 12, -72)
    frame.summaryScroll:SetSize(309, 48)
    frame.summaryContent = CreateFrame('Frame', nil, frame.summaryScroll)
    frame.summaryContent:SetSize(309, 48)
    frame.summaryScroll:SetScrollChild(frame.summaryContent)
    frame.summary = text(frame.summaryContent, 11, 0, 0, 309)
    frame.summary:SetJustifyV('TOP')
    frame.summary:SetWordWrap(true)
    frame.summaryBar = Parent.Scrollbar(frame, function(value)
        frame.summaryScroll:SetVerticalScroll(value)
        frame.summaryBar:Update(
            frame.summaryContentHeight or 48,
            frame.summaryViewportHeight or 48,
            value,
            frame.summaryViewportHeight or 48
        )
    end)
    frame.summaryBar:SetPoint('TOPLEFT', 329, -72)
    frame.summaryScroll:EnableMouseWheel(true)
    frame.summaryScroll:SetScript('OnMouseWheel', function(_, delta)
        if IsControlKeyDown() then
            A.SetScale(A.db.scale + delta * 0.05)
            return
        end
        local value = frame.summaryBar.offset or 0
        value = math.max(0, math.min(frame.summaryRange or 0, value - delta * 24))
        frame.summaryScroll:SetVerticalScroll(value)
        frame.summaryBar:Update(
            frame.summaryContentHeight or 48,
            frame.summaryViewportHeight or 48,
            value,
            frame.summaryViewportHeight or 48
        )
    end)
    button(frame, 'Uses', 61, 12, -125, function()
        A.ClearListFilters()
        view = A.currentNPC and 'npc' or 'item'
        tab = 'uses'
        offset = 0
        A.Refresh()
    end)
    button(frame, 'Sources', 61, 77, -125, function()
        if A.currentNPC then
            local npc = A.currentNPC
            local ok, message = A.ShowSourceLocation({
                npcID = npc.npcID,
                title = npc.name,
                levelText = 'Lv ' .. Parent.LevelText(npc),
            })
            if ok then
                frame:Hide()
            else
                frame.source:SetText(message)
            end
            return
        end
        A.ClearListFilters()
        view = 'item'
        tab = 'sources'
        offset = 0
        A.Refresh()
    end)
    button(frame, 'Recent', 61, 142, -125, function()
        A.ClearListFilters()
        view = 'recent'
        entries = A.currentNPC and A.NPCEntries('', 'recent') or A.Search('')
        offset = 0
        A.Render()
    end)
    button(frame, 'Links', 61, 272, -125, function()
        A.ClearListFilters()
        view = 'links'
        entries = {
            {
                title = 'Wowhead Forever / current entry',
                detail = 'Select link, then press Ctrl+C',
                url = A.currentNPC and ('https://www.wowhead.com/forever/npc=' .. A.currentNPC.npcID)
                    or ('https://www.wowhead.com/forever/item=' .. (A.currentItem or 3371)),
            },
            {
                title = 'Forever client crafting data',
                detail = 'Client build ' .. A.RecipeBuild,
                url = 'https://github.com/masterred92/DwarfExplorersBible/tree/' .. A.RecipeRevision,
            },
            {
                title = 'Quest and vendor metadata / QuestieDB',
                detail = 'Bundled '
                    .. A.BundledMetadata.sourceVersion
                    .. '; newer installed data when compatible',
                url = 'https://github.com/Questie/QuestieDB',
            },
            {
                title = 'Classic drop reference / cMaNGOS',
                detail = 'Classic 1.12; not verified Forever probabilities',
                url = 'https://github.com/cmangos/classic-db',
            },
        }
        offset = 0
        A.Render()
    end)
    button(frame, 'Saved', 61, 207, -125, function()
        A.ClearListFilters()
        view = 'saved'
        entries = A.currentNPC and A.NPCEntries('', 'saved') or A.FavouriteEntries()
        offset = 0
        A.Render()
    end)
    frame.listFilter = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
    frame.listFilter:SetPoint('TOPLEFT', 17, -151)
    frame.listFilter:SetSize(211, 20)
    frame.listFilter:SetAutoFocus(false)
    frame.listFilter:SetScript('OnTextChanged', function(self)
        filterText = self:GetText() or ''
        offset = 0
        if entries then
            A.Render()
        end
    end)
    frame.listFilter:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
    end)
    frame.listFilter:SetScript('OnEnterPressed', function(self)
        self:ClearFocus()
    end)
    frame.clearFilter = button(frame, 'Clear filters', 98, 235, -149, function()
        A.ClearListFilters()
        offset = 0
        A.Render()
    end)
    frame.typeFilter = button(frame, 'All sources', 157, 12, -174, function()
        local nextIndex = 1
        for i, kind in ipairs(filterKinds) do
            if kind == filterKind then
                nextIndex = i % #filterKinds + 1
                break
            end
        end
        filterKind = filterKinds[nextIndex]
        frame.typeFilter:SetText(filterKind == 'All' and 'All sources' or filterKind)
        offset = 0
        A.Render()
    end)
    frame.knownFilter = button(frame, 'Known rates: off', 157, 176, -174, function()
        knownOnly = not knownOnly
        frame.knownFilter:SetText(knownOnly and 'Known rates: on' or 'Known rates: off')
        offset = 0
        A.Render()
    end)
    frame.listFilter:SetScript('OnEnter', function(self)
        A.tooltip:SetOwner(self, 'ANCHOR_RIGHT')
        A.tooltip:SetText('Filter this list by name or location')
        A.tooltip:Show()
    end)
    frame.listFilter:SetScript('OnLeave', function()
        A.tooltip:Hide()
    end)
    for index = 1, 7 do
        local row = CreateFrame('Button', nil, frame)
        row:SetPoint('TOPLEFT', 12, -150 - (index - 1) * 35)
        row:SetSize(309, 34)
        row:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight', 'ADD')
        local stripe = row:CreateTexture(nil, 'BACKGROUND')
        stripe:SetAllPoints(row)
        stripe:SetColorTexture(1, 0.86, 0.6, index % 2 == 0 and 0.035 or 0)

        row.icon = row:CreateTexture(nil, 'ARTWORK')
        row.icon:SetPoint('TOPLEFT', 0, -4)
        row.icon:SetSize(24, 24)
        row.questBadge = row:CreateTexture(nil, 'OVERLAY')
        row.questBadge:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
        row.questBadge:SetSize(12, 12)
        row.questBadge:SetPoint('TOPLEFT', 14, -17)
        row.questBadge:Hide()
        row.portrait = CreateFrame('Frame', nil, row)
        row.portrait:SetPoint('TOPLEFT', 0, -4)
        row.portrait:SetSize(24, 24)
        row.title = text(row, 11, 30, -3, 278)
        row.title:SetHeight(14)
        row.detail = text(row, 10, 30, -18, 278)
        row.detail:SetHeight(13)
        row.detail:SetWidth(164)
        row.detail:SetTextColor(unpack(A.Theme.muted))
        row.sourceRate = text(row, 10, 226, -3, 66)
        row.sourceRate:SetJustifyH('RIGHT')
        row.sourceLevel = text(row, 10, 174, -3, 48)
        row.sourceLevel:SetJustifyH('LEFT')
        row.actionHint = text(row, 10, 196, -18, 112)
        row.actionHint:SetJustifyH('RIGHT')
        row.actionHint:SetTextColor(0.55, 0.88, 1)
        row.actionHint:Hide()
        row:SetScript('OnEnter', function(self)
            updateActionHint(self, true)
            rowTooltip(self)
        end)
        row:SetScript('OnLeave', function()
            updateActionHint(row, false)
            A.tooltip:Hide()
        end)
        row:SetScript('OnClick', function()
            A.tooltip:Hide()
            if row.entry and row.entry.url then
                frame.search:SetText(row.entry.url)
                frame.search:SetFocus()
                frame.search:HighlightText()
                frame.source:SetText('|cff78df87Press Ctrl+C to copy the selected link.|r')
            elseif row.entry and row.entry.action == 'ingredients' then
                A.ShowIngredients(row.entry.recipe)
            elseif row.entry and row.entry.itemID then
                A.NavigateItem(row.entry.itemID)
            elseif row.entry and row.entry.npcID then
                A.NavigateNPC(row.entry)
            elseif row.entry and row.entry.objectID then
                local ok, message = A.ShowSourceLocation(row.entry)
                frame.source:SetText((ok and '|cff78df87' or '|cffff7070') .. message .. '|r')
                if ok then
                    frame:Hide()
                end
            end
        end)
        rows[index] = row
    end
    frame.scroll = Parent.Scrollbar(frame, function(value)
        if offset ~= value then
            offset = value
            A.Render()
        end
    end)
    frame.scroll:SetPoint('TOPLEFT', 329, -152)
    frame:EnableMouseWheel(true)
    frame:SetScript('OnMouseWheel', function(_, delta)
        if IsControlKeyDown() then
            A.SetScale(A.db.scale + delta * 0.05)
        else
            offset = offset - delta
            A.Render()
        end
    end)
    frame.count = text(frame, 10, 12, -399, 120)
    frame.source = text(frame, 10, 12, -416, 325)
    frame.search = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
    frame.search:SetSize(320, 20)
    frame.search:SetPoint('TOPLEFT', 17, -435)
    frame.search:SetAutoFocus(false)
    frame.search:SetText('Search item name or ID')
    frame.search:SetScript('OnEnterPressed', function(self)
        A.ClearListFilters()
        view = 'search'
        entries = A.currentNPC and A.NPCEntries(self:GetText()) or A.Search(self:GetText())
        offset = 0
        A.Render()
        self:ClearFocus()
    end)
    frame.search:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
    end)
    A.tooltip =
        CreateFrame('GameTooltip', 'RaynnaBestiaryItemsDetailTooltip', UIParent, 'GameTooltipTemplate')
    frame:SetScript('OnHide', function()
        A.pinned, A.manualOpen = false, false
        frame.pin:SetText('Pin')
        if Parent.ResetBestiaryHoverSelection then
            Parent.ResetBestiaryHoverSelection()
        end
        A.tooltip:Hide()
    end)
    A.SetScale(A.db.scale)
    frame:Hide()
end
