----------------------------------------------------------------------------
--	聊天系统模块
----------------------------------------------------------------------------
local M = {}

local version = "0.0.1" -- 当前版本
local updateDate = "May 17, 2021" -- 最后更新

local announceFlag = false -- 防止重复发送

-- 发送版本公告（游戏开始时执行一次）
function M.SendVersionAnnouncement()
    if announceFlag == false then
        announceFlag = true

        for id = 1, 36, 1 do
            if (IsPlayerBot(id) == true and GetTeamForPlayer(id) == GetTeam()) then
                local npcBot = GetBot()
                if (npcBot:GetPlayerID() == id) then
                    npcBot:ActionImmediate_Chat("don't worry, be happy!", true)
                    npcBot:ActionImmediate_Chat("欢迎使用 Agent2026。当前版本: " .. version ..
                                                    ", 更新日期: " .. updateDate, true)
                end
                return
            end
        end
    end
end

return M
