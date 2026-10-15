local ADDON, BAE = ...

-- Settings pages -----------------------------------------------------------------
-- A tiny layout helper: controls are stacked from top to bottom on a canvas panel.
local Page = {}
Page.__index = Page
local sliderCount = 0

local function Tooltip(control, title, text)
    if not text then return end
    control:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, .82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function NewPage(name)
    local page = setmetatable({
        panel = CreateFrame("Frame", "BarArtExtended" .. name),
        y = -20, refreshers = {}, syncing = false,
    }, Page)
    page.panel:SetScript("OnShow", function() page:Refresh() end)
    BAE.pages[#BAE.pages + 1] = page
    return page
end

function Page:Refresh()
    if not self.panel:IsShown() or not BAE.db then return end
    self.syncing = true
    for _, refresh in ipairs(self.refreshers) do refresh() end
    self.syncing = false
end

function Page:Text(text, font, x, width)
    local label = self.panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", self.panel, "TOPLEFT", x or 24, self.y)
    label:SetJustifyH("LEFT")
    if width then label:SetWidth(width); label:SetWordWrap(true) end
    label:SetText(text)
    return label
end

function Page:Title(title, subtitle)
    self:Text(title, "GameFontNormalHuge")
    self.y = self.y - 36
    if subtitle then
        local label = self:Text(subtitle, "GameFontHighlight", 24, 560)
        self.y = self.y - label:GetStringHeight() - 14
    end
end

function Page:Heading(text)
    self.y = self.y - 8
    self:Text(text, "GameFontNormalLarge")
    local line = self.panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(.65, .5, .25, .35)
    line:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 24, self.y - 27)
    line:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -30, self.y - 27)
    line:SetHeight(1)
    self.y = self.y - 38
end

function Page:Note(text)
    local label = self:Text(text, "GameFontDisableSmall", 24, 560)
    self.y = self.y - label:GetStringHeight() - 8
end

