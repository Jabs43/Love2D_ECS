require('lib.helperfunctions')
require('lib.globals')
local World = require('lib.ECS')
---------------------------------
--|| Fish Entity Constructor ||--
---------------------------------
local Fish = {}

function Fish:NewEntityPlayer(x,y, dx,dy, w,h, settings)
    -- 1. Create ID
    local player = World.NewEntity()

    -- 2. Create ID with base signature 
    local base_sig = bit.bor(
        COMPONENT.POSITION,
        COMPONENT.VELOCITY,
        COMPONENT.COLLISION,
        COMPONENT.INPUT,
        COMPONENT.SWIM
    )

    -- 3. Add base signature to entityID 
    World.AddEntityToArchetype(player, base_sig)    

    -- 4. Set initial values 
    World:SetEntityPos(player, x, y)
    World:SetEntityVel(player, dx, dy, 70)
    World:SetEntityCollision(player, -w/2, -h/2, w, h)
    World:SetEntityControlls(player, true)
    World:SetEntitySwim(player, true)

    -- 5. Add the FishBody (which moves it to the correct Archetype)
    local s = settings or {}
    World.AddFishBody(player, x, y, s.segs or 24, s.seglen or 3, s.bouyancy or (0.95 * GRV), s.size or 8)
    
    return player
end

function Fish:NewEntityAI(x,y, dx,dy, w,h, settings)
    -- 1. Create ID
    local fish = World.NewEntity()

    -- 2. Create base signature 
    local base_sig = bit.bor(
        COMPONENT.POSITION,
        COMPONENT.VELOCITY,
        COMPONENT.COLLISION,
        COMPONENT.AI,
        COMPONENT.SWIM
    )

    -- 3. Add base signature to entityID 
    World.AddEntityToArchetype(fish, base_sig)

    -- 4. Set initial values 
    World:SetEntityPos(fish, x, y)
    World:SetEntityVel(fish, dx, dy, 70)
    World:SetEntityCollision(fish, -w/2, -h/2, w, h)
    World:SetEntityAi(fish, 0, 0)
    World:SetEntitySwim(fish, true)

    -- 5. Add the FishBody (which moves it to the correct Archetype)
    local s = settings or {}
    World.AddFishBody(fish, x, y, s.segs or 24, s.seglen or 3, s.bouyancy or (0.95 * GRV), s.size or 8)
    
    return fish
end

return Fish
--[[

function new_ai_fish(x,y, dx,dy, w,h, settings)
    local segs = 24
    local seglen = 3 
    local bouy = (0.95 * GRV)
    local size = 8
    if settings then 
        segs = settings.segs or segs
        seglen = settings.seglen or seglen
        bouy = settings.bouyancy or bouy
        size = settings.size or size
    end
    -- 1. Create fish Entity ID 
    local fish = createEntity()
    local half_w, half_h = w/2, h/2
    -- 2. Attach Components to new entity (fish)
    addAi(fish, 0, 0)
    addPosition(fish, x, y)
    addVelocity(fish, dx, dy, 70)
    addCollision(fish,-half_w,-half_h, w, h)
    addSwim(fish, true)
    addFishBody(fish, x, y, segs, seglen, bouy, size)
    return fish
end

function new_ai_fish(x,y,dx,dy,w,h,settings)
    local segs = 24
    local seglen = 3 
    local bouy = (0.95 * GRV)
    local size = 8

    if settings then 
        segs = settings.segs or segs
        seglen = settings.seglen or seglen
        bouy = settings.bouyancy or bouy
        size = settings.size or size
    end

    local fishID = World.NewEntity(
        COMPONENT.POSITION + 
        COMPONENT.VELOCITY + 
        COMPONENT.COLLISION + 
        COMPONENT.FISH + 
        COMPONENT.Ai + 
        COMPONENT.FISHBODY 
    )

    World:ChangeEntityAi(fishID, 0, 0)
    World:ChangeEntityPos(fishID, x, y)
    World:ChangeEntityVel(fishID, dx, dy, spd)
    World:ChangeEntityCollision(fish,-half_w,-half_h, w, h)
    World:ChangeEntitySwim(fish, true)
    InitFishBodyComponent()
end

]]