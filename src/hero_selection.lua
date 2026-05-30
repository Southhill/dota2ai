local role = require(GetScriptDirectory() .. "/base/RoleUtility")
local bnUtil = require(GetScriptDirectory() .. "/base/BotNameUtility")
local config = require(GetScriptDirectory() .. "/const/config")
local Heroes = require(GetScriptDirectory() .. "/const/heroes")
local ChatSystem = require(GetScriptDirectory() .. "/base/ChatSystem")
local g_Agent2026Started = nil -- 防止重复执行开局通告

print("============================================")
print("[Agent2026] 已加载")
print("[Agent2026] 当前脚本路径: " .. GetScriptDirectory())
print("============================================")
print("============================================")

----------------------------------------------------------------------------------------------------
local debugMode = config.debugMode
-----------------------------------------------------SELECT HERO FOR BOT WITH CHAT FEATURE------------------------------
-- function to get hero name that match the expression
function GetHumanChatHero(name)
    if name == nil then
        return ""
    end
    for _, hero in pairs(Heroes.allBotHeroes) do
        if string.find(hero, name) then
            return hero
        end
    end
    return ""
end

-- function to decide which team should get the hero
function SelectHeroChatCallback(PlayerID, ChatText, bTeamOnly)
    local text = string.lower(ChatText)
    local hero = GetHumanChatHero(text)

    if hero ~= "" then
        if bTeamOnly then
            for _, id in pairs(GetTeamPlayers(GetTeam())) do
                if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
                    SelectHeroAndAnnounce(id, hero)
                    break
                end
            end
        elseif bTeamOnly == false and GetTeamForPlayer(PlayerID) ~= GetTeam() then
            for _, id in pairs(GetTeamPlayers(GetTeam())) do
                if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
                    SelectHeroAndAnnounce(id, hero)
                    break
                end
            end
        end
    else
        print("Hero name not found! Please refer to hero_selection.lua of this script for list of heroes's name")
    end
end

-- Explicit helper: select hero then announce to team chat (position + lane)
function SelectHeroAndAnnounce(playerID, heroName)
    SelectHero(playerID, heroName)

    local unit = GetTeamMember(playerID)
    if unit ~= nil then
        local display = heroName or ""
        display = display:gsub("^npc_dota_hero_", "")
        display = display:gsub("_", " ")
        display = display:gsub("(%a)([%w']*)", function(a, b) return string.upper(a) .. b end)

        local pos = -1
        if heroName ~= nil then
            pos = GetHeroPostion(heroName) or -1
        end
        local posText = (pos >= 1 and pos <= 5) and tostring(pos) or "未知"
        local laneName = "未知"
        if pos >= 1 and pos <= 5 then
            local laneConst = GetLanesTable()[pos]
            if laneConst == LANE_TOP then
                laneName = "上路"
            elseif laneConst == LANE_MID then
                laneName = "中路"
            elseif laneConst == LANE_BOT then
                laneName = "下路"
            end
        end

        Say(unit, "[Agent2026] 已选择: " .. display .. " — 位次: " .. posText .. " (" .. laneName .. ")", true)
    end
end

function Think()
    -- 开局在公屏打印确认信息 + 版本公告（仅执行一次）
    if g_Agent2026Started == nil and GetGameState() >= GAME_STATE_PRE_GAME then
        g_Agent2026Started = true
        ChatSystem.SendVersionAnnouncement()
        local allBots = GetTeamPlayers(GetTeam())
        if allBots and #allBots > 0 then
            local firstBot = GetTeamMember(allBots[1])
            if firstBot then
                Say(firstBot, "[Agent2026] 已启用", true)
            end
        end
    end

    if GetGameMode() == GAMEMODE_AP then
        if GetGameState() == GAME_STATE_HERO_SELECTION then
            InstallChatCallback(function(attr)
                SelectHeroChatCallback(attr.player_id, attr.string, attr.team_only)
            end)
        end
        AllPickLogic()
    elseif GetGameMode() == GAMEMODE_CM then
        CaptainModeLogic()
        AddToList()
    elseif GetGameMode() == GAMEMODE_AR then
        AllRandomLogic()
    elseif GetGameMode() == GAMEMODE_MO then
        MidOnlyLogic()
    elseif GetGameMode() == GAMEMODE_1V1MID then
        OneVsOneLogic()
    elseif GetGameMode() == GAMEMODE_SD then
        if GetGameState() == GAME_STATE_HERO_SELECTION then
            InstallChatCallback(function(attr)
                SelectHeroChatCallback(attr.player_id, attr.string, attr.team_only)
            end)
        end
        SingleDraftLogic()
    elseif GetGameMode() == GAMEMODE_TM then
        if GetGameState() == GAME_STATE_HERO_SELECTION then
            InstallChatCallback(function(attr)
                SelectHeroChatCallback(attr.player_id, attr.string, attr.team_only)
            end)
        end
        NewTurboModeLogic()
    else
        if GetGameState() == GAME_STATE_HERO_SELECTION then
            InstallChatCallback(function(attr)
                SelectHeroChatCallback(attr.player_id, attr.string, attr.team_only)
            end)
        end
        AllPickLogic()
    end
