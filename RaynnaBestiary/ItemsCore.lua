local _, Addon = ...
local A = Addon.Items
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local result = {}
    for key, entry in pairs(value) do
        result[key] = copy(entry)
    end
    return result
end
function Addon.InitializeItems()
    if not Addon.db.items then
        Addon.db.items = type(RaynnaCodexDB) == 'table' and copy(RaynnaCodexDB) or {}
    end
    A.db = Addon.db.items
    A.db.scale = A.db.scale or Addon.db.bestiary.scale or 1
    A.db.history = A.db.history or {}
    A.db.appearance = Addon.db.appearance
    A.CreateUI()
    local elapsed = 0
    A.frame:SetScript('OnUpdate', function(_, delta)
        local npc = A.currentNPC
        if npc and npc.loadingDrops and Addon.AdvanceHoverLoot(npc) then npc.lootDirty = true end
        elapsed = elapsed + delta
        if elapsed < 0.08 then
            return
        end
        elapsed = 0
        if npc and npc.lootDirty then
            npc.lootDirty = nil
            A.Refresh()
        end
        if
            not A.pinned
            and not A.manualOpen
            and not A.dragging
            and not A.frame.scroll.dragging
            and not A.frame.summaryBar.dragging
            and not IsAltKeyDown()
            and not A.frame:IsMouseOver()
            and not A.tooltip:IsMouseOver()
        then
            A.frame:Hide()
        end
    end)
    A.frame:RegisterEvent('GET_ITEM_INFO_RECEIVED')
    A.frame:SetScript('OnEvent', function(_, _, id, success)
        if success and A.frame:IsShown() then
            if A.currentNPC then
                if A.IsVisibleLoot(id) then A.Render() end
            elseif id == A.currentItem then
                A.Refresh()
            else
                A.Render()
            end
        end
    end)
    RaynnaCodexAPI = {
        OpenItem = function(id, source)
            return Addon.OpenItem(id, true, source)
        end,
    }
    SLASH_RAYNNACODEX1 = '/rc'
    SlashCmdList.RAYNNACODEX = function(message)
        if message == 'settings' then
            Addon.OpenSettings()
        elseif message == 'hide' then
            A.frame:Hide()
        else
            Addon.OpenItem(A.ItemID(message) or A.db.lastItem or 3371, true)
        end
    end
end
function Addon.OpenItem(id, manual, source)
    local itemLink = type(id) == 'string' and id:find('item:', 1, true) and id or nil
    id = A.ItemID(id)
    if not id or not A.frame then
        return false
    end
    if not manual and A.pinned and A.frame:IsShown() then
        return true
    end
    if A.currentNPC and (source == A.frame or source == _G.RaynnaBestiaryFrame) then
        A.NavigateItem(itemLink or id)
        return true
    end
    A.returnToMonster, A.originName = nil, nil
    if source and source == _G.RaynnaBestiaryFrame then
        A.originName, A.returnToMonster = Addon.CaptureMonsterView()
    end
    A.dismissed = false
    A.ShowItem(itemLink or id, manual)
    if source then
        if A.returnToMonster then
            local ratio = source:GetEffectiveScale() / A.frame:GetEffectiveScale()
            A.frame:ClearAllPoints()
            A.frame:SetPoint(
                'TOPLEFT',
                UIParent,
                'BOTTOMLEFT',
                source:GetLeft() * ratio,
                source:GetTop() * ratio
            )
            source:Hide()
        else
            A.PlaceBeside(source)
        end
    end
    return true
end
