require('lib.helperfunctions')
local GlobalSystems = require('lib.GlobalSystems')
local Push = require('lib.push')

local ffi = require("ffi")

-- 1. Create a persistent buffer for the map to avoid GC pressure
local M = {
    map_ptr = nil,
    buffer_ptr = nil,
    width = 0,
    height = 0
}

--- Generates a game map 
--- @param w integer The map width in 8x8 pixel tiles
--- @param h integer The map height in 8x8 pixel tiles 
--- @param iters integer How many iterations of Cellular Automata you want to generate the map with 
--- @return uint8_t* M.map_ptr This is a pointer to the new map (uint8_t[w*h])
function M.generate(w, h, iters) 
    local map_size = w * h 

    -- Allocate FFI memory(only once or if size changes)
    if not M.map_ptr or (w*h) ~= (M.width*M.height) then 
        M.map_ptr = ffi.new("uint8_t[?]", map_size)
        M.buffer_ptr = ffi.new("uint8_t[?]", map_size)

        M.width, M.height = w, h
    end

    -- 1. Random Fill (Using 0-based indexing for ffi)
    for y = 0, h - 1 do 
        local depth_percent = 0.2
        if y > 400 then
            if y < 450 then depth_percent = 0.51
            elseif y < 500 then depth_percent = 0.45
            elseif y < 550 then depth_percent = 0.49
            elseif y < 600 then depth_percent = 0.50
            elseif y < 650 then depth_percent = 0.40
            elseif y < 700 then depth_percent = 0.49
            else depth_percent = 0.40 end
        end
        for x = 0, w - 1 do 
            local idx = y * w + x 
            if x == 0 or y == 0 or x == w-1 or y == h-1 then 
                M.map_ptr[idx] = 1 
            else
                M.map_ptr[idx] = (math.random() < depth_percent) and 1 or 0
            end
        end
    end

    -- 2. Cellular Automata Step (FFI is much faster than lua table)
    for i = 1, iters do 
        M.step_ffi(M.map_ptr, M.buffer_ptr, w, h)
        -- Swap pointers 
        M.map_ptr, M.buffer_ptr = M.buffer_ptr, M.map_ptr
    end

    -- 3. Flood fill to remove small caves 
    M.cleanup_isolated_caves(M.map_ptr, w, h)

    return M.map_ptr
end

function M.step_ffi(src, dst, w, h)
    for y = 1, h - 2 do 
        local yoff = y * w 
        for x = 1, w - 2 do 
            local idx = yoff + x 
            local adj = 0 
            -- Unrolled 3x3 check for speed 
            adj = adj + src[idx-w-1] + src[idx-w] + src[idx-w+1]
            adj = adj + src[idx-1]                + src[idx+1]
            adj = adj + src[idx+w-1] + src[idx+w] + src[idx+w+1]

            if adj >= 5 then dst[idx] = 1 
            elseif adj < 4 then dst[idx] = 0 
            else dst[idx] = src[idx] end 
        end
    end
end

