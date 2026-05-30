----------------------------------------------------------------------------
--	全局工具库 —包含通用辅助函数
----------------------------------------------------------------------------
local Func = require(GetScriptDirectory() .. "/util/functional")
local utilityModule = {}
local NewTable = Func.NewTable

-- 引入 CDOTA_Bot_Script 扩展方法（每个 Lua 状态需加载一次）
require(GetScriptDirectory() .. "/base/BotExtensions")
local config = require(GetScriptDirectory() .. "/const/config")
local heroUnit = require(GetScriptDirectory() .. "/base/HeroUtility")

-- 常量定义
utilityModule.Const = {
    MAX_SEARCH_DISTANCE = 1600,
    MAX_ALLY_SEARCH_DISTANCE = 1200,
    EXTRA_SEARCH_DISTANCE = 300,
    WARNING_DISTANCE = 600,
    FOUNTAIN_RADIANT = Vector(-7093, -6542),                    -- 天辉泉水坐标
    FOUNTAIN_DIRE = Vector(7015, 6534),                         -- 夜魇泉水坐标
    RADIANT_BASE = Vector(-7174.000000, -6671.00000, 0.000000), -- 天辉基地深处坐标
    DIRE_BASE = Vector(7023.000000, 6450.000000, 0.000000)      -- 夜魇基地深处坐标
}
---------------------------------------------------------------------------------------------------
------  全局工具库，包含一些有用的函数  ------
---------------------------------------------------------------------------------------------------

-- 检测敌方英雄是否拥有免疫类减益效果（委托至 HeroUtility）
function utilityModule.HasImmuneDebuff(npcEnemy)
    return heroUnit.HasImmuneDebuff(npcEnemy)
end

-- 常规施法判定（委托至 HeroUtility）
function utilityModule.NCanCast(npcEnemy)
    return heroUnit.NCanCast(npcEnemy)
end

-- 魔免施法判定（委托至 HeroUtility）
function utilityModule.MiCanCast(npcEnemy)
    return heroUnit.MiCanCast(npcEnemy)
end

-- 通用施法判定（委托至 HeroUtility）
function utilityModule.UCanCast(npcEnemy)
    return heroUnit.UCanCast(npcEnemy)
end

-- 无目标施法：始终返回true
function utilityModule.CanCastNoTarget()
    return heroUnit.CanCastNoTarget()
end

function utilityModule.CanCastPassive()
    return heroUnit.CanCastPassive()
end

function utilityModule.IsRoshan(npcTarget)
    return heroUnit.IsRoshan(npcTarget)
end

function utilityModule.CheckFlag(nBehavior, nFlag)
    if (nFlag == 0) then
        if (nBehavior == 0) then
            return true
        else
            return false
        end
    end

    return ((nBehavior / nFlag) % 2) >= 1
end

-- 判断敌方英雄是否处于被控制状态（委托至 HeroUtility）
function utilityModule.enemyDisabled(npcEnemy)
    return heroUnit.enemyDisabled(npcEnemy)
end

-- 判断一个单位是否为敌方单位（委托至 HeroUtility）
function utilityModule.IsEnemy(hUnit)
    return heroUnit.IsEnemy(hUnit)
end

function utilityModule.PointToPointDistance(a, b)
    local x1 = a.x
    local x2 = b.x
    local y1 = a.y
    local y2 = b.y
    return math.sqrt(math.pow((y2 - y1), 2) + math.pow((x2 - x1), 2))
end

-- 获取两点间距离（PointToPointDistance 的别名）
function utilityModule.GetDistance(a, b)
    return utilityModule.PointToPointDistance(a, b)
end

----------------------------------------------------------------------------------------------------

function utilityModule.GetUnitsTowardsLocation(unit, target, nUnits)
    local vMyLocation, vTargetLocation = unit:GetLocation(), target:GetLocation()
    local tempvector = (vTargetLocation - vMyLocation) /
        utilityModule.PointToPointDistance(vMyLocation, vTargetLocation)
    return vMyLocation + nUnits * tempvector
end

-- 在施法范围内随机找一个落点
function utilityModule.RandomInCastRangePoint(unit, target, CastRange, distance)
    local i = 0
    local l, d
    repeat
        l = utilityModule.GetUnitsTowardsLocation(unit, target, GetUnitToUnitDistance(unit, target) / 2) +
            RandomVector(RandomInt(0, distance))
        d = GetUnitToLocationDistance(unit, l)
        i = i + 1
    until (d <= CastRange or i >= 10)
    if (i >= 10) then
        return utilityModule.GetUnitsTowardsLocation(unit, target, distance)
    else
        return l
    end
