----------------------------------------------------------------------------
--	Ranked Matchmaking AI v1.3 New Structure
--	Author: adamqqq		Email:adamqqq@163.com
----------------------------------------------------------------------------
-------
-- 通用技能/物品使用模块
-- 所有英雄的技能使用、加点、防御符文等通用逻辑都在此定义
-------
ability_item_usage_generic = {}

local utility = require(GetScriptDirectory() .. "/util/Utility")
local Courier = require(GetScriptDirectory() .. "/util/CourierSystem")
local ItemUsageSystem = require(GetScriptDirectory() .. "/util/ItemUsageSystem")
local ChatSystem = require(GetScriptDirectory() .. "/util/ChatSystem")
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")

-- 所有防御塔的 ID 列表（用于防御符文判断）
local towerId = {TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3, TOWER_MID_1, TOWER_MID_2, TOWER_MID_3, TOWER_BOT_1, TOWER_BOT_2,
                 TOWER_BOT_3, TOWER_BASE_1, TOWER_BASE_2}

-- 使用独立表存储防御塔血量历史，避免在塔实体上设置自定义属性
local towerHealthHistory = {}

-- 每 0.5 秒记录一次防御塔血量变化，用于判断是否需要使用防御符文
local RefreshBuildingHealth = AbilityExtensions:SingleForTeam(
    AbilityExtensions:EveryManySeconds(0.5, function()
        for _, id in ipairs(towerId) do
            local tower = GetTower(GetTeam(), id)
            if tower ~= nil and tower:GetHealth() > 0 then
                local towerKey = tostring(GetTeam()) .. "_" .. tostring(id)
                if towerHealthHistory[towerKey] == nil then
                    towerHealthHistory[towerKey] = {}
                end
                local history = towerHealthHistory[towerKey]
                history.health0SecondsAgo = tower:GetHealth()
                if tower:IsAlive() then
                    for _, i in ipairs({0.5, 1, 1.5, 2}) do
                        history["health" .. tostring(i) .. "SecondsAgo"] =
                            history["health" .. tostring(i - 0.5) .. "SecondsAgo"]
                    end
                end
            end
        end
    end))

-- 考虑是否使用防御符文（Glyph）
-- 条件：12分钟后，防御塔血量在1秒内骤降 >= 7.5*游戏分钟数，或血量低于1000且有2+敌方英雄
local function ConsiderGlyph()
    RefreshBuildingHealth()
    if GetGlyphCooldown() > 0 then
        return false
    end

    for i, BuildingID in pairs(towerId) do
        local tower = GetTower(GetTeam(), BuildingID)
        if tower ~= nil and tower:GetHealth() > 0 then
            local tableNearbyEnemyHeroes = utility.GetEnemiesNearLocation(tower:GetLocation(), 700)
            local towerKey = tostring(GetTeam()) .. "_" .. tostring(BuildingID)
            local history = towerHealthHistory[towerKey]
            if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes >= 1 and history ~= nil and
                history["health1SecondsAgo"] and tower:GetHealth() - history["health1SecondsAgo"] >= 7.5 * DotaTime() /
                60 and DotaTime() >= 12 * 60 then
                GetBot():ActionImmediate_Glyph() -- 塔血量骤降，开符文
            end
            if tower:GetHealth() >= 200 and tower:GetHealth() <= 1000 and #tableNearbyEnemyHeroes >= 2 then
                GetBot():ActionImmediate_Glyph() -- 塔残血且敌方人多，开符文
                break
            end
        end
    end
end

-- 记录英雄卡住状态（用于后续的卡住检测和逃生处理）
local function RecordStuckState()
    local npcBot = GetBot()
    local botLoc = npcBot:GetLocation()
    if npcBot:IsAlive() and npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and not IsLocationPassable(botLoc) then
        if npcBot.stuckLoc == nil then
            npcBot.stuckLoc = botLoc
            npcBot.stuckTime = DotaTime()
        elseif npcBot.stuckLoc ~= botLoc then
            npcBot.stuckLoc = botLoc
            npcBot.stuckTime = DotaTime()
        end
    else
        npcBot.stuckTime = nil
        npcBot.stuckLoc = nil
    end
end

-- 判断遗迹血量是否低于指定值
local function AncientBelow(team, health)
    local ancient = GetAncient(team)
    if ancient == nil or not ancient:CanBeSeen() then
        return false
    end
    return ancient:IsInvulnerable() and ancient:GetHealth() < health
