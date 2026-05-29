-- 清空缓存后重新测试 ItemPurchaseSystem
local dir = GetScriptDirectory()
local moduleName = dir .. "/../src/base/ItemPurchaseSystem"

-- 清除已缓存的错误
package.loaded[moduleName] = nil

print("[TEST] Loading ItemPurchaseSystem (cache cleared)...")
local ok, err = pcall(require, moduleName)
if ok then
    print("[TEST] SUCCESS: ItemPurchaseSystem loaded")
else
    print("[TEST] FAILED: " .. tostring(err))
end
