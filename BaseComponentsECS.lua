local ffi = require("ffi")

ffi.cdef[[
// We define the constant in C so it can be used inside the structs
    enum { MAX_ENTITIES = 5000 };
    enum { MAX_SEGS = 200 };
    enum { MAX_ARCHETYPES = 32 };

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

    typedef struct {
        PositionComponent Pos;
        RectangleComponent RecHitbox;
        VelocityComponent Vel;
        ControllsComponent Controlls;
        AiComponent Ai;
    } ECSData;

    typedef struct {
        void* add[32]; // Cache for adding components
        void* remove[32]; // Cache for removing components 
    } Edges;

    typedef struct {
        int ids[MAX_ENTITIES];
        int count;
        int signature;
        Edges edges; // Cache for archetypes transitions
    } Archetype;

    typedef struct {
        Archetype archetypes[MAX_ARCHETYPES];
    } ArchetypeTable;

    typedef struct {
        int signature;
        int arch_index;
    } EntityMetadata;

    typedef struct {
        EntityMetadata entity_metadata[MAX_ENTITIES];
    } EntityMetadataTable;
]]

return ffi.new("ECSData")