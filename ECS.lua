local ffi = require("ffi")
local MAX_ENTITIES = 5000
local MAX_ARCHETYPES = 256

---------------------------------
--[[ Entity Component System ]]--
---------------------------------
--- This is a table of component bit signatures.
--- It's used for adding/removing component from entities
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

    -- (The Individual ID card) This is a table that holds the metadata for each entity ID, 
    -- such as its current signature and archetype index. 
    -- This allows for O(1) access to an entity's signature and archetype when adding/removing components 
    -- or destroying entities.
    arch_table = ffi.new("ArchetypeTable"),

    -- Table that holds entities signature & arch_index
    entities = ffi.new("EntityMetadataTable"),

    -- (The Group Map) this is a table that maps signatures to their archetype index in the Archetypes array for O(1) access to archetypes based on signature.
    signature_to_index = {},

    -- Total number of Archetype layouts that exist (used for caching archetype queries in systems)
    Archetype_count = 0,

    -- Total Entity count
    total_entities = 0,

    -- Table of entity ids that can be recycled for making new entities
    free_ids = {},

    -- To keep track of what the next entity ID should be
    next_id = 1,

    -- To keep track of the current world archetypes to see if they changed for system caching
    Archetype_version = 0
}

function World:Init()
    self.signature_to_index[0] = 0
    local null_arch = self.arch_table.Archetypes[0]
    null_arch.signature = 0
    null_arch.count = 0
    self.Archetype_count = 1
end

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
    if id >= MAX_ENTITIES then 
        error("ECS: Maximum entity limit reached!")
    end

    World.total_entities = World.total_entities + 1
    return id 
end

--- For future use: Gets the archetype table for a given signature. Mainly used for debugging and testing purposes.
--- @param signature integer The bitmask signature of the archetype you want to get
--- @return table archetype The archetype table with ids, count, and signature
function World.GetArchetype(signature)
    local idx = World.signature_to_index[signature]
    
    if not idx then
        -- Safety check for archetype limit
        if World.Archetype_count >= MAX_ARCHETYPES then 
            error("ECS: Maximum archetype limit reached! Cannot create new archetype for signature: " .. signature)
        end
        
        -- New archetype discovered!
        idx = World.Archetype_count
        World.Archetype_count = World.Archetype_count + 1
        
        local arch = World.arch_table.Archetypes[idx]
        arch.signature = signature
        arch.count = 0
        
        -- Map it for future lookups
        World.signature_to_index[signature] = idx
        return arch
    end
    
    return World.arch_table.Archetypes[idx]
end

--- Adds entity ID to a archetype based off of the given signature 
--- @param entityID integer
--- @param signature integer a bitwise OR calculation of COMPONENT table elements
function World.AddEntityToArchetype(entityID, signature)
    -- Create archetype if it doesn't exist
    local arch = World.GetArchetype(signature)

    -- Determine the new position (If count is 0, new_pos is 0)
    local new_pos = arch.count 

    -- Safety check for archetype capacity 
    if new_pos >= MAX_ENTITIES then 
        error("ECS: Archetype reached max capacity!")
    end

    -- Assign the ID to the C struct 
    arch.ids[new_pos] = entityID 
    arch.count = arch.count + 1 

    -- Update the metatable data 
    local meta = World.entities.entity_metadata[entityID]
    meta.signature = signature 
    meta.arch_index = new_pos 

    -- Increment version because a brand new Archetype layout exists
    World.Archetype_version = World.Archetype_version + 1
end

--- Creates a new entity with the given components and adds it to the relevent archetype
--- @param signature integer a bitwise OR calculation of COMPONENT table elements that represents the components this entity should have
--- @return integer entityID The new entity ID that was created
function World.Spawn(signature)
    local entityID = World.NewEntity()
    World.AddEntityToArchetype(entityID, signature)
    return entityID
end

