# Love2D_ECS

A small general **Entity Component System ( ECS )** library tailored for Love2D. It uses Bitmasks for fast component filtering and **FFI (Foreign Function Interaface)** for memory-efficient data storage using a Structure of Arrays (SoA) approach.
## 1. Core Concepts
**Bitmask Signatures**
Each Component is represented by a bit (power of 2). An entity's "Signature" is a single integer created by bitwise `OR`ing these values. This allows the system to check if an entity has a specific set of components almost instantaneously.

**0-Based FFI Memory**
To get a higher level of performance, all component data, metadata, and archetype groupings are stored in pre-allocated FFI C-Structs. Because of this, **Entity IDs and Archetype loops are strictly 0-based.**

**Archetypes & The Transition Graph** 
Entities with the exact same component signatures are grouped into **Archetypes**. When a component is added or removed, the ECS utilizes a cached "Edge Graph" (C-pointers) to instantly move the entity to its new archetype without recalculating bitwise math or doing table lookups.

## 2. Component Definitions
The `COMPONENT` table defines the available bits. To combine components, use `bit.bor()`. (Note: FFI structs cannot store Lua strings, so components like `SPRITE` rely on integer IDs or external Lua tables).

| Constant | Bit Value | Binary Representation
| ----------- | ----------- | ----------- |
| `NONE` | 0 | `0000000`
| `POSITION` | 1 | `0000001`
| `VELOCITY` | 2 | `0000010`
| `COLLISION` | 4 | `0000100`
| `SPRITE` | 8 | `0001000`
| `INPUT` | 16 | `0010000`
| `AI` | 32 | `0100000`

## 3. Entity Management 
`World.NewEntity()`

Creates a new entity ID.
* **Recycling:** Automatically reuses IDs from `free_ids` to prevent ID bloat. 
* **Returns:** `integer` (The new entity ID).
---

`World.Spawn(signature)`

A fast helper function that creates a new entity and immediately places it into the target Archetype based on the provided signature.
* **Returns:** `integer` (The new entity ID).
---

`World.DestroyEntity(id)`

Removes an entity from its archetype and recycles the ID.
* Optimziation: Uses **0-based Swap & Pop** logic to maintain packed contiguous arrays within archetypes.
* **Cleanup:** Increments `Archetype_version` so systems know how to refresh their caches.
---

`World.GetTotalEntityCount()`

Returns the total number of active entities in the world.

---
## 4. Component Management

`World.AddComponent(entityID, componentBit)`

Adds a component to an entity. Uses the Archetype Edge cache for `O(1)` transitions.

---

`World.RemoveComponent(entityID, componentBit)`

Removes a component from an entity and moves it to the appropriate Archetype via Edge pointers.

---
## 5. System Integration & Querying 

To create a System (e.g. a Movement System), you need to query the world for specific component requirements.

`World.query(requiredBits, forbiddenBits)`

Returns a contiguous, 1-based Lua array of **FFI Archetype Pointers** that contain all `requiredBits` and none of the `forbiddenBits`(optional).
* **Example:** `World.query(bit.bor(COMPONENT.POSITION, COMPONENT.VELOCITY), bit.bor(COMPONENT.COLLISION))` returns all entities that can move without collision.
**[!IMPORTANT] Performance Rule:** NEVER call `query()` every frame. Store the results and only re-query if `World.Archetype_version` has changed.

---
## 6. Data Modification (Setters)
These functions modify the raw FFI C-struct data stored in `World.data`.

| Function | Parameters | Description
| ----------- | ----------- | ----------- |
| `SetEntityPos` | `id, x, y` | Updates X and Y coordinates
| `SetEntityVel` | `id, dx, dy, spd` | Updates direction and movement speed.
| `SetEntityCollision` | `id, ox, oy, w, h` | Defines the rectangular hitbox dimensions and offset.
| `SetEntitySprite` | `id, img, scale` | Sets the image path and draw scale.
| `SetEntityAi` | `id, timer, dir` | Updates AI-specific logic variables.

---
## 7. Example Usage
**Writing a High-Performance System:**
Because data is stored in C-structs, Systems must localize their FFI pointers and use 0-based loops for maximum LuaJIT optimization.
```lua
local ecs = require("ECS.lua")
local bor = bit.bor

-- 1. Define the System
local MovementSystem = {
    filter = bor(COMPONENT.POSITION, COMPONENT.VELOCITY),
    cache = {},
    last_version = -1
}

-- 2. System Update loop
function MovementSystem:Update(dt)
    -- Only re-query if an entity was spawned/destroyed or changed components 
    if self.last_version ~= ecs.Archetype_version then 
        self.cache = ecs.query(self.filter)
        self.last_version = ecs.Archetype_version 
    end

    -- Localize FFI pointers outside the loop for speed 
    local posX = ecs.data.Pos.x 
    local posY = ecs.data.Pos.y 
    local velDX = ecs.data.Vel.dx 
    local velDY = ecs.data.Vel.dy 
    local velSpd = ecs.data.Vel.spd

    -- Iterate over cached archetypes (1-based lua table)
    for j = 1, #self.cache do 
        local arch = self.cache[j]
        local ids = arch.ids

        -- Iterate over entities in this archetype (0-based FFI ARRAY)
        for i = 0, arch.count - 1 do 
            local id = ids[i]

            -- Direct C-memory math (Zero Lua overhead)
            posX[id] = posX[id] + (velDX[id] * velSpd[id] * dt)
            posY[id] = posY[id] + (velDY[id] * velSpd[id] * dt)
        end
    end
end
```
---
**Setting up ECS inside main**
```lua
local ecs = require("ECS.lua")
local InputSystem = require("InputSystem.lua")
local MovementSystem = require("MovementSystem.lua")
local RenderSystem = require("RenderSystem.lua")
local bor = bit.bor

local PlayerID
function love.load()
    -- Init ecs archetype[0] !IMPORTANT
    ecs.Init()

    ---------------------------------------
    -- Example player spawn 
    -- 1. Create entitys base signature
    local player_sig = bit.bor(
        COMPONENT.POSITION,
        COMPONENT.VELOCITY,
        COMPONENT.INPUT
    )
    -- 2. Create entityID with base signature(archetype)
    PlayerID = ecs.Spawn(base_sig)
    -- 3. Set init values 
    ecs.SetEntityPos(PlayerID, 100, 100)
    ecs.SetEntityVel(PlayerID, 0, 0, 70)
    ecs.SetEntityControlls(PlayerID, true)
    ---------------------------------------
end

-- System Update loop
function love.update(dt)
    InputSystem:Update(dt)
    MovementSystem:Update(dt)
end

function love.draw()
    RenderSystem:Draw()
end

```
