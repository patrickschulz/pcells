--[[
This file is part of the openPCells project.

An 'object' is a collection of 'shapes', that is an object composed of several polygons on several layers.
--]]
local M = {}

local meta = {}
meta.__index = meta

function M.create(name)
    local self = {
        name = name,
        subs = {},
        shapes = {},
        ports = {},
        anchors = {},
        alignmentbox = nil,
        origin = point.create(0, 0)
    }
    setmetatable(self, meta)
    return self
end

function M.create_omni()
    local self = M.create()
    setmetatable(self.anchors, { __index = function() return point.create(0, 0) end })
    return self
end

function meta.copy(self)
    local new = M.create()
    for i, shape in ipairs(self.shapes) do
        new.shapes[i] = shape:copy()
    end
    for name, pt in pairs(self.anchors) do
        new.anchors[name] = pt:copy()
    end
    return new
end

function M.make_from_shape(shape)
    local self = M.create()
    self:add_shape(shape)
    return self
end

function meta.add(self, other)
    table.insert(self.subs, other)
end

function meta.merge_into(self, other)
    for _, shape in other:iter() do
        self:add_shape(shape)
    end
end

function meta.merge_into_update_alignmentbox(self, other)
    meta.inherit_alignment_box(self, other)
    for _, shape in other:iter() do
        self:add_shape(shape)
    end
end

function meta.flatten_shallow(self)
    for _, sub in ipairs(self.subs) do
        self:merge_into(sub)
    end
    self.subs = {}
end

function meta.is_empty(self)
    return #self.shapes == 0
end

function meta.add_shape(self, shape)
    table.insert(self.shapes, shape:copy())
end

function meta.remove_shape(self, idx)
    table.remove(self.shapes, idx)
end

function meta.add_shapes(self, shapes)
    for _, s in ipairs(shapes) do
        self:add_shape(s)
    end
end

function meta.add_port(self, name, layer, where)
    self.ports[name] = { layer = layer, where = where }
    self.anchors[name] = where:copy() -- copy point, otherwise translation acts twice
end

function meta.find(self, comp)
    local shapes = {}
    local indices = {}
    comp = comp or function() return true end
    for i, s in ipairs(self.shapes) do
        if comp(s) then
            table.insert(shapes, s)
            table.insert(indices, i)
        end
    end
    return indices, shapes
end

function meta.layers(self)
    local lpps = {}
    for _, S in self:iter() do
        lpps[S.lpp:str()] = S.lpp
    end
    return pairs(lpps)
end

-- this function returns an iterator over all shapes in a cell (possibly only selecting a subset)
-- First all shapes are collected in an auxiliary table, which enables modification of the self.shapes table within the iteration
-- Furthermore, the list is iterated from the end, which allows element removal in the loop
function meta.iter(self, comp)
    local indices, shapes = meta.find(self, comp)
    local idx = #shapes + 1 -- start at the end
    local iter = function()
        idx = idx - 1
        return indices[idx], shapes[idx]
    end
    return iter
end

function meta.translate(self, dx, dy)
    if is_lpoint(dx) then
        dx, dy = dx:unwrap()
    end
    for _, shape in ipairs(self.shapes) do
        shape:translate(dx, dy)
    end
    for _, anchor in pairs(self.anchors) do
        anchor:translate(dx, dy)
    end
    for _, port in pairs(self.ports) do
        port.where:translate(dx, dy)
    end
    self.origin:translate(dx, dy)
    if self.alignmentbox then
        self.alignmentbox.bl:translate(dx, dy)
        self.alignmentbox.tr:translate(dx, dy)
    end
    return self
end

function meta.flipx(self, xcenter)
    xcenter = xcenter or 0
    local selfxcenter = self.origin:unwrap()
    for _, shape in ipairs(self.shapes) do
        shape:flipx(xcenter + selfxcenter)
    end
    for _, anchor in pairs(self.anchors) do
        local x = anchor:getx()
        anchor:translate(2 * (selfxcenter - x), 0)
    end
    for _, port in pairs(self.ports) do
        local x = port.where:getx()
        port.where:translate(2 * (selfxcenter - x), 0)
    end
    if self.alignmentbox then
        local blx, bly = self.alignmentbox.bl:unwrap()
        local trx, try = self.alignmentbox.tr:unwrap()
        self.alignmentbox.bl = point.create(2 * (xcenter + selfxcenter) - trx, bly)
        self.alignmentbox.tr = point.create(2 * (xcenter + selfxcenter) - blx, try)
    end
    return self
end