--- Moves Entity from one archetype to another by swaping its signature.
--- Mainly used for adding and removing components for entity IDs.
--- @param entityID integer
--- @param old_sig integer The old signature
--- @param new_sig integer The new signature
function World.MoveEntity(entityID, old_sig, new_sig)
    -- Remove from the old Archetype
    -- Even if old_sig is 0 (no components), we still need to remove it from the "empty" archetype list
    local old_arch = World.GetArchetype(old_sig)
    local meta = World.entities.entity_metadata[entityID]
    local old_idx = meta.arch_index

    local last_idx = old_arch.count - 1
    if old_idx < last_idx then 
        local last_id = old_arch.ids[last_idx]
        old_arch.ids[old_idx] = last_id

        -- Update the moved entity's metadata to its new position
        World.entities.entity_metadata[last_id].arch_index = old_idx
    end

    -- Clean up and decrement count 
    old_arch.ids[last_idx] = 0
    old_arch.count = old_arch.count - 1

    -- Add to new Archetype
    local new_arch = World.GetArchetype(new_sig)
    local new_pos = new_arch.count 

    new_arch.ids[new_pos] = entityID 
    new_arch.count = new_arch.count + 1

    -- Update current entity metadata
    meta.signature = new_sig
    meta.arch_index = new_pos 

    -- Global version bump for system cache refreshing 
    World.Archetype_version = World.Archetype_version + 1
end

--- Removes and recycles entity ID
--- @param entityID integer The entity ID you would like to remove
function World.DestroyEntity(entityID)
    -- Remove from Archetype
    local meta = World.entities.entity_metadata[entityID]
    local signature = meta.signature
    -- If the entity is already "dead" (not in any archetype), just exit
    if meta.arch_index == -1 then return end 

    local arch = World.GetArchetype(signature)
    local idx = meta.arch_index -- Where this entity sits in arch.ids
    local last_idx = arch.count - 1 

    if idx < last_idx then 
        local last_entity_id = arch.ids[last_idx]
        -- Move the last ID into the current ID's slot 
        arch.ids[idx] = last_entity_id 
        -- Update the metadata of the entity that was just moved 
        World.entities.entity_metadata[last_entity_id].arch_index = idx
    end

    -- Cleanup Archetype slot and count 
    arch.ids[last_idx] = 0 
    arch.count = arch.count - 1 

    -- Recycle the ID 
    table.insert(World.free_ids, entityID)
    World.total_entities = World.total_entities - 1 

    -- IMPORTANT: Notify system to refresh their caches
    World.Archetype_version = World.Archetype_version + 1
end

--- Finds entitys signature from its metadata: function will return either a signature OR nil.
--- @param entityID integer The entity that you want to get the signature from 
--- @return integer signature
function World.GetEntitySignature(entityID)
    local meta = World.entities.entity_metadata[entityID]
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
    local meta = World.entities.entity_metadata[entityID]
    if not meta then return 0 end 

    local arch = World.arch_table.Archetypes[meta.signature]
    return arch and arch.count or 0
end

-----------------------------
--|| COMPONENT FUNCTIONS ||--
-----------------------------

----- math.log base 2 is too slow to calculate the bit index for edges, 
-- so we pre-fill a lookup table for quick access
local BIT_TO_INDEX = {}
for i = 0, 31 do 
    BIT_TO_INDEX[bit.lshift(1, i)] = i
end

--- Adds a component to entityID
--- @param entityID integer The entity you would like to add the component to 
--- @param componentBit integer The components Bit signature stored inside the Global table : COMPONENT
function World.AddComponent(entityID, componentBit)
    local meta = World.entities.entity_metadata[entityID]
    local old_sig = meta.signature 

    -- Check if it already has the component!
    if bit.band(old_sig, componentBit) == componentBit then 
        return 
    end

    local old_arch = World.arch_table.Archetypes[old_sig]
    local bit_idx = BIT_TO_INDEX[componentBit]

    -- Check if we've made this transitions before to save time on archetype look-up
    local edge_ptr = old_arch.edges.add[bit_idx]
    local new_arch

    if edge_ptr == nil then 
        local new_sig = bit.bor(meta.signature, componentBit)
        new_arch = World.GetArchetype(new_sig)
        -- Store the pointer
        old_arch.edges.add[bit_idx] = new_arch
    else
        new_arch = ffi.cast("Archetype*", edge_ptr)
    end

    -- Move from old Archetype list to the new one 
    World.MoveEntity(entityID, meta.signature, new_arch.signature)
