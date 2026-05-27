-- 隔离测试 ItemPurchaseSystem.lua
print("[IPS_TEST] Loading ItemPurchaseSystem in isolation...")
local ok, err = pcall(dofile, GetScriptDirectory() .. "/util/ItemPurchaseSystem")
if ok then
    print("[IPS_TEST] OK - loaded: " .. tostring(ok))
else
    print("[IPS_TEST] FAIL: " .. tostring(err))
end
