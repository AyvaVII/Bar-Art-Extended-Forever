local ADDON, BAE = ...

-- Blizzard default UI only ------------------------------------------------------------
-- 1. Buttons of bars 2-8 get the button frame and icon layout of the main bar.
-- 2. The border of bar 1 can be hidden.
local savedRegions = {}      -- button -> { region -> original state }
local KEYS = { "NormalTexture", "PushedTexture", "icon", "IconMask" }

local function Save(region)
    local state = {
        width = region:GetWidth(), height = region:GetHeight(),
        atlas = region.GetAtlas and region:GetAtlas(),
        texture = region.GetTexture and region:GetTexture(),
        coords = region.GetTexCoord and { region:GetTexCoord() },
        alpha = region.GetAlpha and region:GetAlpha(),
        points = {},
    }
    if region.GetDrawLayer then state.layer, state.sublevel = region:GetDrawLayer() end
    for i = 1, region:GetNumPoints() do state.points[i] = { region:GetPoint(i) } end
    return state
end

local function Load(region, state)
    if state.atlas then region:SetAtlas(state.atlas)
    elseif state.texture then region:SetTexture(state.texture) end
    if state.coords then region:SetTexCoord(unpack(state.coords)) end
    if state.layer then region:SetDrawLayer(state.layer, state.sublevel) end
    if state.alpha then region:SetAlpha(state.alpha) end
    region:ClearAllPoints()
    region:SetSize(state.width, state.height)
    for _, point in ipairs(state.points) do region:SetPoint(unpack(point)) end
end

local function RestoreButton(button)
    local saved = savedRegions[button]
    if not saved then return end
    for region, state in pairs(saved) do Load(region, state) end
    savedRegions[button] = nil
    -- Let Blizzard rebuild its own look for the current bar settings.
    if button.UpdateButtonArt then button:UpdateButtonArt() end
end

local function StyleButton(n, button)
    local native = BAE.NativeButton()
    if not BAE.BarActive(n) or not native or not native.NormalTexture or not button.NormalTexture then
        RestoreButton(button)
        return
    end
    local saved = savedRegions[button]
    if not saved then saved = {}; savedRegions[button] = saved end
    local factor = button:GetWidth() / math.max(1, native:GetWidth())
    for _, key in ipairs(KEYS) do
        local from, to = native[key], button[key]
        if from and to then
            if not saved[to] then saved[to] = Save(to) end
            if key == "NormalTexture" or key == "PushedTexture" then
                local atlas = from:GetAtlas()
                if atlas then to:SetAtlas(atlas) else to:SetTexture(from:GetTexture()) end
                to:SetTexCoord(from:GetTexCoord())
                to:SetDrawLayer(from:GetDrawLayer())
                to:SetAlpha((saved[to].alpha or 1) * BAE.db.alpha)
            end
            BAE.MirrorRegion(from, to, native, button, factor)
        end
    end
end

-- Border of bar 1: faded out instead of hidden, so its geometry stays available.
local function Fade(region, hide)
    if not region or not region.SetAlpha then return end
    local saved = BAE.savedAlpha
    if hide then
        if saved[region] == nil then saved[region] = region:GetAlpha() end
        region:SetAlpha(0)
    elseif saved[region] ~= nil then
        region:SetAlpha(saved[region])
        saved[region] = nil
    end
end

local function MainBorder()
    local main = MainActionBar
    if not main then return end
    local hide = BAE.db.enabled and BAE.db.mainBorder == false
    Fade(main.BorderArt, hide)
    for _, pool in pairs({ main.HorizontalDividersPool, main.VerticalDividersPool }) do
        if pool.EnumerateActive then
            for divider in pool:EnumerateActive() do Fade(divider, hide) end
        end
    end
    if not hide then
        for region, alpha in pairs(BAE.savedAlpha) do region:SetAlpha(alpha) end
        wipe(BAE.savedAlpha)
    end
end

local function Update()
    for n = BAE.BT4_SLOTS + 2, BAE.NUM_BARS do          -- Blizzard bars 2-8
        for i = 1, 12 do
            local button = BAE.GetButton(n, i)
            if button then StyleButton(n, button) end
        end
    end
    MainBorder()
end

local function Hide()
    for button in pairs(savedRegions) do RestoreButton(button) end
    for region, alpha in pairs(BAE.savedAlpha) do region:SetAlpha(alpha) end
    wipe(BAE.savedAlpha)
end

BAE.Register(Update, Hide)
