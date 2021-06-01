local M = transformationmatrix.identity()
M:translate(100, 100)
--M:flipy()
M:scale(2)
M:flipx()
--M:rotate_90_left()

local pt = point.create(5, 5)

M:apply_transformation(pt)
M:apply_inverse_transformation(pt)

print(pt)

print(M:orientation_string())