require('lib.globals')
--------------------------------
--|| Global Systems Manager ||
--------------------------------
local GlobalSystems = {
    -- Require all specialized system scripts
    Input = require('lib/GlobalSystems.InputSystem'),
    AI = require('lib/GlobalSystems.AISystem'),
    Physics = require('lib/GlobalSystems.PhysicsSystem'),
    Render = require('lib/GlobalSystems.RenderSystem')
}

--- Update all logic-based entity systems IN ORDER!
--- @param dt float DeltaTime
function GlobalSystems:Update(dt)
    self.Input:Update()
    self.AI:Update(dt)
    self.Physics:Update(dt)
end

--- Update all drawing-based entity systems
function GlobalSystems:Draw()
    self.Render:Draw()
end

return GlobalSystems