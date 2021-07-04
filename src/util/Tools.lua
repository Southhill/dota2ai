local Tools = {}

Tools.GenEnumArray = function(t)
    local result = {}

    for _, val in pairs do
        result[val] = true
    end

    return result
end

return Tools
