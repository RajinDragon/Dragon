
-- click_ai.lua
local mq = require('mq')
local clickies = {"Blood Drinker's Coating","Shield of the Immaculate","Spiritcaller Totem"}
for _,item in ipairs(clickies) do
    if mq.TLO.FindItem(item)() then
        mq.cmdf('/useitem "%s"', item)
        mq.delay(2000)
    end
end
mq.cmd('/echo Clicky AI complete')
