local SpatialHash = {
    grid = {},
    CELLSIZE = 64 -- Adjust based on average entity size 
}

function SpatialHash:clear()
    self.grid = {}
end

function SpatialHash:getRange(x, y, w, h)
    local flr = math.floor
    local x1, y1 = flr(x / self.CELLSIZE), flr(y / self.CELLSIZE)
    local x2, y2 = flr((x + w) / self.CELLSIZE), flr((y + h) / self.CELLSIZE)
    return x1, y1, x2, y2
end

function SpatialHash:register(id, x, y, w, h)
    -- Find which cells the entity's bounding box overlaps
    local x1, y1, x2, y2 = self:getRange(x, y, w, h)

    for cx = x1, x2 do 
        for cy = y1, y2 do 
            local key = cx .. "," .. cy 
            if not self.grid[key] then self.grid[key] = {} end 
            table.insert(self.grid[key], id)
        end
    end
end

function SpatialHash:get_nearby(x, y, w, h)
    local x1, y1, x2, y2 = self:getRange(x, y, w, h)
    local nearby = {}
    local seen = {} -- Prevent duplicates IDs if entity spans multiple cells
    for cx = x1, x2 do 
        for cy = y1, y2 do 
            local key = cx .. "," .. cy 
            if self.grid[key] then 
                for _, id in ipairs(self.grid[key]) do 
                    if not seen[id] then 
                        nearby[#nearby+1] = id
                        seen[id] = true 
                    end
                end
            end
        end
    end
    return nearby
end

return SpatialHash