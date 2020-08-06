return function(args)
    pcell.setup(args)

    local initradius = pcell.process_args("radius",    30.0)
    local turns      = pcell.process_args("turns",      3.0)
    local separation = pcell.process_args("separation", 6.0)
    local width      = pcell.process_args("width",      6.0)
    local extension  = pcell.process_args("extension", 10.0)
    local extsep     = pcell.process_args("extsep",     6.0)
    local metalnum   = pcell.process_args("metalnum",  -1, "integer")

    pcell.check_args()

    local inductor = object.create()

    local tanpi8 = math.tan(math.pi / 8)
    local pitch = separation + width

    local mainmetal = generics.metal(metalnum)
    local auxmetal = generics.metal(metalnum - 1)
    local via = generics.via(metalnum, metalnum - 1)

    -- draw left and right segments
    local sign = (turns % 2 == 0) and 1 or -1
    for i = 1, turns do
        local radius = initradius + (i - 1) * pitch
        local r = radius * tanpi8
        sign = -sign

        local pathpts = pointarray.create()

        pathpts:append(point.create(-r + 0.5 * tanpi8 * width,  sign * radius))
        pathpts:append(point.create(-r,  sign * radius))
        pathpts:append(point.create(-radius,  sign * r))
        pathpts:append(point.create(-radius, -sign * r))
        pathpts:append(point.create(-r, -sign * radius))
        pathpts:append(point.create(-r + 0.5 * tanpi8 * width, -sign * radius))
        
        -- draw underpass
        if i < turns then
            -- create connection to underpass
            pathpts:prepend(point.create(-0.5 * (initradius * tanpi8 + 0.5 * pitch),  sign * radius))
            pathpts:append( point.create(-0.5 * (initradius * tanpi8 + 0.5 * pitch), -sign * radius))
            -- create underpass
            local uppts = pointarray.create()
            uppts:append(point.create(-0.5 * (initradius * tanpi8 + 0.5 * pitch), -sign * radius))
            uppts:append(point.create(-0.5 * pitch - 0.5 * tanpi8 * width, -sign * radius))
            uppts:append(point.create(-0.5 * pitch, -sign * radius))
            uppts:append(point.create( 0.5 * pitch, -sign * (radius + pitch)))
            uppts:append(point.create( 0.5 * pitch + 0.5 * tanpi8 * width, -sign * (radius + pitch)))
            uppts:append(point.create( 0.5 * (initradius * tanpi8 + 0.5 * pitch), -sign * (radius + pitch)))
            inductor:merge_into(layout.path(mainmetal, uppts, width, true))
            inductor:merge_into(layout.path(auxmetal, uppts:xmirror(), width, true))
            -- place vias
            inductor:merge_into(layout.rectangle(via, width, width):translate(
                -0.5 * (initradius * tanpi8 + 0.5 * pitch), 
                -sign * (radius + pitch)
            ))
            inductor:merge_into(layout.rectangle(via, width, width):translate(
                0.5 * (initradius * tanpi8 + 0.5 * pitch), 
                -sign * radius
            ))
        end
        
        -- draw inner connection between left and right
        if i == 1 then
            pathpts:prepend(point.create( 0, sign * radius))
        end

        -- draw connector
        if i == turns then
            -- create connection to underpass
            pathpts:prepend(point.create(-0.5 * (initradius * tanpi8 + 0.5 * pitch), sign * radius))
            if 0.5 * extsep + width > r + 0.5 * width * tanpi8 then
                pathpts:append(point.create(-0.5 * (extsep + width), -r - radius + 0.5 * (extsep + width)))
                pathpts:append(point.create(-0.5 * (extsep + width), -r - radius + 0.5 * (extsep + width) - extension))
            else
                pathpts:append(point.create(-0.5 * (extsep + width), -radius))
                pathpts:append(point.create(-0.5 * (extsep + width), -(radius + extension)))
            end
        end

        inductor:merge_into(layout.path(mainmetal, pathpts, width, true))
        inductor:merge_into(layout.path(mainmetal, pathpts:xmirror(), width, true))
    end

    return inductor
end