end

local lastpick = 10
function NewTurboModeLogic()
    local hero
    if GetHeroPickState() == 58 and GameTime() >= 45 and GameTime() >= lastpick + 1.5 then
        for i, id in pairs(GetTeamPlayers(GetTeam())) do
            if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
                if debugMode then
                    hero = GetRandomHero2()
                else
                    hero = PickRightHero(i - 1)
                end
                SelectHeroAndAnnounce(id, hero)
                lastpick = GameTime()
                return
            end
        end
    end
end

local humanInRad1Slot = nil

function TurboModeLogic()
    local hero
    if #GetTeamPlayers(GetTeam()) < 5 or #GetTeamPlayers(GetOpposingTeam()) < 5 then
        return
    end

    if humanInRad1Slot == nil then
        humanInRad1Slot = IsHumanPlayerInRadiant1Slot()
        return
    end

    -- print(tostring(GetGameMode()).."=>"..tostring(GetGameState())..":"..tostring(DotaTime( ))..":"..tostring(GetHeroPickState()))
    if GetHeroPickState() == 55 and
        ((humanInRad1Slot == true and IsHumanDonePickingFirstSlot() and DotaTime() > -10 and DotaTime() < -5) or
            (humanInRad1Slot == false and GameTime() > 10 and DotaTime() > -10 and DotaTime() < -5)) then
        for i, id in pairs(GetTeamPlayers(GetTeam())) do
            if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
                if debugMode then
                    hero = GetRandomHero2()
                else
                    hero = PickRightHero(i - 1)
                end
                SelectHeroAndAnnounce(id, hero)
                return
            end
        end
    end
end

function SingleDraftLogic()
    local hero
    -- print(tostring(GetGameMode()).."=>"..tostring(GetGameState())..":"..tostring(DotaTime( ))..":"..tostring(GetHeroPickState()))
    if GetHeroPickState() == 2 and GameTime() >= 45 and GameTime() >= lastpick + 1.5 then
        for i, id in pairs(GetTeamPlayers(GetTeam())) do
            if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
                if debugMode then
                    hero = GetRandomHero2()
                else
                    hero = PickRightHero(i - 1)
                end
                SelectHeroAndAnnounce(id, hero)
                lastpick = GameTime()
                return
            end
        end
    end
end

local oboselect = false
------------------------------------------1 VS 1 GAME MODE-------------------------------------------
function OneVsOneLogic()
    local hero
    if IsHumanPlayerExist() then
        oboselect = true
    end

    for _, i in pairs(GetTeamPlayers(GetTeam())) do
        if not oboselect and IsPlayerBot(i) and IsPlayerInHeroSelectionControl(i) and GetSelectedHeroName(i) == "" then
            if IsHumanPresentInGame() then
                hero = GetSelectedHumanHero(GetOpposingTeam())
            else
                hero = GetRandomHero2()
            end
            if hero ~= nil then
                SelectHeroAndAnnounce(i, hero)
                oboselect = true
            end
            return
        elseif oboselect and IsPlayerBot(i) and IsPlayerInHeroSelectionControl(i) and GetSelectedHeroName(i) == "" then
            SelectHeroAndAnnounce(i, "npc_dota_hero_techies")
            return
        end
    end
end

-------------------------------------------------------------------------------------------------------

local pickTime = GameTime()
local randomTime = 0
function AllPickLogic()
    local team = GetTeam()
    if (GameTime() < 45 and AreHumanPlayersReady(team) == false or GameTime() < 25) then
        return
    end

    local picks = GetPicks()
    local selectedHeroes = {}

    for _, hero in pairs(picks) do
        selectedHeroes[hero] = true
    end

    if (not debugMode) then
        for i, id in pairs(GetTeamPlayers(team)) do
            if (IsPlayerInHeroSelectionControl(id) and IsPlayerBot(id) and
                    (GetSelectedHeroName(id) == "" or GetSelectedHeroName(id) == nil)) then
                if (randomTime == 0) then
                    randomTime = RandomInt(10, 12)
                end
                while (GameTime() - pickTime) < randomTime do
                    return
                end
                pickTime = GameTime()
                randomTime = 0

                local temphero = GetPositionedHero(team, selectedHeroes)
                SelectHeroAndAnnounce(id, temphero)
            end
        end
    else
        for i, id in pairs(GetTeamPlayers(team)) do
            if (IsPlayerInHeroSelectionControl(id) and IsPlayerBot(id) and
                    (GetSelectedHeroName(id) == "" or GetSelectedHeroName(id) == nil)) then
                SelectHeroAndAnnounce(id, GetHeroInTest(selectedHeroes))
            end
        end
    end
