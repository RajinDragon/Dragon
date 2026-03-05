
-- radial.lua
local mq = require('mq')
local ImGui = require('ImGui')

local module = {}
local show = false

local actions = {
    {name="Buff Mode", cmd='/bcaa //memspellset buff | /bcaa //buff'},
    {name="Combat Mode", cmd='/bcaa //memspellset combat'},
    {name="Force Rez", cmd='/bcaa //corpse'},
    {name="Assist Tank", cmd='/assist Starlight'},
    {name="Camp Here", cmd='/party camp'},
    {name="Loot Manager", cmd='/lua run party/loot_manager'},
    {name="Add Cursor Loot", cmd='cursorloot'},
    {name="Stop Party AI", cmd='/lua stop party'}
}

function module.toggle()
    show = not show
end

local function runAction(action)
    if action.cmd == "cursorloot" then
        local item = mq.TLO.Cursor.Name()
        if item then
            mq.cmd('/ini e9loot Important "'..item..'" 1')
            print("Added "..item.." to important loot")
        end
    else
        mq.cmd(action.cmd)
    end
end

function module.draw()
    if not show then return end
    local centerX, centerY = ImGui.GetMousePos()
    ImGui.SetNextWindowPos(centerX-150, centerY-150)
    ImGui.Begin("Party Radial", nil,
        ImGuiWindowFlags.NoTitleBar +
        ImGuiWindowFlags.NoResize +
        ImGuiWindowFlags.NoBackground +
        ImGuiWindowFlags.AlwaysAutoResize)
    local radius = 120
    local angleStep = (2 * math.pi) / #actions
    for i,action in ipairs(actions) do
        local angle = angleStep * (i-1)
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        ImGui.SetCursorPos(150+x,150+y)
        if ImGui.Button(action.name) then
            runAction(action)
            show = false
        end
    end
    ImGui.End()
end

return module
