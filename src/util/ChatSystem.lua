local BotsInit = require("game/botsinit")
local M = BotsInit.CreateGeneric()

local version = "0.0.1"
local updateDate = "May 17, 2021"

local announceFlag = false

function M.SendVersionAnnouncement()
    if announceFlag == false then
        announceFlag = true

        for id = 1, 36, 1 do
            if (IsPlayerBot(id) == true and GetTeamForPlayer(id) == GetTeam()) then
                local npcBot = GetBot()
                if (npcBot:GetPlayerID() == id) then
                    npcBot:ActionImmediate_Chat("don't worry, be happy!", true)
                    npcBot:ActionImmediate_Chat("Welcome to Enjoy Play AI. The current version is " .. version ..
                                                    ", updated on " .. updateDate, true)
                    npcBot:ActionImmediate_Chat("Please use hard or unfair mode and do not play as Monkey king.", true)
                end

                return
            end
        end
    end
end

return M
