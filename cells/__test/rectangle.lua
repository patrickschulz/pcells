function parameters()
end

function layout(cell, _P)
    cell:merge_into(geometry.rectangle(generics.metal(1), 50, 50))
    cell:merge_into(geometry.rectangle(generics.metal(1), 50, 50):translate(0, -100))
end
