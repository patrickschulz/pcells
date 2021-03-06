--[[
This file is part of the openPCells project.

An 'object' is a collection of 'shapes', that is an object composed of several polygons on several layers.
--]]
local M = {}

local meta = {}
meta.__index = meta
meta.__tostring = function(self) return string.format("object: %s", self.name or "_NONAME_")  end

function M.create(name)
    local self = {
        name = name,
        children = { lookup = {} },
        shapes = {},
        ports = {},
        anchors = {},
        alignmentbox = nil,
        trans = transformationmatrix.identity(),
        isproxy = false
    }
    setmetatable(self, meta)
    return self
end

function M.create_proxy(name, reference, identifier)
    local self = {
        name = name,
        reference = reference,
        identifier = identifier,
        origin = point.create(0, 0),
        trans = transformationmatrix.identity(),
        isproxy = true
    }
    setmetatable(self, meta)
    return self
end

-- fake object with returns (0, 0) for all anchors
function M.create_omni()
    local self = M.create()
    setmetatable(self.anchors, { __index = function() return point.create(0, 0) end })
    return self
end

function meta.copy(self)
    local new = M.create(self.name)
    new.trans = self.trans:copy()
    for i, S in ipairs(self.shapes) do
        new.shapes[i] = S:copy()
    end
    for name, pt in pairs(self.anchors) do
        new.anchors[name] = pt:copy()
    end
    if self.alignmentbox then
        new.alignmentbox = { bl = self.alignmentbox.bl:copy(), tr = self.alignmentbox.tr:copy() }
    end
    -- copy children
    for identifier, obj in pairs(self.children.lookup) do
        new.children.lookup[identifier] = obj:copy()
    end
    for i, child in ipairs(self.children) do
        new.children[i] = { name = child.name, reference = child.reference, identifier = child.identifier, trans = child.trans:copy(), isproxy = true }
    end
    return new
end

function M.make_from_shape(S)
    local self = M.create()
    self:add_shape(S)
    return self
end

function meta.exchange(self, other)
    self.name = other.name
    self.children = other.children
    self.shapes = other.shapes
    self.ports = other.ports
    self.anchors = other.anchors
    self.alignmentbox = other.alignmentbox
end

function meta.add_child(self, identifier)
    local reference = pcell.get_cell_reference(identifier)
    local child = M.create_proxy(nil, reference, identifier)
    self.trans:apply_inverse_transformation(child.origin)
    table.insert(self.children, child)
    return child
end

function meta.add_child_array(self, identifier, xrep, yrep, xpitch, ypitch)
    local child = self:add_child(identifier)
    child.isarray = true
    child.xrep = xrep
    child.yrep = yrep
    child.xpitch = xpitch
    child.ypitch = ypitch
    return child
end

function meta.foreach_children(self, func, ...)
    for _, child in self:iterate_children() do
        func(child, ...)
        child:foreach_children(func, ...)
    end
end

function meta.add_raw_shape(self, S)
    local new = S:copy()
    table.insert(self.shapes, new)
    return new
end

function meta.add_shape(self, S)
    local new = self:add_raw_shape(S)
    new:apply_transformation(self.trans, self.trans.apply_inverse_transformation)
    return new
end

function meta.remove_shape(self, idx)
    if not idx then
        moderror("object: removing shape with nil index")
    end
    table.remove(self.shapes, idx)
end

function meta.add_shapes(self, shapes)
    for _, s in ipairs(shapes) do
        self:add_shape(s)
    end
end

function meta.merge_into_shallow(self, other)
    for _, S in other:iterate_shapes() do
        local new = self:add_shape(S)
        new:apply_transformation(other.trans, other.trans.apply_transformation)
    end
end

function meta.flatten(self)
    -- add shapes and flatten children (recursive)
    for _, child in self:iterate_children() do
        local obj = child.reference
        obj:copy() -- FIXME: is copy necessary?
        obj:flatten()
        for _, S in obj:iterate_shapes() do
            local new = self:add_raw_shape(S)
            new:apply_transformation(child.trans, child.trans.apply_transformation)
            new:apply_transformation(obj.trans, obj.trans.apply_transformation)
        end
    end
    -- remove children
    self.children = { lookup = {} }
    return self
end

function meta.is_empty(self)
    return #self.shapes == 0 and #self.children == 0
end

function meta.add_port(self, name, layer, where)
    --layer:set_port()
    table.insert(self.ports, { name = name, layer = layer, where = where })
    self.anchors[name] = where:copy() -- copy point, otherwise translation acts twice (FIXME: probably not needed any more)
end

function meta.find_shapes(self, comp)
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
    for _, S in self:iterate_shapes() do
        local lpp = S:get_lpp()
        lpps[lpp:str()] = lpp
    end
    return pairs(lpps)
end

function meta.iterate_children(self)
    local idx = #self.children + 1 -- start at the end
    local iter = function()
        idx = idx - 1
        if idx > 0 then
            return idx, self.children[idx]
        else
            return nil
        end
    end
    return iter
end

-- this function returns an iterator over all shapes in a cell (possibly only selecting a subset)
-- First all shapes are collected in an auxiliary table, which enables modification of the self.shapes table within the iteration
-- Furthermore, the list is iterated from the end, which allows element removal in the loop
function meta.iterate_shapes(self, comp)
    local indices, shapes = meta.find_shapes(self, comp)
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
    self.trans:translate(dx, dy)
    return self
