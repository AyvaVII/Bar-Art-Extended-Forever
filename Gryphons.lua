local ADDON, BAE = ...

-- Gryphons (wyverns for Horde) at both ends of bar 1 --------------------------------
-- Placement is read from Blizzard's own end caps, then mirrored around the centre
-- of the bar so that the left and right cap always sit at the same distance.
local holder

local function Create(bar)
    holder = CreateFrame("Frame", nil, bar)
    holder.left = holder:CreateTexture(nil, "ARTWORK")
    holder.right = holder:CreateTexture(nil, "ARTWORK")
end

local function Vertical(point)
    return point:find("TOP") and "TOP" or (point:find("BOTTOM") and "BOTTOM" or "")
end

-- Reads one Blizzard end cap and describes where its inner edge (the one facing the
-- bar) lies, measured from the horizontal centre of a bar that is `width` wide.
local function ReadCap(source, fallbackAtlas, isLeft, width)
    local atlas = source and source.GetAtlas and source:GetAtlas()
    if not (atlas and C_Texture.GetAtlasInfo(atlas)) then atlas = fallbackAtlas end
    local info = C_Texture.GetAtlasInfo(atlas)
    if not info then return nil end

    local point = isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT"
    local relativePoint = isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT"
    local x, y = 0, 0
    if source and source.GetNumPoints and source:GetNumPoints() > 0 then
        local p, _, rp, px, py = source:GetPoint(1)
        point, relativePoint, x, y = p or point, rp or relativePoint, px or 0, py or 0
    end

    local anchorSide = point:find("LEFT") and "LEFT" or (point:find("RIGHT") and "RIGHT" or "")
    local relativeSide = relativePoint:find("LEFT") and -1 or (relativePoint:find("RIGHT") and 1 or 0)
    local offset
    if isLeft then
        offset = (anchorSide == "RIGHT" and 0) or (anchorSide == "LEFT" and info.width) or info.width / 2
    else
        offset = -((anchorSide == "LEFT" and 0) or (anchorSide == "RIGHT" and info.width) or info.width / 2)
    end
    return {
        atlas = atlas, width = info.width, height = info.height, y = y,
        vertical = Vertical(point), relativeVertical = Vertical(relativePoint),
        inner = relativeSide * width / 2 + x + offset,
    }
end

local function Place(texture, cap, scale)
    if texture.atlas ~= cap.atlas then
        texture:SetAtlas(cap.atlas)
        texture.atlas = cap.atlas
    end
    texture:SetSize(cap.width * scale, cap.height * scale)
    local shade = BAE.Shade()
    texture:SetVertexColor(shade, shade, shade, 1)
end

local function Update()
    local db = BAE.db
    local bar = BAE.GetBar(1)
    local border = BAE.borderFrames[1]
    if not bar or not border or border:GetNumPoints() == 0
        or not db.gryphons or not BAE.BarActive(1) then
        if holder then holder:Hide() end
        return
    end
    if not holder then Create(bar) end

    -- Same coordinate space as the border, so offsets match Blizzard's.
    holder:SetScale(border:GetScale())
    holder:ClearAllPoints()
    holder:SetAllPoints(border)
    holder:SetAlpha(db.alpha)
    if db.gryphonFront then
        holder:SetFrameStrata(bar:GetFrameStrata())
        holder:SetFrameLevel(bar:GetFrameLevel() + 10)
    else
        holder:SetFrameStrata("BACKGROUND")
        holder:SetFrameLevel(1)
    end

    local width = border:GetWidth()
    if not width or width <= 0 then holder:Hide(); return end

    local caps = MainActionBar and MainActionBar.EndCaps
    local kind = UnitFactionGroup("player") == "Horde" and "Wyvern" or "Gryphon"
    local left = ReadCap(caps and caps.LeftEndCap, "UI-HUD-ActionBar-" .. kind .. "-Left", true, width)
    local right = ReadCap(caps and caps.RightEndCap, "UI-HUD-ActionBar-" .. kind .. "-Right", false, width)
    if not left or not right then holder:Hide(); return end

    local scale = math.max(.1, math.min(3, db.gryphonScale))
    Place(holder.left, left, scale)
    Place(holder.right, right, scale)

    -- Mirror both caps around the centre: half = distance of the inner edges.
    local half = (right.inner - left.inner) / 2
    local y = (left.y + right.y) / 2 + db.gryphonY
    local relative = left.relativeVertical ~= "" and left.relativeVertical or "CENTER"
    holder.left:ClearAllPoints()
    holder.left:SetPoint(left.vertical .. "RIGHT", holder, relative, -half - db.gryphonX, y)
    holder.right:ClearAllPoints()
    holder.right:SetPoint(left.vertical .. "LEFT", holder, relative, half + db.gryphonX, y)
    holder:Show()
end

local function Hide()
    if holder then holder:Hide() end
end

BAE.Register(Update, Hide)
