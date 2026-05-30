----------------------------------------------------------------------------
--  开发工具：检测 Dota2 当前 Lua 引擎支持的函数
--  用途：排查 module()/getfenv()/setfenv() 等是否可用
----------------------------------------------------------------------------
print("============================================")
print("[LUA_TEST] Starting Lua environment check...")
print("============================================")

-- 测试 1: Lua 版本
local luaversion = _VERSION or "unknown"
print("[LUA_TEST] Lua Version: " .. luaversion)

-- 测试 2: module()
if module ~= nil then
    print("[LUA_TEST] module() : YES (type: " .. type(module) .. ")")
else
    print("[LUA_TEST] module() : NO (nil)")
end

-- 测试 3: getfenv()
if getfenv ~= nil then
    print("[LUA_TEST] getfenv(): YES (type: " .. type(getfenv) .. ")")
    -- 测试调用
    local ok, result = pcall(getfenv, 1)
    if ok then
        print("[LUA_TEST] getfenv() call: OK")
    else
        print("[LUA_TEST] getfenv() call: FAILED - " .. tostring(result))
    end
else
    print("[LUA_TEST] getfenv(): NO (nil)")
end

-- 测试 4: setfenv()
if setfenv ~= nil then
    print("[LUA_TEST] setfenv(): YES (type: " .. type(setfenv) .. ")")
    local ok, result = pcall(setfenv, 1, {})
    if ok then
        print("[LUA_TEST] setfenv() call: OK")
    else
        print("[LUA_TEST] setfenv() call: FAILED - " .. tostring(result))
    end
else
    print("[LUA_TEST] setfenv(): NO (nil)")
end

-- 测试 5: _ENV (Lua 5.2+)
if _ENV ~= nil then
    print("[LUA_TEST] _ENV     : YES (type: " .. type(_ENV) .. ")")
else
    print("[LUA_TEST] _ENV     : NO (nil)")
end

-- 测试 6: package.seeall
if package ~= nil and package.seeall ~= nil then
    print("[LUA_TEST] package.seeall: YES")
else
    print("[LUA_TEST] package.seeall: NO")
end

-- 测试 7: 关键 API
local apiChecks = {
    "GetBot",
    "GetUnitList",
    "GetScriptDirectory",
    "GetLaneFrontLocation",
    "GetUnitToLocationDistance",
    "ActionImmediate_MoveToLocation",
    "IsFullyCastable",
    "GetAbilityInSlot",
    "print",
    "require",
    "dofile",
    "pcall",
    "setmetatable",
    "getmetatable",
}
for _, funcName in ipairs(apiChecks) do
    if _G[funcName] ~= nil then
        print("[LUA_TEST] " .. funcName .. ": YES")
    else
        print("[LUA_TEST] " .. funcName .. ": NO  <--- 缺失!")
    end
end

-- 测试 8: 尝试模拟 module() 的行为
print("")
print("[LUA_TEST] === Testing module() simulation ===")
-- 测试用 getfenv 是否能获取环境
local testResult, testErr = pcall(function()
    local env = getfenv(2)
    return env ~= nil
end)
if testResult then
    print("[LUA_TEST] getfenv(2) works: YES")
else
    print("[LUA_TEST] getfenv(2) works: NO - " .. tostring(testErr))
end

print("")
print("============================================")
print("[LUA_TEST] Check complete!")
print("============================================")
