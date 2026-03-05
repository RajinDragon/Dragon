
-- loot_manager.lua
local mq = require('mq')
local json = require('dkjson')
local configFile = mq.configDir..'/party_loot.json'
local data = {items={}}
local f = io.open(configFile,"r")
if f then data = json.decode(f:read('*a')) or data f:close() end
local cursor = mq.TLO.Cursor.Name()
if cursor then
    table.insert(data.items, cursor)
    mq.cmdf('/echo Added %s to important loot list', cursor)
end
local save = io.open(configFile,"w+")
save:write(json.encode(data,{indent=true}))
save:close()
