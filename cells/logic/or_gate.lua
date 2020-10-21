function parameters()
    pcell.inherit_all_parameters("logic/_base")
    pcell.add_parameters(
        { "norfingers", 1 },
        { "notfingers", 1 }
    )
end

function layout(gate, _P)
    local _P1 = pcell.clone_matching_parameters("logic/nor_gate", _P)
    _P1.fingers = _P.norfingers
    _P1.rightdummies = 0
    local _P2 = pcell.clone_matching_parameters("logic/not_gate", _P)
    _P2.fingers = _P.notfingers
    _P2.leftdummies = 0
    gate:merge_into(pcell.create_layout("logic/nor_gate", _P1):move_anchor("right"))
    gate:merge_into(pcell.create_layout("logic/not_gate", _P2):move_anchor("left"))

    -- draw connection
    gate:merge_into(geometry.path(generics.metal(1), {
        point.create(-_P.sdwidth / 2, 0),
        point.create(_P.glength + _P.gspace / 2, 0),
    }, _P.sdwidth))
end
