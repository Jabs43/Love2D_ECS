local GameStateManager = {
    stack = {},         --> Stack of active states
    initialized = {}    --> Track states that ran init()
}

-- Helper no-operation
local function noop() end

-- Add new state (optional)
function GameStateManager:addState(name, state)
    self[name] = state
end

-- Internal helper: call function if it exists
local function call(state, fn, ...)
    if state and state[fn] then 
        return state[fn](state, ...)
    end
end 

-- Change current state completely (clears stack)
function GameStateManager:switch(state, ...)
    assert(state, "Missing state to switch to")

    local prev = self.stack[#self.stack]
    call(prev, "exit")

    self.stack = { state } -- Clear and push new

    if not self.initialized[state] then 
        call(state, "init")
        self.initialized[state] = true 
    end

    call(state, "enter", prev, ...)
end

-- Push new state on top (pause current)
function GameStateManager:pushState(state, ...)
    assert(state, "Missing state to push")

    local current = self.stack[#self.stack]
    call(current, "pause")

    if not self.initialized[state] then 
        call(state, "init")
        self.initialized[state] = true 
    end

    table.insert(self.stack, state)
    call(state, "enter", current, ...)
end

-- Pop top state (resume previous)
function GameStateManager:popState(...)
    assert(#self.stack > 1, "No states to pop!")

    local leaving = table.remove(self.stack)
    call(leaving, "exit")

    local resumed = self.stack[#self.stack]
    call(resumed, "resume", leaving, ...)
end

-- Current active state 
function GameStateManager:current()
    return self.stack[#self.stack]
end

-- Manual forwarding (explicit!)
function GameStateManager:update(dt)
    local s = self.stack[#self.stack]
    call(s, "update", dt)
end

function GameStateManager:draw()
    local lg = love.graphics
    lg.setCanvas()
    lg.origin()         -- RESET TRANSFORMS!
    lg.setShader()
    lg.setScissor()
    
    for i = 1, #self.stack do 
        local s = self.stack[i]
        call(s, "draw")
    end
end

function GameStateManager:keypressed(key)
    local s = self.stack[#self.stack]
    call(s, "keypressed", key)
end

return GameStateManager