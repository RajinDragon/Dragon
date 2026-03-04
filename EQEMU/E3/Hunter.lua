local mq = require('mq')
local ImGui = require('ImGui')

-------------------------------------------------
-- FILES
-------------------------------------------------
local CONFIG_FILE = mq.configDir .. "/hunter_custom_named.lua"
local BLACKLIST_FILE = mq.configDir .. "/hunter_blacklist.lua"

-------------------------------------------------
-- SETTINGS
-------------------------------------------------
local WARP_PARTY = false

-------------------------------------------------
-- STATE
-------------------------------------------------
local openGUI = true
local showCustomWindow = false
local showBlacklistWindow = false

local mobIdToWarp = 0
local searchFilter = ""

local hunterTargets = {}
local customNamed = {}
local customBlacklist = {}

local currentZone = mq.TLO.Zone.ID() or 0

-------------------------------------------------
-- SAVE / LOAD
-------------------------------------------------
local function saveTable(path, tbl)
    local f = io.open(path, "w")
    if not f then return end
    f:write("return {\n")
    for name,_ in pairs(tbl) do
        f:write(string.format("  [\"%s\"] = true,\n", name))
    end
    f:write("}\n")
    f:close()
end

local function loadTable(path)
    local ok, data = pcall(dofile, path)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

customNamed = loadTable(CONFIG_FILE)
customBlacklist = loadTable(BLACKLIST_FILE)

mq.bind('/hunter', function() openGUI = not openGUI end)

-------------------------------------------------
-- ADD TARGET
-------------------------------------------------
local function addCurrentTarget()
    local target = mq.TLO.Target
    if target() and target.Type() == "NPC" then
        local name = target.CleanName():lower()
        customNamed[name] = true
        customBlacklist[name] = nil
        saveTable(CONFIG_FILE, customNamed)
        saveTable(BLACKLIST_FILE, customBlacklist)
        print("[Hunter] Added named: "..name)
    end
end

-------------------------------------------------
-- BLACKLIST TARGET
-------------------------------------------------
local function blacklistCurrentTarget()
    local target = mq.TLO.Target
    if target() and target.Type() == "NPC" then
        local name = target.CleanName():lower()
        local id = target.ID()

        customBlacklist[name] = true
        customNamed[name] = nil

        saveTable(BLACKLIST_FILE, customBlacklist)
        saveTable(CONFIG_FILE, customNamed)

        hunterTargets[id] = nil

        print("[Hunter] Blacklisted: "..name)
    end
end

-------------------------------------------------
-- DETECTION
-------------------------------------------------
local function isLikelyRare(name)
    local lower = name:lower()

    if customBlacklist[lower] then return false end
    if customNamed[lower] then return true end

    if lower:find("^a ") then return false end
    if lower:find("^an ") then return false end
    if lower:find("^a_") then return false end

    if lower:find("lord") then return true end
    if lower:find("king") then return true end
    if lower:find("ancient") then return true end
    if lower:find("overseer") then return true end

    if name:match("%u%l+") then return true end

    return false
end

local function detectSpawns()

    local count = mq.TLO.SpawnCount("npc")() or 0

    for i=1,count do
        local spawn = mq.TLO.NearestSpawn(i,"npc")

        if spawn() then
            local id = spawn.ID()
            local name = spawn.CleanName()
            local lower = name:lower()

            if not customBlacklist[lower] then
                if customNamed[lower] or isLikelyRare(name) then
                    if not hunterTargets[id] then
                        hunterTargets[id] = {
                            name = name,
                            id = id,
                            spawnTime = os.time(),
                            isCustom = customNamed[lower] or false
                        }
                    end
                end
            end
        end
    end

    for id,_ in pairs(hunterTargets) do
        if not mq.TLO.Spawn(id)() then
            hunterTargets[id] = nil
        end
    end
end

local function forceScan()
    hunterTargets = {}
    detectSpawns()
    print("[Hunter] Force scan complete.")
end

