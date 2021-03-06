--[[

 Core:
 *****

    --------------------------------------
    |                                    |
    |                                    |
    |  |\   |\   |\   |\   |\   |\   |\  |
    ---| o--| o--| o--| o--| o--| o--| o--
       |/   |/   |/   |/   |/   |/   |/   

        \-------------v--------------/
                   'numinv'

 Inverter:
 *********
                       VDD
                        |
                    |---|
        vbiasp o---o|    
                    |---|
                        |
                    |---|
                ---o|    
                |   |---|
         in o---|       *---o out
                |   |---|
                ----|    
                    |---|
                        |
                    |---|
        vbiasn o----|    
                    |---|
                        |
                       VSS


    All transistors with 'invfingers' fingers


 Biasing:
 ********
                               
  VDD -----------------*--------*-----------------------
                       |        |                      |
                       |        |  'pmoszerofingers'   |
                       |        |   in series (nf = 1) |
                       |        |---|                  |
                       |            |o---              |
                       |        |---|   |              |
                       |        |       |              |
                       |        |---|   |              |
                       |            |o--*              |
                       |        |---|   |              |
                       |        |       |              |
                       |        |---|   |              |
                       |            |o--*              |
                       |        |---|   |              |
   'pmostunefingers'   |        |       |              |    'pmosdiodefingers'
                   |---|        |---|   |              |---| 
       vtune o----o|                |o--*---- VSS          |o--*-o vbiasp
                   |---|        |---|                  |---|   |
                       *---------                      |       |
                       |                               *--------
                       *--------    vbiasn             |
                       |       |       o               |
                       |---|   |       |           |---|
    'nmosdiodefingers'     |---*-------*-----------|     'nmoscurrentfingers'
                       |---|                       |---|
                       |                               |
  VSS -----------------*--------------------------------
                               
--]]
function parameters()
    pcell.reference_cell("basic/cmos")
    pcell.add_parameters(
        { "invfingers", 2, posvals = even() },
        { "numinv", 17, posvals = odd() },
        { "pmosdiodefingers",    2, posvals = even() },
        { "pmoszerofingers",     7   },
        { "pmostunefingers",     2, posvals = even() },
        { "nmoscurrentfingers",  2, posvals = even() },
        { "nmosdiodefingers",    4, posvals = even() },
        { "glength",             200 },
        { "gspace",              140 },
        { "pfingerwidth",        500 },
        { "nfingerwidth",        500 },
        { "separation",          400 },
        { "gstwidth",             60 },
        { "powerwidth",          120 },
        { "powerspace",           60 }
    )
end

