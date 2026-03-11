require('lib.helperfunctions') 
require('lib.globals') -- For MAP_BUFFER, MAP_WIDTH constants in tile collision checks
local Collision = require('lib.collision') -- Example collision module for AABB checks and tilemap queries
local World = require('lib.ECS')
local SpatialHash = require('lib.SpatialHash') -- Example for broad-phase optimization in collision detection

local function is_solid(id, ox, oy)
    -- We pull current values directly from the SoA arrays
    local data = World.data 
    local x, y = data.Pos.x[id], data.Pos.y[id]
    local hitbox = data.RecHitbox
    local mbuff, mwidth = MAP_BUFFER, MAP_WIDTH 

    -- Query tilemap
    return Collision.tiles_for_AABB(
        (x + hitbox.ox[id] + ox) - 1, 
        (y + hitbox.oy[id] + oy) - 1, 
        hitbox.w[id], 
        hitbox.h[id], 
        mbuff, 
        mwidth
    )
end

local function move_xbinary(id, amount)
    local px = World.data.Pos.x
    
    -- 1. If the full move is safe, just take it (fast path)
    if not is_solid(id, amount, 0) then
        px[id] = px[id] + amount
        return
    end

    -- 2. If we hit something, binary search the gap
    local low = 0
    local high = amount

    while low <= high do
        local mid = (low + high) * 0.5
        if is_solid(id, mid, 0) then
            high = mid -- Too far, move the upper bound in
            return -- If we hit solid, we can stop immediately since we only care about the last safe point
        else
            low = mid  -- Safe, move the lower bound up
        end
    end

    -- 3. Move the entity to the last known safe "low" point
    px[id] = px[id] + low
end

local function move_ybinary(id, amount)
    local py = World.data.Pos.y
    
    -- 1. If the full move is safe, just take it (fast path)
    if not is_solid(id, 0, amount) then
        py[id] = py[id] + amount
        return
    end

    -- 2. If we hit something, binary search the gap
    local low = 0
    local high = amount
    
    while low <= high do
        local mid = (low + high) * 0.5
        if is_solid(id, 0, mid) then
            high = mid -- Too far, move the upper bound in
            return -- If we hit solid, we can stop immediately since we only care about the last safe point
        else
            low = mid  -- Safe, move the lower bound up
        end
    end

    -- 3. Move the entity to the last known safe "low" point
    py[id] = py[id] + low
end

local function move(id, dx_frame, dy_frame)
    -- 1. Handle X
    local px = World.data.Pos.x
    -- Simple optimization: check the full distance first
    if not is_solid(id, dx_frame, 0) then
        px[id] = px[id] + dx_frame
    else
        -- Only if full distance fails, do the expensive pixel-step to be precise
        move_xbinary(id, math.floor(dx_frame + 0.5)) 
    end

    -- 2. Handle Y
    local py = World.data.Pos.y
    if not is_solid(id, 0, dy_frame) then
        py[id] = py[id] + dy_frame
    else
        move_ybinary(id, math.floor(dy_frame + 0.5))
    end
end

--[[ Swim movement behaviour ]]--
local function calc_rotated_sine_wave_vec(direction, amp, frequency, phase)
    local t = love.timer.getTime()
    local sin = math.sin

    -- wave displacement along perpendicular axis
    local wave = amp * sin(frequency * t + phase)

    -- rotate wave by direction
    local sa = sin(direction)
    local ca = math.cos(direction)

    -- final vector = ONLY oscillation, no t-based drift!
    local sx = -sa * wave -- perpendicular wiggle
    local sy =  ca * wave

    return sx, sy
end

local function swim_move(spd, dx, dy)
    local new_dx, new_dy = 0, 0
    if dx ~= 0 or dy ~= 0 then 
        local len = math.sqrt(dx*dx + dy*dy)
        local spd_ratio = math.min(1.0, len / spd)
        local frq = 8^spd_ratio
        local ang = math.atan(dy, dx)
        local swim_x, swim_y = calc_rotated_sine_wave_vec(ang, 40, frq, 0)
        new_dx = dx + swim_x
        new_dy = dy + swim_y
    end
    return new_dx, new_dy
