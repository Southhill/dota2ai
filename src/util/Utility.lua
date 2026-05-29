local utilityModule = {} -- 工具模块，提供通用的辅助函数
local AbilityExtensions = require(GetScriptDirectory() .. "/util/AbilityAbstraction")
---------------------------------------------------------------------------------------------------
------  全局工具库，包含一些有用的函数  ------
---------------------------------------------------------------------------------------------------

-- 检测敌方英雄是否拥有免疫类减益效果（如回光返照、寒冬诅咒等）
function utilityModule.HasImmuneDebuff(npcEnemy)
    return npcEnemy:HasModifier("modifier_abaddon_borrowed_time") or -- 亚巴顿回光返照
               npcEnemy:HasModifier("modifier_winter_wyvern_winters_curse") or -- 寒冬飞龙寒冬诅咒
               npcEnemy:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison") or -- 黑鸟星体禁锢
               npcEnemy:HasModifier("modifier_winter_wyvern_winters_curse_aura") -- 寒冬诅咒光环
end

-- 常规施法判定：目标可见、非魔免、非无敌、无免疫减益
function utilityModule.NCanCast(npcEnemy)
    return npcEnemy:CanBeSeen() and not npcEnemy:IsMagicImmune() and not npcEnemy:IsInvulnerable() and
               not utilityModule.HasImmuneDebuff(npcEnemy)
end

-- 魔免施法判定：等同于 UCanCast（可对魔免目标施法）
function utilityModule.MiCanCast(npcEnemy)
    return utilityModule.UCanCast(npcEnemy)
end

-- 通用施法判定：目标可见、非无敌、无免疫减益、非幻象
function utilityModule.UCanCast(npcEnemy)
    return npcEnemy:CanBeSeen() and not npcEnemy:IsInvulnerable() and not utilityModule.HasImmuneDebuff(npcEnemy) and
               not npcEnemy:IsIllusion()
end

-- 无目标施法：始终返回true
function utilityModule.CanCastNoTarget()
    return true
end

-- 被动技能施法：始终返回true
function utilityModule.CanCastPassive()
    return true
end

function utilityModule.IsRoshan(npcTarget)
    return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan")
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

----------------- 本地工具函数（为 Lua 局部可见性重新排序）--------

-- 判断敌方英雄是否处于被控制状态（缠绕、眩晕、妖术）
function utilityModule.enemyDisabled(npcEnemy)
    if npcEnemy:IsRooted() or npcEnemy:IsStunned() or npcEnemy:IsHexed() then
        return true
    end
    return false
end

-- 判断一个单位是否为敌方单位
function utilityModule.IsEnemy(hUnit)
    local ourTeam = GetTeam()
    local Team = GetTeamForPlayer(hUnit:GetPlayerID())
    if ourTeam == Team then
        return false
    else
        return true
    end
end

-- 计算两点之间的欧几里得距离
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

-- 计算英雄的综合状态因子（血量百分比 + 蓝量百分比）
function CDOTA_Bot_Script:GetFactor()
    return self:GetHealth() / self:GetMaxHealth() + self:GetMana() / self:GetMaxMana()
end

----------------------------------------------------------------------------------------------------
-- 向量相关函数
-- BOT EXPERIMENT 的代码，来自 http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
----------------------------------------------------------------------------------------------------

function CDOTA_Bot_Script:GetForwardVector()
    local radians = self:GetFacing() * math.pi / 180
    local forward_vector = Vector(math.cos(radians), math.sin(radians))
    return forward_vector
end

-- 判断英雄是否面向某个目标（带角度精度参数）
function CDOTA_Bot_Script:IsFacingUnit(hTarget, degAccuracy)
    local direction = (hTarget:GetLocation() - self:GetLocation()):Normalized()
    local dot = direction:Dot(self:GetForwardVector())
    local radians = degAccuracy * math.pi / 180
    return dot > math.cos(radians)
end

function CDOTA_Bot_Script:GetXUnitsTowardsLocation(vLocation, nUnits)
    local direction = (vLocation - self:GetLocation()):Normalized()
    return self:GetLocation() + direction * nUnits
end

-- 获取英雄前方 nUnits 距离的坐标
function CDOTA_Bot_Script:GetXUnitsInFront(nUnits)
    return self:GetLocation() + self:GetForwardVector() * nUnits
end

-- 获取英雄后方 nUnits 距离的坐标
function CDOTA_Bot_Script:GetXUnitsInBehind(nUnits)
    return self:GetLocation() - self:GetForwardVector() * nUnits
end

-- 判断英雄是否为肉山（Roshan)
function CDOTA_Bot_Script:IsRoshan()
    return string.find(self:GetUnitName(), "roshan")
end

----------------------------------------------------------------------------------------------------

function utilityModule.GetUnitsTowardsLocation(unit, target, nUnits)
    local vMyLocation, vTargetLocation = unit:GetLocation(), target:GetLocation()
    local tempvector = (vTargetLocation - vMyLocation) /
                           utilityModule.PointToPointDistance(vMyLocation, vTargetLocation)
    return vMyLocation + nUnits * tempvector
end

-- 在施法范围内随机找一个落点（用于闪烁技能等）
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

-- 获取某个位置附近的友方英雄列表（基于最后一次看到的信息
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