end

------------------------------------------ALL RANDOM GAME MODE-------------------------------------------
-- Picking logic for All Random Game Mode
function AllRandomLogic()
    for i, id in pairs(GetTeamPlayers(GetTeam())) do
        if GetHeroPickState() == HEROPICK_STATE_AR_SELECT and IsPlayerInHeroSelectionControl(id) and
            GetSelectedHeroName(id) == "" then
            local hero = GetRandomHero2()
            SelectHeroAndAnnounce(id, hero)
            return
        end
    end
end

-------------------------------------------------------------------------------------------------------------

------------------------------------------MID ONLY SAME HERO GAME MODE-----------------------------------------------
-- Picking logic for Mid Only Same Hero Game Mode
local RandomedHero = nil
function MidOnlyLogic()
    if GetHeroPickState() ~= HEROPICK_STATE_AP_SELECT then
        return
    end

    local selectedHero = nil
    if IsHumanPresentInGame() then
        if not IsHumansDonePicking() then
            return
        end

        if IsHumanPlayerExist() then
            selectedHero = GetSelectedHumanHero(GetTeam())
        else
            selectedHero = GetSelectedHumanHero(GetOpposingTeam())
        end
    elseif GetTeam() == TEAM_DIRE then
        if not IsOpposingTeamDonePicking() then
            return
        end
        selectedHero = GetOpposingTeamSelectedHero()
    else
        selectedHero = SetRandomHero()
    end

    if selectedHero == nil or selectedHero == "" then
        return
    end

    for _, id in pairs(GetTeamPlayers(GetTeam())) do
        if IsPlayerBot(id) and IsPlayerInHeroSelectionControl(id) and GetSelectedHeroName(id) == "" then
            SelectHeroAndAnnounce(id, selectedHero)
            return
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Check if human done picking
function IsHumansDonePicking()
    -- check radiant
    for _, i in pairs(GetTeamPlayers(GetTeam())) do
        if GetSelectedHeroName(i) == "" and not IsPlayerBot(i) then
            return false
        end
    end
    -- check dire
    for _, i in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if GetSelectedHeroName(i) == "" and not IsPlayerBot(i) then
            return false
        end
    end
    -- else humans have picked
    return true
end

-- Get Human Selected Hero
function GetSelectedHumanHero(team)
    for i, id in pairs(GetTeamPlayers(team)) do
        if not IsPlayerBot(id) and GetSelectedHeroName(id) ~= "" then
            return GetSelectedHeroName(id)
        end
    end
end

-- Check if human present in the game
function IsHumanPresentInGame()
    for i, id in pairs(GetTeamPlayers(GetTeam())) do
        if not IsPlayerBot(id) then
            return true
        end
    end
    for i, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if not IsPlayerBot(id) then
            return true
        end
    end
    return false
end

function IsHumanDonePickingFirstSlot()
    if GetTeam() == TEAM_RADIANT then
        for _, id in pairs(GetTeamPlayers(GetTeam())) do
            if IsPlayerBot(id) == false and GetSelectedHeroName(id) ~= "" then
                return true
            end
        end
    else
        for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
            if IsPlayerBot(id) == false and GetSelectedHeroName(id) ~= "" then
                return true
            end
        end
    end
end

function IsHumanPlayerInRadiant1Slot()
    if GetTeam() == TEAM_RADIANT then
        for i, id in pairs(GetTeamPlayers(GetTeam())) do
            if i == 1 and IsPlayerBot(id) == false then
                return true
            end
        end
    else
        for i, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
            if i == 1 and IsPlayerBot(id) == false then
                return true
            end
        end
    end
    return false
end

-- Pick hero based on role
function PickRightHero(slot)
    local initHero = GetRandomHero2()
    local Team = GetTeam()
    if slot == 0 then
        while not role.CanBeMidlaner(initHero) do
            initHero = GetRandomHero2()
        end
    elseif slot == 1 then
        while (Team == TEAM_RADIANT and not role.CanBeOfflaner(initHero)) or
            (Team == TEAM_DIRE and not role.CanBeSafeLaneCarry(initHero)) do
            initHero = GetRandomHero2()
        end
    elseif slot == 2 then
        while not role.CanBeSupport(initHero) do
            initHero = GetRandomHero2()
        end
    elseif slot == 3 then
        while not role.CanBeSupport(initHero) do
            initHero = GetRandomHero2()
        end
    elseif slot == 4 then
        while (Team == TEAM_RADIANT and not role.CanBeSafeLaneCarry(initHero)) or
            (Team == TEAM_DIRE and not role.CanBeOfflaner(initHero)) do
            initHero = GetRandomHero2()
        end
    end
    return initHero
end

