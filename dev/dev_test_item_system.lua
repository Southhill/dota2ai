-- 测试 ItemPurchaseSystem 依赖链
local dir = GetScriptDirectory()
local tests = { "/../src/const/enum", "/../src/util/Tools", "/../src/base/RoleUtility", "/../src/base/ItemPurchaseSystem" }
for _, f in ipairs(tests) do
    local ok, err = pcall(require, dir .. f)
    if ok then
        print("OK: " .. f)
    else
        print("FAIL: " .. f .. " -> " .. tostring(err))
    end
end
