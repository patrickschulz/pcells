function parameters()
    pcell.reference_cell("basic/mosfet")
    pcell.reference_cell("logic/base")
    pcell.add_parameters(
        { "fingers", 1 },
        { "splitenables", false },
        { "inputpos", "center" },
        { "enableppos", "upper" },
        { "enablenpos", "lower" },
        { "swapinputs", false },
        { "swapoutputs", false },
        { "shiftoutput", 0 }
    )
end

function layout(gate, _P)
    local bp = pcell.get_parameters("logic/base")
    local xpitch = bp.gspace + bp.glength
    local xincr = bp.compact and 0 or 1

    local fingers = (_P.splitenables and 3 or 2) * _P.fingers

    local gatecontactpos = { }
    if _P.splitenables then
        for i = 1, _P.fingers do
            if i % 2 == 1 then
                gatecontactpos[(i - 1) * 3 + 1] = _P.inputpos
                gatecontactpos[(i - 1) * 3 + 2] = _P.enableppos
                gatecontactpos[(i - 1) * 3 + 3] = _P.enablenpos
            else
                gatecontactpos[(i - 1) * 3 + 3] = _P.inputpos
                gatecontactpos[(i - 1) * 3 + 2] = _P.enableppos
                gatecontactpos[(i - 1) * 3 + 1] = _P.enablenpos
            end
        end
    else
        for i = 1, _P.fingers do
            if i % 2 == (_P.swapinputs and 0 or 1) then
                gatecontactpos[(i - 1) * 2 + 1] = _P.inputpos
                gatecontactpos[(i - 1) * 2 + 2] = "split"
            else
                gatecontactpos[(i - 1) * 2 + 1] = "split"
                gatecontactpos[(i - 1) * 2 + 2] = _P.inputpos
            end
        end
    end

    local pcontactpos = { }
    local ncontactpos = { }
    local ci1 = _P.swapoutputs and 3 or 1
    local ci2 = _P.swapoutputs and 1 or 3
    if _P.splitenables then
        for i = 1, _P.fingers do
            ncontactpos[(i - 1) * 3 + 2] = "outer"
            ncontactpos[(i - 1) * 3 + 3] = "outer"
            if _P.swapoutputs then
                if i % 2 == 1 then
                    pcontactpos[(i - 1) * 3 + 4] = "inner"
                    ncontactpos[(i - 1) * 3 + 4] = "inner"
                    pcontactpos[(i - 1) * 3 + 2] = "power"
                    ncontactpos[(i - 1) * 3 + 1] = "power"
                else
                    pcontactpos[(i - 1) * 3 + 3] = "power"
                end
            else
                if i % 2 == 1 then
                    pcontactpos[(i - 1) * 3 + 1] = "inner"
                    ncontactpos[(i - 1) * 3 + 1] = "inner"
                    pcontactpos[(i - 1) * 3 + 3] = "power"
                    ncontactpos[(i - 1) * 3 + 4] = "power"
                else
                    pcontactpos[(i - 1) * 3 + 2] = "power"
                end
            end
        end
    else
        for i = 1, _P.fingers do
            if i % 2 == 1 then
                pcontactpos[(i - 1) * 2 + ci1] = "inner"
                ncontactpos[(i - 1) * 2 + ci1] = "inner"
                pcontactpos[(i - 1) * 2 + ci2] = "power"
                ncontactpos[(i - 1) * 2 + ci2] = "power"
            else
                pcontactpos[(i - 1) * 2 + ci1] = "power"
                ncontactpos[(i - 1) * 2 + ci1] = "power"
                pcontactpos[(i - 1) * 2 + ci2] = "inner"
                ncontactpos[(i - 1) * 2 + ci2] = "inner"
            end
        end
    end
    local harness = pcell.create_layout("logic/harness", { 
        fingers = fingers,
        gatecontactpos = gatecontactpos,
        pcontactpos = pcontactpos,
        ncontactpos = ncontactpos,
    })
    gate:merge_into_shallow(harness)
    gate:inherit_alignment_box(harness)

    ---[[
    -- gate straps
    if _P.fingers > 1 then
        if _P.splitenables then
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G1"),
                        harness:get_anchor(string.format("G%d", 
                            _P.fingers % 2 == 0 and 
                                (3 * _P.fingers) or
                                (3 * _P.fingers - 2)
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G2"),
                        harness:get_anchor(string.format("G%d", 
                            3 * _P.fingers - 1
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G3"),
                        harness:get_anchor(string.format("G%d", 
                            _P.fingers % 2 == 0 and 
                                (3 * _P.fingers - 3) or
                                (3 * _P.fingers)
                        )),
                    },
                    bp.sdwidth
                ))
        else
            if _P.swapinputs then
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G2"),
                        harness:get_anchor(string.format("G%d", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers - 1) or
                                (2 * _P.fingers)
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G1upper"),
                        harness:get_anchor(string.format("G%dupper", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers) or
                                (2 * _P.fingers - 1)
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G1lower"),
                        harness:get_anchor(string.format("G%dlower", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers) or
                                (2 * _P.fingers - 1)
                        )),
                    },
                    bp.sdwidth
                ))
            else
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G1"),
                        harness:get_anchor(string.format("G%d", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers) or
                                (2 * _P.fingers - 1)
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G2upper"),
                        harness:get_anchor(string.format("G%dupper", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers - 1) or
                                (2 * _P.fingers)
                        )),
                    },
                    bp.sdwidth
                ))
                gate:merge_into_shallow(geometry.path(
                    generics.metal(1),
                    {
                        harness:get_anchor("G2lower"),
                        harness:get_anchor(string.format("G%dlower", 
                            _P.fingers % 2 == 0 and 
                                (2 * _P.fingers - 1) or
                                (2 * _P.fingers)
                        )),
                    },
                    bp.sdwidth
                ))
            end
        end
    end

    -- drain connection
    if bp.connectoutput then
        local dend = _P.splitenables and (_P.swapoutputs and 4 or 1) or (_P.swapoutputs and 3 or 1)
        gate:merge_into_shallow(geometry.path(generics.metal(1), geometry.path_points_xy(
            harness:get_anchor(string.format("pSDi%d", dend)):translate(0,  bp.sdwidth / 2), {
                harness:get_anchor(string.format("G%d", fingers)):translate(_P.shiftoutput + xpitch / 2, 0),
                0, -- toggle xy
                harness:get_anchor(string.format("nSDi%d", dend)):translate(0, -bp.sdwidth / 2),
        }), bp.sdwidth))
    end

    -- short transistors
    if _P.splitenables then
        for i = 1, _P.fingers do
            gate:merge_into_shallow(geometry.path(generics.metal(1), {
                harness:get_anchor(string.format("nSDc%d", (i - 1) * 3 + 2)),
                harness:get_anchor(string.format("nSDc%d", (i - 1) * 3 + 3)),
            }, bp.sdwidth))
        end
    end

    -- ports
    if _P.splitenables then
        gate:add_port("I", generics.metal(1), harness:get_anchor("G1"))
        gate:add_port("EP", generics.metal(1), harness:get_anchor("G2"))
        gate:add_port("EN", generics.metal(1), harness:get_anchor("G3"))
    else
        if _P.swapinputs then
            gate:add_port("I", generics.metal(1), harness:get_anchor("G2"))
            gate:add_port("EP", generics.metal(1), harness:get_anchor("G1upper"))
            gate:add_port("EN", generics.metal(1), harness:get_anchor("G1lower"))
        else
            gate:add_port("I", generics.metal(1), harness:get_anchor("G1"))
            gate:add_port("EP", generics.metal(1), harness:get_anchor("G2upper"))
            gate:add_port("EN", generics.metal(1), harness:get_anchor("G2lower"))
        end
    end
    gate:add_port("O", generics.metal(1), point.create(_P.fingers * xpitch + _P.shiftoutput, 0))
    gate:add_port("VDD", generics.metal(1), harness:get_anchor("top"))
    gate:add_port("VSS", generics.metal(1),  harness:get_anchor("bottom"))
    --]]
end
