local ffi = require("ffi")

-- We define the constant in C so it can be used inside the structs
ffi.cdef[[
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
        bool can_swim[MAX_ENTITIES];
    } SwimComponent;

    // This represents the data for ONE fish
    typedef struct {
        float rx[MAX_SEGS];
        float ry[MAX_SEGS];
        float ru[MAX_SEGS];
        float rv[MAX_SEGS];
        float nx[MAX_SEGS];
        float ny[MAX_SEGS];
        float segsize[MAX_SEGS];
    } FishPhysics;

    // This holds the data for ALL possible fish
    typedef struct {
        FishPhysics items[MAX_ENTITIES];
        int   segs[MAX_ENTITIES];
        float seglen[MAX_ENTITIES];
        float bouyancy[MAX_ENTITIES];
    } FishBodyComponent;

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
    Swim      = ffi.new("SwimComponent"),
    FishBody  = ffi.new("FishBodyComponent"),
    Ai        = ffi.new("AiComponent")
}