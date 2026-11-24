-- Peer discovery only: no website requests, downloads or execution of peer content.
local _, A = ...
local PREFIX = 'RaynnaBVer'
local VERSION = '2.4.7'
local events = CreateFrame('Frame')
local sent, shown = {}, {}
local pending, popup, ready
local channels = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local function parts(version)
    if type(version) ~= 'string' or #version > 16 then
        return
    end
    local a, b, c = version:match('^(%d+)%.(%d+)%.(%d+)$')
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if a and a <= 9999 and b <= 9999 and c <= 9999 then
        return { a, b, c }
    end
end
local function newer(left, right)
    local a, b = parts(left), parts(right)
    if not a or not b then
        return false
    end
    for i = 1, 3 do
        if a[i] ~= b[i] then
            return a[i] > b[i]
        end
    end
    return false
end
A.IsNewerVersion = newer
local function showPending()
    if not pending or not A.db or (InCombatLockdown and InCombatLockdown()) then
        return
    end
    if shown[pending] or A.db.ignoredUpdateVersion == pending then
        pending = nil
        return
    end
    if not popup then
        popup = CreateFrame('Frame', 'RaynnaBestiaryUpdateNotice', UIParent, 'BackdropTemplate')
        A.updateNotice = popup
        popup:SetSize(390, 225)
        popup:SetPoint('CENTER')
        popup:SetClampedToScreen(true)
        popup:SetFrameStrata('DIALOG')
        popup:EnableMouse(true)
        A.SkinPanel(popup, true)
        local function label(y, width)
            local t = popup:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            t:SetPoint('TOPLEFT', 14, y)
            t:SetWidth(width)
            t:SetJustifyH('LEFT')
            return t
        end
        label(-10, 360):SetText("Raynna's Bestiary — update available")
        popup.message = label(-40, 360)
        label(-87, 360):SetText(
            'A Bestiary user in your guild or group has a newer version.\nUpdate through CurseForge or your usual download source.'
        )
        local url = CreateFrame('EditBox', nil, popup, 'InputBoxTemplate')
        url:SetPoint('TOPLEFT', 18, -132)
        url:SetSize(350, 22)
        url:SetAutoFocus(false)
        url:SetText('https://www.curseforge.com/wow/addons/raynnas-beastiary')
        url:SetScript('OnEscapePressed', function(self)
            self:ClearFocus()
        end)
        -- URL is configured locally, never supplied by another player.
        popup.link = url
        local function button(text, x, width, action)
            local b = CreateFrame('Button', nil, popup, 'UIPanelButtonTemplate')
            b:SetPoint('BOTTOMLEFT', x, 14)
            b:SetSize(width, 24)
            b:SetText(text)
            b:SetScript('OnClick', action)
            return b
        end
        popup.dismiss = button('Dismiss', 14, 105, function()
            popup:Hide()
        end)
        popup.ignore = button('Ignore this version', 130, 245, function()
            A.db.ignoredUpdateVersion = popup.version
            popup:Hide()
        end)
    end
    popup.version = pending
    popup.message:SetText(
        'Installed: ' .. VERSION .. '\nNewer version detected: |cff78df87' .. pending .. '|r'
    )
    shown[pending] = true
    pending = nil
    popup:Show()
end
local function transmit(channel, request)
    if not channels[channel] then
        return
    end
    local now = GetTime()
    local key = channel .. (request and ':query' or ':reply')
    if sent[key] and now - sent[key] < 60 then
        return
    end
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not send then
        return
    end
    sent[key] = now
    pcall(send, PREFIX, (request and 'Q:' or 'V:') .. VERSION, channel)
end
local function announce()
    if IsInGuild and IsInGuild() then
        transmit('GUILD', true)
    end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        transmit('INSTANCE_CHAT', true)
    elseif IsInRaid and IsInRaid() then
        transmit('RAID', true)
    elseif IsInGroup and IsInGroup() then
        transmit('PARTY', true)
    end
end
local function receive(prefix, message, channel)
    if prefix ~= PREFIX or not channels[channel] or type(message) ~= 'string' or #message > 18 then
        return
    end
    local kind, version = message:match('^([QV]):(.+)$')
    if not parts(version) then
        return
    end
    if kind == 'Q' then
        transmit(channel, false)
    end
    if newer(version, VERSION) and not shown[version] and A.db.ignoredUpdateVersion ~= version then
        if not pending or newer(version, pending) then
            pending = version
        end
        showPending()
    end
end
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event, ...)
    if event == 'PLAYER_LOGIN' then
        local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
        if not register then
            return
        end
        local ok, result = pcall(register, PREFIX)
        if not ok or result == false then
            return
        end
        ready = true
        events:RegisterEvent('CHAT_MSG_ADDON')
        events:RegisterEvent('GROUP_ROSTER_UPDATE')
        events:RegisterEvent('PLAYER_GUILD_UPDATE')
        events:RegisterEvent('PLAYER_REGEN_ENABLED')
        announce()
    elseif ready and event == 'CHAT_MSG_ADDON' then
        receive(...)
    elseif ready and event == 'PLAYER_REGEN_ENABLED' then
        showPending()
    elseif ready then
        announce()
    end
end)
A.versionEvents = events
