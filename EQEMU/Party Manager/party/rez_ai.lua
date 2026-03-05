
-- rez_ai.lua
local mq = require('mq')
for i=1, mq.TLO.Group.Members() do
    local m = mq.TLO.Group.Member(i)
    if m() and m.Dead() then
        mq.cmdf('/target %s', m.Name())
        mq.delay(200)
        mq.cmd('/useitem "Resurrection Stone"')
        mq.delay(4000)
    end
end
mq.cmd('/echo Rez AI complete')
