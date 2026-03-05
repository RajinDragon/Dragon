
-- party.lua (Party v5 with Radial Wheel)
local mq = require('mq')
local ImGui = require('ImGui')

local modules = {
    buff = require('party.buff_ai'),
    rez = require('party.rez_ai'),
    click = require('party.click_ai'),
    loot = require('party.loot_manager'),
    radial = require('party.radial')
}

local running = true

mq.bind('/radial', function() modules.radial.toggle() end)

while running do
    modules.radial.draw()
    mq.delay(100)
end
