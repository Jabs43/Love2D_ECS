require('lib.helperfunctions')

local Collision = {}

--- Soft Collision AABB, Rounds hitbox points to the nearest tile coords.
--- Then checks if any tile pixels are intersecting with a wall tile.
--- @param x float The hitbox top left x position 
--- @param y float The hitbox top left y position 
--- @param w float The hitbox width in pixels 
--- @param h float The hitbox height in pixels 
--- @param map_ptr uint8_t* A pointer to the map data Global (MAP_BUFFER)
--- @param map_w integer The current width of the map in tiles Global(MAP_WIDTH)
--- @returns x, y float The new rounded pixel position
function Collision.resolve_box(x, y, w, h, map_ptr, map_w)
    -- tile bounds
    local floor  = math.floor
    local min    = math.min
    local left   = floor(x / 8)
    local right  = floor((x + w + 1) / 8)
    local top    = floor(y / 8)
    local bottom = floor((y + h + 1) / 8)

    for tx = left, right do
        for ty = top, bottom do
            if Collision.is_solid(tx+1, ty+1, map_ptr, map_w) then
                -- tile pixel bounds
                local tile_x = tx * 8
                local tile_y = ty * 8

                -- compute overlap
                local ox1 = (x + w) - tile_x
                local ox2 = (tile_x + 8) - x
                local oy1 = (y + h) - tile_y
                local oy2 = (tile_y + 8) - y

                -- choose minimal axis penetration, same as PICO-8 logic
                local minx = min(ox1, ox2)
                local miny = min(oy1, oy2)

                if minx < miny then
                    -- resolve X
                    if ox1 < ox2 then
                        x = x - ox1     -- push left
                    else
                        x = x + ox2     -- push right
                    end
                else
                    -- resolve Y
                    if oy1 < oy2 then
                        y = y - oy1     -- push up
                    else
                        y = y + oy2     -- push down
                    end
                end
            end
        end
    end
    return x, y
end

--- Basic AABB collision detection, 
--- checks if 2 hitboxs are intersecting.
--- @param a table Holds the bounding box data for object 1
--- @param b table Holds the bounding box data for object 2
--- @returns boolean
function Collision.aabb(a,b)
    return a.x+a.hitbox.x<b.x+b.hitbox.x+b.hitbox.w and 
           a.x+a.hitbox.x+a.hitbox.w>b.x+b.hitbox.x and 
           a.y+a.hitbox.y<b.y+b.hitbox.y+b.hitbox.h and 
           a.y+a.hitbox.y+a.hitbox.h>b.y+b.hitbox.y 
end

--- Checks if tile(x,y) is a wall tile 
--- @param tx integer Tile x coordinate 
--- @param ty integer Tile y coordinate 
--- @param map_ptr uint8_t* A pointer to the map data Global ( MAP_BUFFER)
--- @param map_w integer The current width of the map in tiles Global ( MAP_WIDTH )
--- @returns boolean If tile coord is a wall tile or not 
function Collision.is_solid(tx, ty, map_ptr, map_w)
    local result = map_ptr[(ty - 1) * map_w + tx] == 1 and true or false
    return result
end

--- Rounds hitbox points to the nearest tile coords.
--- Then checks if any tile pixels are intersecting with a wall tile.
--- @param x float The hitbox top left x position 
--- @param y float The hitbox top left y position 
--- @param w float The hitbox width in pixels 
--- @param h float The hitbox height in pixels 
--- @param map_ptr uint8_t* A pointer to the map data Global ( MAP_BUFFER )
--- @param map_w integer The current width of the map in tiles Global ( MAP_WIDTH )
--- @returns boolean 
function Collision.tiles_for_AABB(x, y, w, h, map_ptr, map_w)
    if map_ptr then
        local floor = math.floor
        local minTX = floor(x / 8) 
        local minTY = floor(y / 8)
        local maxTX = floor((x + w + 1) / 8) 
        local maxTY = floor((y + h + 1) / 8)
        for ty = minTY, maxTY do 
            for tx = minTX, maxTX do 
                if Collision.is_solid(tx+1, ty+1, map_ptr, map_w) then
                    return true 
                end
            end
        end
    end
    return false
end

return Collision