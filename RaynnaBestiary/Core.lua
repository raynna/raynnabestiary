-- Standalone lifecycle; no tracking events or required addon dependency.
local _, Addon = ...
RaynnaBestiaryAPI = Addon
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
function Addon.LevelText(row)
    if not row.minLevel then
        return '?'
    end
    if not row.maxLevel or row.minLevel == row.maxLevel then
        return tostring(row.minLevel)
    end
    return row.minLevel .. '-' .. row.maxLevel
end
function Addon.HideDrops()
    local frame = _G.RaynnaTrackerDrops
    if frame then
        frame:Hide()
    end
end
function Addon.OpenSettings()
    RaynnaModsSettingsRegistry:Open('bestiary')
end
local events = CreateFrame('Frame')
Addon.events = events
local needsMigration
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' and name == 'RaynnaBestiary' then
        needsMigration = type(RaynnaBestiaryDB) ~= 'table'
        RaynnaBestiaryDB = RaynnaBestiaryDB or {}
        Addon.db = RaynnaBestiaryDB
    elseif event == 'PLAYER_LOGIN' then
        -- All enabled addons' saved variables are available by this event.
        local old = RaynnaTrackerDB or ForeverHuntDB
        if needsMigration and type(old) == 'table' then
            for _, key in ipairs({ 'bestiary', 'appearance', 'recentPortraitNPCs' }) do
                Addon.db[key] = copy(old[key])
            end
        end
        Addon.db.bestiary = Addon.db.bestiary or {}
        Addon.db.appearance = Addon.db.appearance or {}
        Addon.PreloadTrackerPortraits()
        Addon.BuildBestiary()
        Addon.BuildSettings()
    end
end)
