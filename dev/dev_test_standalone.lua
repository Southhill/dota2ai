-- 独立测试：不依赖任何其他脚本，直接测试 require
print("=== STANDALONE TEST ===")
local dir = GetScriptDirectory()
print("ScriptDir: " .. tostring(dir))

local testFiles = {
    "/util/Utility",
    "/util/CourierSystem",
    "/util/ItemUsageSystem",
    "/util/ChatSystem",
    "/util/AbilityAbstraction",
    "/util/ItemPurchaseSystem",
    "/util/PushUtility",
    "/util/BinDecHex",
}
for _, f in ipairs(testFiles) do
    local ok, err = pcall(require, dir .. f)
    if ok then
        print("OK: " .. f)
    else
        print("FAIL: " .. f .. " -> " .. tostring(err))
    end
end
print("=== TEST COMPLETE ===")
