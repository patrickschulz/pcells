-- for random shuffle
math.randomseed(os.time())

-- debugging
local function _trace (event)
    local s = debug.getinfo(2).name
    print(s)
end

--debug.sethook(_trace, "c")

local techlib = _load_module("technology")
local interface = _load_module("interface")

-- parse command line arguments
local argparse = _load_module("argparse")
local args = argparse.parse(arg)
-- prepare cell arguments
local cellargs = {}
for k, v in string.gmatch(table.concat(args.cellargs, " "), "(%w+)%s*=%s*(%S+)") do
    cellargs[k] = v
end

--debuglib.set(args.debug)

if not args.cell then
    print("no cell type given")
    os.exit(exitcodes.nocelltype)
end

-- output cell parameters
if args.params then
    pcell.parameters(args.cell)
    os.exit(0)
end

if not args.technology then
    print("no technology given")
    os.exit(exitcodes.notechnology)
end
if not args.interface then
    print("no interface given")
    os.exit(exitcodes.nointerface)
end

local tech = techlib.load(args.technology)
interface.load(args.interface)

local cell, msg = pcell.create_layout(args.cell, cellargs, true)
if not cell then
    print(string.format("error while creating cell, received: %s", msg))
    os.exit(exitcodes.errorincell)
end
if args.origin then
    local dx, dy = string.match(args.origin, "%(%s*([-%d]+)%s*,%s*([-%d]+)%s*%)")
    if not dx then 
        print(string.format("could not parse origin (%s)", args.origin))
        os.exit(exitcodes.unknown)
    end
    cell:translate(dx, dy)
end

local techintf = args.interface
if not args.notech then
    techlib.translate_metals(cell)
    techlib.split_vias(cell)
    techlib.create_via_geometries(cell, techintf)
    techlib.map_layers(cell, techintf)
    techlib.fix_to_grid(cell)
end

local filename = args.filename or "openPCells"
interface.set_options(args.interface_options)
interface.write_cell(filename, cell)

-- vim: ft=lua
