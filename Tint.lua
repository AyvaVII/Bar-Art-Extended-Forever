local ADDON, BAE = ...

-- Dark Mode -------------------------------------------------------------------------
-- Our own textures are darkened when they are drawn (BAE.Shade). Blizzard and
-- Bartender4 textures are darkened here, and restored when Dark Mode is switched off.
local originals = setmetatable({}, { __mode = "k" })

function BAE.Shade()
    local db = BAE.db
    if db and db.enabled and db.darkMode then
        return 1 - .9 * math.max(0, math.min(100, db.darkIntensity)) / 100
    end
    return 1
end

-- The colour a texture had before we darkened it.
function BAE.OriginalColor(texture)
    local original = originals[texture]
    if original then return unpack(original) end
    return texture:GetVertexColor()
end

local function Paint(texture, shade)
    if not texture or not texture.GetVertexColor or not texture.SetVertexColor then return end
    local original = originals[texture]
    if not original then
        original = { texture:GetVertexColor() }
        originals[texture] = original
    end
    texture:SetVertexColor(original[1] * shade, original[2] * shade, original[3] * shade, original[4])
end

function BAE.TintFrame(frame, shade)
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then Paint(region, shade) end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do BAE.TintFrame(child, shade) end
    end
end

local function TintButton(button, shade)
    Paint(button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture()), shade)
    Paint(button.PushedTexture or (button.GetPushedTexture and button:GetPushedTexture()), shade)
    Paint(button.Background, shade)
    Paint(button.PushedBackground, shade)
end

local function Restore()
    if not next(originals) then return end
    for texture, original in pairs(originals) do texture:SetVertexColor(unpack(original)) end
    wipe(originals)
end

local extraBars = { "BT4BarMicroMenu", "BT4BarBagBar", "BT4BarStanceBar", "BT4BarPetBar" }

local function Update()
    local shade = BAE.Shade()
    if shade >= 1 then Restore(); return end
    for n = 1, BAE.NUM_BARS do
        for i = 1, 12 do
            local button = BAE.GetButton(n, i)
            if button then TintButton(button, shade) end
        end
    end
    do
        if MainActionBar then
            local art = MainActionBar.BorderArt
            if art then
                if art:GetObjectType() == "Texture" then Paint(art, shade) else BAE.TintFrame(art, shade) end
            end
            if MainActionBar.EndCaps then BAE.TintFrame(MainActionBar.EndCaps, shade) end
            for _, pool in pairs({ MainActionBar.HorizontalDividersPool, MainActionBar.VerticalDividersPool }) do
                if pool.EnumerateActive then
                    for divider in pool:EnumerateActive() do BAE.TintFrame(divider, shade) end
                end
            end
        end
        if MicroMenu then for _, child in ipairs({ MicroMenu:GetChildren() }) do TintButton(child, shade) end end
        if BagsBar then for _, child in ipairs({ BagsBar:GetChildren() }) do TintButton(child, shade) end end
    end
    for _, name in ipairs(extraBars) do
        local bar = _G[name]
        if bar and bar.GetChildren then
            for _, child in ipairs({ bar:GetChildren() }) do TintButton(child, shade) end
        end
    end
end

BAE.Register(Update, Restore)
