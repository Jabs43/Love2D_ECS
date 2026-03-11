require('lib.helperfunctions')
require('lib.globals')
require('lib.collision')
local World = require('lib.ECS')
local bor = bit.bor

local AISystem = {
    filter = bor(COMPONENT.AI, COMPONENT.VELOCITY),
    cache = {},
    last_version = -1
}

function AISystem:Update(dt)
    if self.last_version < World.Archetype_version then 
        self.cache = World.query(self.filter); self.last_version = World.Archetype_version
    end

    local ai = World.data.Ai
    local vel = World.data.Vel 
    local random, cos, sin = math.random, math.cos, math.sin 

    for _, arch in pairs(self.cache) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            ai.timer[id] = ai.timer[id] + dt 

            if ai.timer[id] >= random(5) then 
                ai.timer[id] = 0 
                ai.dir[id] = random() * 6.28 -- 2*PI
            end
            
            local spd = vel.spd[id]
            vel.dx[id] = cos(ai.dir[id]) * spd 
            vel.dy[id] = sin(ai.dir[id]) * spd 
        end
    end
end

return AISystem