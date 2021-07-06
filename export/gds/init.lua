local M = {}


local __libname = "opclib"
local __cellname = "opctoplevelcell"
local __textmode = false

local __userunit = 1
local __databaseunit = 1e-9

local recordtypes = {
    HEADER          = { name = "HEADER",        code = 0x00 },
    BGNLIB          = { name = "BGNLIB",        code = 0x01 },
    LIBNAME         = { name = "LIBNAME",       code = 0x02 },
    UNITS           = { name = "UNITS",         code = 0x03 },
    ENDLIB          = { name = "ENDLIB",        code = 0x04 },
    BGNSTR          = { name = "BGNSTR",        code = 0x05 },
    STRNAME         = { name = "STRNAME",       code = 0x06 },
    ENDSTR          = { name = "ENDSTR",        code = 0x07 },
    BOUNDARY        = { name = "BOUNDARY",      code = 0x08 },
    PATH            = { name = "PATH",          code = 0x09 },
    SREF            = { name = "SREF",          code = 0x0a },
    AREF            = { name = "AREF",          code = 0x0b },
    TEXT            = { name = "TEXT",          code = 0x0c },
    LAYER           = { name = "LAYER",         code = 0x0d },
    DATATYPE        = { name = "DATATYPE",      code = 0x0e },
    WIDTH           = { name = "WIDTH",         code = 0x0f },
    XY              = { name = "XY",            code = 0x10 },
    ENDEL           = { name = "ENDEL",         code = 0x11 },
    SNAME           = { name = "SNAME",         code = 0x12 },
    COLROW          = { name = "COLROW",        code = 0x13 },
    TEXTNODE        = { name = "TEXTNODE",      code = 0x14 },
    NODE            = { name = "NODE",          code = 0x15 },
    TEXTTYPE        = { name = "TEXTTYPE",      code = 0x16 },
    PRESENTATION    = { name = "PRESENTATION",  code = 0x17 },
    SPACING         = { name = "SPACING",       code = 0x18 },
    STRING          = { name = "STRING",        code = 0x19 },
    STRANS          = { name = "STRANS",        code = 0x1a },
    MAG             = { name = "MAG",           code = 0x1b },
    ANGLE           = { name = "ANGLE",         code = 0x1c },
    UINTEGER        = { name = "UINTEGER",      code = 0x1d },
    USTRING         = { name = "USTRING",       code = 0x1e },
    REFLIBS         = { name = "REFLIBS",       code = 0x1f },
    FONTS           = { name = "FONTS",         code = 0x20 },
    PATHTYPE        = { name = "PATHTYPE",      code = 0x21 },
    GENERATIONS     = { name = "GENERATIONS",   code = 0x22 },
    ATTRTABLE       = { name = "ATTRTABLE",     code = 0x23 },
    STYPTABLE       = { name = "STYPTABLE",     code = 0x24 },
    STRTYPE         = { name = "STRTYPE",       code = 0x25 },
    ELFLAGS         = { name = "ELFLAGS",       code = 0x26 },
    ELKEY           = { name = "ELKEY",         code = 0x27 },
    LINKTYPE        = { name = "LINKTYPE",      code = 0x28 },
    LINKKEYS        = { name = "LINKKEYS",      code = 0x29 },
    NODETYPE        = { name = "NODETYPE",      code = 0x2a },
    PROPATTR        = { name = "PROPATTR",      code = 0x2b },
    PROPVALUE       = { name = "PROPVALUE",     code = 0x2c },
    BOX             = { name = "BOX",           code = 0x2d },
    BOXTYPE         = { name = "BOXTYPE",       code = 0x2e },
    PLEX            = { name = "PLEX",          code = 0x2f },
    BGNEXTN         = { name = "BGNEXTN",       code = 0x30 },
    ENDEXTN         = { name = "ENDEXTN",       code = 0x31 },
    TAPENUM         = { name = "TAPENUM",       code = 0x32 },
    TAPECODE        = { name = "TAPECODE",      code = 0x33 },
    STRCLASS        = { name = "STRCLASS",      code = 0x34 },
    RESERVED        = { name = "RESERVED",      code = 0x35 },
    FORMAT          = { name = "FORMAT",        code = 0x36 },
    MASK            = { name = "MASK",          code = 0x37 },
    ENDMASKS        = { name = "ENDMASKS",      code = 0x38 },
    LIBDIRSIZE      = { name = "LIBDIRSIZE",    code = 0x39 },
    SRFNAME         = { name = "SRFNAME",       code = 0x3a },
    LIBSECUR        = { name = "LIBSECUR",      code = 0x3b },
}

local datatypes = {
    NONE                = 0x00,
    BIT_ARRAY           = 0x01,
    TWO_BYTE_INTEGER    = 0x02,
    FOUR_BYTE_INTEGER   = 0x03,
    FOUR_BYTE_REAL      = 0x04,
    EIGHT_BYTE_REAL     = 0x05,
    ASCII_STRING        = 0x06,
}