function Page:Check(label, tip, get, set)
    local box = CreateFrame("CheckButton", nil, self.panel, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 20, self.y + 4)
    box:SetSize(26, 26)
    local text = self.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 4, 1)
    text:SetText(label)
    box:SetScript("OnClick", function(button)
        if not self.syncing then set(button:GetChecked() and true or false) end
    end)
    Tooltip(box, label, tip)
    self.refreshers[#self.refreshers + 1] = function() box:SetChecked(get()) end
    self.y = self.y - 28
    return box
end

function Page:Slider(label, minimum, maximum, step, get, set, format, tip)
    sliderCount = sliderCount + 1
    local name = "BarArtExtendedSlider" .. sliderCount
    self:Text(label)
    local slider = CreateFrame("Slider", name, self.panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 210, self.y - 2)
    slider:SetSize(200, 16)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    for _, part in ipairs({ "Low", "High", "Text" }) do
        local region = slider[part] or _G[name .. part]
        if region then region:SetText("") end
    end
    local value = self:Text("", "GameFontNormal", 424)
    local function Show(v) value:SetText(format and format(v) or tostring(v)) end
    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + .5) * step
        Show(v)
        if not self.syncing then set(v) end
    end)
    Tooltip(slider, label, tip)
    self.refreshers[#self.refreshers + 1] = function()
        local v = get()
        slider:SetValue(v)
        Show(v)
    end
    self.y = self.y - 28
    return slider
end

-- choices: list of { label, value } or a function returning one.
-- With `get` the menu is a radio list; without it each entry is a plain button.
function Page:Dropdown(label, choices, get, set, tip, defaultText)
    self:Text(label)
    local menu = CreateFrame("DropdownButton", nil, self.panel, "WowStyle1DropdownTemplate")
    menu:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 205, self.y + 6)
    menu:SetWidth(210)
    local function List() return type(choices) == "function" and choices() or choices end
    menu:SetupMenu(function(_, root)
        for _, choice in ipairs(List()) do
            local text, value = choice[1], choice[2]
            if get then
                root:CreateRadio(text, function() return BAE.db ~= nil and get() == value end, function() set(value) end)
            else
                root:CreateButton(text, function() set(value) end)
            end
        end
    end)
    Tooltip(menu, label, tip)
    self.refreshers[#self.refreshers + 1] = function()
        local text = type(defaultText) == "function" and defaultText() or defaultText
        if not text and get then
            for _, choice in ipairs(List()) do if choice[2] == get() then text = choice[1] end end
        end
        if text then menu:SetDefaultText(text) end
        menu:GenerateMenu()
    end
    self.y = self.y - 34
    return menu
end

function Page:Button(label, x, onClick, width)
    local button = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", self.panel, "TOPLEFT", x, self.y)
    button:SetSize(width or 150, 26)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function Percent(v) return v .. "%" end

-- Main page ---------------------------------------------------------------------------
local main = NewPage("Main")
main:Title("Bar Art Extended", "Blizzard-style artwork for your Bartender4 action bars.")
main:Check("Enable Bar Art Extended", "Switch all artwork on or off.",
    function() return BAE.db.enabled end, function(v) BAE.Set("enabled", v) end)

main:Heading("Bars")
main:Check("Show border", "Draw the Blizzard frame around each bar.",
    function() return BAE.db.border end, function(v) BAE.Set("border", v) end)
main:Check("Show dividers", "Small ornaments between the buttons (needs the border).",
    function() return BAE.db.dividers end, function(v) BAE.Set("dividers", v) end)
if not BAE.BT4Installed then
    main:Check("Show border of bar 1", "Blizzard's own border around the main action bar.",
        function() return BAE.db.mainBorder end, function(v) BAE.Set("mainBorder", v) end)
end
main:Slider("Border padding", -3, 12, 1,
    function() return BAE.db.borderPadding end, function(v) BAE.Set("borderPadding", v) end, nil,
    "Space between the border and the buttons. Negative values move the border closer.")
main:Dropdown("Icon art", {
        { "Blizzard", "blizzard" }, { "Plain", "plain" }, { "None", "none" },
    }, function() return BAE.db.iconArt end, function(v) BAE.Set("iconArt", v) end,
    "Background artwork of empty action buttons. Spell icons stay unchanged.")
main:Slider("Opacity", 0, 100, 1,
    function() return math.floor(BAE.db.alpha * 100 + .5) end,
    function(v) BAE.Set("alpha", v / 100) end, Percent,
    "Opacity of all added artwork. Spell icons and keybinds are not affected.")

local function OpenEditMode()
    local manager = EditModeManagerFrame
    if InCombatLockdown() or not manager then return end
    if SettingsPanel then HideUIPanel(SettingsPanel) end
    if manager.CanEnterEditMode and manager:CanEnterEditMode() then ShowUIPanel(manager) end
end

if BAE.BT4Installed then
    main:Heading("Gryphons (Bar 1)")
    main:Check("Show gryphons", "Draw the gryphons (wyverns for Horde) at both ends of bar 1.",
        function() return BAE.db.gryphons end, function(v) BAE.Set("gryphons", v) end)
    main:Check("In front of the bar", "Checked: like Blizzard's default UI. Unchecked: behind the bar.",
        function() return BAE.db.gryphonFront end, function(v) BAE.Set("gryphonFront", v) end)
    main:Slider("Size", 25, 150, 5,
        function() return math.floor(BAE.db.gryphonScale * 100 + .5) end,
        function(v) BAE.Set("gryphonScale", v / 100) end, Percent)
    main:Slider("Distance", -60, 120, 1,
        function() return math.floor(BAE.db.gryphonX + .5) end, function(v) BAE.Set("gryphonX", v) end, nil,
        "Move both gryphons away from the bar (positive) or closer to it (negative).")
    main:Slider("Height", -60, 60, 1,
        function() return math.floor(BAE.db.gryphonY + .5) end, function(v) BAE.Set("gryphonY", v) end, nil,
        "Move both gryphons up (positive) or down (negative).")
    main:Note("Bartender4 bars: layout, scale and spacing are set in Bartender4. "
        .. "Blizzard bars that Bartender4 does not manage: Blizzard's Edit Mode.")
    main:Button("Open Bartender4", 24, function()
        if InCombatLockdown() then return end
        if SettingsPanel then HideUIPanel(SettingsPanel) end
        if Bartender4 and Bartender4.ChatCommand then Bartender4:ChatCommand()
        else print("Bar Art Extended: type /bt to open Bartender4.") end
    end)
    main:Button("Open Edit Mode", 184, OpenEditMode)
else
    main:Note("The gryphons and the spacing between the buttons are set in Blizzard's Edit Mode.")
    main:Button("Open Edit Mode", 24, OpenEditMode)
end

-- Dark Mode page ----------------------------------------------------------------------
local dark = NewPage("Dark")
dark:Title("Dark Mode", "Darken the bar artwork, the buttons, the micro menu, bags and gryphons.")
dark:Check("Enable Dark Mode", "Spell icons keep their original colours.",
    function() return BAE.db.darkMode end, function(v) BAE.Set("darkMode", v) end)
dark:Slider("Darkness", 0, 100, 1,
    function() return BAE.db.darkIntensity end, function(v) BAE.Set("darkIntensity", v) end, Percent,
    "0% keeps the original colours, 100% is the darkest look.")

-- Profiles page -----------------------------------------------------------------------

local function EditBox(popup) return popup.editBox or (popup.GetEditBox and popup:GetEditBox()) end

StaticPopupDialogs["BARARTEXTENDED_NEW"] = {
    text = "Name for the new profile.\nIt starts as a copy of your current settings.",
    button1 = ACCEPT or "OK", button2 = CANCEL or "Cancel",
    hasEditBox = true, maxLetters = 40,
    OnShow = function(self)
        local box = EditBox(self)
        if box then box:SetText(""); box:SetFocus() end
    end,
    OnAccept = function(self)
        local box = EditBox(self)
        if box then BAE.CreateProfile(box:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        BAE.CreateProfile(self:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["BARARTEXTENDED_DELETE"] = {
    text = "Delete the profile \"%s\"?\nCharacters using it switch back to \"Default\".",
    button1 = ACCEPT or "OK", button2 = CANCEL or "Cancel",
    OnAccept = function(_, data) BAE.DeleteProfile(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["BARARTEXTENDED_RESET"] = {
    text = "Reset the profile \"%s\" to the default settings?",
    button1 = ACCEPT or "OK", button2 = CANCEL or "Cancel",
    OnAccept = function() BAE.ResetProfile() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["BARARTEXTENDED_COPY"] = {
    text = "Overwrite the settings of \"%s\" with the settings of \"%s\"?",
    button1 = ACCEPT or "OK", button2 = CANCEL or "Cancel",
    OnAccept = function(_, data) BAE.CopyProfile(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local profiles = NewPage("Profiles")
profiles:Title("Profiles",
    "All characters use the profile \"Default\" until you pick another one on that character.")

local function ProfileChoices()
    local list = {}
    for _, name in ipairs(BAE.GetProfiles()) do list[#list + 1] = { name, name } end
    return list
end
local function OtherProfiles()
    local list = {}
    for _, name in ipairs(BAE.GetProfiles()) do
        if name ~= BAE.profileName then list[#list + 1] = { name, name } end
    end
    return list
end

profiles:Dropdown("Active profile", ProfileChoices,
    function() return BAE.profileName end, function(name) BAE.SwitchProfile(name) end, nil,
    function() return BAE.profileName end)
profiles:Dropdown("Copy settings from", OtherProfiles, nil, function(name)
    StaticPopup_Show("BARARTEXTENDED_COPY", BAE.profileName, name, name)
end, nil, "Choose a profile...")

profiles.y = profiles.y - 6
profiles:Button("New Profile", 24, function() StaticPopup_Show("BARARTEXTENDED_NEW") end)
local deleteButton = profiles:Button("Delete Profile", 184, function()
    local name = BAE.profileName
    if name ~= "Default" then StaticPopup_Show("BARARTEXTENDED_DELETE", name, nil, name) end
end)
profiles:Button("Reset Profile", 344, function()
    StaticPopup_Show("BARARTEXTENDED_RESET", BAE.profileName)
end)
profiles.y = profiles.y - 36
profiles:Note("New characters start with \"Default\", which cannot be deleted. Quick switch: /bae profile <name>")
profiles.refreshers[#profiles.refreshers + 1] = function()
    deleteButton:SetEnabled(BAE.profileName ~= "Default")
end

-- Registration ------------------------------------------------------------------------
local category = Settings.RegisterCanvasLayoutCategory(main.panel, "Bar Art Extended")
Settings.RegisterAddOnCategory(category)
Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutSubcategory(category, dark.panel, "Dark Mode"))
Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutSubcategory(category, profiles.panel, "Profiles"))

function BAE.OpenOptions() Settings.OpenToCategory(category:GetID()) end
