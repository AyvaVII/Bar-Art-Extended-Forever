local ADDON, BAE = ...

-- Bar access for both Bartender4 and Blizzard's default action bars -------------------
local PREFIX = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}

BAE.PREFIX = PREFIX
-- Blizzard's own bar frames, used before falling back to the buttons' parent.
local FRAMES = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
}

local installed = false
if C_AddOns and C_AddOns.IsAddOnLoaded then
    installed = C_AddOns.IsAddOnLoaded("Bartender4") and true or false
elseif IsAddOnLoaded then
    installed = IsAddOnLoaded("Bartender4") and true or false
end
BAE.BT4Installed = installed

-- Slots 1-15 are Bartender4's bars 1-15 (its bars 13-15 are Blizzard's action bars 6-8),
-- slots 16-23 are Blizzard's bars 1-8.
-- Both kinds are decorated at the same time: a Blizzard bar that Bartender4 has not
-- taken over stays visible and gets the artwork too.
BAE.BT4_SLOTS = 15
BAE.NUM_BARS = BAE.BT4_SLOTS + 8

local function Kind(n)
    if n <= BAE.BT4_SLOTS then return "bt4", n end
    return "blizzard", n - BAE.BT4_SLOTS
end

function BAE.SlotName(n)
    local kind, id = Kind(n)
    return (kind == "bt4" and "Bartender4 bar " or "Blizzard bar ") .. id
end

function BAE.GetButton(n, i)
    local kind, id = Kind(n)
    if kind == "bt4" then return _G["BT4Button" .. ((id - 1) * 12 + i)] end
    return _G[PREFIX[id] .. i]
end

function BAE.GetBar(n)
    local kind, id = Kind(n)
    if kind == "bt4" then return _G["BT4Bar" .. id] end
    local frame = _G[FRAMES[id]]
    if frame and frame.IsVisible then return frame end
    local first = _G[PREFIX[id] .. "1"]
    return first and (first.bar or first:GetParent())
end

-- Should this bar get artwork right now?
function BAE.BarActive(n)
    local db = BAE.db
    if not db or not db.enabled then return false end
    local kind, id = Kind(n)
    local bar = BAE.GetBar(n)
    if not bar then return false end
    if kind == "blizzard" then
        -- Bar 1 keeps Blizzard's own artwork; bars hidden by Bartender4 are skipped.
        return id ~= 1 and bar:IsVisible() and true or false
    end
    return true
end

-- Does this button take part in the bar's layout?
-- Bartender4 fades or hides empty buttons, but they still belong to the bar.
function BAE.Present(n, i, button)
    if Kind(n) == "bt4" then
        local bar = button:GetParent()
        local count = bar and bar.config and tonumber(bar.config.buttons)
        if count then return i <= count end
    end
    return button:IsShown() and true or false
end

-- The visible buttons that touch the left, right, top and bottom edge of a bar.
function BAE.Extents(n)
    local left, right, top, bottom
    for i = 1, 12 do
        local button = BAE.GetButton(n, i)
        if button and BAE.Present(n, i, button) and button:GetLeft() then
            if not left or button:GetLeft() < left:GetLeft() then left = button end
            if not right or button:GetRight() > right:GetRight() then right = button end
            if not top or button:GetTop() > top:GetTop() then top = button end
            if not bottom or button:GetBottom() < bottom:GetBottom() then bottom = button end
        end
    end
    return left, right, top, bottom
end

-- Decided by where the first two buttons really are, not by a flag of the bar.
function BAE.IsHorizontal(n)
    local first, second = BAE.GetButton(n, 1), BAE.GetButton(n, 2)
    local a, b = first and first:GetTop(), second and second:GetTop()
    if a and b then return math.abs(a - b) < .1 end
    local bar = BAE.GetBar(n)
    return not bar or bar.isHorizontal ~= false
end

-- Blizzard's own main bar is the source of the original artwork ------------------------
function BAE.NativeButton() return _G.ActionButton1 end

function BAE.NativeBorder()
    local art = MainActionBar and MainActionBar.BorderArt
    if not art then return nil end
    return art.NineSlice or art
end

-- Alpha values we changed on Blizzard regions, so copies still see the original.
BAE.savedAlpha = {}

-- Copies how a Blizzard texture looks onto one of our own textures.
function BAE.CopyLook(source, target, alphaFactor)
    local atlas = source:GetAtlas()
    if atlas then target:SetAtlas(atlas) else target:SetTexture(source:GetTexture()) end
    target:SetTexCoord(source:GetTexCoord())
    local r, g, b, a = BAE.OriginalColor(source)
    local shade = BAE.Shade()
    target:SetVertexColor(r * shade, g * shade, b * shade, a)
    target:SetBlendMode(source:GetBlendMode())
    local layer, sublevel = source:GetDrawLayer()
    target:SetDrawLayer(layer, sublevel)
    target:SetAlpha((BAE.savedAlpha[source] or source:GetAlpha()) * (alphaFactor or 1))
end

-- Re-creates the anchors of a region of the native button on a region of another
-- button, scaled by `factor`.
function BAE.MirrorRegion(source, target, nativeButton, button, factor)
    target:ClearAllPoints()
    target:SetSize(source:GetWidth() * factor, source:GetHeight() * factor)
    local count = source:GetNumPoints()
    if count == 0 then target:SetPoint("CENTER", button, "CENTER") return end
    for i = 1, count do
        local point, relative, relativePoint, x, y = source:GetPoint(i)
        local anchor = button
        if relative == nativeButton.icon and button.icon then anchor = button.icon end
        target:SetPoint(point, anchor, relativePoint, x * factor, y * factor)
    end
end