function layout(oscillator, _P)
    local cbp = pcell.get_parameters("basic/cmos")
    local xpitch = _P.glength + _P.gspace

    pcell.push_overwrites("basic/cmos", {
        separation = _P.separation,
        glength = _P.glength,
        gspace = _P.gspace,
        pwidth = _P.pfingerwidth,
        nwidth = _P.nfingerwidth,
        powerwidth = _P.powerwidth,
        powerspace = _P.powerspace,
    })

    -- place inverter cells
    local invgatecontacts = {}
    for i = 1, 2 * _P.invfingers do
        if (i % 4 == 2) or (i % 4 == 3) then
            invgatecontacts[i] = "center"
        else
            invgatecontacts[i] = "outer"
        end
    end
    local invactivecontacts = {}
    for i = 1, 2 * _P.invfingers + 1 do
        if i % 4 == 3 then
            invactivecontacts[i] = "inner"
        elseif i % 4 == 1 then
            invactivecontacts[i] = "power"
        else
            invactivecontacts[i] = "outer"
        end
    end
    local inverterref = pcell.create_layout("basic/cmos", { 
        fingers = 2 * _P.invfingers,
        gatecontactpos = invgatecontacts, 
        pcontactpos = invactivecontacts, 
        ncontactpos = invactivecontacts,
        pcontactheight = _P.pfingerwidth - 120,
        ncontactheight = _P.nfingerwidth - 120,
    })
    inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        inverterref:get_anchor("Gn1"):translate(-xpitch / 2, -_P.gstwidth / 2),
        inverterref:get_anchor(string.format("Gn%d", 2 * _P.invfingers)):translate(xpitch / 2, _P.gstwidth / 2)
    ))
    inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        inverterref:get_anchor("Gp1"):translate(-xpitch / 2, -_P.gstwidth / 2),
        inverterref:get_anchor(string.format("Gp%d", 2 * _P.invfingers)):translate(xpitch / 2, _P.gstwidth / 2)
    ))
    inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        inverterref:get_anchor(string.format("G%d", 2 + 0)):translate(0, -_P.gstwidth / 2),
        inverterref:get_anchor(string.format("G%d", 2 + 4 * (_P.invfingers / 2 - 1) + 1)):translate(0,  _P.gstwidth / 2)
    ))
    for i = 3, 2 * _P.invfingers, 4 do
        inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            inverterref:get_anchor(string.format("pSDo%d", i - 1)):translate(0, -_P.gstwidth),
            inverterref:get_anchor(string.format("pSDo%d", i + 1))
        ))
        inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            inverterref:get_anchor(string.format("nSDo%d", i - 1)):translate(0,  _P.gstwidth),
            inverterref:get_anchor(string.format("nSDo%d", i + 1))
        ))
    end
    -- connect current sources drains on M2
    if _P.invfingers > 2 then
        inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(2), 
            inverterref:get_anchor(string.format("pSDo%d", 2)):translate(0, -_P.gstwidth),
            inverterref:get_anchor(string.format("pSDo%d", 2 * _P.invfingers))
        ))
        inverterref:merge_into_shallow(geometry.rectanglebltr(generics.metal(2), 
            inverterref:get_anchor(string.format("nSDo%d", 2)):translate(0, _P.gstwidth),
            inverterref:get_anchor(string.format("nSDo%d", 2 * _P.invfingers))
        ))
        for i = 3, 2 * _P.invfingers, 4 do
            inverterref:merge_into_shallow(geometry.rectanglebltr(generics.via(1, 2), 
                inverterref:get_anchor(string.format("pSDo%d", i - 1)):translate(0, -_P.gstwidth),
                inverterref:get_anchor(string.format("pSDo%d", i + 1))
            ))
            inverterref:merge_into_shallow(geometry.rectanglebltr(generics.via(1, 2), 
                inverterref:get_anchor(string.format("nSDo%d", i - 1)):translate(0,  _P.gstwidth),
                inverterref:get_anchor(string.format("nSDo%d", i + 1))
            ))
        end
    end
    inverterref:merge_into_shallow(geometry.path(generics.metal(1), geometry.path_points_xy(
        inverterref:get_anchor(string.format("pSDi%d", 3)):translate(0, _P.gstwidth / 2), {
            2 * (_P.invfingers - 1) * xpitch,
            inverterref:get_anchor(string.format("nSDi%d", 3)):translate(0, -_P.gstwidth / 2),
        }), _P.gstwidth
    ))
    local invname = pcell.add_cell_reference(inverterref, "inverter")
    local inverters = {}
    for i = 1, _P.numinv do
        inverters[i] = oscillator:add_child(invname)
        if i > 1 then
            inverters[i]:move_anchor("left", inverters[i - 1]:get_anchor("right"))
        end
    end

    -- current mirror settings
    local cmgatecontacts = {}
    local cmfingers = math.max(_P.pmosdiodefingers + _P.pmoszerofingers + _P.pmostunefingers + 1, _P.nmoscurrentfingers + _P.nmosdiodefingers)
    for i = 1, cmfingers do
        cmgatecontacts[i] = "split"
    end
    local cmpactivecontacts = {}
    local cmnactivecontacts = {}
    -- pmos active contacts
    cmpactivecontacts[cmfingers + 1 - _P.pmosdiodefingers - _P.pmoszerofingers] = "inner"
    for i = 2, _P.pmosdiodefingers, 2 do
        cmpactivecontacts[cmfingers + 2 - i] = "inner"
        cmpactivecontacts[cmfingers + 1 - i] = "power"
    end
    for i = 2, _P.pmostunefingers, 2 do
        cmpactivecontacts[cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers + 1 - i] = "inner"
        cmpactivecontacts[cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers + 0 - i] = "power"
    end
    -- nmos active contacts
    for i = 2, _P.nmosdiodefingers + _P.nmoscurrentfingers, 2 do
        cmnactivecontacts[cmfingers + 2 - i] = "inner"
        cmnactivecontacts[cmfingers + 1 - i] = "power"
    end
    -- fill dummy contacts
    cmpactivecontacts[cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers] = "power"
    for i = 1, cmfingers - _P.pmostunefingers - _P.pmoszerofingers - _P.pmosdiodefingers - 1 do
        cmpactivecontacts[i] = "power"
    end
    for i = 1, cmfingers - _P.nmosdiodefingers - _P.nmoscurrentfingers do
        cmnactivecontacts[i] = "power"
    end
    -- create current mirror layout
    local cmarray = pcell.create_layout("basic/cmos", { 
        fingers = cmfingers,
        gatecontactpos = cmgatecontacts, 
        pcontactpos = cmpactivecontacts, 
        ncontactpos = cmnactivecontacts,
        pcontactheight = _P.pfingerwidth - 120,
        ncontactheight = _P.nfingerwidth - 120,
    })
    -- pmos diode
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers + 1)):translate(0, -_P.gstwidth / 2),
        cmarray:get_anchor(string.format("Gu%d", cmfingers)):translate(0,  _P.gstwidth / 2)
    ))
    -- pmos zero current
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers + 1)):translate(0,  _P.gstwidth / 2),
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers)):translate(0, -_P.gstwidth / 2)
    ))
    -- pmos tuning
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers - _P.pmostunefingers)):translate(0,  _P.gstwidth / 2),
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers - 1)):translate(0, -_P.gstwidth / 2)
    ))
    -- nmos current mirror
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        cmarray:get_anchor(string.format("Gl%d", cmfingers - _P.nmoscurrentfingers - _P.nmosdiodefingers + 1)):translate(0, -_P.gstwidth / 2),
        cmarray:get_anchor(string.format("Gl%d", cmfingers)):translate(0,  _P.gstwidth / 2)
    ))
    -- pmos dummies
    if _P.pmosdiodefingers + _P.pmoszerofingers + _P.pmostunefingers + 1 < _P.nmoscurrentfingers + _P.nmosdiodefingers then
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("Gu%d", 1)):translate(0, -_P.gstwidth / 2),
            cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers - _P.pmostunefingers - 1)):translate(0, _P.gstwidth / 2)
        ))
    end
    -- nmos dummies
    if _P.pmosdiodefingers + _P.pmoszerofingers + _P.pmostunefingers + 1 > _P.nmoscurrentfingers + _P.nmosdiodefingers then
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("Gl%d", 1)):translate(0, -_P.gstwidth / 2),
            cmarray:get_anchor(string.format("Gl%d", cmfingers - _P.nmosdiodefingers - _P.nmoscurrentfingers)):translate(0, _P.gstwidth / 2)
        ))
    end
    -- draw bias source/drain connections
    for i = 2, _P.pmosdiodefingers, 2 do
        local index = cmfingers + 2 - i
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("pSDi%d", index)):translate(-_P.gstwidth / 2, 0),
            point.combine_12(
                cmarray:get_anchor(string.format("pSDi%d", index)),
                cmarray:get_anchor(string.format("Gu%d", index))
            ):translate(_P.gstwidth / 2, 0)
        ))
    end
    for i = 2, _P.nmosdiodefingers, 2 do
        local index = cmfingers - _P.nmoscurrentfingers + 2 - i
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("nSDi%d", index)):translate(-_P.gstwidth / 2, 0),
            point.combine_12(
                cmarray:get_anchor(string.format("nSDi%d", index)),
                cmarray:get_anchor(string.format("Gl%d", index))
            ):translate(_P.gstwidth / 2, 0)
        ))
    end
    for i = 2, cmfingers - _P.pmostunefingers - _P.pmoszerofingers - _P.pmosdiodefingers - 1 do
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("pSDi%d", i)):translate(-_P.gstwidth / 2, 0),
            point.combine_12(
                cmarray:get_anchor(string.format("pSDi%d", i)),
                cmarray:get_anchor(string.format("Gu%d", i))
            ):translate(_P.gstwidth / 2, 0)
        ))
    end
    for i = 2, cmfingers - _P.nmosdiodefingers - _P.nmoscurrentfingers do
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
            cmarray:get_anchor(string.format("nSDi%d", i)):translate(-_P.gstwidth / 2, 0),
            point.combine_12(
                cmarray:get_anchor(string.format("nSDi%d", i)),
                cmarray:get_anchor(string.format("Gl%d", i))
            ):translate(_P.gstwidth / 2, 0)
        ))
    end
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(1), 
        cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers)):translate(-_P.gstwidth / 2, 0),
        point.combine_12(
            cmarray:get_anchor(string.format("Gu%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers)),
            cmarray:get_anchor("top")
        ):translate(_P.gstwidth / 2, 0)
    ))
    -- connect left pmos/nmos
    for i = 0, _P.pmostunefingers, 2 do
        local index = cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers + 1 - i
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.via(1, 2), 
            cmarray:get_anchor(string.format("pSDi%d", index)):translate(-_P.gstwidth / 2, 0),
            cmarray:get_anchor(string.format("pSDo%d", index)):translate( _P.gstwidth / 2, 0)
        ))
    end
    cmarray:merge_into_shallow(geometry.rectangle(generics.via(1, 2), xpitch, _P.gstwidth)
        :translate(cmarray:get_anchor(string.format("Gl%d", cmfingers - _P.nmoscurrentfingers)))
    )
    -- connect right pmos/nmos
    cmarray:merge_into_shallow(geometry.rectanglebltr(generics.metal(2), 
        cmarray:get_anchor(string.format("nSDo%d", cmfingers)):translate(-_P.gstwidth / 2, 0),
        cmarray:get_anchor(string.format("pSDo%d", cmfingers)):translate( _P.gstwidth / 2, 0)
    ))
    if _P.pmosdiodefingers > 2 then
        cmarray:merge_into_shallow(geometry.path(generics.metal(2), {
            cmarray:get_anchor(string.format("pSDc%d", cmfingers - _P.pmosdiodefingers + 2)),
            cmarray:get_anchor(string.format("pSDc%d", cmfingers)),
        }, _P.gstwidth))
    end
    if _P.nmoscurrentfingers > 2 then
        cmarray:merge_into_shallow(geometry.path(generics.metal(2), {
            cmarray:get_anchor(string.format("nSDc%d", cmfingers - _P.nmoscurrentfingers + 2)),
            cmarray:get_anchor(string.format("nSDc%d", cmfingers)),
        }, _P.gstwidth))
    end
    for i = 2, _P.pmosdiodefingers, 2 do
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.via(1, 2), 
            cmarray:get_anchor(string.format("pSDi%d", cmfingers + 2 - i)):translate(-_P.gstwidth / 2, 0),
            cmarray:get_anchor(string.format("pSDo%d", cmfingers + 2 - i)):translate( _P.gstwidth / 2, 0)
        ))
    end
    for i = 2, _P.nmoscurrentfingers, 2 do
        cmarray:merge_into_shallow(geometry.rectanglebltr(generics.via(1, 2), 
            cmarray:get_anchor(string.format("nSDo%d", cmfingers + 2 - i)):translate(-_P.gstwidth / 2, 0),
            cmarray:get_anchor(string.format("nSDi%d", cmfingers + 2 - i)):translate( _P.gstwidth / 2, 0)
        ))
    end
    local cmname = pcell.add_cell_reference(cmarray, "currentmirror")
    local currentmirror = oscillator:add_child(cmname)
    currentmirror:move_anchor("right", inverters[1]:get_anchor("left"))

    -- draw inverter connections
    for i = 1, _P.numinv - 1 do
        -- connect drains to gate of next inverter
        oscillator:merge_into_shallow(geometry.path(generics.metal(1), 
            geometry.path_points_xy(
            point.combine_12(
                inverters[i]:get_anchor(string.format("pSDi%d", 2 * _P.invfingers + 1)),
                inverters[i]:get_anchor(string.format("G%d", 2))
            ), { 2 * xpitch }), _P.gstwidth))
    end

    oscillator:merge_into_shallow(geometry.path(generics.metal(2), geometry.path_points_yx(
        currentmirror:get_anchor(string.format("pSDo%d", cmfingers)), {
            inverters[1]:get_anchor("Gp1")
        }), _P.gstwidth
    ))
    oscillator:merge_into_shallow(geometry.rectangle(generics.via(1, 2), xpitch, _P.gstwidth)
        :translate(inverters[1]:get_anchor("Gp1"))
    )

    oscillator:merge_into_shallow(geometry.path(generics.metal(2), geometry.path_points_xy(
        currentmirror:get_anchor(string.format("pSDc%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers - _P.pmostunefingers + 1)), {
        currentmirror:get_anchor(string.format("pSDc%d", cmfingers - _P.pmosdiodefingers - _P.pmoszerofingers + 1)),
        0, -- toggle xy
        currentmirror:get_anchor(string.format("Gl%d", cmfingers - _P.nmoscurrentfingers)),
        inverters[1]:get_anchor("Gn1")
    }), _P.gstwidth))
    oscillator:merge_into_shallow(geometry.rectangle(generics.via(1, 2), xpitch, _P.gstwidth)
        :translate(currentmirror:get_anchor(string.format("Gl%d", cmfingers - _P.nmoscurrentfingers)))
    )
    oscillator:merge_into_shallow(geometry.rectangle(generics.via(1, 2), xpitch, _P.gstwidth)
        :translate(inverters[1]:get_anchor("Gn1"))
    )

    -- feedback connection
    oscillator:merge_into_shallow(geometry.path(generics.metal(2), {
            inverters[_P.numinv]:get_anchor(string.format("pSDc%d", 2 * _P.invfingers + 1)) .. inverters[_P.numinv]:get_anchor(string.format("G%d", 2)),
            inverters[1]:get_anchor("G2"):translate(-_P.glength / 2, 0)
        }, _P.gstwidth)
    )
    oscillator:merge_into_shallow(
        geometry.rectangle(generics.via(1, 2), _P.gstwidth, _P.separation + 2 * _P.gstwidth)
        :translate(
            inverters[_P.numinv]:get_anchor(string.format("pSDc%d", 2 * _P.invfingers + 1)) .. 
            inverters[_P.numinv]:get_anchor("G2")
        )
    )
    oscillator:merge_into_shallow(
        geometry.rectangle(generics.via(1, 2), 2 * _P.glength + _P.gspace, _P.gstwidth)
        :translate(inverters[1]:get_anchor("G2"):translate(xpitch / 2, 0))
    )

    -- center oscillator
    oscillator:translate((cmfingers + _P.invfingers - (_P.numinv * 2 * _P.invfingers - _P.invfingers)) * xpitch / 2, 0)

    -- place guardring
    local ringwidth = 200
    local pguardringname = pcell.add_cell_reference(pcell.create_layout("auxiliary/guardring", { 
        contype = "p",
        fillwell = true,
        ringwidth = ringwidth,
        width = (cmfingers + 2 * _P.numinv * _P.invfingers + 4) * xpitch, 
        height = 6 * _P.separation + _P.pfingerwidth + _P.nfingerwidth + ringwidth
    }), "pguardring")
    local nguardringname = pcell.add_cell_reference(pcell.create_layout("auxiliary/guardring", { 
        contype = "n",
        fillwell = false,
        drawdeepwell = true,
        ringwidth = ringwidth,
        width = (cmfingers + 2 * _P.numinv * _P.invfingers + 4) * xpitch + 2 * _P.separation + 2 * ringwidth,
        height = 8 * _P.separation + _P.pfingerwidth + _P.nfingerwidth + ringwidth + 2 * ringwidth
    }), "nguardring")
    oscillator:add_child(pguardringname)
    oscillator:add_child(nguardringname)
end
