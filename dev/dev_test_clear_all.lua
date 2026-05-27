-- 清空所有缓存后逐一测试
local dir = GetScriptDirectory()
local modules = {"/const/enum", "/util/Tools", "/util/Utility", "/util/CourierUtility", "/util/CourierSystem",
                 "/util/ItemUsageSystem", "/util/ChatSystem", "/util/AbilityAbstraction", "/util/RoleUtility",
                 "/util/ItemPurchaseSystem", "/util/PushUtility", "/util/BinDecHex"}
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
