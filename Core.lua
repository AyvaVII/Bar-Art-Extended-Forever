local ADDON, BAE = ...

BAE.pages = {}

-- Settings ------------------------------------------------------------------
local defaults = {
    enabled = true,
    border = true,
    dividers = true,
    borderPadding = 0,
    mainBorder = true,      -- Blizzard UI only: border of bar 1
    iconArt = "blizzard",   -- "blizzard" | "plain" | "none"
    alpha = 1,
    gryphons = true,
    gryphonFront = true,
    gryphonScale = 1,
    gryphonX = 0,
    gryphonY = 0,
    darkMode = false,
    darkIntensity = 50,
}

local function Merge(source, target)
    if type(target) ~= "table" then target = {} end
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = Merge(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function BAE.DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = BAE.DeepCopy(inner) end
    return copy
end

-- Module scheduler ----------------------------------------------------------
local modules = {}
local running

function BAE.Register(update, hide)
    modules[#modules + 1] = { update = update, hide = hide }
end

function BAE.Update()
    local db = BAE.db
    if not db or InCombatLockdown() then return end
    if db.enabled then
        running = true
        for _, module in ipairs(modules) do module.update() end
    elseif running ~= false then
        running = false
        for _, module in ipairs(modules) do module.hide() end
    end
end

function BAE.Changed()
    BAE.Update()
    for _, page in ipairs(BAE.pages) do page:Refresh() end
end

function BAE.Set(key, value)
    if not BAE.db then return end
    BAE.db[key] = value
    BAE.Changed()
end

-- Profiles ------------------------------------------------------------------
-- BarArtExtendedDB.profiles[name] holds the settings, BarArtExtendedDB.chars[char]
-- remembers which profile a character uses. Everyone starts on "Default".
local root, charKey

local function Activate(name, remember)
    if not root.profiles[name] then name = "Default" end
    root.profiles[name] = Merge(defaults, root.profiles[name])
    BAE.db = root.profiles[name]
    BAE.profileName = name
    if remember then root.chars[charKey] = name end
end

function BAE.GetProfiles()
    local list = {}
    if root then for name in pairs(root.profiles) do list[#list + 1] = name end end
    table.sort(list, function(a, b)
        if a == "Default" then return b ~= "Default" end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return list
end

function BAE.SwitchProfile(name)
    if root and root.profiles[name] then Activate(name, true); BAE.Changed() end
end

function BAE.CreateProfile(name)
    name = strtrim(name or "")
    if not root or name == "" or #name > 40 then print("Bar Art Extended: invalid profile name."); return end
    if root.profiles[name] then print("Bar Art Extended: that profile already exists."); return end
    root.profiles[name] = BAE.DeepCopy(BAE.db)
    BAE.SwitchProfile(name)
end

function BAE.CopyProfile(from)
    if not root or from == BAE.profileName or not root.profiles[from] then return end
    root.profiles[BAE.profileName] = BAE.DeepCopy(root.profiles[from])
    Activate(BAE.profileName)
    BAE.Changed()
end

function BAE.DeleteProfile(name)
    if not root or name == "Default" or not root.profiles[name] then return end
    root.profiles[name] = nil
    for char, used in pairs(root.chars) do if used == name then root.chars[char] = nil end end
    if BAE.profileName == name then Activate("Default", true) end
    BAE.Changed()
end

function BAE.ResetProfile()
    if not root then return end
    root.profiles[BAE.profileName] = nil
    Activate(BAE.profileName)
    BAE.Changed()
end

-- Startup -------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    BarArtExtendedDB = type(BarArtExtendedDB) == "table" and BarArtExtendedDB or {}
    root = BarArtExtendedDB
    root.profiles = root.profiles or {}
    root.chars = root.chars or {}
    charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    Activate(root.chars[charKey] or "Default")
    C_Timer.NewTicker(0.2, BAE.Update)
end)

-- Slash commands ------------------------------------------------------------
local function Number(text, low, high, fallback)
    local value = tonumber(text)
    if not value then return fallback end
    return math.max(low, math.min(high, value))
end

local commands = {}

commands.on = function() BAE.Set("enabled", true) end
commands.off = function() BAE.Set("enabled", false) end
commands.refresh = function() BAE.Update() end
commands.reset = function() BAE.ResetProfile() end
commands.alpha = function(a) BAE.Set("alpha", Number(a, 0, 1, 1)) end
commands.padding = function(a) BAE.Set("borderPadding", Number(a, -3, 12, 0)) end
commands.border = function(a) BAE.Set("border", a ~= "off") end
commands.dividers = function(a) BAE.Set("dividers", a ~= "off") end

commands.gryph = function(a, b)
    if a == "front" or a == "back" then
        BAE.Set("gryphonFront", a == "front")
    elseif a == "scale" then
        BAE.Set("gryphonScale", Number(b, .25, 1.5, 1))
    else
        BAE.db.gryphonX = Number(a, -200, 200, 0)
        BAE.db.gryphonY = Number(b, -200, 200, 0)
        BAE.Changed()
    end
end

commands.margins = function(a, b, c, d)
    if tonumber(a) and tonumber(b) and tonumber(c) and tonumber(d) then
        BAE.db.margins = { tonumber(a), tonumber(b), tonumber(c), tonumber(d) }
    else
        BAE.db.margins = nil
        BarArtExtendedDB.measured = nil
    end
    BAE.Changed()
end

commands.profile = function(_, _, _, _, rest)
    if rest and rest ~= "" then
        for _, name in ipairs(BAE.GetProfiles()) do
            if name:lower() == rest:lower() then
                BAE.SwitchProfile(name)
                print("Bar Art Extended: profile " .. name)
                return
            end
        end
        print("Bar Art Extended: unknown profile.")
    else
        print("Bar Art Extended: active profile " .. BAE.profileName)
        print("Profiles: " .. table.concat(BAE.GetProfiles(), ", "))
    end
end

commands.debug = function()
    print("Bar Art Extended - Bartender4 installed:", tostring(BAE.BT4Installed))
    local art = BAE.NativeBorder()
    print("Border source:", art and art:GetObjectType() or "none", "| margins l/r/t/b:", BAE.GetMargins(art))
    for n = 1, BAE.NUM_BARS do
        local bar = BAE.GetBar(n)
        local present = 0
        for i = 1, 12 do
            local button = BAE.GetButton(n, i)
            if button and BAE.Present(n, i, button) then present = present + 1 end
        end
        if bar then
            local border = BAE.borderFrames[n]
            print(("%s: visible=%s buttons=%d active=%s horizontal=%s border=%s"):format(
                BAE.SlotName(n), tostring(bar:IsVisible()), present, tostring(BAE.BarActive(n)),
                tostring(BAE.IsHorizontal(n)), tostring(border and border:IsShown() or false)))
        end
    end
    for _, line in ipairs(BAE.DividerInfo()) do print(line) end
    -- Everything Bartender4 created, in case a bar has an unexpected name.
    local names = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and key:match("^BT4Bar") and type(value) == "table" and value.IsVisible then
            names[#names + 1] = key .. (value:IsVisible() and "" or "(hidden)")
        end
    end
    table.sort(names)
    print("Bartender4 frames: " .. table.concat(names, ", "))
    -- Blizzard's bars: do their buttons exist, are they shown?
    for id, prefix in ipairs(BAE.PREFIX) do
        local first = _G[prefix .. "1"]
        local bar = first and (first.bar or first:GetParent())
        print(("Blizzard %d: button=%s shown=%s bar=%s barVisible=%s"):format(id, tostring(first ~= nil),
            tostring(first and first:IsShown() or false), tostring(bar and (bar:GetName() or "unnamed") or "none"),
            tostring(bar and bar:IsVisible() or false)))
    end
end

local function Help()
    print("|cffffd100Bar Art Extended|r  /bae on|off|reset|refresh")
    print("/bae alpha <0-1>  /bae padding <-3..12>  /bae border on|off  /bae dividers on|off")
    print("/bae gryph <x> <y>|scale <0.25-1.5>|front|back")
    print("/bae margins <l> <r> <t> <b>|auto  /bae profile [name]")
end

SLASH_BARARTEXTENDED1 = "/bae"
SlashCmdList.BARARTEXTENDED = function(message)
    local command, rest = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "settings" or command == "options" then
        if BAE.OpenOptions then BAE.OpenOptions() end
        return
    end
    local handler = commands[command]
    if not handler or not BAE.db then Help(); return end
    local a, b, c, d = rest:lower():match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    handler(a, b, c, d, rest)
end

SLASH_BARARTEXTENDEDRELOAD1 = "/rl"
SlashCmdList["BARARTEXTENDEDRELOAD"] = function()
    ReloadUI()
end