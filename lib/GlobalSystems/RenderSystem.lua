require('lib.helperfunctions')
require('lib.globals')
local ffi = require("ffi")
local World = require('lib.ECS')
local bor = bit.bor

ffi.cdef[[
    typedef struct {
        float x;
        float y;
        float z;
    } vec3
]]

local C_POSITION, C_FISHBODY = COMPONENT.POSITION, COMPONENT.FISHBODY
local RenderSystem = {
    filter = bor(C_POSITION, C_FISHBODY),
    cache = {}, 
    last_version = -1,
    -- 1. Create a persistent buffer for 1020 vec4's
    -- This stays in memory and is reused every frame.
    circleBuffer = love.data.newByteData(ffi.sizeof("vec3") * 1020)
}

-- 2. Get a permanent FFI pointer to that buffer 
RenderSystem.circlePointer = ffi.cast("vec3*", RenderSystem.circleBuffer:getFFIPointer())

function RenderSystem:Draw()
    if self.last_version < World.Archetype_version then 
        self.cache = World.query(self.filter); self.last_version = World.Archetype_version 
    end

    local Wdata = World.data
    local fish = Wdata.FishBody 
    local pos = Wdata.Pos 
    local lg = love.graphics 
    local ptr = self.circlePointer

    lg.setShader(HeightMapShader)
    for _, arch in pairs(self.cache) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            local body = fish.items[id]
            local segs = fish.segs[id]

            -- Fill the pointer directly
            for j = 0, segs - 1 do
                ptr[j].x = body.rx[j]
                ptr[j].y = body.ry[j]
                ptr[j].z = body.segsize[j]
                --lg.circle("fill", body.rx[j], body.ry[j], body.segsize[j])
            end

            -- Add the head as the last element
            ptr[segs].x = pos.x[id]
            ptr[segs].y = pos.y[id]
            ptr[segs].z = 6.0

            -- 3. Send the persistent buffer to the shader 
            -- We send the ByteData object itself, Love2D handles the transfer.
            HeightMapShader:send("NUM_CIRCLES", segs + 1)
            HeightMapShader:send("CircleData", self.circleBuffer)

            -- Draw fish
            _setColour(10)
            lg.rectangle("fill", pos.x[id] - 100, pos.y[id] - 100, 400, 400)
        end
    end
    lg.setShader()
end

return RenderSystem