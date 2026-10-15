local ADDON, BAE = ...

-- Small ornaments between neighbouring buttons ------------------------------------
-- They use Blizzard's divider templates so the artwork matches the default UI:
--   "HorizontalDividerTemplate": a thin strip between buttons that sit side by side.
--   "VerticalDividerTemplate":   a thin strip between buttons that sit on top of each other.
-- Every pair of neighbours is checked on its own, so grids (several rows and columns)
-- get dividers in both directions.
local pools = {}
local TOLERANCE = 1

-- Nearest button to the right of `current` in the same row.
local function RightNeighbour(buttons, current)
    local best, bestGap
    for _, other in ipairs(buttons) do
        if other ~= current and math.abs(current:GetTop() - other:GetTop()) < TOLERANCE then
            local gap = other:GetLeft() - current:GetRight()
            if gap >= 0 and (not bestGap or gap < bestGap) then best, bestGap = other, gap end
        end
    end
    return best, bestGap
end

-- Nearest button above `current` in the same column.
local function UpperNeighbour(buttons, current)
    local best, bestGap
    for _, other in ipairs(buttons) do
        if other ~= current and math.abs(current:GetLeft() - other:GetLeft()) < TOLERANCE then
            local gap = other:GetBottom() - current:GetTop()
            if gap >= 0 and (not bestGap or gap < bestGap) then best, bestGap = other, gap end
        end
    end
    return best, bestGap
end

local function GetDivider(pool, bar, template, index)
    local key = template .. index
    local frame = pool.frames[key]
    if not frame then
        frame = CreateFrame("Frame", nil, bar, template)
        frame:SetFrameStrata("BACKGROUND")
        frame:SetFrameLevel(1)
        pool.frames[key] = frame
    end
    return frame
end

local function UpdateBar(n)
    local bar = BAE.GetBar(n)
    local pool = pools[n]
    if pool and pool.bar ~= bar then
        for _, frame in pairs(pool.frames) do frame:Hide() end
        pool = nil
    end
    if not pool then pool = { bar = bar, frames = {} }; pools[n] = pool end
    for _, frame in pairs(pool.frames) do frame:Hide() end

    local db = BAE.db
    if not bar or not BAE.BarActive(n) or not db.dividers or not db.border then return end

    local buttons = {}
    for i = 1, 12 do
        local button = BAE.GetButton(n, i)
        if button and BAE.Present(n, i, button) and button:GetLeft() then buttons[#buttons + 1] = button end
    end

    local shade = BAE.Shade()
    for index, button in ipairs(buttons) do
        local scale = button:GetEffectiveScale() / bar:GetEffectiveScale()

        local right, gap = RightNeighbour(buttons, button)
        if right then
            local frame = GetDivider(pool, bar, "HorizontalDividerTemplate", index)
            frame:SetScale(scale)
            frame:ClearAllPoints()
            -- Blizzard's strip is 12 units wide; centre it in the gap.
            frame:SetPoint("TOP", right, "TOP")
            frame:SetPoint("BOTTOM", right, "BOTTOM")
            frame:SetPoint("RIGHT", right, "LEFT", 6 - gap / 2, 0)
            frame:SetAlpha(db.alpha)
            if shade < 1 and BAE.TintFrame then BAE.TintFrame(frame, shade) end
            frame:Show()
        end

        local upper, rise = UpperNeighbour(buttons, button)
        if upper then
            local frame = GetDivider(pool, bar, "VerticalDividerTemplate", index)
            frame:SetScale(scale)
            frame:ClearAllPoints()
            -- Blizzard's strip is 12 units high; centre it in the gap above this button.
            frame:SetPoint("LEFT", button, "LEFT")
            frame:SetPoint("RIGHT", button, "RIGHT")
            frame:SetPoint("BOTTOM", button, "TOP", 0, rise / 2 - 6)
            frame:SetAlpha(db.alpha)
            if shade < 1 and BAE.TintFrame then BAE.TintFrame(frame, shade) end
            frame:Show()
        end
    end
end

local function Update()
    for n = 1, BAE.NUM_BARS do UpdateBar(n) end
end

local function Hide()
    for _, pool in pairs(pools) do
        for _, frame in pairs(pool.frames) do frame:Hide() end
    end
end

-- For /bae debug: how big are Blizzard's two divider templates?
local probes = {}
function BAE.DividerInfo()
    local lines = {}
    for _, template in ipairs({ "HorizontalDividerTemplate", "VerticalDividerTemplate" }) do
        local probe = probes[template]
        if not probe then
            probe = CreateFrame("Frame", nil, UIParent, template)
            probe:Hide()
            probes[template] = probe
        end
        local region = probe:GetRegions()
        lines[#lines + 1] = ("%s: %.0f x %.0f, art %s"):format(template, probe:GetWidth(), probe:GetHeight(),
            region and region.GetAtlas and tostring(region:GetAtlas()) or "?")
    end
    return lines
end

BAE.Register(Update, Hide)