function M.cleanup_isolated_caves(map, w, h)
    local map_size = w * h 
    local visited = ffi.new("uint8_t[?]", map_size)
    local stack = {}
    local largest_region = {} 

    for i = 0, map_size - 1 do 
        if map[i] == 0 and visited[i] == 0 then 
            local current_region = {}
            local top = 1 
            stack[top] = i
            visited[i] = 1 

            while top > 0 do 
                local curr = stack[top]; top = top - 1 
                current_region[#current_region+1] = curr 
                
                -- Check 4-way neighbours 
                local neighbours = {curr-w, curr+w, curr-1, curr+1}
                for _, n in ipairs(neighbours) do 
                    if n >= 0 and n < map_size and map[n] == 0 and visited[n] == 0 then 
                        visited[n] = 1 
                        top = top + 1 
                        stack[top] = n 
                    end
                end
            end

            if #current_region > #largest_region then 
                largest_region = current_region 
            end
        end
    end

    -- Fill everything that ISN'T the largest region 
    -- 1. Set whole map to walls 
    for i = 0, map_size - 1 do map[i] = 1 end
    -- 2. Carve back the largest region 
    for _, idx in ipairs(largest_region) do map[idx] = 0 end
end

--- Visualization of map in console (ASCII Print)
--- @param m uint8_t* This is a pointer to the map (uint8_t[w*h])
--- @param w integer This is the map width in 8x8 pixel tiles 
--- @param h integer This is the map height in 8x8 pixel tiles 
function M.print_map(m, w, h)
    print("\n--- MAP PREVIEW ---")
    local chars = {}
    -- Lower resolution preview for console legibility
    local floor = math.floor
    local max = math.max
    local step_x = max(1, floor(w/600))
    local step_y = max(1, floor(h/600))

    for y = 0, h - 1, step_y do
        for x = 0, w - 1, step_x do
            local idx = y * w + x 
            -- If True (Wall) print '#', else '.'
            chars[#chars+1] = m[idx] == 1 and "H" or " "
        end
        chars[#chars+1] = "\n"
    end
    print(table.concat(chars))
end

-----------------------------------------------------------
-- FAST TEXTURE GENERATION (FFI)
-----------------------------------------------------------

--- Generates a heightmap texture from the given map 
--- @param map uint8_t* This is a pointer to the game map (uint8_t[w*h])
--- @param w integer This is the maps width in tiles 
--- @param h integer This is the maps height in tiles 
--- @param tile_size integer This is the size of the tile in pixels e.g. 8 for 8x8 tile 
--- @returns image, imageData
function M.generate_heightmap_tex(map, w, h, tile_size)
    local total_w = w * tile_size
    local total_h = h * tile_size
    local imageData = love.image.newImageData(total_w, total_h)
    local pointer = ffi.cast("uint8_t*", imageData:getFFIPointer())

    -- Pre-calculate smoothed values per TILE (not per pixel)
    -- This saves w*h*(tile_size^2) calculations
    local tile_values = ffi.new("float[?]", w * h)
    local smoothing_lvl = 4
    local area = (smoothing_lvl * 2 + 1) ^ 2
    
    for y = 0, h - 1 do
        local y_offset = y * w
        for x = 0, w - 1 do
            local idx = y_offset + x
            local value = 1.0

            if map[idx] == 0 then -- if floor
                local n = 0
                for dy = -smoothing_lvl, smoothing_lvl do
                    local ny = y + dy
                    if ny >= 0 and ny < h then
                        local ny_off = ny * w
                        for dx = -smoothing_lvl, smoothing_lvl do
                            local nx = x + dx
                            if nx >= 0 and nx < w then
                                if map[ny_off + nx] == 1 then 
                                    n = n + 1 
                                end
                            end
                        end
                    end
                end
                
                value = (n / area) ^ 1.8
                if value < 0.01 then value = 0.01 end
            end
            
            -- Convert to 0-255 byte for FFI or 0-1 for standard
            tile_values[idx] = value
        end
    end

    -- FAST PATH (Pointer arithmetic)
    -- Format is usually RGBA (4 bytes per pixel)
    local floor = math.floor
    for ty = 0, h - 1 do
        local ty_off = ty * w
        for tx = 0, w - 1 do
            local val = tile_values[(ty_off + tx) + 1]
            local byte_val = floor(val * 255)
            
            -- Fill the tile block
            local start_y = ty * tile_size
            local start_x = tx * tile_size
            
            for py = 0, tile_size - 1 do
                local row_ptr_offset = (start_y + py) * total_w * 4
                for px = 0, tile_size - 1 do
                    local ptr_idx = row_ptr_offset + (start_x + px) * 4
                    pointer[ptr_idx] = byte_val     -- R
                    pointer[ptr_idx+1] = byte_val   -- G
                    pointer[ptr_idx+2] = byte_val   -- B
                    pointer[ptr_idx+3] = 255        -- A
                end
            end
        end
    end

    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")
    return image, imageData
end

--- This updates the Dynamic Heightmap canvas 
--- @param canvas canvas This is the DynamicHeightmap canvas thats going to be updated
function M.updateDynamicHeightmap(canvas)
    local lg = love.graphics
    lg.setCanvas(canvas)
    lg.clear(0,0,0,0)

    lg.push()       -- isolate transform!
        lg.origin() -- reset ALL transforms
        GlobalSystems:Draw()         -- just draw normally
    lg.pop()

    lg.setCanvas()
end

--- Draws the map inside the global : MAP_BUFFER 
--- @param shader shader The RayTraceShader for the map lighting 
--- @param light_x float The x world position for the main light 
--- @param light_y float The y world position for the main light
function M.draw_map(shader, light_x, light_y)
    local width = MAP_WIDTH
    local height = MAP_HEIGHT

    -- Convert tile pos to map pos
    local map_pixel_w = width * 8
    local map_pixel_h = height * 8 

    local light_uvx = light_x / map_pixel_w
    local light_uvy = light_y / map_pixel_h

    local dirx, diry, dirz = -0.0, -0.0, 0.4

    -- Apply offset before clamping
    local sun_uvx = light_uvx + dirx * (1.0 / width)
    local sun_uvy = light_uvy + diry * (1.0 / height)
    local sun_uvz = dirz

    -- Clamp only after everything is calculated
    shader:send("NUM_LIGHTS", 1)
    shader:send("lightPos", 
        {
            math.max(0.0, math.min(1.0, sun_uvx)),
            math.max(0.0, math.min(1.0, sun_uvy)),
            sun_uvz
        }
    )

    shader:send("lightRadius", SUN_RADIUS)
    shader:send("lightIntensity", SUN_INTENSITY)-- try between [0.0005-0.01] 
    shader:send("lightColour", { 1.0, 1.0, 0.87 })

    shader:send("heightTexelSize", { 1.0/map_pixel_w, 1.0/map_pixel_h })
    --shader:send("refractiveIndex", REFRAC_INDEX)-- 1.33 for water, 1.5 for rock, 1.0 for air
    shader:send("NUM_SAMPLES", NUM_SAMPLES)
    shader:send("BOUNCE_STEPS", BOUNCE_STEPS)
    shader:send("STEPS", STEPS)

    local lg = love.graphics
    lg.setShader(shader) 
        _setColour(14)
        lg.draw(baseTex, 0, 0)
    lg.setShader()
    --love.graphics.draw(baseTex, 0, 0)
end

return M