function meta.flipy(self, ycenter)
    ycenter = ycenter or 0
    local _, selfycenter = self.origin:unwrap()
    for _, shape in ipairs(self.shapes) do
        shape:flipy(ycenter + selfycenter)
    end
    for _, anchor in pairs(self.anchors) do
        local y = anchor:gety()
        anchor:translate(0, 2 * (selfycenter - y))
    end
    for _, port in pairs(self.ports) do
        local y = port.where:gety()
        port.where:translate(0, 2 * (selfycenter - y))
    end
    if self.alignmentbox then
        local blx, bly = self.alignmentbox.bl:unwrap()
        local trx, try = self.alignmentbox.tr:unwrap()
        self.alignmentbox.bl = point.create(blx, 2 * (ycenter + selfycenter) - try)
        self.alignmentbox.tr = point.create(trx, 2 * (ycenter + selfycenter) - bly)
    end
    return self
end

function meta.rotate(self, angle)
    for _, shape in ipairs(self.shapes) do
        shape:rotate(angle)
    end
    for _, anchor in pairs(self.anchors) do
        anchor:rotate(angle)
    end
    return self
end

local function _get_minmax_xy(self)
    local minx =  math.huge
    local maxx = -math.huge
    local miny =  math.huge
    local maxy = -math.huge
    for _, shape in self:iter() do
        if shape.typ == "polygon" then
            for _, pt in ipairs(shape.points) do
                local x, y = pt:unwrap()
                minx = math.min(minx, x)
                maxx = math.max(maxx, x)
                miny = math.min(miny, y)
                maxy = math.max(maxy, y)
            end
        elseif shape.typ == "rectangle" then
            local blx, bly = shape.points.bl:unwrap()
            local trx, try = shape.points.tr:unwrap()
            minx = math.min(minx, blx, trx)
            maxx = math.max(maxx, blx, trx)
            miny = math.min(miny, bly, try)
            maxy = math.max(maxy, bly, try)
        end
    end
    return minx, maxx, miny, maxy
end

function meta.width_height(self)
    local minx, maxx, miny, maxy = _get_minmax_xy(self)
    return maxx - minx, maxy - miny
end

function meta.bounding_box(self)
    local minx, maxx, miny, maxy = _get_minmax_xy(self)
    return { bl = point.create(minx, miny), tr = point.create(maxx, maxy) }
end

function meta.set_alignment_box(self, bl, tr)
    self.alignmentbox = { bl = bl:copy(), tr = tr:copy() }
end

function meta.inherit_alignment_box(self, other)
    local bl, tr = other.alignmentbox.bl, other.alignmentbox.tr
    if self.alignmentbox then
        local blx, bly = bl:unwrap()
        local trx, try = tr:unwrap()
        local sblx, sbly = self.alignmentbox.bl:unwrap()
        local strx, stry = self.alignmentbox.tr:unwrap()
        self.alignmentbox = { bl = point.create(math.min(blx, sblx), math.min(bly, sbly)), tr = point.create(math.max(trx, strx), math.max(try, stry)) }
    else
        self.alignmentbox = { bl = other.alignmentbox.bl:copy(), tr = other.alignmentbox.tr:copy() }
    end
end

local _reserved_anchors = {
    "left", "right", "bottom", "top"
}

function meta.add_anchor(self, name, where)
    if aux.find(_reserved_anchors, function(n) return n == name end) then
        error(string.format("trying to add reserved anchor '%s'", name))
    end
    where = where:copy() or point.create(0, 0)
    self.anchors[name] = where
end

local function _get_anchor(self, name)
    if not self.anchors[name] then
        if self.alignmentbox then
            local blx, bly = self.alignmentbox.bl:unwrap()
            local trx, try = self.alignmentbox.tr:unwrap()
            if name == "left" then
                return point.create(blx, (bly + try) / 2)
            elseif name == "right" then
                return point.create(trx, (bly + try) / 2)
            elseif name == "top" then
                return point.create((blx + trx) / 2, try)
            elseif name == "bottom" then
                return point.create((blx + trx) / 2, bly)
            elseif name == "bottomleft" then
                return point.create(blx, bly)
            elseif name == "bottomright" then
                return point.create(trx, bly)
            elseif name == "topleft" then
                return point.create(blx, try)
            elseif name == "topright" then
                return point.create(trx, try)
            end
        end
        if self.name then
            error(string.format("trying to access anchor '%s' in cell '%s'", name, self.name))
        else
            error(string.format("trying to access anchor '%s'", name))
        end
    end
    return self.anchors[name]
end

function meta.get_anchor(self, name)
    local anchor = _get_anchor(self, name)
    return anchor:copy()
end

function meta.move_anchor(self, name, where)
    where = where or point.create(0, 0)
    local anchor = _get_anchor(self, name)
    local wx, wy = where:unwrap()
    local x, y = anchor:unwrap()
    self:translate(wx - x, wy - y)
    return self
end

return M
