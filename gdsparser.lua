local M = {}

local recordcodes = gdstypetable.recordtypescodes
local recordnames = gdstypetable.recordtypesnames
local datatable = gdstypetable.datatypes

local function read_bytes(file, numbytes)
    local t = {}
    local chunk = file:read(numbytes)
    for i = 1, numbytes do
        t[i] = string.byte(string.sub(chunk, i, i))
    end
    return t
end

local function read_onebyte_integer(file)
    local chunk = file:read(1)
    if chunk then
        return string.byte(chunk)
    end
end

local function read_twobyte_integer(file)
    local chunk = file:read(2)
    if chunk then
        local byte1, byte2 = string.byte(chunk, 1, 2)
        return byte1 * 256 + byte2
    end
end

local function read_header(file)
    local data = {
        length      = read_twobyte_integer(file),
        recordtype  = read_onebyte_integer(file),
        datatype    = read_onebyte_integer(file),
    }
    return data
end

local function read_data(file, header)
    local numbytes = header.length - 4
    return read_bytes(file, numbytes)
end

local function _parse_bit_array(data)
    local res = {}
    for i = 1, 8 do
        res[i] = (data[1] & (1 << (8 - i))) >> (8 - i)
    end
    for i = 1, 8 do
        res[8 + i] = (data[2] & (1 << (8 - i))) >> (8 - i)
    end
    return res
end

local function _parse_integer(data, width, start)
    local num = 0
    if data[start + 1] > 127 then -- negative
        num = -1 * 2^32
    end
    for i = 1, width do
        num = num + data[start + i] * (1 << (8 * (width - i)))
    end
    return num
end

local function _parse_real(data, width, start)
    local sign
    if ((data[start + 1] & 0x80) >> 7) == 0 then sign = 1 else sign = -1 end
    local exp = (data[start + 1] & 0x7f)
    local mantissa = 0
    for i = 2, width do
        mantissa = mantissa + data[start + i] / (256^(i - 1))
    end
    return sign * mantissa * (16 ^ (exp - 64))
end

local function _array_fun(data, func, width)
    if #data > width then
        local nums = {}
        for i = 1, #data / width do
            local num = func(data, width, (i - 1) * width)
            table.insert(nums, num)
        end
        return nums
    else
        return func(data, width, 0)
    end
end

