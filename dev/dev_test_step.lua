----------------------------------------------------------------------------
-- 逐步定位测试：找出 generic.lua 中具体哪行导致失败
----------------------------------------------------------------------------
ability_item_usage_generic = {}

print("[STEP] Step1: require starts...")

local ok1, err1 = pcall(require, GetScriptDirectory() .. "/util/Utility")
if ok1 then print("[STEP] Step2: Utility OK") else print("[STEP] Step2 FAIL: " .. tostring(err1)) return end

local ok2, err2 = pcall(require, GetScriptDirectory() .. "/util/CourierSystem")
if ok2 then print("[STEP] Step3: Courier OK") else print("[STEP] Step3 FAIL: " .. tostring(err2)) return end

local ok3, err3 = pcall(require, GetScriptDirectory() .. "/util/ItemUsageSystem")
if ok3 then print("[STEP] Step4: ItemUsageSystem OK") else print("[STEP] Step4 FAIL: " .. tostring(err3)) return end

local ok4, err4 = pcall(require, GetScriptDirectory() .. "/util/ChatSystem")
if ok4 then print("[STEP] Step5: ChatSystem OK") else print("[STEP] Step5 FAIL: " .. tostring(err4)) return end

local ok5, err5 = pcall(require, GetScriptDirectory() .. "/util/AbilityAbstraction")
if ok5 then print("[STEP] Step6: AbilityAbstraction OK") else print("[STEP] Step6 FAIL: " .. tostring(err5)) return end

print("[STEP] ALL REQUIRES OK!")

for k, v in pairs(ability_item_usage_generic) do
    _G[k] = v
end