end

local function _flipxy(self, mode, ischild)
    local cx, cy = self:get_transformation_correction()
    if mode == "x" then
        self.trans:flipx()
        cy = 0
    else -- mode == "y"
        self.trans:flipy()
        cx = 0
    end
    if not ischild then
        self.trans:auxtranslate(cx, cy)
    end
    if not self.isproxy then
        for _, child in self:iterate_children() do
            _flipxy(child, mode, true)
        end
    end
    return self
end

function meta.flipx(self, xcenter)
    _flipxy(self, "x")
end

function meta.flipy(self)
    _flipxy(self, "y")
end

local function _get_minmax_xy(self)
    local minx =  math.huge
    local maxx = -math.huge
    local miny =  math.huge
    local maxy = -math.huge
    for _, S in self:iterate_shapes() do
        if S.typ == "polygon" then
            for _, pt in ipairs(S:get_points()) do
                local x, y = pt:unwrap()
                minx = math.min(minx, x)
                maxx = math.max(maxx, x)
                miny = math.min(miny, y)
                maxy = math.max(maxy, y)
            end
        elseif S.typ == "rectangle" then
            local blx, bly = S:get_points().bl:unwrap()
            local trx, try = S:get_points().tr:unwrap()
            minx = math.min(minx, blx, trx)
            maxx = math.max(maxx, blx, trx)
            miny = math.min(miny, bly, try)
            maxy = math.max(maxy, bly, try)
        end
    end
    return minx, maxx, miny, maxy
end

function meta.get_transformation_correction(self)
    local obj = self
    if self.isproxy then
        obj = self.reference
    end
    local blx, bly, trx, try
    if obj.alignmentbox then
        blx, bly = obj.alignmentbox.bl:unwrap()
        trx, try = obj.alignmentbox.tr:unwrap()
    else
        blx, trx, bly, try = _get_minmax_xy(obj)
    end
    return blx + trx, bly + try
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
    local bl = other:get_anchor("bottomleft")
    local tr = other:get_anchor("topright")
    if self.alignmentbox then
        local blx, bly = bl:unwrap()
        local trx, try = tr:unwrap()
        local sblx, sbly = self.alignmentbox.bl:unwrap()
        local strx, stry = self.alignmentbox.tr:unwrap()
        self.alignmentbox = { 
            bl = point.create(math.min(blx, sblx), math.min(bly, sbly)), 
            tr = point.create(math.max(trx, strx), math.max(try, stry))
        }
    else
        self.alignmentbox = { bl = bl:copy(), tr = tr:copy() }
    end
end

local _reserved_anchors = {
    "left", "right", "bottom", "top", "bottomleft", "bottomright", "topleft", "topright"
}

function meta.add_anchor(self, name, where)
    if aux.find(_reserved_anchors, function(n) return n == name end) then
        error(string.format("trying to add reserved anchor '%s'", name))
    end
    where = where:copy() or point.create(0, 0)
    self.anchors[name] = where
end

local function _get_special_anchor(self, name)
    if not self.alignmentbox then
        return nil
    end
    local blx, bly = self.alignmentbox.bl:unwrap()
    local trx, try = self.alignmentbox.tr:unwrap()
    local x, y
    if name == "left" then
        x, y = blx, (bly + try) / 2
    elseif name == "right" then
        x, y = trx, (bly + try) / 2
    elseif name == "top" then
        x, y = (blx + trx) / 2, try
    elseif name == "bottom" then
        x, y = (blx + trx) / 2, bly
    elseif name == "bottomleft" then
        x, y = blx, bly
    elseif name == "bottomright" then
        x, y = trx, bly
    elseif name == "topleft" then
        x, y = blx, try
    elseif name == "topright" then
        x, y = trx, try
    else
        return nil
    end
    return point.create(x, y)
end

local function _get_regular_anchor(self, name)
    local anchor = self.anchors[name]
    if anchor then
        local pt = anchor:copy()
        return pt
    end
end

function meta.get_anchor(self, name)
    local obj = self
    if self.isproxy then
        obj = self.reference
    end
    local pt = _get_special_anchor(obj, name)
    if pt then
        obj.trans:apply_translation(pt)
        if self.isproxy then
            self.trans:apply_translation(pt)
        end
        return pt
    else
        pt = _get_regular_anchor(obj, name)
    end
    if not pt then
        if self.name then
            error(string.format("trying to access undefined anchor '%s' in cell '%s'", name, self.name))
        else
            error(string.format("trying to access undefined anchor '%s'", name))
        end
    end
    obj.trans:apply_transformation(pt)
    if self.isproxy then
        self.trans:apply_transformation(pt)
    end
    return pt
end

function meta.move_anchor(self, name, where)
    where = where or point.create(0, 0)
    local anchor = self:get_anchor(name)
    local wx, wy = where:unwrap()
    local x, y = anchor:unwrap()
    self:translate(wx - x, wy - y)
    return self
end

function meta.get_all_anchors(self)
    local anchors = {}
    for name in pairs(self.anchors) do
        anchors[name] = self:get_anchor(name)
    end
    return anchors
end

return M