function GetPicks()
    local selectedHeroes = {}
    for i = 0, 20, 1 do
        if (IsTeamPlayer(i) == true) then
            local hName = GetSelectedHeroName(i)
            if (hName ~= "") then
                table.insert(selectedHeroes, hName)
            end
        end
    end
    return selectedHeroes
end

-- Return hero's postion
function GetHeroPostion(heroName)
    if (heroName ~= "") then
        for p = 1, 5, 1 do
            if (ListContains(Heroes.positionPools[p], heroName) or
                    ListContains(Heroes.unimplementedPools[p], heroName)) then
                return p
            end
        end
    end
    return -1
end

-- Returns a Hero that fills a position that current team does not have filled.
function GetPositionedHero(team, selectedHeroes)
    -- Fill positions in random order
    local positionCounts = GetPositionCounts(team)
    local position
    repeat
        position = RandomInt(1, 5)
    until (positionCounts[position] == 0)

    return GetRandomHero(Heroes.positionPools[position], selectedHeroes)

    -- The object is to fill positions in this order: 3, 4, 2, 5, 1
    -- local order = {3, 4, 2, 5, 1};
    -- local positionCounts = GetPositionCounts( team );
    -- for i,position in ipairs( order ) do
    -- 	if( positionCounts[position] == 0 ) then
    --         return GetRandomHero( Heroes.positionPools[position], selectedHeroes );
    --     end
    -- end
end

-- For the given team, returns a table that gives the counts of heros in each position.
function GetPositionCounts(team)
    local counts = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0
    }
    local playerIds = GetTeamPlayers(team)

    for i, id in ipairs(playerIds) do
        local heroName = GetSelectedHeroName(id)
        if (heroName ~= "") then
            for position = 1, 5, 1 do
                if (ListContains(Heroes.positionPools[position], heroName) or
                        ListContains(Heroes.unimplementedPools[position], heroName)) then
                    counts[position] = counts[position] + 1
                end
            end
        end
    end

    return counts
end

-- A utilitiy function that returns true if the passed list contains the passed value.
function ListContains(list, value)
    if list == nil then
        return false
    end
    for i, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

-- Returns a hero from the hero_pool_test pool
function GetHeroInTest(selectedHeroes)
    -- Step through the "hero_pool_test" pool allocating them in order. This function will error if the pool is too small, but it's not for general use.
    local hero
    repeat
        hero = Heroes.testPool[1]
        table.remove(Heroes.testPool, 1)
    until (selectedHeroes[hero] ~= true)
    return hero
end

