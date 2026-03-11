require('lib.helperfunctions')
require('lib.globals')
local Fish = require('lib/GameObjects.fish')
local mapgen = require('lib.map_gen')
local Push = require('lib.push')
local GS = require('lib/GameStates.GameStateManager')
local GlobalSystems = require('lib.GlobalSystems')
local World = require('lib.ECS')
local Camera = require('lib/GameObjects.camera')

local game = {}

function game:init() 
    print("Game Init")
end

-- Localized player entityID pointer
local PlayerID
local Player_x
local Player_y

function game:enter()
    print("Game Enter")
    MAP_WIDTH, MAP_HEIGHT = 800, 800
    MAP_BUFFER = mapgen.generate(MAP_WIDTH, MAP_HEIGHT,40)
    mapgen.print_map(MAP_BUFFER, MAP_WIDTH, MAP_HEIGHT)

    baseTex, baseData = mapgen.generate_heightmap_tex(MAP_BUFFER, MAP_WIDTH, MAP_HEIGHT, 8)
    local w,h = baseData:getDimensions()
    local aspect = w/h
    
    dynamicCanvas = love.graphics.newCanvas(w, h)
    dynamicCanvas:setFilter("linear", "linear")

    RayTraceShader:send("aspectRatioY", aspect)
    RayTraceShader:send("baseHeight", baseTex)
    RayTraceShader:send("dynamicHeight", dynamicCanvas)

    local sx,sy = 200*8,400*8
    PlayerID = Fish:NewEntityPlayer(sx,sy, 0,0, 8,8)
    local wPos = World.data.Pos
    Player_x = wPos.x[PlayerID]
    Player_y = wPos.y[PlayerID]

    for i=1, 200 do 
        Fish:NewEntityAI(sx,sy, 0,0, 8,8, 
        { segs = 10+math.random(15), size = 6+math.random(5)})
    end

    Fish:NewEntityAI(sx,sy, 0,0, 8,8, 
    { segs = 40+math.random(15), size = 10+math.random(5)})

    cam = Camera(Player_x,Player_y)
    CAM_XBUFF, CAM_YBUFF = cam:position()
    --player = Player:new(VIRTUAL_WIDTH/2,VIRTUAL_HEIGHT/2)
end

function game:update(dt)
    -- Update all game objects
    GlobalSystems:Update(dt)

    local wPos = World.data.Pos
    Player_x = wPos.x[PlayerID]
    Player_y = wPos.y[PlayerID]

    local dx,dy = Player_x - cam.x, Player_y - cam.y
    local map_x,map_y = baseData:getWidth(), baseData:getHeight()-- uses base heightmap size
    local cam_xoff,cam_yoff = VIRTUAL_WIDTH/2,VIRTUAL_HEIGHT/2
    CAM_XBUFF, CAM_YBUFF = cam:position()

    cam:move(dx/2, dy/2)

    if Player_x>(map_x-cam_xoff) then 
        cam:lockX(map_x-cam_xoff)
    elseif Player_x<cam_xoff then
        cam:lockX(cam_xoff)
    end

    if Player_y>(map_y-cam_yoff) then 
        cam:lockY(map_y-cam_yoff)
    elseif Player_y<cam_yoff then
        cam:lockY(cam_yoff)
    end
end

function game:draw()
    ----------------------------
    -- 1. Update dynamic canvas
    ----------------------------
    mapgen.updateDynamicHeightmap(dynamicCanvas)
    RayTraceShader:send("dynamicHeight", dynamicCanvas)

    local lg = love.graphics 
    -- 2. reset ALL transforms
    lg.origin()
    lg.setShader()
    lg.setScissor()

    -----------------------------------------------------
    -- 3: WORLD / CAMERA RENDER → MUST BE INSIDE PUSH
    -----------------------------------------------------
    Push:start()
        _clear(14)
        cam:attach()
            mapgen.draw_map(
                RayTraceShader,
                Player_x, Player_y
            )
        cam:detach()
        --love.graphics.print("VIRTUAL: "..VIRTUAL_WIDTH.."x"..VIRTUAL_HEIGHT, 10, 10)
        lg.print("Entity Count:"..World.GetTotalEntityCount(), VIRTUAL_WIDTH-150, 10)
        print_dbg(dbg_print_settings)
    Push:finish()
end

function game:keypressed(key)
    if key == "return" then 
        GS:pushState(pause)
    elseif key == "backspace" then 
        GS:switch(menu)
    end
end

function game:exit()
    World:ClearAll()
    CAM_XBUFF = HALF_VWIDTH
    CAM_YBUFF = HALF_VHEIGHT
end

return game