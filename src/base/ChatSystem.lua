----------------------------------------------------------------------------
--	聊天系统模块
----------------------------------------------------------------------------
local M = {}

local Project = require(GetScriptDirectory() .. "/const/project")

local announceFlag = false      -- 防止重复发送

local detectedDotaVersion = nil -- 缓存检测到的 Dota2 版本

-- 待检测的 API 函数列表（用于推断版本功能）
local API_CHECK_LIST = { "GetDotaScriptVersion", "GetHeroData", "GetItemData", "GetUnitData", "GetAbilityData",
    "GetModifierData", "GetRuneData", "GetNeutralCampData" }

-- 打印分隔线
local function PrintSection(title)
    print("[Agent2026] ====== " .. title .. " ======")
end

-- 检测当前 Dota2 游戏版本（游戏启动时执行一次并缓存）
local function DetectDotaVersion()
    PrintSection("Dota2 Environment Detection Start")

    -- 方法 1: 检测可用的 API 函数
    PrintSection("Available API Functions")
    for _, apiName in ipairs(API_CHECK_LIST) do
        local ok, _ = pcall(_G[apiName])
        if ok then
            print("[Agent2026] [API] " .. apiName .. " = YES")
        else
            if _G[apiName] ~= nil then
                print("[Agent2026] [API] " .. apiName .. " = exists but errored")
            else
                print("[Agent2026] [API] " .. apiName .. " = NO")
            end
        end
    end

    -- 方法 2: GetDotaScriptVersion() — 获取 Dota2 脚本版本
    local ok, result = pcall(GetDotaScriptVersion)
    if ok and type(result) == "string" and result ~= "" then
        detectedDotaVersion = result
        print("[Agent2026] Dota2 Script Version: " .. result)
    else
        local ok2, mapName = pcall(GetMapName)
        if ok2 and mapName then
            print("[Agent2026] Map: " .. mapName)
        end
        detectedDotaVersion = "unknown"
    end

    -- 方法 3: 输出系统日期作为参考
    PrintSection("System Info")
    local sysDate = GetSystemDate()
    local sysTime = GetSystemTime()
    print("[Agent2026] System date: " .. sysDate .. " " .. sysTime)

    PrintSection("Detection Complete")

    if detectedDotaVersion == nil then
        detectedDotaVersion = "unknown (inferred)"
    end
end

-- 发送版本公告（游戏开始时执行一次）
function M.SendVersionAnnouncement()
    if announceFlag == false then
        announceFlag = true

        -- 首次运行时检测 Dota2 版本
        if detectedDotaVersion == nil then
            DetectDotaVersion()
        end

        local dotaVerStr = detectedDotaVersion or "unknown"
        print("[Agent2026] Agent2026 v" ..
            Project.version .. " | Dota2: " .. dotaVerStr .. " | Date: " .. Project.updateDate)

        -- 只让队内 ID 最小的 bot 发送公告，避免全员刷屏
        local myTeam = GetTeam()
        local lowestBotId = 99
        for id = 0, 23 do
            if IsPlayerBot(id) and GetTeamForPlayer(id) == myTeam and id < lowestBotId then
                lowestBotId = id
            end
        end
        local npcBot = GetBot()
        if npcBot:GetPlayerID() == lowestBotId then
            npcBot:ActionImmediate_Chat("don't worry, be happy!", true)
            npcBot:ActionImmediate_Chat("Agent2026  v" .. Project.version .. ", Dota2: " .. dotaVerStr, true)
        end
    end
end

return M