end

-- 获取指向基地的安全随机向量（用于撤退时选择方向
function utilityModule.GetSafeVector(unit, distance)
    local v = RandomVector(distance)
    if (unit:GetTeam() == TEAM_RADIANT) then
        if (v.x > 0) then
            v.x = -v.x -- 天辉方向指向左下（负坐标方向
        end
        if (v.y > 0) then
            v.y = -v.y
        end
    else
        if (v.x < 0) then
            v.x = -v.x -- 夜魇方向指向右上（正坐标方向
        end
        if (v.y < 0) then
            v.y = -v.y
        end
    end
    return v
end

-- 获取某个位置附近的敌方英雄列表
function utilityModule.GetEnemiesNearLocation(loc, dist)
    if loc == nil then
        return {}
    end

    local Enemies = {}

    for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if (GetUnitToLocationDistance(enemy, loc) < dist) then
            table.insert(Enemies, enemy)
        end
    end

    return Enemies
end

-- 获取某个位置附近的友方英雄列表
function utilityModule.GetAlliesNearLocation(loc, dist)
    if loc == nil then
        return {}
    end

    local Allies = {}

    for _, enID in pairs(GetTeamPlayers(GetTeam())) do
        local allyInfo = GetHeroLastSeenInfo(enID)[1]
        if allyInfo ~= nil and allyInfo["location"] ~= nil then
            if IsHeroAlive(enID) and utilityModule.GetDistance(allyInfo["location"], loc) <= dist and
                (utilityModule.GetDistance(allyInfo["location"], Vector(0, 0)) > 10) and allyInfo["time_since_seen"] <
                10 then
                table.insert(Allies, enID)
            end
        end
    end

    return Allies
end

-- 检查背包中是否有指定物品，有则返回该物品
function utilityModule.IsItemAvailable(item_name)
    local npcBot = GetBot()

    for i = 0, 5, 1 do
        local item = npcBot:GetItemInSlot(i)
        if (item ~= nil) then
            if (item:GetName() == item_name) then
                return item
            end
        end
    end
    return nil
end

local function GetAbilityNames(npcBot)
    local g = NewTable()
    for i = 0, 25 do
        local ability = npcBot:GetAbilityInSlot(i)
        if ability ~= nil and ability:GetName() ~= "generic_hidden" then
            table.insert(g, ability:GetName())
        end
    end
    return g
end

local specialBonusAttributes = "special_bonus_attributes"
local incorrectAbilityName = "incorrect_name"
-- 填充技能加点表：验证并修正每个等级的技能名称，补充天赋槽位
utilityModule.FillInAbilities = function(npcBot, abilityTable)
    local abilitiesNames = GetAbilityNames(npcBot)
    if #abilityTable == 25 then
        table.insert(abilityTable, "nil")
        for i = 27, 30 do
            table.insert(abilityTable, "talent")
        end
    end
    for i = 1, 30 do
        if abilityTable[i] == "nil" then
            abilityTable[i] = specialBonusAttributes
        elseif abilityTable[i] == "talent" then
        elseif abilityTable[i] == nil then
            print("Bot script " .. npcBot:GetUnitName() .. " 在等待" .. i .. " 包含错误的技能名: nil")
            abilityTable[i] = incorrectAbilityName
        elseif not Func:Contains(abilitiesNames, abilityTable[i]) then
            print("Bot script " .. npcBot:GetUnitName() .. " 在等待" .. i .. " 包含错误的技能名: " ..
                abilityTable[i])
            abilityTable[i] = incorrectAbilityName
        end
    end
    abilityTable.incorrectAbilityLevelUpNumber = Func:Count(abilityTable, function(abilityName, index)
        if abilityName == "talent" then
            return false
        end
        local result = index < npcBot:GetLevel() - npcBot:GetAbilityPoints() + 1 and
            (abilityName == incorrectAbilityName)
        return result
    end)
    abilityTable.talentTreeIndex = Func:Count(abilityTable, function(abilityName, index)
        return
            index < npcBot:GetLevel() - npcBot:GetAbilityPoints() + 1 - abilityTable.incorrectAbilityLevelUpNumber and
            abilityName == "talent"
    end)
end

