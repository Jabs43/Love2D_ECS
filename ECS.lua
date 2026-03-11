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
}
------------------------------
--- Lua table that holds all ECS data & functions
local World = {
    -- all of the component data (ffi cstructs) e.g. Pos, Vel, etc
    data = require('lib.BaseComponentsECS'),
    --[[ Entities grouped by their "Signature" (bitmask of components) 
         Example: Archetype[3] = entities with POSITION(1) + VELOCITY(2) components ]]
    Archetypes = {},
    -- Table that holds entities signature & arch_index
    entity_metadata = {},
    -- Total Entity count
    total_entities = 0,
    -- Table of entity ids that can be recycled for making new entities
    free_ids = {},
    -- To keep track of what the next entity ID should be
    next_id = 1,
    -- To keep track of the current world archetypes to see if they changed for system caching
    Archetype_version = 0
}

--------------------------
--|| ENTITY FUNCTIONS ||--
--------------------------

--- Creates a new Entity ID and Initializes it's metadata
--- @return integer id New entity id
function World.NewEntity()
    -- 1. Get an ID (Recycle from free_ids or new)
    local id 
    if #World.free_ids > 0 then 
        id = table.remove(World.free_ids)
    else
        id = World.next_id 
        World.next_id = World.next_id + 1 
    end

    -- Safety check 
    if id > World.data.MAX_ENTITIES then 
        error("ECS: Maximum entity limit reached!")
    end

    -- Inialize metadata
    World.entity_metadata[id] = {
        signature = 0,
        arch_index = -1 -- its position in the archetype list 
    }

    World.total_entities = World.total_entities + 1
    return id 
end

--- Adds entity ID to a archetype based off of the given signature 
--- @param entityID integer
--- @param signature integer a bitwise OR calculation of COMPONENT table elements
function World.AddEntityToArchetype(entityID, signature)
    -- 1. Create archetype if it doesn't exist
    if not World.Archetypes[signature] then 
        World.Archetypes[signature] = {
            ids = {}, 
            count = 0,
            signature = signature 
        }
        -- Increment version because a brand new Archetype layout exists
        World.Archetype_version = World.Archetype_version + 1
    end

    -- Add entity to archetype
    local arch = World.Archetypes[signature]
    arch.count = arch.count + 1
    arch.ids[arch.count] = entityID

    -- Update entity metadata
    local meta = World.entity_metadata[entityID]
    meta.signature = signature
    meta.arch_index = arch.count
end


--- Moves Entity from one archetype to another by swaping its signature.
--- Mainly used for adding and removing components for entity IDs.
--- @param entityID integer
--- @param old_sig integer The old signature
--- @param new_sig integer The new signature
function World.MoveEntity(entityID, old_sig, new_sig)
    -- 1. Remove from the old Archetype list (using SWAP & POP)
    if old_sig ~= 0 then 
        local old_arch = World.Archetypes[old_sig]
        local idx = World.entity_metadata[entityID].arch_index 

        -- SWAP & POP logic
        if idx < old_arch.count then 
            local last_id = old_arch.ids[old_arch.count]
            old_arch.ids[idx] = last_id 
            World.entity_metadata[last_id].arch_index = idx 
        end

        old_arch.ids[old_arch.count] = 0
        old_arch.count = old_arch.count - 1 
    end

    -- 2. Add to the new Archetype 
    World.AddEntityToArchetype(entityID, new_sig)

    -- 3. Update the Global version so Systems refresh their caches
    World.Archetype_version = World.Archetype_version + 1 
end