end

-- 次要操作循环：防御符文 + 未实现物品 + 卡住检测 + 遗迹告警
-- 次要操作循环：防御符文 + 版本公告 + 遗迹血量告警
local function SecondaryOperation()
    ConsiderGlyph()
    ItemUsageSystem.UnImplementedItemUsage()
    RecordStuckState()

    -- 游戏开始前发送版本公告
    if (DotaTime() >= -75 and DotaTime() <= -74) then
        ChatSystem.SendVersionAnnouncement()
    end

    -- 遗迹血量低于1500时发送一级告警
    if AncientBelow(TEAM_RADIANT, 1500) or AncientBelow(TEAM_DIRE, 1500) then
        AbilityExtensions:AnnounceGroups1(GetBot())
    end

    -- 遗迹血量低于1200时发送二级告警
    if AncientBelow(TEAM_RADIANT, 1200) or AncientBelow(TEAM_DIRE, 1200) then
        AbilityExtensions:AnnounceGroups2(GetBot())
    end
end

-- 信使使用与次要操作的主循环
function ability_item_usage_generic.CourierUsageThink()
    if not GetBot():IsAlive() then
        return
    end

    -- 游戏正式开始后才执行次要操作（防御符文/卡住检测/TP等）
    -- 英雄选择/策略/预加载阶段跳过，避免 API 不可用导致 error in error handling
    if GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
        return
    end

    AbilityExtensions:TickFromDota()
    SecondaryOperation()
end

-- 执行技能加点
-- 根据预设的加点表（AbilityToLevelUp）和天赋树（TalentTree）自动加点
local ExecuteAbilityLevelUp = function(AbilityToLevelUp, TalentTree)
    -- 计算当前应该加点的索引（考虑之前错误加点造成的偏移）
    local GetAbilityLevelUpIndex = function(npcBot)
        return npcBot:GetLevel() - npcBot:GetAbilityPoints() + 1 + AbilityToLevelUp.incorrectAbilityLevelUpNumber
    end

    local npcBot = GetBot()
    -- 获取下一个未学习的天赋
    local function GetNextTalent()
        return AbilityExtensions:First(AbilityExtensions:GetTalents(npcBot), function(t)
            return not t:IsTrained()
        end)
    end

    -- 处理刚加点后的状态跟踪
    if AbilityToLevelUp.justLevelUpAbility then
        if AbilityToLevelUp.abilityPoints == npcBot:GetAbilityPoints() then
            AbilityToLevelUp.incorrectAbilityLevelUpNumber = AbilityToLevelUp.incorrectAbilityLevelUpNumber + 1
        end
        AbilityToLevelUp.justLevelUpAbility = false
    end

    AbilityToLevelUp.abilityPoints = npcBot:GetAbilityPoints()

    -- 没有可加的技能点或游戏状态不允许时跳过
    if npcBot:GetAbilityPoints() < 1 + AbilityToLevelUp.incorrectAbilityLevelUpNumber or GetGameState() ~=
        GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
        return
    end

    local abilityName = AbilityToLevelUp[GetAbilityLevelUpIndex(npcBot)]

    -- 如果技能名无效（错误技能名或属性奖励），跳过并记录
    if abilityName == AbilityExtensions.IncorrectAbilityName or abilityName == AbilityExtensions.SpecialBonusAttributes then
        AbilityToLevelUp.incorrectAbilityLevelUpNumber = AbilityToLevelUp.incorrectAbilityLevelUpNumber + 1
        print(npcBot:GetUnitName() .. ": 学习错误技能: " .. tostring(abilityName))
    else
        -- 如果是天赋，从天赋树中获取具体的天赋名称
        if abilityName == "talent" then
            AbilityToLevelUp.talentTreeIndex = AbilityToLevelUp.talentTreeIndex + 1
            if type(TalentTree[AbilityToLevelUp.talentTreeIndex]) == "function" then
                abilityName = TalentTree[AbilityToLevelUp.talentTreeIndex]()
            else
                abilityName = GetNextTalent():GetName()
            end
        end
        npcBot:ActionImmediate_LevelAbility(abilityName)
        AbilityToLevelUp.justLevelUpAbility = true
    end
end

