# Love2D_ECS

A small general **Entity Component System ( ECS )** framework tailored for Love2D. It uses Bitmasks for fast component filtering and **FFI (Foreign Function Interaface)** for memory-efficient data storage using a Structure of Arrays (SoA) approach.
## 1. Core Concepts
**Bitmask Signatures**
Each Component is represented by a bit (power of 2). An entity's "Signature" is a single integer created by bitwise `OR`ing these values. This allows the system to check if an entity has a specific set of components almost instantaneously.

**Archetypes**
Instaed of iterating through every entity, this framework groups entities with the exact same component signatures into **Archetypes**. This makes system iteration extremely fast.

## 2. Component Definitions
The `COMPONENT` table defines the available bits. To combine components, use `bit.bor()`.

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

`World.DestroyEntity(id)`

Removes an entity from its archetype and the world.
* Optimziation: Uses **Swap & Pop** logic to maintain packed arrays within archetypes.
* **Cleanup:** Increments `Archetype_version` so systems know how to refresh their caches.
---

`World.GetTotalEntityCount()`

Returns the total number of active entities in the world.

---
## 4. Component Management

`World.AddComponent(entityID, componentBit)`

Adds a component to an entity.
* This triggers `World.MoveEntity`, migrating the entity to new Archetype that matches the updated signature.

---

`World.RemoveComponent(entityID, componentBit)`

Removes a component from an entity and moves it to the appropriate Archetype.

---
## 5. System Integration & Querying 

To create a System (e.g. a Movement System), you need to query the world for specific component requirements.

`World.query(requiredBits)`

Returns a table of all Archetypes that contain at least `requiredBits`.
* **Example:** `World.query(bit.bor(COMPONENT.POSITION, COMPONENT.VELOCITY))` returns all entities that can move.
**[!TIP] Performance Hint:** Don't call `query()` every frame. Store the results and only re-query if `World.Archetype_version` has changed.

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
```lua
local ecs = require("ECS.lua")

-- 1. Create an entity
local player = ecs.NewEntity()

-- 2. Add components
ecs.AddComponent(player, COMPONENT.POSITION)
ecs.AddComponent(player, COMPONENT.VELOCITY)

-- 3. Initalize data
ecs:SetEntityPos(player, 400, 300)
ecs:SetEntityVel(player, 1, 0, 100) -- Moving right at 100px/s

-- 4. In your update loop
function love.update(dt)
    local moveQuery = bit.bor(COMPONENT.POSITION, COMPONENT.VELOCITY)
    local archetypes = ecs.query(moveQuery)

    for sig, arch in pairs(archetypes) do 
        for i = 1, arch.count do 
            local id = arch.ids[i]
            -- Access FFI data directly for max speed
            ecs.data.Pos.x[id] = ecs.data.pos.x[id] + ecs.data.vel.dx * ecs.data.vel.spd[id] * dt
            ecs.data.Pos.y[id] = ecs.data.pos.y[id] + ecs.data.vel.dy * ecs.data.vel.spd[id] * dt
        end
    end
end
```