-- 检查技能加点表的有效性并填充缺失信息
function utilityModule.CheckAbilityBuild(AbilityToLevelUp)
    local npcBot = GetBot()
    utilityModule.FillInAbilities(npcBot, AbilityToLevelUp)
end

-- 获取泉水的位置坐标
function utilityModule.Fountain(team)
    if team == TEAM_RADIANT then
        return utilityModule.Const.FOUNTAIN_RADIANT
    end
    return utilityModule.Const.FOUNTAIN_DIRE
end

-- 获取敌对队伍的枚举
function utilityModule.GetOtherTeam()
    if GetTeam() == TEAM_RADIANT then
        return TEAM_DIRE
    else
        return TEAM_RADIANT
    end
end

-- 从单位列表中找出血量最低的单位（委托至 HeroUtility）
function utilityModule.GetWeakestUnit(EnemyUnits)
    return heroUnit.GetWeakestUnit(EnemyUnits)
end

-- 从单位列表中找出血量最高的单位（委托至 HeroUtility）
function utilityModule.GetStrongestUnit(EnemyUnits)
    return heroUnit.GetStrongestUnit(EnemyUnits)
end

-- 获取距离指定位置最近的建筑
function utilityModule.GetNearestBuilding(team, location)
    local buildings = utilityModule.GetAllBuilding(team)
    local minDist = 16000 ^ 2
    local nearestBuilding = nil
    for _, v in pairs(buildings) do
        local dist = utilityModule.PointToPointDistance(location, v:GetLocation()) ^ 2
        if dist < minDist then
            minDist = dist
            nearestBuilding = v
        end
    end
    return nearestBuilding
end

-- 获取指定队伍的所有存活建筑（防御塔、兵营、遗迹）
-- 注意：7.33 版本已移除神龛，故不再收集
function utilityModule.GetAllBuilding(team)
    local buildings = {}
    for i = 0, 10 do
        local tower = GetTower(team, i)
        if utilityModule.NotNilOrDead(tower) then
            table.insert(buildings, tower)
        end
    end

    for i = 0, 5 do
        local barrack = GetBarracks(team, i)
        if utilityModule.NotNilOrDead(barrack) then
            table.insert(buildings, barrack)
        end
    end

    local ancient = GetAncient(team)
    table.insert(buildings, ancient)
    return buildings
end

-- 判断单位是否不为空且存活
function utilityModule.NotNilOrDead(unit)
    if unit == nil or unit:IsNull() then
        return false
    end
    if unit:IsAlive() then
        return true
    end
    return false
end

-- 调试用：发送聊天消息（仅在 config.debugMode 开启时生效）
function utilityModule.DebugTalk(message)
    if config.debugMode then
        local npcBot = GetBot()
        npcBot:ActionImmediate_Chat(message, true)
    end
end

