require('lib.helperfunctions')
require('lib.globals')
local Fish = require('lib/GameObjects.fish')
local GS = require('lib/GameStates.GameStateManager')
local GlobalSystems = require('lib.GlobalSystems')
local World = require('lib.ECS')
local Push = require('lib.push')

local menu = {}
local buttons = {}

local function newButton(text, fn)
    return {
        text = text,
        fn = fn,
        now = false,
        last = false
    }
end

function init_buttons()
    table.insert(buttons, newButton(
        "Start Game",
        function()
            print("Starting game")
            menu:keypressed("start")
        end))
    table.insert(buttons, newButton(
        "Load Game",
        function()
            print("Load game")
        end))
    table.insert(buttons, newButton(
        "Settings",
        function()
            print("Settings")
        end))
    table.insert(buttons, newButton(
        "Exit",
        function()
            love.event.quit(0)
        end))
end

function draw_buttons(mx,my)
    if not mx or not my then mx, my = -math.huge, -math.huge end--makes sure that mx and my arent nil
    local lg = love.graphics
    local margin = 10
    local total_h = (BUTTON_HEIGHT+margin) * #buttons
    local cursor_y = 0
    for i, button in ipairs(buttons) do 
        button.last = button.now
        local button_w = Pico_font:getWidth(button.text)+margin
        local bx = (VIRTUAL_WIDTH*0.5)-(button_w*0.5)
        local by = (VIRTUAL_HEIGHT*0.5)-(total_h*0.5) + cursor_y
        local col = 3
        local hot = mx > bx and mx < bx + button_w and 
                    my > by and my < by + BUTTON_HEIGHT
        if hot then 
            col = 2
        end
        button.now = love.mouse.isDown(1)
        if button.now and not button.last and hot then 
            button.fn()
        end
        _setColour(col)
        lg.rectangle(
            "fill",
            bx,
            by,
            button_w,
            BUTTON_HEIGHT,
            button_w/20,
            BUTTON_HEIGHT/4
        )
        _setColour(1)
        local textW = Pico_font:getWidth(button.text)
        local textH = Pico_font:getHeight(button.text)
        lg.print(
            button.text,
            Pico_font,
            (VIRTUAL_WIDTH*0.5)-textW*0.5,
            by + textH * 0.5
        )
        cursor_y = cursor_y + (BUTTON_HEIGHT+margin)
    end
end

-- Localized player entityID pointer
local PlayerID = 0

function menu:init() 
    print("Menu Init")
    init_buttons()
end

function menu:enter()
    print("Menu Enter")
    PlayerID = Fish:NewEntityPlayer(VIRTUAL_WIDTH/2,VIRTUAL_HEIGHT/2, 0,0, 8,8)
end

function menu:update(dt)
    -- Update all game objects
    GlobalSystems:Update(dt)

    if love.keypressed("space") then 
        GS:switch(game) -- switch to game state
    end

    mx, my = Push:toGame(love.mouse.getPosition())
end

function menu:draw()
    local lg = love.graphics
    -- 1. reset ALL transforms
    lg.origin()
    lg.setShader()
    lg.setScissor()

    Push:start()

        _clear(16)

        -- Draw all game objects
        GlobalSystems:Draw()

        if buttons then 
            draw_buttons(mx,my)
        end
        --love.graphics.print("VIRTUAL: "..VIRTUAL_WIDTH.."x"..VIRTUAL_HEIGHT, 10, 10)
        --love.graphics.print("fish ID:"..fish, 10, 10)
        print_dbg(dbg_print_settings)
        lg.print("Entity Count:"..World.GetTotalEntityCount(), VIRTUAL_WIDTH-150, 10)
    Push:finish()
end

function menu:keypressed(key)
    if key == "start" then 
        GS:switch(game) -- switch to game state
    end
end

function menu:exit()
    World:ClearAll()
    CAM_XBUFF = HALF_VWIDTH
    CAM_YBUFF = HALF_VHEIGHT
end

return menu
