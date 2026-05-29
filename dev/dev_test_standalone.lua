-- 独立测试：不依赖任何其他脚本，直接测试 require
print("=== STANDALONE TEST ===")
local dir = GetScriptDirectory()
print("ScriptDir: " .. tostring(dir))

local testFiles = {
    "/../src/base/Utility",
    "/../src/base/CourierSystem",
    "/../src/base/ItemUsageSystem",
    "/../src/base/ChatSystem",
    "/../src/base/AbilityAbstraction",
    "/../src/base/ItemPurchaseSystem",
    "/../src/base/PushUtility",
    "/../src/util/BinDecHex",
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