-- 调试用：打印技能名称列表
function utilityModule.PrintAbilityName(abilities)
    local msg = "{ "
    for k, v in ipairs(abilities) do
        msg = msg .. '"' .. v .. '", '
    end
    msg = string.sub(msg, 0, #msg - 2) -- 去掉末尾逗号
    msg = msg .. " }"
    local npcBot = GetBot()
    npcBot:ActionImmediate_Chat(msg, true)
end

-- 带延迟的调试聊天（避免刷屏）
function utilityModule.DebugTalk_Delay(message)
    local npcBot = GetBot()
    if (npcBot.LastSpeaktime == nil) then
        npcBot.LastSpeaktime = 0
    end
    if (GameTime() - npcBot.LastSpeaktime > 1) then
        npcBot:ActionImmediate_Chat(message, true)
        npcBot.LastSpeaktime = GameTime()
    end
end

-- 检测英雄与目标位置之间是否有树木阻挡
function utilityModule.AreTreesBetween(loc, r)
    local npcBot = GetBot()

    local trees = npcBot:GetNearbyTrees(GetUnitToLocationDistance(npcBot, loc))
    for _, tree in pairs(trees) do
        local x = GetTreeLocation(tree)
        local y = npcBot:GetLocation()
        local z = loc

        if x ~= y then
            local a = 1
            local b = 1
            local c

            if x.x - y.x == 0 then
                b = 0
                c = -x.x
            else
                a = -(x.y - y.y) / (x.x - y.x)
                c = -(x.y + x.x * a)
            end

            local d = math.abs((a * z.x + b * z.y + c) / math.sqrt(a * a + b * b))
            if d <= r and GetUnitToLocationDistance(npcBot, loc) > utilityModule.GetDistance(x, loc) + 50 then
                return true
            end
        end
    end
    return false
end

function utilityModule.VectorTowards(s, t, d)
    local f = t - s
    f = f / utilityModule.GetDistance(f, Vector(0, 0))
    return s + (f * d)
end

-- 获取逃生位置（远离泉水则回基地，否则回泉水深处）
function utilityModule.GetEscapeLoc()
    local bot = GetBot()
    local team = GetTeam()
    if bot:DistanceFromFountain() > 2500 then
        return GetAncient(team):GetLocation()
    else
        if team == TEAM_DIRE then
            return DIRE_BASE
        else
            return RADIANT_BASE
        end
    end
end

-- 安全获取 unit 附近可见英雄列表
--
-- 封装 npcBot:GetNearbyHeroes(radius, isEnemy, mode) 并过滤不可见单位，
-- 避免对战争迷雾中的单位操作时触发引擎警告。
--
-- 参数：
--   unit    - 搜索中心的单位（bot、敌方英雄、塔、建筑等任何 CDOTA_Bot_Script 对象）
--   radius  - 搜索半径
--   isEnemy - true 返回敌方英雄，false 返回友方英雄（相对于 unit 所属队伍）
--   mode    - 行为模式过滤（通常传 BOT_MODE_NONE 获取所有，也可只获取特定模式的英雄）
--
-- 返回：
--   可见英雄的列表（可能为空表）
function utilityModule.GetNearbyVisibleHeroes(unit, radius, isEnemy, mode)
    local heroes = unit:GetNearbyHeroes(radius, isEnemy, mode)
    if heroes == nil then
        return {}
    end
    local visible = {}
    for _, h in ipairs(heroes) do
        if h:CanBeSeen() then
            table.insert(visible, h)
        end
    end
    return visible
end

-- 检查技能加点表是否需要裁剪（当等级较低时移除多余的加点项目）
function utilityModule.CheckAbilityBuildSimple(abilityTree)
    local npcBot = GetBot()
    if #abilityTree > 26 - npcBot:GetLevel() then
        local level = npcBot:GetLevel()
        for _ = 1, level do
            table.remove(abilityTree, 1)
        end
    end
end

-- 判断目标是否为有效的敌方英雄目标（委托至 HeroUtility）
function utilityModule.IsValidTarget(npcTarget)
    return heroUnit.IsValidTarget(npcTarget)
end

-- 检查目标是否有林肯法球/法术反射状态（委托至 HeroUtility）
function utilityModule.HasSphere(npcTarget)
    return heroUnit.HasSphere(npcTarget)
end

-- 判断目标是否为可疑的幻象（委托至 HeroUtility）
function utilityModule.IsSuspiciousIllusion(npcTarget)
    return heroUnit.IsSuspiciousIllusion(npcTarget)
end

-- 常规施法判定（委托至 HeroUtility）
function utilityModule.NormalCanCast(npcTarget)
    return heroUnit.NormalCanCast(npcTarget)
end

-- Roshan 施法判定（委托至 HeroUtility）
function utilityModule.RoshanCanCast(npcTarget)
    return heroUnit.RoshanCanCast(npcTarget)
end

-- 大招施法判定（委托至 HeroUtility）
function utilityModule.UltimateCanCast(npcTarget)
    return heroUnit.UltimateCanCast(npcTarget)
end

-- AOE 施法判定（委托至 HeroUtility）
function utilityModule.AoeCanCast(npcTarget)
    return heroUnit.AoeCanCast(npcTarget)
end

-- 计算连招耗蓝
function utilityModule.GetComboMana(AbilitiesReal)
    local tempComboMana = 0
    for _, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            if ability:IsUltimate() == false or ability:GetCooldownTimeRemaining() <= 30 then
                tempComboMana = tempComboMana + ability:GetManaCost()
            end
        end
    end
    return math.max(tempComboMana, 300)
end

-- 计算连招伤害
function utilityModule.GetComboDamage(AbilitiesReal)
    local tempComboDamage = 0
    for _, ability in pairs(AbilitiesReal) do
        if ability:IsPassive() == false then
            tempComboDamage = tempComboDamage + ability:GetAbilityDamage()
        end
    end
    return math.max(tempComboDamage, GetBot():GetOffensivePower())
end

return utilityModule