--- Removes and recycles entity ID
--- @param entityID integer The entity ID you would like to remove
function World.DestroyEntity(entityID)
    -- Remove from Archetype
    local meta = World.entity_metadata[entityID]
    if not meta or meta.signature == 0 then return end -- Entity already dead or doesn't exist

    local signature = meta.signature
    local arch = World.Archetypes[signature]
    local idx = meta.arch_index -- Where this entity sits in arch.ids

    -- 1. SWAP: last entity to the removed index
    if idx < arch.count then 
        local last_entity_id = arch.ids[arch.count]
        -- Move the last ID into the current ID's slot 
        arch.ids[idx] = last_entity_id 

        -- Update the metadata of the moved entity so it knows its new index 
        World.entity_metadata[last_entity_id].arch_index = idx 
    end

    -- 2. Clean up
    arch.ids[arch.count] = 0 -- Clear the slot 
    arch.count = arch.count - 1 

    -- 3. Reset Entity Metadata
    meta.signature = 0
    meta.arch_index = -1

    -- 4. Recycle the ID 
    World.free_ids[#World.free_ids + 1] = entityID
    World.total_entities = World.total_entities - 1 

    -- 5. IMPORTANT: Notify system to refresh their caches
    World.Archetype_version = World.Archetype_version + 1
end

--- Finds entitys signature from its metadata: function will return either a signature OR nil.
--- @param entityID integer The entity that you want to get the signature from 
--- @return integer signature
function World.GetEntitySignature(entityID)
    local meta = World.entity_metadata[entityID]
    return meta and meta.signature or nil
end

--- Gets the Worlds current total entity count
--- @return integer World.total_entities 
function World.GetTotalEntityCount()
    return World.total_entities or 0
end


--- Gets the Worlds current total entity count for a specific archetype 
--- @param entityID integer A entity with the current archetype/signature you want the count from
--- @return integer arch.count The entity count for specific archetype
function World.GetEntityCountOfArchetype(entityID)
    local meta = World.entity_metadata[entityID]
    if not meta then return 0 end 

    local arch = World.Archetype[meta.signature]
    return arch and arch.count or 0
end

-----------------------------
--|| COMPONENT FUNCTIONS ||--
-----------------------------

--- Adds a component to entityID
--- @param entityID integer The entity you would like to add the component to 
--- @param componentBit integer The components Bit signature stored inside the Global table : COMPONENT
function World.AddComponent(entityID, componentBit)
    local meta = World.entity_metadata[entityID]
    local old_signature = meta.signature

    -- Use bitwise OR to add the bit
    local new_signature = bit.bor(old_signature, componentBit)

    -- If the entity already had this component, do nothing
    if old_signature == new_signature then return end 

    -- Move from old Archetype list to the new one 
    World.MoveEntity(entityID, old_signature, new_signature)
end

--- Removes a component from entityID
--- @param entityID integer The entity you would like to remove the component from
--- @param componentBit integer The components Bit signature stored inside the Global table : COMPONENT
function World.RemoveComponent(entityID, componentBit)
    local meta = World.entity_metadata[entityID]
    local old_signature = meta.signature 

    -- Use bitwise AND and NOT to clear the bit 
    local new_signature = bit.band(old_signature, bit.bnot(componentBit))

    -- If the entity didn't have this component, do nothing 
    if old_signature == new_signature then return end 

    -- Move from the old Archetype list to the new one 
    World.MoveEntity(entityID, old_signature, new_signature)
end

--------------------------
--|| HELPER FUNCTIONS ||--
--------------------------

--- Helper to get all Archetypes that matches a required component bitmask.
--- Usually utilised for caching the relevent archetypes for a given system
--- @param requiredBits integer a bitwise OR combination or all the relevent COMPONENT
--- @return table matches A table of the relevent archetypes 
function World.query(requiredBits)
    local matches = {}
    for signature, arch in pairs(World.Archetypes) do 
        if bit.band(signature, requiredBits) == requiredBits then 
            matches[signature] = arch
        end
    end
    return matches
end

local ffi = require("ffi")
--- Helper to clear all entities and components from ECS 
function World:ClearAll()
    -- 1. Reset Metadata
    self.Archetypes = {}
    self.entity_metadata = {}
    self.free_ids = {}
    self.next_id = 1
    self.total_entities = 0
    
    -- 2. Increment version so Systems refresh their caches
    self.Archetype_version = self.Archetype_version + 1

    -- 3. Fast C-style memory clearing
    -- We loop through each component struct in World.data
    for _, struct in pairs(self.data) do
        -- Check if it's an FFI object (cdata) before filling
        if type(struct) == "cdata" then
            -- ffi.fill(pointer, size_in_bytes, value)
            -- Value 0 sets floats to 0.0, ints to 0, and bools to false
            ffi.fill(struct, ffi.sizeof(struct), 0)
        end
    end
end

-------------------------------------------------------
--|| COMPONENT DATA MODIFICATION/SETTING FUNCTIONS ||--
-------------------------------------------------------

--- Sets the entity's position 
--- @param id integer the ID of the entity that you would like to modify
--- @param x float the new x position 
--- @param y float the new y position
function World:SetEntityPos(id, x, y)
    self.data.Pos.x[id] = x 
    self.data.Pos.y[id] = y 
end

--- Sets the entity's Velocity
--- @param id integer The ID of the entity that you would like to modify
--- @param dx float The x velocity direction 
--- @param dy float The y velocity direction
--- @param spd float The base speed that the entity can move at in pixels per second
function World:SetEntityVel(id, dx, dy, spd)
    self.data.Vel.dx[id] = dx 
    self.data.Vel.dy[id] = dy 
    self.data.Vel.spd[id] = spd 
end

--- Sets the entity's 2D collision box
--- @param id integer The ID of the entity that you would like to modify
--- @param ox float The x off-set for the hitbox x origin
--- @param oy float The y off-set for the hitbox y origin
--- @param w float The pixel width of hitbox 
--- @param h float The pixel height of hitbox
function World:SetEntityCollision(id, ox, oy, w, h)
    self.data.RecHitbox.ox[id] = ox 
    self.data.RecHitbox.oy[id] = oy
    self.data.RecHitbox.w[id] = w
    self.data.RecHitbox.h[id] = h
end

--- Sets the entity's controll settings
--- @param id integer The ID of the entity that you would like to modify
--- @param is_controlled boolean Sets if entity is controlled or not
function World:SetEntityControlls(id, is_controlled)
    self.data.Controlls.active[id] = is_controlled
end

--- Sets the entity's AI settings 
--- @param id integer The ID of the entity that you would like to modify
--- @param timer float The AI timer 
--- @param dir float The AI direction used for movement behaviour in the AISystem
function World:SetEntityAi(id, timer, dir)
    self.data.Ai.timer[id] = timer 
    self.data.Ai.dir[id] = dir 
end

--- Sets the entity's Sprite settings 
--- @param id integer The ID of the entity that you would like to modify
--- @param img string The image file path for the sprite
--- @param scale float The scale of the sprite
function World:SetEntitySprite(id, img, scale)
    self.data.Sprite.img[id] = img 
    self.data.Sprite.scale[id] = scale 
end

return World