-------------------------------------------------
-- MAIN WINDOW
-------------------------------------------------
local function drawMainUI()

    if not openGUI then return end

    openGUI = ImGui.Begin("Elite Hunter", openGUI)

    if ImGui.Button("Add Target As Named") then addCurrentTarget() end
    ImGui.SameLine()
    if ImGui.Button("Blacklist Target") then blacklistCurrentTarget() end

    ImGui.Separator()

    if ImGui.Button("Warp Party: "..tostring(WARP_PARTY)) then
        WARP_PARTY = not WARP_PARTY
    end
    ImGui.SameLine()
    if ImGui.Button("Force Scan Now") then forceScan() end

    ImGui.Separator()

    if ImGui.Button("Show Custom Named") then
        showCustomWindow = not showCustomWindow
    end
    ImGui.SameLine()
    if ImGui.Button("Show Blacklist") then
        showBlacklistWindow = not showBlacklistWindow
    end

    ImGui.Separator()

    ImGui.Text("Search:")
    ImGui.SameLine()
    searchFilter = ImGui.InputText("##search", searchFilter)

    ImGui.Separator()

    for _,mob in pairs(hunterTargets) do
        local spawn = mq.TLO.Spawn(mob.id)
        if spawn() then
            if searchFilter == "" or mob.name:lower():find(searchFilter:lower()) then

                local distance = math.floor(spawn.Distance() or 0)

                if mob.isCustom then
                    ImGui.TextColored(0,1,1,1,
                        string.format("%s | %dm", mob.name, distance))
                else
                    ImGui.TextColored(0,1,0,1,
                        string.format("%s | %dm", mob.name, distance))
                end

                ImGui.SameLine()
                if ImGui.Button("Warp##"..mob.id) then mobIdToWarp = mob.id end
                ImGui.SameLine()
                if ImGui.Button("Target##"..mob.id) then spawn.DoTarget() end
            end
        end
    end

    ImGui.End()
end

-------------------------------------------------
-- CUSTOM WINDOW
-------------------------------------------------
local function drawCustomWindow()
    if not showCustomWindow then return end
    showCustomWindow = ImGui.Begin("Custom Named List", showCustomWindow)
    for name,_ in pairs(customNamed) do
        ImGui.TextColored(0,1,1,1,name)
    end
    ImGui.End()
end

-------------------------------------------------
-- BLACKLIST WINDOW
-------------------------------------------------
local function drawBlacklistWindow()
    if not showBlacklistWindow then return end
    showBlacklistWindow = ImGui.Begin("Blacklist", showBlacklistWindow)
    for name,_ in pairs(customBlacklist) do
        ImGui.TextColored(1,0,0,1,name)
    end
    ImGui.End()
end

-------------------------------------------------
-- RADAR
-------------------------------------------------
local function drawRadar()
    ImGui.SetNextWindowBgAlpha(0.4)
    ImGui.Begin("HunterRadar", nil,
        ImGuiWindowFlags.NoTitleBar +
        ImGuiWindowFlags.AlwaysAutoResize)

    if ImGui.Button("HUNTER") then
        openGUI = true
    end

    ImGui.End()
end

mq.imgui.init('HunterMainUI', drawMainUI)
mq.imgui.init('HunterCustomUI', drawCustomWindow)
mq.imgui.init('HunterBlacklistUI', drawBlacklistWindow)
mq.imgui.init('HunterRadarUI', drawRadar)

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------
while true do

    local zoneNow = mq.TLO.Zone.ID() or 0
    if zoneNow ~= currentZone then
        currentZone = zoneNow
        hunterTargets = {}
        print("[Hunter] Zone changed.")
    end

    detectSpawns()

    if mobIdToWarp > 0 then
        local spawn = mq.TLO.Spawn(mobIdToWarp)
        if spawn() then
            spawn.DoTarget()
            mq.delay(200)
            if WARP_PARTY then
                mq.cmd('/warp target')
                mq.delay(300)
                mq.cmd('/bcaa //warp target')
            else
                mq.cmd('/warp target')
            end
        end
        mobIdToWarp = 0
    end

    mq.delay(50)
end