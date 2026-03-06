--=====================================================================
-- party.lua   (MacroQuest + ImGui – compact button layout)
--=====================================================================
-- A draggable radial UI for party commands, warp points and camp.
--=====================================================================

local mq   = require('mq')
local imgui = require('ImGui')

--=====================================================================
-- DETERMINE WARP FOLDER (next to the script, not under config)
--=====================================================================
local scriptPath = debug.getinfo(1, "S").source
if scriptPath:sub(1,1) == "@" then scriptPath = scriptPath:sub(2) end
local scriptDir = scriptPath:match("(.+)[/\\][^/\\]+$")
local warpFolder = scriptDir .. "/party"

local lfs = require("lfs")
if not lfs.attributes(warpFolder, "mode") then
    local ok, err = lfs.mkdir(warpFolder)
    if not ok then
        mq.cmdf("/echo |cFFFF0000Failed to create warp folder %s: %s|r", warpFolder, tostring(err))
    end
end

--=====================================================================
-- GLOBAL SETTINGS ----------------------------------------------------
--=====================================================================
local showUI   = true          -- /party toggles UI visibility
local warpMode = false         -- true = warp radial, false = party radial
local radius   = 90            -- outer radius for the radial buttons

-- Centre of the UI in **screen** coordinates (used only for dragging)
local centerX, centerY = 200, 200

--=====================================================================
-- BUTTON SIZES -------------------------------------------------------
--=====================================================================
local smallBtnW, smallBtnH = 80, 24        -- 80 × 24 (wider than before)
local bigBtnW,   bigBtnH   = 84, 32      -- 84 × 32 (centre button)

--=====================================================================
-- CALCULATE TIGHT WINDOW SIZE -----------------------------------------
--=====================================================================
-- Width/height of the window are based on radius + half‑button size.
local windowWidth  = radius * 2 + smallBtnW      -- 90*2 + 80 = 260
local windowHeight = radius * 2 + smallBtnH      -- 90*2 + 24 = 204
local windowHalfX = windowWidth  / 2
local windowHalfY = windowHeight / 2

--=====================================================================
-- RADIUS SETTINGS ----------------------------------------------------
--=====================================================================
local innerRadius = 80          -- inner radius for WarpMe/Teleport

--=====================================================================
-- WINDOW FLAGS -------------------------------------------------------
--=====================================================================
local partyFlags = ImGuiWindowFlags.NoTitleBar +
                   ImGuiWindowFlags.NoResize +
                   ImGuiWindowFlags.NoBackground
local warpFlags  = partyFlags   -- same flags for the warp window

--=====================================================================
-- ZONE / WARP DATABASE -----------------------------------------------
--=====================================================================
local zone     = mq.TLO.Zone.ShortName()
local warpFile = warpFolder .. "/" .. zone .. ".lua"
local warpDB   = {}

--=====================================================================
-- SMALL HELPERS ------------------------------------------------------
--=====================================================================
local function clamp(val, minv, maxv)
    if val < minv then return minv
    elseif val > maxv then return maxv
    else return val end
end

local function updateWindowPos()
    local halfW = windowHalfX
    local halfH = windowHalfY
    local screenW = mq.TLO.Window.Width()  or 1920
    local screenH = mq.TLO.Window.Height() or 1080

    centerX = clamp(centerX, halfW, screenW - halfW)
    centerY = clamp(centerY, halfH, screenH - halfH)

    winPosX = centerX - halfW
    winPosY = centerY - halfH
end

--=====================================================================
-- WARP FILE LOAD / SAVE ---------------------------------------------
--=====================================================================
local function loadWarps()
    local f = io.open(warpFile, "r")
    if not f then
        warpDB = {}
        return
    end
    f:close()
    local ok, data = pcall(dofile, warpFile)
    if ok and type(data) == "table" then
        warpDB = data
    else
        warpDB = {}
        mq.cmdf("/echo |cFFFF0000Failed to load warp file %s – starting fresh.|r", warpFile)
    end
end

local function saveWarps()
    local f = io.open(warpFile, "w+")
    if not f then
        mq.cmdf("/echo |cFFFF0000Cannot write warp file %s|r", warpFile)
        return
    end
    f:write("return {\n")
    for k, v in pairs(warpDB) do
        f:write(string.format("['%s']={y=%s,x=%s,z=%s},\n", k, v.y, v.x, v.z))
    end
    f:write("}\n")
    f:close()
