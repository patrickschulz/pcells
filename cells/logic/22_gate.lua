--[[
    A1 ---- GATE1
            GATE1
    A2 ---- GATE1 ---- GATE3 
                       GATE3 ---- Z
    B1 ---- GATE2 ---- GATE3
            GATE2
    B2 ---- GATE2
--]]

function 
    parameters() pcell.reference_cell("logic/base")
    pcell.add_parameters(
        { "flipconnection", false },
        { "gate1", "and_gate" },
        { "gate2", "and_gate" },
        { "gate3", "nor_gate" }
    )
end

function layout(gate, _P)
    local bp = pcell.get_parameters("logic/base");
    local separation = bp.numinnerroutes * bp.gstwidth + (bp.numinnerroutes + 1) * bp.gstspace

    -- isolation dummy
    local isogateref = pcell.create_layout("logic/isogate")
    local isoname = pcell.add_cell_reference(isogateref, "isogate")
    local isogate

    -- gate 1
    pcell.push_overwrites("logic/base", { rightdummies = 0 })
    local gate1ref = pcell.create_layout(string.format("logic/%s", _P.gate1))
    local gate1name = pcell.add_cell_reference(gate1ref, "gate1")
    local gate1 = gate:add_child(gate1name)
    pcell.pop_overwrites("logic/base")

    isogate = gate:add_child(isoname)
    isogate:move_anchor("left", gate1:get_anchor("right"))

    -- gate 2
    pcell.push_overwrites("logic/base", { leftdummies = 0, rightdummies = 0 })
    local gate2ref = pcell.create_layout(string.format("logic/%s", _P.gate2))
    local gate2name = pcell.add_cell_reference(gate2ref, "gate2")
    local gate2 = gate:add_child(gate2name)
    gate2:move_anchor("left", isogate:get_anchor("right"))
    pcell.pop_overwrites("logic/base")

    isogate = gate:add_child(isoname)
    isogate:move_anchor("left", gate2:get_anchor("right"))

    -- gate 3
    pcell.push_overwrites("logic/base", { leftdummies = 0 })
    local gate3ref = pcell.create_layout(string.format("logic/%s", _P.gate3))
    local gate3name = pcell.add_cell_reference(gate3ref, "gate3")
    local gate3 = gate:add_child(gate3name)
    gate3:move_anchor("left", isogate:get_anchor("right"))
    pcell.pop_overwrites("logic/base")

    -- draw connections
    gate:merge_into_shallow(geometry.path(generics.metal(2), 
        geometry.path_points_yx(gate1:get_anchor("Z"), {
            gate1:get_anchor("Z"):translate(0, (_P.flipconnection and -1 or 1) * (separation / 2 + bp.sdwidth / 2)),
            0, -- toggle xy
            gate3:get_anchor("B")
    }), bp.sdwidth))
    gate:merge_into_shallow(geometry.rectangle(generics.via(1, 2), bp.sdwidth, bp.sdwidth):translate(gate1:get_anchor("Z")))
    gate:merge_into_shallow(geometry.rectangle(generics.via(1, 2), bp.sdwidth, bp.sdwidth):translate(gate3:get_anchor("B")))

    gate:merge_into_shallow(geometry.path(generics.metal(1), 
        geometry.path_points_yx(gate2:get_anchor("Z"), {
        gate3:get_anchor("A")
    }), bp.sdwidth))

    -- alignmentbox
    gate:inherit_alignment_box(gate1)
    gate:inherit_alignment_box(gate3)

    -- draw ports
    gate:add_port("A1", generics.metal(1), gate1:get_anchor("A"))
    gate:add_port("A2", generics.metal(1), gate1:get_anchor("B"))
    gate:add_port("B1", generics.metal(1), gate2:get_anchor("A"))
    gate:add_port("B2", generics.metal(1), gate2:get_anchor("B"))
    gate:add_port("Z", generics.metal(1), gate3:get_anchor("Z"))
    gate:add_port("VDD", generics.metal(1), isogate:get_anchor("VDD"))
    gate:add_port("VSS", generics.metal(1), isogate:get_anchor("VSS"))
end