-- helper functions
--[[ not used right now
local function _gdsfloat_to_number(data, width)
    local sign = (data[1] & 0x80) >> 7
    local exp = (data[1] & 0x7f)
    local mantissa = 0
    for i = 2, width do
        mantissa = mantissa + data[i] / (256^(i - 1))
    end
    return sign * mantissa * (16 ^ (exp - 64))
end
--]]

local function _number_to_gdsfloat(num, width)
    local data = {}
    if num == 0 then
        for i = 1, width do
            data[i] = 0x00
        end
        return data
    end
    local sign = false
    if num < 0.0 then
        sign = true
        num = -num
    end
    local exp = 0
    while num >= 1 do
        num = num / 16
        exp = exp + 1
    end
    while num < 0.0625 do
        num = num * 16
        exp = exp - 1
    end
    if sign then
        data[1] = 0x80 + ((exp + 64) & 0x7f)
    else
        data[1] = 0x00 + ((exp + 64) & 0x7f)
    end
    for i = 2, width do
        local int, frac = math.modf(num * 256)
        num = frac
        data[i] = int
    end
    return data
end

local datatable = {
    [datatypes.NONE] = nil,
    [datatypes.BIT_ARRAY] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(binarylib.split_in_bytes(num, 2)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [datatypes.TWO_BYTE_INTEGER] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(binarylib.split_in_bytes(num, 2)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [datatypes.FOUR_BYTE_INTEGER] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(binarylib.split_in_bytes(num, 4)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [datatypes.FOUR_BYTE_REAL] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in _number_to_gdsfloat(num, 4) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [datatypes.EIGHT_BYTE_REAL] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(_number_to_gdsfloat(num, 8)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [datatypes.ASCII_STRING] = function(str) return { string.byte(str, 1, #str) } end,
}

local function _assemble_data(recordtype, datatype, content)
    local data = {
        0x00, 0x00, -- dummy bytes for length, will be filled later
        recordtype, datatype
    }
    local func = datatable[datatype]
    if func then
        for _, b in ipairs(func(content)) do
            table.insert(data, b)
        end
    end
    -- pad with final zero if #data is odd
    if #data % 2 ~= 0 then
        table.insert(data, 0x00)
    end
    local lenbytes = binarylib.split_in_bytes(#data, 2)
    data[1], data[2] = lenbytes[1], lenbytes[2]
    return data
end

local function _write_text_record(file, recordtype, datatype, content)
    if datatype == datatypes.NONE then
        file:write(string.format("%12s #(%4d)\n", recordtype.name, 4))
    else
        local data = _assemble_data(recordtype.code, datatype, content)
        --[[
        local str = {}
        for _, d in ipairs(data) do
            table.insert(str, string.format("0x%02x", d))
        end
        file:write(string.format("%12s (%4d): { %s }\n", recordtype.name, #data, table.concat(str, " ")))
        --]]
        local str
        if datatype == datatypes.NONE then
        elseif datatype == datatypes.BIT_ARRAY or
               datatype == datatypes.TWO_BYTE_INTEGER or
               datatype == datatypes.FOUR_BYTE_INTEGER or
               datatype == datatypes.FOUR_BYTE_REAL or
               datatype == datatypes.EIGHT_BYTE_REAL then
            str = table.concat(content, " ")
        elseif datatype == datatypes.ASCII_STRING then
            str = content
        end
        file:write(string.format("%12s #(%4d): { %s }\n", recordtype.name, #data, str))
    end
end

local function _write_binary_record(file, recordtype, datatype, content)
    local data = _assemble_data(recordtype.code, datatype, content)
    file:write_binary(data)
end

local _write_record = _write_binary_record

local function _unpack_points(pts, multiplier)
    local stream = {}
    for _, pt in ipairs(pts) do
        local x, y = pt:unwrap()
        table.insert(stream, multiplier * x)
        table.insert(stream, multiplier * y)
    end
    return stream
end

-- public interface
function M.get_extension()
    if __textmode then
        return "gdstext"
    else
        return "gds"
    end
end

function M.set_options(opt)
    if opt.libname then __libname = opt.libname end
    if opt.cellname then __cellname = opt.cellname end

    if opt.userunit then
        __userunit = tonumber(opt.userunit)
    end
    if opt.databaseunit then
        __databaseunit = tonumber(opt.databaseunit)
    end

    if opt.textmode then -- enable textmode
        __textmode = true
        _write_record = _write_text_record
    end

    if opt.disablepath then
        M.write_path = nil
    end
end

function M.get_layer(S)
    local lpp = S:get_lpp():get()
    return { layer = lpp.layer, purpose = lpp.purpose }
end

function M.at_begin(file)
    _write_record(file, recordtypes.HEADER, datatypes.TWO_BYTE_INTEGER, { 258 }) -- release 6.0
    local date = os.date("*t")
    _write_record(file, recordtypes.BGNLIB, datatypes.TWO_BYTE_INTEGER, { 
        date.year, date.month, date.day, date.hour, date.min, date.sec, -- last modification time
        date.year, date.month, date.day, date.hour, date.min, date.sec  -- last access time
    })
    _write_record(file, recordtypes.LIBNAME, datatypes.ASCII_STRING, __libname)
    _write_record(file, recordtypes.UNITS, datatypes.EIGHT_BYTE_REAL, { 1 / __userunit, __databaseunit })
end

function M.at_end(file)
    _write_record(file, recordtypes.ENDLIB, datatypes.NONE)
end

function M.at_begin_cell(file, cellname)
    local date = os.date("*t")
    _write_record(file, recordtypes.BGNSTR, datatypes.TWO_BYTE_INTEGER, { 
        date.year, date.month, date.day, date.hour, date.min, date.sec, -- last modification time
        date.year, date.month, date.day, date.hour, date.min, date.sec  -- last access time
    })
    _write_record(file, recordtypes.STRNAME, datatypes.ASCII_STRING, cellname)
end

function M.at_end_cell(file)
    _write_record(file, recordtypes.ENDSTR, datatypes.NONE)
end

function M.write_rectangle(file, layer, bl, tr)
    _write_record(file, recordtypes.BOUNDARY, datatypes.NONE)
    _write_record(file, recordtypes.LAYER, datatypes.TWO_BYTE_INTEGER, { layer.layer })
    _write_record(file, recordtypes.DATATYPE, datatypes.TWO_BYTE_INTEGER, { layer.purpose})
    local ptstream = _unpack_points({ bl, point.combine_21(bl, tr), tr, point.combine_12(bl, tr), bl }, __userunit)
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, ptstream)
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

function M.write_polygon(file, layer, pts)
    local ptstream = _unpack_points(pts, __userunit)
    _write_record(file, recordtypes.BOUNDARY, datatypes.NONE)
    _write_record(file, recordtypes.LAYER, datatypes.TWO_BYTE_INTEGER, { layer.layer })
    _write_record(file, recordtypes.DATATYPE, datatypes.TWO_BYTE_INTEGER, { layer.purpose})
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, ptstream)
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

function M.write_path(file, layer, pts, width)
    local ptstream = _unpack_points(pts, __userunit)
    _write_record(file, recordtypes.PATH, datatypes.NONE)
    _write_record(file, recordtypes.LAYER, datatypes.TWO_BYTE_INTEGER, { layer.layer })
    _write_record(file, recordtypes.DATATYPE, datatypes.TWO_BYTE_INTEGER, { layer.purpose})
    _write_record(file, recordtypes.WIDTH, datatypes.FOUR_BYTE_INTEGER, { width })
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, ptstream)
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

function M.write_cell_reference(file, identifier, x, y, orientation)
    _write_record(file, recordtypes.SREF, datatypes.NONE)
    _write_record(file, recordtypes.SNAME, datatypes.ASCII_STRING, identifier)
    if orientation == "fx" then
        _write_record(file, recordtypes.STRANS, datatypes.BIT_ARRAY, { 0x8000 })
        _write_record(file, recordtypes.ANGLE, datatypes.EIGHT_BYTE_REAL, { 180 })
    elseif orientation == "fy" then
        _write_record(file, recordtypes.STRANS, datatypes.BIT_ARRAY, { 0x8000 })
    elseif orientation == "R180" then
        _write_record(file, recordtypes.ANGLE, datatypes.EIGHT_BYTE_REAL, { 180 })
    end
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, _unpack_points({ point.create(x, y) }, __userunit))
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

function M.write_cell_array(file, identifier, x, y, orientation, xrep, yrep, xpitch, ypitch)
    _write_record(file, recordtypes.AREF, datatypes.NONE)
    _write_record(file, recordtypes.SNAME, datatypes.ASCII_STRING, identifier)
    if orientation == "fx" then
        _write_record(file, recordtypes.STRANS, datatypes.BIT_ARRAY, { 0x8000 })
        _write_record(file, recordtypes.ANGLE, datatypes.EIGHT_BYTE_REAL, { 180 })
    elseif orientation == "fy" then
        _write_record(file, recordtypes.STRANS, datatypes.BIT_ARRAY, { 0x8000 })
    elseif orientation == "R180" then
        _write_record(file, recordtypes.ANGLE, datatypes.EIGHT_BYTE_REAL, { 180 })
    end
    _write_record(file, recordtypes.COLROW, datatypes.TWO_BYTE_INTEGER, { xrep, yrep })
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, 
        _unpack_points({ point.create(x, y), point.create(x + xrep * xpitch, y), point.create(x, y + yrep * ypitch) }, __userunit))
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

function M.write_port(file, name, layer, where)
    _write_record(file, recordtypes.TEXT, datatypes.NONE)
    _write_record(file, recordtypes.LAYER, datatypes.TWO_BYTE_INTEGER, { layer.layer })
    _write_record(file, recordtypes.TEXTTYPE, datatypes.TWO_BYTE_INTEGER, { layer.purpose })
    _write_record(file, recordtypes.PRESENTATION, datatypes.BIT_ARRAY, { 0x0005 })
    _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, _unpack_points({ where }, __userunit))
    _write_record(file, recordtypes.STRING, datatypes.ASCII_STRING, name)
    _write_record(file, recordtypes.ENDEL, datatypes.NONE)
end

return M