-- 技能加点主函数（供各英雄调用）
function ability_item_usage_generic.AbilityLevelUpThink2(AbilityToLevelUp, TalentTree)
    ExecuteAbilityLevelUp(AbilityToLevelUp, TalentTree)
    return
    --
    -- local npcBot = GetBot()
    -- if (npcBot:GetAbilityPoints() < 1 or #AbilityToLevelUp == 0 or
    --        (GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS))
    -- then
    --    return
    -- end
    --
    -- local abilityname = AbilityToLevelUp[1]
    -- print(npcBot:GetUnitName()..": ability to learn "..tostring(abilityname))
    -- if abilityname == "nil" then
    --    table.remove(AbilityToLevelUp, 1)
    --    return
    -- end
    -- if abilityname == "talent" then
    --    for i, temp in pairs(AbilityToLevelUp) do
    --        if temp == "talent" then
    --            table.remove(AbilityToLevelUp, i)
    --            if #TalentTree >= 1 then
    --                table.insert(AbilityToLevelUp, i, TalentTree[1]())
    --            else
    --
    --            end
    --            table.remove(TalentTree, 1)
    --            break
    --        end
    --    end
    -- end
    --
    -- local ability = npcBot:GetAbilityByName(abilityname)
    -- if ability == nil then
    --    print(npcBot:GetUnitName()..": learn ability nil")
    -- elseif not ability:CanAbilityBeUpgraded() then
    --    print(npcBot:GetUnitName()..": cannot learn ability "..abilityname)
    -- else
    --    npcBot:ActionImmediate_Chat("learn ability "..abilityname, true)
    --    print(npcBot:GetUnitName()..": learn ability "..abilityname)
    -- end
    -- if ability ~= nil and ability:CanAbilityBeUpgraded() then
    --    npcBot:ActionImmediate_LevelAbility(abilityname)
    --    IncrementIncorrectAbility(AbilityToLevelUp)
    -- end
    -- table.remove(AbilityToLevelUp, 1)
end

-- 判断是否可以买活（复活时间 >= 指定秒数）
local function CanBuybackUpperRespawnTime(respawnTime)
    local npcBot = GetBot()
    if (not npcBot:IsAlive() and respawnTime ~= nil and npcBot:GetRespawnTime() >= respawnTime and
        npcBot:GetBuybackCooldown() == 0 and npcBot:GetGold() > npcBot:GetBuybackCost()) then
        return true
    end
    return false
end

-- 检测是否为米波的克隆体（只有鞋和TP，没有其他装备）
function ability_item_usage_generic.IsMeepoClone()
    local npcBot = GetBot()
    if npcBot:GetUnitName() == "npc_dota_hero_meepo" and npcBot:GetLevel() > 1 then
        for i = 0, 5 do
            local item = npcBot:GetItemInSlot(i)
            if item ~= nil and not (string.find(item:GetName(), "boots") or string.find(item:GetName(), "treads")) then
                return false
            end
        end
        return true
    end
    return false
end

-- 买活逻辑：关键建筑被攻击时或游戏后期自动买活
function ability_item_usage_generic.BuybackUsageThink()
    local npcBot = GetBot()

    -- 无敌、非英雄、幻象、米波克隆体不买活
    if npcBot:IsInvulnerable() or not npcBot:IsHero() or not string.find(npcBot:GetUnitName(), "hero") or
        npcBot:IsIllusion() or IsMeepoClone() then
        return
    end

    if not npcBot:HasBuyback() then
        return
    end

    -- 复活时间不到20秒不买活（性能考虑，不用 GetUnitList）
    if (not CanBuybackUpperRespawnTime(20)) then
        return
    end

    -- 检查关键建筑是否被攻击
    local tower_top_3 = GetTower(GetTeam(), TOWER_TOP_3)
    local tower_mid_3 = GetTower(GetTeam(), TOWER_MID_3)
    local tower_bot_3 = GetTower(GetTeam(), TOWER_BOT_3)
    local tower_base_1 = GetTower(GetTeam(), TOWER_BASE_1)
    local tower_base_2 = GetTower(GetTeam(), TOWER_BASE_2)
    local barracks_top_melee = GetBarracks(GetTeam(), BARRACKS_TOP_MELEE)
    local barracks_mid_melee = GetBarracks(GetTeam(), BARRACKS_MID_MELEE)
    local barracks_bot_melee = GetBarracks(GetTeam(), BARRACKS_BOT_MELEE)
    local ancient = GetAncient(GetTeam())

    local buildList = {tower_top_3, tower_mid_3, tower_bot_3, tower_base_1, tower_base_2, barracks_top_melee,
                       barracks_mid_melee, barracks_bot_melee, ancient}

    -- 25分钟后，如果关键建筑附近有2+敌方英雄且正在被攻击，则买活
    for _, build in pairs(buildList) do
        local tableNearbyEnemyHeroes = build:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
        if DotaTime() > 25 * 60 and CanBuybackUpperRespawnTime(20) then
            if (tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 1) then
                if (build:WasRecentlyDamagedByAnyHero(2.0) and CanBuybackUpperRespawnTime(20)) then
                    npcBot:ActionImmediate_Buyback()
                    return
                end
            end
        end
    end

    -- 35分钟后，复活时间>=30秒则自动买活
    if (DotaTime() > 35 * 60 and CanBuybackUpperRespawnTime(30)) then
        npcBot:ActionImmediate_Buyback()
    end
