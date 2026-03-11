require('lib.helperfunctions')
require('lib.globals')
local Collision = require('lib.collision')
local World = require('lib.ECS')
local bor = bit.bor

local FishBodyAniSystem = {
    filter = bor(COMPONENT.POSITION, COMPONENT.FISHBODY),
    cache = {},
    last_version = -1
}

function FishBodyAniSystem:Update(dt)-- Works with entitys that have Position AND FishBody components(Data)
    assert(self.last_version ~= nil, "self.last_version is nil")
    assert(World.Archetype_version ~= nil, "World.Archetype_version is nil")
    -- 1. Refresh cache if World Changed
    if self.last_version < World.Archetype_version then 
        self.cache = World.query(self.filter)
        self.last_version = World.Archetype_version
    end

    -- 2. Localize math and globals 
    local sqrt, drag, grv = math.sqrt, DRAG, GRV 
    local mb, mw = MAP_BUFFER, MAP_WIDTH
    local pos_data = World.data.Pos 
    local body_data = World.data.FishBody 
    local resolve_box = Collision.resolve_box 

    -- 3. Loop through matched Archetypes 
    for _, arch in pairs(self.cache) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]

            -- Fetch pointers 
            local px, py = pos_data.x[id], pos_data.y[id]
            local segs = body_data.segs[id]

            -- Localize body arrays for the segment loop 
            local rx, ry = body_data.items[id].rx, body_data.items[id].ry 
            local ru, rv = body_data.items[id].ru, body_data.items[id].rv 
            local nx, ny = body_data.items[id].nx, body_data.items[id].ny 
            local s_size = body_data.items[id].segsize 

            -- STEP 1: Integrate Velocity 
            for j = 0, segs - 1 do 
                local size = s_size[j]
                local u = ru[j] * drag 
                local v = rv[j] * drag + (grv - body_data.bouyancy[id]) * dt 

                nx[j] = rx[j] + u * dt 
                ny[j] = ry[j] + v * dt 

                -- Collision 
                if mb then 
                    nx[j], ny[j] = resolve_box(nx[j], ny[j], size, size, mb, mw)
        end
    end

            -- STEP 2: Pin head to Position 
            nx[0], ny[0] = px, py 

            -- STEP 3: Constraints
            local slen = body_data.seglen[id] 
            for it = 1, 15 do 
                nx[0], ny[0] = px, py
                for j = 1, segs - 1 do 
                    local dx = nx[j] - nx[j-1]
                    local dy = ny[j] - ny[j-1]
                    local dist = sqrt(dx*dx + dy*dy)
                    if dist > 0 then 
                        local diff = (dist - slen) / dist * 0.5
                        dx = dx * diff; dy = dy * diff 
                        nx[j-1] = nx[j-1] + dx 
                        ny[j-1] = ny[j-1] + dy 
                        nx[j] = nx[j] - dx 
                        ny[j] = ny[j] - dy
                    end
                end
            end

            -- STEP 4: Commit 
            for j = 0, segs - 1 do 
                -- Calculate velocity based on how much the constraint moved the segment
                if dt > 0 then
                    ru[j] = (nx[j] - rx[j]) / dt 
                    rv[j] = (ny[j] - ry[j]) / dt 
                else
                    ru[j], rv[j] = 0, 0
                end
                -- Finalize position
                rx[j], ry[j] = nx[j], ny[j]
            end
        end
    end
end

return FishBodyAniSystem