end

loadWarps()
local lastZone = zone   -- remember the zone we started in

--=====================================================================
-- CAMP FUNCTIONS ----------------------------------------------------
--=====================================================================
local function setCamp()
    warpDB["camp"] = { y = mq.TLO.Me.Y(), x = mq.TLO.Me.X(), z = mq.TLO.Me.Z() }
    saveWarps()
end

local function WarpCamp()
    local c = warpDB["camp"]
    if c then
        mq.cmdf("/e3bcaa /warp loc %s %s %s", c.y, c.x, c.z)
    end
end

--=====================================================================
-- WARP FUNCTIONS ----------------------------------------------------
--=====================================================================
local function setWarp(slot)
    warpDB[slot] = { y = mq.TLO.Me.Y(), x = mq.TLO.Me.X(), z = mq.TLO.Me.Z() }
    saveWarps()
end

local function doWarp(slot)
    local w = warpDB[slot]
    if w then
        mq.cmdf("/e3bcaa /warp loc %s %s %s", w.y, w.x, w.z)
    end
end

local function warpToMe()
    mq.cmdf("/e3bcaa /warp loc %s %s %s", mq.TLO.Me.Y(), mq.TLO.Me.X(), mq.TLO.Me.Z())
end

--=====================================================================
-- UI HELPERS --------------------------------------------------------
--=====================================================================
local function drawButton(label, cx, cy, w, h, command)
    imgui.SetCursorPos(cx - w/2, cy - h/2)
    if imgui.Button(label, w, h) then command() end
end

local function outerButton(label, angle, command)
    local rad = math.rad(angle)
    local cx = windowHalfX + math.cos(rad) * radius
    local cy = windowHalfY + math.sin(rad) * radius
    drawButton(label, cx, cy, smallBtnW, smallBtnH, command)
end

local function innerButton(label, angle, command)
    local rad = math.rad(angle)
    local cx = windowHalfX + math.cos(rad) * innerRadius
    local cy = windowHalfY + math.sin(rad) * innerRadius
    drawButton(label, cx, cy, smallBtnW, smallBtnH, command)
end

local function centreButton(label, command)
    drawButton(label, windowHalfX, windowHalfY, bigBtnW, bigBtnH, command)
end

local isDragging = false
local lastMx, lastMy = 0,0
local dragBtnW, dragBtnH = 80,16

local function dragBar()
    -- Position the bar **just under** the centre button (WARPS).
    local barX = windowHalfX - dragBtnW/2
    local barY = windowHalfY + (bigBtnH/2) + 2      -- 2 px gap below centre button
    imgui.SetCursorPos(barX, barY)

    imgui.PushStyleColor(ImGuiCol.Button,          0.4,0.4,0.4,0.35)
    imgui.PushStyleColor(ImGuiCol.ButtonHovered,   0.7,0.7,0.7,0.6)

    imgui.Button("====", dragBtnW, dragBtnH)

    if imgui.IsItemActive() then
        local ok, io = pcall(function() return imgui.GetIO() end)
        if ok and io and io.MouseDelta then
            centerX = centerX + io.MouseDelta.x
            centerY = centerY + io.MouseDelta.y
        else
            local mx, my = imgui.GetMousePos()
            if not isDragging then
                isDragging = true
                lastMx, lastMy = mx, my
            else
                centerX = centerX + (mx - lastMx)
                centerY = centerY + (my - lastMy)
                lastMx, lastMy = mx, my
            end
        end
        updateWindowPos()
    else
        isDragging = false
    end

    imgui.PopStyleColor(2)
end