end

--- Removes a component from entityID
--- @param entityID integer The entity you would like to remove the component from
--- @param componentBit integer The components Bit signature stored inside the Global table : COMPONENT
function World.RemoveComponent(entityID, componentBit)
    local meta = World.entities.entity_metadata[entityID]
    local old_sig = meta.signature
    local old_arch = World.arch_table.Archetypes[old_sig]

    -- Use bitwise AND and NOT to clear the bit 
    local bit_idx = BIT_TO_INDEX[componentBit]

    local edge_ptr = old_arch.edges.remove[bit_idx]
    local new_arch 
    if edge_ptr == nil then 
        -- Calc new sig only if it's the first time
        local new_sig = bit.band(old_sig, bit.bnot(componentBit))

        -- If the entity didn't even have this component, just exit
        if old_sig == new_sig then return end 

        -- Find/Create the new archetype
        new_arch = World.GetArchetype(new_sig)

        -- Store the pointer in the cache
        old_arch.edges.remove[bit_idx] = new_arch 
        -- Bidirectional optimization: 
        -- If removing 'Vel' from 'Pos+Vel' leads here,
        -- Then adding 'Vel' to 'Pos' should lead back to 'old_arch'
        new_arch.edges.add[bit_idx] = old_arch 
    else
        -- Edge exists! Cast the void pointer back to an Archetype pointer
        new_arch = ffi.cast("Archetype*", edge_ptr)
    end

    -- Move from the old Archetype list to the new one 
    World.MoveEntity(entityID, old_sig, new_arch.signature)
end

--------------------------
--|| HELPER FUNCTIONS ||--
--------------------------

--- Helper to get all Archetypes that matches a required component bitmask.
--- Usually utilised for caching the relevent archetypes for a given system
--- @param requiredBits integer a bitwise OR combination or all the relevent COMPONENT
--- @param forbiddenBits integer a bitwise OR combination of all the forbidden COMPONENT
--- @return table matches A table of the relevent archetypes 
function World.query(requiredBits, forbiddenBits)
    forbiddenBits = forbiddenBits or 0
    local matches = {}
    local match_count = 0

    -- Loop through the dense C array of archetypes
    for i = 0, World.Archetype_count - 1 do 
        local arch = World.arch_table.Archetypes[i] 
        -- Check if the arch signature contains all required bits
        if bit.band(arch.signature, requiredBits) == requiredBits and bit.band(arch.signature, forbiddenBits) == 0 then
            match_count = match_count + 1 
            -- We store the 'arch' pointer in a standard lua table for the system to use.
            matches[match_count] = arch
        end
    end
    return matches
end

--- Helper to clear all entities and components from ECS 
function World:ClearAll()
    -- Reset lua archetype mapping 
    self.signature_to_index = {}
    self.Archetype_count = 0

    -- Reset ID Management 
    self.free_ids = {}
    self.next_id = 0 
    self.total_entities = 0

    -- Reset Global Version 
    self.Archetype_version = self.Archetype_version + 1 

    -- Fast C style memory clearing for everything 
    -- Wipe all component data 
    ffi.fill(self.data, ffi.sizeof(self.data), 0)

    -- Wipe all entity metadata (signatures, arch_index)
    ffi.fill(self.entities.entity_metadata, ffi.sizeof(self.entities.entity_metadata), 0)
    for i = 0, MAX_ENTITIES - 1 do 
        self.entities.entity_metadata[i].arch_index = -1 -- Set all arch_index to -1 to indicate "no archetype"
    end

    -- Wipe all archetype data (ids, count, signatures)
    ffi.fill(self.arch_table.Archetypes, ffi.sizeof(self.arch_table.Archetypes), 0)

    -- Re-init the "NULL" Archetype at index 0 
    -- This ensures AddComponent/RemoveComponent always has a valid archetype to move from/to even if an entity has no components
    self:Init()
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