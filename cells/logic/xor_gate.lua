--[[
    VDD ----*-----------------------*
            |                       |
            |                       |
          |-|                     |-|
    A ---o|                ~A ---o|
          |-|                     |-|
            |                       |
          |-|                     |-|
   ~B ---o|                 B ---o|
          |-|                     |-|
            |                       |
            *-----------------------*-------o A XOR B
            |                       |
          |-|                     |-|
   ~B ----|                 B ----|
          |-|                     |-|
            |                       |
          |-|                     |-|
   ~A ----|                 A ----|
          |-|                     |-|
            |                       |
            |                       |
    VSS ----*-----------------------*
--]]

function parameters()
    pcell.reference_cell("basic/transistor")
    pcell.reference_cell("logic/base")
    pcell.add_parameter("fingers", 1)
end

function layout(gate, _P)
    local bp = pcell.get_parameters("logic/base")
    local xpitch = bp.gspace + bp.glength
    local routingshift = bp.separation / 4 - bp.sdwidth / 2

    local block = object.create()

    pcell.push_overwrites("logic/base", { leftdummies = 0, rightdummies = 0 })
    local harness = pcell.create_layout("logic/harness", { fingers = 6 * _P.fingers })
    gate:merge_into(harness)
    pcell.pop_overwrites("logic/base")

    -- common transistor options
    pcell.push_overwrites("basic/transistor", {
        fingers = 6,
        gatelength = bp.glength,
        gatespace = bp.gspace,
        sdwidth = bp.sdwidth,
        drawinnersourcedrain = false,
        drawoutersourcedrain = false,
    })

    -- pmos
    pcell.push_overwrites("basic/transistor", {
        channeltype = "pmos",
        fwidth = bp.pwidth,
        gtopext = bp.powerspace + bp.dummycontheight / 2 + bp.powerwidth / 2,
        gbotext = bp.separation / 2,
        clipbot = true,
    })
    block:merge_into(pcell.create_layout("basic/transistor"):move_anchor("botgate"))
    pcell.pop_overwrites("basic/transistor")

    -- nmos
    pcell.push_overwrites("basic/transistor", {
        channeltype = "nmos",
        fwidth = bp.nwidth,
        gbotext = bp.powerspace + bp.dummycontheight / 2 + bp.powerwidth / 2,
        gtopext = bp.separation / 2,
        cliptop = true,
    })
    block:merge_into(pcell.create_layout("basic/transistor"):move_anchor("topgate"))
    pcell.pop_overwrites("basic/transistor")
    -- pop general transistor overwrites
    pcell.pop_overwrites("basic/transistor")

    -- gate contacts
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate(-5 * xpitch / 2, -routingshift))
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate(-3 * xpitch / 2, -routingshift))
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate(-xpitch / 2,  routingshift))
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate( xpitch / 2,  routingshift))
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate( 3 * xpitch / 2, -routingshift))
    block:merge_into(geometry.rectangle(generics.contact("gate"), bp.glength, bp.gstwidth):translate( 5 * xpitch / 2, -routingshift))

    -- pmos source/drain contacts
    block:merge_into(geometry.rectangle(
        generics.contact("active"), bp.sdwidth, bp.pwidth / 2
    ):translate(0, (bp.separation + bp.pwidth / 2) / 2))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.nwidth / 2),
        2, 5 * xpitch
    ):translate(-xpitch / 2, bp.separation / 2 + bp.pwidth * 3 / 4))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.metal(1), bp.sdwidth, bp.powerspace),
        2, 5 * xpitch
    ):translate(-xpitch / 2, bp.separation / 2 + bp.pwidth + bp.powerspace / 2))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.nwidth / 2),
        2, 1 * xpitch
    ):translate(-3 * xpitch / 2, bp.separation / 2 + bp.pwidth * 3 / 4))
    block:merge_into(geometry.rectangle(
        generics.contact("active"), bp.sdwidth, bp.nwidth / 2
    ):translate(3 * xpitch, bp.separation / 2 + bp.pwidth * 3 / 4))
    block:merge_into(geometry.rectangle(
        generics.metal(1), bp.sdwidth, bp.powerspace
    ):translate(3 * xpitch, bp.separation / 2 + bp.pwidth + bp.powerspace / 2))
    block:merge_into(geometry.rectangle(generics.metal(1), xpitch, bp.sdwidth):translate(-3 * xpitch / 2, bp.separation / 2 + 3 * bp.pwidth / 4))

    -- nmos source/drain contacts
    block:merge_into(geometry.rectangle(
        generics.contact("active"), bp.sdwidth, bp.nwidth / 2
    ):translate(0, -(bp.separation + bp.nwidth / 2) / 2))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.nwidth / 2),
        2, 5 * xpitch
    ):translate(xpitch / 2, -bp.separation / 2 - bp.nwidth * 3 / 4))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.metal(1), bp.sdwidth, bp.powerspace),
        2, 5 * xpitch
    ):translate(xpitch / 2, -bp.separation / 2 - bp.nwidth - bp.powerspace / 2))
    block:merge_into(geometry.multiple_x(
        geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.nwidth / 2),
        2, 1 * xpitch
    ):translate(3 * xpitch / 2, -bp.separation / 2 - bp.nwidth * 3 / 4))
    block:merge_into(geometry.rectangle(generics.metal(1), xpitch, bp.sdwidth):translate(3 * xpitch / 2, -bp.separation / 2 - 3 * bp.nwidth / 4))

    block:merge_into(geometry.rectangle(generics.metal(1), bp.sdwidth, bp.separation))

    -- place block
    for i = 1, _P.fingers do
        local shift = 4 * (i - 1) - (_P.fingers - 1)
        if i % 2 == 0 then
            gate:merge_into(block:copy():flipx():translate(-shift * xpitch, 0))
        else
            gate:merge_into(block:copy():translate(-shift * xpitch, 0))
        end
    end

    gate:inherit_alignment_box(harness)

    -- inverter A
    pcell.push_overwrites("logic/base", { leftdummies = 0 })
    local invb = pcell.create_layout("logic/not_gate", { shiftinput = routingshift, connectoutput = false })
    invb:move_anchor("right", gate:get_anchor("left"))
    gate:merge_into_update_alignmentbox(invb)

    -- inverter B
    local inva = pcell.create_layout("logic/not_gate", { shiftinput = -routingshift })
    inva:move_anchor("right", invb:get_anchor("left"))
    gate:merge_into_update_alignmentbox(inva)
    pcell.pop_overwrites("logic/base")

    gate:merge_into(geometry.path(generics.metal(2), geometry.path_points_xy(
        inva:get_anchor("I"), 
        { xpitch, -bp.separation / 2 + routingshift - bp.sdwidth / 2, point.create(5 * xpitch / 2, -routingshift) }
        ), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(2), geometry.path_points_xy(
        point.combine_12(inva:get_anchor("I"), invb:get_anchor("I")), 
        { point.create(xpitch / 2, routingshift) }
        ), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(1), geometry.path_points_xy(
        inva:get_anchor("O"):translate(0, -routingshift), { 5 * xpitch / 2, point.create(-3 * xpitch / 2, routingshift), -2 * routingshift }), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(1), geometry.path_points_xy(
        invb:get_anchor("OTR"), { point.create(-xpitch / 2, routingshift) }), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(1), geometry.path_points_xy(
        invb:get_anchor("OBR"), { point.create(-xpitch / 2, routingshift) }), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(2), geometry.path_points_xy(
        inva:get_anchor("I"), { point.create(-5 * xpitch / 2, -routingshift) }), bp.sdwidth))
    gate:merge_into(geometry.path(generics.metal(2), {
        point.create(-3 * xpitch / 2, -routingshift),
        point.create( 3 * xpitch / 2, -routingshift),
        }, bp.sdwidth))

    -- M1 -> M2 vias
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(inva:get_anchor("I")))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(invb:get_anchor("I")))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(point.create(xpitch / 2, routingshift)))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(point.create(-3 * xpitch / 2, -routingshift)))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(point.create( 3 * xpitch / 2, -routingshift)))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(point.create(5 * xpitch / 2, -routingshift)))
    gate:merge_into(geometry.rectangle(generics.via(1, 2), bp.glength, bp.sdwidth):translate(point.create(-5 * xpitch / 2, -routingshift)))

    gate:add_port("A", generics.metal(1), inva:get_anchor("I"))
    gate:add_port("B", generics.metal(1), invb:get_anchor("I"))
    gate:add_port("Z", generics.metal(1), point.create(0, 0))
    gate:add_port("VDD", generics.metal(1), point.create(0, bp.separation / 2 + bp.pwidth + bp.powerspace + bp.powerwidth / 2))
    gate:add_port("VSS", generics.metal(1), point.create(0, -bp.separation / 2 - bp.nwidth - bp.powerspace - bp.powerwidth / 2))
end
