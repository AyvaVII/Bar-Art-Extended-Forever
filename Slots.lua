local ADDON, BAE = ...

-- Slot artwork -----------------------------------------------------------------
-- Every button gets a small holder frame on its bar. Bartender4 fades empty buttons
-- with alpha 0, so the artwork must not be a child of the button itself.
local holders = {}
local hiddenNative = {}

local function Holder(button)
    local holder = holders[button]
    if holder then return holder end
    local bar = button:GetParent()
    if not bar then return nil end
    holder = CreateFrame("Frame", nil, bar)
    holder:SetFrameStrata(button:GetFrameStrata())
    holder:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    holder:SetAllPoints(button)
    holder.back = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    holder.art = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
    holder.back:Hide()
    holder.art:Hide()
    holders[button] = holder
    return holder
end

-- The bar's own slot layers are replaced by ours while a bar is decorated.
local function SetNativeHidden(button, hide)
    for _, key in ipairs({ "SlotBackground", "SlotArt" }) do
        local region = button[key]
        if region then
            if hide then
                if hiddenNative[region] == nil then hiddenNative[region] = region:GetAlpha() end
                region:SetAlpha(0)
            elseif hiddenNative[region] ~= nil then
                region:SetAlpha(hiddenNative[region])
                hiddenNative[region] = nil
            end
        end
    end
end

local function Style(holder, button, db)
    local width, height = button:GetWidth(), button:GetHeight()
    local native = BAE.NativeButton()
    local shade = BAE.Shade()
    holder.hasBack = false
    holder.back:Hide()

    if db.iconArt == "plain" or not (native and native.SlotArt) then
        holder.art:SetAtlas(db.iconArt == "plain" and "UI-HUD-ActionBar-IconFrame-Background"
            or "ui-hud-actionbar-iconframe-slot")
        holder.art:ClearAllPoints()
        holder.art:SetPoint("CENTER", button, "CENTER")
        holder.art:SetSize(width, height)
        holder.art:SetVertexColor(shade, shade, shade, 1)
        holder.art:SetBlendMode("BLEND")
        holder.art:SetAlpha(db.alpha)
        return
    end

    local factor = width / math.max(1, native:GetWidth())
    if native.SlotBackground then
        BAE.CopyLook(native.SlotBackground, holder.back, db.alpha)
        BAE.MirrorRegion(native.SlotBackground, holder.back, native, button, factor)
        holder.hasBack = true
    end
    BAE.CopyLook(native.SlotArt, holder.art, db.alpha)
    BAE.MirrorRegion(native.SlotArt, holder.art, native, button, factor)
end

local function UpdateButton(n, i, button)
    local db = BAE.db
    local active = BAE.BarActive(n)
    if not active and not holders[button] then return end
    local holder = Holder(button)
    if not holder then return end
    SetNativeHidden(button, active)
    if not active or not BAE.Present(n, i, button) or db.iconArt == "none" then
        holder.back:Hide()
        holder.art:Hide()
        holder.key = nil
        return
    end

    -- Stay right behind the button, whatever strata or level the bar uses.
    local strata, level = button:GetFrameStrata(), math.max(0, button:GetFrameLevel() - 1)
    if holder:GetFrameStrata() ~= strata then holder:SetFrameStrata(strata) end
    if holder:GetFrameLevel() ~= level then holder:SetFrameLevel(level) end

    local barScale = holder:GetParent():GetEffectiveScale()
    if barScale > 0 then holder:SetScale(button:GetEffectiveScale() / barScale) end

    local native = BAE.NativeButton()
    local key = table.concat({
        button:GetWidth(), button:GetHeight(), db.iconArt, db.alpha, BAE.Shade(),
        native and native:GetWidth() or 0,
    }, "|")
    if holder.key ~= key then
        holder.key = key
        Style(holder, button, db)
    end
    holder.art:Show()
    if holder.hasBack then holder.back:Show() end
end

local function Update()
    for n = 1, BAE.NUM_BARS do
        for i = 1, 12 do
            local button = BAE.GetButton(n, i)
            if button then UpdateButton(n, i, button) end
        end
    end
end

local function Hide()
    for _, holder in pairs(holders) do
        holder.back:Hide()
        holder.art:Hide()
        holder.key = nil
    end
    for region, alpha in pairs(hiddenNative) do region:SetAlpha(alpha) end
    wipe(hiddenNative)
end

BAE.Register(Update, Hide)