end

-- 初始化英雄技能：扫描所有技能槽，分离出普通技能和天赋
function ability_item_usage_generic.InitAbility(Abilities, AbilitiesReal, Talents)
    local npcBot = GetBot()

    for i = 0, 25, 1 do
        local ability = npcBot:GetAbilityInSlot(i)
        if (ability ~= nil) then
            print("技能名称:" .. npcBot:GetUnitName() .. "-" .. ability:GetName())
            if (ability:GetName() ~= "generic_hidden") then
                if (ability:IsTalent() == true) then
                    table.insert(Talents, ability:GetName()) -- 存入天赋
                else
                    table.insert(Abilities, ability:GetName()) -- 存入技能名
                    table.insert(AbilitiesReal, ability) -- 存入技能对象
                end
            end
        end
    end

    npcBot.abilityInited = true -- 每次脚本重载时设为 true
end

-- 计算连招所需的总蓝量
function ability_item_usage_generic.GetComboMana(AbilitiesReal)
    local npcBot = GetBot()
    local tempComboMana = 0
    for i, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            if ability:IsUltimate() == false or ability:GetCooldownTimeRemaining() <= 30 then
                tempComboMana = tempComboMana + ability:GetManaCost()
            end
        end
    end
    return math.max(tempComboMana, 300)
end

-- 计算连招总伤害
function ability_item_usage_generic.GetComboDamage(AbilitiesReal)
    local npcBot = GetBot()
    local tempComboDamage = 0
    for i, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            tempComboDamage = tempComboDamage + ability:GetAbilityDamage()
        end
    end
    return math.max(tempComboDamage, GetBot():GetOffensivePower())
end

-- 调试用：打印技能使用信息
function ability_item_usage_generic.PrintDebugInfo(AbilitiesReal, cast)
    local npcBot = GetBot()
    for i = 1, #AbilitiesReal do
        if (cast.Desire[i] ~= nil and cast.Desire[i] > 0) then
            local ability = AbilitiesReal[i]
            if ((cast.Type[i] == nil or cast.Type[i] == "Target") and cast.Target[i] ~= nil and
                utility.CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_UNIT_TARGET)) then
                if (cast.Target[i] ~= nil) then
                    utility.DebugTalk("尝试使用技能 " .. i .. " 对 " .. cast.Target[i]:GetUnitName() ..
                                          " 欲望值= " .. cast.Desire[i])
                else
                    utility.DebugTalk("尝试使用技能 " .. i .. " 欲望值= " .. cast.Desire[i])
                end
            else
                utility.DebugTalk("尝试使用技能 " .. i .. " 欲望值= " .. cast.Desire[i])
            end
        end
    end
end

-- 根据考虑函数计算各技能的施放欲望并执行
function ability_item_usage_generic.ConsiderAbility(AbilitiesReal, Consider)
    local npcBot = GetBot()
    local cast = {}
    cast.Desire = {}
    cast.Target = {}
    cast.Type = {}
    for i, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false and Consider[i] ~= nil then
            cast.Desire[i], cast.Target[i], cast.Type[i] = Consider[i]()
        end
    end
    return cast
end