end

local function apply_swim(dt, spd, dx, dy)
    local dx_final, dy_final = 0, 0
    local dx_swim, dy_swim = swim_move(spd, dx, dy)
    dx_final = dx_swim * dt 
    dy_final = dy_swim * dt 
    return dx_final, dy_final 
end

local bor = bit.bor
local band = bit.band

local PhysicsSystem = {
    -- Queries
    swim_filter = bor(COMPONENT.POSITION, COMPONENT.VELOCITY, COMPONENT.SWIM),
    simple_filter = bor(COMPONENT.POSITION, COMPONENT.VELOCITY), -- Note: excludes SWIM
    cache_swim = {},
    cache_simple = {},
    last_version = -1
}

function PhysicsSystem:Update(dt)
    -- Refresh both caches 
    if self.last_version < World.Archetype_version then
        self.cache_swim = World.query(self.swim_filter)
        -- Custom query Logic: get POSITION+VELOCITY but NOT SWIM 
        self.cache_simple = {} 
        for signature, arch in pairs(World.Archetypes) do 
            if band(signature, self.simple_filter) == self.simple_filter 
            and band(signature, COMPONENT.SWIM) == 0 then 
                self.cache_simple[signature] = arch 
            end
        end
        self.last_version = World.Archetype_version 
    end

    SpatialHash:clear()
    local data = World.data 
    local pos = data.Pos
    local vel = data.Vel

    -- REBUILD HASH: Register all collidable entities
    for sig, arch in pairs(self.cache_swim) do 
        if band(sig, COMPONENT.COLLISION) > 0 then 
            for i = 1, arch.count do 
                local id = arch.ids[i]
                SpatialHash:register(id, data.Pos.x[id], data.Pos.y[id], data.RecHitbox.w[id], data.RecHitbox.h[id])
            end
        end
    end

    -- 1. Process Swimming Entities 
    for sig, arch in pairs(self.cache_swim) do
        -- Check ONCE per archetype if it has collision
        local has_collision = band(sig, COMPONENT.COLLISION) > 0 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            local mx, my = apply_swim(dt, vel.spd[id], vel.dx[id], vel.dy[id])

            if has_collision then 
                local nearby_ids = SpatialHash:get_nearby(pos.x[id] + mx, pos.y[id] + my, data.RecHitbox.w[id], data.RecHitbox.h[id])
                for _, other_id in ipairs(nearby_ids) do 
                    if id ~= other_id then 
                        -- Check if we collide with this nearby entity
                        local a = {
                            x = pos.x[id], 
                            y = pos.y[id], 
                            hitbox = {
                                x = data.RecHitbox.ox[id], 
                                y = data.RecHitbox.oy[id], 
                                w = data.RecHitbox.w[id], 
                                h = data.RecHitbox.h[id]
                            }
                        }
                        local b = {
                            x = pos.x[other_id], 
                            y = pos.y[other_id], 
                            hitbox = {
                                x = data.RecHitbox.ox[other_id], 
                                y = data.RecHitbox.oy[other_id], 
                                w = data.RecHitbox.w[other_id], 
                                h = data.RecHitbox.h[other_id]
                            }
                        }
                        if Collision.aabb(a, b) then
                            -- Handle collision (simple response: just reset positions to pre-move state, could be improved with proper resolution)
                            pos.x[id] = pos.x[id]
                            pos.y[id] = pos.y[id]

                            pos.x[other_id] = pos.x[other_id]
                            pos.y[other_id] = pos.y[other_id]
                        end
                    end
                end
                move(id, mx, my)
            else
                pos.x[id] = pos.x[id] + mx 
                pos.y[id] = pos.y[id] + my
            end
        end
    end

    -- 2. Process Simple Entities (Bullet logic, etc)
    for _, arch in pairs(self.cache_simple) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            pos.x[id] = pos.x[id] + vel.dx[id] * dt 
            pos.y[id] = pos.y[id] + vel.dy[id] * dt 
        end
    end
end

return PhysicsSystem