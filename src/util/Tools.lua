----------------------------------------------------------------------------
--	Ranked Matchmaking AI
--	工具函数模块 —— 基础辅助工具
----------------------------------------------------------------------------
local Tools = {}

-- 将列表转换为枚举数组（键为值，值为 true）
-- 例如: {"a", "b"} => {a=true, b=true}
Tools.GenEnumArray = function(t)
    local result = {}

    for _, val in pairs(t) do
        result[val] = true
    end

    return result
end

return Tools