function ability_item_usage_generic.ConsiderAbilityCoroutine(AbilitiesReal, Consider)
    local npcBot = GetBot()
    local cast = {}
    cast.Desire = {}
    cast.Target = {}
    cast.Type = {}
    for i, ability in pairs(AbilitiesReal) do
        if Consider[i] ~= nil then
            local consider1 = AbilityExtensions:ResumeUntilReturn(Consider[i])
            consider1 = AbilityExtensions:Max(consider1, function(t)
                return t[1]
            end)
            if consider1 then
                cast.Desire[i], cast.Target[i], cast.Type[i] = AbilityExtensions:Unpack(consider1)
            else
                cast.Desire[i] = 0
            end
        end
    end
    return cast
end

local worldBounds = GetWorldBounds()
local function OutOfBound(vector)
    return worldBounds[1] >= vector.x or worldBounds[2] >= vector.y or worldBounds[3] <= vector.x or worldBounds[4] <=
               vector.y
end
function ability_item_usage_generic.UseAbility(AbilitiesReal, cast)
    local npcBot = GetBot()
    local HighestDesire = 0
    local HighestDesireAbility = 0
    local HighestDesireAbilityNumber = 0
    for i, ability in pairs(AbilitiesReal) do
        if (cast.Desire[i] ~= nil and cast.Desire[i] > HighestDesire) then
            HighestDesire = cast.Desire[i]
            HighestDesireAbilityNumber = i
        end
    end
    if (HighestDesire > 0) then
        local j = HighestDesireAbilityNumber
        local ability = AbilitiesReal[j]
        if not ability:IsCooldownReady() then
            print("Ability still in cooldown: " .. ability:GetName())
            AbilityExtensions:DebugPause()
            return
        end
        if npcBot:GetMana() < ability:GetManaCost() then
            print("Ability mana not enough: " .. ability:GetName())
            AbilityExtensions:DebugPause()
            return
        end
        if ability:IsHidden() then
            print("Ability is hidden: " .. ability:GetName())
            AbilityExtensions:DebugPause()
            return
        end
        -- if npcBot:IsRooted() then
        -- 	print("use when rooted: "..ability:GetName())
        -- end

        local function CallWithTarget()
            cast.Type[j] = "Target"
            -- if not AbilityExtensions:IsHero(cast.Target[j]) then
            -- 	print("target at creep"..ability:GetName())
            -- end
            -- print("target ability :"..ability:GetName())
            if AbilityExtensions:IsVector(cast.Target[j]) then
                print("Wrong target type")
                print(ability:GetName(), cast.Target[j], cast.Type[j])
                AbilityExtensions:DebugPause()
                return
            else
                npcBot:Action_UseAbilityOnEntity(ability, cast.Target[j])
            end
        end
        local function CallWithLocation()
            cast.Type[j] = "Location"
            if not AbilityExtensions:IsVector(cast.Target[j]) then
                print("Wrong target type")
                print(ability:GetName(), cast.Target[j], cast.Type[j])
                AbilityExtensions:DebugPause()
                return
            elseif OutOfBound(cast.Target[j]) then
                print("Ability cast out of world bounds!")
                print(ability:GetName(), cast.Target[j], cast.Type[j])
                AbilityExtensions:DebugPause()
                return
            else
                npcBot:Action_UseAbilityOnLocation(ability, cast.Target[j])
            end
        end

        if (cast.Type[j] == nil) then
            if (utility.CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_NO_TARGET)) then
                npcBot:Action_UseAbility(ability)
            elseif (utility.CheckFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_POINT)) then
                CallWithLocation()
            elseif (utility.CheckFlag(ability:GetTargetType(), ABILITY_TARGET_TYPE_TREE)) then
                cast.Type[j] = "Tree"
                npcBot:Action_UseAbilityOnTree(ability, cast.Target[j])
            else
                CallWithTarget()
            end
        else
            if cast.Type[j] == "Target" then
                CallWithTarget()
            elseif cast.Type[j] == "Location" then
                CallWithLocation()
            elseif cast.Type[j] == "Tree" then
                npcBot:Action_UseAbilityOnTree(ability, cast.Target[j])
            else
                npcBot:Action_UseAbility(ability)
            end
        end
        return j, cast.Target[j], cast.Type[j]
    end
end

-- 导出函数到全局（兼容旧版 require 调用模式）
for k, v in pairs(ability_item_usage_generic) do
    _G[k] = v
end
