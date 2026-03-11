require('lib.helperfunctions')
require('lib.globals')
local World = require('lib.ECS')
local bor = bit.bor

local InputSystem = {
    filter = bor(COMPONENT.INPUT, COMPONENT.VELOCITY),
    cache = {}, 
    last_version = -1
}

function InputSystem:Update()
    if self.last_version < World.Archetype_version then 
        self.cache = World.query(self.filter); self.last_version = World.Archetype_version
    end

    local vx, vy, vspd = World.data.Vel.dx, World.data.Vel.dy, World.data.Vel.spd
    local isDown = love.keyboard.isDown 
    local sqrt = math.sqrt

    for _, arch in pairs(self.cache) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            local dx, dy = 0, 0
            local spd = vspd[id]
            
            if isDown("space") then spd = 110 end 
            if isDown("left")  then dx = dx - 1 end 
            if isDown("right") then dx = dx + 1 end 
            if isDown("up")    then dy = dy - 1 end 
            if isDown("down")  then dy = dy + 1 end 

            if dx ~= 0 or dy ~= 0 then 
                local len = sqrt(dx*dx + dy*dy)
                vx[id], vy[id] = (dx/len) * spd, (dy/len) * spd 
            else
                vx[id], vy[id] = 0, 0 
            end
        end
    end
end

return InputSystem