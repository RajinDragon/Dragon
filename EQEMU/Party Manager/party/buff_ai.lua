
-- buff_ai.lua
local mq = require('mq')
local buffs = {"Symbol","Virtue","Focus","Protection"}

for i=1, mq.TLO.Group.Members() do
    local member = mq.TLO.Group.Member(i).Name()
    if member then
        for _,b in ipairs(buffs) do
            mq.cmdf('/target %s', member)
            mq.delay(200)
            mq.cmdf('/casting "%s"', b)
            mq.delay(3000)
        end
    end
end
mq.cmd('/echo Buff AI complete')