local function _parse_data(header, data)
    if header.datatype == datatable.NONE then
        return nil
    elseif header.datatype == datatable.BIT_ARRAY then
        return _parse_bit_array(data)
    elseif header.datatype == datatable.TWO_BYTE_INTEGER then
        return _array_fun(data, _parse_integer, 2)
    elseif header.datatype == datatable.FOUR_BYTE_INTEGER then
        return _array_fun(data, _parse_integer, 4)
    elseif header.datatype == datatable.FOUR_BYTE_REAL then
        return _array_fun(data, _parse_real, 4)
    elseif header.datatype == datatable.EIGHT_BYTE_REAL then
        return _array_fun(data, _parse_real, 8)
    elseif header.datatype == datatable.ASCII_STRING then
        local t = {}
        for i = 1, #data do
            table.insert(t, string.char(data[i]))
        end
        if data[#data] == 0 then
            t[#t] = nil
        end
        return table.concat(t)
    else
        error("unknown datatype")
    end
end

local function read_record(file)
    local header = read_header(file)
    if not header then return nil end
    local data = read_data(file, header)
    return header, data
end

local function _read_stream(filename)
    local file = io.open(filename, "r")
    if not file then
        moderror(string.format("gdsparser: could not open file '%s'", filename))
    end
    local records = {}
    while true do
        local header, data = read_record(file)
        table.insert(records, { header = header, raw = data, data = _parse_data(header, data) })
        if header.recordtype == recordcodes.ENDLIB then
            break
        end
    end
    return records
end

function M.show_records(filename, flags)
    if flags == "all" then
        flags = {
            showrecordlength = true
        }
    end
    local records = _read_stream(filename)
    local indent = 0
    for _, record in ipairs(records) do
        local header, data = record.header, record.data
        if header.recordtype == 0x04 or 
            header.recordtype == 0x07 or 
            header.recordtype == 0x11 then 
            indent = indent - 1
        end
        if flags.showrecordlength then
            io.write(string.format("%s%s (%d)", string.rep(" ", 4 * indent), recordnames[header.recordtype], header.length))
        else
            io.write(string.format("%s%s", string.rep(" ", 4 * indent), recordnames[header.recordtype]))
        end
        if type(data) == "table" then
            data = "{ " .. table.concat(data, " ") .. " }"
        end
        if data then
            print(string.format(" -> data: %s", data))
        else
            print()
        end
        if header.recordtype == 0x01 or 
            header.recordtype == 0x05 or 
            header.recordtype == 0x08 or 
            header.recordtype == 0x09 or 
            header.recordtype == 0x0b or 
            header.recordtype == 0x0c or 
            header.recordtype == 0x2d or 
            header.recordtype == 0x0a then 
            indent = indent + 1
        end
    end
end

function M.read_cells(filename)
    local cells = {}
    local records = _read_stream(filename)
    local cell
    local shape
    local function is_record(record, rtype) return record.header.recordtype == recordcodes[rtype] end
    for _, record in ipairs(records) do
        if is_record(record, "BGNSTR") then
            cell = {
                shapes = {},
                references = {},
                labels = {}
            }
        elseif is_record(record, "ENDSTR") then
            table.insert(cells, cell)
            cell = nil
        elseif is_record(record, "STRNAME") then
            cell.name = record.data
        elseif is_record(record, "BOUNDARY") or
               is_record(record, "BOX") or
               is_record(record, "PATH") then
            obj = { 
                what = "shape",
                shapetype = (is_record(record, "BOUNDARY") and "polygon") or
                       (is_record(record, "BOX") and "rectangle") or
                       (is_record(record, "PATH") and "path")
            }
        elseif is_record(record, "SREF") then
            obj = { what = "sref" }
        elseif is_record(record, "AREF") then
            obj = { what = "aref" }
        elseif is_record(record, "TEXT") then
            obj = { what = "text" }
        elseif is_record(record, "ENDEL") then
            if obj.what == "shape" then
                table.insert(cell.shapes, obj)
            elseif obj.what == "sref" then
                table.insert(cell.references, obj)
            elseif obj.what == "aref" then
                table.insert(cell.references, obj)
            elseif obj.what == "text" then
                table.insert(cell.labels, obj)
            end
            obj = nil
        elseif is_record(record, "LAYER") then
            obj.layer = record.data
        elseif is_record(record, "DATATYPE") then
            obj.purpose = record.data
        elseif is_record(record, "TEXTTYPE") then
            obj.purpose = record.data
        elseif is_record(record, "XY") then
            obj.pts = record.data
        elseif is_record(record, "WIDTH") then
            obj.width = record.data
        elseif is_record(record, "COLROW") then
            obj.xrep = record.data[1]
            obj.yrep = record.data[2]
        elseif is_record(record, "SNAME") then
            obj.name = record.data
        elseif is_record(record, "STRING") then
            obj.text = record.data
        end
    end
    return cells
end

local function _get_cell_references(cell)
    local references = {}
    for _, ref in ipairs(cell.references) do
        table.insert(references, ref.name)
    end
    return references
end

local function _find_cell(cells, cellname)
    for _, cell in ipairs(cells) do
        if cell.name == cellname then
            return cell
        end
    end
end

local function _assemble_tree_element(cells, tree, cell, level)
    for _, ref in ipairs(cell.references) do
        local sub = _find_cell(cells, ref.name)
        table.insert(tree, { level = level + 1, cell = sub })
        _assemble_tree_element(cells, tree, sub, level + 1)
    end
end

function M.resolve_hierarchy(cells)
    local referenced = {}
    for _, cell in ipairs(cells) do
        local references = _get_cell_references(cell)
        for _, ref in ipairs(references) do
            table.insert(referenced, ref)
        end
    end
    local toplevel = {}
    for _, cell in ipairs(cells) do
        if not aux.any_of(function(r) return cell.name == r end, referenced) then
            table.insert(toplevel, cell)
        end
    end
    local tree = {}
    for _, cell in ipairs(toplevel) do
        table.insert(tree, { level = 0, cell = cell })
        _assemble_tree_element(cells, tree, cell, 0)
    end
    return tree
end

return M
