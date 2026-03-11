local ffi = require("ffi")

--[[ Base components for the ECS. 
     These are the components that will be used by most entities in the game. 
     They are defined as C structs for performance reasons. ]]
ffi.cdef[[
// We define the constant in C so it can be used inside the structs
    enum { MAX_ENTITIES = 10000 };
    enum { MAX_SEGS = 200 };

    typedef struct {
        float x[MAX_ENTITIES];
        float y[MAX_ENTITIES];
    } PositionComponent;

    typedef struct {
        float ox[MAX_ENTITIES];
        float oy[MAX_ENTITIES];
        float w[MAX_ENTITIES];
        float h[MAX_ENTITIES];
    } RectangleComponent;

    typedef struct {
        float dx[MAX_ENTITIES];
        float dy[MAX_ENTITIES];
        float spd[MAX_ENTITIES];
    } VelocityComponent;

    typedef struct {
        bool active[MAX_ENTITIES];
    } ControllsComponent;

    typedef struct {
        float timer[MAX_ENTITIES];
        float dir[MAX_ENTITIES];
    } AiComponent;
]]

-- Note: We use "MAX_ENTITIES" from the enum defined above
return {
    MAX_ENTITIES = 10000,
    Pos       = ffi.new("PositionComponent"),
    RecHitbox = ffi.new("RectangleComponent"),
    Vel       = ffi.new("VelocityComponent"),
    Controlls = ffi.new("ControllsComponent"),
    Ai        = ffi.new("AiComponent")
}