--| colour functions |--
palette = {
    {140,143,174},
    {88,69,99},
    {62,33,55},
    {154,99,72},
    {215,155,125},
    {245,237,186},
    {192,199,65},
    {100,125,52},
    {228,148,58},
    {157,48,59},
    {210,100,113},
    {112,55,127},
    {126,196,193},
    {52,133,157},
    {23,67,75},
    {31,14,28}
}

function _setColour(col,_alpha)
    local colour = (col ~= nil) and palette[col] or {255,255,255}
    local red = colour[1]
    local green = colour[2]
    local blue = colour[3]
    local alpha = _alpha or 255

    return love.graphics.setColor(red/255,green/255,blue/255,alpha/255)
end

function _clear(col)
    local colour = palette[col]
    local red = colour[1]
    local green = colour[2]
    local blue = colour[3]
    local alpha = 255

    return love.graphics.clear(red/255,green/255,blue/255,alpha/255,true,true)
end

--| grid/table functions |--
function idx(x, y, w) return (y - 1) * w + x end

-- Create a blank 1-D grid (table) with length w*h and initial value (0/1)
function blankgrid(default, w, h)
    local grid={}
    for i=1, w*h do 
        grid[i] = default
    end
    return grid
end

function list_to_grid(list, w, h)
    local g = blankgrid(false, w, h)
    for i=1,#list do
        local p = list[i]
        g[idx(p.x, p.y, w) - 1] = true
    end
    return g
end

function get_maptile(m, x, y, w)-- Get cell
    if x < 1 or y < 1 or x > w then return true end
    return m[(y - 1) * w + x]
end

function set_maptile(m, x, y, w, h, val)
    if x < 1 or y < 1 or x > w or y > h then return end
    m[(y - 1) * w + x] = val 
end

-- Shortcut versions that take a flat index when available
function idx_to_xy(i, w)
    local y = math.floor((i - 1) / w) + 1
    local x = i - (y - 1) * w
    return x, y
end

function clear_table(table)
    for k in pairs(table) do 
        table[k] = nil 
    end
end

function clear_grid(grid)
    for i=1,#grid do
        grid[i] = false
    end
end

--| math functions |--
function calc_hypotenuse(x,y,x2,y2)
    local delta_x = x - x2
    local delta_y = y - y2
    return math.sqrt(delta_x*delta_x + delta_y*delta_y)
end

function sign(v)
    return v < 0 and -1 or (v > 0 and 1 or 0)
end

function mid(a, b, c)
    return math.max(math.min(a, b), math.min(b, c))
end

function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function normalise(x,y)
    local magnitude = math.sqrt(x^2 + y^2)
    local nx, ny
    -- Handle the case where the magnitude is zero 
    if magnitude == 0 then
        nx = 0
        ny = 0
    else 
        nx = x / magnitude
        ny = y / magnitude
    end
    return nx, ny
end

function round(num)
    return math.floor(num + 0.5 * sign(num))
end

function size_gen(i,size,segs1)
        return math.abs(size * math.sin((3.14/(segs1)) * (i+1)))
end

function draw_rotated_sine_wave(x, y, direction, length, amp, frequency, phase, samples,c)
    -- clamp samples between 2 and length
    samples = math.max(2, math.min(samples, length))

    local sa = math.sin(direction)
    local ca = math.cos(direction)

    -- set color if provided
    _setColour(c)

    -- precompute points for the line strip
    local pts = {}

    for t = 0, length, length / (samples - 1) do
        local sint = amp * math.sin(frequency * t + phase)
        local sx = ca * t - sa * sint
        local sy = ca * sint + sa * t

        table.insert(pts, x + sx)
        table.insert(pts, y + sy)
    end

    love.graphics.line(pts)
end

function calc_rotated_sine_wave_vec(direction, amp, frequency, phase)
    local t = love.timer.getTime()

    -- wave displacement along perpendicular axis
    local wave = amp * math.sin(frequency * t + phase)

    -- rotate wave by direction
    local sa = math.sin(direction)
    local ca = math.cos(direction)

    -- final vector = ONLY oscillation, no t-based drift!
    local sx = -sa * wave -- perpendicular wiggle
    local sy =  ca * wave

    return sx, sy
end

-- Define the debug settings table.
-- The second element is now an ANONYMOUS FUNCTION that returns the live value.
dbg_print_settings = {
    {"fps: ",        love.timer.getFPS}, -- Store the function itself
    {"fps %1.0L: ",  function() return string.format("%05.1f", fps_lows) end},
    {"SUN_R: ",      function() return SUN_RADIUS end},
    {"SUN_I: ",      function() return SUN_INTENSITY end},
    {"REFRAC: ",     function() return REFRAC_INDEX end}, 
    {"NUM_SMPS: ",   function() return NUM_SAMPLES end},
    {"BNCE_STEPS: ", function() return BOUNCE_STEPS end},
    {"STEPS: ",      function() return STEPS end}
}

function print_dbg(dbgs)
    _setColour(13, 200)
    
    for i=1,#dbgs do 
        local d = dbgs[i]
        local str = d[1]
        local value_func = d[2]  -- This is now a function
        
        -- Call the function to get the current value!
        local val = value_func() 
        
        -- Calculate Y position more robustly
        local y_pos = 12 * (i-1)
        
        love.graphics.print(str .. val, 0, y_pos)
    end
end