-- 填充技能加点表：验证并修正每个等级的技能名称，补充天赋槽位
utilityModule.FillInAbilities = function(npcBot, abilityTable)
    local abilities = AbilityExtensions:GetAbilityNames(npcBot)
    if #abilityTable == 25 then
        table.insert(abilityTable, "nil")
        for i = 27, 30 do
            table.insert(abilityTable, "talent")
        end
    end
    for i = 1, 30 do
        if abilityTable[i] == "nil" then
            abilityTable[i] = AbilityExtensions.SpecialBonusAttributes
        elseif abilityTable[i] == "talent" then
        elseif abilityTable[i] == nil then
            print("Bot script " .. npcBot:GetUnitName() .. " 在等�?" .. i .. " 包含错误的技能名: nil")
            abilityTable[i] = AbilityExtensions.IncorrectAbilityName
        elseif not AbilityExtensions:Contains(abilities, abilityTable[i]) then
            print("Bot script " .. npcBot:GetUnitName() .. " 在等�?" .. i .. " 包含错误的技能名: " ..
                      abilityTable[i])
            abilityTable[i] = AbilityExtensions.IncorrectAbilityName
        end
    end
    abilityTable.incorrectAbilityLevelUpNumber = AbilityExtensions:Count(abilityTable, function(abilityName, index)
        if abilityName == "talent" then
            return false
        end
        local ability = npcBot:GetAbilityByName(abilityName)
        local result = index < npcBot:GetLevel() - npcBot:GetAbilityPoints() + 1 and
                           (abilityName == AbilityExtensions.IncorrectAbilityName)
        return result
    end)
    abilityTable.talentTreeIndex = AbilityExtensions:Count(abilityTable, function(abilityName, index)
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
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------------------------
-- 获取泉水的位置坐标
function utilityModule.Fountain(team)
    if team == TEAM_RADIANT then
        return Vector(-7093, -6542) -- 天辉泉水坐标
    end
    return Vector(7015, 6534) -- 夜魇泉水坐标
end

-- 获取敌对队伍的枚举
function utilityModule.GetOtherTeam()
    if GetTeam() == TEAM_RADIANT then
        return TEAM_DIRE
    else
        return TEAM_RADIANT
    end
end

-- 从单位列表中找出血量最低的单位
function utilityModule.GetWeakestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 10000
    end

    local WeakestUnit = nil
    local LowestHealth = 10000
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() and unit:CanBeSeen() then
            if unit:GetHealth() < LowestHealth then
                LowestHealth = unit:GetHealth()
                WeakestUnit = unit
            end
        end
    end

    return WeakestUnit, LowestHealth
end

-- 从单位列表中找出血量最高的单位
function utilityModule.GetStrongestUnit(EnemyUnits)
    if EnemyUnits == nil or #EnemyUnits == 0 then
        return nil, 0
    end

    local StrongestUnit = nil
    local HighestHealth = 0
    for _, unit in pairs(EnemyUnits) do
        if unit ~= nil and unit:IsAlive() and unit:CanBeSeen() then
            if unit:GetHealth() > HighestHealth then
                HighestHealth = unit:GetHealth()
                StrongestUnit = unit
            end
        end
    end

    return StrongestUnit, HighestHealth
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

-- 获取指定队伍的所有建筑（防御塔、兵营、神龛、遗迹）
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

    for i = 0, 4 do
        local shrine = GetShrine(team, i)
        if utilityModule.NotNilOrDead(shrine) then
            table.insert(buildings, shrine)
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

-- 调试用：发送聊天消息（仅在 debug_mode 开启时生效
function utilityModule.DebugTalk(message)
    local debug_mode = false

    if (debug_mode == true) then
        local npcBot = GetBot()
        npcBot:ActionImmediate_Chat(message, true)
    end
end

function utilityModule.DebugTable(tb)
    local msg = "{ "
    local DebugRec
    DebugRec = function(tb)
        for k, v in pairs(tb) do
            if type(v) == "number" or type(v) == "string" then
                msg = msg .. k .. " = " .. v
                msg = msg .. ", "
            end
            if type(v) == "table" then
                msg = msg .. k .. " = " .. "{ "
                DebugRec(v)
                msg = msg .. "}, "
            end
        end
    end
    DebugRec(tb)
    msg = msg .. " }"

    local npcBot = GetBot()
    npcBot:ActionImmediate_Chat(msg, true)
end

-- 反转键值对
function utilityModule.ReverseTable(tb)
    local g = {}
    for k, v in pairs(tb) do
        if type(v) == "number" or type(v) == "string" then
            g[v] = k
        end
    end
    return g
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

local RadiantBase = Vector(-7174.000000, -6671.00000, 0.000000) -- 天辉基地深处坐标
local DireBase = Vector(7023.000000, 6450.000000, 0.000000) -- 夜魇基地深处坐标

-- 获取逃生位置（远离泉水则回基地，否则回泉水深处）
function utilityModule.GetEscapeLoc()
    local bot = GetBot()
    local team = GetTeam()
    if bot:DistanceFromFountain() > 2500 then
        return GetAncient(team):GetLocation()
    else
        if team == TEAM_DIRE then
            return DireBase
        else
            return RadiantBase
        end
    end
end

-- 检测英雄是否卡住（长时间在同一个位置移动但无法前进
function utilityModule.IsStuck(npcBot)
    if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then
        local attackTarget = npcBot:GetAttackTarget()
        local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()))
        local TAd = GetUnitToUnitDistance(npcBot, GetAncient(GetTeam()))
        local Et = npcBot:GetNearbyTowers(450, true)
        local At = npcBot:GetNearbyTowers(450, false)
        if npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and attackTarget == nil and EAd > 2200 and TAd >
            2200 and #Et == 0 and #At == 0 and DotaTime() > npcBot.stuckTime + 5.0 and
            GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25 then
            print(npcBot:GetUnitName() .. " is stuck")
            return true
        end
    end
    return false
end

-- 安全获取附近可见英雄列表（自动过滤不可见单位，避免引擎警告）
function utilityModule.GetNearbyVisibleHeroes(npcBot, radius, teamFilter, modeFilter)
    local heroes = utility.GetNearbyVisibleHeroes(npcBot, radius, teamFilter, modeFilter)
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

return utilityModule
