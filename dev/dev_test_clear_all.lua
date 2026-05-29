-- 清空所有缓存后逐一测试
local dir = GetScriptDirectory()
local modules = { "/../src/const/enum", "/../src/util/Tools", "/../src/base/Utility", "/../src/base/CourierSystem",
    "/../src/base/ItemUsageSystem", "/../src/base/ChatSystem", "/../src/base/AbilityAbstraction",
    "/../src/base/RoleUtility",
    "/../src/base/ItemPurchaseSystem", "/../src/base/PushUtility", "/../src/util/BinDecHex" }
for _, name in ipairs(modules) do
    local fullPath = dir .. name
    package.loaded[fullPath] = nil -- 清除缓存
    local ok, err = pcall(require, fullPath)
    if ok then
        print("OK: " .. name)
    else
        print("FAIL: " .. name .. " -> " .. tostring(err))
    end
end