--=====================================================================
-- PARTY RADIAL -------------------------------------------------------
--=====================================================================
local function drawPartyRadial()
    updateWindowPos()
    imgui.SetNextWindowPos(winPosX, winPosY, 1)            -- ImGuiCond.Always
    imgui.SetNextWindowSize(windowWidth, windowHeight, 1)   -- **tight size**

    imgui.PushStyleColor(ImGuiCol.WindowBg, 0,0,0,0)

    if imgui.Begin("PartyRadial", nil, partyFlags) then
        dragBar()

        -- ==== OUTER CIRCLE (small buttons) ====
        outerButton("Follow",     60, function() mq.cmd("/followme")    end)
        outerButton("Stop",      120, function() mq.cmd("/followoff")   end)
        outerButton("WarpCamp", 150, function() WarpCamp()          end)

        outerButton("PlayerLoot",30, function() mq.cmd("/mac e9loot")   end)
        outerButton("PartyLoot",330,function() mq.cmd("/e3bcaa /mac e9loot") end)

        outerButton("Buff",      240, function() mq.cmd("/e3bcaa /memspellset buff")   end)
        outerButton("Combat",    300, function() mq.cmd("/e3bcaa /memspellset combat") end)

        outerButton("SetCamp",  210, function() setCamp() end)

        -- ==== INNER CIRCLE (WarpMe left, Teleport right) ====
        outerButton("WarpMe",   180, function() warpToMe() end)                     -- left side
        outerButton("Teleport",   0, function() mq.cmd("/e3bcaa /useitem 0") end)   -- right side

        -- ==== CENTRAL LARGER BUTTON (WARPS) ====
        centreButton("WARPS", function() warpMode = true end)
    end   -- imgui.Begin

    imgui.End()
    imgui.PopStyleColor()
end

--=====================================================================
-- WARP RADIAL --------------------------------------------------------
--=====================================================================
local function drawWarpRadial()
    updateWindowPos()
    imgui.SetNextWindowPos(winPosX, winPosY, 1)
    imgui.SetNextWindowSize(windowWidth, windowHeight, 1)   -- **tight size**

    imgui.PushStyleColor(ImGuiCol.WindowBg, 0,0,0,0)

    if imgui.Begin("WarpRadial", nil, warpFlags) then
        dragBar()

        -- ==== LEFT SIDE – Set 1‑5 (angles 210‑330) ====
        outerButton("Set2", 210, function() setWarp("warp2") end)   -- swapped with Set1
        outerButton("Set1", 240, function() setWarp("warp1") end)   -- swapped with Set2
        outerButton("Set3", 180, function() setWarp("warp3") end)   -- unchanged
        outerButton("Warp1", 300, function() doWarp("warp1") end)   -- Set4 → now Warp1
        outerButton("Warp2", 330, function() doWarp("warp2") end)   -- Set5 → now Warp2

        -- ==== RIGHT SIDE – Warp 1‑5 (angles 0‑120) ====
        outerButton("Warp3",   0,   function() doWarp("warp3") end)   -- now Warp3
        outerButton("Warp4",  30,   function() doWarp("warp4") end)   -- now Warp4
        outerButton("Warp5",  60,   function() doWarp("warp5") end)   -- now Warp5
        outerButton("Set4", 150, function() setWarp("warp4") end)       -- stays Set4 (right side)
        outerButton("Set5", 120, function() setWarp("warp5") end)       -- stays Set5 (right side)

        -- ==== CENTRAL LARGER BUTTON (BACK) ====
        centreButton("BACK", function() warpMode = false end)
    end   -- imgui.Begin

    imgui.End()
    imgui.PopStyleColor()
end

--=====================================================================
-- UI INITIALISATION -------------------------------------------------
--=====================================================================
mq.imgui.init("partyui", function()
    if not showUI then return end

    if warpMode then
        drawWarpRadial()
    else
        drawPartyRadial()
    end
end)

--=====================================================================
-- COMMANDS -----------------------------------------------------------
--=====================================================================
mq.bind("/party", function()
    showUI = not showUI
end)

mq.bind("/reloadwarps", function()
    zone     = mq.TLO.Zone.ShortName()
    warpFile = warpFolder .. "/" .. zone .. ".lua"
    loadWarps()
    mq.cmdf("/echo |cFF00FF00Warps reloaded for zone %s|r", zone)
    lastZone = zone
end)

--=====================================================================
-- KEEP THE SCRIPT RUNNING --------------------------------------------
--=====================================================================
while true do
    mq.delay(100)

    -- -----------------------------------------------------------------
    -- AUTO‑RELOAD ON ZONE CHANGE
    -- -----------------------------------------------------------------
    local curZone = mq.TLO.Zone.ShortName()
    if curZone ~= lastZone then
        zone     = curZone
        warpFile = warpFolder .. "/" .. zone .. ".lua"
        loadWarps()
        mq.cmdf("/echo |cFFFFFF00Loaded warp data for zone %s|r", zone)
        lastZone = curZone
    end
end
