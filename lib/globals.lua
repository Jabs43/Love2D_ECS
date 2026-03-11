PIXELS_PER_METER=70
GRV=9.8*PIXELS_PER_METER
ACCUMULATOR = 0
FIXED_DT = 1/60
fps_lows = 0
BUTTON_HEIGHT=30
VIRTUAL_WIDTH, VIRTUAL_HEIGHT = 320,180 --fixed game resolution
HALF_VWIDTH,HALF_VHEIGHT = VIRTUAL_WIDTH * 0.5, VIRTUAL_HEIGHT * 0.5
WINDOW_WIDTH, WINDOW_HEIGHT = love.window.getDesktopDimensions()
WINDOW_WIDTH, WINDOW_HEIGHT = WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5 --make the window a bit smaller than the screen
Pico_font = love.graphics.newFont("fonts/pico-8.ttf", 12)

MAP_WIDTH, MAP_HEIGHT = 100, 100
MAP_BUFFER = {}

CAM_XBUFF = HALF_VWIDTH
CAM_YBUFF = HALF_VHEIGHT
RayTraceShader = love.graphics.newShader('lib/shaders/raytracing.glsl')
HeightMapShader = love.graphics.newShader('lib/shaders/heightmapShading.glsl')
DBUG = 0

SUN_RADIUS = 0.0015
SUN_INTENSITY = 0.002
REFRAC_INDEX = 1.33
NUM_SAMPLES = 50
BOUNCE_STEPS = 20
STEPS = 150
---------------------------------
--[[ Entity Component System ]]--
---------------------------------
COMPONENT = {
    NONE      = 0,  -- No components
    POSITION  = 1,  -- (bit 0) [00000001]
    VELOCITY  = 2,  -- (bit 1) [00000010]
    COLLISION = 4,  -- (bit 2) [00000100]
    SPRITE    = 8,  -- (bit 3) [00001000]
    INPUT     = 16, -- (bit 4) [00010000]
    AI        = 32, -- (bit 5) [00100000]
    SWIM      = 64, -- (bit 6) [01000000] 
    FISHBODY  = 128 -- (bit 7) [10000000]
}