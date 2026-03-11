require('lib.helperfunctions')
require('lib.globals')

local camera = {}
camera.__index = camera 

-- Movement interpolators (for camera locking/windowing)
camera.smooth = {}

function camera.smooth.none()
    return function(dx,dy) return dx,dy end
end

function camera.smooth.linear(speed)
    assert(type(speed) == "number", "Invalid parameter: speed = "..tostring(speed))
    return function(dx, dy, s)
        -- normalize direction 
        local d = math.sqrt(dx*dx+dy*dy)
        local dts = math.min((s or speed) * love.timer.getDelta(), d) -- prevent overshooting the goal 
        if d > 0 then 
            dx, dy = dx/d, dy/d 
        end

        return dx*dts, dy*dts 
    end
end

function camera.smooth.damped(stiffness)
    assert(type(stiffness) == "number", "Invalid parameter: stiffness = "..tostring(stiffness))
    return function(dx, dy, s)
        local dts = love.timer.getDelta() * (s or stiffness)
        return dx*dts, dy*dts
    end
end

local function new(x,y, zoom, rot, smoother)
    x, y = x or VIRTUAL_WIDTH/2, y or VIRTUAL_HEIGHT/2
    zoom = zoom or 1 
    rot = rot or 0
    smoother = smoother or camera.smooth.none()-- For locking, see below 
    return setmetatable({x = x,y = y,scale = zoom,rot = rot,smoother = smoother}, camera)
end

function camera:lookAt(x,y)
    self.x, self.y = x, y 
    return self
end

function camera:move(dx,dy)
    self.x, self.y = self.x + dx, self.y + dy 
    return self 
end

function camera:position()
    return self.x,  self.y
end

function camera:rotate(phi)
    self.rot = self.rot + phi 
    return self 
end

function camera:rotateTo(phi)
    self.rot = phi 
    return self 
end

function camera:zoom(mul)
    self.scale = self.scale * mul 
    return self 
end

function camera:zoomTo(zoom)
    self.scale = zoom 
    return self 
end

function camera:attach(x,y,w,h, noclip)
    x, y = x or 0, y or 0
    w, h = w or VIRTUAL_WIDTH, h or VIRTUAL_HEIGHT
    self._sx,self._sy,self._sw,self._sh = love.graphics.getScissor()
    if not noclip then 
        love.graphics.setScissor(x,y,w,h)
    end
    local cx, cy = x+w/2, y+h/2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(self.scale)
    love.graphics.rotate(self.rot)
    love.graphics.translate(-self.x, -self.y)
end

function camera:detach()
    love.graphics.pop()
    love.graphics.setScissor(self._sx,self._sy,self._sw,self._sh)
end

function camera:draw(...)
    local x,y,w,h,noclip,func 
    local nargs = select("#", ...)
    if nargs == 1 then 
        func = ...
    elseif nargs == 5 then 
        x,y,w,h,func = ...
    elseif nargs == 6 then 
        x,y,w,h,noclip,func = ... 
    else 
        error("Invalid arguments to camera:draw()")
    end

    self:attach(x,y,w,h,noclip)
    func()
    self:detach()
end
-- World coords to Camera coords
function camera:cameraCoords(x,y, ox,oy,w,h)
    ox,oy = ox or 0, oy or 0
    w,h = w or VIRTUAL_WIDTH, h or VIRTUAL_HEIGHT
    -- x,y = ((x,y) - (self.x, self.y)):rotated(self.rot) * self.scale + center 
    local c,s = math.cos(self.rot), math.sin(self.rot)
    x,y = x - self.x, y - self.y 
    x,y = c*x - s*y, s*x + c*y 
    return x*self.scale + w/2 + ox, y*self.scale + h/2 + oy 
end

-- Camera coords to World coords
function camera:worldCoords(x,y, ox,oy,w,h)
    ox,oy = ox or 0, oy or 0 
    w,h = w or VIRTUAL_WIDTH, h or VIRTUAL_HEIGHT
    -- x,y = (((x,y) - center) / self.scale):rotated(-self.rot) + (self.x,self.y)
    local c,s = math.cos(-self.rot), math.sin(-self.rot)
    x,y = (x - w/2 - ox) / self.scale, (y - h/2 - oy) / self.scale 
    x,y = c*x - s*y, s*x + c*y 
    return x+self.x, y+self.y
end 

function camera:mousePosition(ox,oy,w,h)
    local mx,my = Push:toGame(love.mouse.getPosition())
    return self:worldCoords(mx,my, ox,oy,w,h)
end

function camera:lockX(x, smoother, ...)
    local dx,dy = (smoother or self.smoother)(x - self.x, self.y, ...)
    self.x = self.x + dx 
    return self
end

function camera:lockY(y, smoother, ...)
    local dx,dy = (smoother or self.smoother)(self.x, y - self.y, ...)
    self.y = self.y + dy 
    return self
end

function camera:lockPosition(x,y, smoother, ...)
    return self:move((smoother or self.smoother)(x - self.x, y - self.y, ...))
end

function camera:lockWindow(x, y, x_min, x_max, y_min, y_max, smoother, ...)
    -- Figure out displacement in camera coordinates
    x,y = self:cameraCoords(x,y)
    local dx,dy = 0,0
    if x < x_min then 
        dx = x - x_min 
    elseif x > x_max then 
        dx = x - x_max 
    end
    if y < y_min then 
        dy = y - y_min 
    elseif y > y_max then 
        dy = y - y_max 
    end

    -- Transform displacement to movement in world coords
    local c,s = math.cos(-self.rot), math.sin(-self.rot)
    dx,dy = (c*dx - s*dy) / self.scale, (s*dx + c*dy) / self.scale
    -- Move 
    self:move((smoother or self.smoother)(dx,dy,...))
end

-- the module
return setmetatable({new = new, smooth = camera.smooth},
	{__call = function(_, ...) return new(...) end})