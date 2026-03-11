io.stdout:setvbuf("no")
require('lib.helperfunctions')
require('lib.globals')

local World = require('lib.ECS')
local Push = require('lib.push')
local profiler = require('profile')
profiler.setclock(love.timer.getTime)

local frame_count = 0
local frame_count1 = 0
local averagedt = {}
local new_report = "Profiling..."
local report_interval = 100

-- setting up Game State Manager
local GS = require('lib/GameStates.GameStateManager')
-- Define states
menu = require('lib/GameStates/states.menu')
game = require('lib/GameStates/states.game')
pause = require('lib/GameStates/states.pause')

local lg = love.graphics
function love.load()
    -- Enable debugger 
    debugMode = false 
    if arg[#arg] == "debug" then 
        require('lldebugger').start()
        profiler.start()
    end
    -- overrides the love error handler
    local loveErrorhandler = love.errorhandler or love.errhand 
    function love.errorhandler(msg)
        if debugMode then 
            error(msg, 2)
        else 
            return loveErrorhandler(msg)
        end
    end
    -- Sharpens game image:
    lg.setDefaultFilter("nearest","nearest", 1)
    -- applying game resolution
    Push:setupScreen(
    VIRTUAL_WIDTH, VIRTUAL_HEIGHT, 
    WINDOW_WIDTH, WINDOW_HEIGHT,
    {
        fullscreen = false,
        vsync = false,
        resizable = true,
        canvas = true
    })

    GS:switch(menu)
end

function love.resize(w,h)
    Push:resize(w,h)
end

function love.keypressed(key)
    GS:keypressed(key)
end


function love.update(dt)
    local isDown = love.keyboard.isDown
    -- quit
    if isDown("escape") then love.event.quit() end

    -- Light settings
    if isDown("r") then SUN_RADIUS = SUN_RADIUS + .0001
    elseif isDown("t") then SUN_RADIUS = SUN_RADIUS - .0001 end
    
    if isDown("f") then SUN_INTENSITY = SUN_INTENSITY + .0001
    elseif isDown("g") then SUN_INTENSITY = SUN_INTENSITY - .0001 end
    
    if isDown("v") then REFRAC_INDEX = REFRAC_INDEX + .01
    elseif isDown("b") then REFRAC_INDEX = REFRAC_INDEX - .01 end
    
    if isDown("w") then NUM_SAMPLES = NUM_SAMPLES + 1 
    elseif isDown("e") then NUM_SAMPLES = NUM_SAMPLES - 1 end
    
    if isDown("x") then STEPS = STEPS + 1 
    elseif isDown("c") then STEPS = STEPS - 1 end
    
    if isDown("s") then BOUNCE_STEPS = BOUNCE_STEPS + 1 
    elseif isDown("d") then BOUNCE_STEPS = BOUNCE_STEPS - 1 end

    local last_entityID = World.GetTotalEntityCount()
    if isDown("p") then World.DestroyEntity(last_entityID) end

    frame_count = frame_count + 1
    frame_count1 = frame_count1 + 1 

    if frame_count1 % 100 == 0 then 
        local lowest = 1.0 / love.timer.getDelta()
        for i=1, #averagedt do 
            local current = averagedt[i]
            lowest = current < lowest and current or lowest
        end
        averagedt = {}
        fps_lows = lowest
    else
        averagedt[#averagedt+1] = 1.0 / love.timer.getDelta()
    end

    ACCUMULATOR = ACCUMULATOR + dt
    DRAG=math.pow(0.1, FIXED_DT)

    while ACCUMULATOR >= FIXED_DT do 
        GS:update(FIXED_DT)
        ACCUMULATOR = ACCUMULATOR - FIXED_DT
    end

    -- Every 100 frames: stop, collect report, start
    if arg[#arg] == "debug" then 
        if frame_count % report_interval == 0 then 
            profiler.stop()
            new_report = profiler.report(20)-- Shows top 20 function
            profiler.reset()
            profiler.start()
        end
    end
end


function love.draw()
    --_clear(16)

    lg.setLineStyle("rough")

    -- Set the font to custom font
    lg.setFont(Pico_font)

    GS:draw()

    if arg[#arg] == "debug" then 
        if frame_count % report_interval == 0 then
            print(new_report)
        end
    end
end
