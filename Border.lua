local ADDON, BAE = ...

-- Bar borders -------------------------------------------------------------------
local frames = {}
BAE.borderFrames = frames

-- Used only if Blizzard's hidden bar cannot be measured.
local FALLBACK_MARGINS = { 8, 8, 8, 8 }

local function Sane(value) return value and value > -30 and value < 120 end

local function ScaleOf(region)
    if region.GetEffectiveScale then return region:GetEffectiveScale() end
    local parent = region:GetParent()
    return parent and parent:GetEffectiveScale() or 1
end

-- Distance between Blizzard's border and its outer buttons, in border units.
local function Measure(art)
    local scale = ScaleOf(art)
    local artLeft, artRight, artTop, artBottom = art:GetLeft(), art:GetRight(), art:GetTop(), art:GetBottom()
    if not (artLeft and artRight and artTop and artBottom) or scale <= 0 then return end

    local left, right, top, bottom
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button and button:IsShown() and button:GetLeft() then
            if not left or button:GetLeft() < left:GetLeft() then left = button end
            if not right or button:GetRight() > right:GetRight() then right = button end
            if not top or button:GetTop() > top:GetTop() then top = button end
            if not bottom or button:GetBottom() < bottom:GetBottom() then bottom = button end
        end
    end
    if not left then return end

    local function Units(value, frame) return value * frame:GetEffectiveScale() / scale end
    return Units(left:GetLeft(), left) - artLeft,
        artRight - Units(right:GetRight(), right),
        artTop - Units(top:GetTop(), top),
        Units(bottom:GetBottom(), bottom) - artBottom
end

function BAE.GetMargins(art)
    local manual = BAE.db and BAE.db.margins
    if manual then return unpack(manual) end
    local saved = BarArtExtendedDB and BarArtExtendedDB.measured
    if saved then return unpack(saved) end
    if art then
        local l, r, t, b = Measure(art)
        if Sane(l) and Sane(r) and Sane(t) and Sane(b) then
            BarArtExtendedDB.measured = { l, r, t, b }
            return l, r, t, b
        end
    end
    return unpack(FALLBACK_MARGINS)
end

local function GetFrame(n)
    local bar = BAE.GetBar(n)
    if not bar then return nil end
    local frame = frames[n]
    if frame then
        -- The bar changed (for example Bartender4 took over): follow it.
        if frame:GetParent() ~= bar then
            frame:SetParent(bar)
            frame:SetFrameStrata("BACKGROUND")
            frame:SetFrameLevel(0)
        end
        return frame
    end
    frame = CreateFrame("Frame", nil, bar)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame.back = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.back:SetAtlas("ui-hud-actionbar-frame-background")
    frame.back:SetAllPoints(frame)
    frame.back:Hide()
    frame.tex = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
    frame.tex:SetAllPoints(frame)
    frame.tex:Hide()
    frame.pieces = {}
    frame:Hide()
    frames[n] = frame
    return frame
end

local function HidePieces(frame)
    for _, piece in pairs(frame.pieces) do piece:Hide() end
end

-- Copies Blizzard's border onto our frame. It is either one texture or a "nine slice"
-- frame (corners, edges, centre) whose pieces keep their size when the frame stretches.
local function Sync(frame, art)
    if not art then
        local shade = BAE.Shade()
        frame.tex:SetAtlas("UI-HUD-ActionBar-Frame")
        frame.tex:SetVertexColor(shade, shade, shade, 1)
        frame.tex:ClearAllPoints()
        frame.tex:SetAllPoints(frame)
        frame.tex:Show()
        frame.back:Hide()
        HidePieces(frame)
        return
    end

    if art:GetObjectType() == "Texture" then
        BAE.CopyLook(art, frame.tex, 1)
        frame.tex:ClearAllPoints()
        frame.tex:SetAllPoints(frame)
        frame.tex:Show()
        frame.back:Hide()
        HidePieces(frame)
        return
    end

    frame.tex:Hide()
    local sources = {}
    for _, region in ipairs({ art:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            sources[#sources + 1] = region
            if not frame.pieces[region] then frame.pieces[region] = frame:CreateTexture(nil, "BORDER") end
        end
    end
    -- First all pieces exist, then they are anchored to each other.
    local hasCenter = false
    for _, region in ipairs(sources) do
        local piece = frame.pieces[region]
        if region == art.Center then hasCenter = true end
        BAE.CopyLook(region, piece, 1)
        if region.IsHorizTile and piece.SetHorizTile then
            piece:SetHorizTile(region:IsHorizTile())
            piece:SetVertTile(region:IsVertTile())
        end
        piece:ClearAllPoints()
        piece:SetSize(region:GetWidth(), region:GetHeight())
        for i = 1, region:GetNumPoints() do
            local point, relative, relativePoint, x, y = region:GetPoint(i)
            piece:SetPoint(point, frame.pieces[relative] or frame, relativePoint, x, y)
        end
        piece:SetShown(region:IsShown())
    end
    frame.back:SetShown(not hasCenter)
end

local function UpdateBar(n)
    local frame = GetFrame(n)
    if not frame then return end
    local db = BAE.db
    local left, right, top, bottom = BAE.Extents(n)
    if not BAE.BarActive(n) or not left then frame:Hide(); return end

    local art = BAE.NativeBorder()
    local key = table.concat({
        art and art:GetObjectType() or "none", art and art:GetWidth() or 0,
        art and art:GetHeight() or 0, BAE.Shade(),
    }, "|")
    if frame.key ~= key then
        frame.key = key
        Sync(frame, art)
    end

    -- Scaling the frame keeps Blizzard's border thickness and corner size intact.
    local native = BAE.NativeButton()
    local ratio = (art and native) and ScaleOf(art) / native:GetEffectiveScale() or 1
    local barScale = frame:GetParent():GetEffectiveScale()
    if barScale <= 0 then return end
    frame:SetScale(left:GetEffectiveScale() / barScale * ratio)

    local l, r, t, b = BAE.GetMargins(art)
    local pad = db.borderPadding
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", left, "LEFT", -(l + pad), 0)
    frame:SetPoint("RIGHT", right, "RIGHT", r + pad, 0)
    frame:SetPoint("TOP", top, "TOP", 0, t + pad)
    frame:SetPoint("BOTTOM", bottom, "BOTTOM", 0, -(b + pad))
    frame:SetAlpha(db.alpha)
    frame:SetShown(db.border)
end

local function Update()
    for n = 1, BAE.NUM_BARS do UpdateBar(n) end
end

local function Hide()
    for _, frame in pairs(frames) do frame:Hide(); frame.key = nil end
end

BAE.Register(Update, Hide)
