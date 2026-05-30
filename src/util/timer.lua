----------------------------------------------------------------------------
--	计时器工具模块 — 帧定时器、节流、协程等通用工具
--	来源：从 AbilityAbstraction.lua 重构提取
----------------------------------------------------------------------------
local Timer = {}
local Func = require(GetScriptDirectory() .. "/util/functional")
local NewTable = Func.NewTable

-- ========== 帧计数器 ==========

local frameNumber = 0
local dotaTimer

local function FloatEqual(a, b)
    return math.abs(a - b) < 0.000001
end

function Timer.GetFrameNumber()
    return frameNumber
end

function Timer.EveryManyFrames(count, times)
    times = times or 1
    return frameNumber % count < times
end

-- ========== 时间节流 ==========

local defaultReturn = NewTable()
local everySecondsCallRegistry = NewTable()

-- 创建一个节流函数：每隔 second 秒才执行一次 oldFunction
-- 中间调用返回空表（defaultReturn），可用 CalledOnThisFrame 判断是否命中
function Timer.EveryManySeconds(second, oldFunction)
    local functionName = tostring(oldFunction)
    everySecondsCallRegistry[functionName .. "lastCallTime"] = math.random() * second
    return function(...)
        if everySecondsCallRegistry[functionName .. "lastCallTime"] <= DotaTime() - second then
            everySecondsCallRegistry[functionName .. "lastCallTime"] = DotaTime()
            return oldFunction(...)
        else
            return defaultReturn
        end
    end
end

-- ========== 帧节流（每帧只执行一次）=========

local singleForTeamRegistry = NewTable()

-- 每帧每个队伍只执行一次 oldFunction
function Timer.SingleForTeam(oldFunction)
    local functionName = tostring(oldFunction) .. GetTeam()
    return function(...)
        if singleForTeamRegistry[functionName] ~= frameNumber then
            singleForTeamRegistry[functionName] = frameNumber
            return oldFunction(...)
        else
            return defaultReturn
        end
    end
end

local singleForAllBotsRegistry = NewTable()

-- 每帧所有 bot 只执行一次 oldFunction
function Timer.SingleForAllBots(oldFunction)
    local functionName = tostring(oldFunction)
    return function(...)
        if singleForAllBotsRegistry[functionName] ~= frameNumber then
            singleForAllBotsRegistry[functionName] = frameNumber
            return oldFunction(...)
        else
            return defaultReturn
        end
    end
end

-- 判断某次函数调用结果是否为节流命中
function Timer.CalledOnThisFrame(functionInvocationResult)
    return functionInvocationResult ~= defaultReturn
end

-- ========== 协程系统 ==========

local slowFunctionRegistries = NewTable()
local coroutineRegistry = NewTable()
local coroutineExempt = NewTable()

-- 注册慢函数（每 N 帧执行一次）
function Timer.RegisterSlowFunction(oldFunction, calledWhenHowManyFrames, frameOffset)
    return function(...)
        if frameNumber % calledWhenHowManyFrames == frameOffset then
            return oldFunction(...)
        else
            return Func.UnpackIfTable(defaultReturn)
        end
    end
end

-- 收集协程的所有 yield 返回值
function Timer.ResumeUntilReturn(func)
    local g = NewTable()
    local thread = coroutine.create(func)
    while true do
        local values = { coroutine.resume(thread) }
        if values[1] then
            table.remove(values, 1)
            table.insert(g, values)
        else
            error(values[2])
            break
        end
    end
    return g
end

-- 启动一个协程
function Timer.StartCoroutine(func)
    local newCoroutine = coroutine.create(func)
    table.insert(coroutineRegistry, newCoroutine)
    table.insert(coroutineExempt, { newCoroutine, frameNumber })
    return newCoroutine
end

-- 等待指定秒数（需配合 TickFromDota 驱动）
function Timer.WaitForSeconds(seconds)
    local function WaitFor(firstFrameTime)
        local t = seconds - firstFrameTime
        while t > 0 do
            t = t - coroutine.yield()
        end
    end
    return Timer.StartCoroutine(WaitFor)
end

-- 停止一个协程
function Timer.StopCoroutine(thread)
    Func.Remove_Modify(coroutineExempt, function(t)
        return t[1] == thread
    end)
    Func.Remove_Modify(coroutineRegistry, thread)
end

-- ========== 主驱动（每帧调用）=========

-- 主驱动函数：驱动帧计数器、慢函数注册表、协程系统
--
-- 注意：Dota 2 Bot API 中每个脚本文件运行在独立的 Lua 状态中，
--       因此 Timer 模块并非全局单实例。
--       - team_desires.lua 的 Lua 状态：在 TeamThink() 中每帧调用
--       - 每个 hero 脚本的 Lua 状态：在 CourierUsageThink() 中每帧调用
--       （由 ability_item_usage_generic.CourierUsageThink() 转发）
--
-- 功能：
--   1. 检测 DotaTime() 是否变化，若是则推进帧计数器
--   2. 执行已注册的慢函数（每 N 帧执行一次）
--   3. 恢复所有挂起的协程，传入两帧之间的时间差（delta time）
--   4. 清理已结束的协程
function Timer.TickFromDota()
    local time = DotaTime()

    local function ResumeCoroutine(thread)
        local coroutineResult = { coroutine.resume(thread[1], time - dotaTimer) }
        if not coroutineResult[1] then
            error(coroutineResult[2])
        end
    end

    if dotaTimer == nil then
        dotaTimer = time
        return
    end

    if not FloatEqual(time, dotaTimer) then
        frameNumber = frameNumber + 1
        Func.ForEach(slowFunctionRegistries, function(t)
            t(time - dotaTimer)
        end)

        local threadIndex = 1
        while threadIndex <= #coroutineRegistry do
            local t = coroutineRegistry[threadIndex]
            local exemptIndex
            local exempt
            Func.ForEach(coroutineExempt, function(exemptPair, index)
                if exemptPair[1] == t then
                    if exemptPair[2] == frameNumber then
                        exempt = true
                    end
                    exemptIndex = index
                end
            end)
            if exemptIndex then
                table.remove(coroutineExempt, exemptIndex)
            end
            if not exempt then
                if coroutine.status(t) == "suspended" then
                    ResumeCoroutine(t)
                    threadIndex = threadIndex + 1
                elseif coroutine.status(t) == "dead" then
                    table.remove(coroutineRegistry, threadIndex)
                else
                    threadIndex = threadIndex + 1
                end
            end
        end
        dotaTimer = time
    end
end

return Timer
