function check_number(val, ref)
    if type(val) ~= "number" then
        return nil, string.format("value is not a number: %s", val)
    end
    if val ~= ref then
        return nil, string.format("numbers do not match: %d vs %d", val, ref)
    end
    return true
end

function check_point(pt, ref)
    if pt ~= ref then
        local px, py = pt:unwrap()
        local rx, ry = ref:unwrap()
        return nil, string.format("point does not match: (%d, %d) vs. (%d, %d)", px, py, rx, ry)
    end
    return true
end

function check_points(pts, ref, ignoreorder)
    if #pts ~= #ref then
        return nil, string.format("number of points does not match: %d vs %d", #pts, #ref)
    end
    for i = 1, #pts do
        if pts[i] ~= ref[i] then
            local px, py = pts[i]:unwrap()
            local rx, ry = ref[i]:unwrap()
            return nil, string.format("point does not match: (%d, %d) vs. (%d, %d)", px, py, rx, ry)
        end
    end
    return true
end

local reporttab
function report(what, result, msg)
    table.insert(reporttab, { what = what, result = result, msg = msg })
end

function run_test(module, test)
    -- reset reporttab
    reporttab = {}
    print(string.format("  * %s: ", test))
    dofile(string.format("%s/testsuite/%s/%s.lua", _get_opc_home(), module, test))
    for _, r in ipairs(reporttab) do
        io.write(string.format("    x %s: ", r.what))
        if r.result then
            print("success")
        else
            print(string.format("failure: %s", r.msg))
        end
    end
    --[[
    if status then
        print("success")
    else
        print(string.format("failure: %s", msg))
    end
    --]]
end
