require('lib.helperfunctions')
require('lib.globals')
require('lib/GameObjects.fish')
local Push = require('lib.push')
local GS = require('lib/GameStates.GameStateManager')
local Camera = require('lib/GameObjects.camera')

local pause = {}

function pause:enter() 
    print("Pause enter") 
end 

function pause:draw()
    local lg = love.graphics
    -- 1. reset ALL transforms
    lg.origin()
    lg.setShader()
    lg.setScissor()

    Push:start()
        -- ONLY overlay elements
        _setColour(16,150)
        lg.rectangle("fill",0,0,VIRTUAL_WIDTH,VIRTUAL_HEIGHT)
        _setColour(11)
        local xoff = (VIRTUAL_WIDTH - (12 * 22))
        lg.print("Paused - ESC to resume", xoff, (VIRTUAL_HEIGHT/2)-10)
        --love.graphics.print("Virtual: "..Push:getWidth().."x"..Push:getHeight(), 10, 25)
    Push:finish()
end 

function pause:update(dt)
end

function pause:keypressed(key)
    if key == "return" then 
        GS:popState()
    end
end

return pause