-- Returns a random hero from the supplied heroPool that is not in the selectedHeroes list.
-- Note: this function will enter an infinite loop if all heros in the pool have been selected.
function GetRandomHero(heroPool, selectedHeroes)
    local hero
    repeat
        hero = heroPool[RandomInt(1, #heroPool)]
    until (selectedHeroes[hero] ~= true)
    return hero
end

-- first, check the list of required heroes and pick from those
-- then try the whole bot pool
function GetRandomHero2()
    local hero
    local picks = GetPicks()
    local selectedHeroes = {}

    for slot, hero in pairs(picks) do
        selectedHeroes[hero] = true
    end

    if testMode then
        hero = requiredHeroes[RandomInt(1, #requiredHeroes)]
    else
        hero = nil
    end

    if (hero == nil) then
        hero = Heroes.allBotHeroes[RandomInt(1, #Heroes.allBotHeroes)]
    end

    while (selectedHeroes[hero] == true) do
        hero = Heroes.allBotHeroes[RandomInt(1, #Heroes.allBotHeroes)]
    end

    return hero
end

-- Returns true if, for the specified team, all the Human players have picked a hero.
function AreHumanPlayersReady(team)
    local number, playernumber = 0, 0
    local IDs = GetTeamPlayers(team)
    for i, id in pairs(IDs) do
        if (IsPlayerBot(id) == false) then
            local hName = GetSelectedHeroName(id)
            playernumber = playernumber + 1
            if (hName ~= "") then
                number = number + 1
            end
        end
    end

    if (number >= playernumber) then
        return true
    else
        return false
    end
end

function GetSafeLane()
    if GetTeam() == TEAM_RADIANT then
        return LANE_BOT
    else
        return LANE_TOP
    end
end

function GetOffLane()
    if GetTeam() == TEAM_RADIANT then
        return LANE_TOP
    else
        return LANE_BOT
    end
end

-- index:position,value:lane.
function GetLanesTable()
    local safeLane = GetSafeLane()
    local offLane = GetOffLane()

    local laneTable = {
        [1] = safeLane,
        [2] = LANE_MID,
        [3] = offLane,
        [4] = offLane,
        [5] = safeLane
    }

    return laneTable
end

-- index:id,value:lane Get normal lane assaignment.
function GetAssaignedLanes()
    local laneTable = GetLanesTable()
    local lanes = { 1, 1, 2, 3, 3 }

    for id = 1, 5 do
        local hero = GetTeamMember(id)
        if (hero == nil) then
            break
        end
        local heroName = hero:GetUnitName()
        local postion = GetHeroPostion(heroName)
        lanes[id] = laneTable[postion]
    end
    return lanes
end

function TranspositionTable(sourceTable)
    local newTable = {}
    for k, v in pairs(sourceTable) do
        newTable[v] = k
    end
    return newTable
end

-- index:lane,value:position.
function GetPositionAssaignedLanes()
    return TranspositionTable(GetLanesTable())
end

----------------------------------------------------------------------------------------------------
-- BOT EXPERIMENT Author:Arizona Fauzie Link:http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
----------------------------------------------------------------------------------------------------
local chatLanes = {}
---------------------------------------------------------LANE ASSIGMENT WITH CHAT FEATURE-----------------------------------------------
-- Parses a chat command from a teammate and converts it into a lane assignment table.
-- Only teammates from the same team are allowed to set these lane commands.
-- Expected input: 5 words separated by spaces, each one of `top`, `mid`, or `bot`.
-- The parsed lanes are stored in the shared `chatLanes` table for later assignment.
function ProcessLaneChatCommand(PlayerID, ChatText, bTeamOnly)
    if GetTeamForPlayer(PlayerID) == GetTeam() then
        chatLanes = {}
        local count = 1
        for str in string.gmatch(ChatText, "%S+") do
            if str == "top" then
                chatLanes[count] = LANE_TOP
            elseif str == "mid" then
                chatLanes[count] = LANE_MID
            elseif str == "bot" then
                chatLanes[count] = LANE_BOT
            end
            count = count + 1
        end
        if #chatLanes ~= 5 then
            print(
                "Wrong Command! Lane count is less or more than 5. Typo? Please type 5 lane (top, mid, or bot) with space separating each other.")
        end
    else
        print("You're not my team...!")
    end
end

function UpdateLaneAssignments()
    if GetGameMode() == GAMEMODE_AP or GetGameMode() == GAMEMODE_TM or GetGameMode() == GAMEMODE_SD then
        -- print("AP Lane Assignment")
        if GetGameState() == GAME_STATE_STRATEGY_TIME or GetGameState() == GAME_STATE_PRE_GAME then
            InstallChatCallback(function(attr)
                ProcessLaneChatCommand(attr.player_id, attr.string, attr.team_only)
            end)
        end
        if #chatLanes == 5 then
            return chatLanes
        else
            return APLaneAssignment()
        end
    elseif GetGameMode() == GAMEMODE_CM then
        -- print("CM Lane Assignment")
        return CMLaneAssignment()
    elseif GetGameMode() == GAMEMODE_AR then
        return APLaneAssignment()
    elseif GetGameMode() == GAMEMODE_MO then
        return MOLaneAssignment()
    elseif GetGameMode() == GAMEMODE_1V1MID then
        return OneVsOneLaneAssignment()
    end
end

-- function printTable(table)
-- 	if(GetTeam()==TEAM_RADIANT)
-- 	then
-- 		print(tostring(table).."TEAM_RADIANT");
-- 	else
-- 		print(tostring(table).."TEAM_DIRE");
-- 	end

-- 	for k,v in pairs(table) do
-- 		print(k.." "..v)
-- 	end
-- end

function APLaneAssignment()
    local gamestate = GetGameState()
    if (gamestate == GAME_STATE_HERO_SELECTION or gamestate == GAME_STATE_STRATEGY_TIME or gamestate ==
            GAME_STATE_TEAM_SHOWCASE or gamestate == GAME_STATE_WAIT_FOR_MAP_TO_LOAD or gamestate ==
            GAME_STATE_WAIT_FOR_PLAYERS_TO_LOAD) then
        return
    end

    local lanes = GetAssaignedLanes()

    if (DotaTime() < -15) then
        return lanes
    end

    local lanecount = {
        [LANE_NONE] = 5,
        [LANE_MID] = 1,
        [LANE_TOP] = 2,
        [LANE_BOT] = 2
    }

    -- adjust the lane assignement when player occupied the other lane.
    -- TODO: Assign lane at Team level not hero level.
    local playercount = 0
    local ids = GetTeamPlayers(GetTeam())
    for i, v in pairs(ids) do
        if not IsPlayerBot(v) then
            playercount = playercount + 1
        end
    end
    if (playercount > 0) then
        for i = 1, playercount do
            local lane = GetLane(GetTeam(), GetTeamMember(i))
            lanecount[lane] = lanecount[lane] - 1
            lanes[i] = lane
        end

        for i = (playercount + 1), 5 do
            local hero = GetTeamMember(i)
            local heroName = hero:GetUnitName()
            local position = GetHeroPostion(heroName)
            local laneTable = GetLanesTable()
            local bestLane = laneTable[position]
            local positionAssaignedLanes = GetPositionAssaignedLanes()
            local safeLane = GetSafeLane()
            local offLane = GetOffLane()
            -- try to assign the most suitable lane, if can't try other lane.
            if lanecount[bestLane] > 0 then
                lanes[i] = bestLane
                lanecount[bestLane] = lanecount[bestLane] - 1
            elseif lanecount[offLane] > 0 then
                lanes[i] = offLane
                lanecount[offLane] = lanecount[offLane] - 1
            elseif lanecount[safeLane] > 0 then
                lanes[i] = safeLane
                lanecount[safeLane] = lanecount[safeLane] - 1
            elseif lanecount[LANE_MID] > 0 then
                lanes[i] = LANE_MID
                lanecount[LANE_MID] = lanecount[LANE_MID] - 1
            end
        end
    end
    return lanes
end

function GetLane(nTeam, hHero)
    if (hHero == nil) then
        return LANE_NONE
    end

    local vBot = GetLaneFrontLocation(nTeam, LANE_BOT, 0)
    local vTop = GetLaneFrontLocation(nTeam, LANE_TOP, 0)
    local vMid = GetLaneFrontLocation(nTeam, LANE_MID, 0)
    -- print(GetUnitToLocationDistance(hHero, vMid))
    if hHero:DistanceFromFountain() < 2500 then
        return LANE_NONE
    end
    if GetUnitToLocationDistance(hHero, vBot) < 2500 then
        return LANE_BOT
    end
    if GetUnitToLocationDistance(hHero, vTop) < 2500 then
        return LANE_TOP
    end
    if GetUnitToLocationDistance(hHero, vMid) < 2500 then
        return LANE_MID
    end
    return LANE_NONE
end

------------------------------------------CAPTAIN'S MODE GAME MODE-------------------------------------------
local UnImplementedHeroes = {}

local ListPickedHeroes = {}
local AllHeroesSelected = false
local BanCycle = 1
local PickCycle = 1
local NeededTime = 28
local Min = 15
local Max = 20
local CMdebugMode = true
local UnavailableHeroes = { "npc_dota_hero_techies" }
local HeroLanes = {
    [1] = LANE_MID,
    [2] = LANE_TOP,
    [3] = LANE_TOP,
    [4] = LANE_BOT,
    [5] = LANE_BOT
}

local PairsHeroNameNRole = {}
local humanPick = {}

-- Picking logic for Captain's Mode Game Mode
function CaptainModeLogic()
    if (GetGameState() ~= GAME_STATE_HERO_SELECTION) then
        return
    end
    if not CMdebugMode then
        -- end
        NeededTime = RandomInt(Min, Max)
    elseif CMdebugMode then
        NeededTime = 25
    end
    if GetHeroPickState() == HEROPICK_STATE_CM_CAPTAINPICK then
        PickCaptain()
    elseif GetHeroPickState() >= HEROPICK_STATE_CM_BAN1 and GetHeroPickState() <= 18 and GetCMPhaseTimeRemaining() <=
        NeededTime then
        BansHero()
        NeededTime = 0
    elseif GetHeroPickState() >= HEROPICK_STATE_CM_SELECT1 and GetHeroPickState() <= HEROPICK_STATE_CM_SELECT10 and
        GetCMPhaseTimeRemaining() <= NeededTime then
        PicksHero()
        NeededTime = 0
    elseif GetHeroPickState() == HEROPICK_STATE_CM_PICK then
        SelectsHero()
    end
end

-- Pick the captain
function PickCaptain()
    if not IsHumanPlayerExist() or DotaTime() > -1 then
        if GetCMCaptain() == -1 then
            local CaptBot = GetFirstBot()
            if CaptBot ~= nil then
                print("CAPTAIN PID : " .. CaptBot)
                SetCMCaptain(CaptBot)
            end
        end
    end
end

-- Check if human player exist in team
function IsHumanPlayerExist()
    local Players = GetTeamPlayers(GetTeam())
    for _, id in pairs(Players) do
        if not IsPlayerBot(id) then
            return true
        end
    end
    return false
end

-- Get the first bot to be the captain
function GetFirstBot()
    local BotId = nil
    local Players = GetTeamPlayers(GetTeam())
    for _, id in pairs(Players) do
        if IsPlayerBot(id) then
            BotId = id
            return BotId
        end
    end
    return BotId
end

-- Ban hero function
function BansHero()
    if not IsPlayerBot(GetCMCaptain()) or not IsPlayerInHeroSelectionControl(GetCMCaptain()) then
        return
    end
    local BannedHero = RandomHero()
    print(BannedHero .. " is banned")
    CMBanHero(BannedHero)
    BanCycle = BanCycle + 1
end

-- Pick hero function
function PicksHero()
    if not IsPlayerBot(GetCMCaptain()) or not IsPlayerInHeroSelectionControl(GetCMCaptain()) then
        return
    end
    local PickedHero = RandomHero()
    if PickCycle == 1 then
        while not role.CanBeOfflaner(PickedHero) do
            PickedHero = RandomHero()
        end
        PairsHeroNameNRole[PickedHero] = "offlaner"
    elseif PickCycle == 2 then
        while not role.CanBeSupport(PickedHero) do
            PickedHero = RandomHero()
        end
        PairsHeroNameNRole[PickedHero] = "support"
    elseif PickCycle == 3 then
        while not role.CanBeMidlaner(PickedHero) do
            PickedHero = RandomHero()
        end
        PairsHeroNameNRole[PickedHero] = "midlaner"
    elseif PickCycle == 4 then
        while not role.CanBeSupport(PickedHero) do
            PickedHero = RandomHero()
        end
        PairsHeroNameNRole[PickedHero] = "support"
    elseif PickCycle == 5 then
        while not role.CanBeSafeLaneCarry(PickedHero) do
            PickedHero = RandomHero()
        end
        PairsHeroNameNRole[PickedHero] = "carry"
    end
    print(PickedHero .. " is picked")
    CMPickHero(PickedHero)
    PickCycle = PickCycle + 1
end

-- Check if selected hero already picked by human
local function alreadyInTable(hero_name)
    for _, h in pairs(humanPick) do
        if hero_name == h then
            return true
        end
    end
    return false
end

-- Add to list human picked heroes
function AddToList()
    if not IsPlayerBot(GetCMCaptain()) then
        for _, h in pairs(Heroes.allBotHeroes) do
            if IsCMPickedHero(GetTeam(), h) and not alreadyInTable(h) then
                table.insert(humanPick, h)
            end
        end
    end
end

-- Check if the randomed hero doesn't available for captain's mode
function IsUnavailableHero(name)
    for _, uh in pairs(UnavailableHeroes) do
        if name == uh then
            return true
        end
    end
    return false
end

-- Check if a hero hasn't implemented yet
function IsUnImplementedHeroes(name)
    for _, unh in pairs(UnImplementedHeroes) do
        if name == unh then
            return true
        end
    end
    return false
end

-- Random hero which is non picked, non banned, or non human picked heroes if the human is the captain
function RandomHero()
    local hero = Heroes.allBotHeroes[RandomInt(1, #Heroes.allBotHeroes)]
    while (IsUnavailableHero(hero) or IsCMPickedHero(GetTeam(), hero) or IsCMPickedHero(GetOpposingTeam(), hero) or
            IsCMBannedHero(hero)) do
        hero = Heroes.allBotHeroes[RandomInt(1, #Heroes.allBotHeroes)]
    end
    return hero
end

-- Check if the human already pick the hero in captain's mode
function WasHumansDonePicking()
    local Players = GetTeamPlayers(GetTeam())
    for _, id in pairs(Players) do
        if not IsPlayerBot(id) then
            if GetSelectedHeroName(id) == nil or GetSelectedHeroName(id) == "" then
                return false
            end
        end
    end
    return true
end

-- Select the rest of the heroes that the human players don't pick in captain's mode
function SelectsHero()
    if not AllHeroesSelected and (WasHumansDonePicking() or GetCMPhaseTimeRemaining() < 1) then
        local Players = GetTeamPlayers(GetTeam())
        local RestBotPlayers = {}

        GetTeamSelectedHeroes()

        for _, id in pairs(Players) do
            local hero_name = GetSelectedHeroName(id)

            if hero_name ~= nil and hero_name ~= "" then
                UpdateSelectedHeroes(hero_name)
                print(hero_name .. " Removed")
            else
                table.insert(RestBotPlayers, id)
            end
        end

        for i = 1, #RestBotPlayers do
            SelectHeroAndAnnounce(RestBotPlayers[i], ListPickedHeroes[i])
        end

        AllHeroesSelected = true
    end
end

-- Get the team picked heroes
function GetTeamSelectedHeroes()
    for _, sName in pairs(Heroes.allBotHeroes) do
        if IsCMPickedHero(GetTeam(), sName) then
            table.insert(ListPickedHeroes, sName)
        end
    end
    for _, sName in pairs(UnImplementedHeroes) do
        if IsCMPickedHero(GetTeam(), sName) then
            table.insert(ListPickedHeroes, sName)
        end
    end
end

-- Update team picked heroes after human players select their desired hero
function UpdateSelectedHeroes(selected)
    for i = 1, #ListPickedHeroes do
        if ListPickedHeroes[i] == selected then
            table.remove(ListPickedHeroes, i)
        end
    end
end

-------------------------------------------------------------------------------------------------------

---------------------------------------------------------CAPTAIN'S MODE LANE ASSIGNMENT------------------------------------------------
function CMLaneAssignment()
    if IsPlayerBot(GetCMCaptain()) then
        FillLaneAssignmentTable()
    else
        FillLAHumanCaptain()
    end
    return HeroLanes
end

-- Lane Assignment if the captain is not human
function FillLaneAssignmentTable()
    local supportAlreadyAssigned = false
    local TeamMember = GetTeamPlayers(GetTeam())
    for i = 1, #TeamMember do
        --[[if GetTeamMember(i) ~= nil and GetTeamMember(i):IsHero() then
			local unit_name =  GetTeamMember(i):GetUnitName();
			if PairsHeroNameNRole[unit_name] == "support" and not supportAlreadyAssigned then
				HeroLanes[i] = LANE_TOP;
				supportAlreadyAssigned = true;
			elseif PairsHeroNameNRole[unit_name] == "support" and supportAlreadyAssigned then
				HeroLanes[i] = LANE_BOT;
			elseif PairsHeroNameNRole[unit_name] == "midlaner" then
				HeroLanes[i] = LANE_MID;
			elseif PairsHeroNameNRole[unit_name] == "offlaner" then
				if GetTeam() == TEAM_RADIANT then
					HeroLanes[i] = LANE_TOP;
				else
					HeroLanes[i] = LANE_BOT;
				end
			elseif PairsHeroNameNRole[unit_name] == "carry" then
				if GetTeam() == TEAM_RADIANT then
					HeroLanes[i] = LANE_BOT;
				else
					HeroLanes[i] = LANE_TOP;
				end
			end
		end]]
        if GetTeamMember(i) ~= nil and GetTeamMember(i):IsHero() then
            local unit_name = GetTeamMember(i):GetUnitName()
            if PairsHeroNameNRole[unit_name] == "support" then
                if GetTeam() == TEAM_RADIANT then
                    HeroLanes[i] = LANE_BOT
                else
                    HeroLanes[i] = LANE_TOP
                end
            elseif PairsHeroNameNRole[unit_name] == "midlaner" then
                HeroLanes[i] = LANE_MID
            elseif PairsHeroNameNRole[unit_name] == "offlaner" then
                if GetTeam() == TEAM_RADIANT then
                    HeroLanes[i] = LANE_TOP
                else
                    HeroLanes[i] = LANE_BOT
                end
            elseif PairsHeroNameNRole[unit_name] == "carry" then
                if GetTeam() == TEAM_RADIANT then
                    HeroLanes[i] = LANE_BOT
                else
                    HeroLanes[i] = LANE_TOP
                end
            end
        end
    end
end

-- Fill the lane assignment if the captain is human
function FillLAHumanCaptain()
    local TeamMember = GetTeamPlayers(GetTeam())
    for i = 1, #TeamMember do
        if GetTeamMember(i) ~= nil and GetTeamMember(i):IsHero() then
            local unit_name = GetTeamMember(i):GetUnitName()
            local key = GetFromHumanPick(unit_name)
            if key ~= nil then
                if key == 1 then
                    if GetTeam() == TEAM_DIRE then
                        HeroLanes[i] = LANE_BOT
                    else
                        HeroLanes[i] = LANE_TOP
                    end
                elseif key == 2 then
                    if GetTeam() == TEAM_DIRE then
                        HeroLanes[i] = LANE_BOT
                    else
                        HeroLanes[i] = LANE_TOP
                    end
                elseif key == 3 then
                    HeroLanes[i] = LANE_MID
                elseif key == 4 then
                    if GetTeam() == TEAM_DIRE then
                        HeroLanes[i] = LANE_TOP
                    else
                        HeroLanes[i] = LANE_BOT
                    end
                elseif key == 5 then
                    if GetTeam() == TEAM_DIRE then
                        HeroLanes[i] = LANE_TOP
                    else
                        HeroLanes[i] = LANE_BOT
                    end
                end
            end
        end
    end
end

-- Get human picked heroes if the captain is human player
function GetFromHumanPick(hero_name)
    local i = nil
    for key, h in pairs(humanPick) do
        if hero_name == h then
            i = key
        end
    end
    return i
end

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------MID ONLY LANE ASSIGNMENT------------------------------------------------------
function MOLaneAssignment()
    local lanes = {
        [1] = LANE_MID,
        [2] = LANE_MID,
        [3] = LANE_MID,
        [4] = LANE_MID,
        [5] = LANE_MID
    }
    return lanes
end

---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------1 VS 1 LANE ASSIGNMENT------------------------------------------------------
function OneVsOneLaneAssignment()
    local lanes = {
        [1] = LANE_MID,
        [2] = LANE_TOP,
        [3] = LANE_TOP,
        [4] = LANE_TOP,
        [5] = LANE_TOP
    }
    return lanes
end

---------------------------------------------------------------------------------------------------------------------------------------
